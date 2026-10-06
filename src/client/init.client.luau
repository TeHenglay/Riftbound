--!strict
-- Client entry point.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local CameraController = require(script.CameraController)
local HudController = require(script.HudController)
local InputController = require(script.InputController)

HudController.start()
CameraController.start()
InputController.start()

InputController.onSelectionChanged(HudController.setSelected)

Remotes.LoadoutChanged.OnClientEvent:Connect(function(loadout)
	InputController.setLoadout(loadout)
	HudController.setLoadout(loadout)
end)

Remotes.SkillFx.OnClientEvent:Connect(HudController.playSkillFx)
