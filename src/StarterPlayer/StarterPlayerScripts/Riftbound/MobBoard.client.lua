-- Summoning board panel (training arena). The server opens it from the
-- board's prompt with the mob catalog; each card asks the server to summon
-- that mob on the pad. Golems pick a wave size. See MobBoard.server.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Theme = require(Shared:WaitForChild("Theme"))
local remote = Shared:WaitForChild("Remotes"):WaitForChild("MobBoard")
local player = Players.LocalPlayer

-- Colours and fonts come from the shared modern theme (Theme.lua).
local C = Theme.Palette()
local F = Theme.F

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
local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 4) })
end
local function stroke(color, t, tr)
	return new("UIStroke", { Color = color, Thickness = t or 1.5, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function button(props)
	props.AutoButtonColor = true
	props.FontFace = props.FontFace or F.Bold
	props.TextColor3 = props.TextColor3 or C.Parchment
	props.TextSize = props.TextSize or 14
	local b = new("TextButton", props)
	corner(3).Parent = b
	return b
end

local gui = new("ScreenGui", {
	Name = "RiftboundMobBoard",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 46,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local W, H = 820, 560
local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, Active = true, Parent = gui })
local content = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.Panel, Parent = screen }, {
	corner(6), stroke(C.Bronze, 2, 0),
})
local uiScale = new("UIScale", { Parent = content })

text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(400, 18), Text = "T R A I N I N G   G R O U N D S", FontFace = F.Bold, TextSize = 13, TextColor3 = C.Rift, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
text({ Position = UDim2.fromOffset(24, 30), Size = UDim2.fromOffset(500, 40), Text = "Summoning Board", FontFace = F.Title, TextSize = 32, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
local countLabel = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 26), Size = UDim2.fromOffset(260, 20), Text = "", FontFace = F.Bold, TextSize = 15, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Right, Parent = content })
local hint = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 46), Size = UDim2.fromOffset(320, 18), Text = "Summons appear on the glowing pad. No rewards.", TextSize = 13, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Right, Parent = content })
local closeBtn = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 20), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.Ink, Text = "X", TextColor3 = C.Ash, TextSize = 18, Parent = content })
stroke(C.Bronze, 1, 0.3).Parent = closeBtn

local tabsRow = new("Frame", { Position = UDim2.fromOffset(24, 82), Size = UDim2.new(1, -48, 0, 34), BackgroundTransparency = 1, Parent = content }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local clearBtn = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 82), Size = UDim2.fromOffset(150, 34), BackgroundColor3 = Color3.fromRGB(60, 20, 26), Text = "Clear my mobs", Parent = content })
stroke(C.Bad, 1, 0.4).Parent = clearBtn

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(24, 128),
	Size = UDim2.new(1, -48, 1, -148),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.Bronze,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = content,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(250, 104), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
})

local GROUPS = { "Golems", "Bosses", "Training" }
local SHORT = { Swarmer = "Small", Grunt = "Normal", Brute = "Big", Elite = "Elite" }
local catalog = {}
local current = GROUPS[1]
local tabButtons = {}

local function summon(id, kind)
	remote:FireServer("Summon", id, kind)
end

local function card(entry, order)
	local frame = new("Frame", { LayoutOrder = order, BackgroundColor3 = C.Card, Parent = list }, {
		corner(4), stroke(entry.Color, 1, 0.55),
		new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = entry.Color, BorderSizePixel = 0 }, { corner(2) }),
	})
	text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -22, 0, 24), Text = entry.Name, FontFace = F.Bold, TextSize = 18, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	text({ Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -22, 0, 18), Text = entry.Sub or "", TextSize = 13, TextColor3 = C.Ash, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local row = new("Frame", { Position = UDim2.new(0, 14, 1, -42), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1, Parent = frame }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if entry.Kinds then
		local n = #entry.Kinds
		for i, kind in entry.Kinds do
			local b = button({ LayoutOrder = i, Size = UDim2.new(1 / n, -4, 1, 0), BackgroundColor3 = C.Ink, Text = SHORT[kind] or kind, TextSize = 13, Parent = row })
			stroke(entry.Color, 1, 0.4).Parent = b
			b.Activated:Connect(function()
				summon(entry.Id, kind)
			end)
		end
	else
		local b = button({ Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.Ink, Text = "Summon", Parent = row })
		stroke(entry.Color, 1, 0.4).Parent = b
		b.Activated:Connect(function()
			summon(entry.Id)
		end)
	end
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, entry in catalog do
		if entry.Group == current then
			card(entry, i)
		end
	end
	for group, b in tabButtons do
		local on = group == current
		b.BackgroundColor3 = if on then C.Bronze else C.Ink
		b.TextColor3 = if on then C.Ink else C.Parchment
	end
	list.CanvasPosition = Vector2.zero
end

for i, group in GROUPS do
	local b = button({ LayoutOrder = i, Size = UDim2.fromOffset(120, 34), BackgroundColor3 = C.Ink, Text = group, TextSize = 15, Parent = tabsRow })
	stroke(C.Bronze, 1, 0.3).Parent = b
	tabButtons[group] = b
	b.Activated:Connect(function()
		current = group
		render()
	end)
end

local function fit()
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		uiScale.Scale = math.min(1, (v.X - 24) / W, (v.Y - 24) / H)
	end
end

local function close()
	gui.Enabled = false
end

closeBtn.Activated:Connect(close)
clearBtn.Activated:Connect(function()
	remote:FireServer("Clear")
end)
UserInputService.InputBegan:Connect(function(input)
	if gui.Enabled and input.KeyCode == Enum.KeyCode.Escape then
		close()
	end
end)

remote.OnClientEvent:Connect(function(action, a, b)
	if action == "Open" then
		catalog = a or {}
		fit()
		render()
		gui.Enabled = true
		content.Position = UDim2.new(0.5, 0, 0.5, 16)
		TweenService:Create(content, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	elseif action == "Count" then
		countLabel.Text = ("Your mobs: %d / %d"):format(a, b)
		countLabel.TextColor3 = if a >= b then C.Bad else C.Ash
	elseif action == "Full" then
		hint.Text = ("Limit reached (%d). Clear some mobs first."):format(a)
		hint.TextColor3 = C.Bad
		task.delay(2.5, function()
			hint.Text = "Summons appear on the glowing pad. No rewards."
			hint.TextColor3 = C.Ash
		end)
	end
end)

-- Walking away from the board closes the panel.
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui.Enabled then
			local board = workspace:FindFirstChild("RiftboundTestArena")
			board = board and board:FindFirstChild("MobBoard")
			local base = board and board:FindFirstChild("Base")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not base or not root or (root.Position - base.Position).Magnitude > 30 then
				close()
			end
		end
	end
end)
