-- Story screen (pick a nation's story and an act), plus in-run banners: act
-- intro, wave counter, boss name and the "Act Cleared" rewards card. Opened
-- with NationRemotes.OpenStoryLocal:Fire() (the Play page's Story card).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Theme = require(Shared:WaitForChild("Theme"))
local Story = require(Shared:WaitForChild("Story"))
local Nations = require(Shared:WaitForChild("Nations"))
local Items = require(Shared:WaitForChild("Items"))
local Skills = require(Shared:WaitForChild("Skills"))
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

-- Colours and fonts come from the shared modern theme (Theme.lua).
local C = Theme.Palette()
local F = Theme.F
local EMBLEM = UIAssets.Nations
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
	return text({ Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 16), Text = value, FontFace = F.Italic, TextSize = 14, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
end
-- Runs are private to you and your party (invite from Play > Party).
local partyLabel = toggle(28, "PARTY", "")
toggle(240, "LOBBY", "Private · just you and your party")
local function refreshParty()
	if player:GetAttribute("PartyLeader") then
		partyLabel.Text = "You lead · they come with you"
	elseif player:GetAttribute("PartyId") then
		partyLabel.Text = "Your leader picks the act"
	else
		partyLabel.Text = "Solo · invite in Play > Party"
	end
end
refreshParty()
player:GetAttributeChangedSignal("PartyId"):Connect(refreshParty)
player:GetAttributeChangedSignal("PartyLeader"):Connect(refreshParty)
local status = text({ Position = UDim2.fromOffset(456, 652), Size = UDim2.fromOffset(420, 44), FontFace = F.Italic, TextSize = 16, TextWrapped = true, TextColor3 = C.Ash, Parent = content })
local leaveBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 652), Size = UDim2.fromOffset(150, 46), BackgroundColor3 = Color3.fromRGB(40, 20, 26), Text = "LEAVE", TextColor3 = C.Parchment, TextSize = 18, FontFace = F.Label, Parent = content }, { corner(3), stroke(C.Bad, 1.5, 0.2) })
local startBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -190, 0, 652), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = Color3.fromRGB(28, 54, 30), Text = "START", TextColor3 = C.Gold, TextSize = 20, FontFace = F.Label, Parent = content }, { corner(3), stroke(C.Good, 2, 0) })

local selected, selectedAct, selectedDiff = nil, 1, Story.DefaultDifficulty
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

-- A small label hanging over a button's top-right corner (RARE DROP, CLEARED).
local function cornerTag(b, label, color)
	local tag = new("Frame", { Name = "CornerTag", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, -9), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, ZIndex = (b.ZIndex or 1) + 2, Parent = b }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		Theme.Edged(2),
	})
	text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = label, FontFace = F.BodyBold, TextSize = 11, TextColor3 = Color3.fromRGB(16, 20, 12), ZIndex = (b.ZIndex or 1) + 3, Parent = tag })
	return tag
end

-- Gold frame and a corner tag: marks the rare skill drop wherever it shows.
local function rareStyle(b, label)
	b.BackgroundColor3 = Color3.fromRGB(40, 32, 14)
	local edge = b:FindFirstChildOfClass("UIStroke")
	edge.Color = Theme.C.Coin
	edge.Thickness = 3
	edge.Transparency = 0
	cornerTag(b, label, Theme.C.Coin)
end

local render

