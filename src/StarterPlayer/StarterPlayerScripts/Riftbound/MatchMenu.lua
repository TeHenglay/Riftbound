-- In-match settings: a "Bold Vanguard" gear tile in the bottom-right corner while
-- the player is in a match (Training in the Rift, a Story act). It opens a
-- small panel with Resume and Leave Match; leaving asks to confirm,
-- then fires LeaveMatch and the server sends the player home to their lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local MatchMenu = {}

local player = Players.LocalPlayer
local HUD, remotes
local C, F, new, stroke, text, tween, spaced, slab, popIn
local gui, holder, gear, panel, content
local shown, open = false, false

local GEAR = 60
local EDGE = 16
local GEAR_ICON = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png"
local OUTLINE = Color3.fromRGB(13, 10, 20)
local FACE = Color3.fromRGB(18, 10, 30)
local STEEL = Color3.fromRGB(150, 160, 190)

local MODES = {
	Rift = "the Training Grounds",
	Story = "a Story act",
}

-- In a match: past the lobbies (the Rift or a story arena).
local function inMatch()
	if player:GetAttribute("NeedsNation") or not player:GetAttribute("Nation") then
		return false
	end
	local area = player:GetAttribute("Area")
	if area ~= nil then
		return area ~= "Nation" and area ~= "Crossroads"
	end
	return player:GetAttribute("InRift") == true
end

-------------------------------------------------------------------------------
-- Look (matches the lobby menu tiles)
-------------------------------------------------------------------------------

local function framed(button, tint)
	new("Frame", {
		Name = "Outline",
		Position = UDim2.fromOffset(-5, -5),
		Size = UDim2.new(1, 10, 1, 14),
		BackgroundColor3 = OUTLINE,
		ZIndex = button.ZIndex - 3,
		Parent = button,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	local rim = new("UIStroke", { Color = tint, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(-1, -1),
		Size = UDim2.new(1, 2, 1, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = button.ZIndex - 2,
		Parent = button,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 9) }),
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, tint:Lerp(FACE, 0.42)),
				ColorSequenceKeypoint.new(0.55, tint:Lerp(FACE, 0.78)),
				ColorSequenceKeypoint.new(1, FACE),
			}),
		}),
		rim,
	})
	new("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = button.ZIndex - 1,
		Parent = button,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 7) }),
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.8 }),
	})
	return rim
end

local function hover(button, rim, tint)
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.06 })
		rim.Color = tint:Lerp(Color3.new(1, 1, 1), 0.4)
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
		rim.Color = tint
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.06 })
	end)
end

-- A wide panel button with outlined lettering.
local function bar(parent, y, title, tint, onClick)
	local button = new("TextButton", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.new(1, -24, 0, 56),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 26,
		Parent = parent,
	})
	local rim = framed(button, tint)
	local label = text({
		Size = UDim2.fromScale(1, 1),
		Text = title,
		FontFace = F.TitleBold,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 27,
		Parent = button,
	})
	new("UIStroke", { Color = OUTLINE, Thickness = 2.5, Parent = label })
	hover(button, rim, tint)
	button.Activated:Connect(onClick)
	return button
end

local function note(parent, y, height, body, color)
	return text({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		Text = body,
		FontFace = F.Italic,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = color or C.Ash,
		ZIndex = 26,
		Parent = parent,
	})
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

local showMenu, showConfirm

local function close()
	if not open then
		return
	end
	open = false
	panel.Visible = false
	HUD.SetLobbyPanel(false)
end

local function leave()
	close()
	local remote = remotes:FindFirstChild("LeaveMatch")
	if remote then
		remote:FireServer()
	else
		HUD.Toast("You can't leave right now.", C.Ash)
	end
end

local function setTitle(title, subtitle)
	panel.Banner.Title.Text = spaced(title)
	panel.Banner.Subtitle.Text = spaced(subtitle)
	content:ClearAllChildren()
end

showMenu = function()
	setTitle("Settings", "The fight carries on")
	local mode = MODES[player:GetAttribute("Area")] or "the Rift"
	note(content, 0, 24, "You are in " .. mode .. ".", C.Parchment)
	bar(content, 40, "Resume", C.Rift, close)
	bar(content, 116, "Leave Match", C.Crimson, showConfirm)
end

