-- Riftbound HUD in the "Shattered Obsidian" style: textured obsidian slabs held
-- by bronze clamps, glowing rift cracks, crystal-shard skill icons with inked
-- glyphs, crimson vitals and classical serif type. The art is drawn by
-- tools/art/build.js and referenced through ReplicatedStorage.Riftbound.UIAssets.
-- Contains the vitals (level/HP/XP), gold, ability shards, the Arsenal list,
-- tooltips, toasts and the Forge ("choose one fusion").
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Merge = require(Shared:WaitForChild("Merge"))
local Progression = require(Shared:WaitForChild("Progression"))
local Skills = require(Shared:WaitForChild("Skills"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local C = {
	Ink = Color3.fromRGB(7, 5, 10),
	Bronze = Color3.fromRGB(168, 119, 63),
	Gold = Color3.fromRGB(233, 194, 122),
	Crimson = Color3.fromRGB(200, 34, 46),
	Blood = Color3.fromRGB(96, 10, 20),
	Rift = Color3.fromRGB(178, 108, 255),
	RiftHot = Color3.fromRGB(231, 200, 255),
	RiftDeep = Color3.fromRGB(64, 26, 128),
	Parchment = Color3.fromRGB(241, 227, 198),
	Ash = Color3.fromRGB(156, 138, 123),
	Good = Color3.fromRGB(143, 227, 107),
}

local function face(enum, weight, style)
	return Font.new(Font.fromEnum(enum).Family, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
end

local F = {
	Title = face(Enum.Font.Bodoni),
	TitleBold = face(Enum.Font.Bodoni, Enum.FontWeight.Bold),
	Body = face(Enum.Font.Merriweather),
	BodyBold = face(Enum.Font.Merriweather, Enum.FontWeight.Bold),
	Label = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	Italic = face(Enum.Font.Garamond, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
}

local NUMERALS = { "I", "II", "III", "IV", "V" }
local KEYWORDS = {}
for _, word in { "Burns", "Burning", "Burn", "Slows", "Slow", "Soaks", "Soaked", "Soak", "Stuns", "Stun", "Shocked", "Shock", "Pulls", "Freezing" } do
	table.insert(KEYWORDS, word)
	table.insert(KEYWORDS, word:lower())
end

local SLOTS = {
	{ Slot = "M1", Key = "LMB", Lift = 10 },
	{ Slot = "Q", Key = "Q", Lift = 0 },
	{ Slot = "E", Key = "E", Lift = 0 },
	{ Slot = "Dash", Key = "SHIFT", Lift = 10 },
}
local ICON = 84
local DASH_INFO = { Name = "Dash", Description = "A swift dash through danger. Use it to reposition and escape." }

local HUD = {}

local player = Players.LocalPlayer
local remotes
local build = { Skills = {}, Slots = {} }
local discovered = {}
local cooldownEnds = {} -- [skillId] = { Ends, Length }
local dash = { Ends = 0, Length = 1 }
local slotCards = {}
local gui, fxGui, arsenal, forge, forgeShade, toastHolder, tooltip

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------

local function new(class, props, children)
	local inst = Instance.new(class)
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

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 3) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or F.Body
	props.TextColor3 = props.TextColor3 or C.Parchment
	props.TextSize = props.TextSize or 14
	props.Text = props.Text or ""
	return new("TextLabel", props)
end

local function tween(inst, t, goal, style, direction)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function hex(color)
	return "#" .. color:ToHex()
end

-- "THE FORGE" -> "T H E   F O R G E" (Roblox text has no letter-spacing).
local function spaced(s)
	return (s:upper():gsub("(.)", "%1 "):gsub(" $", ""):gsub("   ", "     "))
end

-- Bolds status keywords and ingredient names in a description (RichText).
local function emphasize(desc, extra)
	local out = desc
	for _, word in extra or {} do
		out = out:gsub(word, "<b>" .. word .. "</b>")
	end
	-- Frontier patterns keep "Burn" from matching inside "Burns".
	for _, word in KEYWORDS do
		out = out:gsub("%f[%a]" .. word .. "%f[%A]", '<font color="#ffffff"><b>' .. word .. "</b></font>")
	end
	return out
end

-- Tiled film grain + stretched smoke on top of a textured surface.
local function texture(parent, z, grainAlpha, smokeAlpha)
	new("ImageLabel", {
		Name = "Smoke",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.Smoke,
		ImageTransparency = smokeAlpha or 0.55,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = z,
		Parent = parent,
	})
	new("ImageLabel", {
		Name = "Grain",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.Grain,
		ImageTransparency = grainAlpha or 0.55,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		ZIndex = z,
		Parent = parent,
	})
end

-- Obsidian slab panel (9-slice art) with grain inside the rim.
local function slab(props, image, slice)
	props.BackgroundTransparency = 1
	props.Image = image or UIAssets.Slab
	props.ScaleType = Enum.ScaleType.Slice
	props.SliceCenter = slice or UIAssets.SlabSlice
	props.SliceScale = props.SliceScale or 0.5
	local z = props.ZIndex or 1
	local panel = new("ImageLabel", props)
	local inner = new("Frame", {
		Name = "Texture",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = panel,
	})
	texture(inner, z, 0.6, 0.7)
	return panel
end

-- Crystal-shard icon for a skill (or "Dash" / nil for empty).
local function shard(id, size, parent, z)
	local image = if id == "Dash" then UIAssets.Icons.Dash elseif id and UIAssets.Icons[id] then UIAssets.Icons[id] else UIAssets.Icons.Empty
	return new("ImageLabel", {
		Name = "Shard",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = image,
		ZIndex = z or 1,
		Parent = parent,
	})
end

local function skillInSlot(slot)
	if slot == "M1" then
		return "RiftBolt", 1
	end
	local id = build.Slots[slot]
	return id, id and build.Skills[id]
end

local function skillColor(id)
	local def = id and Skills.Defs[id]
	return if def then Elements.ColorOf(def.Elements) else C.Ash
end

-- Short headline stat for a skill at a level, e.g. ("Damage", "55").
local function headlineStat(def, level)
	local mult = Skills.DamageMult(level or 1)
	if def.Kind == "Zone" then
		return "Damage per tick", string.format("%d  ·  %d sec", math.floor(def.TickDamage * mult + 0.5), def.Duration)
	elseif def.Kind == "Chain" then
		return "Damage", string.format("%d  ·  %d jumps", math.floor(def.Damage * mult + 0.5), def.Jumps)
	end
	return "Damage", tostring(math.floor(def.Damage * mult + 0.5))
end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

local function buildTooltip()
	tooltip = slab({ Name = "Tooltip", Size = UDim2.fromOffset(290, 120), Visible = false, ZIndex = 50, Parent = gui })
	local content = new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = tooltip,
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	text({ Name = "Title", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), FontFace = F.TitleBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = content })
	text({ Name = "Meta", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = content })
	text({
		Name = "Body",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 160),
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = F.Body,
		TextSize = 13,
		TextWrapped = true,
		RichText = true,
		TextColor3 = Color3.fromRGB(217, 201, 173),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 52,
		Parent = content,
	})

	RunService.RenderStepped:Connect(function()
		if tooltip.Visible then
			tooltip.Size = UDim2.fromOffset(290, 32 + 24 + 4 + 14 + 4 + content.Body.TextBounds.Y + 18)
			local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			local size = tooltip.AbsoluteSize
			local screen = gui.AbsoluteSize
			local x = math.min(mouse.X + 18, screen.X - size.X - 8)
			local y = mouse.Y + 18
			if y + size.Y > screen.Y - 8 then
				y = mouse.Y - size.Y - 12
			end
			tooltip.Position = UDim2.fromOffset(x, y)
		end
	end)
end

local function showTooltip(id, level)
	local content = tooltip.Content
	local def = id and Skills.Defs[id]
	if id == "Dash" then
		content.Title.Text = DASH_INFO.Name
		content.Title.TextColor3 = C.RiftHot
		content.Meta.Text = "MOVEMENT  ·  SHIFT"
		content.Body.Text = DASH_INFO.Description
	elseif def then
		content.Title.Text = def.Name .. (if level and id ~= "RiftBolt" then "  " .. NUMERALS[level] else "")
		content.Title.TextColor3 = skillColor(id)
		local elements = if #def.Elements > 0 then table.concat(def.Elements, " + "):upper() else "RIFT"
		content.Meta.Text = string.format("%s  ·  %s  ·  %.1fs", elements, def.Kind:upper(), Skills.CooldownOf(id, level or 1))
		local label, value = headlineStat(def, level)
		content.Body.Text = emphasize(def.Description) .. `\n<font color="{hex(C.Ash)}">> {label}</font>   <font color="{hex(C.Good)}">{value}</font>`
	else
		return
	end
	tooltip.Visible = true
end

local function hideTooltip()
	tooltip.Visible = false
end

local function hoverable(guiObject, getInfo)
	guiObject.MouseEnter:Connect(function()
		showTooltip(getInfo())
	end)
	guiObject.MouseLeave:Connect(hideTooltip)
end

-------------------------------------------------------------------------------
-- Toasts: small banners that drop in under the top of the screen
-------------------------------------------------------------------------------

function HUD.Toast(message, color)
	local band = new("ImageLabel", {
		Size = UDim2.fromOffset(520, 58),
		BackgroundTransparency = 1,
		Image = UIAssets.Banner,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.BannerSlice,
		SliceScale = 0.45,
		ImageTransparency = 1,
		Parent = toastHolder,
	})
	local label = text({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 1, -12),
		Text = message,
		FontFace = F.TitleBold,
		TextSize = 22,
		TextColor3 = color or C.Gold,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		Parent = band,
	})
	tween(band, 0.25, { ImageTransparency = 0.05 })
	tween(label, 0.25, { TextTransparency = 0 })
	task.delay(2.4, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(band, 0.45, { ImageTransparency = 1 }).Completed:Wait()
		band:Destroy()
	end)
