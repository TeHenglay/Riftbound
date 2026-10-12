-- Riftbound HUD in the shared modern theme (Theme.lua): flat dark panels with
-- hard black edges and square corners, diamond skill icons, crimson vitals,
-- lettered in BuilderSans. The art is drawn by
-- tools/art/build.js and referenced through ReplicatedStorage.Riftbound.UIAssets.
-- Contains the vitals (level/HP/XP), gold, ability shards, the Arsenal list,
-- tooltips, toasts and the Forge ("choose one fusion").
local GuiService = game:GetService("GuiService")
local screenCenter -- defined with HUD.Style below
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Items = require(Shared:WaitForChild("Items"))
local Merge = require(Shared:WaitForChild("Merge"))
local Progression = require(Shared:WaitForChild("Progression"))
local Skills = require(Shared:WaitForChild("Skills"))
local Stats = require(Shared:WaitForChild("Stats"))
local Nations = require(Shared:WaitForChild("Nations"))
local Runes = require(Shared:WaitForChild("Runes"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local Theme = require(Shared:WaitForChild("Theme"))

-- Colours and fonts come from the shared modern theme (Theme.lua).
local C = Theme.Palette()

local F = Theme.F

local NUMERALS = { "I", "II", "III", "IV", "V" }
local KEYWORDS = {}
for _, word in { "Burns", "Burning", "Burn", "Slows", "Slow", "Soaks", "Soaked", "Soak", "Stuns", "Stun", "Shocked", "Shock", "Pulls", "Freezing", "Freezes", "Freeze", "Frozen", "Ablaze" } do
	table.insert(KEYWORDS, word)
	table.insert(KEYWORDS, word:lower())
end

-- Fixed slots always hold the same ability (Fixed = its id).
local SLOTS = {
	{ Slot = "M1", Key = "LMB" },
	{ Slot = "M2", Key = "RMB", Fixed = "Block" },
	{ Slot = "Q", Key = "Q" },
	{ Slot = "E", Key = "E" },
	{ Slot = "Dash", Key = "SHIFT", Fixed = "Dash" },
}
local ICON = 84
-- Skill slots are diamond icons (black border baked into the art), drawn a
-- little larger than ICON since a diamond fills less of its box.
local DIAMOND = ICON + 8
local SKILL_ART = 512 -- source pixel size of the skill icons (for cropping)
local FIXED_INFO = {
	AutoCast = { Name = "Auto-cast", Meta = "CLICK TO TOGGLE  ·  ONE SLOT", Subtitle = "A U T O", Description = "Casts this slot by itself at the nearest enemy whenever it's ready. Only one slot can auto-cast at a time; click again to turn it off." },
	Dash = { Name = "Dash", Meta = "MOVEMENT  ·  SHIFT", Subtitle = "M O V E M E N T", Description = "A swift dash through danger. Use it to reposition and escape." },
	Block = { Name = "Block", Meta = "DEFENSE  ·  HOLD RMB", Subtitle = "D E F E N S E", Description = "Hold to raise a rift shield that stops enemy attacks. You move at half speed and it breaks after 3 seconds. Block right as a hit lands to parry: the attacker is stunned and knocked back." },
}

local HUD = {}

local player = Players.LocalPlayer
local remotes
local build = { Skills = {}, Slots = {}, Sockets = {}, Pouch = {} }
local discovered = {}
local cooldownEnds = {} -- [skillId] = { Ends, Length }
local dash = { Ends = 0, Length = 1 }
local block = { Ends = 0, Length = 1 }
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
		LineJoinMode = Enum.LineJoinMode.Miter,
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

-- A flat dark panel with a hard black edge (the old obsidian slab art is gone).
local function slab(props)
	props.Image = ""
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.C.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.06
	props.BorderSizePixel = 0
	props.ScaleType = nil
	props.SliceCenter = nil
	props.SliceScale = nil
	local panel = new("ImageLabel", props)
	Theme.Edged().Parent = panel
	return panel
end

-- Crystal-shard icon for a skill (or "Dash" / nil for empty).
-- Awakened skills get a living frame: a gold -> cyan -> violet diamond border
-- that slowly turns and pulses, an outer halo and a crystal on the top tip.
-- One loop animates every frame on screen.
local AWAKEN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 92)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(110, 232, 255)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(196, 124, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 92)),
})
local awakenFrames = setmetatable({}, { __mode = "k" }) -- [gradient] = { Halo = stroke }
local awakenLoop

local function awakenFrame(icon, size, z)
	local function diamond(scale, thickness, transparency)
		local frame = new("Frame", {
			Name = "AwakenFrame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			Rotation = 45,
			BackgroundTransparency = 1,
			ZIndex = z + 1,
			Parent = icon,
		})
		local edge = new("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = thickness,
			Transparency = transparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Miter,
			Parent = frame,
		})
		local gradient = new("UIGradient", { Color = AWAKEN_GRADIENT, Parent = edge })
		return gradient, edge
	end
	-- The inner border sits on the icon art's black edge and paints over it.
	local inner = diamond(0.62, math.max(3, size * 0.065), 0)
	-- The outer halo stays inside the icon's own square so it never runs into
	-- the icons beside it.
	local outerGradient, halo = diamond(0.69, math.max(1, size * 0.02), 0.35)
	awakenFrames[inner] = { Speed = 1 }
	awakenFrames[outerGradient] = { Speed = -0.6, Halo = halo }
	-- Crystal on the top tip.
	new("Frame", {
		Name = "AwakenCrystal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromOffset(math.max(5, size * 0.11), math.max(5, size * 0.11)),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(150, 240, 255),
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = icon,
	}, { new("UIStroke", { Color = Color3.fromRGB(255, 230, 140), Thickness = 1 }) })
	if not awakenLoop then
		awakenLoop = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			for gradient, info in awakenFrames do
				if gradient:IsDescendantOf(game) then
					gradient.Rotation = (t * 120 * info.Speed) % 360
					if info.Halo then
						info.Halo.Transparency = 0.35 + 0.3 * math.sin(t * 3)
					end
				else
					awakenFrames[gradient] = nil
				end
			end
		end)
	end
end

local function shard(id, size, parent, z)
	local image = if id == "Dash" then UIAssets.Icons.Dash elseif id and UIAssets.Icons[id] then UIAssets.Icons[id] else UIAssets.Icons.Empty
	local icon = new("ImageLabel", {
		Name = "Shard",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = image,
		ZIndex = z or 1,
		Parent = parent,
	})
	local def = id and Skills.Defs[id]
	if def and def.Awakened then
		awakenFrame(icon, size, z or 1)
	end
	return icon
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
	if def.Kind == "Zone" or def.Kind == "Tornado" then
		return "Damage per tick", string.format("%d  ·  %d sec", math.floor(def.TickDamage * mult + 0.5), def.Duration)
	elseif def.Kind == "Chain" then
		return "Damage", string.format("%d  ·  %d jumps", math.floor(def.Damage * mult + 0.5), def.Jumps)
	elseif def.Kind == "Serpent" then
		return "Damage", string.format("%d  ·  up to %d bites", math.floor(def.Damage * mult + 0.5), def.Jumps)
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
	if id == "Flask" then
		local charges, max = player:GetAttribute("FlaskCharges") or 0, player:GetAttribute("FlaskMax") or 0
		content.Title.Text = "Rift Flask"
		content.Title.TextColor3 = Color3.fromRGB(255, 96, 114)
		content.Meta.Text = `CONSUMABLE  ·  R  ·  {charges} / {max} CHARGES`
		content.Body.Text = emphasize("Drink to restore 35% of your health. You are slowed while you sip. Holds 3 charges.")
			.. `\n<font color="{hex(C.Ash)}">> Refill at the Rift Well or by levelling up</font>`
	elseif FIXED_INFO[id] then
		local info = FIXED_INFO[id]
		content.Title.Text = info.Name
		content.Title.TextColor3 = C.RiftHot
		content.Meta.Text = info.Meta
		content.Body.Text = emphasize(info.Description)
	elseif def then
		content.Title.Text = def.Name .. (if level and id ~= "RiftBolt" then "  " .. NUMERALS[level] else "")
		content.Title.TextColor3 = skillColor(id)
		local elements = if #def.Elements > 0 then table.concat(def.Elements, " + "):upper() else "RIFT"
		content.Meta.Text = string.format("%s  ·  %s  ·  %.1fs", elements, def.Kind:upper(), Skills.CooldownOf(id, level or 1) * Stats.CooldownMult(player:GetAttribute("Stat_Focus")) * Nations.CooldownMult(player))
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

	local medal = new("Frame", {
		Name = "Medallion",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(92, 92),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = root,
	})
	-- The diamond is three squares turned 45 degrees: a black edge, a gold ring
	-- and a dark core. Sides are 1/sqrt(2) of the box so the tips touch its edges,
	-- and they scale with it for the level-up bounce.
	local SIDE = 1 / math.sqrt(2)
	local function diamond(name, inset, color, z)
		return new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(SIDE, -inset, SIDE, -inset),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = medal,
		})
	end
	diamond("Edge", 0, Color3.fromRGB(0, 0, 0), 8)
	local gold = diamond("Gold", 6, Color3.new(1, 1, 1), 8)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 222, 120), Color3.fromRGB(196, 140, 40)),
		Rotation = 45,
		Parent = gold,
	})
	diamond("Core", 16, Color3.fromRGB(12, 12, 18), 9)
	text({
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "LV",
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(240, 195, 65),
		ZIndex = 10,
		Parent = medal,
	})
	local levelText = text({
		Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "1",
		FontFace = F.TitleBold,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.2,
		ZIndex = 10,
		Parent = medal,
	})

	-- Health Bar: 100% sharp 90-degree rectangle with crisp black border (zero UIStroke/UICorner)
	local bar = new("Frame", {
		Name = "HealthBar",
		Position = UDim2.fromOffset(62, 22),
		Size = UDim2.fromOffset(260, 24),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = root,
	})
	local track = new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = Color3.fromRGB(15, 10, 18),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = bar,
	})
	local lag = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 214, 180),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = track,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(235, 48, 56), Color3.fromRGB(130, 12, 22)),
			Rotation = 90,
		}),
	})
	local hpText = text({
		Size = UDim2.fromScale(1, 1),
		FontFace = F.BodyBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.1,
		ZIndex = 7,
		Parent = track,
	})

	-- Shorter EXP bar directly underneath the health bar, matching the user sketch
	local xpBar = new("Frame", {
		Name = "EXPBar",
		Position = UDim2.fromOffset(62, 48),
		Size = UDim2.fromOffset(180, 10),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = root,
	})
	local xpTrack = new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = Color3.fromRGB(15, 10, 18),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = xpBar,
	})
	local xpFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = xpTrack,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(165, 80, 255), Color3.fromRGB(110, 40, 220)),
		}),
	})
	-- Compact XP text tucked in the notch directly to the right of the EXP bar
	local xpText = text({
		Position = UDim2.fromOffset(248, 46),
		Size = UDim2.fromOffset(80, 14),
		FontFace = F.Label,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(190, 175, 215),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.3,
		ZIndex = 4,
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
			xpText.Text = `{xp}/{toNext} XP`
			tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(xp / toNext, 0, 1), 1) })
		else
			xpText.Text = "MAX"
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
			medal.Size = UDim2.fromOffset(106, 106)
			medal.Position = UDim2.fromOffset(-7, -7)
			tween(medal, 0.5, { Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
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
-- Gold (top-left, below the level diamond)
-------------------------------------------------------------------------------

local GOLD_X, GOLD_Y = 22, 112 -- home spot: under the level diamond
local GOLD_W, GOLD_H = 140, 30
local goldBox

local function buildGold()
	-- Sharp flat plate with a hard black edge, matching the bars above it.
	local box = new("Frame", {
		Name = "Gold",
		Position = UDim2.fromOffset(GOLD_X, GOLD_Y),
		Size = UDim2.fromOffset(GOLD_W, GOLD_H),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = gui,
	})
	goldBox = box
	local plate = new("Frame", {
		Name = "Plate",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = Theme.C.Panel,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = box,
	})
	local coin = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Image = UIAssets.Coin,
		ZIndex = 7,
		Parent = plate,
	})
	local amount = text({
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Text = "0",
		FontFace = F.TitleBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 215, 90),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
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
				Position = UDim2.new(1, 8, 0, 4),
				Size = UDim2.fromOffset(80, 20),
				Text = `+{gold - last}`,
				FontFace = F.TitleBold,
				TextSize = 18,
				TextColor3 = C.Gold,
				TextStrokeColor3 = C.Ink,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 8,
				Parent = box,
			})
			tween(pop, 0.9, { Position = UDim2.new(1, 8, 0, -10), TextTransparency = 1, TextStrokeTransparency = 1 })
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
-- Runes (this run only): socket pips over the LMB / Q / E shards, socket cells
-- in the Backpack, and the "Rune found" card that sockets the oldest pouch
-- rune (buttons or keys 1 / 2 / 3). Everything hides outside a story run.
-------------------------------------------------------------------------------

