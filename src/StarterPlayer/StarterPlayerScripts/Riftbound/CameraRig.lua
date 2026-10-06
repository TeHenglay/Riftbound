-- Hades-style angled top-down camera that follows the character.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local OFFSET_DIR = Vector3.new(0, 1.35, 1).Unit
local MIN_ZOOM, MAX_ZOOM = 35, 90
local FOLLOW_SPEED = 12

local CameraRig = {}

function CameraRig.Init()
	local player = Players.LocalPlayer
	local zoom = 58
	local focus

	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 4, MIN_ZOOM, MAX_ZOOM)
		end
	end)

	RunService:BindToRenderStep("RiftboundCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 45
		local target = root.Position
		focus = if focus then focus:Lerp(target, math.min(dt * FOLLOW_SPEED, 1)) else target
		camera.CFrame = CFrame.lookAt(focus + OFFSET_DIR * zoom, focus)
	end)
end

return CameraRig