local function canStart()
	if player:GetAttribute("PartyId") and not player:GetAttribute("PartyLeader") then
		return false, "Your party leader picks the act."
	end
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
			selectedDiff = Story.DefaultDifficulty
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
		if cleared then
			-- Green corner tag; it says HARD too once the act is beaten on Hard.
			local hard = done[Story.Key(selected, act, "Hard")]
			cornerTag(b, if hard then "CLEARED · HARD" else "CLEARED", C.Good)
		end
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
		local count = #Story.DifficultyOrder
		local b = tile(diffRow, i, (RW - 10 * (count - 1)) / count, nil, name, sub, d.Color, name == selectedDiff, locked)
		b.Activated:Connect(function()
			selectedDiff = name
			render()
		end)
	end

	clear(rewardRow)
	local first = not done[Story.Key(selected, selectedAct, selectedDiff)]
	local gold = math.floor(Story.ClearGold[selectedAct] * diff.Reward) * (if first then 2 else 1)
	-- The act-clear bundle: gold plus the guaranteed materials (mobs drop none).
	local bundle = Story.Bundle(selected, selectedAct, selectedDiff, home == selected)
	local dropSkill, dropChance = Story.SkillDropOf(selected, selectedAct)
	local n = 1 + #bundle + (if dropSkill then 1 else 0)
	local w = (RW - 10 * (n - 1)) / n
	local roomy = w >= 150 -- narrow tiles drop the icon so the text fits
	tile(rewardRow, 1, w, if roomy then UIAssets.Coin else nil, tostring(gold), if first then "Gold · first clear ×2" else "Gold", C.Gold, false, false)
	for i, entry in bundle do
		local item = Items.Defs[entry.Id]
		tile(rewardRow, 1 + i, w, if roomy then UIAssets.Items[entry.Id] else nil, "×" .. entry.Count, item.Name, Items.Rarity[item.Rarity].Color, false, false)
	end
	-- The skill drop leads the row (LayoutOrder 0) in a gold frame with a tag,
	-- so the chance at a new skill stands out from the guaranteed loot.
	if dropSkill then
		local skill = Skills.Defs[dropSkill]
		local b = tile(rewardRow, 0, w, if roomy then UIAssets.Icons[dropSkill] else nil, math.floor(dropChance * 100) .. "%", skill.Name .. " · skill", Theme.C.Coin, false, false)
		rareStyle(b, "RARE DROP")
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
local bannerSub = text({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 64), FontFace = F.Italic, TextSize = 19, TextColor3 = C.Parchment, TextWrapped = true, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.5, Parent = banner })
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


-------------------------------------------------------------------------------
-- Results: the act-cleared screen. A header showing the story's map art, the
-- run's stats (clear time, damage, kills), the rewards, and Retry / Next /
-- Lobby. Everything animates in.
-------------------------------------------------------------------------------

local RES_W, RES_H = 800, 648
local BAND_H = 200 -- map art header
local RES_PAD = 32
local BTN = {
	Retry = Color3.fromRGB(255, 172, 64),
	Next = Color3.fromRGB(96, 214, 128),
	Lobby = Color3.fromRGB(236, 78, 78),
}

local results = new("Frame", { Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Visible = false, Active = true, ZIndex = 30, Parent = gui })
local resCard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RES_W, RES_H), BackgroundColor3 = Theme.C.Panel, ZIndex = 31, Parent = results }, { Theme.Edged(4) })
local resScale = new("UIScale", { Parent = resCard })

-- Header: the story's map art (as on the Story screen), darkened toward the
-- bottom-left so the emblem and title stay readable.
local resMap = new("ImageLabel", { Size = UDim2.new(1, 0, 0, BAND_H), BackgroundColor3 = Theme.C.Ink, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, ZIndex = 31, Parent = resCard })
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 31, Parent = resMap }, {
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0.15) }) }),
})
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 31, Parent = resMap }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.9), NumberSequenceKeypoint.new(1, 1) }) }),
})
new("Frame", { Position = UDim2.fromOffset(0, BAND_H), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 32, Parent = resCard })
local DIA = 78
local DIA_Y = BAND_H - 66 -- emblem and title sit low on the art
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(RES_PAD + 52, DIA_Y), Size = UDim2.fromOffset(DIA, DIA), Rotation = 45, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 32, Parent = resCard })
local resDiamond = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(RES_PAD + 52, DIA_Y), Size = UDim2.fromOffset(DIA - 10, DIA - 10), Rotation = 45, BackgroundColor3 = Theme.C.Raised, BorderSizePixel = 0, ZIndex = 33, Parent = resCard })
local resEmblem = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(RES_PAD + 52, DIA_Y), Size = UDim2.fromOffset(86, 86), BackgroundTransparency = 1, ZIndex = 34, Parent = resCard })
local TX = RES_PAD + 124
local TY = BAND_H - 106
local resKicker = text({ Position = UDim2.fromOffset(TX, TY), Size = UDim2.new(1, -TX - RES_PAD, 0, 16), Text = spaced("Victory"), FontFace = F.Label, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.15, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34, Parent = resCard })
local resTitle = text({ Position = UDim2.fromOffset(TX, TY + 16), Size = UDim2.new(1, -TX - RES_PAD, 0, 46), FontFace = F.TitleBold, TextSize = 42, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34, Parent = resCard })
local resTags = new("Frame", { Position = UDim2.fromOffset(TX, TY + 66), Size = UDim2.new(1, -TX - RES_PAD, 0, 24), BackgroundTransparency = 1, ZIndex = 34, Parent = resCard }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Stats row.
local STAT_Y = BAND_H + 26
local resStats = new("Frame", { Position = UDim2.fromOffset(RES_PAD, STAT_Y), Size = UDim2.new(1, -RES_PAD * 2, 0, 84), BackgroundTransparency = 1, ZIndex = 32, Parent = resCard }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local statValue = {}
for i, info in {
	{ Key = "Time", Label = "Clear time", Color = Color3.fromRGB(110, 200, 255) },
	{ Key = "Damage", Label = "Damage dealt", Color = Color3.fromRGB(255, 96, 88) },
	{ Key = "Kills", Label = "Enemies defeated", Color = Color3.fromRGB(255, 196, 80) },
} do
	local box = new("Frame", { Size = UDim2.new(1 / 3, -10, 1, 0), BackgroundColor3 = Theme.C.Raised, LayoutOrder = i, ZIndex = 33, Parent = resStats }, { Theme.Edged(2) })
	new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = info.Color, BorderSizePixel = 0, ZIndex = 34, Parent = box })
	text({ Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 14), Text = spaced(info.Label), FontFace = F.Label, TextSize = 10, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34, Parent = box })
	statValue[info.Key] = text({ Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 38), FontFace = F.TitleBold, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34, Parent = box })