local runeCard
local runePips = {} -- [slot] = { pip frames }
local runeDismissed = 0 -- pouch size when "Later" was pressed
local runeBusy = false

local function inRun()
	return player:GetAttribute("StoryRun") ~= nil
end

-- The runes socketed into the skill equipped in `slot` (runes follow skills).
local function socketsOf(slot)
	local skillId = skillInSlot(slot)
	return skillId and (build.Sockets or {})[skillId] or {}
end

local function runeColor(id)
	local def = Runes.Defs[id]
	return if def then Runes.Rarity[def.Rarity].Color else C.Ash
end

local function showRuneTooltip(id)
	local def = Runes.Defs[id]
	if not def then
		return
	end
	local content = tooltip.Content
	content.Title.Text = def.Name
	content.Title.TextColor3 = runeColor(id)
	content.Meta.Text = `{spaced(def.Rarity)}   ·   R U N E   ·   T H I S   R U N`
	local details = Runes.Details[id]
	content.Body.Text = emphasize(def.Effect) .. (if details then `\n<font color="{hex(C.Ash)}">{details}</font>` else "")
	tooltip.Visible = true
end

local function socketRune(slot)
	local pouch = build.Pouch or {}
	if runeBusy or not pouch[1] or not runeCard or not runeCard.Visible then
		return
	end
	runeBusy = true
	local ok, done, why = pcall(remotes.Rune.InvokeServer, remotes.Rune, "Socket", 1, slot)
	runeBusy = false
	if not ok or not done then
		HUD.Toast(if ok then (why or "Can't socket that") else "Couldn't reach the server", C.Crimson)
	end
end

