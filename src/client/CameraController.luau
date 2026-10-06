--!strict
-- Hades-style angled top-down camera that follows the character.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local OFFSET = Vector3.new(0, 42, 26)
local FIELD_OF_VIEW = 45

local CameraController = {}

function CameraController.start()
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer

	RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW
		local focus = root.Position
		camera.CFrame = CFrame.lookAt(focus + OFFSET, focus)
	end)
end

return CameraController
