-- Builds the five nation lobbies: floating islands far from the Rift, each with
-- a spawn pad, a nation board, a central monument, braziers, themed decor and
-- a Rift portal into gameplay. Everything lives in workspace.NationLobbies.
--
-- Props from ServerStorage.LobbyAssets (AI-generated meshes and Creator Store
-- models, place-only) are used when present; otherwise plain parts stand in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Nations = require(Shared:WaitForChild("Nations"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local LobbyBuilder = {}

LobbyBuilder.Spacing = 700
LobbyBuilder.Height = 150
LobbyBuilder.Z = 2600
LobbyBuilder.Radius = 72

local RIFT = Color3.fromRGB(178, 108, 255)
local RIFT_HOT = Color3.fromRGB(231, 200, 255)
local OBSIDIAN = Color3.fromRGB(22, 17, 30)
local BRONZE = Color3.fromRGB(168, 119, 63)
local GOLD = Color3.fromRGB(233, 194, 122)
local PARCHMENT = Color3.fromRGB(241, 227, 198)

local THEMES = {
	Fire = {
		TerrainRock = Enum.Material.Basalt,
		FloorVariant = "fire_ground", PlazaVariant = "fire_plaza",
		Floor = Enum.Material.Basalt, FloorColor = Color3.fromRGB(46, 34, 32),
		Plaza = Enum.Material.CrackedLava, PlazaColor = Color3.fromRGB(70, 40, 30),
		Rock = Enum.Material.Basalt, RockColor = Color3.fromRGB(38, 30, 30),
		Particle = UIAssets.Fx.Flame,
	},
	Earth = {
		TerrainRock = Enum.Material.Rock,
		FloorVariant = "earth_grass", PlazaVariant = "earth_flagstone",
		Floor = Enum.Material.Grass, FloorColor = Color3.fromRGB(92, 122, 58),
		Plaza = Enum.Material.Slate, PlazaColor = Color3.fromRGB(118, 104, 88),
		Rock = Enum.Material.Rock, RockColor = Color3.fromRGB(105, 90, 74),
		Particle = UIAssets.Fx.Shard,
	},
	Water = {
		TerrainRock = Enum.Material.Sandstone,
		FloorVariant = nil, PlazaVariant = "water_marble", -- the AI sand variant came out too brown
		Floor = Enum.Material.Sand, FloorColor = Color3.fromRGB(246, 238, 220),
		Plaza = Enum.Material.Marble, PlazaColor = Color3.fromRGB(205, 220, 230),
		Rock = Enum.Material.Limestone, RockColor = Color3.fromRGB(170, 180, 186),
		Particle = UIAssets.Fx.Drop,
	},
	Wind = {
		TerrainRock = Enum.Material.Rock,
		FloorVariant = "wind_grass", PlazaVariant = "wind_limestone",
		Floor = Enum.Material.Grass, FloorColor = Color3.fromRGB(126, 176, 120),
		Plaza = Enum.Material.Limestone, PlazaColor = Color3.fromRGB(226, 228, 214),
		Rock = Enum.Material.Rock, RockColor = Color3.fromRGB(150, 150, 140),
		Particle = UIAssets.Fx.Swirl,
	},
	Lightning = {
		FloorVariant = "sky_cloud", PlazaVariant = "sky_marble",
		Floor = Enum.Material.Snow, FloorColor = Color3.fromRGB(232, 235, 245),
		Plaza = Enum.Material.Marble, PlazaColor = Color3.fromRGB(226, 226, 234),
		Rock = Enum.Material.SmoothPlastic, RockColor = Color3.fromRGB(236, 240, 250),
		MonumentHeight = 30,
		Particle = UIAssets.Fx.Lightning,
	},
}

local function part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- A flat disc: cylinder lying with its axis vertical.
local function disc(parent, center, diameter, thickness, material, color, props)
	local p = part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Material = material,
		Color = color,
		Parent = parent,
	})
	for k, v in props or {} do
		p[k] = v
	end
	return p
end

local function emitter(parent, texture, color, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Rate = 8
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(2, 4)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.SpreadAngle = Vector2.new(15, 15)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	for k, v in props or {} do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent, color, range, brightness, flicker)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 14
	l.Brightness = brightness or 1.5
	l.Shadows = false
	if flicker then
		l:SetAttribute("Flicker", true)
	end
	l.Parent = parent
	return l
end

-- Clones a prop from ServerStorage.LobbyAssets, scaled to `height`, with its
-- base resting at `cf`. Returns the clone or nil when the asset is missing.
local function prop(parent, name, cf, height)
	local folder = ServerStorage:FindFirstChild("LobbyAssets")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local m = Instance.new("Model")
		m.Name = name
		model.Parent = m
		m.PrimaryPart = model
		model = m
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	if height and size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
	local boxCf, boxSize = model:GetBoundingBox()
	local offset = model:GetPivot():ToObjectSpace(boxCf)
	-- Put the bounding box's bottom centre on cf.
	model:PivotTo(cf * CFrame.new(0, boxSize.Y / 2, 0) * offset:Inverse())
	model.Parent = parent
	return model
end

local function rock(parent, theme, cf, size)
	return part({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = cf,
		Material = theme.Rock,
		Color = theme.RockColor,
		Parent = parent,
	})
end

-------------------------------------------------------------------------------
-- Shared pieces
-------------------------------------------------------------------------------

local function buildIsland(lobby, def, theme, c, rng)
	local R = theme.Radius or LobbyBuilder.Radius
	local island = Instance.new("Model")
	island.Name = "Island"
	island.Parent = lobby

	disc(island, c - Vector3.new(0, 4, 0), R * 2, 8, theme.Floor, theme.FloorColor, { Name = "Ground" })
	disc(island, c + Vector3.new(0, 0.15, 0), 70, 0.3, Enum.Material.Neon, def.Color, { Name = "PlazaRing" })
	disc(island, c + Vector3.new(0, 0.25, 0), 66, 0.5, theme.Plaza, theme.PlazaColor, { Name = "Plaza" })
	disc(island, c + Vector3.new(0, 0.4, 0), 14, 0.6, Enum.Material.Neon, def.Color, { Name = "CoreGlow", Transparency = 0.2 })

	-- Hanging rocks under the island so it reads as floating: smooth terrain
	-- rock when the theme has it, otherwise part balls (the cloud island).
	if theme.TerrainRock then
		local terrain = workspace.Terrain
		for i = 1, 18 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, R * 0.8)
			local s = rng:NextNumber(16, 26) * (1 - r / R * 0.5)
			terrain:FillBall(c + Vector3.new(math.cos(a) * r, -s - 8 - rng:NextNumber(0, 14), math.sin(a) * r), s, theme.TerrainRock)
		end
		for i = 1, 5 do
			terrain:FillBall(c + Vector3.new(rng:NextNumber(-8, 8), -30 - i * 13, rng:NextNumber(-8, 8)), 18 - i * 3, theme.TerrainRock)
		end
		-- Rock band under the ground part. Terrain snaps to a 4-stud grid, so it
		-- stays well below the floor; touching it makes the floor flicker.
		terrain:FillCylinder(CFrame.new(c - Vector3.new(0, 14, 0)), 8, R - 2, theme.TerrainRock)
	end
	for i = 1, if theme.TerrainRock then 0 else 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, R * 0.75)
		local s = rng:NextNumber(26, 48) * (1 - r / R * 0.5)
		rock(island, theme, CFrame.new(c + Vector3.new(math.cos(a) * r, -s * 0.3 - rng:NextNumber(4, 22), math.sin(a) * r)), s)
	end
	-- A crooked tail of stone dripping down from the middle.
	for i = 1, if theme.TerrainRock then 0 else 4 do
		rock(island, theme, CFrame.new(c + Vector3.new(rng:NextNumber(-6, 6), -30 - i * 14, rng:NextNumber(-6, 6))), 30 - i * 6)
	end

	-- An invisible fence keeps players from walking off the edge.
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		part({
			Name = "Fence",
			Size = Vector3.new(14, 30, 2),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * (R + 1), 15, math.sin(a) * (R + 1))) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Transparency = 1,
			CanQuery = false,
			Parent = island,
		})
	end
