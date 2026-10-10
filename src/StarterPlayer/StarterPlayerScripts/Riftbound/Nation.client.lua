-- Nation select screen (first join), travel fades between the lobby and the
-- Rift, and lobby ambience (sky tint, spinning crystals, windmills, flowing
-- waterfall, flickering lights, lightning strikes).
-- Drawn in the Shattered Obsidian style used by HUD.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Nations = require(Shared:WaitForChild("Nations"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local remotes = Shared:WaitForChild("NationRemotes")

local player = Players.LocalPlayer

local C = {
	Ink = Color3.fromRGB(7, 5, 10),
	Bronze = Color3.fromRGB(168, 119, 63),
	Gold = Color3.fromRGB(233, 194, 122),
	Rift = Color3.fromRGB(178, 108, 255),
	RiftHot = Color3.fromRGB(231, 200, 255),
	RiftDeep = Color3.fromRGB(64, 26, 128),
	Parchment = Color3.fromRGB(241, 227, 198),
	Ash = Color3.fromRGB(156, 138, 123),
}

local function face(enum, weight, style)
	return Font.new(Font.fromEnum(enum).Family, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
end

local F = {
	TitleBold = face(Enum.Font.Bodoni, Enum.FontWeight.Bold),
	Body = face(Enum.Font.Merriweather),
	Label = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	Italic = face(Enum.Font.Garamond, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
}

-- Crystal-shard skill icon that stands for each nation.
local EMBLEM = {
	Fire = UIAssets.Icons.Fireball,
	Earth = UIAssets.Icons.StoneSpike,
	Water = UIAssets.Icons.TidalWave,
	Wind = UIAssets.Icons.Gust,
	Lightning = UIAssets.Icons.ChainShock,
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

local function tween(inst, t, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function spaced(s)
	return (s:upper():gsub("(.)", "%1 "):gsub(" $", ""):gsub("   ", "     "))
end

local gui = new("ScreenGui", {
	Name = "RiftboundNation",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Full-screen veil used for travel fades.
local veil = new("Frame", {
	Name = "Veil",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.RiftDeep,
	BackgroundTransparency = 1,
	ZIndex = 100,
	Parent = gui,
}, {
	new("ImageLabel", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Vignette, ImageTransparency = 1, ZIndex = 101 }),
})

-------------------------------------------------------------------------------
-- Select screen
-------------------------------------------------------------------------------

local CARD_W, CARD_H, GAP = 214, 372, 14

local screen
local hideOtherGuis -- defined below
local function buildScreen()
	local chosen
	local cards = {}

	screen = new("Frame", {
		Name = "NationSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.45, -- the lobby preview shows through
		Active = true,
		ZIndex = 10,
		Parent = gui,
	})
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Smoke, ImageTransparency = 0.6, ImageColor3 = C.RiftDeep, ZIndex = 10, Parent = screen })
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Grain, ImageTransparency = 0.7, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(256, 256), ZIndex = 10, Parent = screen })
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Vignette, ZIndex = 10, Parent = screen })
	-- Rift light rising from the bottom edge.
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.45),
		BackgroundColor3 = C.Rift,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = screen,
	}, {
		new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }) }),
	})

	local content = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_W * 5 + GAP * 4, 620),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = screen,
	})
	local scale = new("UIScale", { Parent = content })
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (view.X - 32) / content.Size.X.Offset, (view.Y - 24) / content.Size.Y.Offset)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	text({ Size = UDim2.new(1, 0, 0, 18), Text = spaced("Riftbound"), FontFace = F.Label, TextSize = 14, TextColor3 = C.Rift, ZIndex = 11, Parent = content })
	text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 52), Text = spaced("Choose your nation"), FontFace = F.TitleBold, TextSize = 44, TextColor3 = C.Gold, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, ZIndex = 11, Parent = content })
	text({ Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 24), Text = "Your oath is sworn once. Your nation is where you rest between runs.", FontFace = F.Italic, TextSize = 20, TextColor3 = C.Ash, ZIndex = 11, Parent = content })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(320, 1), BackgroundColor3 = C.Bronze, BorderSizePixel = 0, ZIndex = 11, Parent = content })

	local row = new("Frame", { Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, CARD_H + 12), BackgroundTransparency = 1, ZIndex = 11, Parent = content })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })

	local confirm, confirmLabel

	local function refresh()
		for id, card in cards do
			local on = chosen == id
			local hover = card.Hover
			tween(card.Body, 0.18, { Position = UDim2.fromOffset(0, if on or hover then 0 else 12) })
			tween(card.Stroke, 0.18, { Color = if on then card.Def.Color else C.Bronze, Thickness = if on then 3 else 1.5, Transparency = if on or hover then 0 else 0.35 })
			tween(card.Glow, 0.25, { BackgroundTransparency = if on then 0.55 elseif hover then 0.8 else 1 })
			tween(card.Shade, 0.25, { BackgroundTransparency = if chosen and not on then 0.45 else 1 })
		end
		if chosen then
			local def = Nations.Defs[chosen]
			confirmLabel.Text = spaced("Swear to the " .. def.Name)
			tween(confirm, 0.2, { ImageTransparency = 0, ImageColor3 = Color3.new(1, 1, 1) })
			tween(confirmLabel, 0.2, { TextTransparency = 0, TextColor3 = def.Color })
		else
			confirmLabel.Text = spaced("Choose a nation")
			tween(confirm, 0.2, { ImageTransparency = 0.4, ImageColor3 = Color3.fromRGB(150, 150, 150) })
			tween(confirmLabel, 0.2, { TextTransparency = 0.3, TextColor3 = C.Ash })
		end
	end

	for i, id in Nations.Order do
		local def = Nations.Defs[id]
		local holder = new("Frame", { Size = UDim2.fromOffset(CARD_W, CARD_H + 12), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 11, Parent = row })
		local body = new("ImageButton", {
			Name = id,
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = Color3.fromRGB(16, 12, 22),
			AutoButtonColor = false,
			Image = "",
			ZIndex = 12,
			Parent = holder,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = body })
		local stroke = new("UIStroke", { Color = C.Bronze, Thickness = 1.5, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = body })
		-- Nation colour welling up from the bottom of the card.
		local glow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = def.Color, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 12, Parent = body }, {
			new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = def.Deep, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 12, Parent = body }, {
			new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UIAssets.Grain, ImageTransparency = 0.75, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(256, 256), ZIndex = 12, Parent = body })
		-- Bronze clamp at the top.
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(70, 8), BackgroundColor3 = C.Bronze, BorderSizePixel = 0, ZIndex = 14, Parent = body }, { new("UICorner", { CornerRadius = UDim.new(0, 2) }) })

		local emblem = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, Image = EMBLEM[id], ZIndex = 13, Parent = body })
		new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.8, 1.8), BackgroundTransparency = 1, Image = UIAssets.Fx.Glow, ImageColor3 = def.Color, ImageTransparency = 0.55, ZIndex = 12, Parent = emblem })

		local element = if id == "Wind" then "Wind" else def.Element
		text({ Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 16), Text = spaced(element), FontFace = F.Label, TextSize = 13, TextColor3 = def.Color, ZIndex = 13, Parent = body })
		text({ Position = UDim2.fromOffset(10, 144), Size = UDim2.new(1, -20, 0, 56), Text = def.Name, FontFace = F.TitleBold, TextSize = 26, TextWrapped = true, TextColor3 = C.Gold, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.4, ZIndex = 13, Parent = body })
		text({ Position = UDim2.fromOffset(10, 200), Size = UDim2.new(1, -20, 0, 22), Text = def.Motto, FontFace = F.Italic, TextSize = 17, TextColor3 = C.Ash, TextWrapped = true, ZIndex = 13, Parent = body })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 234), Size = UDim2.fromOffset(120, 1), BackgroundColor3 = C.Bronze, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 13, Parent = body })
		for k, perk in def.PerkText do
			local y = 248 + (k - 1) * 52
			text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(14, 18), Text = "◆", TextColor3 = def.Color, FontFace = F.Body, TextSize = 13, ZIndex = 13, Parent = body })
			text({
				Position = UDim2.fromOffset(34, y),
				Size = UDim2.new(1, -46, 0, 46),
				Text = perk,
				TextWrapped = true,
				FontFace = F.Body,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 13,
				Parent = body,
			})
		end
		local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 15, Parent = body }, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) })

		local card = { Def = def, Emblem = emblem, Body = body, Stroke = stroke, Glow = glow, Shade = shade, Hover = false }
		cards[id] = card
		body.MouseEnter:Connect(function()
			card.Hover = true
			refresh()
		end)
		body.MouseLeave:Connect(function()
			card.Hover = false
			refresh()
		end)
		body.Activated:Connect(function()
			chosen = id
			refresh()
		end)
	end

	confirm = new("ImageButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126 + CARD_H + 30),
		Size = UDim2.fromOffset(460, 66),
		BackgroundTransparency = 1,
		Image = UIAssets.Banner,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.BannerSlice,
		SliceScale = 0.5,
		ZIndex = 12,
		Parent = content,
	})
	confirmLabel = text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -12), FontFace = F.TitleBold, TextSize = 20, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3, ZIndex = 13, Parent = confirm })

	local busy = false
	confirm.Activated:Connect(function()
		if not chosen or busy then
			return
		end
		busy = true
		confirmLabel.Text = spaced("Swearing...")
		local ok, result = pcall(remotes.ChooseNation.InvokeServer, remotes.ChooseNation, chosen)
		if ok and result then
			tween(veil, 0.5, { BackgroundTransparency = 0 })
			tween(veil.Vignette, 0.5, { ImageTransparency = 0 }).Completed:Wait()
			if screen then -- the Nation attribute may have closed it already
				screen:Destroy()
				screen = nil
			end
			task.wait(1.2) -- the server respawns you in your lobby
			tween(veil, 0.8, { BackgroundTransparency = 1 })
			tween(veil.Vignette, 0.8, { ImageTransparency = 1 })
		else
			busy = false
			refresh()
		end
	end)

	refresh()
	-- Behind the cards the camera circles a lobby: the hovered or chosen
	-- nation's, otherwise each one in turn. The server streams that lobby in.
	local t0 = os.clock()
	local previewing
	local function previewTarget(t)
		for id, card in cards do
			if card.Hover then
				return id
			end
		end
		return chosen or Nations.Order[math.floor(t / 7) % #Nations.Order + 1]
	end
	local camera = workspace.CurrentCamera
	RunService:BindToRenderStep("NationPreview", Enum.RenderPriority.Last.Value + 5, function()
		if not screen then
			RunService:UnbindFromRenderStep("NationPreview")
			camera.CameraType = Enum.CameraType.Custom
			hideOtherGuis(false)
			return
		end
		hideOtherGuis(true) -- HUDs may load after the screen
		local t = os.clock() - t0
		for i, id in Nations.Order do
			cards[id].Emblem.Position = UDim2.new(0.5, 0, 0, 22 + math.sin(t * 1.6 + i) * 4)
		end
		local id = previewTarget(t)
		if id ~= previewing then
			previewing = id
			remotes.Preview:FireServer(id)
		end
		local lobby = workspace:FindFirstChild("NationLobbies") and workspace.NationLobbies:FindFirstChild(id)
		local center = lobby and lobby:GetAttribute("Center")
		if center then
			local a = t * 0.12
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * 120, 55, math.cos(a) * 120), center + Vector3.new(0, 12, 0))
		end
	end)
