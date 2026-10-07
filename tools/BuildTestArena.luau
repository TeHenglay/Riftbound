-- Builds Workspace.RiftboundTestArena in Edit mode. Safe to re-run: it
-- replaces the previous arena. Run through the Studio MCP execute_luau tool
-- or paste into the Studio command bar.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local SHRINES = {
	{ Element = "Fire", Skill = "Fireball", SkillName = "Fireball", Color = Color3.fromRGB(255, 106, 43) },
	{ Element = "Water", Skill = "TidalWave", SkillName = "Tidal Wave", Color = Color3.fromRGB(52, 152, 255) },
	{ Element = "Earth", Skill = "StoneSpike", SkillName = "Stone Spike", Color = Color3.fromRGB(176, 122, 64) },
	{ Element = "Air", Skill = "Gust", SkillName = "Gust", Color = Color3.fromRGB(170, 245, 225) },
	{ Element = "Lightning", Skill = "SparkBolt", SkillName = "Spark Bolt", Color = Color3.fromRGB(250, 225, 60) },
}
local SIZE = 170
local WALL_HEIGHT = 14
local FLOOR_TOP = 1

local old = workspace:FindFirstChild("RiftboundTestArena")
if old then
	old:Destroy()
end

local arena = Instance.new("Model")
arena.Name = "RiftboundTestArena"

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function billboard(adornee, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 26)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextSize = 20
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = title
	t.Parent = gui
	local s = t:Clone()
	s.Position = UDim2.fromOffset(0, 24)
	s.Font = Enum.Font.GothamBold
	s.TextSize = 13
	s.TextColor3 = Color3.fromRGB(235, 230, 250)
	s.Text = subtitle
	s.Parent = gui
	gui.Parent = adornee
end

-- Floor, walls and rift cracks ----------------------------------------------
part(arena, {
	Name = "Floor",
	Size = Vector3.new(SIZE, 2, SIZE),
	Position = Vector3.new(0, FLOOR_TOP - 1, 0),
	Material = Enum.Material.Slate,
	Color = Color3.fromRGB(88, 80, 108),
})
for i, spec in {
	{ Vector3.new(SIZE + 8, WALL_HEIGHT, 4), Vector3.new(0, 0, -SIZE / 2 - 2) },
	{ Vector3.new(SIZE + 8, WALL_HEIGHT, 4), Vector3.new(0, 0, SIZE / 2 + 2) },
	{ Vector3.new(4, WALL_HEIGHT, SIZE), Vector3.new(-SIZE / 2 - 2, 0, 0) },
	{ Vector3.new(4, WALL_HEIGHT, SIZE), Vector3.new(SIZE / 2 + 2, 0, 0) },
} do
	part(arena, {
		Name = "Wall" .. i,
		Size = spec[1],
		Position = spec[2] + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT / 2, 0),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(58, 50, 76),
	})