local function buildRuneCard()
	runeCard = slab({
		Name = "RuneCard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(310, 236),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	text({ Name = "Kicker", Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 0, 14), FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = runeCard })
	text({ Name = "Title", Position = UDim2.fromOffset(22, 34), Size = UDim2.new(1, -44, 0, 26), FontFace = F.TitleBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 31, Parent = runeCard })
	text({ Name = "Rarity", Position = UDim2.fromOffset(22, 60), Size = UDim2.new(1, -44, 0, 14), FontFace = F.Label, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = runeCard })
	text({ Name = "Effect", Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 0, 38), FontFace = F.Body, TextSize = 15, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31, Parent = runeCard })
	local row = new("Frame", {
		Name = "Slots",
		Position = UDim2.fromOffset(22, 122),
		Size = UDim2.new(1, -44, 0, 62),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = runeCard,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, slot in Runes.Slots do
		local b = new("TextButton", {
			Name = slot,
			Size = UDim2.new(1 / #Runes.Slots, -4, 1, 0),
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = C.Ink,
			LayoutOrder = i,
			ZIndex = 32,
			Parent = row,
		}, { corner(3), stroke(C.Bronze, 1.2, 0.3) })
		text({ Name = "Key", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 14), Text = `{i}  ·  {Runes.SlotKeys[slot]}`, FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 33, Parent = b })
		text({ Name = "Skill", Position = UDim2.fromOffset(4, 20), Size = UDim2.new(1, -8, 0, 18), FontFace = F.BodyBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 33, Parent = b })
		text({ Name = "Count", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 14), FontFace = F.Label, TextSize = 11, TextColor3 = C.Ash, ZIndex = 33, Parent = b })
		b.Activated:Connect(function()
			socketRune(slot)
		end)
	end
	local later = new("TextButton", {
		Name = "Later",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 194),
		Size = UDim2.fromOffset(150, 24),
		Text = "L A T E R   ( B )",
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = runeCard,
	})
	later.Activated:Connect(function()
		runeDismissed = #(build.Pouch or {})
		runeCard.Visible = false
	end)
	runeCard.MouseEnter:Connect(hideTooltip)
end

local function refreshRunes()
	local shown = inRun()
	for slot, pips in runePips do
		local list = socketsOf(slot)
		for i, pip in pips do
			local id = list[i]
			pip.Visible = shown
			pip.BackgroundColor3 = if id then runeColor(id) else C.Ink
			pip.BackgroundTransparency = if id then 0 else 0.3
		end
	end
	if not runeCard then
		return
	end
	local pouch = build.Pouch or {}
	runeDismissed = math.min(runeDismissed, #pouch)
	local id = pouch[1]
	local def = id and Runes.Defs[id]
	if not shown or not def or #pouch <= runeDismissed or build.Offer then
		runeCard.Visible = false
		return
	end
	local color = runeColor(id)
	runeCard.Kicker.Text = "R U N E   F O U N D" .. (if #pouch > 1 then `   ·   +{#pouch - 1}   M O R E` else "")
	runeCard.Title.Text = def.Name
	runeCard.Title.TextColor3 = color
	runeCard.Rarity.Text = spaced(def.Rarity)
	runeCard.Rarity.TextColor3 = color
	runeCard.Effect.Text = emphasize(def.Effect)
	for _, slot in Runes.Slots do
		local b = runeCard.Slots[slot]
		local list = socketsOf(slot)
		local skill = Skills.Defs[(skillInSlot(slot))]
		local ok, why = Runes.CanSocket(list, id)
		if not skill then
			ok, why = false, "No skill"
		end
		b.Skill.Text = if skill then skill.Name else "Empty"
		b.Skill.TextColor3 = if ok then C.Parchment else C.Ash
		b.Count.Text = if ok then `{#list} / {Runes.Sockets}` else why:upper()
		b.UIStroke.Color = if ok then color else C.Bronze
		b.AutoButtonColor = ok
	end
	runeCard.Visible = true
end

-------------------------------------------------------------------------------
-- Rune pick: after each cleared wave the run pauses (Runes.PickTime) and three
-- rune cards come up. Click a key under a card to socket it into that skill,
-- or keep it in the pouch. When time runs out the server picks one for you.
-------------------------------------------------------------------------------

local offerScreen
local offerShown -- the offer table currently drawn
local offerKey -- which offer was last animated in (so re-draws don't replay it)

-- Rune screen sounds; SoundFX is set up by SoundBoot, so play softly if it isn't ready.
local SoundFX
do
	local ok, module = pcall(require, script.Parent:WaitForChild("SoundFX", 5))
	SoundFX = if ok then module else nil
end
local function playSound(name)
	if SoundFX then
		pcall(SoundFX.Play, name)
	end
end

local function chooseRune(index, slot)
	if runeBusy then
		return
	end
	runeBusy = true
	local ok, done, why = pcall(remotes.Rune.InvokeServer, remotes.Rune, "Choose", index, slot)
	runeBusy = false
	if not ok or not done then
		HUD.Toast(if ok then (why or "Can't take that rune") else "Couldn't reach the server", C.Crimson)
	else
		playSound("RunePick")
	end
end

local OFFER_H = 510 -- pick screen height: title row + cards
local CARD_H = 424

local function buildOfferScreen()
	offerScreen = new("Frame", {
		Name = "RuneOffer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 40,
		-- Its own screen that ignores the top-bar inset, so the dim covers the
		-- whole display (the inset isn't known yet when the HUD is built).
		Parent = new("ScreenGui", {
			Name = "RiftboundRuneOffer",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 5,
			Parent = gui.Parent,
		}),
	})
	local holder = new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, OFFER_H),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = offerScreen,
	}, { new("UIScale", {}) })
	text({ Name = "Header", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 40), Text = spaced("Choose a Rune"), FontFace = F.Title, TextSize = 34, TextStrokeColor3 = C.RiftDeep, TextStrokeTransparency = 0.4, ZIndex = 41, Parent = holder })
	text({ Name = "Timer", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), FontFace = F.Label, TextSize = 13, TextColor3 = C.Gold, ZIndex = 41, Parent = holder })
	local row = new("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, CARD_H),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = holder,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i = 1, Runes.Choices do
		local card = slab({ Name = "Card" .. i, Size = UDim2.fromOffset(255, CARD_H), LayoutOrder = i, ZIndex = 41, Parent = row })
		new("UIScale", { Name = "Pop", Parent = card })
		-- A rarity-coloured flash that fades as the card lands.
		new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 46, Parent = card })
		new("Frame", { Name = "Glow", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 4), BorderSizePixel = 0, ZIndex = 42, Parent = card })
		text({ Name = "Title", Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -40, 0, 52), FontFace = F.TitleBold, TextSize = 21, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
		text({ Name = "Rarity", Position = UDim2.fromOffset(20, 82), Size = UDim2.new(1, -40, 0, 14), FontFace = F.Label, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
		text({ Name = "Effect", Position = UDim2.fromOffset(20, 104), Size = UDim2.new(1, -40, 0, 42), FontFace = F.BodyBold, TextSize = 15, TextWrapped = true, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
		-- How the rune works in more detail (Runes.Details), under a thin rule.
		new("Frame", { Position = UDim2.fromOffset(20, 152), Size = UDim2.new(1, -40, 0, 1), BackgroundColor3 = C.Ash, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 42, Parent = card })
		text({ Name = "Details", Position = UDim2.fromOffset(20, 160), Size = UDim2.new(1, -40, 0, 112), FontFace = F.Body, TextSize = 13, TextColor3 = C.Gold, TextWrapped = true, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
		text({ Position = UDim2.fromOffset(20, 280), Size = UDim2.new(1, -40, 0, 14), Text = "S O C K E T   I N T O", FontFace = F.Label, TextSize = 10, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
		local keys = new("Frame", {
			Name = "Slots",
			Position = UDim2.fromOffset(18, 298),
			Size = UDim2.new(1, -36, 0, 66),
			BackgroundTransparency = 1,
			ZIndex = 42,
			Parent = card,
		}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for j, slot in Runes.Slots do
			local b = new("TextButton", {
				Name = slot,
				Size = UDim2.new(1 / #Runes.Slots, -4, 1, 0),
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = C.Ink,
				LayoutOrder = j,
				ZIndex = 43,
				Parent = keys,
			}, { corner(3), stroke(C.Bronze, 1.2, 0.3) })
			text({ Name = "Key", Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14), Text = Runes.SlotKeys[slot], FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 44, Parent = b })
			text({ Name = "Skill", Position = UDim2.fromOffset(3, 22), Size = UDim2.new(1, -6, 0, 18), FontFace = F.BodyBold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 44, Parent = b })
			text({ Name = "Count", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 14), FontFace = F.Label, TextSize = 10, TextColor3 = C.Ash, ZIndex = 44, Parent = b })
			b.Activated:Connect(function()
				chooseRune(i, slot)
			end)
		end
		local keep = new("TextButton", {
			Name = "Keep",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 376),
			Size = UDim2.new(1, -36, 0, 30),
			Text = "K E E P   I N   P O U C H",
			FontFace = F.Label,
			TextSize = 11,
			TextColor3 = C.Ash,
			AutoButtonColor = true,
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.4,
			ZIndex = 43,
			Parent = card,
		}, { corner(3), stroke(C.Bronze, 1, 0.6) })
		keep.Activated:Connect(function()
			chooseRune(i, nil)
		end)
	end
	RunService.RenderStepped:Connect(function()
		if offerScreen.Visible and offerShown then
			local left = math.max(0, math.ceil(offerShown.Ends - workspace:GetServerTimeNow()))
			holder.Timer.Text = `T H E   R I F T   H O L D S   ·   {left}s`
			local view = workspace.CurrentCamera.ViewportSize
			holder.UIScale.Scale = math.min(1, (view.X - 24) / 820, (view.Y - 24) / OFFER_H)
		end
	end)
end

-- The pick screen arriving: the dim fades in, the title drops, and the cards
-- spin and pop in one after another with a flash of their rarity colour.
local function animateOffer(offer)
	local holder = offerScreen.Holder
	offerScreen.BackgroundTransparency = 1
	tween(offerScreen, 0.3, { BackgroundTransparency = 0.4 })
	holder.Header.TextTransparency = 1
	holder.Header.Position = UDim2.fromOffset(0, -24)
	tween(holder.Header, 0.4, { TextTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	playSound("RuneOffer")
	for i = 1, Runes.Choices do
		local card = holder.Cards["Card" .. i]
		local id = offer.Ids[i]
		local def = id and Runes.Defs[id]
		card.Pop.Scale = 0.05
		card.Rotation = if i % 2 == 0 then 12 else -12
		card.Flash.BackgroundColor3 = if def then runeColor(id) else Color3.new(1, 1, 1)
		card.Flash.BackgroundTransparency = 0
		task.delay(0.12 + (i - 1) * 0.14, function()
			if offerKey ~= offer.Ends then
				return -- a newer offer (or none) replaced this one
			end
			tween(card.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(card, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
			tween(card.Flash, 0.6, { BackgroundTransparency = 1 })
			playSound(if def and def.Rarity == "Legendary" then "RuneLegendary" else "RuneCard")
		end)
	end
end

local function refreshOffer()
	if not offerScreen then
		return
	end
	local offer = build.Offer
	if not offer or not inRun() then
		offerShown = nil
		offerKey = nil
		offerScreen.Visible = false
		return
	end
	offerShown = offer
	hideTooltip()
	for i = 1, Runes.Choices do
		local card = offerScreen.Holder.Cards["Card" .. i]
		local id = offer.Ids[i]
		local def = id and Runes.Defs[id]
		card.Visible = def ~= nil
		if def then
			local color = runeColor(id)
			card.Glow.BackgroundColor3 = color
			card.Title.Text = def.Name
			card.Title.TextColor3 = color
			card.Rarity.Text = spaced(def.Rarity)
			card.Rarity.TextColor3 = color
			card.Effect.Text = emphasize(def.Effect)
			card.Details.Text = emphasize(Runes.Details[id] or "")
			for _, slot in Runes.Slots do
				local b = card.Slots[slot]
				local skillId = skillInSlot(slot)
				local list = socketsOf(slot)
				local ok, why = Runes.CanSocket(list, id)
				if not skillId then
					ok, why = false, "No skill"
				end
				-- Allowed, but warn when the rune would do nothing for this skill.
				local useful, reason = Runes.Applies(id, skillId and Skills.Defs[skillId])
				b.Skill.Text = if skillId then Skills.Defs[skillId].Name else "Empty"
				b.Skill.TextColor3 = if ok and useful then C.Parchment else C.Ash
				b.Count.Text = if not ok then why:upper() elseif not useful then reason:upper() else `{#list} / {Runes.Sockets}`
				b.Count.TextColor3 = if ok and not useful then C.Crimson else C.Ash
				b.UIStroke.Color = if ok and useful then color else C.Bronze
				b.AutoButtonColor = ok
			end
		end
	end
	offerScreen.Visible = true
	-- Build updates re-draw the cards; only a new offer plays the entrance.
	if offerKey ~= offer.Ends then
		offerKey = offer.Ends
		animateOffer(offer)
	end
end

-- Keys 1 / 2 / 3 socket the shown rune into LMB / Q / E (see Controls).
function HUD.RuneHotkey(n)
	local slot = Runes.Slots[n]
	if slot then
		socketRune(slot)
	end
end

-------------------------------------------------------------------------------
-- Ability shards (bottom-left)
-------------------------------------------------------------------------------

-- Auto-cast: one skill slot (LMB, Q or E) can cast itself at the nearest
-- enemy whenever it's ready. A small diamond above each skill slot toggles
-- it: green fill (black edge) when on, and the slot's border turns green.
local AUTO_GREEN = Color3.fromRGB(80, 230, 110)
local autoSlot -- "M1" | "Q" | "E" | nil
local autoToggles = {} -- [slot] = { Button, Ring }

local function refreshAuto()
	for slot, ui in autoToggles do
		local on = slot == autoSlot
		ui.Button.BackgroundColor3 = if on then AUTO_GREEN else Color3.fromRGB(24, 24, 32)
		ui.Ring.Visible = on
	end
end

function HUD.AutoSlot()
	return autoSlot
end

function HUD.SetAutoSlot(slot)
	autoSlot = if slot == autoSlot then nil else slot -- clicking the active one turns it off
	refreshAuto()
end

local function makeSlot(parent, entry, index)
	local holder = new("Frame", {
		Name = entry.Slot,
		Position = UDim2.new(0, (index - 1) * 96, 1, -(ICON + 46)),
		Size = UDim2.fromOffset(ICON + 12, ICON + 46),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	-- Soft element-coloured diamond glow behind the icon.
	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(DIAMOND * 0.74, DIAMOND * 0.74),
		Rotation = 45,
		BackgroundColor3 = C.Rift,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = holder,
	})
	local iconHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(DIAMOND, DIAMOND),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = holder,
	})
	-- Cooldown: the icon itself tinted dark and cropped from the top down, so
	-- the shade keeps the diamond shape.
	local shade = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ICON / 2 - DIAMOND / 2),
		Size = UDim2.fromOffset(DIAMOND, 0),
		BackgroundTransparency = 1,
		ImageColor3 = C.Ink,
		ImageTransparency = 0.3,
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
	-- Auto-cast toggle (skill slots only; not Block, Dash or the flask).
	if not entry.Fixed then
		local ring = new("Frame", {
			Name = "AutoRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, ICON / 2),
			Size = UDim2.fromOffset(DIAMOND * 0.62, DIAMOND * 0.62),
			Rotation = 45,
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 5,
			Parent = holder,
		}, {
			-- Sits on the icon art's black edge and turns it green.
			new("UIStroke", { Color = AUTO_GREEN, Thickness = math.max(3, DIAMOND * 0.065), LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local toggle = new("TextButton", {
			Name = "AutoToggle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, -32),
			Size = UDim2.fromOffset(17, 17),
			Rotation = 45,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Color3.fromRGB(24, 24, 32),
			ZIndex = 8,
			Parent = holder,
		}, { new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		toggle.Activated:Connect(function()
			HUD.SetAutoSlot(entry.Slot)
		end)
		toggle.MouseEnter:Connect(function()
			showTooltip("AutoCast")
		end)
		toggle.MouseLeave:Connect(hideTooltip)
		autoToggles[entry.Slot] = { Button = toggle, Ring = ring }
	end
	-- Rune socket pips above the shard (only skill slots have sockets).
	if Runes.SlotKeys[entry.Slot] then
		local pips = {}
		for i = 1, Runes.Sockets do
			pips[i] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, (i - (Runes.Sockets + 1) / 2) * 16, 0, -12),
				Size = UDim2.fromOffset(9, 9),
				Rotation = 45,
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.3,
				Visible = false,
				ZIndex = 6,
				Parent = holder,
			}, { stroke(C.Bronze, 1, 0.3) })
		end
		runePips[entry.Slot] = pips
	end
	hoverable(holder, function()
		if entry.Fixed then
			return entry.Fixed
		end
		return skillInSlot(entry.Slot)
	end)
end

local function refreshSlots()
	for _, entry in SLOTS do
		local card = slotCards[entry.Slot]
		local id, level = nil, nil
		if entry.Fixed then
			id = entry.Fixed
		else
			id, level = skillInSlot(entry.Slot)
		end
		local key = tostring(id) .. tostring(level)
		if card.Shown ~= key then
			card.Shown = key
			card.IconHolder:ClearAllChildren()
			card.Shade.Image = shard(id, DIAMOND, card.IconHolder, 2).Image
			local def = id and Skills.Defs[id]
			if FIXED_INFO[id] then
				card.Name.Text = FIXED_INFO[id].Name
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
		elseif entry.Slot == "M2" then
			cd = block
		else
			local id = skillInSlot(entry.Slot)
			cd = id and cooldownEnds[id]
		end
		local remaining = if cd then cd.Ends - now else 0
		if remaining > 0 then
			card.Cooling = true
			local frac = math.clamp(remaining / cd.Length, 0, 1)
			card.Shade.Size = UDim2.fromOffset(DIAMOND, DIAMOND * frac)
			card.Shade.ImageRectSize = Vector2.new(SKILL_ART, SKILL_ART * frac)
			card.Timer.Text = if remaining >= 1 then tostring(math.ceil(remaining)) else ""
		elseif card.Cooling then
			card.Cooling = false
			card.Shade.Size = UDim2.fromOffset(DIAMOND, 0)
			card.Timer.Text = ""
			card.Halo.BackgroundTransparency = 0.3
			card.Halo.Size = UDim2.fromOffset(DIAMOND, DIAMOND)
			tween(card.Halo, 0.4, { BackgroundTransparency = 0.78, Size = UDim2.fromOffset(DIAMOND * 0.74, DIAMOND * 0.74) })
		end
	end
end

-------------------------------------------------------------------------------
-- Flask (bottom-right corner)
-------------------------------------------------------------------------------

local FLASK_RED = Color3.fromRGB(255, 74, 94)

-- The flask is the last slot of the skill bar, right after SHIFT.
local function buildFlask()
	local holder = new("Frame", {
		Name = "Flask",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18 + #SLOTS * 96, 1, -6),
		Size = UDim2.fromOffset(ICON + 12, ICON + 50),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Diamond slot like the skill shards: a soft red glow, a black-edged
	-- diamond with a dark red core, and the potion art standing upright on top.
	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(DIAMOND * 0.74, DIAMOND * 0.74),
		Rotation = 45,
		BackgroundColor3 = FLASK_RED,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = holder,
	})
	local side = DIAMOND / math.sqrt(2)
	new("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(side, side),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = holder,
	})
	new("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(side - 10, side - 10),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = holder,
	}, {
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(92, 24, 36), Color3.fromRGB(28, 8, 14)), Rotation = 90 }),
	})
	local ART = math.floor(DIAMOND * 0.62)
	local icon = new("ImageLabel", {
		Name = "Shard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON / 2),
		Size = UDim2.fromOffset(ART, ART),
		BackgroundTransparency = 1,
		Image = UIAssets.Icons.Flask,
		ZIndex = 3,
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
	text({ Size = UDim2.fromScale(1, 1), Text = "R", FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 7, Parent = keyPlate })
	local pips = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ICON + 16),
		Size = UDim2.fromOffset(ICON, 14),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
		}),
	})
	local label = text({
		Position = UDim2.fromOffset(-10, ICON + 31),
		Size = UDim2.new(1, 20, 0, 16),
		FontFace = F.BodyBold,
		TextSize = 12,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		Parent = holder,
	})

	local last = player:GetAttribute("FlaskCharges") or 0
	local function refresh()
		local charges = player:GetAttribute("FlaskCharges") or 0
		local max = player:GetAttribute("FlaskMax") or 0
		for _, child in pips:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i = 1, max do
			local full = i <= charges
			new("Frame", {
				Size = UDim2.fromOffset(9, 9),
				Rotation = 45,
				BackgroundColor3 = if full then FLASK_RED else C.Ink,
				LayoutOrder = i,
				Parent = pips,
			}, { stroke(if full then Color3.fromRGB(255, 190, 196) else C.Bronze, 1.2) })
		end
		label.Text = `Flask  {charges}/{max}`
		icon.ImageColor3 = if charges > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(110, 100, 105)
		halo.BackgroundTransparency = if charges > 0 then 0.8 else 0.95
		if charges < last then
			-- Drank: the shard pulses and the halo flares.
			icon.Size = UDim2.fromOffset(ART * 1.2, ART * 1.2)
			tween(icon, 0.35, { Size = UDim2.fromOffset(ART, ART) }, Enum.EasingStyle.Back)
			halo.BackgroundTransparency = 0.2
			tween(halo, 0.5, { BackgroundTransparency = if charges > 0 then 0.8 else 0.95 })
		end
		last = charges
	end
	player:GetAttributeChangedSignal("FlaskCharges"):Connect(refresh)
	player:GetAttributeChangedSignal("FlaskMax"):Connect(refresh)
	refresh()
	hoverable(holder, function()
		return "Flask"
	end)
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

local ARSENAL_W, ARSENAL_H = 300, 440

-- One Q / E equip button: filled with the skill's colour when equipped there.
local function equipChip(parent, slot, id, color, x)
	local equipped = build.Slots[slot] == id
	local chip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Text = slot,
		FontFace = F.BodyBold,
		TextSize = 14,
		AutoButtonColor = true,
		BackgroundColor3 = if equipped then color else Theme.C.Panel,
		TextColor3 = if equipped then Theme.C.Ink else C.Ash,
		ZIndex = 4,
		Parent = parent,
	}, { Theme.Edged(2) })
	chip.Activated:Connect(function()
		remotes.Equip:FireServer(slot, id)
	end)
	return chip
end

local function buildArsenal()
	arsenal = slab({
		Name = "Arsenal",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.47, 0),
		Size = UDim2.fromOffset(ARSENAL_W, ARSENAL_H),
		Parent = gui,
	})
	-- Header: title and how many skills you own.
	text({ Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 26), Text = "Skill Set", FontFace = F.TitleBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Parent = arsenal })
	text({ Name = "Count", Position = UDim2.fromOffset(16, 18), Size = UDim2.new(1, -32, 0, 20), FontFace = F.Body, TextSize = 13, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Right, Parent = arsenal })

	-- Equipped strip: what is on Q and E right now.
	local strip = new("Frame", { Name = "Equipped", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 96), BackgroundTransparency = 1, Parent = arsenal }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, slot in { "Q", "E" } do
		local box = new("Frame", { Name = slot, Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Theme.C.Raised, LayoutOrder = i, Parent = strip }, { Theme.Edged(2) })
		new("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(50, 50), BackgroundTransparency = 1, ZIndex = 2, Parent = box })
		local key = new("Frame", { Position = UDim2.fromOffset(-2, -2), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Theme.C.Ink, ZIndex = 4, Parent = box }, { Theme.Edged(1.5) })
		text({ Size = UDim2.fromScale(1, 1), Text = slot, FontFace = F.BodyBold, TextSize = 11, ZIndex = 5, Parent = key })
		-- ("Title", not "Name": box.Name is the Instance's own name property.)
		text({ Name = "Title", Position = UDim2.fromOffset(4, 58), Size = UDim2.new(1, -8, 0, 18), FontFace = F.BodyBold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = box })
		text({ Name = "Detail", Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 14), FontFace = F.Body, TextSize = 11, TextColor3 = C.Ash, ZIndex = 2, Parent = box })
		hoverable(box, function()
			return skillInSlot(slot)
		end)
	end
	new("Frame", { Position = UDim2.fromOffset(12, 156), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = arsenal })

	text({
		Name = "Empty",
		Position = UDim2.fromOffset(20, 176),
		Size = UDim2.new(1, -40, 0, 60),
		Text = "No skills yet.\nFind an elemental shrine and press F.",
		FontFace = F.Body,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = C.Ash,
		Parent = arsenal,
	})
	new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(12, 166),
		Size = UDim2.new(1, -24, 1, -204),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Ash,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
		Parent = arsenal,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2) }),
	})

	-- Key hints along the bottom.
	text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "F  Interact     R  Flask     B  Bag     C  Stats",
		FontFace = F.Body,
		TextSize = 11,
		TextColor3 = C.Ash,
		Parent = arsenal,
	})