end

-- Other HUDs are hidden while the select screen is up.
local hidden = {}
function hideOtherGuis(on)
	if on then
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	else
		for _, g in hidden do
			g.Enabled = true
		end
		table.clear(hidden)
	end
end

local function checkNeeds()
	if player:GetAttribute("NeedsNation") and not player:GetAttribute("Nation") and not screen then
		buildScreen()
	end
end
player:GetAttributeChangedSignal("NeedsNation"):Connect(checkNeeds)
checkNeeds()
-- The nation can also be set without the screen (e.g. Studio test hooks).
player:GetAttributeChangedSignal("Nation"):Connect(function()
	if player:GetAttribute("Nation") and screen then
		screen:Destroy()
		screen = nil
	end
end)

-------------------------------------------------------------------------------
-- Travel between the lobby and the Rift
-------------------------------------------------------------------------------

remotes:WaitForChild("Travel").OnClientEvent:Connect(function(cf)
	tween(veil, 0.35, { BackgroundTransparency = 0 })
	tween(veil.Vignette, 0.35, { ImageTransparency = 0 }).Completed:Wait()
	local char = player.Character
	if char then
		char:PivotTo(cf)
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	task.wait(0.35)
	tween(veil, 0.6, { BackgroundTransparency = 1 })
	tween(veil.Vignette, 0.6, { ImageTransparency = 1 })
end)

