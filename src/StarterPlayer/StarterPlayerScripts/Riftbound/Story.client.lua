-- Story screen (pick a nation's story and an act), plus in-run banners: act
-- intro, wave counter, boss name and the "Act Cleared" rewards card. Opened
-- with NationRemotes.OpenStoryLocal:Fire() (the Play page's Story card).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Story = require(Shared:WaitForChild("Story"))
local Nations = require(Shared:WaitForChild("Nations"))
local Items = require(Shared:WaitForChild("Items"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local remotes = Shared:WaitForChild("NationRemotes")

-- Listen for the Story card right away; a click before the screen is built
-- is queued and opens it once ready.
local openStory, pendingOpen
remotes:WaitForChild("OpenStoryLocal").Event:Connect(function()
	if openStory then
		openStory()
	else
		pendingOpen = true
	end
end)

local player = Players.LocalPlayer

local C = {
	Ink = Color3.fromRGB(7, 5, 10),
	Bronze = Color3.fromRGB(168, 119, 63),
	Gold = Color3.fromRGB(233, 194, 122),
	Rift = Color3.fromRGB(178, 108, 255),
	Parchment = Color3.fromRGB(241, 227, 198),
	Ash = Color3.fromRGB(156, 138, 123),
	Good = Color3.fromRGB(143, 227, 107),
	Bad = Color3.fromRGB(232, 84, 84),
}
local function face(enum, weight, style)
	return Font.new(Font.fromEnum(enum).Family, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
end
local F = {
	TitleBold = face(Enum.Font.Bodoni, Enum.FontWeight.Bold),
	Body = face(Enum.Font.Merriweather),
	BodyBold = face(Enum.Font.Merriweather, Enum.FontWeight.Bold),
	Label = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	Italic = face(Enum.Font.Garamond, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
}
local EMBLEM = {
	Fire = UIAssets.Icons.Fireball,
	Earth = UIAssets.Icons.StoneSpike,
	Water = UIAssets.Icons.TidalWave,
	Wind = UIAssets.Icons.Gust,
	Lightning = UIAssets.Icons.ChainShock,
}
-- Acts with arenas so far; the rest show as coming soon.
local BUILT = { [1] = true }

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
local function text(props)
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or F.Body
	props.TextColor3 = props.TextColor3 or C.Parchment
	props.TextSize = props.TextSize or 14
	return new("TextLabel", props)
end
local function spaced(s)
	return (s:upper():gsub("(.)", "%1 "):gsub(" $", ""):gsub("   ", "     "))
end
local function tween(inst, t, goal)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 4) })
end
local function stroke(color, t, tr)
	return new("UIStroke", { Color = color, Thickness = t or 1.5, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local gui = new("ScreenGui", {
	Name = "RiftboundStory",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 45,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-------------------------------------------------------------------------------
-- Story select screen: "Create Lobby" — maps on the left, acts in the middle,
-- a big preview with difficulty and rewards on the right, Start / Leave below.
-------------------------------------------------------------------------------

local W, H = 1280, 720
local screen = new("Frame", { Name = "StorySelect", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Visible = false, Active = true, Parent = gui })
new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Vignette, Parent = screen })
local content = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(14, 10, 20), Parent = screen }, {
	corner(6), stroke(C.Bronze, 2, 0), new("UIScale", {}),
})
new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Grain, ImageTransparency = 0.78, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(256, 256), Parent = content })
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(110, 10), BackgroundColor3 = C.Bronze, BorderSizePixel = 0, ZIndex = 3, Parent = content }, { corner(2) })