end

local function refreshArsenal()
	-- Equipped strip.
	for _, slot in { "Q", "E" } do
		local box = arsenal.Equipped[slot]
		local id, level = skillInSlot(slot)
		local def = id and Skills.Defs[id]
		box.Icon:ClearAllChildren()
		shard(id, 50, box.Icon, 3)
		box.Title.Text = if def then def.Name else "Empty"
		box.Title.TextColor3 = if def then C.Parchment else C.Ash
		box.Detail.Text = if def then `Lv {level}  ·  {if #def.Elements == 2 then "Fusion" else def.Elements[1]}` else "Equip a skill below"
	end

	local list = arsenal.List
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local owned = sortedOwned()
	arsenal.Empty.Visible = #owned == 0
	arsenal.Count.Text = if #owned == 1 then "1 skill" else `{#owned} skills`
	for i, id in owned do
		local def = Skills.Defs[id]
		local level = build.Skills[id]
		local color = skillColor(id)
		local equipped = build.Slots.Q == id or build.Slots.E == id
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = if equipped then color:Lerp(Theme.C.Raised, 0.82) else Theme.C.Raised,
			LayoutOrder = i,
			ZIndex = 2,
			Parent = list,
		}, { Theme.Edged(2) })
		-- Element accent down the left edge.
		new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3, Parent = row })
		local s = shard(id, 46, row, 3)
		s.Position = UDim2.fromOffset(8, 4)
		text({
			Position = UDim2.fromOffset(60, 7),
			Size = UDim2.new(1, -136, 0, 20),
			Text = def.Name,
			FontFace = F.BodyBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
		-- Level pips (filled up to the skill's level) and the element.
		for pip = 1, Skills.MaxLevel do
			new("Frame", {
				Position = UDim2.fromOffset(62 + (pip - 1) * 11, 35),
				Size = UDim2.fromOffset(6, 6),
				Rotation = 45,
				BackgroundColor3 = if pip <= level then color else Theme.C.Ink,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = row,
			})
		end
		text({
			Position = UDim2.fromOffset(62 + Skills.MaxLevel * 11 + 4, 29),
			Size = UDim2.new(1, -200, 0, 16),
			Text = if #def.Elements == 2 then "Fusion" else (def.Elements[1] or "Rift"),
			FontFace = F.Body,
			TextSize = 11,
			TextColor3 = C.Ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = row,
		})
		equipChip(row, "Q", id, color, -44)
		equipChip(row, "E", id, color, -8)
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
	-- Matches BuildService.Merge: level 1, or the level you already have (plus a copy).
	local level = Merge.ResultLevel(build.Skills[option.A], build.Skills[option.B])
	if build.Skills[option.Result] then
		level = math.max(build.Skills[option.Result], level)
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
-- Arsenal collapse tab
-------------------------------------------------------------------------------

local ARSENAL_OPEN = UDim2.new(0, 14, 0.47, 0)
local ARSENAL_CLOSED = UDim2.new(0, -ARSENAL_W - 8, 0.47, 0) -- only the tab peeks out
local arsenalCollapsed = false

local function buildArsenalToggle()
	local tab = new("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 3, 0.5, 0),
		Size = UDim2.fromOffset(24, 64),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.C.Panel,
		ZIndex = 4,
		Parent = arsenal,
	}, { Theme.Edged(3) })
	local arrow = text({
		Size = UDim2.fromScale(1, 1),
		Text = "<",
		FontFace = F.TitleBold,
		TextSize = 20,
		TextColor3 = C.Parchment,
		ZIndex = 5,
		Parent = tab,
	})
	tab.Activated:Connect(function()
		arsenalCollapsed = not arsenalCollapsed
		arrow.Text = if arsenalCollapsed then ">" else "<"
		hideTooltip()
		tween(arsenal, 0.3, { Position = if arsenalCollapsed then ARSENAL_CLOSED else ARSENAL_OPEN }, Enum.EasingStyle.Quint)
	end)
	tab.MouseEnter:Connect(function()
		tab.BackgroundColor3 = Theme.C.Raised
	end)
	tab.MouseLeave:Connect(function()
		tab.BackgroundColor3 = Theme.C.Panel
	end)
end

-------------------------------------------------------------------------------
-- Backpack: equipment, stats, collected items and powers (B)
-------------------------------------------------------------------------------

local ITEM_CELLS = 18 -- 6 x 3 grid: room for every material
local inventory = {}
local backpack
local refreshBackpack, refreshSkillsTab, showBackpackTab
local levelBusy = false -- a Level Up request is on its way

local function showItemTooltip(id, count)
	local def = Items.Defs[id]
	local content = tooltip.Content
	content.Title.Text = def.Name
	content.Title.TextColor3 = def.Color
	content.Meta.Text = `{spaced(Items.Rarity[def.Rarity].Name)}   ·   x{count}`
	content.Body.Text = def.Description
	tooltip.Visible = true
end

local function sectionHeader(parent, title, x, y)
	text({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(240, 26),
		Text = title,
		FontFace = F.TitleBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = parent,
	})
	new("Frame", { Position = UDim2.fromOffset(x, y + 30), Size = UDim2.fromOffset(46, 2), BackgroundColor3 = C.Crimson, BorderSizePixel = 0, ZIndex = 22, Parent = parent })
end

-- Layout (pixels inside the panel). Left: equipment + stats. Right: an
-- inventory grid big enough for every material, then powers.
local BP_W, BP_H = 1000, 620
local BP_PAD = 32
local BP_LEFT_W = 420
local BP_RIGHT_X = BP_PAD + BP_LEFT_W + 24
local BP_RIGHT_W = BP_W - BP_RIGHT_X - BP_PAD
local BP_HEAD_Y = 84 -- section headers
local BP_TOP = 126 -- section content

local function clearGui(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-------------------------------------------------------------------------------
-- Backpack: Skills tab (every owned skill; level up with duplicate copies)
-------------------------------------------------------------------------------

local skillsTab
local skillsSelected -- skill id shown on the right
local backpackTab = "Items"
local SK_LIST_W = 400
local SK_DETAIL_X = BP_PAD + SK_LIST_W + 28
local SK_DETAIL_W = BP_W - SK_DETAIL_X - BP_PAD
local SK_CARD_GAP = 10
local SK_CARD_W = math.floor((SK_LIST_W - 10 - SK_CARD_GAP) / 2)
local SK_CARD_H = 196
local SK_GOLD = Color3.fromRGB(255, 214, 92)
local SK_GREEN = Color3.fromRGB(90, 220, 120)
local SK_PURPLE = Color3.fromRGB(178, 120, 255)

-- A rounded colour pill with text (element chips, badges).
local function pill(parent, label, bg, fg, x, y, h, z)
	local p = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, h),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = bg,
		ZIndex = z,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = label, FontFace = F.Label, TextSize = math.floor(h * 0.55), TextColor3 = fg, ZIndex = z + 1, Parent = p })
	return p
end

-- Rounded progress bar; returns the bar.
local function progressBar(parent, x, y, w, h, ratio, color, label, z)
	local bar = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(12, 12, 18), ZIndex = z, Parent = parent }, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	if ratio > 0 then
		new("Frame", { Size = UDim2.new(math.clamp(ratio, 0.06, 1), 0, 1, 0), BackgroundColor3 = color, ZIndex = z + 1, Parent = bar }, {
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color) }),
		})
	end
	if label then
		text({ Size = UDim2.fromScale(1, 1), Text = label, FontFace = F.Label, TextSize = math.floor(h * 0.62), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, ZIndex = z + 2, Parent = bar })
	end
	return bar
end

local function cooldownAt(id, level)
	return Skills.CooldownOf(id, level) * Stats.CooldownMult(player:GetAttribute("Stat_Focus")) * Nations.CooldownMult(player)
end

local function levelUp(id)
	if levelBusy then
		return
	end
	levelBusy = true
	local ok, done, why = pcall(remotes.LevelSkill.InvokeServer, remotes.LevelSkill, id)
	levelBusy = false
	if not ok or not done then
		HUD.Toast(if ok then (why or "Can't level up") else "Couldn't reach the server", C.Crimson)
	end
end

