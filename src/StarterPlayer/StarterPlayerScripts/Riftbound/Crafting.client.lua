-- Redesigned Crafting and Skill Awakening Client UI for Riftbound.
-- Option 2: Sleek Minimalist ARPG (Hades / Modern Stylized Action RPG Style)
-- Features:
--   • Ultra-clean dark frosted glass panels with razor-sharp elemental neon accents
--   • Left recipe gallery with high-contrast elemental colored borders and [ ELEMENT ] corner badges
--   • Top capsule/pill tabs with smooth glowing accent borders
--   • Fusion formula linked by luminous elemental energy beams and a glowing geometric catalyst core
--   • Horizontal requirements section with REAL modern progress bars (0/4, 2/4, 4/4 fill)
--   • High-impact vibrant gradient action button (Fiery Orange to Electric Cyan)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Theme = require(Shared:WaitForChild("Theme"))
local Crafting = require(Shared:WaitForChild("Crafting"))
local Skills = require(Shared:WaitForChild("Skills"))
local Items = require(Shared:WaitForChild("Items"))
local Elements = require(Shared:WaitForChild("Elements"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local remotes = Shared:WaitForChild("Remotes")
local OpenForge = remotes:WaitForChild("OpenForge")
local OpenAwakening = remotes:WaitForChild("OpenAwakening")
local CraftSkill = remotes:WaitForChild("CraftSkill")
local AwakenSkill = remotes:WaitForChild("AwakenSkill")
local GetBuild = remotes:WaitForChild("GetBuild")
local GetInventory = remotes:WaitForChild("GetInventory")
local BuildChanged = remotes:WaitForChild("BuildChanged")
local InventoryChanged = remotes:WaitForChild("InventoryChanged")
local TestEquipSkill = remotes:WaitForChild("TestEquipSkill")

local player = Players.LocalPlayer
local C = Theme.C
local F = Theme.F

-------------------------------------------------------------------------------
-- Neon Elemental Color Palette
-------------------------------------------------------------------------------
local NeonColors = {
	Fire = Color3.fromRGB(255, 110, 35),
	Water = Color3.fromRGB(40, 200, 255),
	Earth = Color3.fromRGB(230, 165, 50),
	Wind = Color3.fromRGB(50, 230, 165),
	Lightning = Color3.fromRGB(185, 105, 255),
	Rift = Color3.fromRGB(195, 115, 255),
	Gold = Color3.fromRGB(255, 200, 50),
}

local function getSkillElement(skillId)
	local def = skillId and Skills.Defs[skillId]
	if def and def.Elements and def.Elements[1] then
		return def.Elements[1]
	end
	return "Rift"
end

local function getSkillColor(skillId)
	local elem = getSkillElement(skillId)
	return NeonColors[elem] or Color3.fromRGB(180, 170, 210)
end

local ItemNeonColors = {
	FireShard = Color3.fromRGB(255, 110, 35),
	WaterShard = Color3.fromRGB(40, 200, 255),
	EarthShard = Color3.fromRGB(230, 165, 50),
	WindShard = Color3.fromRGB(50, 230, 165),
	LightningShard = Color3.fromRGB(185, 105, 255),
	EmberCore = Color3.fromRGB(255, 120, 40),
	AbyssalPearl = Color3.fromRGB(50, 205, 255),
	GraniteCore = Color3.fromRGB(230, 165, 50),
	ZephyrCore = Color3.fromRGB(50, 230, 165),
	VoltCore = Color3.fromRGB(185, 105, 255),
	FireEssence = Color3.fromRGB(255, 130, 45),
	WaterEssence = Color3.fromRGB(65, 210, 255),
	EarthEssence = Color3.fromRGB(240, 175, 60),
	WindEssence = Color3.fromRGB(60, 240, 175),
	LightningEssence = Color3.fromRGB(200, 120, 255),
	RiftShard = Color3.fromRGB(190, 110, 255),
	HuskIchor = Color3.fromRGB(140, 230, 110),
	Gold = Color3.fromRGB(255, 200, 50),
}

-------------------------------------------------------------------------------
-- Helper Constructors
-------------------------------------------------------------------------------
local function new(class, props, children)
	local inst = Instance.new(class)
	-- Strokes outline the box, never the text (the default "Contextual" mode
	-- put a coloured glow around button text and made it hard to read).
	if class == "UIStroke" and props.ApplyStrokeMode == nil then
		inst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function text(props)
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or F.Body
	props.TextColor3 = props.TextColor3 or C.Text
	props.TextSize = props.TextSize or 14
	return new("TextLabel", props)
end

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local currentTab = "Forge" -- "Forge" or "Awaken"
local BaseOrder = { "Fireball", "TidalWave", "StoneSpike", "Gust", "SparkBolt" } -- the Base tab's list
local selectedId = nil
local searchQuery = ""
local cachedBuild = { Skills = {}, Slots = {} }
local cachedInventory = {}

-------------------------------------------------------------------------------
-- UI Container & Textured Obsidian Basalt Frame
-------------------------------------------------------------------------------
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("RiftboundCrafting")
if oldGui then
	oldGui:Destroy()
end

local gui = new("ScreenGui", {
	Name = "RiftboundCrafting",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 42,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local shade = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(6, 5, 8),
	BackgroundTransparency = 0.45,
	Text = "",
	AutoButtonColor = false,
	Parent = gui,
})

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1080, 690),
	BackgroundColor3 = Color3.fromRGB(16, 16, 20),
	BorderSizePixel = 0,
	ClipsDescendants = false,
	Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", {
		Color = Color3.fromRGB(58, 50, 42),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}),
	new("UIScale", {}),
})

local panelScale = panel:FindFirstChildOfClass("UIScale")
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera and panelScale then
		local vp = camera.ViewportSize
		if vp.X > 0 and vp.Y > 0 then
			local scale = math.clamp(math.min(vp.X / 1140, vp.Y / 740), 0.65, 1.05)
			panelScale.Scale = scale
		end
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- Subtle Dark Vignette for edge depth
local panelVignette = new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = UIAssets.Vignette,
	ImageTransparency = 0.55,
	ZIndex = 1,
	Parent = panel,
})

-- Subtle Dark Stone Grit
local panelGrain = new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = UIAssets.Grain,
	ImageTransparency = 0.9,
	TileSize = UDim2.fromOffset(256, 256),
	ScaleType = Enum.ScaleType.Tile,
	ZIndex = 1,
	Parent = panel,
})

-------------------------------------------------------------------------------
-- Header Section (Option 1: Dark Fantasy Plaque)
-------------------------------------------------------------------------------
local header = new("Frame", {
	Size = UDim2.new(1, 0, 0, 66),
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = panel,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
})

local headerDivider = new("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Color3.fromRGB(55, 48, 40),
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = header,
})

-- Left: Flaming Anvil Icon
local headerIconContainer = new("Frame", {
	Position = UDim2.fromOffset(18, 8),
	Size = UDim2.fromOffset(50, 50),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = header,
})

local headerAura = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(64, 64),
	BackgroundTransparency = 1,
	Image = UIAssets.Fx.Glow,
	ImageColor3 = Color3.fromRGB(255, 120, 30),
	ImageTransparency = 0.35,
	ZIndex = 3,
	Parent = headerIconContainer,
})

local headerIcon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.9),
	BackgroundTransparency = 1,
	Image = UIAssets.Menu.Forge or "rbxassetid://132527579649611",
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
	Parent = headerIconContainer,
})

-- Center: Golden Carved Plaque Cartouche
local titlePlaque = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.fromOffset(260, 40),
	BackgroundColor3 = Color3.fromRGB(26, 24, 28),
	ZIndex = 3,
	Parent = header,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", {
		Color = Color3.fromRGB(165, 125, 60),
		Thickness = 1.5,
	}),
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 28, 26)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 22, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 28, 26)),
		}),
	}),
})

local titleLabel = text({
	Size = UDim2.fromScale(1, 1),
	FontFace = F.TitleBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 220, 130),
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "THE FORGE",
	ZIndex = 4,
	Parent = titlePlaque,
}, {
	new("UIStroke", {
		Color = Color3.fromRGB(35, 20, 10),
		Thickness = 1.5,
	}),
})

local subtitleLabel = text({
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	Parent = header,
})

-- Right: Close Button
local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = Color3.fromRGB(38, 20, 24),
	Text = "X",
	TextColor3 = Color3.fromRGB(220, 190, 190),
	TextSize = 16,
	FontFace = F.Bold,
	ZIndex = 3,
	Parent = header,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = Color3.fromRGB(130, 50, 60), Thickness = 1 }),
})

closeBtn.MouseEnter:Connect(function()
	tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(75, 25, 35) })
	closeBtn.UIStroke.Color = Color3.fromRGB(240, 70, 85)
	closeBtn.TextColor3 = Color3.fromRGB(255, 230, 235)
end)
closeBtn.MouseLeave:Connect(function()
	tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(38, 20, 24) })
	closeBtn.UIStroke.Color = Color3.fromRGB(130, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(220, 190, 190)
end)

-------------------------------------------------------------------------------
-- Tabs (Option 1: Dark Fantasy Inset Tabs)
-------------------------------------------------------------------------------
local tabRow = new("Frame", {
	Position = UDim2.fromOffset(24, 76),
	Size = UDim2.new(1, -48, 0, 34),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = panel,
})

