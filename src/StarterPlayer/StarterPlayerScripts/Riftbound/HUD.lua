-- Skill bar, skill list, toasts and the Forge (fusion) screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Merge = require(Shared:WaitForChild("Merge"))
local Skills = require(Shared:WaitForChild("Skills"))

local THEME = {
	Panel = Color3.fromRGB(16, 12, 26),
	PanelLight = Color3.fromRGB(34, 26, 52),
	Accent = Color3.fromRGB(170, 120, 255),
	Text = Color3.fromRGB(240, 235, 255),
	Muted = Color3.fromRGB(150, 140, 175),
	Good = Color3.fromRGB(120, 230, 160),
}

local SLOT_KEYS = {
	{ Slot = "M1", Label = "LMB" },
	{ Slot = "Q", Label = "Q" },
	{ Slot = "E", Label = "E" },
	{ Slot = "Dash", Label = "SHIFT" },
}

local HUD = {}

local remotes
local build = { Skills = {}, Slots = {} }
local discovered = {}
local cooldownEnds = {} -- [skillId] = { Ends, Length }
local dash = { Ends = 0, Length = 1 }
local slotCards = {}
local forgeSelection = {}
local gui, skillListFrame, forgeFrame, toastHolder

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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness)
	return new("UIStroke", { Color = color, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.TextSize = props.TextSize or 14
	return new("TextLabel", props)
end

local function button(props)
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.TextSize = props.TextSize or 14
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.PanelLight
	props.AutoButtonColor = true
	return new("TextButton", props, { corner(6) })
end

-- Round icon coloured by the skill's element(s).
local function icon(id, size, parent)
	local def = Skills.Defs[id]
	local frame = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIGradient", { Color = Elements.SequenceOf(def and def.Elements or {}), Rotation = 45 }),
	})
	label({
		Size = UDim2.fromScale(1, 1),
		Text = def and def.Name:sub(1, 1) or "",
		Font = Enum.Font.GothamBlack,
		TextSize = math.floor(size * 0.5),
		TextColor3 = Color3.fromRGB(20, 14, 30),
		Parent = frame,
	})
	return frame
end

local function skillInSlot(slot)
	if slot == "M1" then
		return "RiftBolt", 1
	end
	local id = build.Slots[slot]
	return id, id and build.Skills[id]
end

-------------------------------------------------------------------------------
-- Toasts
-------------------------------------------------------------------------------

function HUD.Toast(text, color)
	local toast = label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color or THEME.Text,
		TextStrokeTransparency = 0.4,
		Parent = toastHolder,
	})
	task.delay(2.2, function()
		TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.5)
		toast:Destroy()
	end)
end

-------------------------------------------------------------------------------
-- Skill bar
-------------------------------------------------------------------------------

local function makeSlotCard(parent, slot, keyLabel, order)
	local card = new("Frame", {
		Name = slot,
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(12) })
	local border = stroke(THEME.Muted, 2)
	border.Parent = card
	label({
		Size = UDim2.fromOffset(50, 16),
		Position = UDim2.fromOffset(7, 4),
		Text = keyLabel,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Accent,
		Parent = card,
	})
	local level = label({
		Size = UDim2.fromOffset(40, 16),
		Position = UDim2.new(1, -46, 0, 4),
		Text = "",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = THEME.Muted,
		Parent = card,
	})
	local iconHolder = new("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0.5, -17, 0, 20),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local name = label({
		Size = UDim2.new(1, -8, 0, 28),
		Position = UDim2.new(0, 4, 1, -31),
		Text = "",
		TextSize = 11,
		TextWrapped = true,
		Parent = card,
	})
	local shade = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = card,
	}, { corner(12) })
	local timer = label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		ZIndex = 4,
		Parent = card,
	})
	slotCards[slot] = { Border = border, Level = level, IconHolder = iconHolder, Name = name, Shade = shade, Timer = timer, Shown = nil }
end

local function refreshSlots()
	for _, entry in SLOT_KEYS do
		local card = slotCards[entry.Slot]
		local id, level, title, color
		if entry.Slot == "Dash" then
			title, color = "Dash", THEME.Accent
		else
			id, level = skillInSlot(entry.Slot)
			local def = id and Skills.Defs[id]
			title = def and def.Name or "Empty"
			color = def and Elements.ColorOf(def.Elements) or THEME.Muted
		end
		card.Name.Text = title
		card.Border.Color = color
		card.Level.Text = if level and entry.Slot ~= "M1" then `Lv {level}` else ""
		if card.Shown ~= (id or entry.Slot) then
			card.Shown = id or entry.Slot
			card.IconHolder:ClearAllChildren()
			if id then
				icon(id, 34, card.IconHolder)
			elseif entry.Slot == "Dash" then
				label({ Size = UDim2.fromScale(1, 1), Text = ">>", TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = THEME.Accent, Parent = card.IconHolder })
			end
		end
	end
end