end

-- Rewards.
local REW_Y = STAT_Y + 84 + 26
text({ Position = UDim2.fromOffset(RES_PAD, REW_Y), Size = UDim2.fromOffset(200, 14), Text = spaced("Rewards"), FontFace = F.Label, TextSize = 11, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = resCard })
local resRewards = new("Frame", { Position = UDim2.fromOffset(RES_PAD, REW_Y + 26), Size = UDim2.new(1, -RES_PAD * 2, 0, 120), BackgroundTransparency = 1, ZIndex = 32, Parent = resCard }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Buttons and status line.
local resButtons = new("Frame", { Position = UDim2.fromOffset(RES_PAD, RES_H - 104), Size = UDim2.new(1, -RES_PAD * 2, 0, 62), BackgroundTransparency = 1, ZIndex = 32, Parent = resCard }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local resStatus = text({ Position = UDim2.fromOffset(RES_PAD, RES_H - 34), Size = UDim2.new(1, -RES_PAD * 2, 0, 18), FontFace = F.Body, TextSize = 13, TextColor3 = C.Bad, ZIndex = 32, Parent = resCard })

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Counts a stat up from zero.
local function countUp(label, target, format, delay)
	label.Text = format(0)
	task.delay(delay, function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.8 do
			local a = (os.clock() - t0) / 0.8
			label.Text = format(target * (1 - (1 - a) ^ 3))
			task.wait()
		end
		label.Text = format(target)
	end)
end

local function chip(order, label, bg, fg)
	local f = new("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = bg, LayoutOrder = order, ZIndex = 35, Parent = resTags }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Theme.Edged(2),
	})
	text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = label, FontFace = F.BodyBold, TextSize = 12, TextColor3 = fg, ZIndex = 36, Parent = f })
end

-- A reward cell: icon on top, amount and name underneath. Pops in after `delay`.
local function rewardCell(order, icon, amount, name, color, rare, delay)
	local holder = new("Frame", { Size = UDim2.fromOffset(104, 120), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 33, Parent = resRewards })
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.C.Raised, ZIndex = 33, Parent = holder }, { stroke(C.Bronze, 2) })
	local pop = new("UIScale", { Scale = 0, Parent = b })
	if icon then
		new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Image = icon, ZIndex = 34, Parent = b })
	end
	text({ Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 22), Text = amount, FontFace = F.TitleBold, TextSize = 20, TextColor3 = color, ZIndex = 34, Parent = b })
	text({ Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 16), Text = name, FontFace = F.Body, TextSize = 12, TextColor3 = C.Ash, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 34, Parent = b })
	if rare then
		rareStyle(b, rare)
	end
	task.delay(delay, function()
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

local resBusy = false
local function resAction(action)
	if resBusy then
		return
	end
	resBusy = true
	resStatus.Text = ""
	local ok, done, msg = pcall(function()
		local r = remotes:WaitForChild("StoryAction", 5)
		return r:InvokeServer(action)
	end)
	resBusy = false
	if ok and done then
		results.Visible = false
	else
		resStatus.Text = if ok then (msg or "Can't do that right now") else "The Rift is closed"
	end
end

local function resButton(order, label, color, enabled, action)
	local b = new("TextButton", {
		Size = UDim2.new(1 / 3, -10, 1, 0),
		Text = label,
		FontFace = F.TitleBold,
		TextSize = 20,
		TextColor3 = if enabled then Theme.C.Ink else C.Ash,
		BackgroundColor3 = if enabled then color else Theme.C.Raised,
		AutoButtonColor = false,
		LayoutOrder = order,
		ZIndex = 33,
		Parent = resButtons,
	}, { Theme.Edged(3) })
	if enabled then
		local base = color
		b.MouseEnter:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.18) })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = base })
		end)
		b.Activated:Connect(function()
			resAction(action)
		end)
	end
	return b