end

-------------------------------------------------------------------------------
-- Vitals: level shard, HP and rift essence (top-left)
-------------------------------------------------------------------------------

local function buildVitals()
	local root = new("Frame", {
		Name = "Vitals",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(360, 100),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local medal = new("ImageLabel", {
		Name = "Medallion",
		Size = UDim2.fromOffset(86, 86),
		BackgroundTransparency = 1,
		Image = UIAssets.Medallion,
		ZIndex = 5,
		Parent = root,
	})
	text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 12), Text = "L V", FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 6, Parent = medal })
	local levelText = text({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 34), Text = "1", FontFace = F.TitleBold, TextSize = 32, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, ZIndex = 6, Parent = medal })

	local bar = new("ImageLabel", {
		Name = "HealthBar",
		Position = UDim2.fromOffset(70, 20),
		Size = UDim2.fromOffset(276, 34),
		BackgroundTransparency = 1,
		Image = UIAssets.Bar,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.BarSlice,
		SliceScale = 0.7,
		ZIndex = 3,
		Parent = root,
	})
	local track = new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(16, 7),
		Size = UDim2.new(1, -36, 1, -14),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = bar,
	})
	local lag = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 214, 180),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = track,
	})
	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	}, { new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 92, 78), Color3.fromRGB(110, 9, 20)), Rotation = 90 }) })
	new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.Grain,
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		ZIndex = 5,
		Parent = track,
	})
	local hpText = text({
		Size = UDim2.fromScale(1, 1),
		FontFace = F.Label,
		TextSize = 14,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		ZIndex = 6,
		Parent = track,
	})

	local xpTrack = new("Frame", {
		Position = UDim2.fromOffset(86, 58),
		Size = UDim2.fromOffset(230, 6),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Parent = root,
	}, { stroke(C.Bronze, 1, 0.35) })
	local xpFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = xpTrack,
	}, { new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(90, 34, 176), C.RiftHot) }) })
	local xpText = text({
		Position = UDim2.fromOffset(86, 68),
		Size = UDim2.fromOffset(260, 14),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		Parent = root,
	})

	local hurt = new("ImageLabel", {
		Name = "HurtFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.Vignette,
		ImageColor3 = C.Crimson,
		ImageTransparency = 1,
		Parent = fxGui,
	})

	local function refreshProgress()
		local level = player:GetAttribute("Level") or 1
		local xp = player:GetAttribute("Xp") or 0
		local toNext = player:GetAttribute("XpToNext") or Progression.XpToNext(level)
		levelText.Text = tostring(level)
		if toNext > 0 then
			xpText.Text = `{xp} / {toNext}   ·   R I F T   E S S E N C E`
			tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(xp / toNext, 0, 1), 1) })
		else
			xpText.Text = "M A S T E R Y   A T T A I N E D"
			xpFill.Size = UDim2.fromScale(1, 1)
		end
	end
	for _, name in { "Level", "Xp", "XpToNext" } do
		player:GetAttributeChangedSignal(name):Connect(refreshProgress)
	end
	local lastLevel = player:GetAttribute("Level") or 1
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level") or 1
		if level > lastLevel then
			medal.Size = UDim2.fromOffset(104, 104)
			medal.Position = UDim2.fromOffset(-9, -9)
			tween(medal, 0.5, { Size = UDim2.fromOffset(86, 86), Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
		end
		lastLevel = level
	end)
	refreshProgress()

	local connections = {}
	local function bindCharacter(char)
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		local hum = char:WaitForChild("Humanoid")
		local last = hum.Health
		local function refresh()
			local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			hpText.Text = `{math.ceil(hum.Health)} / {math.floor(hum.MaxHealth)}`
			fill.Size = UDim2.fromScale(frac, 1)
			if hum.Health < last then
				hurt.ImageTransparency = 0.2
				tween(hurt, 0.6, { ImageTransparency = 1 })
				task.delay(0.3, function()
					tween(lag, 0.4, { Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1) })
				end)
			else
				lag.Size = UDim2.fromScale(frac, 1)
			end
			last = hum.Health
		end
		table.insert(connections, hum.HealthChanged:Connect(refresh))
		table.insert(connections, hum:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
		refresh()
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

-------------------------------------------------------------------------------
-- Gold (top-right)
-------------------------------------------------------------------------------

local function buildGold()
	local box = new("Frame", {
		Name = "Gold",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(190, 64),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local plate = slab({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(160, 50), Parent = box })
	local coin = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1,
		Image = UIAssets.Coin,
		ZIndex = 5,
		Parent = box,
	})
	local amount = text({
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = "0",
		FontFace = F.TitleBold,
		TextSize = 26,
		TextColor3 = C.Gold,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
		Parent = plate,
	})

	local last = player:GetAttribute("Gold") or 0
	local function refresh()
		local gold = player:GetAttribute("Gold") or 0
		amount.Text = tostring(gold)
		if gold > last then
			coin.Rotation = -25
			tween(coin, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
			local pop = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -20, 0, 76),
				Size = UDim2.fromOffset(120, 22),
				Text = `+{gold - last}`,
				FontFace = F.TitleBold,
				TextSize = 22,
				TextColor3 = C.Gold,
				TextStrokeColor3 = C.Ink,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = gui,
			})
			tween(pop, 0.9, { Position = UDim2.new(1, -20, 0, 100), TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(0.9, function()
				pop:Destroy()
			end)
		end
		last = gold
	end
	player:GetAttributeChangedSignal("Gold"):Connect(refresh)
	refresh()
end

-------------------------------------------------------------------------------
-- Ability shards (bottom-left)
-------------------------------------------------------------------------------

local function makeSlot(parent, entry, index)
	local holder = new("Frame", {
		Name = entry.Slot,
		Position = UDim2.new(0, (index - 1) * 96, 1, -(ICON + 46) - entry.Lift),
		Size = UDim2.fromOffset(ICON + 12, ICON + 46),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	-- Soft element-coloured glow behind the shard.
	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(ICON * 0.95, ICON * 0.95),
		BackgroundColor3 = C.Rift,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = holder,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local iconHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = holder,
	})
	-- Cooldown: the shard image darkened from the top down.
	local shade = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(ICON * 0.74, 0),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = holder,
	})
	local timer = text({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(ICON + 12, ICON),
		FontFace = F.TitleBold,
		TextSize = 30,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0,
		ZIndex = 5,
		Parent = holder,
	})
	local keyPlate = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ICON - 8),
		Size = UDim2.fromOffset(50, 18),
		BackgroundColor3 = C.Ink,
		ZIndex = 6,
		Parent = holder,
	}, { stroke(C.Bronze, 1.5) })
	text({ Size = UDim2.fromScale(1, 1), Text = entry.Key, FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 7, Parent = keyPlate })
	local name = text({
		Position = UDim2.fromOffset(-10, ICON + 13),
		Size = UDim2.new(1, 20, 0, 30),
		FontFace = F.BodyBold,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		Parent = holder,
	})
	slotCards[entry.Slot] = { Halo = halo, IconHolder = iconHolder, Shade = shade, Timer = timer, Name = name, Shown = false, Cooling = false }
	hoverable(holder, function()
		if entry.Slot == "Dash" then
			return "Dash"
		end
		return skillInSlot(entry.Slot)
	end)