local function buildSkillsTab(tab)
	skillsTab = tab
	sectionHeader(tab, "Skills", BP_PAD, BP_HEAD_Y)
	text({
		Name = "Count",
		Position = UDim2.fromOffset(BP_PAD + 120, BP_HEAD_Y + 6),
		Size = UDim2.fromOffset(SK_LIST_W - 120, 16),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		Parent = tab,
	})
	new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(BP_PAD, BP_TOP),
		Size = UDim2.fromOffset(SK_LIST_W, BP_H - BP_TOP - 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Rift,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
		Parent = tab,
	}, {
		-- Two big cards per row.
		new("UIGridLayout", { CellSize = UDim2.fromOffset(SK_CARD_W, SK_CARD_H), CellPadding = UDim2.fromOffset(SK_CARD_GAP, SK_CARD_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8) }),
	})
	new("Frame", {
		Position = UDim2.fromOffset(SK_DETAIL_X - 14, BP_HEAD_Y),
		Size = UDim2.new(0, 1, 1, -BP_HEAD_Y - 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 22,
		Parent = tab,
	})
	new("Frame", { Name = "Detail", Position = UDim2.fromOffset(SK_DETAIL_X, BP_HEAD_Y), Size = UDim2.fromOffset(SK_DETAIL_W, BP_H - BP_HEAD_Y - 24), BackgroundTransparency = 1, ZIndex = 22, Parent = tab })
end

-- One card in the skill grid: big icon tinted in the skill's colour, name,
-- level diamonds, a copies bar and badges (equipped key, ready / max).
local function skillListRow(list, order, id)
	local def = Skills.Defs[id]
	local level = build.Skills[id]
	local color = skillColor(id)
	local copies = (build.Copies or {})[id] or 0
	local need = Skills.CopiesToLevel(level)
	local temp = (build.Temp or {})[id]
	local selected = id == skillsSelected
	local ready = need ~= nil and copies >= need and not temp
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ZIndex = 23,
		Parent = list,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Theme.C.Ink, if selected then 0.45 else 0.62), color:Lerp(Theme.C.Ink, 0.88)) }),
		new("UIStroke", {
			Color = if selected then Color3.new(1, 1, 1) elseif def.Awakened then SK_GOLD else color,
			Thickness = if selected then 3 else 1.5,
			Transparency = if selected then 0 else 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	local icon = shard(id, 88, card, 24)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 12)
	-- Equipped key in the top-left corner.
	local equippedOn = if build.Slots.Q == id then "Q" elseif build.Slots.E == id then "E" else nil
	if equippedOn then
		local key = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 27, Parent = card }, {
			new("UICorner", { CornerRadius = UDim.new(0, 7) }),
			new("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		text({ Size = UDim2.fromScale(1, 1), Text = equippedOn, FontFace = F.TitleBold, TextSize = 16, TextColor3 = Theme.C.Ink, ZIndex = 28, Parent = key })
	end
	-- Status badge in the top-right corner.
	local badge = if temp then { "TRAINING", SK_PURPLE } elseif not need then { "MAX", SK_GOLD } elseif ready then { "LEVEL UP!", SK_GREEN } else nil
	if badge then
		local b = pill(card, badge[1], badge[2], Theme.C.Ink, 0, 8, 20, 27)
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -8, 0, 8)
	end
	text({
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 34),
		Text = def.Name,
		FontFace = F.BodyBold,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = if def.Awakened then SK_GOLD else Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.6,
		ZIndex = 24,
		Parent = card,
	})
	-- Level diamonds.
	local pipsW = Skills.MaxLevel * 16
	for pip = 1, Skills.MaxLevel do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -pipsW / 2 + (pip - 0.5) * 16, 0, 152),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = if pip <= level then color:Lerp(Color3.new(1, 1, 1), 0.2) else Color3.fromRGB(16, 16, 22),
			BorderSizePixel = 0,
			ZIndex = 24,
			Parent = card,
		}, { new("UIStroke", { Color = if pip <= level then Color3.new(1, 1, 1) else color, Thickness = 1, Transparency = if pip <= level then 0.4 else 0.5 }) })
	end
	progressBar(card, 14, 168, SK_CARD_W - 28, 16, if need then copies / need else 1, if ready then SK_GREEN elseif not need then SK_GOLD else color, if temp then "BORROWED" elseif need then `{copies} / {need}` else "MAX LEVEL", 24)
	card.Activated:Connect(function()
		skillsSelected = id
		refreshSkillsTab()
	end)
	hoverable(card, function()
		return id, build.Skills[id]
	end)
end

