-- Applies the shared modern theme (ReplicatedStorage.Riftbound.Theme) to every
-- screen the player gets, including ones built later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Theme"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function hook(gui)
	if gui:IsA("LayerCollector") then
		Theme.Apply(gui)
	end
end

for _, gui in playerGui:GetChildren() do
	hook(gui)
end
playerGui.ChildAdded:Connect(hook)