end

local function refreshSlots()
	for _, entry in SLOTS do
		local card = slotCards[entry.Slot]
		local id, level = nil, nil
		if entry.Slot == "Dash" then
			id = "Dash"
		else
			id, level = skillInSlot(entry.Slot)
		end
		local key = tostring(id) .. tostring(level)
		if card.Shown ~= key then
			card.Shown = key
			card.IconHolder:ClearAllChildren()
			shard(id, ICON, card.IconHolder, 2)
			local def = id and Skills.Defs[id]
			if id == "Dash" then
				card.Name.Text = "Dash"
				card.Halo.BackgroundColor3 = C.Rift
			else
				card.Name.Text = if def then def.Name .. (if level and entry.Slot ~= "M1" then "  " .. NUMERALS[level] else "") else "—"
				card.Halo.BackgroundColor3 = skillColor(id)
			end
			card.Halo.BackgroundTransparency = if id then 0.78 else 0.95
		end
	end
end

local function updateCooldowns()
	local now = os.clock()
	for _, entry in SLOTS do
		local card = slotCards[entry.Slot]
		local cd
		if entry.Slot == "Dash" then
			cd = dash
		else
			local id = skillInSlot(entry.Slot)
			cd = id and cooldownEnds[id]
		end
		local remaining = if cd then cd.Ends - now else 0
		if remaining > 0 then
			card.Cooling = true
			card.Shade.Size = UDim2.fromOffset(ICON * 0.74, (ICON - 16) * math.clamp(remaining / cd.Length, 0, 1))
			card.Timer.Text = if remaining >= 1 then tostring(math.ceil(remaining)) else ""
		elseif card.Cooling then
			card.Cooling = false
			card.Shade.Size = UDim2.fromOffset(ICON * 0.74, 0)
			card.Timer.Text = ""
			card.Halo.BackgroundTransparency = 0.3
			card.Halo.Size = UDim2.fromOffset(ICON * 1.25, ICON * 1.25)
			tween(card.Halo, 0.4, { BackgroundTransparency = 0.78, Size = UDim2.fromOffset(ICON * 0.95, ICON * 0.95) })
		end
	end
