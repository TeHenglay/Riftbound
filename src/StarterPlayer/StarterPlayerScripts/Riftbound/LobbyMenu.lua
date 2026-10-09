-- Lobby menu: Shattered Obsidian tiles down the left (Store, Items, Quests,
-- Areas, Play) and right (Profile, Calendar) edges of the screen.
-- Shown only while the player is in their nation's lobby; slides away in the Rift.
-- Items opens the Backpack, Play sends you into the arena, Profile shows your
-- level and attributes. Store, Quests, Areas and Calendar open
-- placeholder panels until those features exist.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Progression = require(Shared:WaitForChild("Progression"))
local Stats = require(Shared:WaitForChild("Stats"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local LobbyMenu = {}

local player = Players.LocalPlayer
local HUD, remotes
local C, F, new, stroke, text, tween, spaced, slab, popIn
local gui, left, right, holder, panel
local shown = false
local openId

local TILE = 112
local GAP = 8
local EDGE = 16

local BUTTONS = {
	Store = { Title = "Store", Tint = Color3.fromRGB(233, 194, 122), Subtitle = "THE RIFT MERCHANT" },
	Items = { Title = "Items", Tint = Color3.fromRGB(192, 132, 70), Key = "B" },
	Quests = { Title = "Quests", Tint = Color3.fromRGB(255, 106, 43), Subtitle = "BOUNTIES OF THE RIFT" },
	Areas = { Title = "Areas", Tint = Color3.fromRGB(159, 240, 216), Subtitle = "TRAVEL THE SHATTERED LANDS" },
	Play = { Title = "Play", Tint = Color3.fromRGB(178, 108, 255) },
	Profile = { Title = "Profile", Tint = Color3.fromRGB(60, 156, 255), Subtitle = "YOUR RIFTWALKER" },
	Calendar = { Title = "Calendar", Tint = Color3.fromRGB(250, 225, 60), Subtitle = "DAILY REWARDS" },
}

local PLACEHOLDER = {
	Store = "The Rift Merchant is still unpacking. Soon you'll spend your gold here on cosmetics, flasks and boosts.",
	Quests = "No bounties are posted yet. Daily and weekly quests with gold and XP rewards are coming.",
	Areas = "Only the first arena has been charted. New areas unlock here as you push deeper into the Rift.",
}

-------------------------------------------------------------------------------
-- Lobby detection
-------------------------------------------------------------------------------

-- NationService marks the player: they're in their nation's lobby once a
-- nation is chosen, until they step through the portal into the Rift.
local function inLobby()
	return player:GetAttribute("Nation") ~= nil
		and not player:GetAttribute("InRift")
		and not player:GetAttribute("NeedsNation")
end

-------------------------------------------------------------------------------
-- Panels
-------------------------------------------------------------------------------

local function closePanel()
	if not openId then
		return
	end
	openId = nil
	panel.Visible = false
	HUD.SetLobbyPanel(false)
end

local function buildPanel()
	panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(620, 460),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = holder,
	})
	new("UIScale", { Parent = panel })
	slab({
		Name = "Body",
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 1, -92),
		ZIndex = 20,
		Parent = panel,
	})
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
		Parent = panel,
	})
	text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = F.Title,
		TextSize = 36,
		TextStrokeColor3 = C.RiftDeep,
		TextStrokeTransparency = 0.4,
		ZIndex = 23,
		Parent = banner,
	})
	text({
		Name = "Subtitle",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 16),
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
		Parent = panel,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(C.Bronze, 2) })
	close.Activated:Connect(closePanel)

	new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(46, 128),
		Size = UDim2.new(1, -92, 1, -160),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = panel,
	})
end

local function icon(id, props)
	local image = UIAssets.Menu and UIAssets.Menu[id]
	props.BackgroundTransparency = 1
	props.Image = image or UIAssets.Medallion
	props.ZIndex = props.ZIndex or 22
	return new("ImageLabel", props)
end

local function paragraph(parent, y, height, body, props)
	local label = text({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		Text = body,
		FontFace = F.Body,
		TextSize = 17,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 22,
		Parent = parent,
	})
	for k, v in props or {} do
		label[k] = v
	end
	return label