local function updateCooldowns()
	local now = os.clock()
	for _, entry in SLOT_KEYS do
		local card = slotCards[entry.Slot]
		local cd
		if entry.Slot == "Dash" then
			cd = dash
		else
			local id = skillInSlot(entry.Slot)
			cd = id and cooldownEnds[id]
		end
		local remaining = cd and cd.Ends - now or 0
		if remaining > 0 then
			card.Shade.Size = UDim2.fromScale(1, math.clamp(remaining / cd.Length, 0, 1))
			card.Timer.Text = if remaining >= 1 then string.format("%d", math.ceil(remaining)) else ""
		else
			card.Shade.Size = UDim2.fromScale(1, 0)
			card.Timer.Text = ""
		end
	end
end

-------------------------------------------------------------------------------
-- Skill list (left side)
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

local function refreshSkillList()
	for _, child in skillListFrame.List:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local owned = sortedOwned()
	skillListFrame.Empty.Visible = #owned == 0
	for i, id in owned do
		local def = Skills.Defs[id]
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = THEME.PanelLight,
			LayoutOrder = i,
			Parent = skillListFrame.List,
		}, { corner(6) })
		local ic = icon(id, 24, row)
		ic.Position = UDim2.fromOffset(5, 5)
		label({
			Size = UDim2.new(1, -110, 1, 0),
			Position = UDim2.fromOffset(35, 0),
			Text = `{def.Name}  <font color="#968caf">Lv {build.Skills[id]}</font>`,
			RichText = true,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		for j, slot in { "Q", "E" } do
			local equipped = build.Slots[slot] == id
			local b = button({
				Size = UDim2.fromOffset(30, 24),
				Position = UDim2.new(1, -70 + (j - 1) * 34, 0, 5),
				Text = slot,
				TextSize = 12,
				BackgroundColor3 = if equipped then THEME.Accent else Color3.fromRGB(55, 45, 80),
				TextColor3 = if equipped then THEME.Panel else THEME.Text,
				Parent = row,
			})
			b.Activated:Connect(function()
				remotes.Equip:FireServer(slot, id)
			end)
		end
	end
end

-------------------------------------------------------------------------------
-- Forge
-------------------------------------------------------------------------------

local refreshForge

local function buildForge()
	forgeFrame = new("Frame", {
		Name = "Forge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(THEME.Accent, 2) })

	label({
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 12),
		Text = "THE FORGE",
		TextSize = 26,
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.Accent,
		Parent = forgeFrame,
	})
	label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 44),
		Text = "Pick two element skills to fuse them into something new",
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.Muted,
		Parent = forgeFrame,
	})
	local close = button({
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -40, 0, 10),
		Text = "X",
		Parent = forgeFrame,
	})
	close.Activated:Connect(function()
		HUD.SetForge(false)
	end)

	new("Frame", {
		Name = "Choices",
		Size = UDim2.new(1, -40, 0, 92),
		Position = UDim2.fromOffset(20, 74),
		BackgroundTransparency = 1,
		Parent = forgeFrame,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local preview = new("Frame", {
		Name = "Preview",
		Size = UDim2.new(1, -40, 0, 92),
		Position = UDim2.fromOffset(20, 176),
		BackgroundColor3 = THEME.PanelLight,
		Parent = forgeFrame,
	}, { corner(10) })
	label({
		Name = "Title",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 8),
		TextSize = 19,
		Font = Enum.Font.GothamBlack,
		RichText = true,
		Text = "",
		Parent = preview,
	})
	label({
		Name = "Body",
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.fromOffset(10, 38),
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		Text = "",
		Parent = preview,
	})

	local fuse = button({
		Name = "Fuse",
		Size = UDim2.fromOffset(180, 40),
		Position = UDim2.new(0.5, -90, 0, 278),
		Text = "FUSE",
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		Parent = forgeFrame,
	})
	fuse.Activated:Connect(function()
		if #forgeSelection ~= 2 or not Merge.Result(forgeSelection[1], forgeSelection[2]) then
			return
		end
		local ok, result = remotes.Merge:InvokeServer(forgeSelection[1], forgeSelection[2])
		if ok then
			forgeSelection = {}
			refreshForge()
		else
			HUD.Toast(result or "Fusion failed", Color3.fromRGB(255, 120, 120))
		end
	end)

	label({
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.fromOffset(20, 330),
		Text = "RECIPE BOOK",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Accent,
		Parent = forgeFrame,
	})
	new("Frame", {
		Name = "Recipes",
		Size = UDim2.new(1, -40, 0, 110),
		Position = UDim2.fromOffset(20, 350),
		BackgroundTransparency = 1,
		Parent = forgeFrame,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -5, 0, 18),
			CellPadding = UDim2.fromOffset(10, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

refreshForge = function()
	if not forgeFrame then
		return
	end
	-- Drop selections the player no longer owns.
	for i = #forgeSelection, 1, -1 do
		if not build.Skills[forgeSelection[i]] then
			table.remove(forgeSelection, i)
		end
	end

	local choices = forgeFrame.Choices
	for _, child in choices:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local anyBase = false
	for order, element in Elements.Order do
		local id = Skills.BaseFor(element)
		if id and build.Skills[id] then
			anyBase = true
			local selected = table.find(forgeSelection, id) ~= nil
			local color = Elements.List[element].Color
			local card = button({
				Size = UDim2.fromOffset(88, 88),
				Text = "",
				LayoutOrder = order,
				BackgroundColor3 = if selected then THEME.PanelLight:Lerp(color, 0.35) else THEME.PanelLight,
				Parent = choices,
			})
			stroke(if selected then color else THEME.Muted, if selected then 3 else 1).Parent = card
			local ic = icon(id, 34, card)
			ic.Position = UDim2.new(0.5, -17, 0, 10)
			label({
				Size = UDim2.new(1, -6, 0, 30),
				Position = UDim2.new(0, 3, 1, -36),
				Text = `{Skills.Defs[id].Name}\nLv {build.Skills[id]}`,
				TextSize = 11,
				TextWrapped = true,
				Parent = card,
			})
			card.Activated:Connect(function()
				local idx = table.find(forgeSelection, id)
				if idx then
					table.remove(forgeSelection, idx)
				else
					if #forgeSelection >= 2 then
						table.remove(forgeSelection, 1)
					end
					table.insert(forgeSelection, id)
				end
				refreshForge()
			end)
		end
	end
	if not anyBase then
		label({
			Size = UDim2.new(1, 0, 1, 0),
			Text = "You have no element skills. Take some from the shrines first.",
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.Muted,
			Parent = choices,
		})
	end

	local title, body = forgeFrame.Preview.Title, forgeFrame.Preview.Body
	local fuse = forgeFrame.Fuse
	local result = #forgeSelection == 2 and Merge.Result(forgeSelection[1], forgeSelection[2])
	if result then
		local a, b, r = Skills.Defs[forgeSelection[1]], Skills.Defs[forgeSelection[2]], Skills.Defs[result]
		local level = Merge.ResultLevel(build.Skills[a.Id], build.Skills[b.Id])
		if build.Skills[result] then
			level = math.min(math.max(build.Skills[result], level) + 1, Skills.MaxLevel)
		end
		local hex = Elements.ColorOf(r.Elements):ToHex()
		title.Text = `{a.Name} + {b.Name}  =  <font color="#{hex}">{r.Name}</font>  <font color="#968caf">Lv {level}</font>`
		body.Text = `{r.Description}  Both ingredient skills are used up.`
		fuse.BackgroundColor3 = THEME.Accent
		fuse.TextColor3 = THEME.Panel
	else
		title.Text = if #forgeSelection < 2 then "Select two skills" else "Those can't be fused"
		body.Text = "Every pair of different elements fuses into a unique skill."
		fuse.BackgroundColor3 = Color3.fromRGB(55, 45, 80)
		fuse.TextColor3 = THEME.Muted
	end

	local recipes = forgeFrame.Recipes
	for _, child in recipes:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local keys = {}
	for key in Merge.All() do
		table.insert(keys, key)
	end
	table.sort(keys)
	for i, key in keys do
		local id = Merge.All()[key]
		local known = discovered[id]
		local hex = Elements.ColorOf(Skills.Defs[id].Elements):ToHex()
		label({
			Text = `{(key:gsub("%+", " + "))}  =  ` .. (if known then `<font color="#{hex}">{Skills.Defs[id].Name}</font>` else "???"),
			RichText = true,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if known then THEME.Text else THEME.Muted,
			LayoutOrder = i,
			Parent = recipes,
		})
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function HUD.ForgeOpen()
	return forgeFrame ~= nil and forgeFrame.Visible
end

function HUD.SetForge(open)
	forgeFrame.Visible = open
	if open then
		refreshForge()
	end
end

function HUD.ToggleForge()
	HUD.SetForge(not forgeFrame.Visible)
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
	refreshSkillList()
	refreshForge()
end

function HUD.Init(remoteFolder)
	remotes = remoteFolder
	local player = Players.LocalPlayer

	gui = new("ScreenGui", {
		Name = "RiftboundHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local bar = new("Frame", {
		Name = "SkillBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(4 * 88 + 3 * 10, 88),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in SLOT_KEYS do
		makeSlotCard(bar, entry.Slot, entry.Label, i)
	end

	skillListFrame = new("Frame", {
		Name = "SkillList",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(250, 330),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { corner(12) })
	label({
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		Text = "YOUR SKILLS",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Accent,
		Parent = skillListFrame,
	})
	label({
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 26),
		Text = "F: Interact   Shift: Dash   Scroll: Zoom",
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Muted,
		Parent = skillListFrame,
	})
	label({
		Name = "Empty",
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 56),
		Text = "Walk up to an element shrine and press F to take its skill.",
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextColor3 = THEME.Muted,
		Parent = skillListFrame,
	})
	new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -16, 1, -56),
		Position = UDim2.fromOffset(8, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = skillListFrame,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	toastHolder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	buildForge()

	remotes.BuildChanged.OnClientEvent:Connect(applyBuild)
	remotes.Notify.OnClientEvent:Connect(HUD.Toast)
	remotes.OpenForge.OnClientEvent:Connect(function()
		HUD.SetForge(true)
	end)
	applyBuild(remotes.GetBuild:InvokeServer())

	RunService.RenderStepped:Connect(updateCooldowns)
end

return HUD