end

-------------------------------------------------------------------------------
-- Arsenal: owned skills with Q/E equip (left)
-------------------------------------------------------------------------------

local function sortedOwned()
	local ids = {}
	for id in build.Skills do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local da, db = Skills.Defs[a], Skills.Defs[b]
		if #da.Elements ~= #db.Elements then
			return #da.Elements > #db.Elements
		end
		return da.Name < db.Name
	end)
	return ids
end

local function buildArsenal()
	arsenal = slab({
		Name = "Arsenal",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.47, 0),
		Size = UDim2.fromOffset(280, 310),
		Parent = gui,
	})
	text({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 24), Text = spaced("Arsenal"), FontFace = F.Title, TextSize = 20, TextColor3 = C.Parchment, Parent = arsenal })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(150, 2), BackgroundColor3 = C.Rift, BorderSizePixel = 0, Parent = arsenal }, {
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	text({
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "F  INTERACT    ·    SHIFT  DASH    ·    WHEEL  ZOOM",
		FontFace = F.Label,
		TextSize = 10,
		TextColor3 = C.Ash,
		Parent = arsenal,
	})
	text({
		Name = "Empty",
		Position = UDim2.fromOffset(24, 84),
		Size = UDim2.new(1, -48, 0, 70),
		Text = "No powers yet.\nSeek the elemental shrines and press F.",
		FontFace = F.Italic,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = C.Ash,
		Parent = arsenal,
	})
	new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(14, 72),
		Size = UDim2.new(1, -28, 1, -88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Bronze,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
		Parent = arsenal,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 4) }),
	})
