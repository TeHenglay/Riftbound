-- Play screen: full-screen mode select opened by the lobby's Play button.
-- Your Riftwalker stands on the left; mode cards fill the right (Story, Raid,
-- Training, Daily Challenge). Only Training is playable for now: it fires
-- EnterRift("Training") into the current arena. Story and Daily Challenge are
-- display cards; Raid is level-locked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local PlayScreen = {}

-- Set by LobbyMenu: called with true/false as the screen opens and closes.
PlayScreen.OnToggle = nil

local player = Players.LocalPlayer
local HUD, remotes
local C, F, new, stroke, text, tween, spaced, slab
local screen, viewport, levelLabel, nameLabel, nationLabel, resetLabels, storyLabels
local isOpen = false
local spin, ticker

local RAID_LEVEL = 25
local CARD_W, CARD_H, CARD_GAP = 440, 214, 22

-- Card order is the grid order: Story, Raid / Training, Daily Challenge.
local MODES = {
	{
		Id = "Story",
		Title = "Story",
		Kind = "Progressive Gamemode",
		Tint = Color3.fromRGB(60, 156, 255),
		InfoLabel = "Current Map",
		InfoValue = "The Five Nations",
		InfoNote = "0/15 Acts Cleared",
		Icons = { "TidalWave", "StoneSpike", "Fireball" },
		Footer = "Total Progress: 0%",
		Story = true,
	},
	{
		Id = "Raid",
		Title = "Raid",
		Kind = "Difficult Gamemode",
		Tint = Color3.fromRGB(232, 54, 74),
		InfoLabel = "Current Map",
		InfoValue = "Spire of Ash",
		InfoNote = "0/3 Acts Cleared",
		Icons = { "Firestorm", "MagmaBurst", "Thunderstorm" },
		Footer = "Total Progress: 0%",
		Level = RAID_LEVEL,
		Soon = true,
	},
	{
		Id = "Training",
		Title = "Training",
		Kind = "Practice Gamemode",
		Tint = Color3.fromRGB(143, 227, 107),
		InfoLabel = "Current Map",
		InfoValue = "Training Grounds",
		InfoNote = "Shrines, the Forge and endless Rift Husks",
		Icons = { "RiftBolt", "Gust", "ChainShock" },
		Footer = "Nothing at stake",
		Mode = "Training",
	},
	{
		Id = "DailyChallenge",
		Title = "Daily Challenge",
		Kind = "Reward Gamemode",
		Tint = Color3.fromRGB(250, 225, 60),
		InfoLabel = "Available Challenges",
		InfoValue = "Daily, Weekly",
		InfoNote = "Opens with the next update",
		Icons = { "PlasmaLance", "FrostGale", "SteamCloud" },
		Resets = true,
		Soon = true,
	},
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function level()
	return player:GetAttribute("Level") or 1
end

local function hex(color)
	return "#" .. color:ToHex()
end

-- "9h, 45m" / "5d, 9h" until the next UTC midnight / Monday.
local function untilReset(weekly)
	local now = os.time()
	local day = 86400
	local nextDay = (now // day + 1) * day
	local target = nextDay
	if weekly then
		-- 1970-01-01 was a Thursday; Monday 00:00 UTC is 4 days into each week.
		local weekStart = ((now - 4 * day) // (7 * day)) * 7 * day + 4 * day
		target = weekStart + 7 * day
	end
	local left = target - now
	local d, h, m = left // day, (left % day) // 3600, (left % 3600) // 60
	if d > 0 then
		return string.format("%dd, %dh", d, h)
	end
	return string.format("%dh, %dm", h, m)
end

local function refreshResets()
	for weekly, label in resetLabels do
		label.Text = (if weekly then "Weekly Reset: " else "Daily Reset: ") .. untilReset(weekly)
	end
end

local function padlock(parent, x, y, color)
	local lock = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, x, 0, y),
		Size = UDim2.fromOffset(26, 30),
		BackgroundTransparency = 1,
		ZIndex = 27,
		Parent = parent,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(16, 20),
		BackgroundTransparency = 1,
		ZIndex = 27,
		Parent = lock,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(color, 3) })
	new("Frame", {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromOffset(26, 18),
		BackgroundColor3 = color,
		ZIndex = 28,
		Parent = lock,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
end

-------------------------------------------------------------------------------
-- Mode cards
-------------------------------------------------------------------------------

local function enter(mode)
	local remote = remotes:FindFirstChild("EnterRift")
	if not remote then
		HUD.Toast("The way into the Rift isn't open yet.", C.Ash)
		return
	end
	PlayScreen.Close()
	remote:FireServer(mode)
end

-- The lobby thread's story screen; nil until its server provides it.
local function storyHook()
	local folder = Shared:FindFirstChild("NationRemotes")
	return folder and folder:FindFirstChild("OpenStoryLocal")
end

local function activate(info)
	if info.Story then
		local hook = storyHook()
		if hook then
			PlayScreen.Close()
			hook:Fire()
		else
			HUD.Toast("Story is coming in a future update.", info.Tint)
		end
	elseif info.Level and level() < info.Level then
		HUD.Toast(`Reach level {info.Level} to unlock the {info.Title}.`, C.Ash)
	elseif info.Mode then
		enter(info.Mode)
	else
		HUD.Toast(`{info.Title} is coming in a future update.`, info.Tint)
	end
end

local function modeCard(parent, info, order)
	local card = slab({
		Name = info.Id,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		LayoutOrder = order,
		SliceScale = 0.4,
		ZIndex = 22,
		Parent = parent,
	})
	new("UIScale", { Parent = card })
	-- Coloured wash from the left edge, like light through the rift.
	new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundColor3 = info.Tint,
		BorderSizePixel = 0,
		ZIndex = 22,
		Parent = card,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.55, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local frame = new("UIStroke", {
		Color = C.Bronze,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})

	text({
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -48, 0, 40),
		Text = info.Title,
		FontFace = F.TitleBold,
		TextSize = 36,
		TextColor3 = info.Tint:Lerp(Color3.new(1, 1, 1), 0.25),
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(26, 52),
		Size = UDim2.new(1, -52, 0, 18),
		Text = spaced(info.Kind),
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = card,
	})

	text({
		Position = UDim2.fromOffset(26, 86),
		Size = UDim2.fromOffset(230, 16),
		Text = spaced(info.InfoLabel),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = info.Tint,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(26, 102),
		Size = UDim2.fromOffset(230, 24),
		Text = info.InfoValue,
		FontFace = F.BodyBold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = card,
	})
	local note = text({
		Position = UDim2.fromOffset(26, 128),
		Size = UDim2.fromOffset(230, 34),
		Text = info.InfoNote,
		FontFace = F.Italic,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 24,
		Parent = card,
	})

	local icons = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 94),
		Size = UDim2.fromOffset(3 * 52 + 2 * 6 + 12, 64),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		ZIndex = 23,
		Parent = card,
	}, {
		stroke(C.Bronze, 1.5),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	for _, id in info.Icons do
		new("ImageLabel", {
			Size = UDim2.fromOffset(52, 52),
			BackgroundTransparency = 1,
			Image = UIAssets.Icons[id] or UIAssets.Medallion,
			ZIndex = 24,
			Parent = icons,
		})
	end

	-- Footer strip: progress or reset timers on the left, the call to action on the right.
	local footer = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		ZIndex = 24,
		Parent = card,
	}, { stroke(C.Bronze, 1, 0.4) })
	if info.Resets then
		for i, weekly in { false, true } do
			local chip = text({
				Position = UDim2.fromOffset(10 + (i - 1) * 156, 0),
				Size = UDim2.fromOffset(150, 34),
				FontFace = F.Label,
				TextSize = 15,
				TextColor3 = C.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 25,
				Parent = footer,
			})
			resetLabels[weekly] = chip
		end
	else
		local footerText = text({
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			Text = info.Footer,
			FontFace = F.Label,
			TextSize = 15,
			TextColor3 = C.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 25,
			Parent = footer,
		})
		if info.Story then
			storyLabels = { Note = note, Footer = footerText }
		end
	end
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Text = if info.Mode or info.Story then "Click to enter  >" elseif info.Soon then "Coming soon" else "",
		FontFace = F.Label,
		TextSize = 15,
		TextColor3 = if info.Mode or info.Story then C.Good else C.RiftHot,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 25,
		Parent = footer,
	})

	local lock
	if info.Level then
		lock = new("Frame", {
			Name = "Locked",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.28,
			ZIndex = 26,
			Parent = card,
		})
		padlock(lock, 0, 54, C.Crimson)
		text({
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 0, 26),
			Text = "Locked",
			FontFace = F.TitleBold,
			TextSize = 24,
			ZIndex = 27,
			Parent = lock,
		})
		text({
			Position = UDim2.fromOffset(0, 114),
			Size = UDim2.new(1, 0, 0, 22),
			Text = `You must be <font color="{hex(C.Crimson)}"><b>Level {info.Level}</b></font> to play this gamemode!`,
			RichText = true,
			FontFace = F.Body,
			TextSize = 15,
			ZIndex = 27,
			Parent = lock,
		})
	end

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 30,
		Parent = card,
	})
	hit.MouseEnter:Connect(function()
		tween(card.UIScale, 0.12, { Scale = 1.03 })
		frame.Color = info.Tint
	end)
	hit.MouseLeave:Connect(function()
		tween(card.UIScale, 0.12, { Scale = 1 })
		frame.Color = C.Bronze
	end)
	hit.Activated:Connect(function()
		activate(info)
	end)
	return card, lock
