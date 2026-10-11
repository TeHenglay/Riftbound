-- Party wiring: the PartyAction remote (invite, accept, decline, leave, kick),
-- PartyChanged (the party snapshot, nil when out of one) and PartyInvite (an
-- invite popup). Starting matches with the party lives in LobbyMenu.server
-- (Training) and StoryService (Story acts).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local PartyService = require(script.Parent.PartyService)

local remotes = Shared:WaitForChild("NationRemotes")
local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local PartyAction = remote("RemoteFunction", "PartyAction")
local PartyChanged = remote("RemoteEvent", "PartyChanged")
local PartyInvite = remote("RemoteEvent", "PartyInvite")

PartyService.OnNotify = function(player, text, color)
	local notify = Shared:WaitForChild("Remotes"):FindFirstChild("Notify")
	if notify then
		notify:FireClient(player, text, color)
	end
end
PartyService.OnChanged = function(player, snapshot)
	PartyChanged:FireClient(player, snapshot)
end
PartyService.OnInvite = function(player, from, seconds)
	PartyInvite:FireClient(player, {
		From = from.UserId,
		Name = from.DisplayName,
		Nation = from:GetAttribute("Nation"),
		Level = from:GetAttribute("Level") or 1,
		Seconds = seconds,
	})
end

local lastCall = {}

-- ("Invite", userId), ("Accept", leaderId), ("Decline", leaderId), ("Leave"),
-- ("Kick", userId) or ("Get"). Returns ok, message (or the snapshot for Get).
PartyAction.OnServerInvoke = function(player, action, arg)
	if action == "Get" then
		return PartyService.Snapshot(player)
	end
	if os.clock() - (lastCall[player] or 0) < 0.25 then
		return false, "Slow down"
	end
	lastCall[player] = os.clock()
	if action == "Invite" and typeof(arg) == "number" then
		return PartyService.Invite(player, Players:GetPlayerByUserId(arg))
	elseif action == "Accept" then
		return PartyService.Accept(player, arg)
	elseif action == "Decline" then
		return PartyService.Decline(player, arg)
	elseif action == "Leave" then
		return PartyService.Leave(player)
	elseif action == "Kick" and typeof(arg) == "number" then
		return PartyService.Kick(player, arg)
	end
	return false, "Bad request"
end

-- Keep members' level and nation fresh in everyone's party list.
local function track(player)
	for _, name in { "Level", "Nation" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			PartyService.Refresh(player)
		end)
	end
end
Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
	PartyService.Remove(player)
end)