-------------------------------------------------------------------------------
-- Lobby ambience (client-side so it costs no network)
-------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local spinners, lights, blades, flows = {}, {}, {}, {}
local function track(inst)
	if inst:IsA("BasePart") and inst:GetAttribute("Spin") then
		spinners[inst] = inst.CFrame
	elseif inst:IsA("BasePart") and inst:GetAttribute("MillHub") then
		blades[inst] = inst.CFrame
	elseif inst:IsA("PointLight") and inst:GetAttribute("Flicker") then
		lights[inst] = { Base = inst.Brightness, Seed = math.random() * 100 }
	elseif inst:IsA("Texture") and inst:GetAttribute("Flow") then
		flows[inst] = inst:GetAttribute("Flow")
	end
end
local lobbies = workspace:WaitForChild("NationLobbies", 30)
if lobbies then
	for _, d in lobbies:GetDescendants() do
		track(d)
	end
	lobbies.DescendantAdded:Connect(track)
	lobbies.DescendantRemoving:Connect(function(d)
		spinners[d], lights[d], blades[d], flows[d] = nil, nil, nil, nil
	end)
end

-- Sky tint per nation while standing in a lobby. The original lighting is
-- restored when you leave for the Rift.
local MOODS = {
	Fire = { Tint = Color3.fromRGB(255, 222, 200), Sat = 0.1, Air = Color3.fromRGB(255, 120, 70), Decay = Color3.fromRGB(120, 40, 20), Density = 0.42, Haze = 2.6 },
	Earth = { Tint = Color3.fromRGB(252, 246, 230), Sat = 0.05, Air = Color3.fromRGB(214, 202, 172), Decay = Color3.fromRGB(120, 110, 80), Density = 0.3, Haze = 1.4 },
	Water = { Tint = Color3.fromRGB(222, 240, 255), Sat = 0.1, Air = Color3.fromRGB(170, 215, 255), Decay = Color3.fromRGB(90, 140, 200), Density = 0.3, Haze = 1 },
	Wind = { Tint = Color3.fromRGB(242, 255, 250), Sat = 0, Air = Color3.fromRGB(222, 245, 240), Decay = Color3.fromRGB(150, 200, 200), Density = 0.25, Haze = 0.5 },
	Crossroads = { Tint = Color3.fromRGB(255, 244, 232), Sat = 0.05, Air = Color3.fromRGB(206, 184, 226), Decay = Color3.fromRGB(110, 80, 140), Density = 0.3, Haze = 1.2 },
	Lightning = { Tint = Color3.fromRGB(222, 222, 255), Sat = -0.05, Air = Color3.fromRGB(150, 146, 192), Decay = Color3.fromRGB(70, 60, 110), Density = 0.42, Haze = 2 },
}
local ATMOS_PROPS = { "Color", "Decay", "Density", "Haze", "Glare", "Offset" }
local saved, tint, ownAtmos
local function setMood(id)
	local mood = id and MOODS[id]
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if mood then
		if not saved then
			saved = {}
			if atmos then
				for _, k in ATMOS_PROPS do
					saved[k] = atmos[k]
				end
			else
				ownAtmos = Instance.new("Atmosphere")
				ownAtmos.Parent = Lighting
				atmos = ownAtmos
			end
			tint = Instance.new("ColorCorrectionEffect")
			tint.Name = "NationTint"
			tint.Parent = Lighting
		end
		tint.TintColor = mood.Tint
		tint.Saturation = mood.Sat
		atmos.Color = mood.Air
		atmos.Decay = mood.Decay
		atmos.Density = mood.Density
		atmos.Haze = mood.Haze
		atmos.Offset = 0.1
	elseif saved then
		if ownAtmos then
			ownAtmos:Destroy()
			ownAtmos = nil
		elseif atmos then
			for k, v in saved do
				atmos[k] = v
			end
		end
		if tint then
			tint:Destroy()
			tint = nil
		end
		saved = nil
	end