end

local function comingSoon(parent, y)
	local tag = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(180, 30),
		BackgroundColor3 = C.Ink,
		ZIndex = 22,
		Parent = parent,
	}, { stroke(C.Rift, 1.5) })
	text({
		Size = UDim2.fromScale(1, 1),
		Text = spaced("Coming soon"),
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = C.RiftHot,
		ZIndex = 23,
		Parent = tag,
	})
end

local function fillPlaceholder(content, id)
	icon(
		id,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(120, 120),
			Parent = content,
		}
	)
	paragraph(
		content,
		136,
		64,
		PLACEHOLDER[id],
		{ TextXAlignment = Enum.TextXAlignment.Center, FontFace = F.Italic, TextColor3 = C.Ash, TextSize = 18 }
	)
	if id == "Store" then
		paragraph(
			content,
			204,
			24,
			string.format("Your purse: <b>%d gold</b>", player:GetAttribute("Gold") or 0),
			{
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = C.Gold,
			}
		)
	end
	comingSoon(content, 240)
end

-- Seven-day login track; day one lit, the rest waiting.
local function fillCalendar(content)
	paragraph(
		content,
		0,
		44,
		"Return each day to claim a reward from the Rift. Daily rewards begin with the next update.",
		{
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.Italic,
			TextColor3 = C.Ash,
		}
	)
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(7 * 66 - 6, 92),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	local numerals = { "I", "II", "III", "IV", "V", "VI", "VII" }
	local rewards = { "50", "75", "100", "125", "150", "200", "500" }
	for day = 1, 7 do
		local lit = day == 1
		local cell = new("Frame", {
			Size = UDim2.fromOffset(60, 92),
			BackgroundColor3 = if lit then C.RiftDeep else C.Ink,
			BackgroundTransparency = 0.1,
			LayoutOrder = day,
			ZIndex = 22,
			Parent = row,
		}, { stroke(if lit then C.Rift else C.Bronze, if lit then 2 else 1.2) })
		text({
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 22),
			Text = numerals[day],
			FontFace = F.TitleBold,
			TextSize = 20,
			TextColor3 = if lit then C.RiftHot else C.Parchment,
			ZIndex = 23,
			Parent = cell,
		})
		new(
			"ImageLabel",
			{
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 32),
				Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 1,
				Image = UIAssets.Coin,
				ZIndex = 23,
				Parent = cell,
			}
		)
		text({
			Position = UDim2.new(0, 0, 1, -26),
			Size = UDim2.new(1, 0, 0, 18),
			Text = rewards[day],
			FontFace = F.Label,
			TextSize = 13,
			TextColor3 = C.Gold,
			ZIndex = 23,
			Parent = cell,
		})
	end
	comingSoon(content, 180)
end

local function profileStat(parent, order, label, value, color)
	local row = new(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = parent,
		}
	)
	text({
		Size = UDim2.fromScale(0.6, 1),
		Text = label,
		FontFace = F.Body,
		TextSize = 16,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = row,
	})
	text({
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.fromScale(0.4, 1),
		Text = value,
		FontFace = F.BodyBold,
		TextSize = 16,
		TextColor3 = color or C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		Parent = row,
	})
	new(
		"Frame",
		{
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Bronze,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = 22,
			Parent = row,
		}
	)
end