end

local function clearChildren(frame)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function showResults(payload)
	local story = Story.Defs[payload.Nation]
	local color = payload.Color or C.Rift
	resMap.Image = (story and story.Image) or ""
	resDiamond.BackgroundColor3 = color:Lerp(Theme.C.Raised, 0.7)
	resEmblem.Image = EMBLEM[payload.Nation] or ""
	resTitle.Text = (payload.Title or "Act Cleared"):upper()
	resKicker.Text = spaced("Victory") .. "   ·   " .. (payload.Subtitle or "")
	resStatus.Text = ""

	clearChildren(resTags)
	local diff = Story.Difficulties[payload.Difficulty]
	if diff then
		chip(1, payload.Difficulty:upper(), diff.Color, Theme.C.Ink)
	end
	if payload.First then
		chip(2, "FIRST CLEAR  ·  GOLD ×2", Theme.C.Coin, Theme.C.Ink)
	end

	countUp(statValue.Time, payload.Time or 0, clock, 0.25)
	countUp(statValue.Damage, payload.Damage or 0, commas, 0.35)
	countUp(statValue.Kills, payload.Kills or 0, commas, 0.45)

	clearChildren(resRewards)
	local order, delay = 1, 0.55
	if payload.Skill and Skills.Defs[payload.Skill.Id] then
		local copy = payload.Skill.Copy
		rewardCell(0, UIAssets.Icons[payload.Skill.Id], if copy then "+1 Copy" else "New!", Skills.Defs[payload.Skill.Id].Name, Theme.C.Coin, if copy then "DUPLICATE" else "NEW SKILL", delay)
		delay += 0.08
	end
	rewardCell(order, UIAssets.Coin, "+" .. commas(payload.Gold or 0), "Gold", Theme.C.Coin, nil, delay)
	for _, entry in payload.Items or {} do
		order += 1
		delay += 0.08
		local item = Items.Defs[entry.Id]
		rewardCell(order, UIAssets.Items[entry.Id], "×" .. entry.Count, if item then item.Name else entry.Id, if item then Items.Rarity[item.Rarity].Color else C.Parchment, nil, delay)
	end

	clearChildren(resButtons)
	local nextAct = payload.Act and payload.Act + 1
	local hasNext = story ~= nil and story.Acts[nextAct] ~= nil
	local nextBuilt = hasNext and BUILT[nextAct] == true
	resButton(1, "Retry", BTN.Retry, true, "Retry")
	resButton(2, if nextBuilt then "Next Act" elseif hasNext then "Next Act · Soon" else "Last Act", BTN.Next, nextBuilt, "Next")
	resButton(3, "Lobby", BTN.Lobby, true, "Lobby")

	-- Entrance: the shade fades in and the card scales up.
	local view = workspace.CurrentCamera.ViewportSize
	local fit = math.min(1, (view.X - 24) / RES_W, (view.Y - 24) / RES_H)
	results.BackgroundTransparency = 1
	results.Visible = true
	tween(results, 0.3, { BackgroundTransparency = 0.3 })
	resScale.Scale = fit * 0.88
	TweenService:Create(resScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
end

-- Dying or leaving the run closes it.
player:GetAttributeChangedSignal("StoryRun"):Connect(function()
	if not player:GetAttribute("StoryRun") then
		results.Visible = false
	end
end)

remotes:WaitForChild("StoryBanner").OnClientEvent:Connect(function(payload)
	if payload.Kind == "Cleared" then
		showResults(payload)
	elseif payload.Kind == "Act" then
		results.Visible = false -- the party leader picked Retry or Next
		showBanner(payload, 5)
	else
		showBanner(payload, 2.5)
	end
end)