local SkillsCatalog = {
	All = {
		"Fireball", "TidalWave", "StoneSpike", "Gust", "SparkBolt",
		"SteamCloud", "MagmaBurst", "Firestorm", "PlasmaLance", "MudTrap",
		"FrostGale", "ChainShock", "Sandstorm", "MagnetQuake", "Thunderstorm",
		"FireballAwakened", "TidalWaveAwakened", "StoneSpikeAwakened", "GustAwakened", "SparkBoltAwakened",
	},
	Base = {
		"Fireball", "TidalWave", "StoneSpike", "Gust", "SparkBolt",
	},
	Forge = {
		"SteamCloud", "MagmaBurst", "Firestorm", "PlasmaLance", "MudTrap",
		"FrostGale", "ChainShock", "Sandstorm", "MagnetQuake", "Thunderstorm",
	},
	Awaken = {
		"FireballAwakened", "TidalWaveAwakened", "StoneSpikeAwakened", "GustAwakened", "SparkBoltAwakened",
	},
}

local tabAll = new("TextButton", {
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(0.25, -4, 1, 0),
	BackgroundColor3 = Color3.fromRGB(26, 24, 28),
	Text = `ALL SKILLS ({5 + #Crafting.ForgeOrder + #Crafting.AwakenOrder})`,
	TextColor3 = Color3.fromRGB(255, 195, 110),
	TextSize = 12,
	FontFace = F.Bold,
	ZIndex = 3,
	Parent = tabRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = Color3.fromRGB(180, 120, 50), Thickness = 1.5 }),
})

local tabBase = new("TextButton", {
	Position = UDim2.new(0.25, 2, 0, 0),
	Size = UDim2.new(0.25, -4, 1, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Text = "BASE (5)",
	TextColor3 = Color3.fromRGB(140, 145, 160),
	TextSize = 12,
	FontFace = F.Bold,
	ZIndex = 3,
	Parent = tabRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = Color3.fromRGB(45, 44, 48), Thickness = 1 }),
})

local tabForge = new("TextButton", {
	Position = UDim2.new(0.50, 4, 0, 0),
	Size = UDim2.new(0.25, -4, 1, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Text = "FUSIONS (10)",
	TextColor3 = Color3.fromRGB(140, 145, 160),
	TextSize = 12,
	FontFace = F.Bold,
	ZIndex = 3,
	Parent = tabRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = Color3.fromRGB(45, 44, 48), Thickness = 1 }),
})

local tabAwaken = new("TextButton", {
	Position = UDim2.new(0.75, 6, 0, 0),
	Size = UDim2.new(0.25, -6, 1, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Text = `AWAKENED ({#Crafting.AwakenOrder})`,
	TextColor3 = Color3.fromRGB(140, 145, 160),
	TextSize = 12,
	FontFace = F.Bold,
	ZIndex = 3,
	Parent = tabRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = Color3.fromRGB(45, 44, 48), Thickness = 1 }),
})

-------------------------------------------------------------------------------
-- Main Body: Left Panel & Right Panel
-------------------------------------------------------------------------------
local body = new("Frame", {
	Position = UDim2.fromOffset(24, 126),
	Size = UDim2.new(1, -48, 1, -144),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = panel,
})

-- Left Panel: Recipe Browser (Basalt Chamber)
local leftPanel = new("Frame", {
	Size = UDim2.new(0.36, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(18, 16, 22),
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = body,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 6) }),
	new("UIStroke", { Color = Color3.fromRGB(80, 65, 55), Thickness = 1.5 }),
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 22, 28)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 12, 16)),
		}),
		Rotation = 45,
	}),
})

-- Search Bar
local searchBoxFrame = new("Frame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 0, 36),
	BackgroundColor3 = Color3.fromRGB(24, 20, 26),
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = leftPanel,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = Color3.fromRGB(85, 68, 55), Thickness = 1 }),
})

local searchInput = new("TextBox", {
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -24, 1, 0),
	BackgroundTransparency = 1,
	FontFace = F.Body,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(245, 245, 255),
	PlaceholderText = "Search skills or elements...",
	PlaceholderColor3 = Color3.fromRGB(140, 130, 125),
	ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	ZIndex = 4,
	Parent = searchBoxFrame,
})

local listScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 52),
	Size = UDim2.new(1, -16, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Color3.fromRGB(120, 95, 65),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 3,
	Parent = leftPanel,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(168, 126),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

-------------------------------------------------------------------------------
-- Right Panel: Altar & Requirements (Molten Crucible Chamber)
-------------------------------------------------------------------------------
local rightPanel = new("Frame", {
	Position = UDim2.new(0.38, 0, 0, 0),
	Size = UDim2.new(0.62, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(16, 13, 18),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = body,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 6) }),
	new("UIStroke", { Color = Color3.fromRGB(95, 75, 55), Thickness = 1.5 }),
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 18, 22)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 10, 14)),
		}),
		Rotation = 90,
	}),
})

-------------------------------------------------------------------------------
-- Top Row: Result Skill Showcase Banner (Dark Fantasy Cartouche)
-------------------------------------------------------------------------------
local resultBanner = new("Frame", {
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.new(1, -24, 0, 122),
	BackgroundColor3 = Color3.fromRGB(22, 22, 28),
	ZIndex = 3,
	Parent = rightPanel,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = Color3.fromRGB(75, 62, 50), Thickness = 1.2 }),
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 26, 32)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 17, 22)),
		}),
		Rotation = 90,
	}),
})

local resultAura = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(62, 61),
	Size = UDim2.fromOffset(140, 140),
	BackgroundTransparency = 1,
	Image = UIAssets.Fx.Glow,
	ImageColor3 = Color3.fromRGB(255, 140, 40),
	ImageTransparency = 0.55,
	ZIndex = 3,
	Parent = resultBanner,
})

local resultIcon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(108, 108),
	BackgroundTransparency = 1,
	Image = UIAssets.Icons.Empty,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
	Parent = resultBanner,
})

local resultTitle = text({
	Position = UDim2.fromOffset(128, 12),
	Size = UDim2.new(1, -138, 0, 28),
	FontFace = F.TitleBold,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 218, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Result Skill",
	ZIndex = 4,
	Parent = resultBanner,
})

local resultDesc = text({
	Position = UDim2.fromOffset(128, 44),
	Size = UDim2.new(1, -138, 0, 40),
	FontFace = F.Body,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(225, 230, 245),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "Description",
	ZIndex = 4,
	Parent = resultBanner,
})

local statusText = text({
	Position = UDim2.fromOffset(128, 88),
	Size = UDim2.new(1, -138, 0, 22),
	FontFace = F.Bold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(70, 230, 190),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "TYPE: ZONE • Applies Burn & Slow",
	ZIndex = 4,
	Parent = resultBanner,
})

-------------------------------------------------------------------------------
-- Middle Row: Formula Section (Skill 1 + Skill 2)
-------------------------------------------------------------------------------
local formulaCard = new("Frame", {
	Position = UDim2.fromOffset(12, 142),
	Size = UDim2.new(1, -24, 0, 150),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = rightPanel,
})

local formulaLabel = text({
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	Parent = formulaCard,
})

-- Connecting Energy Beams behind skills and + connector
local energyBeamLeft = new("Frame", {
	Position = UDim2.new(0.24, 0, 0, 45),
	Size = UDim2.new(0.20, 0, 0, 2),
	BackgroundColor3 = Color3.fromRGB(255, 120, 40),
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = formulaCard,
}, {
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 210, 80)),
		}),
	}),
})

local energyBeamRight = new("Frame", {
	Position = UDim2.new(0.56, 0, 0, 45),
	Size = UDim2.new(0.20, 0, 0, 2),
	BackgroundColor3 = Color3.fromRGB(40, 200, 255),
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = formulaCard,
}, {
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 200, 255)),
		}),
	}),
})

-- Center + Connector Symbol
local plusLabel = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 45),
	Size = UDim2.fromOffset(40, 40),
	FontFace = F.TitleBold,
	TextSize = 32,
	TextColor3 = Color3.fromRGB(255, 215, 110),
	Text = "+",
	ZIndex = 5,
	Parent = formulaCard,
}, {
	new("UIStroke", {
		Color = Color3.fromRGB(30, 20, 15),
		Thickness = 2,
	}),
})

-- Skill 1 Hero
local s1Box = new("Frame", {
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(0.46, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = formulaCard,
})

local s1Glow = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 45),
	Size = UDim2.fromOffset(110, 110),
	BackgroundTransparency = 1,
	Image = UIAssets.Fx.Glow,
	ImageColor3 = Color3.fromRGB(255, 110, 35),
	ImageTransparency = 0.5,
	ZIndex = 3,
	Parent = s1Box,
})

local s1Icon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(90, 90),
	BackgroundTransparency = 1,
	Image = UIAssets.Icons.Empty,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
	Parent = s1Box,
})

local s1Name = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 94),
	Size = UDim2.new(1, 0, 0, 16),
	FontFace = F.Bold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "Skill 1",
	ZIndex = 4,
	Parent = s1Box,
})

local s1Element = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.new(1, 0, 0, 14),
	FontFace = F.Bold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(255, 120, 40),
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Fire",
	ZIndex = 4,
	Parent = s1Box,
})

local s1Status = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 129),
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = s1Box,
})

local s1StatusText = text({
	Size = UDim2.fromScale(1, 1),
	FontFace = F.Bold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(90, 205, 110),
	Text = "OWNED LV1",
	ZIndex = 5,
	Parent = s1Status,
})

