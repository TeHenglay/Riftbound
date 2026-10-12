-- Skill Trainer (Training Grounds): talk to the trainer (F) to open this
-- picker. Three tabs (Base, Fused, Awakened) list every skill; click one to
-- see it, then Equip on Q or E. Skills you don't own are only borrowed for
-- Training (TestEquipSkill lends them; they're never saved and are taken back
-- when you leave). Closes itself when you leave Training.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Skills = require(Shared:WaitForChild("Skills"))
local Stats = require(Shared:WaitForChild("Stats"))
local Nations = require(Shared:WaitForChild("Nations"))

local SkillTrainer = {}

local player = Players.LocalPlayer
local HUD, remotes
local C, F, new, stroke, text, tween, spaced, slab, popIn
local gui, panel, grid, detail, tabRow, status
local isOpen, tab, selected, busy = false, "Base", nil, false

local W, H = 980, 600
local TABS = { "Base", "Fused", "Awakened" }
local GOLD = Color3.fromRGB(255, 214, 92)
local AWAKEN = Color3.fromRGB(110, 232, 255)

-- Every skill in a tab, sorted by name.
local function skillsIn(name)
	local list = {}
	for id, def in Skills.Defs do
		local fused = #def.Elements == 2
		local wanted = if name == "Awakened" then def.Awakened == true
			elseif name == "Fused" then fused and not def.Awakened
			else #def.Elements == 1 and not def.Awakened
		if wanted and id ~= "RiftBolt" then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return Skills.Defs[a].Name < Skills.Defs[b].Name
	end)
	return list
end

local function clear(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function damageText(def)
	if def.Kind == "Zone" or def.Kind == "Tornado" then
		return string.format("%d per tick  ·  %ds", math.floor((def.TickDamage or 0) + 0.5), def.Duration or 0)
	end
	return tostring(math.floor((def.Damage or 0) + 0.5))
end

local render

local function equip(slot, id)
	if busy then
		return
	end
	busy = true
	local ok, done, msg = pcall(remotes.TestEquipSkill.InvokeServer, remotes.TestEquipSkill, slot, id)
	busy = false
	if ok and done then
		local def = Skills.Defs[id]
		status.Text = `{def.Name} is on {slot}. Go try it on the dummies!`
		status.TextColor3 = C.Good
	else
		status.Text = if ok then (msg or "Can't equip that here") else "Couldn't reach the server"
		status.TextColor3 = C.Bad
	end
end

local function card(parent, order, id)
	local def = Skills.Defs[id]
	local color = HUD.SkillColor(id)
	local on = id == selected
	local build = HUD.Build()
	local equippedOn = if build.Slots.Q == id then "Q" elseif build.Slots.E == id then "E" else nil
	local b = new("TextButton", {
		Size = UDim2.fromOffset(132, 150),
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = if on then color:Lerp(C.Card, 0.7) else C.Card,
		LayoutOrder = order,
		ZIndex = 32,
		Parent = parent,
	}, { stroke(if on then color else C.Bronze, if on then 2.5 else 1.5, if on then 0 else 0.3) })
	local icon = HUD.SkillIcon(id, 78, b, 33)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 12)
	text({
		Position = UDim2.fromOffset(6, 96),
		Size = UDim2.new(1, -12, 0, 32),
		Text = def.Name,
		FontFace = F.BodyBold,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 33,
		Parent = b,
	})
	if equippedOn then
		local tag = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 20),
			BackgroundColor3 = color,
			ZIndex = 34,
			Parent = b,
		})
		text({ Size = UDim2.fromScale(1, 1), Text = equippedOn, FontFace = F.Label, TextSize = 13, TextColor3 = C.Ink, ZIndex = 35, Parent = tag })
	end
	b.Activated:Connect(function()
		selected = id
		status.Text = ""
		render()
	end)
end

