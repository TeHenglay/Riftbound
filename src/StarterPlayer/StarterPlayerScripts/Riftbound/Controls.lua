-- Input: hold left mouse for the basic attack, hold right mouse to block,
-- Q/E for equipped skills,
-- Shift to dash, R to drink the flask, B for the backpack, C for stats. Skills aim at the cursor.
-- (F is the interact key.)
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DASH_SPEED = 85
local DASH_TIME = 0.18
local DASH_COOLDOWN = 0.9

local CastAnimator = require(script.Parent:WaitForChild("CastAnimator"))

local Controls = {}

function Controls.Init(Remotes, HUD)
	local player = Players.LocalPlayer
	local attackHeld = false
	local blockHeld = false
	local lastDash = -math.huge

	local function getRoot()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return nil
		end
		return char:FindFirstChild("HumanoidRootPart"), hum
	end

	local function aimPoint(root)
		local mouse = UserInputService:GetMouseLocation()
		local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("RiftFX") }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if result then
			return result.Position
		end
		-- Nothing under the cursor: intersect with the floor plane.
		local floorY = root.Position.Y - 3
		local t = (floorY - ray.Origin.Y) / ray.Direction.Y
		return ray.Origin + ray.Direction * math.max(t, 0)
	end

	local function cast(slot)
		local root = getRoot()
		if not root or HUD.MenuOpen() then
			return
		end
		if not HUD.TryStartCooldown(slot) then
			return
		end
		local target = aimPoint(root)
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
		Remotes.Cast:FireServer(slot, target)
		CastAnimator.Play(player.Character, HUD.SkillInSlot(slot))
	end

	local function dash()
		local root, hum = getRoot()
		local now = os.clock()
		if not root or now - lastDash < DASH_COOLDOWN then
			return
		end
		lastDash = now
		local dir = hum.MoveDirection
		if dir.Magnitude < 0.1 then
			dir = root.CFrame.LookVector
		end
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = root:FindFirstChild("RootAttachment")
		lv.MaxForce = math.huge
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = dir * DASH_SPEED
		lv.Parent = root
		Debris:AddItem(lv, DASH_TIME)
		HUD.StartDashCooldown(DASH_COOLDOWN)
		CastAnimator.Play(player.Character, "Dash")
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not processed then
				attackHeld = true
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if not processed and not HUD.MenuOpen() and getRoot() then
				blockHeld = true
				Remotes.Block:FireServer(true)
				if HUD.BlockReady() then
					CastAnimator.PredictGuard()
				end
			end
			return
		end
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Q then
			cast("Q")
		elseif key == Enum.KeyCode.E then
			cast("E")
		elseif key == Enum.KeyCode.LeftShift then
			dash()
		elseif key == Enum.KeyCode.R then
			Remotes.UseFlask:FireServer()
		elseif key == Enum.KeyCode.B then
			HUD.ToggleBackpack()
		elseif key == Enum.KeyCode.C then
			HUD.ToggleStats()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and blockHeld then
			blockHeld = false
			Remotes.Block:FireServer(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if attackHeld then
			cast("M1")
		end
	end)
end

return Controls