-- Skill 2 Hero
local s2Box = new("Frame", {
	Position = UDim2.new(0.54, 0, 0, 0),
	Size = UDim2.new(0.46, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = formulaCard,
})

local s2Glow = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 45),
	Size = UDim2.fromOffset(110, 110),
	BackgroundTransparency = 1,
	Image = UIAssets.Fx.Glow,
	ImageColor3 = Color3.fromRGB(40, 200, 255),
	ImageTransparency = 0.5,
	ZIndex = 3,
	Parent = s2Box,
})

local s2Icon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(90, 90),
	BackgroundTransparency = 1,
	Image = UIAssets.Icons.Empty,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
	Parent = s2Box,
})

-- The awakened skill's living frame (matches the HUD's awakened icons),
-- shown on the Altar's "after" preview.
local s2AwakenFrame = new("Frame", { Name = "AwakenFrame", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = s2Icon })
local s2AwakenGradients = {}
for i, spec in { { 0.62, 6, 0 }, { 0.9, 2, 0.35 } } do -- inner one covers the art's black edge
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(spec[1], spec[1]),
		Rotation = 45,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = s2AwakenFrame,
	})
	local edge = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = spec[2], Transparency = spec[3], LineJoinMode = Enum.LineJoinMode.Miter, Parent = ring })
	s2AwakenGradients[i] = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 92)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(110, 232, 255)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(196, 124, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 92)),
		}),
		Parent = edge,
	})
end
new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.02),
	Size = UDim2.fromOffset(10, 10),
	Rotation = 45,
	BackgroundColor3 = Color3.fromRGB(150, 240, 255),
	BorderSizePixel = 0,
	ZIndex = 6,
	Parent = s2AwakenFrame,
}, { new("UIStroke", { Color = Color3.fromRGB(255, 230, 140), Thickness = 1 }) })
game:GetService("RunService").RenderStepped:Connect(function()
	if gui.Enabled and s2AwakenFrame.Visible then
		local t = os.clock()
		s2AwakenGradients[1].Rotation = (t * 120) % 360
		s2AwakenGradients[2].Rotation = (-t * 72) % 360
	end
end)

local s2Name = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 94),
	Size = UDim2.new(1, 0, 0, 16),
	FontFace = F.Bold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "Skill 2",
	ZIndex = 4,
	Parent = s2Box,
})

local s2Element = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.new(1, 0, 0, 14),
	FontFace = F.Bold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(40, 200, 255),
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Water",
	ZIndex = 4,
	Parent = s2Box,
})

local s2Status = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 129),
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = s2Box,
})

local s2StatusText = text({
	Size = UDim2.fromScale(1, 1),
	FontFace = F.Bold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(205, 80, 80),
	Text = "NOT OWNED",
	ZIndex = 5,
	Parent = s2Status,
})

-------------------------------------------------------------------------------
-- Bottom Section: Requirements with Modern Progress Bars
-------------------------------------------------------------------------------
local reqSection = new("Frame", {
	Position = UDim2.fromOffset(12, 298),
	Size = UDim2.new(1, -24, 0, 140),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = rightPanel,
})

local reqLabel = text({
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 18),
	FontFace = F.Label,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(205, 190, 170),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "REQUIRED MATERIALS & GOLD",
	ZIndex = 3,
	Parent = reqSection,
})

local matScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, 0, 1, -20),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Color3.fromRGB(85, 75, 65),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ZIndex = 3,
	Parent = reqSection,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}),
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 4),
	}),
})

-------------------------------------------------------------------------------
-- Quick Equip to Test (Slots Q & E): removed from the Forge screen, so the
-- row is kept hidden. Equip skills from the Backpack (B) instead.
-------------------------------------------------------------------------------
local equipSection = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -58),
	Size = UDim2.new(1, -24, 0, 44),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 3,
	Parent = rightPanel,
})

local equipQBtn = new("TextButton", {
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(0.5, -6, 1, 0),
	BackgroundColor3 = Color3.fromRGB(20, 26, 36),
	Text = "✦ EQUIP [Q]",
	TextColor3 = Color3.fromRGB(160, 225, 255),
	TextSize = 13,
	FontFace = F.TitleBold,
	AutoButtonColor = true,
	ZIndex = 4,
	Parent = equipSection,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = Color3.fromRGB(55, 115, 175), Thickness = 1.5 }),
})

local equipEBtn = new("TextButton", {
	Position = UDim2.new(0.5, 6, 0, 0),
	Size = UDim2.new(0.5, -6, 1, 0),
	BackgroundColor3 = Color3.fromRGB(32, 26, 20),
	Text = "✦ EQUIP [E]",
	TextColor3 = Color3.fromRGB(255, 215, 120),
	TextSize = 13,
	FontFace = F.TitleBold,
	AutoButtonColor = true,
	ZIndex = 4,
	Parent = equipSection,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = Color3.fromRGB(150, 110, 45), Thickness = 1.5 }),
})

-- Option 1 Bronze & Molten Gold Action Button (Highly Visible in all states)
local actionBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -24, 0, 44),
	BackgroundColor3 = Color3.fromRGB(52, 28, 34),
	Text = "INSUFFICIENT REQUIREMENTS",
	TextColor3 = Color3.fromRGB(245, 220, 220),
	TextSize = 15,
	FontFace = F.TitleBold,
	AutoButtonColor = true,
	ZIndex = 3,
	Parent = rightPanel,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = Color3.fromRGB(150, 70, 80), Thickness = 1.5 }),
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 30, 36)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(78, 40, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 30, 36)),
		}),
	}),
})

-------------------------------------------------------------------------------
-- Requirement Card with Sleek Progress Bar
-------------------------------------------------------------------------------
local function addReqCard(iconImage, nameText, owned, required, isGold, neonColor)
	neonColor = neonColor or (if isGold then NeonColors.Gold else Color3.fromRGB(180, 170, 210))
	local isSatisfied = (owned >= required)
	local ratio = math.clamp(owned / math.max(required, 1), 0, 1)

	local card = new("Frame", {
		Size = UDim2.fromOffset(124, 114),
		BackgroundColor3 = Color3.fromRGB(22, 21, 26),
		ZIndex = 3,
		Parent = matScroll,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		new("UIStroke", {
			Color = if isSatisfied then Color3.fromRGB(195, 155, 75) else Color3.fromRGB(75, 65, 58),
			Thickness = 1.2,
		}),
	})

	-- Ambient item aura
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
		Image = UIAssets.Fx.Glow,
		ImageColor3 = neonColor,
		ImageTransparency = 0.55,
		ZIndex = 3,
		Parent = card,
	})

	-- Item icon
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(42, 42),
		BackgroundTransparency = 1,
		Image = iconImage or UIAssets.Icons.Empty,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
		Parent = card,
	})

	-- Name text
	text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(1, -6, 0, 18),
		FontFace = F.Body,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(240, 240, 250),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = nameText,
		ZIndex = 4,
		Parent = card,
	})

	-- Modern Horizontal Progress Bar Container
	local barBg = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -10, 0, 20),
		BackgroundColor3 = Color3.fromRGB(18, 19, 26),
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = card,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
		new("UIStroke", {
			Color = if isSatisfied then neonColor else Color3.fromRGB(120, 45, 55),
			Thickness = 1,
		}),
	})

	-- Filled Progress Bar
	if ratio > 0 then
		new("Frame", {
			Size = UDim2.new(ratio, 0, 1, 0),
			BackgroundColor3 = if isSatisfied then (if isGold then NeonColors.Gold else neonColor) else Color3.fromRGB(220, 60, 70),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = barBg,
		})
	end

	-- Progress Text Overlay
	local progText = if isSatisfied and not isGold then `✓ {owned}/{required}` else `{owned}/{required}`
	text({
		Size = UDim2.fromScale(1, 1),
		FontFace = F.Bold,
		TextSize = 10,
		TextColor3 = if isSatisfied then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 175, 180),
		Text = progText,
		ZIndex = 5,
		Parent = barBg,
	})

	return card
end