-- The right side: a colourful banner for the selected skill, stat tiles,
-- the copies bar, a big Level Up button and the Q / E keys.
local function skillDetail(panel, id)
	local def = Skills.Defs[id]
	local level = build.Skills[id]
	local color = skillColor(id)
	local copies = (build.Copies or {})[id] or 0
	local need = Skills.CopiesToLevel(level)
	local temp = (build.Temp or {})[id]
	local ready = need ~= nil and copies >= need and not temp
	local W = SK_DETAIL_W

	-- Banner.
	local banner = new("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 23, Parent = panel }, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIGradient", { Rotation = 20, Color = ColorSequence.new(color:Lerp(Theme.C.Ink, 0.35), color:Lerp(Theme.C.Ink, 0.85)) }),
		new("UIStroke", { Color = if def.Awakened then SK_GOLD else color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local icon = shard(id, 118, banner, 25)
	icon.Position = UDim2.fromOffset(14, 16)
	text({ Position = UDim2.fromOffset(146, 16), Size = UDim2.new(1, -160, 0, 32), Text = def.Name, FontFace = F.TitleBold, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 25, Parent = banner })
	-- Element chips in each element's own colour, then the kind.
	local chips = new("Frame", { Position = UDim2.fromOffset(146, 54), Size = UDim2.new(1, -160, 0, 22), BackgroundTransparency = 1, ZIndex = 25, Parent = banner }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, el in def.Elements do
		pill(chips, el:upper(), Elements.List[el].Color, Theme.C.Ink, 0, 0, 22, 25).LayoutOrder = i
	end
	pill(chips, def.Kind:upper(), Color3.fromRGB(30, 30, 42), Color3.fromRGB(220, 220, 235), 0, 0, 22, 25).LayoutOrder = 9
	if def.Awakened then
		pill(banner, "AWAKENED", SK_GOLD, Theme.C.Ink, 146, 116, 22, 25)
	end
	-- Level: big badge + diamonds.
	local lvl = new("Frame", { Position = UDim2.fromOffset(146, 84), Size = UDim2.fromOffset(62, 26), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 25, Parent = banner }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})
	text({ Size = UDim2.fromScale(1, 1), Text = `LV {level}`, FontFace = F.TitleBold, TextSize = 16, TextColor3 = Theme.C.Ink, ZIndex = 26, Parent = lvl })
	for pip = 1, Skills.MaxLevel do
		new("Frame", {
			Position = UDim2.fromOffset(222 + (pip - 1) * 22, 90),
			Size = UDim2.fromOffset(13, 13),
			Rotation = 45,
			BackgroundColor3 = if pip <= level then Color3.new(1, 1, 1) else Color3.fromRGB(16, 16, 22),
			BorderSizePixel = 0,
			ZIndex = 25,
			Parent = banner,
		}, { new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.5 }) })
	end

	text({ Position = UDim2.fromOffset(4, 160), Size = UDim2.new(1, -8, 0, 50), Text = emphasize(def.Description), RichText = true, FontFace = F.Body, TextSize = 14, TextWrapped = true, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = panel })

	-- Stat tiles: now, and what the next level brings.
	local label, now = headlineStat(def, level)
	local _, nextValue = headlineStat(def, math.min(level + 1, Skills.MaxLevel))
	local tiles = {
		{ string.upper(label), now, nextValue, Color3.fromRGB(255, 120, 80) },
		{ "COOLDOWN", string.format("%.2fs", cooldownAt(id, level)), string.format("%.2fs", cooldownAt(id, math.min(level + 1, Skills.MaxLevel))), Color3.fromRGB(90, 170, 255) },
	}
	local tileW = math.floor((W - 10) / 2)
	for i, t in tiles do
		local tile = new("Frame", { Position = UDim2.fromOffset((i - 1) * (tileW + 10), 216), Size = UDim2.fromOffset(tileW, 78), BackgroundColor3 = t[4]:Lerp(Theme.C.Ink, 0.78), ZIndex = 23, Parent = panel }, {
			new("UICorner", { CornerRadius = UDim.new(0, 12) }),
			new("UIStroke", { Color = t[4], Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 14), Text = t[1], FontFace = F.Label, TextSize = 11, TextColor3 = t[4]:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24, Parent = tile })
		text({ Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -28, 0, 28), Text = t[2], FontFace = F.TitleBold, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24, Parent = tile })
		text({ Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 0, 16), Text = if need then `next level  →  {t[3]}` else "max level", FontFace = F.BodyBold, TextSize = 13, TextColor3 = if need then SK_GREEN else SK_GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24, Parent = tile })
	end

	-- Copies.
	text({ Position = UDim2.fromOffset(2, 306), Size = UDim2.new(1, 0, 0, 16), Text = "DUPLICATE COPIES", FontFace = F.Label, TextSize = 12, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = panel })
	progressBar(panel, 0, 326, W, 24, if need then copies / need else 1, if ready then SK_GREEN elseif not need then SK_GOLD else color, if temp then "BORROWED FOR TRAINING" elseif need then `{copies} / {need}  copies` else "MAX LEVEL", 23)
	text({ Position = UDim2.fromOffset(2, 354), Size = UDim2.new(1, 0, 0, 16), Text = "Copies drop from Story skill rewards and from fusing into a skill you own.", FontFace = F.Italic, TextSize = 12, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = panel })

	-- Level Up.
	local top, sub, bg, edge
	if temp then
		top, sub, bg, edge = "TRAINING SKILL", "borrowed skills can't level up", SK_PURPLE:Lerp(Theme.C.Ink, 0.7), SK_PURPLE
	elseif not need then
		top, sub, bg, edge = "MAX LEVEL", "this skill is fully powered up", SK_GOLD:Lerp(Theme.C.Ink, 0.7), SK_GOLD
	elseif ready then
		top, sub, bg, edge = "LEVEL UP!", `uses {need} copies  ·  becomes level {level + 1}`, Color3.fromRGB(40, 150, 72), SK_GREEN
	else
		top, sub, bg, edge = `COLLECT {need - copies} MORE {if need - copies == 1 then "COPY" else "COPIES"}`, `then level up to level {level + 1}`, Color3.fromRGB(26, 26, 36), Color3.fromRGB(80, 80, 100)
	end
	local up = new("TextButton", { Position = UDim2.fromOffset(0, 378), Size = UDim2.new(1, 0, 0, 62), Text = "", AutoButtonColor = ready, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 24, Parent = panel }, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(bg:Lerp(Color3.new(1, 1, 1), if ready then 0.2 else 0.05), bg) }),
		new("UIStroke", { Color = edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 28), Text = top, FontFace = F.TitleBold, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, ZIndex = 25, Parent = up })
	text({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 18), Text = sub, FontFace = F.Body, TextSize = 13, TextColor3 = Color3.fromRGB(225, 225, 235), ZIndex = 25, Parent = up })
	if ready then
		up.Activated:Connect(function()
			levelUp(id)
		end)
	end

	-- Equip keys.
	for i, slot in { "Q", "E" } do
		local on = build.Slots[slot] == id
		local b = new("TextButton", {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 5, 0, 450),
			Size = UDim2.new(0.5, -5, 0, 46),
			Text = "",
			AutoButtonColor = not on,
			BackgroundColor3 = if on then color else Color3.fromRGB(28, 28, 40),
			ZIndex = 24,
			Parent = panel,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 12) }),
			new("UIStroke", { Color = color, Thickness = 2, Transparency = if on then 0 else 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local key = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = if on then Theme.C.Ink else color, ZIndex = 25, Parent = b }, {
			new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
		text({ Size = UDim2.fromScale(1, 1), Text = slot, FontFace = F.TitleBold, TextSize = 17, TextColor3 = if on then color else Theme.C.Ink, ZIndex = 26, Parent = key })
		text({ Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0), Text = if on then "EQUIPPED" else `EQUIP ON {slot}`, FontFace = F.Label, TextSize = 14, TextColor3 = if on then Theme.C.Ink else Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25, Parent = b })
		if not on then
			b.Activated:Connect(function()
				remotes.Equip:FireServer(slot, id)
			end)
		end
	end
end

refreshSkillsTab = function()
	if not skillsTab or not skillsTab.Visible then
		return
	end
	local owned = sortedOwned()
	if not skillsSelected or not build.Skills[skillsSelected] then
		skillsSelected = owned[1]
	end
	local list = skillsTab.List
	clearGui(list)
	local ready = 0
	for i, id in owned do
		skillListRow(list, i, id)
		local need = Skills.CopiesToLevel(build.Skills[id])
		if need and ((build.Copies or {})[id] or 0) >= need and not (build.Temp or {})[id] then
			ready += 1
		end
	end
	skillsTab.Count.Text = (if #owned == 1 then "1   S K I L L" else `{#owned}   S K I L L S`) .. (if ready > 0 then `   ·   {ready}   R E A D Y` else "")
	local detail = skillsTab.Detail
	clearGui(detail)
	if skillsSelected then
		skillDetail(detail, skillsSelected)
	else
		text({ Size = UDim2.new(1, 0, 0, 60), Text = "No skills yet. Seek the elemental shrines or clear Story acts.", FontFace = F.Italic, TextSize = 17, TextWrapped = true, TextColor3 = C.Ash, ZIndex = 23, Parent = detail })
	end
end

showBackpackTab = function(name)
	backpackTab = name
	backpack.ItemsTab.Visible = name == "Items"
	backpack.SkillsTab.Visible = name == "Skills"
	for _, tab in backpack.Tabs:GetChildren() do
		if tab:IsA("TextButton") then
			local on = tab.Name == name
			tab.BackgroundColor3 = if on then C.Rift:Lerp(Theme.C.Ink, 0.35) else Theme.C.Raised
			tab.TextColor3 = if on then C.Parchment else C.Ash
		end
	end
	hideTooltip()
	refreshBackpack()
end

local function buildBackpack()
	backpack = new("Frame", {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = screenCenter(),
		Size = UDim2.fromOffset(BP_W, BP_H),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	new("UIScale", { Parent = backpack })
	slab({ Name = "Body", Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = backpack })

	-- Title inside the panel, top-left; close button top-right.
	text({ Position = UDim2.fromOffset(BP_PAD, 20), Size = UDim2.fromOffset(400, 34), Text = "Backpack", FontFace = F.TitleBold, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = backpack })
	text({ Position = UDim2.fromOffset(BP_PAD, 54), Size = UDim2.fromOffset(400, 16), Text = "What you carry through the Rift", FontFace = F.Body, TextSize = 14, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = backpack })
	new("Frame", { Position = UDim2.fromOffset(BP_PAD, 76), Size = UDim2.new(1, -BP_PAD * 2, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 22, Parent = backpack })

	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		FontFace = F.TitleBold,
		TextSize = 18,
		TextColor3 = C.Parchment,
		AutoButtonColor = true,
		BackgroundColor3 = Theme.C.Raised,
		ZIndex = 24,
		Parent = backpack,
	}, { stroke(C.Bronze, 2) })
	close.Activated:Connect(function()
		HUD.SetBackpack(false)
	end)

	-- Tabs: Items (equipment, inventory, powers) and Skills (list + level up).
	local itemsTab = new("Frame", { Name = "ItemsTab", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 21, Parent = backpack })
	local skillsTab = new("Frame", { Name = "SkillsTab", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 21, Parent = backpack })
	local tabRow = new("Frame", {
		Name = "Tabs",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 24),
		Size = UDim2.fromOffset(2 * 130 + 8, 34),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Parent = backpack,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, name in { "Items", "Skills" } do
		local tab = new("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(130, 34),
			Text = spaced(name),
			FontFace = F.Label,
			TextSize = 13,
			AutoButtonColor = true,
			LayoutOrder = i,
			ZIndex = 24,
			Parent = tabRow,
		}, { stroke(C.Bronze, 2) })
		tab.Activated:Connect(function()
			showBackpackTab(name)
		end)
	end
	buildSkillsTab(skillsTab)

	-- Left column: equipment + stats
	sectionHeader(itemsTab, "Equipment", BP_PAD, BP_HEAD_Y)
	new("Frame", {
		Name = "Equipment",
		Position = UDim2.fromOffset(BP_PAD, BP_TOP),
		Size = UDim2.fromOffset(BP_LEFT_W, 6 * 53),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = itemsTab,
	}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(BP_PAD, BP_TOP + 6 * 53 + 18),
		Size = UDim2.fromOffset(BP_LEFT_W, 100),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = itemsTab,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(136, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Divider between the columns.
	new("Frame", {
		Position = UDim2.fromOffset(BP_RIGHT_X - 13, BP_HEAD_Y),
		Size = UDim2.new(0, 1, 1, -BP_HEAD_Y - 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 22,
		Parent = itemsTab,
	})

	-- Right column: inventory + powers
	sectionHeader(itemsTab, "Inventory", BP_RIGHT_X, BP_HEAD_Y)
	text({
		Name = "ItemCount",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -BP_PAD, 0, BP_HEAD_Y + 6),
		Size = UDim2.fromOffset(260, 16),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		Parent = itemsTab,
	})
	new("Frame", {
		Name = "Items",
		Position = UDim2.fromOffset(BP_RIGHT_X, BP_TOP),
		Size = UDim2.fromOffset(BP_RIGHT_W, 3 * 72 + 2 * 10),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = itemsTab,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 72), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local powersY = BP_TOP + 3 * 72 + 2 * 10 + 26
	sectionHeader(itemsTab, "Powers", BP_RIGHT_X, powersY)
	-- Scrolls; click a power to open it in the Skills tab.
	new("ScrollingFrame", {
		Name = "Powers",
		Position = UDim2.fromOffset(BP_RIGHT_X, powersY + 42),
		Size = UDim2.fromOffset(BP_RIGHT_W, BP_H - powersY - 42 - 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Rift,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
		Parent = itemsTab,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(70, 86), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local function equipmentRow(parent, order, iconId, key, title, subtitle, color, hover, rightPad)
	rightPad = rightPad or 0
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new(color, C.Ink),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.68), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 0.45) }),
		}),
		stroke(C.Bronze, 1, 0.55),
	})
	local icon = shard(iconId, 46, row, 23)
	icon.Position = UDim2.fromOffset(2, 1)
	local plate = new("Frame", {
		Position = UDim2.fromOffset(54, 15),
		Size = UDim2.fromOffset(44, 18),
		BackgroundColor3 = C.Ink,
		ZIndex = 23,
		Parent = row,
	}, { stroke(C.Bronze, 1.2) })
	text({ Size = UDim2.fromScale(1, 1), Text = key, FontFace = F.Label, TextSize = 11, TextColor3 = C.Gold, ZIndex = 24, Parent = plate })
	text({
		Position = UDim2.fromOffset(108, 5),
		Size = UDim2.new(1, -116 - rightPad, 0, 20),
		Text = title,
		FontFace = F.TitleBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 23,
		Parent = row,
	})
	text({
		Position = UDim2.fromOffset(108, 26),
		Size = UDim2.new(1, -116 - rightPad, 0, 14),
		Text = subtitle,
		RichText = true,
		FontFace = F.Label,
		TextSize = 10,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = row,
	})
	hoverable(row, hover)
	return row
end

-- This run's rune sockets on an equipment row; click a rune to unsocket it
-- back to the pouch (the Rune found card then offers it again).
local function socketCells(row, slot)
	local list = socketsOf(slot)
	for i = 1, Runes.Sockets do
		local id = list[i]
		local cell = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10 - (Runes.Sockets - i) * 24, 0.5, 0),
			Size = UDim2.fromOffset(15, 15),
			Rotation = 45,
			Text = "",
			AutoButtonColor = id ~= nil,
			BackgroundColor3 = if id then runeColor(id) else C.Ink,
			BackgroundTransparency = if id then 0 else 0.35,
			ZIndex = 25,
			Parent = row,
		}, { stroke(C.Bronze, 1, 0.3) })
		if id then
			cell.MouseEnter:Connect(function()
				showRuneTooltip(id)
			end)
			cell.MouseLeave:Connect(hideTooltip)
			cell.Activated:Connect(function()
				hideTooltip()
				pcall(remotes.Rune.InvokeServer, remotes.Rune, "Unsocket", skillInSlot(slot), i)
			end)
		end
	end
end

local function stat(parent, order, label, value)
	local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = parent })
	text({ Size = UDim2.new(1, 0, 0, 13), Text = spaced(label), FontFace = F.Label, TextSize = 10, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = cell })
	text({ Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 20), Text = value, FontFace = F.TitleBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = cell })
end

