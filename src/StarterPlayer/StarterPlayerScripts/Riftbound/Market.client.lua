-- The Crossroads market screens: the Rift Shop (spend gold) and the Goods
-- Merchant (sell loot for gold), in the Shattered Obsidian style. Opened by
-- the stall prompts (server OpenMarket) or locally through
-- NationRemotes.OpenMarketLocal:Fire("Shop" | "Merchant").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Market = require(Shared:WaitForChild("Market"))
local Items = require(Shared:WaitForChild("Items"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local remotes = Shared:WaitForChild("NationRemotes")
local mainRemotes = Shared:WaitForChild("Remotes")

local player = Players.LocalPlayer

local C = {
	Ink = Color3.fromRGB(7, 5, 10),
	Bronze = Color3.fromRGB(168, 119, 63),
	Gold = Color3.fromRGB(233, 194, 122),
	Rift = Color3.fromRGB(178, 108, 255),
	RiftDeep = Color3.fromRGB(64, 26, 128),
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

local function iconFor(offerId, offer)
	if offer.Item then
		return UIAssets.Items[offer.Item]
	elseif offer.Icon == "Flask" then
		return UIAssets.Icons.Flask
	elseif offer.Icon == "Tome" then
		return UIAssets.Stats.Focus
	end
	return UIAssets.Icons.Empty
end

local gui = new("ScreenGui", {
	Name = "RiftboundMarket",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local shade = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.4, Text = "", AutoButtonColor = false, Parent = gui })
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 560),
	BackgroundColor3 = Color3.fromRGB(16, 12, 22),
	Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = C.Bronze, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIScale", {}),
})
new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Grain, ImageTransparency = 0.75, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(256, 256), Parent = panel })
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(90, 9), BackgroundColor3 = C.Bronze, BorderSizePixel = 0, ZIndex = 3, Parent = panel }, { new("UICorner", { CornerRadius = UDim.new(0, 2) }) })
local glow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Rift, BorderSizePixel = 0, Parent = panel }, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }) }),
})
local kicker = text({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 16), FontFace = F.Label, TextSize = 13, TextColor3 = C.Rift, ZIndex = 2, Parent = panel })
local title = text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 40), FontFace = F.TitleBold, TextSize = 34, TextColor3 = C.Gold, ZIndex = 2, Parent = panel })
local subtitle = text({ Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 20), FontFace = F.Italic, TextSize = 18, TextColor3 = C.Ash, ZIndex = 2, Parent = panel })
new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(260, 1), BackgroundColor3 = C.Bronze, BorderSizePixel = 0, ZIndex = 2, Parent = panel })
local goldLabel = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 20), Size = UDim2.fromOffset(160, 22), FontFace = F.BodyBold, TextSize = 18, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2, Parent = panel })
local close = new("TextButton", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.Ink, Text = "X", TextColor3 = C.Ash, TextSize = 18, FontFace = F.BodyBold, ZIndex = 3, Parent = panel }, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIStroke", { Color = C.Bronze, Thickness = 1, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 124),
	Size = UDim2.new(1, -40, 1, -168),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Bronze,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 2,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local status = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -40, 0, 22), FontFace = F.Italic, TextSize = 17, TextColor3 = C.Ash, ZIndex = 2, Parent = panel })

local mode
local inventory = {}

local function setStatus(msg, good)
	status.Text = msg
	status.TextColor3 = if good then C.Good else C.Bad
end