-------------------------------------------------------------------------------
-- Render & Refresh Logic
-------------------------------------------------------------------------------
local function updateHeader()
	if currentTab == "Forge" then
		titleLabel.Text = "THE FORGE"
		titlePlaque.UIStroke.Color = Color3.fromRGB(165, 125, 60)
		headerIcon.Image = UIAssets.Menu.Forge or "rbxassetid://132527579649611"
		headerAura.ImageColor3 = Color3.fromRGB(255, 120, 30)

		tabForge.BackgroundColor3 = Color3.fromRGB(26, 24, 28)
		tabForge.TextColor3 = Color3.fromRGB(255, 195, 110)
		tabForge.UIStroke.Color = Color3.fromRGB(180, 120, 50)
		tabForge.UIStroke.Thickness = 1.5

		tabAwaken.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabAwaken.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabAwaken.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabAwaken.UIStroke.Thickness = 1

		tabBase.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabBase.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabBase.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabBase.UIStroke.Thickness = 1

		formulaLabel.Text = "FUSION FORMULA"
		plusLabel.Text = "+"
		plusLabel.TextSize = 32
		plusLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
		energyBeamLeft.BackgroundColor3 = Color3.fromRGB(220, 150, 45)
		energyBeamRight.BackgroundColor3 = Color3.fromRGB(220, 150, 45)
		resultBanner.UIStroke.Color = Color3.fromRGB(75, 62, 50)
		resultTitle.TextColor3 = Color3.fromRGB(255, 218, 90)
	elseif currentTab == "Awaken" then
		titleLabel.Text = "AWAKENING ALTAR"
		titlePlaque.UIStroke.Color = Color3.fromRGB(80, 170, 240)
		headerIcon.Image = UIAssets.Stats.Focus or "rbxassetid://115007593027726"
		headerAura.ImageColor3 = Color3.fromRGB(50, 180, 255)

		tabAwaken.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		tabAwaken.TextColor3 = Color3.fromRGB(100, 220, 255)
		tabAwaken.UIStroke.Color = Color3.fromRGB(60, 180, 255)
		tabAwaken.UIStroke.Thickness = 1.5

		tabForge.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabForge.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabForge.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabForge.UIStroke.Thickness = 1

		tabBase.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabBase.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabBase.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabBase.UIStroke.Thickness = 1

		formulaLabel.Text = "ASCENSION FORMULA"
		plusLabel.Text = ">>"
		plusLabel.TextSize = 28
		plusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
		energyBeamLeft.BackgroundColor3 = Color3.fromRGB(50, 190, 255)
		energyBeamRight.BackgroundColor3 = Color3.fromRGB(140, 90, 255)
		resultBanner.UIStroke.Color = Color3.fromRGB(60, 140, 210)
		resultTitle.TextColor3 = Color3.fromRGB(120, 230, 255)
	else -- "Base"
		titleLabel.Text = "ELEMENTAL CODEX"
		titlePlaque.UIStroke.Color = Color3.fromRGB(80, 210, 150)
		headerIcon.Image = UIAssets.Menu.Areas or UIAssets.Icons.Empty
		headerAura.ImageColor3 = Color3.fromRGB(60, 220, 160)

		tabBase.BackgroundColor3 = Color3.fromRGB(18, 26, 22)
		tabBase.TextColor3 = Color3.fromRGB(90, 230, 170)
		tabBase.UIStroke.Color = Color3.fromRGB(60, 200, 140)
		tabBase.UIStroke.Thickness = 1.5

		tabForge.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabForge.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabForge.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabForge.UIStroke.Thickness = 1

		tabAwaken.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		tabAwaken.TextColor3 = Color3.fromRGB(140, 145, 160)
		tabAwaken.UIStroke.Color = Color3.fromRGB(45, 44, 48)
		tabAwaken.UIStroke.Thickness = 1

		formulaLabel.Text = "CORE ELEMENT"
		plusLabel.Text = "✦"
		plusLabel.TextSize = 28
		plusLabel.TextColor3 = Color3.fromRGB(90, 230, 170)
		energyBeamLeft.BackgroundColor3 = Color3.fromRGB(60, 200, 140)
		energyBeamRight.BackgroundColor3 = Color3.fromRGB(60, 200, 140)
		resultBanner.UIStroke.Color = Color3.fromRGB(50, 150, 100)
		resultTitle.TextColor3 = Color3.fromRGB(140, 240, 190)
	end
end