local function showDetail(id)
	clear(detail)
	if not id then
		text({ Size = UDim2.new(1, 0, 0, 40), Text = "Pick a skill on the left.", FontFace = F.Italic, TextSize = 16, TextColor3 = C.Ash, ZIndex = 33, Parent = detail })
		return
	end
	local def = Skills.Defs[id]
	local color = HUD.SkillColor(id)
	local build = HUD.Build()
	local icon = HUD.SkillIcon(id, 110, detail, 33)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	text({ Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 30), Text = def.Name, FontFace = F.TitleBold, TextSize = 24, TextColor3 = if def.Awakened then AWAKEN else color, TextWrapped = true, ZIndex = 33, Parent = detail })
	local elements = if #def.Elements > 0 then table.concat(def.Elements, " + ") else "Rift"
	text({ Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 16), Text = spaced(`{elements}  ·  {def.Kind}`), FontFace = F.Label, TextSize = 11, TextColor3 = C.Ash, ZIndex = 33, Parent = detail })
	text({ Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 74), Text = def.Description, FontFace = F.Body, TextSize = 14, TextWrapped = true, TextColor3 = C.Gold, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, Parent = detail })
	local box = new("Frame", { Position = UDim2.fromOffset(0, 256), Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.Card, ZIndex = 33, Parent = detail }, { stroke(C.Bronze, 1.5, 0.3) })
	local cooldown = Skills.CooldownOf(id, 1) * Stats.CooldownMult(player:GetAttribute("Stat_Focus")) * Nations.CooldownMult(player)
	for i, row in { { "Damage", damageText(def) }, { "Cooldown", string.format("%.2fs", cooldown) } } do
		local y = 8 + (i - 1) * 26
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(120, 22), Text = row[1], FontFace = F.Body, TextSize = 15, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34, Parent = box })
		text({ Position = UDim2.fromOffset(130, y), Size = UDim2.new(1, -144, 0, 22), Text = row[2], FontFace = F.BodyBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 34, Parent = box })
	end
	local owned = build.Skills[id] and not (build.Temp or {})[id]
	text({
		Position = UDim2.fromOffset(0, 328),
		Size = UDim2.new(1, 0, 0, 34),
		Text = if owned then "You own this skill." else "Borrowed for Training: it's taken back when you leave and never saved.",
		FontFace = F.Italic,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = if owned then C.Good else C.Ash,
		ZIndex = 33,
		Parent = detail,
	})
	for i, slot in { "Q", "E" } do
		local on = build.Slots[slot] == id
		local b = new("TextButton", {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 370),
			Size = UDim2.new(0.5, -6, 0, 50),
			Text = if on then `ON {slot}` else `EQUIP ON {slot}`,
			FontFace = F.Title,
			TextSize = 18,
			TextColor3 = if on then C.Ink else C.Parchment,
			BackgroundColor3 = if on then color else C.Rift:Lerp(C.Ink, 0.45),
			AutoButtonColor = not on,
			ZIndex = 34,
			Parent = detail,
		}, { stroke(if on then color else C.Rift, 2) })
		if not on then
			b.Activated:Connect(function()
				equip(slot, id)
			end)
		end
	end
end

render = function()
	if not isOpen then
		return
	end
	for _, b in tabRow:GetChildren() do
		if b:IsA("TextButton") then
			local on = b.Name == tab
			b.BackgroundColor3 = if on then C.Rift:Lerp(C.Ink, 0.35) else C.Card
			b.TextColor3 = if on then C.Parchment else C.Ash
		end
	end
	local list = skillsIn(tab)
	if not selected or not table.find(list, selected) then
		selected = list[1]
	end
	clear(grid)
	for i, id in list do
		card(grid, i, id)
	end
	showDetail(selected)
end