end

-------------------------------------------------------------------------------
-- Riftwalker preview
-------------------------------------------------------------------------------

local function clearModel()
	if spin then
		spin:Disconnect()
		spin = nil
	end
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
end

local function showCharacter()
	clearModel()
	local char = player.Character
	if not char then
		return
	end
	local was = char.Archivable
	char.Archivable = true
	local copy = char:Clone()
	char.Archivable = was
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = viewport
	-- Frame the body whatever the avatar's scale (it faces -Z, toward the camera).
	-- Accessory handles are left out: their boxes are often far bigger than the mesh.
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestorOfClass("Accessory") then
			local half = part.Size / 2
			lo = lo:Min(part.Position - half)
			hi = hi:Max(part.Position + half)
		end
	end
	if lo.X == math.huge then
		local box, boxSize = copy:GetBoundingBox()
		lo, hi = box.Position - boxSize / 2, box.Position + boxSize / 2
	end
	local size, center = hi - lo, (hi + lo) / 2
	local camera = viewport.CurrentCamera
	local aspect = viewport.AbsoluteSize.X / math.max(viewport.AbsoluteSize.Y, 1)
	local half = math.max(size.Y, size.X / math.max(aspect, 0.1)) / 2 / 0.8
	local distance = half / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.04, -distance), center)
	local start = os.clock()
	spin = RunService.RenderStepped:Connect(function()
		copy:PivotTo(CFrame.Angles(0, math.sin((os.clock() - start) * 0.7) * 0.45, 0))
	end)
