-- Hades-style angled top-down camera that follows the character, with
-- trauma-based screen shake for big impacts (CameraRig.Shake).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local OFFSET_DIR = Vector3.new(0, 1.35, 1).Unit
local MIN_ZOOM, MAX_ZOOM = 35, 90
local FOLLOW_SPEED = 12
local SHAKE_DECAY = 2.4 -- trauma lost per second
local SHAKE_MAX_OFFSET = 1.4 -- studs at full trauma
local SHAKE_MAX_ROLL = math.rad(2.5)

local CameraRig = {}

local trauma = 0

-- Adds screen shake (0..1). `at` (optional) fades it with distance from the camera focus.
function CameraRig.Shake(amount, at)
	local player = Players.LocalPlayer
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if at and root then
		local dist = (at - root.Position).Magnitude
		amount *= math.clamp(1 - (dist - 20) / 60, 0, 1)
	end
	trauma = math.min(trauma + amount, 1)
end

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
		local cf = CFrame.lookAt(focus + OFFSET_DIR * zoom, focus)
		if trauma > 0 then
			-- Squared trauma feels better than linear; noise keeps it smooth.
			local s = trauma * trauma
			local t = os.clock() * 28
			local offset = Vector3.new(math.noise(t, 0.1), math.noise(t, 1.7), 0) * SHAKE_MAX_OFFSET * s
			cf = cf * CFrame.new(offset) * CFrame.Angles(0, 0, math.noise(t, 3.3) * SHAKE_MAX_ROLL * s)
			trauma = math.max(trauma - SHAKE_DECAY * dt, 0)
		end
		camera.CFrame = cf
	end)
end

return CameraRig
