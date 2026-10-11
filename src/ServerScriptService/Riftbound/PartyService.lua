-- Parties: a player invites others (up to PartyService.Max players in all) and
-- becomes the party leader. Only the leader starts matches; when they do,
-- every member waiting in a lobby comes along (Training or a Story act).
-- Invites expire after INVITE_TIME seconds. If the leader leaves, the next
-- member leads; a party left with one player breaks up.
-- Each member gets the player attribute "PartyId" (shared by the party) and
-- "PartyLeader" (true for the leader), and a snapshot through OnChanged.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local PartyService = {}

PartyService.Max = 4 -- players in a party, leader included
local INVITE_TIME = 30
local INVITE_COOLDOWN = 3 -- seconds between invites to the same player

-- Set by Party.server.
PartyService.OnNotify = function(_player, _text, _color) end
PartyService.OnChanged = function(_player, _snapshot) end -- snapshot is nil when out of a party
PartyService.OnInvite = function(_player, _from, _seconds) end

local parties = {} -- [id] = { Id, Leader, Members = { player, ... } }
local partyOf = {} -- [player] = party
local invites = {} -- [target] = { [partyId] = { From = player, Expires = os.clock() } }
local lastInvite = {} -- [from] = { [target] = os.clock() }

local function snapshot(party)
	local members = {}
	for _, p in party.Members do
		table.insert(members, {
			UserId = p.UserId,
			Name = p.Name,
			DisplayName = p.DisplayName,
			Nation = p:GetAttribute("Nation"),
			Level = p:GetAttribute("Level") or 1,
			Leader = p == party.Leader,
		})
	end
	return { Id = party.Id, Leader = party.Leader.UserId, Max = PartyService.Max, Members = members }
end

local function publish(party)
	local snap = snapshot(party)
	for _, p in party.Members do
		p:SetAttribute("PartyId", party.Id)
		p:SetAttribute("PartyLeader", p == party.Leader)
		PartyService.OnChanged(p, snap)
	end
end

local function clearPlayer(player)
	partyOf[player] = nil
	if player.Parent then
		player:SetAttribute("PartyId", nil)
		player:SetAttribute("PartyLeader", nil)
		PartyService.OnChanged(player, nil)
	end
end

local function disband(party)
	parties[party.Id] = nil
	for _, p in party.Members do
		clearPlayer(p)
	end
	table.clear(party.Members)
	for _, pending in invites do
		pending[party.Id] = nil
	end
end

local function create(leader)
	local party = { Id = HttpService:GenerateGUID(false), Leader = leader, Members = { leader } }
	parties[party.Id] = party
	partyOf[leader] = party
	return party
end

function PartyService.Get(player)
	return partyOf[player]
end

function PartyService.IsLeader(player)
	local party = partyOf[player]
	return party ~= nil and party.Leader == player
end

-- True when the player may start a match: solo, or leading their party.
function PartyService.CanStart(player)
	local party = partyOf[player]
	return party == nil or party.Leader == player
end

-- The other members, in join order.
function PartyService.Others(player)
	local party = partyOf[player]
	local list = {}
	for _, p in party and party.Members or {} do
		if p ~= player then
			table.insert(list, p)
		end
	end
	return list
end

-- Members that can follow the leader into a match right now: in a lobby, with
-- a nation and a living character.
function PartyService.Followers(leader)
	local ready, busy = {}, {}
	for _, p in PartyService.Others(leader) do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if p:GetAttribute("Nation") and not p:GetAttribute("InRift") and hum and hum.Health > 0 then
			table.insert(ready, p)
		else
			table.insert(busy, p)
		end
	end
	return ready, busy
end

