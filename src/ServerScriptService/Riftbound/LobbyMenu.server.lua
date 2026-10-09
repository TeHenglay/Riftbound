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

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastFire[player] = nil
end)
