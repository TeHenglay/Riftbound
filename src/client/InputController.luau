--!strict
-- Skill input: mouse aim, attack/special/cast/dash, plus debug keys for testing elements.
--   Left click  Attack        Right click  Special
--   Q           Cast          Space        Dash
--   1-6         Infuse Fire/Ice/Lightning/Wind/Earth/Shadow into the selected slot (debug)
--   Tab         Cycle selected slot (debug)
--   F           Fuse the first available fusion on the selected slot (debug)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fusions = require(Shared.Fusions)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Types = require(Shared.Types)

local DASH_SPEED = 90
local DASH_TIME = 0.15

local SLOT_ORDER: { Types.SlotId } = { "Attack", "Special", "Cast", "Dash" }
local DEBUG_ELEMENTS: { [Enum.KeyCode]: Types.ElementId } = {
	[Enum.KeyCode.One] = "Fire",
	[Enum.KeyCode.Two] = "Ice",
	[Enum.KeyCode.Three] = "Lightning",
	[Enum.KeyCode.Four] = "Wind",
	[Enum.KeyCode.Five] = "Earth",
	[Enum.KeyCode.Six] = "Shadow",
}

local InputController = {}

local player = Players.LocalPlayer
local selectedIndex = 1
local loadout: Types.Loadout? = nil
local lastDash = 0
local onSelectionChanged: (Types.SlotId) -> () = function() end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Direction from the character to where the mouse points on the ground plane.
local function aimDirection(): Vector3
	local root = rootPart()
	if not root then
		return Vector3.zero
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return root.CFrame.LookVector
	end
	local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
	local target = ray.Origin + ray.Direction * t
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
end

local function faceDirection(direction: Vector3)
	local root = rootPart()
	if root and direction.Magnitude > 0 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
end

local function useSkill(slot: Types.SlotId)
	local direction = aimDirection()
	faceDirection(direction)
	Remotes.UseSkill:FireServer(slot, direction)
end

local function dash()
	local now = os.clock()
	local root = rootPart()
	if not root or now - lastDash < Skills.Dash.cooldown then
		return
	end
	lastDash = now

	-- Dash where you are moving, or toward the mouse if standing still.
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	local move = if humanoid then humanoid.MoveDirection else Vector3.zero
	local direction = if move.Magnitude > 0.1 then move.Unit else aimDirection()

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * DASH_SPEED
	velocity.ForceLimitsEnabled = true
	velocity.Parent = root
	task.delay(DASH_TIME, function()
		velocity:Destroy()
		attachment:Destroy()
	end)

	Remotes.UseSkill:FireServer("Dash", direction)
end

local function onAction(
	actionName: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if actionName == "Attack" or actionName == "Special" or actionName == "Cast" then
		useSkill(actionName :: Types.SlotId)
	elseif actionName == "Dash" then
		dash()
	elseif actionName == "DebugInfuse" then
		local element = DEBUG_ELEMENTS[input.KeyCode]
		if element then
			Remotes.Infuse:FireServer(SLOT_ORDER[selectedIndex], element)
		end
	elseif actionName == "DebugSlot" then
		selectedIndex = selectedIndex % #SLOT_ORDER + 1
		onSelectionChanged(SLOT_ORDER[selectedIndex])
	elseif actionName == "DebugFuse" and loadout then
		local slot = SLOT_ORDER[selectedIndex]
		local options = Fusions.available(loadout[slot])
		if options[1] then
			Remotes.Fuse:FireServer(slot, options[1].id)
		end
	end
	return Enum.ContextActionResult.Sink
end

function InputController.selectedSlot(): Types.SlotId
	return SLOT_ORDER[selectedIndex]
end

function InputController.onSelectionChanged(callback: (Types.SlotId) -> ())
	onSelectionChanged = callback
end

function InputController.setLoadout(newLoadout: Types.Loadout)
	loadout = newLoadout
end

function InputController.start()
	local priority = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(
		"Attack",
		onAction,
		false,
		priority,
		Enum.UserInputType.MouseButton1
	)
	ContextActionService:BindActionAtPriority(
		"Special",
		onAction,
		false,
		priority,
		Enum.UserInputType.MouseButton2
	)
	ContextActionService:BindActionAtPriority("Cast", onAction, false, priority, Enum.KeyCode.Q)
	-- Binding Space at high priority replaces jump with dash.
	ContextActionService:BindActionAtPriority("Dash", onAction, false, priority, Enum.KeyCode.Space)

	local debugKeys = {}
	for key in DEBUG_ELEMENTS do
		table.insert(debugKeys, key)
	end
	ContextActionService:BindActionAtPriority(
		"DebugInfuse",
		onAction,
		false,
		priority,
		table.unpack(debugKeys)
	)
	ContextActionService:BindActionAtPriority("DebugSlot", onAction, false, priority, Enum.KeyCode.Tab)
	ContextActionService:BindActionAtPriority("DebugFuse", onAction, false, priority, Enum.KeyCode.F)
end

return InputController
