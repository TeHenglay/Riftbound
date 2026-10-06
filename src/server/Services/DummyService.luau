--!strict
-- Spawns training dummies to test skills on. Replaced by real enemies in the run loop milestone.

local CollectionService = game:GetService("CollectionService")

local DUMMY_HEALTH = 200
local RESPAWN_DELAY = 3
local POSITIONS = {
	Vector3.new(-10, 0, -25),
	Vector3.new(0, 0, -30),
	Vector3.new(10, 0, -25),
	Vector3.new(4, 0, -38),
}

local DummyService = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addHealthLabel(model: Model, head: BasePart, humanoid: Humanoid)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	local function refresh()
		local tags = {}
		for _, status in { "Burn", "Chill" } do
			if model:GetAttribute(status) then
				table.insert(tags, status)
			end
		end
		local suffix = if #tags > 0 then "\n" .. table.concat(tags, " ") else ""
		label.Text = string.format("%d / %d%s", math.ceil(humanoid.Health), DUMMY_HEALTH, suffix)
	end
	humanoid.HealthChanged:Connect(refresh)
	model.AttributeChanged:Connect(refresh)
	refresh()

	gui.Parent = head
end

local function spawnDummy(position: Vector3)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local base = CFrame.new(position)
	local root = makePart(
		"HumanoidRootPart",
		Vector3.new(2, 2, 1),
		base * CFrame.new(0, 3, 0),
		Color3.fromRGB(140, 100, 60)
	)
	local head = makePart(
		"Head",
		Vector3.new(1.5, 1.5, 1.5),
		base * CFrame.new(0, 4.75, 0),
		Color3.fromRGB(200, 170, 120)
	)
	local post =
		makePart("Post", Vector3.new(0.5, 2, 0.5), base * CFrame.new(0, 1, 0), Color3.fromRGB(90, 60, 40))
	root.Parent = model
	head.Parent = model
	post.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.RequiresNeck = false -- parts are anchored, not jointed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- Tint the dummy while statuses are active so effects are easy to see.
	model.AttributeChanged:Connect(function()
		if model:GetAttribute("Chill") then
			root.Color = Color3.fromRGB(120, 200, 255)
		elseif model:GetAttribute("Burn") then
			root.Color = Color3.fromRGB(255, 120, 50)
		else
			root.Color = Color3.fromRGB(140, 100, 60)
		end
	end)

	addHealthLabel(model, head, humanoid)
	CollectionService:AddTag(model, "Enemy")
	model.Parent = workspace

	humanoid.Died:Connect(function()
		task.wait(RESPAWN_DELAY)
		model:Destroy()
		spawnDummy(position)
	end)
end

function DummyService.start()
	for _, position in POSITIONS do
		spawnDummy(position)
	end
end

return DummyService