end
local rng = Random.new(7)
for i = 1, 26 do
	local length = rng:NextNumber(6, 22)
	part(arena, {
		Name = "RiftCrack",
		Size = Vector3.new(0.5, 0.06, length),
		CFrame = CFrame.new(rng:NextNumber(-75, 75), FLOOR_TOP + 0.03, rng:NextNumber(-75, 75)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 90, 255),
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Element shrines ------------------------------------------------------------
local shrines = Instance.new("Folder")
shrines.Name = "Shrines"
shrines.Parent = arena
for i, s in SHRINES do
	local x = (i - 3) * 22
	local z = -58
	local model = Instance.new("Model")
	model.Name = s.Element .. "Shrine"
	part(model, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 9, 9),
		CFrame = CFrame.new(x, FLOOR_TOP + 1, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(70, 62, 86),
	})
	part(model, {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 9.6, 9.6),
		CFrame = CFrame.new(x, FLOOR_TOP + 0.2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = s.Color,
		CanCollide = false,
	})
	local crystal = part(model, {
		Name = "Crystal",
		Size = Vector3.new(2.4, 4.5, 2.4),
		CFrame = CFrame.new(x, FLOOR_TOP + 5.2, z) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = s.Color,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = s.Color
	light.Range = 16
	light.Brightness = 2
	light.Parent = crystal
	billboard(crystal, s.Element:upper() .. " SHRINE", s.SkillName, s.Color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take " .. s.SkillName
	prompt.ObjectText = s.Element .. " Shrine"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("GrantSkill", s.Skill)
	prompt.Parent = model.Base
	model.Parent = shrines
end

-- The Forge ------------------------------------------------------------------
local forge = Instance.new("Model")
forge.Name = "Forge"
local forgeBase = part(forge, {
	Name = "Base",
	Size = Vector3.new(8, 3, 6),
	Position = Vector3.new(-52, FLOOR_TOP + 1.5, 40),
	Material = Enum.Material.Basalt,
	Color = Color3.fromRGB(40, 32, 56),
})
part(forge, {
	Name = "Top",
	Size = Vector3.new(10, 1, 7),
	Position = Vector3.new(-52, FLOOR_TOP + 3.5, 40),
	Material = Enum.Material.Marble,
	Color = Color3.fromRGB(80, 70, 100),
})
local core = part(forge, {
	Name = "Core",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(3, 3, 3),
	Position = Vector3.new(-52, FLOOR_TOP + 6, 40),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(170, 120, 255),
	CanCollide = false,
})
local forgeLight = Instance.new("PointLight")
forgeLight.Color = Color3.fromRGB(170, 120, 255)
forgeLight.Range = 20
forgeLight.Brightness = 3
forgeLight.Parent = core
billboard(core, "THE FORGE", "Fuse two elements", Color3.fromRGB(190, 150, 255))
local forgePrompt = Instance.new("ProximityPrompt")
forgePrompt.ActionText = "Open Forge"
forgePrompt.ObjectText = "The Forge"
forgePrompt.KeyboardKeyCode = Enum.KeyCode.F
forgePrompt.HoldDuration = 0
forgePrompt.MaxActivationDistance = 12
forgePrompt.RequiresLineOfSight = false
forgePrompt:SetAttribute("Forge", true)
forgePrompt.Parent = forgeBase
forge.Parent = arena

-- The Rift Well: refills flasks (F) ---------------------------------------------
local WELL_POS = Vector3.new(30, FLOOR_TOP, 44)
local WELL_RED = Color3.fromRGB(255, 74, 94)
local well = Instance.new("Model")
well.Name = "RiftWell"
local wellBase = part(well, {
	Name = "Base",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(3, 10, 10),
	CFrame = CFrame.new(WELL_POS + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Material = Enum.Material.Basalt,
	Color = Color3.fromRGB(58, 48, 70),
})
part(well, {
	Name = "Rim",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.6, 10.6, 10.6),
	CFrame = CFrame.new(WELL_POS + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Material = Enum.Material.Metal,
	Color = Color3.fromRGB(168, 119, 63),
})
local liquid = part(well, {
	Name = "Liquid",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.3, 8, 8),
	CFrame = CFrame.new(WELL_POS + Vector3.new(0, 3.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Material = Enum.Material.Neon,
	Color = WELL_RED,
	CanCollide = false,
})
local wellLight = Instance.new("PointLight")
wellLight.Color = WELL_RED
wellLight.Range = 18
wellLight.Brightness = 2.5
wellLight.Parent = liquid
billboard(liquid, "RIFT WELL", "Press F to refill your flasks", Color3.fromRGB(255, 120, 135))

local refillPrompt = Instance.new("ProximityPrompt")
refillPrompt.ActionText = "Refill Flasks"
refillPrompt.ObjectText = "Rift Well"
refillPrompt.KeyboardKeyCode = Enum.KeyCode.F
refillPrompt.HoldDuration = 0
refillPrompt.MaxActivationDistance = 11
refillPrompt.RequiresLineOfSight = false
refillPrompt:SetAttribute("FlaskRefill", true)
refillPrompt.Parent = wellBase

well.Parent = arena

-- Dummy spawn points -----------------------------------------------------------
local spawns = Instance.new("Folder")
spawns.Name = "DummySpawns"
spawns.Parent = arena
local function marker(name, kind, pos)
	part(spawns, {
		Name = name,
		Size = Vector3.new(3, 0.2, 3),
		Position = pos + Vector3.new(0, FLOOR_TOP + 0.1, 0),
		Transparency = if kind == "Training" then 0.4 else 1,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 90, 70),
		CanCollide = false,
		CanQuery = false,
	}):SetAttribute("Kind", kind)
end
marker("Training1", "Training", Vector3.new(30, 0, -18))
marker("Training2", "Training", Vector3.new(38, 0, -6))
marker("Training3", "Training", Vector3.new(30, 0, 6))
marker("Husk1", "Husk", Vector3.new(60, 0, 50))
marker("Husk2", "Husk", Vector3.new(66, 0, 34))
marker("Husk3", "Husk", Vector3.new(50, 0, 62))

arena.Parent = workspace

-- Spawn point inside the arena -------------------------------------------------
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Parent = workspace
end
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, FLOOR_TOP + 0.5, 30)
spawn.Material = Enum.Material.Neon
spawn.Color = Color3.fromRGB(110, 70, 200)
spawn.Transparency = 0.3
spawn.CanCollide = false
for _, d in spawn:GetChildren() do
	if d:IsA("Decal") then
		d:Destroy()
	end
end

-- Moody rift lighting ----------------------------------------------------------
Lighting.ClockTime = 15.5
Lighting.Brightness = 2.6
Lighting.ExposureCompensation = 0.25
Lighting.Ambient = Color3.fromRGB(95, 80, 125)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 112, 160)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.22
	atmosphere.Color = Color3.fromRGB(150, 120, 200)
	atmosphere.Decay = Color3.fromRGB(80, 50, 120)
	atmosphere.Haze = 1.5
end

return "Arena built: " .. #arena:GetDescendants() .. " instances"