end

local function refreshArsenal()
	local list = arsenal.List
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local owned = sortedOwned()
	arsenal.Empty.Visible = #owned == 0
	for i, id in owned do
		local def = Skills.Defs[id]
		local level = build.Skills[id]
		local color = skillColor(id)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			ZIndex = 2,
			Parent = list,
		}, {
			new("UIGradient", {
				Color = ColorSequence.new(color, C.Ink),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 0.5) }),
			}),
			stroke(C.Bronze, 1, 0.55),
		})
		local s = shard(id, 44, row, 3)
		s.Position = UDim2.fromOffset(2, 1)
		text({
			Position = UDim2.fromOffset(50, 5),
			Size = UDim2.new(1, -124, 0, 18),
			Text = def.Name,
			FontFace = F.TitleBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextStrokeColor3 = C.Ink,
			TextStrokeTransparency = 0.4,
			ZIndex = 3,
			Parent = row,
		})
		text({
			Position = UDim2.fromOffset(50, 25),
			Size = UDim2.new(1, -124, 0, 14),
			Text = `<font color="{hex(C.Gold)}">{NUMERALS[level]}</font>   {if #def.Elements == 2 then "F U S I O N" else spaced(def.Elements[1])}`,
			RichText = true,
			FontFace = F.Label,
			TextSize = 10,
			TextColor3 = C.Ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = row,
		})
		for j, slot in { "Q", "E" } do
			local equipped = build.Slots[slot] == id
			local chip = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6 - (2 - j) * 32, 0.5, 0),
				Size = UDim2.fromOffset(28, 26),
				Text = slot,
				FontFace = F.Label,
				TextSize = 13,
				AutoButtonColor = true,
				BackgroundColor3 = if equipped then C.Gold else C.Ink,
				TextColor3 = if equipped then C.Ink else C.Ash,
				ZIndex = 3,
				Parent = row,
			}, { stroke(if equipped then C.Gold else C.Bronze, 1.5) })
			chip.Activated:Connect(function()
				remotes.Equip:FireServer(slot, id)
			end)
		end
		hoverable(row, function()
			return id, build.Skills[id]
		end)
	end