local function renderDetails()
	for _, child in matScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	if not selectedId then
		return
	end

	local gold = player:GetAttribute("Gold") or 0

	if currentTab == "Forge" then
		local recipe = Crafting.ForgeRecipes[selectedId]
		if not recipe then return end

		local def = Skills.Defs[recipe.Result]
		resultTitle.Text = recipe.Title
		resultDesc.Text = recipe.Description
		resultIcon.Image = UIAssets.Icons[recipe.Result] or UIAssets.Icons.Empty

		-- Component Skill 1
		local s1Id = recipe.Skills[1]
		local s1Def = Skills.Defs[s1Id]
		local s1Owned = cachedBuild.Skills[s1Id]
		local s1Elem = getSkillElement(s1Id)
		local s1Color = getSkillColor(s1Id)
		s1Icon.Image = UIAssets.Icons[s1Id] or UIAssets.Icons.Empty
		s1Name.Text = s1Def and s1Def.Name or s1Id
		s1Element.Text = s1Elem
		s1Element.TextColor3 = s1Color
		s1Glow.ImageColor3 = s1Color
		s1StatusText.TextColor3 = if s1Owned then Color3.fromRGB(90, 205, 110) else Color3.fromRGB(205, 80, 80)
		s1StatusText.Text = if s1Owned then `OWNED LV{s1Owned}` else "NOT OWNED"

		-- Component Skill 2
		local s2Id = recipe.Skills[2]
		local s2Def = Skills.Defs[s2Id]
		local s2Owned = cachedBuild.Skills[s2Id]
		local s2Elem = getSkillElement(s2Id)
		local s2Color = getSkillColor(s2Id)
		s2Icon.Image = UIAssets.Icons[s2Id] or UIAssets.Icons.Empty
		s2AwakenFrame.Visible = false
		s2Name.Text = s2Def and s2Def.Name or s2Id
		s2Element.Text = s2Elem
		s2Element.TextColor3 = s2Color
		s2Glow.ImageColor3 = s2Color
		s2StatusText.TextColor3 = if s2Owned then Color3.fromRGB(90, 205, 110) else Color3.fromRGB(205, 80, 80)
		s2StatusText.Text = if s2Owned then `OWNED LV{s2Owned}` else "NOT OWNED"

		-- Energy Beams connecting skills to center
		plusLabel.Text = "+"
		plusLabel.TextSize = 32
		plusLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
		energyBeamLeft.BackgroundColor3 = Color3.fromRGB(220, 150, 45)
		energyBeamRight.BackgroundColor3 = Color3.fromRGB(220, 150, 45)

		-- Result Banner
		resultBanner.UIStroke.Color = Color3.fromRGB(75, 62, 50)
		resultTitle.TextColor3 = Color3.fromRGB(255, 218, 90)
		resultAura.ImageColor3 = getSkillColor(recipe.Result)

		-- Material Requirements in Horizontal Scroll with Progress Bars
		-- Shards (Act 1), Cores (Act 2), Essences (Act 3), then Rift Shards.
		local mats = {}
		for mat in recipe.Materials do
			table.insert(mats, mat)
		end
		local function rank(mat)
			return if mat == "RiftShard" then 999 else (table.find(Items.Order, mat) or 500)
		end
		table.sort(mats, function(a, b)
			return rank(a) < rank(b)
		end)
		for _, mat in mats do
			local count = recipe.Materials[mat]
			local mDef = Items.Defs[mat]
			local mName = mDef and mDef.Name or mat
			local owned = cachedInventory[mat] or 0
			local neon = ItemNeonColors[mat] or Color3.fromRGB(180, 170, 210)
			addReqCard(UIAssets.Items[mat] or UIAssets.Icons.Empty, mName, owned, count, false, neon)
		end

		-- Gold Fee as a Requirement Card with Progress Bar
		addReqCard(UIAssets.Coin, "Gold", gold, recipe.Gold, true, NeonColors.Gold)

		-- Result Info
		local statStr = "Deals massive elemental damage"
		if def and def.Status then
			local statList = {}
			for sName, _ in def.Status do
				table.insert(statList, sName)
			end
			if #statList > 0 then
				statStr = "Inflicts " .. table.concat(statList, ", ")
			end
		end
		statusText.Text = `TYPE: {(def and def.Kind or "SKILL"):upper()} • {statStr}`

		local canCraft, _ = Crafting.CanCraft(selectedId, cachedBuild.Skills, cachedInventory, gold)
		actionBtn.Active = canCraft
		if canCraft then
			actionBtn.Text = "FORGE FUSION"
			actionBtn.TextColor3 = Color3.fromRGB(255, 240, 180)
			actionBtn.UIStroke.Color = Color3.fromRGB(255, 195, 75)
			actionBtn.UIStroke.Thickness = 2
			actionBtn.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(195, 95, 25)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 165, 45)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 95, 25)),
			})
		else
			actionBtn.Text = "INSUFFICIENT REQUIREMENTS"
			actionBtn.TextColor3 = Color3.fromRGB(245, 220, 220)
			actionBtn.UIStroke.Color = Color3.fromRGB(150, 70, 80)
			actionBtn.UIStroke.Thickness = 1.5
			actionBtn.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 30, 36)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(78, 40, 48)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 30, 36)),
			})
		end
	elseif currentTab == "Awaken" then
		-- Awakening Tab Details
		local recipe = Crafting.AwakenRecipes[selectedId]
		if not recipe then return end

		local def = Skills.Defs[recipe.AwakenedSkill]
		resultTitle.Text = recipe.Title
		resultDesc.Text = recipe.Description
		resultIcon.Image = UIAssets.Icons[recipe.BaseSkill] or UIAssets.Icons.Empty

		-- Skill 1 is Base Skill
		local baseDef = Skills.Defs[recipe.BaseSkill]
		local baseOwned = cachedBuild.Skills[recipe.BaseSkill] or 0
		local baseElem = getSkillElement(recipe.BaseSkill)
		local baseColor = getSkillColor(recipe.BaseSkill)
		s1Icon.Image = UIAssets.Icons[recipe.BaseSkill] or UIAssets.Icons.Empty
		s1Name.Text = if baseDef then baseDef.Name else recipe.BaseSkill
		s1Element.Text = baseElem
		s1Element.TextColor3 = baseColor
		s1Glow.ImageColor3 = baseColor
		local needLevel = recipe.RequiredLevel
		s1StatusText.TextColor3 = if baseOwned >= needLevel then Color3.fromRGB(90, 205, 110) else Color3.fromRGB(205, 80, 80)
		s1StatusText.Text = if baseOwned >= needLevel then `READY (LV{baseOwned})` else `LV {baseOwned}/{needLevel}`

		-- Center Connector: Ascension Chevron (>>)
		plusLabel.Text = ">>"
		plusLabel.TextSize = 28
		plusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)

		-- Skill 2 is Awakened Skill (Fireball >> Fireball Awakened)
		local isAwakened = (cachedBuild.Skills[recipe.AwakenedSkill] ~= nil)
		s2Icon.Image = UIAssets.Icons[recipe.BaseSkill] or UIAssets.Icons.Empty
		s2AwakenFrame.Visible = true
		s2Name.Text = if def then def.Name else recipe.AwakenedSkill
		s2Element.Text = `{baseElem} • Awakened`
		s2Element.TextColor3 = Color3.fromRGB(100, 220, 255)
		s2Glow.ImageColor3 = Color3.fromRGB(100, 220, 255)
		s2StatusText.TextColor3 = if isAwakened then Color3.fromRGB(90, 205, 110) else Color3.fromRGB(140, 210, 255)
		s2StatusText.Text = if isAwakened then "AWAKENED" else `PERK: {recipe.PerkName:upper()}`

		-- Energy Beams connecting base skill to awakened skill
		energyBeamLeft.BackgroundColor3 = baseColor
		energyBeamRight.BackgroundColor3 = Color3.fromRGB(100, 220, 255)

		-- Result Banner
		resultBanner.UIStroke.Color = Color3.fromRGB(60, 140, 210)
		resultTitle.TextColor3 = Color3.fromRGB(120, 230, 255)
		resultAura.ImageColor3 = Color3.fromRGB(100, 220, 255)

		-- Material Requirements in Horizontal Scroll with Progress Bars.
		-- Fused awakenings list exact materials (both nations' Essences and Shards).
		if recipe.Materials then
			local mats = {}
			for mat in recipe.Materials do
				table.insert(mats, mat)
			end
			local function rank(mat)
				return if mat == "RiftShard" then 999 else (table.find(Items.Order, mat) or 500)
			end
			table.sort(mats, function(a, b)
				return rank(a) < rank(b)
			end)
			for _, mat in mats do
				local mDef = Items.Defs[mat]
				addReqCard(UIAssets.Items[mat] or UIAssets.Icons.Empty, mDef and mDef.Name or mat, cachedInventory[mat] or 0, recipe.Materials[mat], false, ItemNeonColors[mat] or Color3.fromRGB(180, 170, 210))
			end
		else
		local essCount = cachedInventory[recipe.Essence] or 0
		local coreCount = cachedInventory[recipe.Core] or 0
		local catIcon = if essCount >= 1 then UIAssets.Items[recipe.Essence] else (UIAssets.Items[recipe.Core] or UIAssets.Icons.Empty)
		local catName = if essCount >= 1 then (Items.Defs[recipe.Essence] and Items.Defs[recipe.Essence].Name or recipe.Essence) else (Items.Defs[recipe.Core] and Items.Defs[recipe.Core].Name or recipe.Core)
		local catNeon = if essCount >= 1 then (ItemNeonColors[recipe.Essence] or NeonColors.Fire) else (ItemNeonColors[recipe.Core] or NeonColors.Rift)
		local catOwned = if essCount >= 1 then essCount else coreCount
		local catReq = if essCount >= 1 then 1 else 2
		addReqCard(catIcon, catName, catOwned, catReq, false, catNeon)

		local shardCount = cachedInventory[recipe.Shard] or 0
		local sDef = Items.Defs[recipe.Shard]
		local sName = sDef and sDef.Name or recipe.Shard
		addReqCard(UIAssets.Items[recipe.Shard], sName, shardCount, recipe.ShardCount, false, ItemNeonColors[recipe.Shard])

		local riftCount = cachedInventory.RiftShard or 0
		addReqCard(UIAssets.Items.RiftShard, "Rift Shard", riftCount, recipe.RiftShardCount, false, ItemNeonColors.RiftShard)
		end

		-- Gold Fee as a Requirement Card with Progress Bar
		addReqCard(UIAssets.Coin, "Gold", gold, recipe.Gold, true, NeonColors.Gold)

		-- Perk Details
		statusText.Text = `PERK: {recipe.PerkName:upper()} • +20% Base Damage`

		-- Green when you can awaken; red (with the reason) when you can't.
		local canAwaken, why = Crafting.CanAwaken(selectedId, cachedBuild.Skills, cachedInventory, gold)
		actionBtn.Active = canAwaken
		if canAwaken then
			actionBtn.Text = "AWAKEN SKILL"
			actionBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
			actionBtn.UIStroke.Color = Color3.fromRGB(110, 230, 130)
			actionBtn.UIStroke.Thickness = 2
			actionBtn.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 110, 52)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 170, 84)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 110, 52)),
			})
		else
			actionBtn.Text = "CAN'T AWAKEN  ·  " .. tostring(why or "requirements not met"):upper()
			actionBtn.TextColor3 = Color3.fromRGB(255, 230, 230)
			actionBtn.UIStroke.Color = Color3.fromRGB(220, 80, 90)
			actionBtn.UIStroke.Thickness = 1.5
			actionBtn.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 24, 32)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 38, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 24, 32)),
			})
		end
	else
		-- Base Skills Tab Details
		local def = Skills.Defs[selectedId]
		if not def then return end

		local elem = (def.Elements and def.Elements[1]) or "Rift"
		local elemColor = NeonColors[elem] or Color3.fromRGB(255, 200, 50)
		local isOwned = (cachedBuild.Skills and cachedBuild.Skills[selectedId] ~= nil)
		local level = (cachedBuild.Skills and cachedBuild.Skills[selectedId]) or 1

		resultTitle.Text = def.Name
		resultDesc.Text = def.Description
		resultIcon.Image = UIAssets.Icons[selectedId] or UIAssets.Icons.Empty
		resultAura.ImageColor3 = elemColor
		resultTitle.TextColor3 = elemColor
		resultBanner.UIStroke.Color = elemColor:Lerp(Color3.fromRGB(75, 62, 50), 0.5)

		statusText.Text = `TYPE: {(def.Kind or "SKILL"):upper()} • ELEMENT: {elem:upper()} • RANK {level}`

		-- Formula card for Base Skill
		formulaLabel.Text = "ELEMENTAL SOURCE"
		plusLabel.Text = "✦"
		plusLabel.TextSize = 28
		plusLabel.TextColor3 = elemColor
		energyBeamLeft.BackgroundColor3 = elemColor
		energyBeamRight.BackgroundColor3 = elemColor

		s1Icon.Image = UIAssets.Icons[selectedId] or UIAssets.Icons.Empty
		s1Name.Text = def.Name
		s1Element.Text = elem
		s1Element.TextColor3 = elemColor
		s1Glow.ImageColor3 = elemColor
		s1StatusText.TextColor3 = if isOwned then Color3.fromRGB(90, 205, 110) else Color3.fromRGB(100, 220, 255)
		s1StatusText.Text = if isOwned then `OWNED LV{level}` else "READY TO TEST"

		s2Icon.Image = UIAssets.Icons[selectedId] or UIAssets.Icons.Empty
		s2AwakenFrame.Visible = false
		s2Name.Text = "Elemental Shrine"
		s2Element.Text = `{elem} Essence`
		s2Element.TextColor3 = elemColor
		s2Glow.ImageColor3 = elemColor
		s2StatusText.TextColor3 = Color3.fromRGB(255, 215, 110)
		s2StatusText.Text = "TEST ARENA"

		-- Info in requirements
		reqLabel.Text = "TRAINING / FREE TESTING"
		addReqCard(UIAssets.Icons[selectedId], def.Name, 1, 1, false, elemColor)
		addReqCard(UIAssets.Menu.Play or UIAssets.Icons.Empty, "Free Equip", 1, 1, false, Color3.fromRGB(90, 220, 140))

		actionBtn.Active = true
		actionBtn.Text = "EQUIP ON [Q] TO TEST"
		actionBtn.TextColor3 = Color3.fromRGB(220, 245, 235)
		actionBtn.UIStroke.Color = Color3.fromRGB(60, 180, 120)
		actionBtn.UIStroke.Thickness = 1.5
		actionBtn.UIGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 52, 38)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(36, 78, 56)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 52, 38)),
		})
	end

	-- Update Quick Equip Buttons (Slots Q & E)
	local targetSkillId
	if currentTab == "Forge" then
		local recipe = Crafting.ForgeRecipes[selectedId]
		targetSkillId = recipe and recipe.Result
	elseif currentTab == "Awaken" then
		local recipe = Crafting.AwakenRecipes[selectedId]
		targetSkillId = recipe and recipe.AwakenedSkill
	elseif currentTab == "Base" then
		targetSkillId = selectedId
	end

	if targetSkillId then
		local isQ = (cachedBuild.Slots and cachedBuild.Slots.Q == targetSkillId)
		local isE = (cachedBuild.Slots and cachedBuild.Slots.E == targetSkillId)

		equipQBtn.Visible = true
		equipEBtn.Visible = true

		if isQ then
			equipQBtn.Text = "✓ EQUIPPED ON [Q]"
			equipQBtn.TextColor3 = Color3.fromRGB(225, 255, 255)
			equipQBtn.BackgroundColor3 = Color3.fromRGB(18, 65, 82)
			equipQBtn.UIStroke.Color = Color3.fromRGB(60, 220, 255)
			equipQBtn.UIStroke.Thickness = 2
		else
			equipQBtn.Text = "✦ EQUIP [Q]"
			equipQBtn.TextColor3 = Color3.fromRGB(160, 225, 255)
			equipQBtn.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
			equipQBtn.UIStroke.Color = Color3.fromRGB(55, 115, 175)
			equipQBtn.UIStroke.Thickness = 1.5
		end

		if isE then
			equipEBtn.Text = "✓ EQUIPPED ON [E]"
			equipEBtn.TextColor3 = Color3.fromRGB(255, 245, 200)
			equipEBtn.BackgroundColor3 = Color3.fromRGB(75, 58, 18)
			equipEBtn.UIStroke.Color = Color3.fromRGB(255, 205, 75)
			equipEBtn.UIStroke.Thickness = 2
		else
			equipEBtn.Text = "✦ EQUIP [E]"
			equipEBtn.TextColor3 = Color3.fromRGB(255, 215, 120)
			equipEBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 20)
			equipEBtn.UIStroke.Color = Color3.fromRGB(150, 110, 45)
			equipEBtn.UIStroke.Thickness = 1.5
		end
	else
		equipQBtn.Visible = false
		equipEBtn.Visible = false
	end