refreshBackpack = function()
	if not backpack or not backpack.Visible then
		return
	end
	refreshSkillsTab()

	-- Equipment
	local equipment = backpack.ItemsTab.Equipment
	clearGui(equipment)
	for i, entry in SLOTS do
		if entry.Fixed then
			local info = FIXED_INFO[entry.Fixed]
			equipmentRow(equipment, i, entry.Fixed, entry.Key, info.Name, info.Subtitle, C.Rift, function()
				return entry.Fixed
			end)
		else
			local id, level = skillInSlot(entry.Slot)
			local def = id and Skills.Defs[id]
			local subtitle
			if not def then
				subtitle = "E M P T Y"
			elseif entry.Slot == "M1" then
				subtitle = "B A S I C   A T T A C K"
			else
				subtitle = `<font color="{hex(C.Gold)}">{NUMERALS[level]}</font>   {if #def.Elements == 2 then "F U S I O N" else spaced(def.Elements[1])}`
			end
			local sockets = inRun() and Runes.SlotKeys[entry.Slot] ~= nil
			local row = equipmentRow(equipment, i, id, entry.Key, if def then def.Name else "Nothing equipped", subtitle, skillColor(id), function()
				return skillInSlot(entry.Slot)
			end, if sockets then 72 else 0)
			if sockets then
				socketCells(row, entry.Slot)
			end
		end
	end
	local charges, max = player:GetAttribute("FlaskCharges") or 0, player:GetAttribute("FlaskMax") or 0
	equipmentRow(equipment, #SLOTS + 1, "Flask", "R", "Rift Flask", `{charges} / {max}   C H A R G E S`, Color3.fromRGB(255, 74, 94), function()
		return "Flask"
	end)

	-- Stats
	local stats = backpack.ItemsTab.Stats
	clearGui(stats)
	local level = player:GetAttribute("Level") or 1
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local known, total = 0, 0
	for _, id in Merge.All() do
		total += 1
		if discovered[id] then
			known += 1
		end
	end
	stat(stats, 1, "Level", tostring(level))
	stat(stats, 2, "Max Health", tostring(if hum then math.floor(hum.MaxHealth) else Progression.MaxHealth(level)))
	local damage = Progression.DamageMult(level) * Stats.DamageMult(player:GetAttribute("Stat_Might")) * Nations.DamageMult(player)
	stat(stats, 3, "Skill Damage", `+{math.floor((damage - 1) * 100 + 0.5)}%`)
	stat(stats, 4, "Gold", tostring(player:GetAttribute("Gold") or 0))
	stat(stats, 5, "Fusions", `{known} / {total}`)
	stat(stats, 6, "Powers", tostring(#sortedOwned()))

	-- Inventory
	local grid = backpack.ItemsTab.Items
	clearGui(grid)
	local kinds, pieces = 0, 0
	for _, id in Items.Order do
		local count = inventory[id]
		if count and count > 0 then
			kinds += 1
			pieces += count
			local def = Items.Defs[id]
			local rarity = Items.Rarity[def.Rarity]
			local cell = new("Frame", {
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.25,
				LayoutOrder = kinds,
				ZIndex = 22,
				Parent = grid,
			}, { corner(4), stroke(rarity.Color, 1.5, 0.2) })
			new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(64, 64),
				BackgroundTransparency = 1,
				Image = UIAssets.Items[id],
				ZIndex = 23,
				Parent = cell,
			})
			text({
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -3, 1, -1),
				Size = UDim2.fromOffset(40, 18),
				Text = `x{count}`,
				FontFace = F.TitleBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextStrokeColor3 = C.Ink,
				TextStrokeTransparency = 0,
				ZIndex = 24,
				Parent = cell,
			})
			cell.MouseEnter:Connect(function()
				showItemTooltip(id, count)
			end)
			cell.MouseLeave:Connect(hideTooltip)
		end
	end
	for i = kinds + 1, ITEM_CELLS do
		new("Frame", {
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.55,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = grid,
		}, { corner(4), stroke(C.Bronze, 1, 0.65) })
	end
	backpack.ItemsTab.ItemCount.Text = if pieces > 0 then `{pieces}   I T E M S` else "C L E A R   S T O R Y   A C T S   T O   C O L L E C T"

	-- Powers (owned skills)
	local powers = backpack.ItemsTab.Powers
	clearGui(powers)
	local owned = sortedOwned()
	for i, id in owned do
		local level = build.Skills[id]
		local need = Skills.CopiesToLevel(level)
		local ready = need ~= nil and ((build.Copies or {})[id] or 0) >= need and not (build.Temp or {})[id]
		local cell = new("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = i, ZIndex = 22, Parent = powers })
		local s = shard(id, 62, cell, 23)
		s.Position = UDim2.fromOffset(4, 0)
		text({
			Position = UDim2.fromOffset(0, 62),
			Size = UDim2.new(1, 0, 0, 16),
			-- A green arrow marks a skill that can level up right now.
			Text = NUMERALS[level] .. (if ready then "  ▲" else ""),
			FontFace = F.TitleBold,
			TextSize = 14,
			TextColor3 = if ready then C.Good else C.Gold,
			ZIndex = 23,
			Parent = cell,
		})
		cell.Activated:Connect(function()
			skillsSelected = id
			showBackpackTab("Skills")
		end)
		hoverable(cell, function()
			return id, build.Skills[id]
		end)
	end
	if #owned == 0 then
		text({
			Size = UDim2.fromOffset(360, 60),
			Text = "No powers yet. Seek the elemental shrines.",
			FontFace = F.Italic,
			TextSize = 17,
			TextColor3 = C.Ash,
			ZIndex = 22,
			Parent = powers,
		})
	end
end

-------------------------------------------------------------------------------
-- Attributes: spend stat points (C, or click the level medallion)
-------------------------------------------------------------------------------

local attributes
local refreshAttributes

local ATTR_W, ATTR_H = 760, 560
local ATTR_CARD_W, ATTR_CARD_H = 351, 196
local ATTR_GOLD = Color3.fromRGB(255, 214, 92)

local function buildAttributes()
	attributes = new("Frame", {
		Name = "Attributes",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = screenCenter(),
		Size = UDim2.fromOffset(ATTR_W, ATTR_H),
		BackgroundColor3 = Theme.C.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 18) }),
		new("UIStroke", { Color = Color3.fromRGB(70, 60, 100), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 30, 52), Color3.fromRGB(16, 15, 24)) }),
	})
	new("UIScale", { Parent = attributes })

	-- Header.
	text({ Position = UDim2.fromOffset(28, 22), Size = UDim2.fromOffset(400, 36), Text = "Attributes", FontFace = F.TitleBold, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = attributes })
	text({ Position = UDim2.fromOffset(28, 60), Size = UDim2.fromOffset(460, 18), Text = "Every level gives you a point. Spend it to shape your power!", FontFace = F.Body, TextSize = 14, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = attributes })
	-- Points medallion: a gold diamond with the unspent points, glowing when you have some.
	local medal = new("Frame", { Name = "Medal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -138, 0, 58), Size = UDim2.fromOffset(52, 52), Rotation = 45, BackgroundColor3 = ATTR_GOLD, ZIndex = 22, Parent = attributes }, {
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	text({ Name = "Points", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -138, 0, 58), Size = UDim2.fromOffset(52, 52), Text = "0", FontFace = F.TitleBold, TextSize = 26, TextColor3 = Theme.C.Ink, ZIndex = 23, Parent = attributes })
	text({ Name = "PointsLabel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -176, 0, 58), Size = UDim2.fromOffset(140, 18), Text = "POINTS TO SPEND", FontFace = F.Label, TextSize = 11, TextColor3 = ATTR_GOLD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = attributes })

	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(40, 40),
		Text = "X",
		FontFace = F.TitleBold,
		TextSize = 18,
		TextColor3 = C.Parchment,
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(40, 34, 56),
		ZIndex = 24,
		Parent = attributes,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }), new("UIStroke", { Color = Color3.fromRGB(90, 80, 120), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	close.Activated:Connect(function()
		HUD.SetStats(false)
	end)

	local grid = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(24, 112),
		Size = UDim2.new(1, -48, 0, ATTR_CARD_H * 2 + 12),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = attributes,
	}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(ATTR_CARD_W, ATTR_CARD_H), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(500, 18), Text = "Press C anytime to open this page", FontFace = F.Italic, TextSize = 13, TextColor3 = Color3.fromRGB(130, 125, 150), ZIndex = 22, Parent = attributes })

	for order, id in Stats.Order do
		local def = Stats.Defs[id]
		local color = def.Color
		local card = new("Frame", {
			Name = id,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = order,
			ZIndex = 22,
			Parent = grid,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 16) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Theme.C.Ink, 0.55), color:Lerp(Theme.C.Ink, 0.88)) }),
			new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		new("ImageLabel", { Name = "Icon", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(82, 82), BackgroundTransparency = 1, Image = UIAssets.Stats[id], ZIndex = 24, Parent = card })
		text({ Position = UDim2.fromOffset(104, 14), Size = UDim2.new(1, -116, 0, 28), Text = def.Name, FontFace = F.TitleBold, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = card })
		text({ Position = UDim2.fromOffset(104, 44), Size = UDim2.new(1, -116, 0, 36), Text = def.Description, FontFace = F.Body, TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(225, 222, 235), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24, Parent = card })
		-- Current bonus and what the next point gives.
		text({ Position = UDim2.fromOffset(16, 102), Size = UDim2.fromOffset(200, 14), Text = "YOUR BONUS", FontFace = F.Label, TextSize = 11, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = card })
		text({ Name = "Bonus", Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -100, 0, 28), FontFace = F.TitleBold, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = card })
		text({ Name = "Next", Position = UDim2.fromOffset(16, 144), Size = UDim2.new(1, -100, 0, 16), FontFace = F.BodyBold, TextSize = 13, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = card })
		-- Rank: ten rounded segments and "4 / 10".
		new("Frame", { Name = "Pips", Position = UDim2.fromOffset(16, 170), Size = UDim2.new(1, -150, 0, 12), BackgroundTransparency = 1, ZIndex = 24, Parent = card }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4) }),
		})
		text({ Name = "Rank", Position = UDim2.new(1, -132, 0, 166), Size = UDim2.fromOffset(50, 20), FontFace = F.Label, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = card })
		-- The big + button.
		local plus = new("TextButton", {
			Name = "Plus",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -14),
			Size = UDim2.fromOffset(64, 64),
			Text = "+",
			FontFace = F.TitleBold,
			TextSize = 38,
			AutoButtonColor = true,
			ZIndex = 25,
			Parent = card,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local maxTag = new("Frame", { Name = "Max", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -30), Size = UDim2.fromOffset(70, 28), BackgroundColor3 = ATTR_GOLD, Visible = false, ZIndex = 25, Parent = card }, {
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
		text({ Size = UDim2.fromScale(1, 1), Text = "MAX", FontFace = F.TitleBold, TextSize = 15, TextColor3 = Theme.C.Ink, ZIndex = 26, Parent = maxTag })
		plus.Activated:Connect(function()
			if (player:GetAttribute("StatPoints") or 0) <= 0 then
				return
			end
			if remotes.SpendStat:InvokeServer(id) then
				-- Pop the icon and flash the card.
				local icon = card.Icon
				icon.Size = UDim2.fromOffset(98, 98)
				icon.Position = UDim2.fromOffset(4, 4)
				tween(icon, 0.4, { Size = UDim2.fromOffset(82, 82), Position = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
				local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 27, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 16) }) })
				tween(flash, 0.35, { BackgroundTransparency = 1 })
				task.delay(0.4, function()
					flash:Destroy()
				end)
			end
		end)
	end
	-- The medallion gently pulses while there are points to spend.
	RunService.RenderStepped:Connect(function()
		if attributes.Visible and (player:GetAttribute("StatPoints") or 0) > 0 then
			local size = 52 + math.sin(os.clock() * 4) * 4
			medal.Size = UDim2.fromOffset(size, size)
		end
	end)
end

refreshAttributes = function()
	if not attributes then
		return
	end
	local points = player:GetAttribute("StatPoints") or 0
	attributes.Points.Text = tostring(points)
	attributes.Medal.BackgroundColor3 = if points > 0 then ATTR_GOLD else Color3.fromRGB(70, 66, 90)
	attributes.Medal.Size = UDim2.fromOffset(52, 52)
	attributes.Points.TextColor3 = if points > 0 then Theme.C.Ink else Color3.fromRGB(170, 165, 190)
	attributes.PointsLabel.TextColor3 = if points > 0 then ATTR_GOLD else C.Ash
	for _, id in Stats.Order do
		local def = Stats.Defs[id]
		local card = attributes.Rows[id]
		local rank = player:GetAttribute("Stat_" .. id) or 0
		for _, child in card.Pips:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local segW = math.floor((ATTR_CARD_W - 150 - 4 * (Stats.MaxRank - 1)) / Stats.MaxRank)
		for i = 1, Stats.MaxRank do
			local full = i <= rank
			new("Frame", {
				Size = UDim2.fromOffset(segW, 12),
				BackgroundColor3 = if full then def.Color:Lerp(Color3.new(1, 1, 1), 0.15) else Color3.fromRGB(14, 14, 20),
				LayoutOrder = i,
				ZIndex = 24,
				Parent = card.Pips,
			}, {
				new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				new("UIStroke", { Color = if full then Color3.new(1, 1, 1) else def.Color, Thickness = 1, Transparency = if full then 0.5 else 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
		end
		local maxed = rank >= Stats.MaxRank
		card.Rank.Text = `{rank} / {Stats.MaxRank}`
		card.Bonus.Text = if rank == 0 then "None yet" else def.Format(rank)
		card.Bonus.TextColor3 = if rank == 0 then Color3.fromRGB(190, 185, 205) else Color3.new(1, 1, 1)
		card.Next.Text = if maxed then "Fully trained!" else `next point:  {def.Format(rank + 1)}`
		card.Next.TextColor3 = if maxed then ATTR_GOLD else C.Good
		local canBuy = points > 0 and not maxed
		card.Plus.Visible = not maxed
		card.Max.Visible = maxed
		card.Plus.BackgroundColor3 = if canBuy then def.Color else Color3.fromRGB(30, 30, 40)
		card.Plus.TextColor3 = if canBuy then Theme.C.Ink else Color3.fromRGB(110, 108, 125)
		card.Plus.UIStroke.Transparency = if canBuy then 0 else 0.7
		card.Plus.AutoButtonColor = canBuy
	end
end

-- "+N" badge on the level medallion while points are unspent; clicking the
-- medallion opens the Attributes page.
local function buildPointsBadge()
	local medal = gui.Vitals.Medallion
	local hit = new("TextButton", {
		Name = "OpenStats",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = medal,
	})
	hit.Activated:Connect(function()
		HUD.ToggleStats()
	end)
	-- Unspent stat points: a small gold diamond (matching the level diamond's
	-- ring) with an upright "+1" that gently pulses until you spend them.
	local badge = new("Frame", {
		Name = "PointsBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 16),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
		Parent = medal,
	})
	local badgeScale = new("UIScale", { Parent = badge })
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 210, 90), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 8, Parent = badge })
	local gem = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 9, Parent = badge }, {
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 226, 130), Color3.fromRGB(200, 140, 36)), Rotation = 45 }),
		Theme.Edged(2),
	})
	local label = text({ Size = UDim2.fromScale(1, 1), FontFace = F.TitleBold, TextSize = 13, TextColor3 = Color3.fromRGB(28, 18, 4), ZIndex = 10, Parent = badge })
	local pulse, glowPulse
	local function refresh()
		local points = player:GetAttribute("StatPoints") or 0
		badge.Visible = points > 0
		label.Text = "+" .. points
		if points > 0 and not pulse then
			local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			pulse = TweenService:Create(badgeScale, info, { Scale = 1.12 })
			glowPulse = TweenService:Create(glow, info, { BackgroundTransparency = 0.25, Size = UDim2.fromOffset(36, 36) })
			pulse:Play()
			glowPulse:Play()
		elseif points == 0 and pulse then
			pulse:Cancel()
			glowPulse:Cancel()
			pulse, glowPulse = nil, nil
			badgeScale.Scale = 1
		end
	end
	player:GetAttributeChangedSignal("StatPoints"):Connect(refresh)
	refresh()