function SkillTrainer.Open()
	if isOpen then
		return
	end
	isOpen = true
	HUD.SetLobbyPanel(true) -- dims the screen and pauses casting
	status.Text = ""
	local view = workspace.CurrentCamera.ViewportSize
	local fit = math.min(1, (view.X - 24) / W, (view.Y - 24) / H)
	panel.UIScale.Scale = fit * 0.92
	gui.Enabled = true
	render()
	tween(panel.UIScale, 0.28, { Scale = fit }, Enum.EasingStyle.Back)
end

function SkillTrainer.Close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	HUD.SetLobbyPanel(false)
end

local function build()
	gui = new("ScreenGui", {
		Name = "RiftboundSkillTrainer",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	panel = slab({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		Active = true,
		ZIndex = 30,
		Parent = gui,
	})
	new("UIScale", { Parent = panel })
	text({ Position = UDim2.fromOffset(28, 18), Size = UDim2.fromOffset(400, 34), Text = "Skill Trainer", FontFace = F.TitleBold, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = panel })
	text({ Position = UDim2.fromOffset(28, 52), Size = UDim2.fromOffset(500, 16), Text = "Borrow any skill and try it in the Training Grounds", FontFace = F.Body, TextSize = 14, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = panel })
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		FontFace = F.TitleBold,
		TextSize = 18,
		TextColor3 = C.Parchment,
		BackgroundColor3 = C.Card,
		ZIndex = 33,
		Parent = panel,
	}, { stroke(C.Bronze, 2) })
	close.Activated:Connect(SkillTrainer.Close)

	tabRow = new("Frame", {
		Position = UDim2.fromOffset(28, 84),
		Size = UDim2.fromOffset(3 * 150 + 16, 36),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = panel,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, name in TABS do
		local b = new("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(150, 36),
			Text = spaced(if name == "Fused" then "Fused" else name),
			FontFace = F.Label,
			TextSize = 13,
			AutoButtonColor = true,
			LayoutOrder = i,
			ZIndex = 33,
			Parent = tabRow,
		}, { stroke(if name == "Awakened" then GOLD else C.Bronze, 2, if name == "Awakened" then 0.3 else 0) })
		b.Activated:Connect(function()
			tab = name
			selected = nil
			status.Text = ""
			render()
		end)
	end

	grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(28, 134),
		Size = UDim2.fromOffset(600, H - 134 - 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Rift,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = panel,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(132, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	new("Frame", { Position = UDim2.fromOffset(646, 84), Size = UDim2.new(0, 1, 1, -108), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 32, Parent = panel })
	detail = new("Frame", { Position = UDim2.fromOffset(666, 84), Size = UDim2.fromOffset(W - 666 - 28, 430), BackgroundTransparency = 1, ZIndex = 32, Parent = panel })
	status = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 666, 1, -20),
		Size = UDim2.fromOffset(W - 666 - 28, 44),
		FontFace = F.Italic,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = C.Ash,
		ZIndex = 33,
		Parent = panel,
	})
end

function SkillTrainer.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	local style = HUD.Style
	C, F, new, stroke, text, tween, spaced, slab, popIn =
		style.C, style.F, style.new, style.stroke, style.text, style.tween, style.spaced, style.slab, style.popIn
	build()

	UserInputService.InputBegan:Connect(function(input)
		if isOpen and input.KeyCode == Enum.KeyCode.Escape then
			SkillTrainer.Close()
		end
	end)
	-- Leaving Training (or dying) closes it.
	player:GetAttributeChangedSignal("Area"):Connect(function()
		if player:GetAttribute("Area") ~= "Rift" then
			SkillTrainer.Close()
		end
	end)
	remotes:WaitForChild("BuildChanged").OnClientEvent:Connect(function()
		task.defer(render) -- equipped tags and buttons follow the build
	end)
	task.spawn(function()
		local open = remotes:WaitForChild("OpenSkillTrainer", 30)
		if open then
			open.OnClientEvent:Connect(SkillTrainer.Open)
		end
	end)
end

return SkillTrainer