end

local function renderList()
	for _, child in listScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local gold = player:GetAttribute("Gold") or 0
	local list = if currentTab == "Forge" then Crafting.ForgeOrder elseif currentTab == "Awaken" then Crafting.AwakenOrder else BaseOrder
	local query = searchQuery:lower():gsub("%s+", "")
	local count = 0

	for _, id in list do
		local title, sub, elemName, iconAsset, isOwned, lvl
		if currentTab == "Forge" then
			local recipe = Crafting.ForgeRecipes[id]
			if not recipe then continue end
			title = recipe.Title
			sub = (recipe.Skills[1] .. recipe.Skills[2])
			elemName = getSkillElement(recipe.Result)
			iconAsset = UIAssets.Icons[recipe.Result] or UIAssets.Icons.Empty
			lvl = cachedBuild.Skills and cachedBuild.Skills[recipe.Result]
			isOwned = lvl ~= nil
		elseif currentTab == "Awaken" then
			local recipe = Crafting.AwakenRecipes[id]
			if not recipe then continue end
			title = recipe.Title
			sub = recipe.BaseSkill
			elemName = getSkillElement(recipe.BaseSkill)
			iconAsset = UIAssets.Icons[recipe.BaseSkill] or UIAssets.Icons.Empty
			lvl = cachedBuild.Skills and cachedBuild.Skills[recipe.AwakenedSkill]
			isOwned = lvl ~= nil
		else -- "Base"
			local def = Skills.Defs[id]
			if not def then continue end
			title = def.Name
			sub = (def.Elements and def.Elements[1]) or "Rift"
			elemName = sub
			iconAsset = UIAssets.Icons[id] or UIAssets.Icons.Empty
			lvl = cachedBuild.Skills and cachedBuild.Skills[id]
			isOwned = lvl ~= nil
		end

		local titleMatch = title:lower():gsub("%s+", "")
		local subMatch = sub:lower():gsub("%s+", "")
		if query == "" or string.find(titleMatch, query) or string.find(subMatch, query) then
			count += 1
			local isSelected = selectedId == id
			local elemColor = NeonColors[elemName] or Color3.fromRGB(180, 170, 210)

			-- Option 1: Dark Fantasy Beveled Stone Card
			local card = new("TextButton", {
				Size = UDim2.fromOffset(145, 114),
				BackgroundColor3 = if isSelected then Color3.fromRGB(28, 26, 32) else Color3.fromRGB(20, 20, 25),
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = count,
				ZIndex = 3,
				Parent = listScroll,
			}, {
				new("UICorner", { CornerRadius = UDim.new(0, 3) }),
				new("UIStroke", {
					Color = if isSelected then Color3.fromRGB(220, 160, 60) else Color3.fromRGB(48, 44, 40),
					Thickness = if isSelected then 2 else 1,
				}),
			})

			-- Soft Radial Glow behind Diamond Icon
			new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 39),
				Size = UDim2.fromOffset(74, 74),
				BackgroundTransparency = 1,
				Image = UIAssets.Fx.Glow,
				ImageColor3 = elemColor,
				ImageTransparency = if isSelected then 0.5 else 0.75,
				ZIndex = 3,
				Parent = card,
			})

			-- Large centered diamond icon (70x70)
			new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(70, 70),
				BackgroundTransparency = 1,
				Image = iconAsset,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 4,
				Parent = card,
			})

			-- Skill Title
			text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 76),
				Size = UDim2.new(1, -8, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = F.Bold,
				TextSize = 11,
				Text = title,
				TextColor3 = if isSelected then Color3.fromRGB(255, 230, 160) else Color3.fromRGB(235, 235, 240),
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 4,
				Parent = card,
			})

			-- Option 1 Status Text (OWNED LV1 in green, NOT OWNED in red)
			local statusStr = if isOwned then `OWNED LV{lvl or 1}` else (if currentTab == "Base" then "READY TO TEST" else "NOT OWNED")
			text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 93),
				Size = UDim2.new(1, -8, 0, 15),
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = F.Bold,
				TextSize = 10,
				Text = statusStr,
				TextColor3 = if isOwned then Color3.fromRGB(90, 205, 110) else (if currentTab == "Base" then Color3.fromRGB(100, 220, 255) else Color3.fromRGB(205, 80, 80)),
				ZIndex = 4,
				Parent = card,
			})

			-- Hover Transitions
			card.MouseEnter:Connect(function()
				if selectedId ~= id then
					tween(card, 0.15, { BackgroundColor3 = Color3.fromRGB(28, 26, 32) })
					card.UIStroke.Color = Color3.fromRGB(140, 110, 55)
				end
			end)
			card.MouseLeave:Connect(function()
				if selectedId ~= id then
					tween(card, 0.15, { BackgroundColor3 = Color3.fromRGB(20, 20, 25) })
					card.UIStroke.Color = Color3.fromRGB(48, 44, 40)
				end
			end)

			card.MouseButton1Click:Connect(function()
				selectedId = id
				renderList()
				renderDetails()
			end)
		end
	end

	local rows = math.ceil(count / 2)
	listScroll.CanvasSize = UDim2.new(0, 0, 0, rows * 122 + 8)
end

local function refreshAll()
	updateHeader()
	renderList()
	renderDetails()
end

local function openUI(tab)
	currentTab = tab or "Forge"
	selectedId = if currentTab == "Forge" then Crafting.ForgeOrder[1] elseif currentTab == "Awaken" then Crafting.AwakenOrder[1] else BaseOrder[1]
	searchQuery = ""
	searchInput.Text = ""

	task.spawn(function()
		cachedBuild = GetBuild:InvokeServer() or cachedBuild
		cachedInventory = GetInventory:InvokeServer() or cachedInventory
		refreshAll()
	end)

	gui.Enabled = true
	panel.Position = UDim2.new(0.5, 0, 0.55, 0)
	panel.BackgroundTransparency = 1
	tween(panel, 0.25, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0 })
end

local function closeUI()
	tween(panel, 0.2, { Position = UDim2.new(0.5, 0, 0.55, 0), BackgroundTransparency = 1 })
	task.delay(0.2, function()
		gui.Enabled = false
	end)
end

-------------------------------------------------------------------------------
-- Events & Tab Toggles
-------------------------------------------------------------------------------
closeBtn.MouseButton1Click:Connect(closeUI)
shade.MouseButton1Click:Connect(closeUI)

searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	searchQuery = searchInput.Text
	renderList()
end)

tabForge.MouseButton1Click:Connect(function()
	if currentTab ~= "Forge" then
		currentTab = "Forge"
		selectedId = Crafting.ForgeOrder[1]
		searchQuery = ""
		searchInput.Text = ""
		refreshAll()
	end
end)

tabAwaken.MouseButton1Click:Connect(function()
	if currentTab ~= "Awaken" then
		currentTab = "Awaken"
		selectedId = Crafting.AwakenOrder[1]
		searchQuery = ""
		searchInput.Text = ""
		refreshAll()
	end
end)

tabBase.MouseButton1Click:Connect(function()
	if currentTab ~= "Base" then
		currentTab = "Base"
		selectedId = BaseOrder[1]
		searchQuery = ""
		searchInput.Text = ""
		refreshAll()
	end
end)

local function handleEquip(slot)
	local targetSkillId
	if currentTab == "Forge" then
		local recipe = Crafting.ForgeRecipes[selectedId]
		targetSkillId = recipe and recipe.Result
	elseif currentTab == "Awaken" then
		local recipe = Crafting.AwakenRecipes[selectedId]
		targetSkillId = recipe and recipe.AwakenedSkill
	elseif currentTab == "Base" then
		targetSkillId = selectedId
	end

	if not targetSkillId then return end
	local btn = if slot == "Q" then equipQBtn else equipEBtn
	btn.Text = `EQUIPPING [{slot}]...`

	local ok, res = TestEquipSkill:InvokeServer(slot, targetSkillId)
	if ok then
		if cachedBuild.Slots then
			cachedBuild.Slots[slot] = targetSkillId
		end
		if cachedBuild.Skills and not cachedBuild.Skills[targetSkillId] then
			cachedBuild.Skills[targetSkillId] = 1
		end
		renderList()
		renderDetails()
	else
		btn.Text = `FAILED: {res or "Error"}`
		task.delay(1.5, function()
			if btn.Parent then
				renderDetails()
			end
		end)
	end