-- Header.
text({ Position = UDim2.fromOffset(28, 18), Size = UDim2.fromOffset(400, 16), Text = spaced("Create Lobby"), FontFace = F.Label, TextSize = 13, TextColor3 = C.Rift, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
text({ Position = UDim2.fromOffset(28, 34), Size = UDim2.fromOffset(600, 40), Text = "Set up your story", FontFace = F.TitleBold, TextSize = 32, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.Ink, Text = "X", TextColor3 = C.Ash, TextSize = 18, FontFace = F.BodyBold, Parent = content }, { corner(3), stroke(C.Bronze, 1, 0.3) })
new("Frame", { Position = UDim2.fromOffset(28, 84), Size = UDim2.new(1, -56, 0, 1), BackgroundColor3 = C.Bronze, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = content })

local function columnLabel(x, w, label)
	text({ Position = UDim2.fromOffset(x, 96), Size = UDim2.fromOffset(w, 16), Text = spaced(label), FontFace = F.Label, TextSize = 12, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
end
columnLabel(28, 290, "Maps")
columnLabel(336, 220, "Acts")

-- Left: map cards.
local maps = new("ScrollingFrame", { Position = UDim2.fromOffset(28, 118), Size = UDim2.fromOffset(292, 500), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Bronze, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = content }, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
-- Middle: act cards.
local acts = new("Frame", { Position = UDim2.fromOffset(336, 118), Size = UDim2.fromOffset(220, 500), BackgroundTransparency = 1, Parent = content }, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
-- Right: preview, difficulty, rewards.
local RX, RW = 574, W - 574 - 28
local preview = new("ImageLabel", { Position = UDim2.fromOffset(RX, 96), Size = UDim2.fromOffset(RW, 300), BackgroundColor3 = C.Ink, ScaleType = Enum.ScaleType.Crop, Parent = content }, { corner(4), stroke(C.Bronze, 1.5, 0.2) })
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BorderSizePixel = 0, Parent = preview }, {
	corner(4),
	new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.85), NumberSequenceKeypoint.new(1, 1) }) }),
})
local previewName = text({ Position = UDim2.fromOffset(20, 186), Size = UDim2.new(1, -40, 0, 40), FontFace = F.TitleBold, TextSize = 34, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.4, Parent = preview })
local previewTag = text({ Position = UDim2.fromOffset(20, 226), Size = UDim2.new(1, -40, 0, 22), FontFace = F.Label, TextSize = 18, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.4, Parent = preview })
local previewText = text({ Position = UDim2.fromOffset(20, 250), Size = UDim2.new(1, -40, 0, 44), FontFace = F.Italic, TextSize = 16, TextWrapped = true, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.5, Parent = preview })

text({ Position = UDim2.fromOffset(RX, 410), Size = UDim2.fromOffset(RW, 16), Text = spaced("Select Difficulty"), FontFace = F.Label, TextSize = 12, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
local diffRow = new("Frame", { Position = UDim2.fromOffset(RX, 432), Size = UDim2.fromOffset(RW, 76), BackgroundTransparency = 1, Parent = content }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
text({ Position = UDim2.fromOffset(RX, 522), Size = UDim2.fromOffset(RW, 16), Text = spaced("Rewards"), FontFace = F.Label, TextSize = 12, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
local rewardRow = new("Frame", { Position = UDim2.fromOffset(RX, 544), Size = UDim2.fromOffset(RW, 76), BackgroundTransparency = 1, Parent = content }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Bottom bar.
new("Frame", { Position = UDim2.fromOffset(28, 636), Size = UDim2.new(1, -56, 0, 1), BackgroundColor3 = C.Bronze, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = content })
local function toggle(x, label, value)
	local f = new("Frame", { Position = UDim2.fromOffset(x, 652), Size = UDim2.fromOffset(200, 44), BackgroundColor3 = Color3.fromRGB(20, 16, 26), Parent = content }, { corner(3), stroke(C.Bronze, 1, 0.6) })
	text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18), Text = label, FontFace = F.Label, TextSize = 13, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	text({ Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 16), Text = value, FontFace = F.Italic, TextSize = 14, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
end
-- Parties aren't built yet: these show their state but can't be changed.
toggle(28, "FRIENDS ONLY", "Off · parties coming soon")
toggle(240, "MAX PLAYERS", "Open · anyone can join your act")
local status = text({ Position = UDim2.fromOffset(456, 652), Size = UDim2.fromOffset(420, 44), FontFace = F.Italic, TextSize = 16, TextWrapped = true, TextColor3 = C.Ash, Parent = content })
local leaveBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 652), Size = UDim2.fromOffset(150, 46), BackgroundColor3 = Color3.fromRGB(40, 20, 26), Text = "LEAVE", TextColor3 = C.Parchment, TextSize = 18, FontFace = F.Label, Parent = content }, { corner(3), stroke(C.Bad, 1.5, 0.2) })
local startBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -190, 0, 652), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = Color3.fromRGB(28, 54, 30), Text = "START", TextColor3 = C.Gold, TextSize = 20, FontFace = F.Label, Parent = content }, { corner(3), stroke(C.Good, 2, 0) })

local selected, selectedAct, selectedDiff = nil, 1, "Easy"
local busy = false