end

-------------------------------------------------------------------------------
-- The Forge: "Choose one fusion"
-------------------------------------------------------------------------------

local refreshForge

local function buildForge()
	forgeShade = new("Frame", {
		Name = "ForgeShade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = fxGui,
	}, {
		new("ImageLabel", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Vignette, ImageTransparency = 1 }),
	})

	forge = new("Frame", {
		Name = "Forge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(660, 600),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	new("UIScale", { Parent = forge })

	local body = slab({ Name = "Body", Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 1, -92), ZIndex = 20, Parent = forge })
	-- Rift light seeping up from the bottom of the slab.
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 150),
		BackgroundColor3 = C.Rift,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = body,
	}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.84) }) })

	local banner = new("ImageLabel", {
		Name = "Banner",
		Position = UDim2.fromOffset(-30, 0),
		Size = UDim2.new(1, 60, 0, 104),
		BackgroundTransparency = 1,
		Image = UIAssets.Banner,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.BannerSlice,
		SliceScale = 0.8,
		ZIndex = 22,
		Parent = forge,
	})
	text({
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 40),
		Text = spaced("The Forge"),
		FontFace = F.Title,
		TextSize = 38,
		TextColor3 = C.Parchment,
		TextStrokeColor3 = C.RiftDeep,
		TextStrokeTransparency = 0.4,
		ZIndex = 23,
		Parent = banner,
	})
	text({
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "W H E R E   T H E   R I F T   T E A R S ,   E L E M E N T S   B L E E D   I N T O   O N E",
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Gold,
		ZIndex = 23,
		Parent = banner,
	})

	local close = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 112),
		Size = UDim2.fromOffset(34, 34),
		Text = "X",
		FontFace = F.TitleBold,
		TextSize = 18,
		TextColor3 = C.Gold,
		AutoButtonColor = true,
		BackgroundColor3 = C.Ink,
		ZIndex = 24,
		Parent = forge,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(C.Bronze, 2) })
	close.Activated:Connect(function()
		HUD.SetForge(false)
	end)

	text({
		Position = UDim2.fromOffset(40, 116),
		Size = UDim2.fromOffset(300, 28),
		Text = "Choose one fusion",
		FontFace = F.TitleBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = forge,
	})
	new("Frame", { Position = UDim2.fromOffset(40, 148), Size = UDim2.fromOffset(52, 2), BackgroundColor3 = C.Crimson, BorderSizePixel = 0, ZIndex = 22, Parent = forge })
	text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, 124),
		Size = UDim2.fromOffset(240, 16),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		Parent = forge,
	})

	new("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.fromOffset(28, 160),
		Size = UDim2.new(1, -56, 1, -186),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Bronze,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
		Parent = forge,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
end

-- Every fusion the player could make right now: { A, B, Result }.
local function availableFusions()
	local bases = {}
	for _, element in Elements.Order do
		local id = Skills.BaseFor(element)
		if id and build.Skills[id] then
			table.insert(bases, id)
		end
	end
	local out = {}
	for i = 1, #bases do
		for j = i + 1, #bases do
			local result = Merge.Result(bases[i], bases[j])
			if result then
				table.insert(out, { A = bases[i], B = bases[j], Result = result })
			end
		end
	end
	return out
end

local function fusionRow(parent, option, order)
	local a, b, r = Skills.Defs[option.A], Skills.Defs[option.B], Skills.Defs[option.Result]
	local level = Merge.ResultLevel(build.Skills[option.A], build.Skills[option.B])
	if build.Skills[option.Result] then
		level = math.min(math.max(build.Skills[option.Result], level) + 1, Skills.MaxLevel)
	end
	local color = Elements.ColorOf(r.Elements)

	local row = new("ImageButton", {
		Name = option.Result,
		Size = UDim2.new(1, 0, 0, 128),
		BackgroundTransparency = 1,
		Image = UIAssets.Row,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.RowSlice,
		SliceScale = 0.6,
		AutoButtonColor = false,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	})
	-- Element-coloured wash from the left, brightened on hover.
	local wash = new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
		ZIndex = 22,
		Parent = row,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.55, 0.95), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	local icon = shard(option.Result, 104, row, 23)
	icon.Position = UDim2.fromOffset(16, 12)

	text({
		Position = UDim2.fromOffset(134, 16),
		Size = UDim2.new(1, -290, 0, 26),
		Text = r.Name,
		FontFace = F.TitleBold,
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.4,
		ZIndex = 23,
		Parent = row,
	})
	local tag = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 18),
		Size = UDim2.fromOffset(150, 20),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		ZIndex = 23,
		Parent = row,
	}, { stroke(C.Rift, 1) })
	text({
		Size = UDim2.fromScale(1, 1),
		Text = spaced(r.Elements[1] .. "+" .. r.Elements[2]):gsub("%+", " + "),
		FontFace = F.Label,
		TextSize = 10,
		TextColor3 = C.RiftHot,
		ZIndex = 24,
		Parent = tag,
	})
	text({
		Position = UDim2.fromOffset(134, 46),
		Size = UDim2.new(1, -160, 0, 40),
		Text = emphasize(`Fuse {a.Name} and {b.Name}. {r.Description}`, { a.Name, b.Name }),
		RichText = true,
		FontFace = F.Body,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(217, 201, 173),
		ZIndex = 23,
		Parent = row,
	})
	local label, value = headlineStat(r, level)
	text({
		Position = UDim2.fromOffset(134, 94),
		Size = UDim2.fromOffset(250, 16),
		Text = `>  {label}   ·   Rank {NUMERALS[level]}`,
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = row,
	})
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 94),
		Size = UDim2.fromOffset(160, 16),
		Text = value,
		FontFace = F.Label,
		TextSize = 13,
		TextColor3 = C.Good,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 23,
		Parent = row,
	})

	local hoverStroke = stroke(color, 2, 1)
	hoverStroke.Parent = wash
	row.MouseEnter:Connect(function()
		tween(wash.UIGradient, 0.15, { Offset = Vector2.new(0.15, 0) })
		tween(hoverStroke, 0.15, { Transparency = 0.1 })
		tween(icon, 0.15, { Size = UDim2.fromOffset(112, 112), Position = UDim2.fromOffset(12, 8) })
	end)
	row.MouseLeave:Connect(function()
		tween(wash.UIGradient, 0.15, { Offset = Vector2.new(0, 0) })
		tween(hoverStroke, 0.15, { Transparency = 1 })
		tween(icon, 0.15, { Size = UDim2.fromOffset(104, 104), Position = UDim2.fromOffset(16, 12) })
	end)
	row.Activated:Connect(function()
		local ok, result = remotes.Merge:InvokeServer(option.A, option.B)
		if ok then
			HUD.SetForge(false)
		else
			HUD.Toast(result or "The Forge refuses.", Color3.fromRGB(255, 120, 110))
		end
	end)