local function button(parent, label, x, width, onClick)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(width, 34),
		BackgroundColor3 = Color3.fromRGB(40, 28, 54),
		Text = label,
		TextColor3 = C.Gold,
		TextSize = 14,
		FontFace = F.Label,
		AutoButtonColor = true,
		ZIndex = 3,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
		new("UIStroke", { Color = C.Bronze, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	b.Activated:Connect(onClick)
	return b
end

local function row(order, icon, name, nameColor, desc, priceText)
	local r = new("Frame", { Size = UDim2.new(1, -6, 0, 70), BackgroundColor3 = Color3.fromRGB(24, 18, 32), LayoutOrder = order, ZIndex = 2, Parent = list }, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
		new("UIStroke", { Color = C.Bronze, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	new("ImageLabel", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Image = icon or "", ZIndex = 3, Parent = r })
	text({ Position = UDim2.fromOffset(74, 9), Size = UDim2.new(1, -290, 0, 22), Text = name, FontFace = F.TitleBold, TextSize = 20, TextColor3 = nameColor or C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = r })
	text({ Position = UDim2.fromOffset(74, 32), Size = UDim2.new(1, -290, 0, 32), Text = desc, FontFace = F.Body, TextSize = 13, TextColor3 = C.Ash, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = r })
	text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -132, 0.5, 0), Size = UDim2.fromOffset(70, 22), Text = priceText, FontFace = F.BodyBold, TextSize = 16, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = r })
	return r
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	goldLabel.Text = tostring(player:GetAttribute("Gold") or 0) .. " gold"
	if mode == "Shop" then
		for i, id in Market.ShopOrder do
			local offer = Market.Shop[id]
			local item = offer.Item and Items.Defs[offer.Item]
			local name = offer.Name or (item and item.Name) or id
			local desc = offer.Description or (item and item.Description) or ""
			local color = item and Items.Rarity[item.Rarity].Color or C.Parchment
			local r = row(i, iconFor(id, offer), name, color, desc, `{offer.Price} g`)
			button(r, "BUY", -10, 110, function()
				local ok, ok2, msg = pcall(remotes.MarketBuy.InvokeServer, remotes.MarketBuy, id)
				setStatus(if ok then (msg or "") else "The shop is closed", ok and ok2)
				if ok and ok2 then
					setStatus(`Bought {name}`, true)
				end
				render()
			end)
		end
	else
		local any = false
		for i, id in Items.Order do
			local price = Market.SellPrice[id]
			local owned = inventory[id] or 0
			local def = Items.Defs[id]
			if price then
				any = any or owned > 0
				local r = row(i, UIAssets.Items[id], `{def.Name}  ×{owned}`, Items.Rarity[def.Rarity].Color, def.Description, `{price} g`)
				local function sell(count)
					local ok, ok2, msg = pcall(remotes.MarketSell.InvokeServer, remotes.MarketSell, id, count)
					setStatus(if ok then (msg or "") else "The merchant is away", ok and ok2)
				end
				button(r, "SELL 1", -62, 52, function()
					sell(1)
				end).Active = owned > 0
				button(r, "ALL", -6, 52, function()
					sell("all")
				end).Active = owned > 0
			end
		end
		if not any then
			setStatus("Bring loot from the Rift: Rift Husks drop shards, ichor and cores.", false)
			status.TextColor3 = C.Ash
		end
	end
end

local function open(kind)
	if kind ~= "Shop" and kind ~= "Merchant" then
		return
	end
	mode = kind
	if kind == "Shop" then
		kicker.Text = spaced("The Crossroads")
		title.Text = "The Rift Shop"
		subtitle.Text = "Spend your gold. Prices hold steady in every nation."
	else
		kicker.Text = spaced("The Crossroads")
		title.Text = "Goods Merchant"
		subtitle.Text = "Sell the loot you carry home from the Rift."
	end
	status.Text = ""
	local ok, snapshot = pcall(mainRemotes.GetInventory.InvokeServer, mainRemotes.GetInventory)
	inventory = ok and snapshot or {}
	local view = workspace.CurrentCamera.ViewportSize
	panel.UIScale.Scale = math.min(1, (view.X - 32) / 560, (view.Y - 32) / 560)
	render()
	gui.Enabled = true
	panel.Position = UDim2.new(0.5, 0, 0.5, 16)
	tween(panel, 0.2, { Position = UDim2.fromScale(0.5, 0.5) })
end

local function hide()
	gui.Enabled = false
	mode = nil
end

remotes:WaitForChild("OpenMarket").OnClientEvent:Connect(open)
remotes:WaitForChild("OpenMarketLocal").Event:Connect(open)
close.Activated:Connect(hide)
shade.Activated:Connect(hide)
UserInputService.InputBegan:Connect(function(input)
	if gui.Enabled and input.KeyCode == Enum.KeyCode.Escape then
		hide()
	end
end)
mainRemotes:WaitForChild("InventoryChanged").OnClientEvent:Connect(function(snapshot)
	inventory = snapshot
	if mode then
		render()
	end
end)
player:GetAttributeChangedSignal("Gold"):Connect(function()
	if mode then
		goldLabel.Text = tostring(player:GetAttribute("Gold") or 0) .. " gold"
	end
end)
-- Leaving the Crossroads closes the market.
player:GetAttributeChangedSignal("Area"):Connect(function()
	if player:GetAttribute("Area") ~= "Crossroads" then
		hide()
	end
end)