end

equipQBtn.MouseButton1Click:Connect(function()
	handleEquip("Q")
end)

equipEBtn.MouseButton1Click:Connect(function()
	handleEquip("E")
end)

-------------------------------------------------------------------------------
-- Fusion warning: a new fusion always starts at level 1, so fusing skills
-- above level 1 throws their levels away. Ask first.
-------------------------------------------------------------------------------
local FUSE_WARN_LEVEL = 2 -- warn when an ingredient is at this level or higher

local confirmShade = new("TextButton", {
	Name = "FuseConfirm",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 3, 6),
	BackgroundTransparency = 0.35,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 60,
	Parent = gui,
})
local confirmBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 280),
	BackgroundColor3 = Color3.fromRGB(20, 18, 24),
	ZIndex = 61,
	Parent = confirmShade,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 6) }),
	new("UIStroke", { Color = Color3.fromRGB(220, 150, 45), Thickness = 2 }),
})
local confirmTitle = text({
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.new(1, -48, 0, 30),
	Text = "LEVELS WILL BE LOST",
	FontFace = F.Title,
	TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 205, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 62,
	Parent = confirmBox,
})
local confirmBody = text({
	Position = UDim2.fromOffset(24, 58),
	Size = UDim2.new(1, -48, 0, 140),
	FontFace = F.Body,
	TextSize = 16,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 62,
	Parent = confirmBox,
})
local function confirmButton(label, x, color, stroke)
	return new("TextButton", {
		Position = UDim2.new(x, if x == 0 then 24 else 6, 1, -64),
		Size = UDim2.new(0.5, -30, 0, 44),
		Text = label,
		FontFace = F.TitleBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(245, 240, 230),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		ZIndex = 62,
		Parent = confirmBox,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		new("UIStroke", { Color = stroke, Thickness = 1.5 }),
	})
end
local confirmNo = confirmButton("CANCEL", 0, Color3.fromRGB(40, 36, 44), Color3.fromRGB(90, 80, 100))
local confirmYes = confirmButton("FUSE ANYWAY", 0.5, Color3.fromRGB(120, 60, 24), Color3.fromRGB(230, 150, 60))
local confirmAction
confirmNo.MouseButton1Click:Connect(function()
	confirmShade.Visible = false
	confirmAction = nil
end)
confirmShade.MouseButton1Click:Connect(function()
	confirmShade.Visible = false
	confirmAction = nil
end)
confirmYes.MouseButton1Click:Connect(function()
	confirmShade.Visible = false
	local action = confirmAction
	confirmAction = nil
	if action then
		action()
	end
end)

-- Runs `onYes` straight away, or after the player confirms if an ingredient
-- is at FUSE_WARN_LEVEL or above.
local function confirmFusion(recipe, onYes)
	local lines = {}
	for _, skillId in recipe.Skills do
		local level = cachedBuild.Skills and cachedBuild.Skills[skillId] or 0
		if level >= FUSE_WARN_LEVEL then
			local def = Skills.Defs[skillId]
			table.insert(lines, `<b>{def and def.Name or skillId}</b> (Lv {level})`)
		end
	end
	if #lines == 0 then
		onYes()
		return
	end
	local result = Skills.Defs[recipe.Result]
	local resultName = result and result.Name or recipe.Title
	local owned = cachedBuild.Skills and cachedBuild.Skills[recipe.Result]
	local outcome = if owned
		then `You already have <b>{resultName}</b> (Lv {owned}): it stays at Lv {owned} and gains 1 copy.`
		else `<b>{resultName}</b> starts at <b>level 1</b>.`
	confirmBody.Text = `{table.concat(lines, " and ")} will be used up, and their levels and spare copies are lost.\n\n{outcome}\n\nOnly Awakening keeps a skill's level.`
	confirmAction = onYes
	confirmShade.Visible = true
end

-------------------------------------------------------------------------------
-- Fusion / Awakening cinematic: the Forge panel steps aside (so the world
-- effect around your character shows) and a full-screen reveal plays.
-------------------------------------------------------------------------------
local CINE_GOLD, CINE_CYAN, CINE_VIOLET = Color3.fromRGB(255, 214, 92), Color3.fromRGB(110, 232, 255), Color3.fromRGB(196, 124, 255)
local cinePlaying = false

-- A diamond outline (a square turned 45 degrees), matching the skill icons.
-- `size` is the diamond's width tip to tip; tweening Size keeps it a diamond.
local DIAMOND = 1 / math.sqrt(2)
local function cineDiamond(parent, size, color, thickness, z)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * DIAMOND, size * DIAMOND),
		Rotation = 45,
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}, {
		new("UIStroke", { Color = color, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Miter }),
	})
end

-- Soft light rays fanning out from the centre; returns the spinning holder.
-- Each ray is a stretched soft glow passing through the centre (so it makes
-- two opposite rays and spins around the middle), with blurry edges.
local GLOW = UIAssets.Fx.Glow
local function cineRays(parent, colors, count, length, z)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = z, Parent = parent })
	local beams = math.max(1, math.floor(count / 2))
	for i = 1, beams do
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 2 == 0 then 46 else 80, length * 2),
			Rotation = i / beams * 180,
			BackgroundTransparency = 1,
			Image = GLOW,
			ImageColor3 = colors[(i - 1) % #colors + 1],
			ImageTransparency = if i % 2 == 0 then 0.35 else 0.15,
			ZIndex = z,
			Parent = holder,
		})
	end
	-- A big soft bloom behind everything.
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(length * 1.4, length * 1.4),
		BackgroundTransparency = 1,
		Image = GLOW,
		ImageColor3 = colors[1],
		ImageTransparency = 0.25,
		ZIndex = z - 1,
		Parent = holder,
	})
	return holder
end

local function cineIcon(parent, id, size, z)
	return new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = UIAssets.Icons[id] or UIAssets.Icons.Empty,
		ZIndex = z,
		Parent = parent,
	})
end