local function progress()
	local set = {}
	for key in string.gmatch(player:GetAttribute("StoryProgress") or "", "[^,]+") do
		set[key] = true
	end
	return set
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function tile(parent, order, w, icon, title, sub, color, on, locked)
	local b = new("TextButton", { Size = UDim2.fromOffset(w, 76), BackgroundColor3 = if on then Color3.fromRGB(34, 26, 44) else Color3.fromRGB(20, 16, 26), Text = "", AutoButtonColor = not locked, LayoutOrder = order, Parent = parent }, { corner(4), stroke(if on then C.Good else C.Bronze, if on then 2.5 else 1, if on then 0 else 0.5) })
	if icon then
		new("ImageLabel", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Image = icon, ImageTransparency = if locked then 0.6 else 0, Parent = b })
	end
	local x = if icon then 70 else 10
	text({ Position = UDim2.fromOffset(x, 14), Size = UDim2.new(1, -x - 6, 0, 24), Text = title, FontFace = F.TitleBold, TextSize = 20, TextColor3 = if locked then C.Ash else color, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
	text({ Position = UDim2.fromOffset(x, 40), Size = UDim2.new(1, -x - 6, 0, 22), Text = sub, FontFace = F.Body, TextSize = 13, TextColor3 = C.Ash, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = b })
	return b
end

local render

local function canStart()
	local done = progress()
	if selectedAct > 1 and not done[Story.Key(selected, selectedAct - 1)] then
		return false, "Clear Act " .. (selectedAct - 1) .. " first."
	end
	if not BUILT[selectedAct] then
		return false, "Act " .. selectedAct .. " is coming soon."
	end
	local need = Story.Difficulties[selectedDiff].Needs
	if need and not done[Story.Key(selected, selectedAct, need)] then
		return false, "Clear this act on " .. need .. " to unlock " .. selectedDiff .. "."
	end
	return true, ""
end

function render()
	local def = Story.Defs[selected]
	local done = progress()
	local home = player:GetAttribute("Nation")

	clear(maps)
	for i, id in Story.Order do
		local sdef = Story.Defs[id]
		local on = id == selected
		local card = new("ImageButton", { Size = UDim2.fromOffset(282, 150), Image = sdef.Image, ScaleType = Enum.ScaleType.Crop, BackgroundColor3 = C.Ink, AutoButtonColor = true, LayoutOrder = i, Parent = maps }, { corner(4), stroke(if on then C.Good else C.Bronze, if on then 2.5 else 1, if on then 0 else 0.4) })
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BorderSizePixel = 0, Parent = card }, {
			corner(4),
			new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.9), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		new("ImageLabel", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Image = EMBLEM[id], Parent = card })
		text({ Position = UDim2.fromOffset(12, 96), Size = UDim2.new(1, -24, 0, 24), Text = sdef.Title, FontFace = F.TitleBold, TextSize = 20, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, Parent = card })
		text({ Position = UDim2.fromOffset(12, 122), Size = UDim2.new(1, -24, 0, 18), Text = `Mode: <font color="#{sdef.Color:ToHex()}">Story</font>{if home == id then "   ·   Home ×1.5" else ""}`, RichText = true, FontFace = F.Label, TextSize = 13, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, Parent = card })
		card.Activated:Connect(function()
			selected = id
			selectedAct = 1
			selectedDiff = "Easy"
			render()
		end)
	end

	clear(acts)
	for act, actDef in def.Acts do
		local cleared = done[Story.Key(selected, act)]
		local unlocked = act == 1 or done[Story.Key(selected, act - 1)]
		local sub = if not BUILT[act] then "Coming soon" elseif not unlocked then "Locked" elseif cleared then "Cleared" else "Ready"
		local b = tile(acts, act, 220, nil, "Act " .. act, actDef.Name .. "  ·  " .. sub, if cleared then C.Good else C.Gold, act == selectedAct, not BUILT[act] or not unlocked)
		b.Size = UDim2.fromOffset(220, 96)
		b.Activated:Connect(function()
			selectedAct = act
			render()
		end)
	end

	local actDef = def.Acts[selectedAct]
	local diff = Story.Difficulties[selectedDiff]
	preview.Image = def.Image or ""
	previewName.Text = actDef.Name
	previewTag.Text = `<font color="#{diff.Color:ToHex()}">[{selectedDiff:upper()}]</font>   Story [Act {selectedAct}]   ·   {def.Title}`
	previewText.Text = actDef.Text

	clear(diffRow)
	for i, name in Story.DifficultyOrder do
		local d = Story.Difficulties[name]
		local locked = d.Needs and not done[Story.Key(selected, selectedAct, d.Needs)]
		local sub = if locked then "Clear on " .. d.Needs else `HP ×{d.Health} · loot ×{d.Reward}`
		local b = tile(diffRow, i, (RW - 30) / 4, nil, name, sub, d.Color, name == selectedDiff, locked)
		b.Activated:Connect(function()
			selectedDiff = name
			render()
		end)
	end

	clear(rewardRow)
	local first = not done[Story.Key(selected, selectedAct, selectedDiff)]
	local gold = math.floor(Story.ClearGold[selectedAct] * diff.Reward) * (if first then 2 else 1)
	local essence = Story.EssenceReward[selectedAct] * diff.Reward * (if home == selected then Story.HomeBonus else 1)
	local essenceId = Story.EssenceId(selected)
	local w = (RW - 30) / 4
	tile(rewardRow, 1, w, UIAssets.Coin, tostring(gold), if first then "Gold · first clear ×2" else "Gold", C.Gold, false, false)
	tile(rewardRow, 2, w, UIAssets.Items[essenceId], tostring(math.floor(essence)), Items.Defs[essenceId].Name, def.Color, false, false)
	for i, drop in Story.ShownDrops do
		local item = Items.Defs[drop.Id]
		tile(rewardRow, 2 + i, w, UIAssets.Items[drop.Id], math.floor(drop.Chance * 100) .. "%", item.Name, Items.Rarity[item.Rarity].Color, false, false)
	end

	local ok, why = canStart()
	startBtn.AutoButtonColor = ok
	startBtn.TextTransparency = if ok then 0 else 0.5
	status.Text = why
	status.TextColor3 = C.Ash
