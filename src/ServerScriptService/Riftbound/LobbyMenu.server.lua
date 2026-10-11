-- Lobby menu: picking a match on the Play screen fires EnterRift(mode). Only
-- Training (the current arena) is open; it walks the player through their
-- nation's portal (same path as touching the gate).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local NationService = require(script.Parent.NationService)

local remotes = Shared:WaitForChild("Remotes")
local EnterRift = remotes:FindFirstChild("EnterRift") or Instance.new("RemoteEvent")
EnterRift.Name = "EnterRift"
EnterRift.Parent = remotes

local MODES = {
	Training = "the Training Grounds",
}

local lastFire = {}
EnterRift.OnServerEvent:Connect(function(player, mode)
	if typeof(mode) ~= "string" or not MODES[mode] then
		return
	end
	if os.clock() - (lastFire[player] or 0) < 2 then
		return
	end
	lastFire[player] = os.clock()
	-- Only from a lobby: nation chosen and not already in the Rift.
	if player:GetAttribute("Nation") and not player:GetAttribute("InRift") then
		player:SetAttribute("MatchMode", mode)
		NationService.EnterRift(player)
		local notify = remotes:FindFirstChild("Notify")
		if notify then
			notify:FireClient(player, "Entering " .. MODES[mode])
		end
	end
end)

-- The in-match settings menu's Leave Match: straight home to the nation lobby.
-- Story.server.lua drops the player from their story run when Area changes.
local LeaveMatch = remotes:FindFirstChild("LeaveMatch") or Instance.new("RemoteEvent")
LeaveMatch.Name = "LeaveMatch"
LeaveMatch.Parent = remotes

local lastLeave = {}
LeaveMatch.OnServerEvent:Connect(function(player)
	if os.clock() - (lastLeave[player] or 0) < 2 or not player:GetAttribute("InRift") then
		return
	end
	lastLeave[player] = os.clock()
	player:SetAttribute("MatchMode", nil)
	NationService.ReturnToLobby(player)
	local notify = remotes:FindFirstChild("Notify")
	if notify then
		notify:FireClient(player, "You left the match")
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastFire[player] = nil
	lastLeave[player] = nil
end)
