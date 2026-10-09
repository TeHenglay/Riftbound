-- Lobby menu: the Play button fires EnterRift, which walks the player through
-- their nation's portal (same path as touching the gate).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local NationService = require(script.Parent.NationService)

local remotes = Shared:WaitForChild("Remotes")
local EnterRift = remotes:FindFirstChild("EnterRift") or Instance.new("RemoteEvent")
EnterRift.Name = "EnterRift"
EnterRift.Parent = remotes

local lastFire = {}
EnterRift.OnServerEvent:Connect(function(player)
	if os.clock() - (lastFire[player] or 0) < 2 then
		return
	end
	lastFire[player] = os.clock()
	-- Only from a lobby: nation chosen and not already in the Rift.
	if player:GetAttribute("Nation") and not player:GetAttribute("InRift") then
		NationService.EnterRift(player)
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastFire[player] = nil
end)