end

-------------------------------------------------------------------------------
-- Build / open / close
-------------------------------------------------------------------------------

-- Story progress from the StoryCleared attribute (0-15 acts).
local STORY_ACTS = 15
local function refreshStory()
	if not storyLabels then
		return
	end
	local cleared = math.clamp(player:GetAttribute("StoryCleared") or 0, 0, STORY_ACTS)
	storyLabels.Note.Text = `{cleared}/{STORY_ACTS} Acts Cleared`
	storyLabels.Footer.Text = `Total Progress: {math.floor(cleared / STORY_ACTS * 100)}%`
end

local function refreshHeader()
	levelLabel.Text = `Level {level()}`
	nameLabel.Text = player.DisplayName
	local nation = player:GetAttribute("Nation")
	nationLabel.Text = if nation then spaced(tostring(nation) .. " Nation") else ""
end

local function build(holder)
	resetLabels = {}
	screen = new("Frame", {
		Name = "PlayScreen",
		-- Reaches up under Roblox's top bar so the backdrop covers the whole screen.
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.12,
		Active = true,
		Visible = false,
		ZIndex = 20,
		Parent = holder,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(C.RiftDeep:Lerp(C.Ink, 0.4), C.Ink),
		}),
	})
	new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.Smoke,
		ImageTransparency = 0.8,
		ImageColor3 = C.Rift,
		ZIndex = 20,
		Parent = screen,
	})

	-- Left: the player's Riftwalker with level and name.
	local left = new("Frame", {
		Name = "Riftwalker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.22, 0, 0.5, -10),
		Size = UDim2.fromOffset(460, 680),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = screen,
	})
	levelLabel = text({
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = F.TitleBold,
		TextSize = 40,
		TextColor3 = C.Gold,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		ZIndex = 22,
		Parent = left,
	})
	nameLabel = text({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 38),
		FontFace = F.TitleBold,
		TextSize = 32,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.2,
		ZIndex = 22,
		Parent = left,
	})
	nationLabel = text({
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = C.RiftHot,
		ZIndex = 22,
		Parent = left,
	})
	-- Glowing plinth under the figure.
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(320, 60),
		BackgroundColor3 = C.Rift,
		BackgroundTransparency = 0.55,
		ZIndex = 21,
		Parent = left,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	viewport = new("ViewportFrame", {
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 1, -110),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 150, 200),
		LightColor = Color3.fromRGB(255, 240, 225),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 22,
		Parent = left,
	})
	local camera = new("Camera", {
		FieldOfView = 32,
		CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -13), Vector3.new(0, 0.1, 0)),
		Parent = viewport,
	})
	viewport.CurrentCamera = camera

	-- Right: mode cards under a banner.
	local right = new("Frame", {
		Name = "Modes",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.66, 0, 0.5, -10),
		Size = UDim2.fromOffset(CARD_W * 2 + CARD_GAP, 120 + CARD_H * 2 + CARD_GAP),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = screen,
	})
	local banner = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(520, 96),
		BackgroundTransparency = 1,
		Image = UIAssets.Banner,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIAssets.BannerSlice,
		SliceScale = 0.8,
		ZIndex = 22,
		Parent = right,
	})
	text({
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 40),
		Text = spaced("Choose your match"),
		FontFace = F.Title,
		TextSize = 34,
		TextStrokeColor3 = C.RiftDeep,
		TextStrokeTransparency = 0.4,
		ZIndex = 23,
		Parent = banner,
	})
	text({
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 16),
		Text = spaced("Where will the Rift take you"),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Gold,
		ZIndex = 23,
		Parent = banner,
	})
	local grid = new("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 1, -120),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = right,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_W, CARD_H),
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local locks = {}
	for i, info in MODES do
		local _, lock = modeCard(grid, info, i)
		if lock then
			locks[info] = lock
		end
	end
	local function refreshLocks()
		for info, lock in locks do
			lock.Visible = level() < info.Level
		end
	end
	player:GetAttributeChangedSignal("Level"):Connect(refreshLocks)
	refreshLocks()

	-- Bottom bar with Back.
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundColor3 = C.Ink,
		ZIndex = 24,
		Parent = screen,
	})
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.Bronze,
		BorderSizePixel = 0,
		ZIndex = 25,
		Parent = bar,
	})
	local back = new("TextButton", {
		Name = "Back",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 36, 0.5, 0),
		Size = UDim2.fromOffset(260, 62),
		Text = spaced("Back"),
		FontFace = F.Title,
		TextSize = 26,
		TextColor3 = C.Parchment,
		BackgroundColor3 = Color3.fromRGB(28, 20, 36),
		AutoButtonColor = true,
		ZIndex = 26,
		Parent = bar,
	}, { stroke(C.Bronze, 2) })
	back.Activated:Connect(PlayScreen.Close)
	text({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(560, 30),
		Text = "Pick a mode to step into the Rift.",
		FontFace = F.Italic,
		TextSize = 20,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 26,
		Parent = bar,
	})