end

local function open()
	if player:GetAttribute("InRift") then
		return
	end
	local view = workspace.CurrentCamera.ViewportSize
	content.UIScale.Scale = math.min(1, (view.X - 24) / W, (view.Y - 24) / H)
	selected = selected or (player:GetAttribute("Nation") or "Fire")
	render()
	screen.Visible = true
end

startBtn.Activated:Connect(function()
	if busy or not canStart() then
		return
	end
	busy = true
	status.Text = "Opening the Rift..."
	status.TextColor3 = C.Ash
	local ok, started, msg = pcall(remotes.StartStory.InvokeServer, remotes.StartStory, selected, selectedAct, selectedDiff)
	busy = false
	if ok and started then
		screen.Visible = false
	else
		status.Text = if ok then (msg or "Can't start") else "The Rift is closed"
		status.TextColor3 = C.Bad
	end
end)
local function close()
	screen.Visible = false
end
closeBtn.Activated:Connect(close)
leaveBtn.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input)
	if screen.Visible and input.KeyCode == Enum.KeyCode.Escape then
		close()
	end
end)
player:GetAttributeChangedSignal("StoryProgress"):Connect(function()
	if screen.Visible then
		render()
	end
end)

openStory = open
if pendingOpen then
	open()
end


-------------------------------------------------------------------------------
-- In-run banners
-------------------------------------------------------------------------------

local banner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(640, 110), BackgroundTransparency = 1, Visible = false, Parent = gui })
local bannerKicker = text({ Size = UDim2.new(1, 0, 0, 18), FontFace = F.Label, TextSize = 14, Parent = banner })
local bannerTitle = text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 50), FontFace = F.TitleBold, TextSize = 42, TextColor3 = C.Gold, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, Parent = banner })
local bannerSub = text({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 40), FontFace = F.Italic, TextSize = 19, TextColor3 = C.Parchment, TextWrapped = true, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.5, Parent = banner })
local bannerToken = 0

local function showBanner(payload, duration)
	bannerToken += 1
	local token = bannerToken
	bannerKicker.Text = spaced(if payload.Kind == "Boss" then "Boss" elseif payload.Kind == "Cleared" then "Victory" else "The Rift")
	bannerKicker.TextColor3 = payload.Color or C.Rift
	bannerTitle.Text = payload.Title or ""
	bannerSub.Text = payload.Subtitle or ""
	banner.Visible = true
	for _, t in { bannerKicker, bannerTitle, bannerSub } do
		t.TextTransparency = 1
		tween(t, 0.35, { TextTransparency = 0 })
	end
	task.delay(duration, function()
		if bannerToken == token then
			for _, t in { bannerKicker, bannerTitle, bannerSub } do
				tween(t, 0.6, { TextTransparency = 1 })
			end
			task.wait(0.6)
			if bannerToken == token then
				banner.Visible = false
			end
		end
	end)
end

remotes:WaitForChild("StoryBanner").OnClientEvent:Connect(function(payload)
	if payload.Kind == "Cleared" then
		local essenceName = Items.Defs[payload.EssenceId] and Items.Defs[payload.EssenceId].Name or "Essence"
		payload.Subtitle = `{payload.Subtitle}   ·   +{payload.Gold} gold{if payload.First then " (first clear)" else ""}   ·   +{payload.Essence} {essenceName}\nWalk through the gate to return.`
		showBanner(payload, 7)
	elseif payload.Kind == "Act" then
		showBanner(payload, 5)
	else
		showBanner(payload, 2.5)
	end
end)