end

refreshForge = function()
	if not forge then
		return
	end
	local list = forge.Options
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local options = availableFusions()
	for i, option in options do
		fusionRow(list, option, i)
	end
	if #options == 0 then
		text({
			Size = UDim2.new(1, 0, 0, 120),
			Text = "The Forge is cold.\nCarry at least two different elements to bind them.",
			FontFace = F.Italic,
			TextSize = 20,
			TextWrapped = true,
			TextColor3 = C.Ash,
			ZIndex = 23,
			Parent = list,
		})
	end
	local known, total = 0, 0
	for _, id in Merge.All() do
		total += 1
		if discovered[id] then
			known += 1
		end
	end
	forge.Count.Text = `C O D E X   {known} / {total}   D I S C O V E R E D`
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function HUD.ForgeOpen()
	return forge ~= nil and forge.Visible
end

function HUD.SetForge(open)
	if open == forge.Visible then
		return
	end
	hideTooltip()
	if open then
		refreshForge()
		forge.Visible = true
		forgeShade.Visible = true
		arsenal.Visible = false
		forge.UIScale.Scale = 0.92
		tween(forge.UIScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		forgeShade.BackgroundTransparency = 1
		forgeShade.Vignette.ImageTransparency = 1
		tween(forgeShade, 0.25, { BackgroundTransparency = 0.5 })
		tween(forgeShade.Vignette, 0.25, { ImageTransparency = 0 })
	else
		forge.Visible = false
		forgeShade.Visible = false
		arsenal.Visible = true
	end
end

function HUD.ToggleForge()
	HUD.SetForge(not forge.Visible)
end

-- Starts the local cooldown for a slot. Returns false if it is still cooling down.
function HUD.TryStartCooldown(slot)
	local id, level = skillInSlot(slot)
	if not id or not level then
		return false
	end
	local now = os.clock()
	local cd = cooldownEnds[id]
	if cd and now < cd.Ends then
		return false
	end
	local length = Skills.CooldownOf(id, level)
	cooldownEnds[id] = { Ends = now + length, Length = length }
	return true
end

function HUD.StartDashCooldown(length)
	dash = { Ends = os.clock() + length, Length = length }
end

local function applyBuild(snapshot)
	build = snapshot
	for id in build.Skills do
		discovered[id] = true
	end
	refreshSlots()
	refreshArsenal()
	refreshForge()
end

function HUD.Init(remoteFolder)
	remotes = remoteFolder
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)

	local playerGui = player:WaitForChild("PlayerGui")
	gui = new("ScreenGui", {
		Name = "RiftboundHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	fxGui = new("ScreenGui", {
		Name = "RiftboundFX",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1,
		Parent = playerGui,
	})

	buildVitals()
	buildGold()

	local bar = new("Frame", {
		Name = "SkillBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -10),
		Size = UDim2.fromOffset(4 * 96, ICON + 60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for i, entry in SLOTS do
		makeSlot(bar, entry, i)
	end

	buildArsenal()

	toastHolder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(520, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	buildForge()
	buildTooltip()

	remotes.BuildChanged.OnClientEvent:Connect(applyBuild)
	remotes.Notify.OnClientEvent:Connect(HUD.Toast)
	remotes.OpenForge.OnClientEvent:Connect(function()
		HUD.SetForge(true)
	end)
	applyBuild(remotes.GetBuild:InvokeServer())

	RunService.RenderStepped:Connect(updateCooldowns)
end

return HUD