end

local function buildSpawn(lobby, def, theme, c)
	local at = c + Vector3.new(0, 0.5, theme.SpawnZ or 46)
	local spawn = part({
		Class = "SpawnLocation",
		Name = "Spawn",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.lookAt(at, at - Vector3.new(0, 0, 1)),
		Material = theme.Plaza,
		Color = theme.PlazaColor,
		Parent = lobby,
	})
	-- Must be neutral for Player.RespawnLocation to work on team-less players;
	-- NationService always sets RespawnLocation, so it never spawns strangers here.
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	for _, d in spawn:GetChildren() do
		d:Destroy() -- default decal
	end
	disc(lobby, at + Vector3.new(0, 0.55, 0), 9, 0.1, Enum.Material.Neon, def.Color, { Name = "SpawnGlow", Transparency = 0.4, CanCollide = false })
end

local function buildBoard(lobby, def, c)
	local base = CFrame.lookAt(c + Vector3.new(-18, 0, 34), c + Vector3.new(0, 0, 50))
	local board = Instance.new("Model")
	board.Name = "NationBoard"
	board.Parent = lobby
	local slab = part({
		Name = "Slab",
		Size = Vector3.new(14, 10, 1),
		CFrame = base * CFrame.new(0, 8, 0),
		Material = Enum.Material.Basalt,
		Color = OBSIDIAN,
		Parent = board,
	})
	for _, x in { -7.3, 7.3 } do
		part({ Name = "Post", Size = Vector3.new(1.2, 13.5, 1.6), CFrame = base * CFrame.new(x, 6.75, 0), Material = Enum.Material.Metal, Color = BRONZE, Parent = board })
	end
	part({ Name = "Cap", Size = Vector3.new(16, 1, 1.8), CFrame = base * CFrame.new(0, 13.4, 0), Material = Enum.Material.Metal, Color = BRONZE, Parent = board })
	part({ Name = "Glow", Size = Vector3.new(14, 0.3, 0.4), CFrame = base * CFrame.new(0, 3.1, -0.4), Material = Enum.Material.Neon, Color = def.Color, Parent = board })

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces the spawn
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = slab
	local function label(y, h, text, font, color, size)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.06, y)
		t.Size = UDim2.fromScale(0.88, h)
		t.Text = text
		t.FontFace = font
		t.TextColor3 = color
		t.TextScaled = true
		t.RichText = true
		t.TextWrapped = true
		t.Parent = gui
		local c2 = Instance.new("UITextSizeConstraint")
		c2.MaxTextSize = size
		c2.Parent = t
		return t
	end
	local serif = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)
	local label2 = Font.new(Font.fromEnum(Enum.Font.Oswald).Family, Enum.FontWeight.Bold)
	local italic = Font.new(Font.fromEnum(Enum.Font.Garamond).Family, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	local body = Font.new(Font.fromEnum(Enum.Font.Merriweather).Family)
	local element = if def.Id == "Wind" then "WIND" else def.Element:upper()
	label(0.07, 0.1, (element:gsub("(.)", "%1 ")) .. " N A T I O N", label2, def.Color, 40)
	label(0.18, 0.2, def.Name, serif, GOLD, 90)
	label(0.39, 0.1, def.Motto, italic, PARCHMENT, 44)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = BRONZE
	line.BorderSizePixel = 0
	line.Position = UDim2.fromScale(0.2, 0.53)
	line.Size = UDim2.fromScale(0.6, 0.006)
	line.Parent = gui
	for i, perk in def.PerkText do
		label(0.58 + (i - 1) * 0.15, 0.12, `<font color="#{def.Color:ToHex()}">◆</font>  {perk}`, body, PARCHMENT, 46)
	end
end

-- opts: Offset (from the lobby centre), Travel ("Rift", "Crossroads" or
-- "Nation"), Name, Title, Subtitle, Veil and Glow colours.
local function buildPortal(lobby, def, c, opts)
	opts = opts or {}
	local at = c + (opts.Offset or Vector3.new(0, 0, -56))
	local base = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
	local portal = Instance.new("Model")
	portal.Name = opts.Name or "RiftPortal"
	portal.Parent = lobby

	-- Steps up to the gate.
	for i = 0, 2 do
		part({ Name = "Step", Size = Vector3.new(30 - i * 3, 1, 10 - i * 2.5), CFrame = base * CFrame.new(0, 0.5 + i, -i * 2.5), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = portal })
	end
	local floorY = 3
	for _, x in { -11, 11 } do
		part({ Name = "Pillar", Size = Vector3.new(5, 26, 5), CFrame = base * CFrame.new(x, floorY + 13, -5), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = portal })
		part({ Name = "Trim", Size = Vector3.new(5.6, 1.2, 5.6), CFrame = base * CFrame.new(x, floorY + 1, -5), Material = Enum.Material.Metal, Color = BRONZE, Parent = portal })
		part({ Name = "Trim", Size = Vector3.new(5.6, 1.2, 5.6), CFrame = base * CFrame.new(x, floorY + 24, -5), Material = Enum.Material.Metal, Color = BRONZE, Parent = portal })
		-- Rift crack running up the pillar's face.
		part({ Name = "Crack", Size = Vector3.new(0.5, 18, 0.2), CFrame = base * CFrame.new(x, floorY + 12, -2.45) * CFrame.Angles(0, 0, math.rad(x > 0 and 6 or -6)), Material = Enum.Material.Neon, Color = RIFT, CanCollide = false, Parent = portal })
	end
	part({ Name = "Lintel", Size = Vector3.new(30, 5, 6), CFrame = base * CFrame.new(0, floorY + 28, -5), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = portal })
	part({ Name = "LintelTrim", Size = Vector3.new(31, 1, 6.6), CFrame = base * CFrame.new(0, floorY + 25.6, -5), Material = Enum.Material.Metal, Color = BRONZE, Parent = portal })
	part({ Name = "Keystone", Size = Vector3.new(4, 4, 1), CFrame = base * CFrame.new(0, floorY + 28, -1.9) * CFrame.Angles(0, 0, math.rad(45)), Material = Enum.Material.Neon, Color = def.Color, Parent = portal })

	local veil = part({
		Name = "Veil",
		Size = Vector3.new(17, 24, 0.4),
		CFrame = base * CFrame.new(0, floorY + 12.5, -5),
		Material = Enum.Material.Neon,
		Color = opts.Veil or Color3.fromRGB(96, 40, 170),
		Transparency = 0.35,
		CanCollide = false,
		Parent = portal,
	})
	local gate = part({
		Name = "Gate",
		Size = Vector3.new(17, 24, 4),
		CFrame = veil.CFrame,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = portal,
	})
	local travelTo = opts.Travel or "Rift"
	gate:SetAttribute("Travel", travelTo)
	if travelTo == "Rift" then
		gate:SetAttribute("RiftPortal", true)
	end
	local glow = opts.Glow or RIFT
	light(veil, glow, 30, 3)
	emitter(veil, UIAssets.Fx.Swirl, glow:Lerp(Color3.new(1, 1, 1), 0.5), {
		Rate = 14,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.5, 1.5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NumberRange.new(-120, -60),
	})
	emitter(veil, UIAssets.Fx.Spark, glow, {
		Rate = 20,
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
	})

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(260, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 20, 0)
	tag.MaxDistance = 140
	tag.LightInfluence = 0
	tag.Parent = gate
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Text = opts.Title or "T H E   R I F T"
	title.FontFace = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)
	title.TextSize = 30
	title.TextColor3 = glow:Lerp(Color3.new(1, 1, 1), 0.5)
	title.TextStrokeTransparency = 0.3
	title.Parent = tag
	local sub = title:Clone()
	sub.Position = UDim2.fromOffset(0, 34)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Text = opts.Subtitle or "walk through to begin your run"
	sub.FontFace = Font.new(Font.fromEnum(Enum.Font.Garamond).Family, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	sub.TextSize = 18
	sub.TextColor3 = PARCHMENT
	sub.Parent = tag
end

local function buildMonument(lobby, def, theme, c)
	part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = lobby })
	part({ Name = "PedestalTrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12.6, 12.6), CFrame = CFrame.new(c + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = BRONZE, Parent = lobby })
	local statue = prop(lobby, def.Id .. "Monument", CFrame.lookAt(c + Vector3.new(0, 2.3, 0), c + Vector3.new(0, 2.3, 10)), theme.MonumentHeight or 18)
	local crystalY = 9
	if statue then
		local cf, size = statue:GetBoundingBox()
		crystalY = cf.Position.Y + size.Y / 2 - c.Y + 6
	end
	local crystal = part({
		Name = "NationCrystal",
		Size = Vector3.new(3, 7, 3),
		CFrame = CFrame.new(c + Vector3.new(0, crystalY, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = def.Color,
		CanCollide = false,
		Parent = lobby,
	})
	crystal:SetAttribute("Spin", 20)
	light(crystal, def.Color, 40, 2.5)
	emitter(crystal, UIAssets.Fx.Glow, def.Color, { Rate = 4, Speed = NumberRange.new(0, 0.5), Size = NumberSequence.new(5), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
end

-------------------------------------------------------------------------------
-- Themed decor
-------------------------------------------------------------------------------

local function ring(c, rng, count, rMin, rMax, avoidPaths)
	local out = {}
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		-- Keep the walk from spawn (south) to portal (north) clear.
		if avoidPaths and math.abs(math.cos(a)) < 0.3 then
			a += 0.6
		end
		local r = rng:NextNumber(rMin, rMax)
		table.insert(out, { Pos = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), Angle = a })
	end
	return out
end

local Decor = {}

-- Clouds: soft balls that never collide.
local function cloud(parent, pos, size, color, transparency)
	return part({
		Name = "Cloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(pos),
		Material = Enum.Material.SmoothPlastic,
		Color = color or Color3.fromRGB(245, 248, 255),
		Transparency = transparency or 0.2,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
end

-- A natural peak built from smooth terrain: stacked balls that shrink with
-- height, with a snow cap. Returns the summit position.
local function terrainPeak(base, height, radius, rng, rock, cap, capFrom, stopAt)
	local terrain = workspace.Terrain
	local steps = math.max(6, math.floor(height / 10))
	local top
	for i = 0, steps do
		local t = i / steps
		if stopAt and t > stopAt then
			break
		end
		local r = radius * (1 - t) ^ 1.25 + 4
		local center = base + Vector3.new(rng:NextNumber(-1, 1) * radius * 0.08, height * t, rng:NextNumber(-1, 1) * radius * 0.08)
		local material = if cap and t >= capFrom then cap else rock
		terrain:FillBall(center, r, material)
		-- Rough shoulders so the slope isn't a perfect cone.
		if i % 2 == 0 and t < 0.8 then
			local a = rng:NextNumber(0, math.pi * 2)
			terrain:FillBall(center + Vector3.new(math.cos(a) * r * 0.7, 0, math.sin(a) * r * 0.7), r * 0.45, material)
		end
		top = center + Vector3.new(0, r * 0.5, 0)
	end
	return top
end

-- A big landmark (volcano, mountain, cliff) from LobbyAssets, or a stack of
-- shrinking discs/rocks when the asset is missing. Returns the top position.
local function landmark(lobby, theme, name, base, height, width, facing)
	local model = prop(lobby, name, CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z)), height)
	if model then
		model.Name = name
		local cf, size = model:GetBoundingBox()
		return Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2, cf.Position.Z), model
	end
	local tiers = 8
	for i = 0, tiers - 1 do
		local d = width * (1 - i / tiers) + 6
		disc(lobby, base + Vector3.new(0, (i + 0.5) * height / tiers, 0), d, height / tiers, theme.Rock, theme.RockColor, { Name = name .. "Tier" })
	end
	return base + Vector3.new(0, height, 0), nil
end

function Decor.Fire(lobby, def, theme, c, rng)
	-- The volcano looms behind the portal, its crater smoking and glowing.
	local terrain = workspace.Terrain
	local vBase = c + Vector3.new(0, -90, -250)
	local summit = terrainPeak(vBase, 250, 120, rng, Enum.Material.Basalt, Enum.Material.Basalt, 1, 0.78)
	-- Hollow crater with a lava floor.
	local top = Vector3.new(vBase.X, summit.Y - 6, vBase.Z)
	terrain:FillCylinder(CFrame.new(top + Vector3.new(0, 8, 0)), 24, 20, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(top - Vector3.new(0, 4, 0)), 4, 20, Enum.Material.CrackedLava)
	local crater = part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 38, 38), CFrame = CFrame.new(top - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 90, 20), CanCollide = false, Parent = lobby })
	-- Glowing lava rivers running down the face toward the island.
	for k = -1, 1 do
		local angle = math.rad(90 + k * 28)
		local prev
		for i = 0, 14 do
			local t = i / 14
			-- Drop a ray onto the slope, from just under the crater rim outward.
			local r = 24 + 100 * t
			local wobble = math.sin(i * 1.3 + k) * 0.06
			local dir = Vector3.new(math.cos(angle + wobble), 0, math.sin(angle + wobble))
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { terrain }
			local hit = workspace:Raycast(vBase + dir * r + Vector3.new(0, 400, 0), Vector3.new(0, -500, 0), params)
			local pos = if hit then hit.Position + hit.Normal * 0.4 else nil
			if not pos then
				continue
			end
			if prev then
				part({ Name = "LavaRiver", Size = Vector3.new(5 - t * 1.5, 1.2, (pos - prev).Magnitude + 1), CFrame = CFrame.lookAt((prev + pos) / 2, pos), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 100 - t * 40, 20), CanCollide = false, CastShadow = false, Parent = lobby })
			end
			prev = pos
		end
	end
	light(crater, Color3.fromRGB(255, 100, 30), 60, 6, true)
	emitter(crater, UIAssets.Fx.Smoke, Color3.fromRGB(60, 46, 44), {
		Rate = 6,
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(10, 16),
		Acceleration = Vector3.new(4, 2, 6),
		LightEmission = 0,
		SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 20), NumberSequenceKeypoint.new(1, 70) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
	})
	emitter(crater, UIAssets.Fx.Flame, Color3.fromRGB(255, 120, 40), {
		Rate = 10,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 4) }),
	})
	emitter(crater, UIAssets.Fx.Spark, Color3.fromRGB(255, 170, 70), { Rate = 25, Speed = NumberRange.new(20, 40), Acceleration = Vector3.new(0, -25, 0), SpreadAngle = Vector2.new(40, 40), Lifetime = NumberRange.new(2, 3) })

	-- Lava pools and steaming vents across the ground.
	for _, spot in ring(c, rng, 7, 46, 62, true) do
		local d = rng:NextNumber(12, 20)
		disc(lobby, spot.Pos + Vector3.new(0, 0.05, 0), d + 3, 0.5, Enum.Material.Basalt, Color3.fromRGB(28, 20, 20), { Name = "LavaRim" })
		local pool = disc(lobby, spot.Pos + Vector3.new(0, 0.25, 0), d, 0.4, Enum.Material.Neon, Color3.fromRGB(255, 96, 20), { Name = "LavaPool", CanCollide = false })
		light(pool, Color3.fromRGB(255, 110, 40), 22, 2, true)
		emitter(pool, UIAssets.Fx.Flame, Color3.fromRGB(255, 130, 40), { Rate = 5, Speed = NumberRange.new(3, 6), EmissionDirection = Enum.NormalId.Right, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.5) }) })
		emitter(pool, UIAssets.Fx.Spark, Color3.fromRGB(255, 170, 60), { Rate = 6, Speed = NumberRange.new(4, 9), Acceleration = Vector3.new(0, 4, 0), EmissionDirection = Enum.NormalId.Right })
	end
	for _, spot in ring(c, rng, 8, 56, 68, true) do
		local terrain = workspace.Terrain
		for _ = 1, 3 do
			-- Basalt boulders as parts: terrain cutting through the floor flickers.
			local size = rng:NextNumber(4, 9)
			part({ Name = "Boulder", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(spot.Pos + Vector3.new(rng:NextNumber(-4, 4), size * 0.2, rng:NextNumber(-4, 4))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Material = Enum.Material.Basalt, Color = Color3.fromRGB(44, 36, 34), Parent = lobby })
		end
		if false then
			for _ = 1, 4 do
				local h = rng:NextNumber(6, 16)
				part({ Name = "BasaltColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3.4, 3.4), CFrame = CFrame.new(spot.Pos + Vector3.new(rng:NextNumber(-3, 3), h / 2, rng:NextNumber(-3, 3))) * CFrame.Angles(0, 0, math.rad(90)), Material = theme.Rock, Color = theme.RockColor, Parent = lobby })
			end
		end
	end
	-- Embers drifting up and ash falling over the whole island.
	local air = part({ Name = "Embers", Size = Vector3.new(140, 1, 140), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(air, UIAssets.Fx.Spark, Color3.fromRGB(255, 150, 60), { Rate = 40, Speed = NumberRange.new(3, 7), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(1, 2, 0), Lifetime = NumberRange.new(3, 5), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
	local ash = part({ Name = "Ash", Size = Vector3.new(140, 1, 140), CFrame = CFrame.new(c + Vector3.new(0, 45, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(ash, UIAssets.Fx.Smoke, Color3.fromRGB(80, 70, 70), { Rate = 20, LightEmission = 0, Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Bottom, Lifetime = NumberRange.new(8, 10), Size = NumberSequence.new(0.6), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) })
end

function Decor.Earth(lobby, def, theme, c, rng)
	-- A ring of mountains rising from below the island, all around.
	for i = 1, 11 do
		local a = (i - 1) / 11 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local r = rng:NextNumber(175, 205)
		-- Peaks on the camera side (+Z) sit lower and further out so they frame
		-- the view instead of blocking it.
		local south = math.sin(a) > 0.3
		if south then
			r += 50
		end
		local base = c + Vector3.new(math.cos(a) * r, if south then -150 else -90, math.sin(a) * r)
		terrainPeak(base, rng:NextNumber(160, 230) - (if south then 40 else 0), rng:NextNumber(55, 75), rng, Enum.Material.Rock, Enum.Material.Snow, 0.72)
	end
	for _, spot in ring(c, rng, 8, 50, 64, true) do
		if not prop(lobby, "EarthTree", CFrame.new(spot.Pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(22, 30)) then
			part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 2.6, 2.6), CFrame = CFrame.new(spot.Pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 42), Parent = lobby })
			for j = 1, 3 do
				part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(8, 11), CFrame = CFrame.new(spot.Pos + Vector3.new(rng:NextNumber(-2.5, 2.5), 15 + j * 1.5, rng:NextNumber(-2.5, 2.5))), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 118, 46), Parent = lobby })
			end
		end
	end
	for _, spot in ring(c, rng, 6, 42, 56, true) do
		if not prop(lobby, "EarthBush", CFrame.new(spot.Pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(4, 6)) then
			rock(lobby, theme, CFrame.new(spot.Pos + Vector3.new(0, 2, 0)), rng:NextNumber(6, 10))
		end
	end
	-- Standing stones flanking the portal path.
	for _, x in { -14, 14 } do
		for _, z in { -20, -34 } do
			part({ Name = "StandingStone", Size = Vector3.new(3, 12, 4), CFrame = CFrame.new(c + Vector3.new(x, 6, z)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))), Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 102, 92), Parent = lobby })
		end
	end
end

function Decor.Water(lobby, def, theme, c, rng)
	-- A shallow lagoon covers the island; sand walkways lead to the spawn and
	-- the portal, with a beach left around the rim.
	local lagoon = disc(lobby, c + Vector3.new(0, 0.2, 0), 124, 0.4, Enum.Material.Glass, Color3.fromRGB(8, 62, 96), { Name = "Lagoon", Transparency = 0.3, Reflectance = 0.4 })
	disc(lobby, c + Vector3.new(0, 0.12, 0), 128, 0.3, Enum.Material.Sand, Color3.fromRGB(196, 214, 200), { Name = "Shallows" })
	for _, z in { 51, -51 } do
		part({ Name = "Walkway", Size = Vector3.new(16, 0.6, 42), CFrame = CFrame.new(c + Vector3.new(0, 0.25, z)), Material = theme.Floor, Color = theme.FloorColor, Parent = lobby })
	end
	part({ Name = "BoardIslet", Size = Vector3.new(18, 0.6, 8), CFrame = CFrame.new(c + Vector3.new(-14, 0.25, 34)), Material = theme.Floor, Color = theme.FloorColor, Parent = lobby })
	-- Ripples and glints across the water.
	local surface = part({ Name = "Ripples", Size = Vector3.new(110, 0.2, 110), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(surface, UIAssets.Fx.Ring, Color3.fromRGB(210, 240, 255), { Rate = 10, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.05, 0.1), Lifetime = NumberRange.new(2, 3), RotSpeed = NumberRange.new(0, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 6) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }) })
	emitter(surface, UIAssets.Fx.Spark, Color3.new(1, 1, 1), { Rate = 14, Speed = NumberRange.new(0, 0.2), Lifetime = NumberRange.new(0.4, 0.8), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 0) }) })
	light(lagoon, def.Color, 30, 0.6)
	-- Coral islets dotted through the lagoon.
	for _, spot in ring(c, rng, 6, 40, 56, true) do
		disc(lobby, spot.Pos + Vector3.new(0, 0.3, 0), rng:NextNumber(8, 11), 0.6, theme.Floor, theme.FloorColor, { Name = "Islet" })
		prop(lobby, "WaterCoral", CFrame.new(spot.Pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(5, 8))
	end
	-- Waterfall pouring off a cliff beyond the east rim into the lagoon.
	-- The cliff is real terrain: mossy rock with a grassy top.
	local top = terrainPeak(c + Vector3.new(92, -60, 8), 110, 30, rng, Enum.Material.Slate, Enum.Material.Grass, 0.88, 0.85)
	local fallX = 58
	local height = math.max(20, top.Y - c.Y - 6)
	local sheet = part({
		Name = "Waterfall",
		Size = Vector3.new(1, height, 12),
		CFrame = CFrame.new(c + Vector3.new(fallX, height / 2, 8)),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(140, 200, 255),
		Transparency = 0.25,
		CanCollide = false,
		Parent = lobby,
	})
	local tex = Instance.new("Texture")
	tex.Texture = UIAssets.Fx.Drop
	tex.Face = Enum.NormalId.Left
	tex.StudsPerTileU = 1.5
	tex.StudsPerTileV = 3
	tex.Transparency = 0.55
	tex.Color3 = Color3.fromRGB(235, 248, 255)
	tex:SetAttribute("Flow", 14)
	tex.Parent = sheet
	-- The cliff's top ledge the water spills from.
	part({ Name = "FallLedge", Size = Vector3.new(30, 3, 16), CFrame = CFrame.new(c + Vector3.new(fallX + 14, height + 1.5, 8)), Material = Enum.Material.Rock, Color = Color3.fromRGB(120, 130, 140), Parent = lobby })
	local lip = part({ Name = "FallLip", Size = Vector3.new(2, 1, 12), CFrame = CFrame.new(c + Vector3.new(fallX - 1, height, 8)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(lip, UIAssets.Fx.Drop, Color3.fromRGB(200, 230, 255), { Rate = 70, EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(14, 20), Acceleration = Vector3.new(-2, -30, 0), Lifetime = NumberRange.new(1.2, 1.6), SpreadAngle = Vector2.new(4, 4), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 2.4) }) })
	local splash = part({ Name = "Splash", Size = Vector3.new(10, 1, 14), CFrame = CFrame.new(c + Vector3.new(fallX - 5, 1, 8)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(splash, UIAssets.Fx.Smoke, Color3.fromRGB(235, 245, 255), { Rate = 16, LightEmission = 0.3, Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(2, 3), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }) })
	emitter(splash, UIAssets.Fx.Drop, Color3.fromRGB(170, 215, 255), { Rate = 24, Speed = NumberRange.new(6, 10), Acceleration = Vector3.new(0, -30, 0), SpreadAngle = Vector2.new(50, 50) })
	light(splash, def.Color, 28, 1.4)
	-- Fountain jets near the plaza.
	for _, x in { -40, 40 } do
		local jet = part({ Name = "Jet", Size = Vector3.one, CFrame = CFrame.new(c + Vector3.new(x, 1, -22)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
		emitter(jet, UIAssets.Fx.Drop, Color3.fromRGB(150, 210, 255), { Rate = 30, Speed = NumberRange.new(14, 18), Acceleration = Vector3.new(0, -30, 0), SpreadAngle = Vector2.new(14, 14), Lifetime = NumberRange.new(1, 1.3), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.3) }) })
	end
end

function Decor.Wind(lobby, def, theme, c, rng)
	-- Clouds hugging the rim and drifting below.
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(66, 95)
		cloud(lobby, c + Vector3.new(math.cos(a) * r, rng:NextNumber(-22, 2), math.sin(a) * r), rng:NextNumber(14, 26), nil, 0.25)
	end
	-- Small floating rocks with grass tops.
	for _, spot in ring(c, rng, 6, 85, 110, false) do
		local h = rng:NextNumber(10, 30)
		local isle = part({ Name = "FloatingRock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(spot.Pos + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Grass, Color = theme.FloorColor, Parent = lobby })
		rock(lobby, theme, isle.CFrame * CFrame.new(-4, 0, 0), 9)
	end
	for _, spot in ring(c, rng, 4, 54, 60, true) do
		if not prop(lobby, "WindMill", CFrame.new(spot.Pos) * CFrame.Angles(0, -spot.Angle - math.pi / 2, 0), 24) then
			part({ Name = "MillTower", Size = Vector3.new(4, 18, 4), CFrame = CFrame.new(spot.Pos + Vector3.new(0, 9, 0)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 120, 90), Parent = lobby })
			local hub = CFrame.lookAt(spot.Pos + Vector3.new(0, 16, 0), c + Vector3.new(0, 16, 0)) * CFrame.new(0, 0, -2.5)
			for k = 0, 3 do
				local blade = part({ Name = "Blade", Size = Vector3.new(1.2, 9, 0.3), CFrame = hub * CFrame.Angles(0, 0, math.rad(k * 90)) * CFrame.new(0, 4.5, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(235, 232, 220), Parent = lobby })
				blade:SetAttribute("MillHub", hub.Position)
			end
		end
	end
	local wisps = part({ Name = "Wisps", Size = Vector3.new(120, 1, 120), CFrame = CFrame.new(c + Vector3.new(0, 4, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	emitter(wisps, UIAssets.Fx.Swirl, def.Color, { Rate = 12, Speed = NumberRange.new(6, 10), EmissionDirection = Enum.NormalId.Right, Lifetime = NumberRange.new(2, 3), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
end

function Decor.Lightning(lobby, def, theme, c, rng)
	-- A sea of clouds the island floats in, thick around the rim and below.
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, 140)
		local s = rng:NextNumber(20, 42)
		-- Near the rim, keep the tops just under the floor so the plaza stays clear.
		local y = if r < 82 then -s / 2 - rng:NextNumber(0.5, 6) else rng:NextNumber(-26, -4) - (r - 60) * 0.15
		cloud(lobby, c + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), s, if rng:NextNumber() < 0.3 then Color3.fromRGB(205, 210, 228) else nil, rng:NextNumber(0.05, 0.25))
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 60)
		local s = rng:NextNumber(30, 50)
		cloud(lobby, c + Vector3.new(math.cos(a) * r, -s / 2 - rng:NextNumber(4, 16), math.sin(a) * r), s, Color3.fromRGB(225, 230, 245), 0.1)
	end
	-- Marble columns with gold capitals around the plaza: a sky temple.
	for _, spot in ring(c, rng, 10, 50, 50, true) do
		local h = 18
		part({ Name = "ColumnBase", Size = Vector3.new(4.4, 1, 4.4), CFrame = CFrame.new(spot.Pos + Vector3.new(0, 0.5, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(236, 236, 240), Parent = lobby })
		part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3.2, 3.2), CFrame = CFrame.new(spot.Pos + Vector3.new(0, 1 + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = Color3.fromRGB(236, 236, 240), Parent = lobby })
		local cap = part({ Name = "Capital", Size = Vector3.new(4.4, 1.2, 4.4), CFrame = CFrame.new(spot.Pos + Vector3.new(0, 1.6 + h, 0)), Material = Enum.Material.Metal, Color = GOLD, Parent = lobby })
		local spark = part({ Name = "ColumnSpark", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = cap.CFrame * CFrame.new(0, 1.6, 0), Material = Enum.Material.Neon, Color = def.Color, CanCollide = false, Parent = lobby })
		light(spark, def.Color, 16, 1.5, true)
		emitter(spark, UIAssets.Fx.Lightning, def.Color, { Rate = 3, Lifetime = NumberRange.new(0.1, 0.2), Speed = NumberRange.new(0, 0), Size = NumberSequence.new(3), Transparency = NumberSequence.new(0) })
	end
	-- A storm cloud over the plaza; the client throws bolts out of it.
	for i = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 44)
		local storm = cloud(lobby, c + Vector3.new(math.cos(a) * r, rng:NextNumber(58, 68), math.sin(a) * r), rng:NextNumber(20, 32), Color3.fromRGB(70, 66, 92), 0.2)
		storm.Name = "StormCloud"
		if i % 4 == 0 then
			light(storm, def.Color, 50, 0, true):SetAttribute("Strike", true)
		end
	end
end

-------------------------------------------------------------------------------

-- Realistic AI-generated MaterialVariants (MaterialService, place-only). Parts
-- keep their base material when a variant is missing.
local function applyVariants(lobby, theme)
	local MaterialService = game:GetService("MaterialService")
	-- Finds "name" or a regenerated "name_<n>" variant.
	local function find(name)
		if not name then
			return nil
		end
		for _, v in MaterialService:GetDescendants() do
			if v:IsA("MaterialVariant") and (v.Name == name or v.Name:match("^" .. name .. "_%d+$")) then
				return v.Name
			end
		end
		return nil
	end
	for _, p in lobby:GetDescendants() do
		if not p:IsA("BasePart") or p:IsA("MeshPart") then
			continue
		end
		local name
		if p.Material == theme.Floor and p.Color == theme.FloorColor then
			name = theme.FloorVariant
		elseif p.Material == theme.Plaza and p.Color == theme.PlazaColor then
			name = theme.PlazaVariant
		elseif p.Material == Enum.Material.Basalt and p.Color == OBSIDIAN then
			name = "rift_obsidian"
		elseif p.Material == Enum.Material.Metal and p.Color == BRONZE then
			name = "rift_bronze"
		end
		local found = find(name)
		if found then
			p.MaterialVariant = found
		end
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- The Crossroads: the main lobby every nation shares
-------------------------------------------------------------------------------

LobbyBuilder.HubCenter = Vector3.new(0, 150, 3500)

local HUB_THEME = {
	Radius = 100,
	SpawnZ = 74,
	TerrainRock = Enum.Material.Slate,
	FloorVariant = "earth_flagstone", PlazaVariant = "rift_obsidian",
	Floor = Enum.Material.Cobblestone, FloorColor = Color3.fromRGB(150, 142, 132),
	Plaza = Enum.Material.Basalt, PlazaColor = OBSIDIAN,
	Rock = Enum.Material.Slate, RockColor = Color3.fromRGB(90, 86, 96),
	Particle = UIAssets.Fx.Spark,
}
local HUB_DEF = { Id = "Crossroads", Name = "The Crossroads", Color = RIFT, Deep = Color3.fromRGB(40, 20, 80) }

-- Tidy a lobby: drop decor that landed where a gate now stands.
local KEEP = { Island = true, Spawn = true, SpawnGlow = true, NationBoard = true, RiftPortal = true, CrossroadsGate = true, HomeGate = true }
local function clearAround(lobby, pos, radius)
	for _, child in lobby:GetChildren() do
		if KEEP[child.Name] then
			continue
		end
		local at = if child:IsA("Model") then child:GetPivot().Position elseif child:IsA("BasePart") then child.Position else nil
		if at and (Vector3.new(at.X, pos.Y, at.Z) - pos).Magnitude < radius then
			child:Destroy()
		end
	end
end

local function billboard(parent, title, subtitle, color, height)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(280, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	tag.MaxDistance = 120
	tag.LightInfluence = 0
	tag.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 32)
	t.Text = title
	t.FontFace = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)
	t.TextSize = 28
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Parent = tag
	local s = t:Clone()
	s.Position = UDim2.fromOffset(0, 32)
	s.Size = UDim2.new(1, 0, 0, 20)
	s.Text = subtitle
	s.FontFace = Font.new(Font.fromEnum(Enum.Font.Garamond).Family, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	s.TextSize = 18
	s.TextColor3 = PARCHMENT
	s.Parent = tag
	return tag
end

-- A market stall with its keeper and a prompt that opens the market screen.
local function buildStall(hub, c, offset, market, title, subtitle, cloth)
	local at = c + offset
	local base = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
	local stall = Instance.new("Model")
	stall.Name = market .. "Stall"
	stall.Parent = hub
	if not prop(stall, "MarketStall", base, 15) then
		part({ Name = "Counter", Size = Vector3.new(14, 3.6, 3), CFrame = base * CFrame.new(0, 1.8, -1), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 76, 50), Parent = stall })
		for _, x in { -7, 7 } do
			for _, z in { -1, 6 } do
				part({ Name = "Post", Size = Vector3.new(0.8, 11, 0.8), CFrame = base * CFrame.new(x, 5.5, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 62, 40), Parent = stall })
			end
		end
		part({ Name = "Awning", Size = Vector3.new(16, 0.4, 10), CFrame = base * CFrame.new(0, 11.3, 2.5) * CFrame.Angles(math.rad(-12), 0, 0), Material = Enum.Material.Fabric, Color = cloth, Parent = stall })
	end
	-- The keeper stands behind the counter, facing the plaza.
	if not prop(stall, market .. "Keeper", base * CFrame.new(0, 0, 3.5), 7) then
		part({ Name = "KeeperBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 2.6, 2.6), CFrame = base * CFrame.new(0, 2.5, 3.5) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Fabric, Color = cloth, Parent = stall })
		part({ Name = "KeeperHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = base * CFrame.new(0, 5.8, 3.5), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(214, 170, 130), Parent = stall })
	end
	prop(stall, "MarketCrates", base * CFrame.new(-10, 0, 1) * CFrame.Angles(0, math.rad(20), 0), 4.5)
	prop(stall, "MarketCrates", base * CFrame.new(10, 0, 2) * CFrame.Angles(0, math.rad(-35), 0), 4)
	local lamp = part({ Name = "StallLamp", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 9.5, -2), Material = Enum.Material.Neon, Color = GOLD, CanCollide = false, Parent = stall })
	light(lamp, Color3.fromRGB(255, 200, 140), 22, 1.6, true)
	-- What players walk up to.
	local counter = part({ Name = "MarketPrompt", Size = Vector3.new(14, 6, 4), CFrame = base * CFrame.new(0, 3, -3), Transparency = 1, CanCollide = false, Parent = stall })
	counter:SetAttribute("Market", market)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if market == "Shop" then "Browse" else "Trade"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	billboard(counter, title, subtitle, GOLD, 12)
end

function LobbyBuilder.BuildHub()
	local c = LobbyBuilder.HubCenter
	local theme = HUB_THEME
	local rng = Random.new(4242)
	local hub = Instance.new("Model")
	hub.Name = "Crossroads"
	hub:SetAttribute("Center", c)
	hub:SetAttribute("Hub", true)
	workspace.Terrain:FillBlock(CFrame.new(c + Vector3.new(0, 20, 0)), Vector3.new(680, 420, 680), Enum.Material.Air)
	buildIsland(hub, HUB_DEF, theme, c, rng)
	buildSpawn(hub, HUB_DEF, theme, c)

	-- The heart of the plaza: an obsidian dais under a huge floating rift crystal.
	part({ Name = "Dais", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 22, 22), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = hub })
	part({ Name = "DaisTrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 23, 23), CFrame = CFrame.new(c + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = BRONZE, Parent = hub })
	local heart = part({ Name = "RiftHeart", Size = Vector3.new(6, 16, 6), CFrame = CFrame.new(c + Vector3.new(0, 16, 0)) * CFrame.Angles(0, math.rad(45), 0), Material = Enum.Material.Neon, Color = RIFT, CanCollide = false, Parent = hub })
	heart:SetAttribute("Spin", 15)
	light(heart, RIFT, 60, 3)
	emitter(heart, UIAssets.Fx.Swirl, RIFT_HOT, { Rate = 8, Speed = NumberRange.new(0.5, 1), Lifetime = NumberRange.new(2, 3), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }) })
	emitter(heart, UIAssets.Fx.Spark, RIFT, { Rate = 16, Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(180, 180) })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local shard = part({ Name = "HeartShard", Size = Vector3.new(1.6, 4, 1.6), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 9, 14 + (k % 2) * 4, math.sin(a) * 9)) * CFrame.Angles(0, a, math.rad(20)), Material = Enum.Material.Neon, Color = RIFT_HOT, CanCollide = false, Parent = hub })
		shard:SetAttribute("Spin", 40 + k * 5)
	end

	-- A banner for each nation in a ring around the dais.
	for i, id in Nations.Order do
		local def = Nations.Defs[id]
		local a = math.rad(-90 + (i - 3) * 36) -- fanned across the north half
		local at = c + Vector3.new(math.cos(a) * 34, 0, math.sin(a) * 34)
		local face = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
		part({ Name = "BannerBase", Size = Vector3.new(3, 1, 3), CFrame = face * CFrame.new(0, 0.5, 0), Material = Enum.Material.Basalt, Color = OBSIDIAN, Parent = hub })
		part({ Name = "BannerPole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 0.8, 0.8), CFrame = face * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = BRONZE, Parent = hub })
		part({ Name = "BannerBar", Size = Vector3.new(8, 0.5, 0.5), CFrame = face * CFrame.new(0, 21, -0.6), Material = Enum.Material.Metal, Color = BRONZE, Parent = hub })
		local cloth = part({ Name = "BannerCloth", Size = Vector3.new(7, 12, 0.2), CFrame = face * CFrame.new(0, 14.8, -0.7), Material = Enum.Material.Fabric, Color = def.Color:Lerp(def.Deep, 0.35), Parent = hub })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.4
		gui.Parent = cloth
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.fromScale(0.5, 0.08)
		img.Size = UDim2.fromScale(0.8, 0.46)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = ({ Fire = UIAssets.Icons.Fireball, Earth = UIAssets.Icons.StoneSpike, Water = UIAssets.Icons.TidalWave, Wind = UIAssets.Icons.Gust, Lightning = UIAssets.Icons.ChainShock })[id]
		img.Parent = gui
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.05, 0.6)
		name.Size = UDim2.fromScale(0.9, 0.3)
		name.Text = def.Name
		name.TextScaled = true
		name.TextWrapped = true
		name.FontFace = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)
		name.TextColor3 = GOLD
		name.Parent = gui
		local flame = part({ Name = "BannerFlame", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = face * CFrame.new(0, 22.6, 0), Material = Enum.Material.Neon, Color = def.Color, CanCollide = false, Parent = hub })
		light(flame, def.Color, 16, 1.2, true)
	end

	-- One gate, north, home to your nation's lobby.
	buildPortal(hub, { Color = GOLD }, c, {
		Offset = Vector3.new(0, 0, -84),
		Travel = "Nation",
		Name = "HomeGate",
		Title = "Y O U R   N A T I O N",
		Subtitle = "return to your nation's lobby",
		Veil = Color3.fromRGB(150, 104, 40),
		Glow = GOLD,
	})

	-- The market on the east side.
	buildStall(hub, c, Vector3.new(66, 0, -26), "Shop", "The Rift Shop", "flasks, tomes and materials", Color3.fromRGB(120, 60, 160))
	buildStall(hub, c, Vector3.new(66, 0, 26), "Merchant", "Goods Merchant", "sells gold for your loot", Color3.fromRGB(160, 110, 40))

	-- Paved paths from the plaza to each gate, the stalls and the arrival pad.
	local pathColor = Color3.fromRGB(96, 88, 84)
	for _, target in { Vector3.new(0, 0, -76), Vector3.new(56, 0, 0), Vector3.new(0, 0, 68) } do
		local from = c + target.Unit * 33
		local to = c + target
		part({ Name = "Path", Size = Vector3.new(12, 0.3, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to) + Vector3.new(0, 0.15, 0), Material = Enum.Material.Slate, Color = pathColor, Parent = hub })
	end
	part({ Name = "MarketSquare", Size = Vector3.new(26, 0.3, 82), CFrame = CFrame.new(c + Vector3.new(62, 0.16, 0)), Material = Enum.Material.Slate, Color = pathColor, Parent = hub })
	-- Benches and planters between the paths.
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		local at = c + Vector3.new(math.cos(a) * 48, 0, math.sin(a) * 48)
		local face = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
		if k % 2 == 0 then
			part({ Name = "BenchSeat", Size = Vector3.new(8, 0.6, 2.4), CFrame = face * CFrame.new(0, 1.9, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 76, 50), Parent = hub })
			part({ Name = "BenchBack", Size = Vector3.new(8, 2, 0.4), CFrame = face * CFrame.new(0, 3.1, 1.1) * CFrame.Angles(math.rad(-10), 0, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 76, 50), Parent = hub })
			for _, x in { -3.4, 3.4 } do
				part({ Name = "BenchLeg", Size = Vector3.new(0.5, 1.6, 2.2), CFrame = face * CFrame.new(x, 0.8, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 36, 44), Parent = hub })
			end
		else
			part({ Name = "Planter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 7, 7), CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(120, 112, 104), Parent = hub })
			part({ Name = "PlanterSoil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6, 6), CFrame = CFrame.new(at + Vector3.new(0, 2.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 110, 50), Parent = hub })
			prop(hub, "EarthTree", CFrame.new(at + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, k, 0), 12)
		end
	end

	-- Lamp posts around the edge, trees between them.
	for k = 0, 13 do
		local a = (k + 0.5) / 14 * math.pi * 2
		local at = c + Vector3.new(math.cos(a) * 90, 0, math.sin(a) * 90)
		part({ Name = "LampPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 0.7, 0.7), CFrame = CFrame.new(at + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 36, 44), Parent = hub })
		local lamp = part({ Name = "Lamp", Size = Vector3.new(1.6, 2, 1.6), CFrame = CFrame.new(at + Vector3.new(0, 12.6, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 140), CanCollide = false, Parent = hub })
		light(lamp, Color3.fromRGB(255, 196, 130), 24, 1.4, true)
		if k % 2 == 0 then
			local ta = a + math.pi / 14
			prop(hub, "EarthTree", CFrame.new(c + Vector3.new(math.cos(ta) * 94, 0, math.sin(ta) * 94)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(20, 26))
		end
	end
	for _, gate in { Vector3.new(0, 0, -84), Vector3.new(66, 0, -26), Vector3.new(66, 0, 26) } do
		for _, child in hub:GetChildren() do
			if child.Name == "EarthTree" and ((child:GetPivot().Position - (c + gate)) * Vector3.new(1, 0, 1)).Magnitude < 22 then
				child:Destroy()
			end
		end
	end

	applyVariants(hub, theme)
	return hub
end

function LobbyBuilder.Center(index)
	return Vector3.new((index - 3) * LobbyBuilder.Spacing, LobbyBuilder.Height, LobbyBuilder.Z)
end

function LobbyBuilder.Build(id, index)
	local def = Nations.Defs[id]
	local theme = THEMES[id]
	local c = LobbyBuilder.Center(index)
	local rng = Random.new(index * 7919)
	local lobby = Instance.new("Model")
	lobby.Name = id
	lobby:SetAttribute("Nation", id)
	lobby:SetAttribute("Center", c)
	-- Clear terrain (Water's ponds) left by an earlier build.
	workspace.Terrain:FillBlock(CFrame.new(c + Vector3.new(0, 20, 0)), Vector3.new(680, 420, 680), Enum.Material.Air)
	buildIsland(lobby, def, theme, c, rng)
	buildSpawn(lobby, def, theme, c)
	buildBoard(lobby, def, c)
	-- The lobby's rift gate leads to the Crossroads, the main lobby every
	-- nation shares. Training in the Rift starts from the menu's Play button.
	buildPortal(lobby, def, c, {
		Travel = "Crossroads",
		Title = "T H E   C R O S S R O A D S",
		Subtitle = "the main lobby · every nation meets here",
	})
	buildMonument(lobby, def, theme, c)
	Decor[id](lobby, def, theme, c, rng)
	applyVariants(lobby, theme)
	return lobby
end

-- Builds every lobby that's missing. `rebuild` replaces existing ones.
function LobbyBuilder.BuildAll(rebuild)
	local folder = workspace:FindFirstChild("NationLobbies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NationLobbies"
		folder.Parent = workspace
	end
	for i, id in Nations.Order do
		local existing = folder:FindFirstChild(id)
		if existing and rebuild then
			existing:Destroy()
			existing = nil
		end
		if not existing then
			LobbyBuilder.Build(id, i).Parent = folder
		end
	end
	local hub = folder:FindFirstChild("Crossroads")
	if hub and rebuild then
		hub:Destroy()
		hub = nil
	end
	if not hub then
		LobbyBuilder.BuildHub().Parent = folder
	end
	return folder
end

-- Building blocks shared with StoryBuilder (story arenas).
LobbyBuilder.Lib = {
	part = part, disc = disc, emitter = emitter, light = light, prop = prop, rock = rock,
	ring = ring, cloud = cloud, terrainPeak = terrainPeak, buildIsland = buildIsland,
	buildPortal = buildPortal, billboard = billboard, applyVariants = applyVariants,
	Themes = THEMES, Decor = Decor,
	Colors = { Rift = RIFT, RiftHot = RIFT_HOT, Obsidian = OBSIDIAN, Bronze = BRONZE, Gold = GOLD, Parchment = PARCHMENT },
}

return LobbyBuilder