local function fillProfile(content)
	local portrait = new("ImageLabel", {
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = C.Ink,
		Image = "",
		ZIndex = 22,
		Parent = content,
	}, { stroke(C.Bronze, 2.5) })
	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			player.UserId,
			Enum.ThumbnailType.AvatarBust,
			Enum.ThumbnailSize.Size150x150
		)
		if ok and portrait.Parent then
			portrait.Image = image
		end
	end)
	text({
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.fromOffset(150, 24),
		Text = player.DisplayName,
		FontFace = F.TitleBold,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 22,
		Parent = content,
	})
	text({
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.fromOffset(150, 16),
		Text = "@" .. player.Name,
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Ash,
		ZIndex = 22,
		Parent = content,
	})

	local list = new("Frame", {
		Position = UDim2.fromOffset(176, 0),
		Size = UDim2.new(1, -176, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	}, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("Xp") or 0
	local toNext = player:GetAttribute("XpToNext") or Progression.XpToNext(level)
	local order = 0
	local function add(label, value, color)
		order += 1
		profileStat(list, order, label, value, color)
	end
	local nation = player:GetAttribute("Nation")
	if nation then
		add("Nation", tostring(nation), C.Gold)
	end
	add("Level", string.format("%d / %d", level, Progression.MaxLevel), C.RiftHot)
	add("Rift Essence", if toNext > 0 then string.format("%d / %d", xp, toNext) else "MAX")
	add("Gold", tostring(player:GetAttribute("Gold") or 0), C.Gold)
	add("Unspent points", tostring(player:GetAttribute("StatPoints") or 0))
	for _, id in Stats.Order do
		add(id, tostring(player:GetAttribute("Stat_" .. id) or 0))
	end
end

local FILL = {
	Profile = fillProfile,
	Calendar = fillCalendar,
}

local function openPanel(id)
	if openId == id then
		closePanel()
		return
	end
	local info = BUTTONS[id]
	local content = panel.Content
	content:ClearAllChildren()
	panel.Banner.Title.Text = spaced(info.Title)
	panel.Banner.Subtitle.Text = spaced(info.Subtitle or "");
	(FILL[id] or fillPlaceholder)(content, id)
	openId = id
	HUD.SetLobbyPanel(true)
	panel.Visible = true
	popIn(panel)
end

-------------------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------------------

local ACTIONS = {
	Items = function()
		closePanel()
		HUD.ToggleBackpack()
	end,
	Play = function()
		closePanel()
		local enter = remotes:FindFirstChild("EnterRift")
		if enter then
			enter:FireServer()
		else
			HUD.Toast("The way into the Rift isn't open yet.", C.Ash)
		end
	end,
}

local function activate(id)
	if ACTIONS[id] then
		ACTIONS[id]()
	else
		openPanel(id)
	end
end

local function hover(button, scale, label, tint)
	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.07 })
		label.TextColor3 = C.RiftHot
		tint.Transparency = 0
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
		label.TextColor3 = C.Parchment
		tint.Transparency = 0.6
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.07 })
	end)
end

local function keyBadge(parent, key)
	local plate = new("Frame", {
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.Ink,
		ZIndex = 5,
		Parent = parent,
	}, { stroke(C.Bronze, 1.5) })
	text({
		Size = UDim2.fromScale(1, 1),
		Text = key,
		FontFace = F.Label,
		TextSize = 13,
		TextColor3 = C.Gold,
		ZIndex = 6,
		Parent = plate,
	})
end