end

-- The lobby the camera is in, if any.
local function currentLobby()
	if not lobbies then
		return nil
	end
	local pos = workspace.CurrentCamera.Focus.Position
	-- Story arenas share their nation's look, so they count too.
	for _, folder in { lobbies, workspace:FindFirstChild("StoryArenas") } do
		for _, lobby in folder and folder:GetChildren() or {} do
			local center = lobby:GetAttribute("Center")
			if center and (Vector3.new(pos.X, center.Y, pos.Z) - center).Magnitude < 260 and math.abs(pos.Y - center.Y) < 200 then
				return lobby
			end
		end
	end
	return nil
end

-- A jagged bolt from a storm cloud down to the plaza, seen only by you.
local function bolt(lobby)
	local clouds = {}
	for _, p in lobby:GetChildren() do
		if p.Name == "StormCloud" then
			table.insert(clouds, p)
		end
	end
	if #clouds == 0 then
		return
	end
	local center = lobby:GetAttribute("Center")
	local from = clouds[math.random(#clouds)].Position
	local a, r = math.random() * math.pi * 2, 20 + math.random() * 40
	local to = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local color = Nations.Defs.Lightning.Color
	local prev = from
	for i = 1, 7 do
		local nextPos = if i == 7 then to else from:Lerp(to, i / 7) + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = if i % 2 == 0 then Color3.new(1, 1, 1) else color
		seg.Size = Vector3.new(0.7, 0.7, (nextPos - prev).Magnitude)
		seg.CFrame = CFrame.lookAt((prev + nextPos) / 2, nextPos)
		seg.Parent = workspace
		TweenService:Create(seg, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(seg, 0.4)
		prev = nextPos
	end
	local glow = Instance.new("Part")
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.Transparency = true, false, false, 1
	glow.CFrame = CFrame.new(to + Vector3.new(0, 2, 0))
	glow.Parent = workspace
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, 40, 8
	l.Parent = glow
	TweenService:Create(l, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	Debris:AddItem(glow, 0.5)
end

local strike, moodCheck, here, hereId = 0, 0, nil, nil
RunService.Heartbeat:Connect(function(dt)
	moodCheck -= dt
	if moodCheck <= 0 then
		moodCheck = 0.5
		here = if player:GetAttribute("InRift") and player:GetAttribute("Area") ~= "Story" then nil else currentLobby()
		hereId = here and (here:GetAttribute("Nation") or here.Name)
		setMood(hereId)
	end
	if not here then
		return
	end
	local t = os.clock()
	for p, base in spinners do
		p.CFrame = base * CFrame.new(0, math.sin(t * 1.2) * 0.8, 0) * CFrame.Angles(0, math.rad(t * p:GetAttribute("Spin")), 0)
	end
	for p, base in blades do
		local hub = p:GetAttribute("MillHub")
		p.CFrame = CFrame.new(hub) * CFrame.fromAxisAngle(base.LookVector, t * 0.8) * CFrame.new(-hub) * base
	end
	for tex, speed in flows do
		tex.OffsetStudsV = (t * speed) % tex.StudsPerTileV
	end
	strike -= dt
	local flash = strike <= 0 and math.random() < 0.012
	if flash then
		strike = 1.5
		if hereId == "Lightning" then
			bolt(here)
		end
	end
	for l, info in lights do
		if l:GetAttribute("Strike") then
			l.Brightness = if flash then 8 else math.max(0, l.Brightness - dt * 20)
		else
			l.Brightness = info.Base * (0.8 + math.noise(t * 3, info.Seed) * 0.6)
		end
	end
end)