showConfirm = function()
	setTitle("Leave Match", "Return to your lobby")
	local body = "Head back to your nation's lobby now?"
	if player:GetAttribute("Area") == "Story" then
		body ..= " This act's run is lost and you'll start it over next time."
	end
	note(content, 0, 52, body)
	local row = new("Frame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		ZIndex = 26,
		Parent = content,
	})
	local stay = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, ZIndex = 26, Parent = row })
	local go = new("Frame", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, ZIndex = 26, Parent = row })
	bar(stay, 0, "Stay", C.Rift, showMenu)
	bar(go, 0, "Leave", C.Crimson, leave)
end

local function openMenu()
	if open or not shown then
		return
	end
	-- Close the Forge / Backpack / Attributes first; they share the dim shade.
	HUD.SetLobbyPanel(true)
	open = true
	showMenu()
	panel.Visible = true
	popIn(panel)
end

local function toggle()
	if open then
		close()
	else
		openMenu()
	end
end

local function buildPanel()
	panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 330),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = holder,
	})
	new("UIScale", { Parent = panel })
	slab({
		Name = "Body",
		Position = UDim2.fromOffset(10, 84),
		Size = UDim2.new(1, -20, 1, -84),
		ZIndex = 20,
		Parent = panel,
	})
	local banner = new("ImageLabel", {
		Name = "Banner",
		Position = UDim2.fromOffset(-24, 0),
		Size = UDim2.new(1, 48, 0, 96),
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
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = F.Title,
		TextSize = 32,
		TextStrokeColor3 = C.RiftDeep,
		TextStrokeTransparency = 0.4,
		ZIndex = 23,
		Parent = banner,
	})
	text({
		Name = "Subtitle",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Gold,
		ZIndex = 23,
		Parent = banner,
	})
	local x = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 104),
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
	x.Activated:Connect(close)
	content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(40, 118),
		Size = UDim2.new(1, -80, 1, -140),
		BackgroundTransparency = 1,
		ZIndex = 24,
		Parent = panel,
	})
end

-- Bottom-right corner of the screen.
local GEAR_IN, GEAR_OUT = UDim2.new(1, -EDGE, 1, -EDGE - 12), UDim2.new(1, GEAR + 40, 1, -EDGE - 12)

local function buildGear()
	gear = new("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 1),
		Position = GEAR_OUT,
		Size = UDim2.fromOffset(GEAR, GEAR),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	})
	local rim = framed(gear, STEEL)
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Image = GEAR_ICON,
		ZIndex = 6,
		Parent = gear,
	})
	hover(gear, rim, STEEL)
	gear.Activated:Connect(toggle)
end

local function setShown(on)
	if on == shown then
		return
	end
	shown = on
	if on then
		gear.Visible = true
		tween(gear, 0.35, { Position = GEAR_IN }, Enum.EasingStyle.Quint)
	else
		close()
		local tw = tween(gear, 0.25, { Position = GEAR_OUT }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not shown then
				gear.Visible = false
			end
		end)
	end
end

local function fitToScreen()
	local camera = workspace.CurrentCamera
	if camera then
		holder.UIScale.Scale = math.clamp(camera.ViewportSize.Y / 1000, 0.6, 1)
	end
end

function MatchMenu.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	local style = HUD.Style
	C, F, new, stroke, text, tween, spaced, slab, popIn =
		style.C, style.F, style.new, style.stroke, style.text, style.tween, style.spaced, style.slab, style.popIn

	gui = new("ScreenGui", {
		Name = "RiftboundMatchMenu",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	new("UIScale", { Parent = holder })
	holder.UIScale:GetPropertyChangedSignal("Scale"):Connect(function()
		local s = holder.UIScale.Scale
		holder.Size = UDim2.fromScale(1 / s, 1 / s)
	end)
	fitToScreen()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fitToScreen)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end

	buildGear()
	buildPanel()

	-- A HUD menu (Forge, Backpack) opening hides this panel, after the lobby menu's own handler.
	local previous = HUD.OnHudMenuOpened
	HUD.OnHudMenuOpened = function()
		if previous then
			previous()
		end
		if open then
			open = false
			panel.Visible = false
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and open then
			close()
		end
	end)

	local function refresh()
		setShown(inMatch())
	end
	for _, name in { "Nation", "InRift", "NeedsNation", "Area" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return MatchMenu