-- Square tile: icon art with the name along the bottom.
local function tile(parent, id, x, y)
	local info = BUTTONS[id]
	local button = new("ImageButton", {
		Name = id,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundTransparency = 1,
		Image = (UIAssets.Menu and UIAssets.Menu[id]) or UIAssets.Slab,
		ScaleType = if UIAssets.Menu and UIAssets.Menu[id]
			then Enum.ScaleType.Stretch
			else Enum.ScaleType.Slice,
		SliceCenter = UIAssets.SlabSlice,
		SliceScale = 0.35,
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = button })
	local glow = new(
		"UIStroke",
		{ Color = info.Tint, Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	new("Frame", {
		Name = "Glow",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = button,
	}, { glow })
	local label = text({
		Name = "Label",
		Position = UDim2.new(0, 0, 1, -32),
		Size = UDim2.new(1, 0, 0, 24),
		Text = info.Title,
		FontFace = F.TitleBold,
		TextSize = 20,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0,
		ZIndex = 4,
		Parent = button,
	})
	if info.Key then
		keyBadge(button, info.Key)
	end
	hover(button, scale, label, glow)
	button.Activated:Connect(function()
		activate(id)
	end)
	return button
end

-- Wide Store bar across the top of the left column.
local function storeBar(parent)
	local info = BUTTONS.Store
	local width = TILE * 2 + GAP
	local button = new("ImageButton", {
		Name = "Store",
		Size = UDim2.fromOffset(width, 76),
		BackgroundTransparency = 1,
		Image = UIAssets.Row,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.RowSlice,
		SliceScale = 0.5,
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = button })
	local glow = new(
		"UIStroke",
		{ Color = info.Tint, Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	new(
		"Frame",
		{
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 1, -12),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = button,
		},
		{ glow }
	)
	icon(
		"Store",
		{ Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(72, 72), ZIndex = 3, Parent = button }
	)
	local label = text({
		Position = UDim2.fromOffset(84, 0),
		Size = UDim2.new(1, -96, 1, 0),
		Text = info.Title,
		FontFace = F.TitleBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0,
		ZIndex = 4,
		Parent = button,
	})
	hover(button, scale, label, glow)
	button.Activated:Connect(function()
		activate("Store")
	end)
end

local LEFT_W = TILE * 2 + GAP
local LEFT_H = 76 + GAP + TILE * 2 + GAP
local RIGHT_H = TILE * 2 + GAP
local LEFT_IN, LEFT_OUT = UDim2.new(0, EDGE, 0.56, 0), UDim2.new(0, -LEFT_W - 40, 0.56, 0)
local RIGHT_IN, RIGHT_OUT = UDim2.new(1, -EDGE, 0.56, 0), UDim2.new(1, TILE + 40, 0.56, 0)

local function buildColumns()
	left = new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = LEFT_OUT,
		Size = UDim2.fromOffset(LEFT_W, LEFT_H),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	})
	storeBar(left)
	local top = 76 + GAP
	tile(left, "Items", 0, top)
	tile(left, "Quests", TILE + GAP, top)
	tile(left, "Areas", 0, top + TILE + GAP)
	tile(left, "Play", TILE + GAP, top + TILE + GAP)

	right = new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = RIGHT_OUT,
		Size = UDim2.fromOffset(TILE, RIGHT_H),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	})
	for i, id in { "Profile", "Calendar" } do
		tile(right, id, 0, (i - 1) * (TILE + GAP))
	end
end

local function setShown(on)
	if on == shown then
		return
	end
	shown = on
	HUD.SetLobby(on)
	if on then
		left.Visible = true
		right.Visible = true
		tween(left, 0.35, { Position = LEFT_IN }, Enum.EasingStyle.Quint)
		tween(right, 0.35, { Position = RIGHT_IN }, Enum.EasingStyle.Quint)
	else
		closePanel()
		tween(left, 0.25, { Position = LEFT_OUT }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		local tw =
			tween(right, 0.25, { Position = RIGHT_OUT }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not shown then
				left.Visible = false
				right.Visible = false
			end
		end)
	end
end

-- Keeps the columns readable on small screens (1 at 1000px tall and up).
local function fitToScreen()
	local camera = workspace.CurrentCamera
	if camera then
		holder.UIScale.Scale = math.clamp(camera.ViewportSize.Y / 1000, 0.6, 1)
	end
end

function LobbyMenu.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	local style = HUD.Style
	C, F, new, stroke, text, tween, spaced, slab, popIn =
		style.C,
		style.F,
		style.new,
		style.stroke,
		style.text,
		style.tween,
		style.spaced,
		style.slab,
		style.popIn

	gui = new("ScreenGui", {
		Name = "RiftboundLobbyMenu",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	new("UIScale", { Parent = holder })
	-- UIScale shrinks around the top-left corner, so the holder is resized to keep anchors on the screen edges.
	holder.UIScale:GetPropertyChangedSignal("Scale"):Connect(function()
		local s = holder.UIScale.Scale
		holder.Size = UDim2.fromScale(1 / s, 1 / s)
	end)
	fitToScreen()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fitToScreen)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end

	buildColumns()
	buildPanel()
	HUD.OnHudMenuOpened = function()
		openId = nil
		panel.Visible = false
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and openId then
			closePanel()
		end
	end)

	local function refresh()
		setShown(inLobby())
	end
	for _, name in { "Nation", "InRift", "NeedsNation" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return LobbyMenu