-- kind: "Fusion" or "Awaken". resultId: the new skill; fromIds: what went in.
local function playCinematic(kind, resultId, fromIds, levelKept)
	if cinePlaying then
		return
	end
	cinePlaying = true
	local resultDef = Skills.Defs[resultId]
	local resultColor = getSkillColor(resultId)
	local awaken = kind == "Awaken"
	-- Step the Forge aside (everything on its screen, titles included) and
	-- blur the world behind the reveal.
	tween(panelScale, 0.25, { Scale = (panelScale.Scale or 1) * 0.85 })
	local hidden = {}
	task.delay(0.2, function()
		for _, child in gui:GetChildren() do
			if child:IsA("GuiObject") and child ~= shade and child.Name ~= "Cinematic" and child.Visible then
				child.Visible = false
				table.insert(hidden, child)
			end
		end
	end)
	tween(shade, 0.3, { BackgroundTransparency = 1 })
	local blur = Instance.new("BlurEffect")
	blur.Name = "RiftCinematicBlur"
	blur.Size = 0
	blur.Parent = game:GetService("Lighting")
	tween(blur, 0.4, { Size = 14 })

	-- A little bigger than the screen so the impact shake never shows an edge.
	local CINE_HOME = UDim2.new(0, -30, 0, -30)
	local cine = new("TextButton", { Name = "Cinematic", Position = CINE_HOME, Size = UDim2.new(1, 60, 1, 60), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 80, Parent = gui })
	-- Shakes the whole reveal for `time` seconds, fading out.
	local function shakeScreen(strength, time)
		local began = os.clock()
		local c
		c = game:GetService("RunService").RenderStepped:Connect(function()
			local t = (os.clock() - began) / time
			if t >= 1 or not cine.Parent then
				c:Disconnect()
				if cine.Parent then
					cine.Position = CINE_HOME
				end
				return
			end
			local k = strength * (1 - t) ^ 2
			cine.Position = CINE_HOME + UDim2.fromOffset(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k)
		end)
	end
	tween(cine, 0.4, { BackgroundTransparency = 0.6 })
	local live = true
	local conns = {}
	local function finish()
		if not live then
			return
		end
		live = false
		for _, c in conns do
			c:Disconnect()
		end
		tween(cine, 0.35, { BackgroundTransparency = 1 })
		for _, d in cine:GetDescendants() do
			if d:IsA("GuiObject") then
				tween(d, 0.3, { BackgroundTransparency = 1 })
				if d:IsA("TextLabel") then
					tween(d, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
				elseif d:IsA("ImageLabel") then
					tween(d, 0.3, { ImageTransparency = 1 })
				end
			elseif d:IsA("UIStroke") then
				tween(d, 0.3, { Transparency = 1 })
			end
		end
		tween(blur, 0.4, { Size = 0 })
		task.delay(0.4, function()
			cine:Destroy()
			blur:Destroy()
			for _, child in hidden do
				child.Visible = true
			end
			panel.Visible = true
			tween(shade, 0.25, { BackgroundTransparency = 0.45 })
			updateScale()
			cinePlaying = false
		end)
	end

	local PEAK = if awaken then 1.4 else 1.1
	local flashFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 95, Parent = cine })

	if awaken then
		-- Power gathers: rings close in on the skill, which shakes and burns white.
		local icon = cineIcon(cine, fromIds[1], 150, 86)
		local aura = cineDiamond(cine, 190, CINE_GOLD, 4, 85)
		aura.Position = UDim2.fromScale(0.5, 0.42)
		for i = 1, 6 do
			task.delay((i - 1) * 0.22, function()
				if not live then
					return
				end
				local r = cineDiamond(cine, 900, if i % 3 == 1 then CINE_GOLD elseif i % 3 == 2 then CINE_CYAN else CINE_VIOLET, 5, 84)
				r.Position = UDim2.fromScale(0.5, 0.42)
				local edge = r:FindFirstChildOfClass("UIStroke")
				edge.Transparency = 0.6
				tween(r, 0.55, { Size = UDim2.fromOffset(170 * DIAMOND, 170 * DIAMOND) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				tween(edge, 0.55, { Transparency = 0, Thickness = 10 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.56, function()
					r:Destroy()
				end)
			end)
		end
		local start = os.clock()
		table.insert(conns, game:GetService("RunService").RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / PEAK, 0, 1)
			local jitter = t * t * 10
			icon.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * jitter, 0.42, math.random(-100, 100) / 100 * jitter)
			icon.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 250, 230), t)
			local auraSize = (190 + math.sin(os.clock() * 20) * 8 * t) * DIAMOND
			aura.Size = UDim2.fromOffset(auraSize, auraSize)
		end))
		task.delay(PEAK, function()
			if not live then
				return
			end
			icon:Destroy()
			aura:Destroy()
		end)
	else
		-- The two skills spin in from the sides and smash together.
		local a = cineIcon(cine, fromIds[1], 130, 86)
		local b = cineIcon(cine, fromIds[2], 130, 86)
		a.Position = UDim2.fromScale(0.18, 0.42)
		b.Position = UDim2.fromScale(0.82, 0.42)
		for _, pair in { { a, getSkillColor(fromIds[1]) }, { b, getSkillColor(fromIds[2]) } } do
			local glow = cineDiamond(pair[1], 160, pair[2], 4, 85)
			tween(glow, PEAK, { Size = UDim2.fromOffset(220 * DIAMOND, 220 * DIAMOND) })
		end
		tween(a, PEAK, { Position = UDim2.fromScale(0.5, 0.42), Rotation = 540 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(b, PEAK, { Position = UDim2.fromScale(0.5, 0.42), Rotation = -540 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(PEAK, function()
			if not live then
				return
			end
			a:Destroy()
			b:Destroy()
		end)
	end

	-- The reveal.
	task.delay(PEAK, function()
		if not live then
			return
		end
		flashFrame.BackgroundTransparency = 0
		tween(flashFrame, if awaken then 0.9 else 0.6, { BackgroundTransparency = 1 })
		shakeScreen(if awaken then 22 else 14, if awaken then 0.7 else 0.5)
		local colors = if awaken then { CINE_GOLD, CINE_CYAN, CINE_VIOLET } else { resultColor, getSkillColor(fromIds[1]), getSkillColor(fromIds[2]) }
		local rays = cineRays(cine, colors, if awaken then 24 else 16, 520, 82)
		table.insert(conns, game:GetService("RunService").RenderStepped:Connect(function(dt)
			rays.Rotation += dt * (if awaken then 25 else 15)
		end))
		for i = 1, 3 do
			local wave = cineDiamond(cine, 40, colors[i], 8, 83)
			wave.Position = UDim2.fromScale(0.5, 0.42)
			local edge = wave:FindFirstChildOfClass("UIStroke")
			task.delay((i - 1) * 0.12, function()
				tween(wave, 0.9, { Size = UDim2.fromOffset(1100 * DIAMOND, 1100 * DIAMOND) }, Enum.EasingStyle.Quart)
				tween(edge, 0.9, { Transparency = 1, Thickness = 1 })
			end)
		end
		local icon = cineIcon(cine, resultId, 10, 88)
		tween(icon, 0.55, { Size = UDim2.fromOffset(190, 190) }, Enum.EasingStyle.Back)
		if awaken then
			-- The awakened frame: turning gold-cyan-violet diamond borders.
			for i, spec in { { 0.62, 12, 0 }, { 0.92, 3, 0.3 } } do -- inner one covers the art's black edge
				local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(spec[1], spec[1]), Rotation = 45, BackgroundTransparency = 1, ZIndex = 89, Parent = icon })
				local edge = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = spec[2], Transparency = spec[3], LineJoinMode = Enum.LineJoinMode.Miter, Parent = ring })
				local gradient = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CINE_GOLD), ColorSequenceKeypoint.new(0.35, CINE_CYAN), ColorSequenceKeypoint.new(0.65, CINE_VIOLET), ColorSequenceKeypoint.new(1, CINE_GOLD) }), Parent = edge })
				table.insert(conns, game:GetService("RunService").RenderStepped:Connect(function()
					gradient.Rotation = (os.clock() * (if i == 1 then 140 else -90)) % 360
				end))
			end
		end
		local title = text({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 150),
			Size = UDim2.fromOffset(900, 64),
			Text = if awaken then "A W A K E N E D" else "F U S I O N   C O M P L E T E",
			FontFace = F.TitleBold,
			TextSize = if awaken then 60 else 46,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.2,
			TextTransparency = 1,
			ZIndex = 90,
			Parent = cine,
		})
		local titleGradient = new("UIGradient", {
			Color = if awaken
				then ColorSequence.new({ ColorSequenceKeypoint.new(0, CINE_GOLD), ColorSequenceKeypoint.new(0.5, CINE_CYAN), ColorSequenceKeypoint.new(1, CINE_VIOLET) })
				else ColorSequence.new(Color3.new(1, 1, 1), resultColor),
			Parent = title,
		})
		table.insert(conns, game:GetService("RunService").RenderStepped:Connect(function()
			titleGradient.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.3, 0)
		end))
		title.Position = UDim2.new(0.5, 0, 0.42, 190)
		tween(title, 0.45, { Position = UDim2.new(0.5, 0, 0.42, 150), TextTransparency = 0 }, Enum.EasingStyle.Back)
		local sub = text({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 218),
			Size = UDim2.fromOffset(900, 30),
			Text = if awaken
				then `{resultDef and resultDef.Name or resultId}   ·   {resultDef and resultDef.PerkName or ""}   ·   Level {levelKept or 1} kept`
				else `{resultDef and resultDef.Name or resultId}   ·   starts at Level 1`,
			FontFace = F.Bold,
			TextSize = 22,
			TextColor3 = if awaken then CINE_CYAN else resultColor,
			TextStrokeTransparency = 0.3,
			TextTransparency = 1,
			ZIndex = 90,
			Parent = cine,
		})
		task.delay(0.25, function()
			tween(sub, 0.4, { TextTransparency = 0 })
		end)
		local hint = text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -40),
			Size = UDim2.fromOffset(400, 20),
			Text = "click to continue",
			FontFace = F.Body,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextTransparency = 1,
			ZIndex = 90,
			Parent = cine,
		})
		task.delay(1, function()
			tween(hint, 0.4, { TextTransparency = 0.3 })
		end)
		cine.MouseButton1Click:Connect(finish)
		task.delay(if awaken then 4.5 else 3.8, finish)
	end)
end

local function forgeSelected()
	actionBtn.Text = "FORGING..."
	local recipe = Crafting.ForgeRecipes[selectedId]
	local success, result = CraftSkill:InvokeServer(selectedId)
	if success then
		if recipe then
			playCinematic("Fusion", recipe.Result, recipe.Skills)
		end
		task.spawn(function()
			cachedBuild = GetBuild:InvokeServer() or cachedBuild
			cachedInventory = GetInventory:InvokeServer() or cachedInventory
			refreshAll()
		end)
	else
		actionBtn.Text = "FAILED: " .. tostring(result)
		task.delay(2, function()
			renderDetails()
		end)
	end
end

actionBtn.MouseButton1Click:Connect(function()
	if not selectedId then return end
	if currentTab == "Base" then
		handleEquip("Q")
		return
	end
	if currentTab == "Forge" then
		local recipe = Crafting.ForgeRecipes[selectedId]
		if recipe then
			confirmFusion(recipe, forgeSelected)
		end
	else
		actionBtn.Text = "ASCENDING..."
		local recipe = Crafting.AwakenRecipes[selectedId]
		local levelBefore = recipe and cachedBuild.Skills and cachedBuild.Skills[recipe.BaseSkill]
		local success, result = AwakenSkill:InvokeServer(selectedId)
		if success then
			if recipe then
				playCinematic("Awaken", recipe.AwakenedSkill, { recipe.BaseSkill }, levelBefore)
			end
			task.spawn(function()
				cachedBuild = GetBuild:InvokeServer() or cachedBuild
				cachedInventory = GetInventory:InvokeServer() or cachedInventory
				refreshAll()
			end)
		else
			actionBtn.Text = "FAILED: " .. tostring(result)
			task.delay(2, function()
				renderDetails()
			end)
		end
	end
end)

OpenForge.OnClientEvent:Connect(function()
	openUI("Forge")
end)

OpenAwakening.OnClientEvent:Connect(function()
	openUI("Awaken")
end)

BuildChanged.OnClientEvent:Connect(function(snapshot)
	cachedBuild = snapshot or cachedBuild
	if gui.Enabled then
		refreshAll()
	end
end)

InventoryChanged.OnClientEvent:Connect(function(snapshot)
	cachedInventory = snapshot or cachedInventory
	if gui.Enabled then
		refreshAll()
	end
end)

player:GetAttributeChangedSignal("Gold"):Connect(function()
	if gui.Enabled then
		refreshAll()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)
