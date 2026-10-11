-- The UI look shared by every screen: modern and minimal. Flat dark panels
-- with hard black edges and square corners (matching the black rim on the
-- diamond skill icons), one clean sans face (BuilderSans), white text, and
-- colour used only as an accent (element, rarity, rift purple).
--
-- Screens keep their own palette tables (C) and font tables (F) but fill them
-- from here. Theme.Apply(screenGui) then restyles whatever the old art left
-- behind as it is built: ornate slab / banner / row images become flat
-- panels, rounded corners go square, outlines turn into sharp black edges and
-- the smoke and grain overlays are hidden.
local Theme = {}

local function face(weight, style)
	return Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, weight, style or Enum.FontStyle.Normal)
end

Theme.Font = {
	Regular = face(Enum.FontWeight.Regular),
	Medium = face(Enum.FontWeight.Medium),
	Bold = face(Enum.FontWeight.Bold),
	Heavy = face(Enum.FontWeight.ExtraBold),
}

-- Font table in the shape the screens already use.
Theme.F = {
	Title = Theme.Font.Heavy,
	TitleBold = Theme.Font.Heavy,
	Body = Theme.Font.Medium,
	BodyBold = Theme.Font.Bold,
	Bold = Theme.Font.Bold,
	Label = Theme.Font.Bold,
	Italic = Theme.Font.Regular,
}

Theme.C = {
	Black = Color3.new(0, 0, 0),
	Ink = Color3.fromRGB(8, 9, 13), -- screen shade
	Panel = Color3.fromRGB(20, 21, 28), -- panels and cards
	Raised = Color3.fromRGB(32, 34, 44), -- rows, buttons, wells
	Text = Color3.fromRGB(245, 246, 250),
	Light = Color3.fromRGB(214, 217, 226),
	Muted = Color3.fromRGB(160, 164, 178),
	Faint = Color3.fromRGB(110, 114, 128),
	Rift = Color3.fromRGB(168, 110, 255),
	RiftHot = Color3.fromRGB(222, 200, 255),
	RiftDeep = Color3.fromRGB(10, 10, 14), -- was a purple text stroke; now plain ink
	Good = Color3.fromRGB(120, 220, 120),
	Bad = Color3.fromRGB(236, 80, 88),
	Coin = Color3.fromRGB(255, 200, 80), -- gold currency only
}

-- Old palette names mapped onto the theme, so existing code keeps working.
function Theme.Palette(extra)
	local C = Theme.C
	local p = {
		Ink = C.Ink,
		Panel = C.Panel,
		Card = C.Raised,
		Bronze = C.Black, -- every old bronze outline becomes a black edge
		Gold = C.Light, -- old gold lettering becomes light grey text
		Parchment = C.Text,
		Ash = C.Muted,
		Rift = C.Rift,
		RiftHot = C.RiftHot,
		RiftDeep = C.RiftDeep,
		Good = C.Good,
		Bad = C.Bad,
		Crimson = Color3.fromRGB(214, 44, 56),
		Blood = Color3.fromRGB(70, 12, 18),
	}
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end

Theme.Edge = 3 -- panel outline thickness

-- A hard black outline with square corners.
function Theme.Edged(thickness, color)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.C.Black
	s.Thickness = thickness or Theme.Edge
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

-------------------------------------------------------------------------------
-- Restyling pass
-------------------------------------------------------------------------------

local UIAssets = require(script.Parent:WaitForChild("UIAssets"))

-- Ornate panel art that becomes a flat panel, and texture overlays that hide.
local PANEL_ART = {}
for _, id in { UIAssets.Slab, UIAssets.Row, UIAssets.Bar, UIAssets.Medallion } do
	if id then
		PANEL_ART[id] = true
	end
end
-- Banner art (panel titles, toasts) simply disappears: the title text sits
-- straight on the panel or the screen.
local HEADER_ART = { [UIAssets.Banner] = true }
local OVERLAY_ART = {}
for _, id in { UIAssets.Smoke, UIAssets.Grain } do
	if id then
		OVERLAY_ART[id] = true
	end
end

local function hasEdge(inst)
	for _, child in inst:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			return true
		end
	end
	return false
end

local function restyle(inst)
	if inst:GetAttribute("ThemeSkip") then
		return
	end
	if inst:IsA("UICorner") then
		inst.CornerRadius = UDim.new(0, 0)
	elseif inst:IsA("UIStroke") then
		inst.LineJoinMode = Enum.LineJoinMode.Miter
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if PANEL_ART[inst.Image] then
			inst.Image = ""
			inst.BackgroundColor3 = Theme.C.Panel
			inst.BackgroundTransparency = 0.06
			inst.BorderSizePixel = 0
			if not hasEdge(inst) then
				Theme.Edged().Parent = inst
			end
		elseif HEADER_ART[inst.Image] then
			inst.Image = ""
			inst.BackgroundTransparency = 1
		elseif OVERLAY_ART[inst.Image] then
			inst.Visible = false
		end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		-- Any leftover face becomes BuilderSans at the nearest weight.
		local f = inst.FontFace
		if not f.Family:find("BuilderSans") then
			local w = f.Weight
			local weight = if w.Value >= 800 then Enum.FontWeight.ExtraBold
				elseif w.Value >= 600 then Enum.FontWeight.Bold
				elseif w.Value >= 500 then Enum.FontWeight.Medium
				else Enum.FontWeight.Regular
			inst.FontFace = face(weight)
		elseif f.Style == Enum.FontStyle.Italic then
			inst.FontFace = face(f.Weight)
		end
	end
end

-- Restyles everything under `root` now and anything added later.
function Theme.Apply(root)
	if root:GetAttribute("Themed") then
		return
	end
	root:SetAttribute("Themed", true)
	for _, inst in root:GetDescendants() do
		restyle(inst)
	end
	root.DescendantAdded:Connect(function(inst)
		-- Wait a frame so the builder has finished setting properties.
		task.defer(restyle, inst)
	end)
end

return Theme