-- Returns ok, message.
function PartyService.Invite(from, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		return false, "That player isn't here"
	end
	if target == from then
		return false, "You can't invite yourself"
	end
	if not target:GetAttribute("Nation") then
		return false, target.DisplayName .. " hasn't picked a nation yet"
	end
	local party = partyOf[from]
	if party and party.Leader ~= from then
		return false, "Only the party leader can invite"
	end
	if party and partyOf[target] == party then
		return false, target.DisplayName .. " is already in your party"
	end
	if partyOf[target] then
		return false, target.DisplayName .. " is already in a party"
	end
	if party and #party.Members >= PartyService.Max then
		return false, "Your party is full (" .. PartyService.Max .. " players)"
	end
	lastInvite[from] = lastInvite[from] or {}
	if os.clock() - (lastInvite[from][target] or 0) < INVITE_COOLDOWN then
		return false, "Wait a moment before inviting again"
	end
	lastInvite[from][target] = os.clock()
	if not party then
		party = create(from)
		publish(party)
	end
	invites[target] = invites[target] or {}
	invites[target][party.Id] = { From = from, Expires = os.clock() + INVITE_TIME }
	PartyService.OnInvite(target, from, INVITE_TIME)
	return true, "Invited " .. target.DisplayName
end

-- Finds a live invite to `player` from the party `leaderId` now leads.
local function findInvite(player, leaderId)
	local pending = invites[player]
	if not pending then
		return nil
	end
	for id, invite in pending do
		local party = parties[id]
		if not party or os.clock() > invite.Expires then
			pending[id] = nil
		elseif party.Leader.UserId == leaderId or invite.From.UserId == leaderId then
			return party, id
		end
	end
	return nil
end

-- Returns ok, message.
function PartyService.Accept(player, leaderId)
	if typeof(leaderId) ~= "number" then
		return false, "Bad request"
	end
	local party, id = findInvite(player, leaderId)
	if not party then
		return false, "That invite has expired"
	end
	invites[player][id] = nil
	if partyOf[player] == party then
		return true, "Already in this party"
	end
	if #party.Members >= PartyService.Max then
		return false, "That party is full"
	end
	if partyOf[player] then
		PartyService.Leave(player)
	end
	table.insert(party.Members, player)
	partyOf[player] = party
	publish(party)
	for _, p in party.Members do
		if p ~= player then
			PartyService.OnNotify(p, player.DisplayName .. " joined the party")
		end
	end
	return true, "Joined " .. party.Leader.DisplayName .. "'s party"
end

function PartyService.Decline(player, leaderId)
	if typeof(leaderId) ~= "number" then
		return false, "Bad request"
	end
	local party, id = findInvite(player, leaderId)
	if party then
		invites[player][id] = nil
		PartyService.OnNotify(party.Leader, player.DisplayName .. " declined your invite")
	end
	return true
end

function PartyService.Leave(player)
	local party = partyOf[player]
	if not party then
		return false, "You're not in a party"
	end
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	clearPlayer(player)
	if #party.Members <= 1 then
		for _, p in party.Members do
			PartyService.OnNotify(p, "Your party broke up")
		end
		disband(party)
		return true, "You left the party"
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
		PartyService.OnNotify(party.Leader, "You're the party leader now")
	end
	publish(party)
	for _, p in party.Members do
		PartyService.OnNotify(p, player.DisplayName .. " left the party")
	end
	return true, "You left the party"
end

function PartyService.Kick(leader, userId)
	local party = partyOf[leader]
	if not party or party.Leader ~= leader then
		return false, "Only the party leader can remove players"
	end
	for _, p in party.Members do
		if p.UserId == userId and p ~= leader then
			PartyService.OnNotify(p, "You were removed from the party")
			PartyService.Leave(p)
			return true, "Removed " .. p.DisplayName
		end
	end
	return false, "That player isn't in your party"
end

function PartyService.Snapshot(player)
	local party = partyOf[player]
	return party and snapshot(party)
end

-- Re-sends the party to its members (e.g. after a member levels up).
function PartyService.Refresh(player)
	local party = partyOf[player]
	if party then
		publish(party)
	end
end

function PartyService.Remove(player)
	if partyOf[player] then
		PartyService.Leave(player)
	end
	invites[player] = nil
	lastInvite[player] = nil
	for _, pending in invites do
		for id, invite in pending do
			if invite.From == player then
				pending[id] = nil
			end
		end
	end
end

return PartyService