end

-------------------------------------------------------------------------------
-- Boss bar: the nearest living boss's name and health, pinned to the top of
-- the screen while you fight it.
-------------------------------------------------------------------------------

local BOSS_RANGE = 300 -- studs; bosses in other players' arenas stay hidden
local BOSS_W = 560

local function buildBossBar()
	local root = new("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		-- Up in the top bar's row (Roblox's buttons only use the top-left).
		Position = UDim2.new(0.5, 0, 0, -44),
		Size = UDim2.fromOffset(BOSS_W, 68),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	text({ Size = UDim2.new(1, 0, 0, 14), Text = spaced("Boss"), FontFace = F.Label, TextSize = 11, TextColor3 = C.Crimson, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.4, Parent = root })
	local name = text({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 26), FontFace = F.TitleBold, TextSize = 24, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.2, Parent = root })
	local bar = new("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = root })
	local track = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = Color3.fromRGB(15, 10, 18), BorderSizePixel = 0, ClipsDescendants = true, Parent = bar })
	local lag = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 214, 180), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2, Parent = track })
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = track }, {
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 92, 60), Color3.fromRGB(150, 16, 28)), Rotation = 90 }),
	})
	local hp = text({ Size = UDim2.fromScale(1, 1), FontFace = F.BodyBold, TextSize = 13, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.1, ZIndex = 4, Parent = track })

	local current, last, nextScan = nil, nil, 0
	local function findBoss()
		local char = player.Character
		local me = char and char:FindFirstChild("HumanoidRootPart")
		local folder = workspace:FindFirstChild("RiftEnemies")
		if not me or not folder then
			return nil
		end
		local best, bestDist = nil, BOSS_RANGE
		for _, model in folder:GetChildren() do
			if model:GetAttribute("Boss") then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local part = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and part then
					local d = (part.Position - me.Position).Magnitude
					if d < bestDist then
						best, bestDist = model, d
					end
				end
			end
		end
		return best
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 0.25
			local boss = findBoss()
			if boss ~= current then
				current, last = boss, nil
				root.Visible = boss ~= nil
				if boss then
					name.Text = boss:GetAttribute("BossName") or boss.Name
					lag.Size = UDim2.fromScale(1, 1)
				end
			end
		end
		local hum = current and current:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		hp.Text = `{math.ceil(hum.Health)} / {math.floor(hum.MaxHealth)}`
		if last and hum.Health < last then
			task.delay(0.3, function()
				if current and current:FindFirstChildOfClass("Humanoid") == hum then
					tween(lag, 0.4, { Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1) })
				end
			end)
		elseif not last or hum.Health > last then
			lag.Size = UDim2.fromScale(frac, 1)
		end
		last = hum.Health
	end)
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

local inLobby = false
local lobbyMenuOpen = false
local closeLobbyPanel

local function menuShade(show)
	if show then
		forgeShade.Visible = true
		forgeShade.BackgroundTransparency = 1
		forgeShade.Vignette.ImageTransparency = 1
		tween(forgeShade, 0.25, { BackgroundTransparency = 0.5 })
		tween(forgeShade.Vignette, 0.25, { ImageTransparency = 0 })
	else
		forgeShade.Visible = false
	end
	arsenal.Visible = not show and not inLobby
end

local function popIn(frame)
	frame.UIScale.Scale = 0.92
	tween(frame.UIScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- True while any full-screen menu (Forge, Backpack) is open; Controls uses it to block casting.
function HUD.MenuOpen()
	local playerGui = player:FindFirstChild("PlayerGui")
	local craftingGui = playerGui and playerGui:FindFirstChild("RiftboundCrafting")
	local craftingOpen = craftingGui and craftingGui.Enabled
	return lobbyMenuOpen or craftingOpen or (forge ~= nil and forge.Visible) or (backpack ~= nil and backpack.Visible) or (attributes ~= nil and attributes.Visible) or (offerScreen ~= nil and offerScreen.Visible)
end

-- Middle of the real screen for panels in this ScreenGui: it starts below
-- Roblox's top bar, so plain 0.5 lands half a top bar too low.
screenCenter = function()
	return UDim2.new(0.5, 0, 0.5, -GuiService:GetGuiInset().Y / 2)
end
HUD.ScreenCenter = screenCenter

-- Shared look for other screens (the lobby menu) so they match the HUD.
HUD.Style = {
	C = C,
	F = F,
	new = new,
	stroke = stroke,
	text = text,
	tween = tween,
	spaced = spaced,
	slab = slab,
	popIn = popIn,
}

-- Docks the gold bar into another frame (the lobby menu puts it above the
-- Store button) at `position` and `width`; with no parent it goes home, under
-- the level diamond.
function HUD.DockGold(parent, position, width)
	if not goldBox then
		return
	end
	if parent then
		goldBox.Parent = parent
		goldBox.Position = position
		goldBox.Size = UDim2.fromOffset(width or GOLD_W, GOLD_H)
	else
		goldBox.Parent = gui
		goldBox.Position = UDim2.fromOffset(GOLD_X, GOLD_Y)
		goldBox.Size = UDim2.fromOffset(GOLD_W, GOLD_H)
	end
end

HUD.GoldHeight = GOLD_H

-- In the lobby the Arsenal steps aside for the lobby menu buttons.
function HUD.SetLobby(on)
	inLobby = on
	arsenal.Visible = not on and not HUD.MenuOpen()
end

-- The lobby menu sets this to hide its panel when a HUD menu (Forge, Backpack, Attributes) opens.
HUD.OnHudMenuOpened = nil

closeLobbyPanel = function()
	if lobbyMenuOpen then
		lobbyMenuOpen = false
		if HUD.OnHudMenuOpened then
			HUD.OnHudMenuOpened()
		end
	end
end

-- A lobby menu panel is open: dim the world and block casting like the HUD's own menus.
function HUD.SetLobbyPanel(open)
	if open then
		hideTooltip()
		forge.Visible = false
		backpack.Visible = false
		attributes.Visible = false
	end
	lobbyMenuOpen = open
	menuShade(open)
end

-- Skill icon (with the awakened frame) and colour, for other screens.
HUD.SkillIcon = function(id, size, parent, z)
	return shard(id, size, parent, z)
end
HUD.SkillColor = function(id)
	return skillColor(id)
end

-- The current build snapshot (skills, slots, temp skills).
function HUD.Build()
	return build
end

-- The skill id equipped in a slot ("M1", "Q", "E"), or nil.
function HUD.SkillInSlot(slot)
	return (skillInSlot(slot))
end

function HUD.ForgeOpen()
	local playerGui = player:FindFirstChild("PlayerGui")
	local craftingGui = playerGui and playerGui:FindFirstChild("RiftboundCrafting")
	return craftingGui ~= nil and craftingGui.Enabled
end

function HUD.SetForge(open)
	-- Deprecated: The Forge modal is managed by Crafting.client.lua
	if forge then
		forge.Visible = false
	end
	menuShade(false)
end

function HUD.ToggleForge()
	-- Deprecated: The Forge modal is managed by Crafting.client.lua
end

function HUD.SetBackpack(open)
	if open == backpack.Visible then
		return
	end
	hideTooltip()
	if open then
		closeLobbyPanel()
		forge.Visible = false
		attributes.Visible = false
		backpack.Visible = true
		showBackpackTab(backpackTab) -- reopens on the last tab used (and refreshes)
		-- Opening the backpack brings back runes waiting to be socketed.
		runeDismissed = 0
		refreshRunes()
		menuShade(true)
		popIn(backpack)
	else
		backpack.Visible = false
		menuShade(false)
	end
end

function HUD.ToggleBackpack()
	HUD.SetBackpack(not backpack.Visible)
end

function HUD.SetStats(open)
	if open == attributes.Visible then
		return
	end
	hideTooltip()
	if open then
		closeLobbyPanel()
		forge.Visible = false
		backpack.Visible = false
		attributes.Visible = true
		refreshAttributes()
		menuShade(true)
		popIn(attributes)
	else
		attributes.Visible = false
		menuShade(false)
	end
end

function HUD.ToggleStats()
	HUD.SetStats(not attributes.Visible)
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
	local length = Skills.CooldownOf(id, level) * Stats.CooldownMult(player:GetAttribute("Stat_Focus")) * Nations.CooldownMult(player) * Runes.CooldownMult(socketsOf(slot))
	cooldownEnds[id] = { Ends = now + length, Length = length }
	return true
end

function HUD.StartDashCooldown(length)
	dash = { Ends = os.clock() + length, Length = length }
end

-- True when the shield is off cooldown.
function HUD.BlockReady()
	return os.clock() >= block.Ends
end

local function applyBuild(snapshot)
	build = snapshot
	for id in build.Skills do
		discovered[id] = true
	end
	build.Sockets = build.Sockets or {}
	build.Pouch = build.Pouch or {}
	refreshSlots()
	refreshArsenal()
	refreshForge()
	refreshBackpack()
	refreshRunes()
	refreshOffer()
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
		Size = UDim2.fromOffset(#SLOTS * 96, ICON + 60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for i, entry in SLOTS do
		makeSlot(bar, entry, i)
	end
	-- The server publishes when the shield can be raised again.
	player:GetAttributeChangedSignal("BlockReadyAt"):Connect(function()
		local length = (player:GetAttribute("BlockReadyAt") or 0) - workspace:GetServerTimeNow()
		if length > 0 then
			block = { Ends = os.clock() + length, Length = length }
		end
	end)
	buildFlask()

	buildArsenal()
	buildArsenalToggle()

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
	buildBackpack()
	buildAttributes()
	buildPointsBadge()
	buildBossBar()
	buildTooltip()
	buildRuneCard()
	buildOfferScreen()

	remotes.BuildChanged.OnClientEvent:Connect(applyBuild)
	remotes.Notify.OnClientEvent:Connect(HUD.Toast)
	-- Rune of the Endless Cascade: a kill made the skill ready again.
	remotes.CooldownReset.OnClientEvent:Connect(function(id)
		cooldownEnds[id] = nil
	end)
	player:GetAttributeChangedSignal("StoryRun"):Connect(function()
		runeDismissed = 0
		refreshRunes()
		refreshOffer()
		refreshBackpack()
	end)
	applyBuild(remotes.GetBuild:InvokeServer())

	remotes.InventoryChanged.OnClientEvent:Connect(function(snapshot)
		inventory = snapshot
		refreshBackpack()
	end)
	inventory = remotes.GetInventory:InvokeServer() or {}
	for _, name in { "Gold", "Level", "FlaskCharges", "FlaskMax", "StatPoints", "Stat_Vitality", "Stat_Might", "Stat_Swiftness", "Stat_Focus" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshBackpack()
			refreshAttributes()
		end)
	end

	RunService.RenderStepped:Connect(updateCooldowns)
end

return HUD