end

function PlayScreen.IsOpen()
	return isOpen
end

function PlayScreen.Open()
	if isOpen then
		return
	end
	isOpen = true
	refreshHeader()
	refreshResets()
	refreshStory()
	showCharacter()
	HUD.SetLobbyPanel(true)
	if PlayScreen.OnToggle then
		PlayScreen.OnToggle(true)
	end
	screen.Visible = true
	screen.BackgroundTransparency = 1
	tween(screen, 0.25, { BackgroundTransparency = 0.12 })
	ticker = task.spawn(function()
		while isOpen do
			task.wait(30)
			refreshResets()
		end
	end)
end

function PlayScreen.Close()
	if not isOpen then
		return
	end
	isOpen = false
	screen.Visible = false
	clearModel()
	if ticker then
		task.cancel(ticker)
		ticker = nil
	end
	HUD.SetLobbyPanel(false)
	if PlayScreen.OnToggle then
		PlayScreen.OnToggle(false)
	end
end

-- Called when a HUD menu (Forge, Backpack, Stats) takes over the screen.
function PlayScreen.Hide()
	if isOpen then
		isOpen = false
		screen.Visible = false
		clearModel()
		if ticker then
			task.cancel(ticker)
			ticker = nil
		end
		if PlayScreen.OnToggle then
			PlayScreen.OnToggle(false)
		end
	end
end

function PlayScreen.Init(holder, hud, remoteFolder)
	HUD = hud
	remotes = remoteFolder
	local style = HUD.Style
	C, F, new, stroke, text, tween, spaced, slab =
		style.C, style.F, style.new, style.stroke, style.text, style.tween, style.spaced, style.slab
	build(holder)
end

return PlayScreen
