-- Party panel and invite popups. The Play screen's Party button opens the
-- panel: your party (leader first, up to the server's Max players) and every
-- other player in the server with an Invite button. The leader can invite and
-- remove players; anyone can leave. Invites from others pop up at the top of
-- the screen with Accept / Decline and a countdown, wherever you are.
-- The server side is PartyService (NationRemotes.PartyAction / PartyChanged /
-- PartyInvite).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")

local PartyPanel = {}

-- Called with the party snapshot (or nil) whenever it changes.
PartyPanel.OnChanged = nil

local player = Players.LocalPlayer
local HUD, partyRemotes
local C, F, new, stroke, text, tween, spaced, slab, popIn
local gui, holder, panel, title, membersList, playersList, leaveBtn, status, invitesHolder
local party -- snapshot from the server, nil when solo
local invited = {} -- [userId] = os.clock() the invite expires (sent by you)
local isOpen = false
local busy = false

local W, H = 760, 520
local ROW = 54
local MAX_DEFAULT = 4
local LEADER_TAG = Color3.fromRGB(255, 200, 80)

local function headshot(userId)
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=60&h=60`
end

local function maxPlayers()
	return party and party.Max or MAX_DEFAULT
end

local function inParty(userId)
	for _, m in party and party.Members or {} do
		if m.UserId == userId then
			return true
		end
	end
	return false
end

local function amLeader()
	return party == nil or party.Leader == player.UserId
end

local function call(action, arg)
	if busy or not partyRemotes or not partyRemotes:FindFirstChild("PartyAction") then
		return false, if busy then nil else "Parties aren't ready yet"
	end
	busy = true
	local ok, done, msg = pcall(partyRemotes.PartyAction.InvokeServer, partyRemotes.PartyAction, action, arg)
	busy = false
	if not ok then
		return false, "The Rift is closed"
	end
	return done, msg
end

local function button(parent, props, color, onClick)
	local b = new("TextButton", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		Text = spaced(props.Text),
		FontFace = F.Title,
		TextSize = props.TextSize or 14,
		TextColor3 = C.Parchment,
		BackgroundColor3 = color,
		AutoButtonColor = props.Enabled ~= false,
		TextTransparency = if props.Enabled == false then 0.5 else 0,
		BackgroundTransparency = if props.Enabled == false then 0.5 else 0,
		ZIndex = props.ZIndex or 34,
		Parent = parent,
	}, { stroke(C.Bronze, 2) })
	if props.Enabled ~= false then
		b.Activated:Connect(onClick)
	end
	return b
end

local function row(parent, order, userId, name, sub, tag)
	local r = new("Frame", {
		Size = UDim2.new(1, -8, 0, ROW),
		BackgroundColor3 = C.Card,
		LayoutOrder = order,
		ZIndex = 32,
		Parent = parent,
	}, { stroke(C.Bronze, 1.5) })
	new("ImageLabel", {
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.Ink,
		Image = headshot(userId),
		ZIndex = 33,
		Parent = r,
	})
	text({
		Position = UDim2.fromOffset(58, 7),
		Size = UDim2.new(1, -170, 0, 22),
		Text = name .. (if tag then `  <font color="#{LEADER_TAG:ToHex()}">{tag}</font>` else ""),
		RichText = true,
		FontFace = F.BodyBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 33,
		Parent = r,
	})
	text({
		Position = UDim2.fromOffset(58, 29),
		Size = UDim2.new(1, -170, 0, 18),
		Text = sub,
		FontFace = F.Body,
		TextSize = 13,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
		Parent = r,
	})
	return r
end

local function describe(nation, level)
	return `Level {level or 1}` .. (if nation then ` · {nation} Nation` else "")
end

local function clearList(list)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setStatus(message, color)
	status.Text = message or ""
	status.TextColor3 = color or C.Ash
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

local render

local function renderMembers()
	clearList(membersList)
	local members = party and party.Members
		or { { UserId = player.UserId, DisplayName = player.DisplayName, Nation = player:GetAttribute("Nation"), Level = player:GetAttribute("Level"), Leader = true } }
	local leader = amLeader()
	for i, m in members do
		local you = m.UserId == player.UserId
		local r = row(membersList, i, m.UserId, m.DisplayName .. (if you then " (you)" else ""), describe(m.Nation, m.Level), if m.Leader then "LEADER" else nil)
		if leader and not you then
			button(r, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(96, 34),
				Text = "Remove",
				TextSize = 12,
			}, C.Crimson, function()
				local ok, msg = call("Kick", m.UserId)
				setStatus(msg, if ok then C.Good else C.Bad)
			end)
		end
	end
	-- Empty seats.
	for i = #members + 1, maxPlayers() do
		new("Frame", {
			Size = UDim2.new(1, -8, 0, ROW),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.4,
			LayoutOrder = i,
			ZIndex = 32,
			Parent = membersList,
		}, {
			stroke(C.Bronze, 1, 0.6),
			text({
				Size = UDim2.fromScale(1, 1),
				Text = "Open seat",
				FontFace = F.Italic,
				TextSize = 15,
				TextColor3 = C.Ash,
				ZIndex = 33,
			}),
		})
	end
	title.Text = spaced(`Party  {#members}/{maxPlayers()}`)
	leaveBtn.Visible = party ~= nil
end

local function renderPlayers()
	clearList(playersList)
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	if #others == 0 then
		text({
			Size = UDim2.new(1, -8, 0, 60),
			Text = "No one else is in this server yet.",
			FontFace = F.Italic,
			TextSize = 15,
			TextColor3 = C.Ash,
			ZIndex = 33,
			Parent = playersList,
		})
		return
	end
	local leader = amLeader()
	local full = party ~= nil and #party.Members >= maxPlayers()
	for i, p in others do
		local nation = p:GetAttribute("Nation")
		local where = if p:GetAttribute("InRift") then " · in a match" else ""
		local r = row(playersList, i, p.UserId, p.DisplayName, describe(nation, p:GetAttribute("Level")) .. where)
		local label, enabled = "Invite", true
		if inParty(p.UserId) then
			label, enabled = "In Party", false
		elseif p:GetAttribute("PartyId") then
			label, enabled = "Busy", false
		elseif (invited[p.UserId] or 0) > os.clock() then
			label, enabled = "Invited", false
		elseif not nation or not leader or full then
			enabled = false
		end
		button(r, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(96, 34),
			Text = label,
			TextSize = 12,
			Enabled = enabled,
		}, C.Rift, function()
			local ok, msg = call("Invite", p.UserId)
			if ok then
				invited[p.UserId] = os.clock() + 30
				task.delay(30.5, function()
					if isOpen then
						render()
					end
				end)
			end
			setStatus(msg, if ok then C.Good else C.Bad)
			render()
		end)
	end
end

render = function()
	if not panel then
		return
	end
	renderMembers()
	renderPlayers()
	if not amLeader() then
		setStatus("Your party leader picks the match. Stay in a lobby to be brought along.")
	end
end

local function list(parent, x, heading)
	text({
		Position = UDim2.fromOffset(x, 78),
		Size = UDim2.fromOffset(340, 20),
		Text = spaced(heading),
		FontFace = F.Label,
		TextSize = 12,
		TextColor3 = C.RiftHot,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 32,
		Parent = parent,
	})
	return new("ScrollingFrame", {
		Position = UDim2.fromOffset(x, 102),
		Size = UDim2.fromOffset(344, H - 102 - 86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Rift,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = parent,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
end

local function buildPanel()
	local shade = new("TextButton", {
		Name = "PartyShade",
		-- Covers the whole screen, top bar included, so the panel centres on it.
		Position = UDim2.fromOffset(0, -game:GetService("GuiService"):GetGuiInset().Y),
		Size = UDim2.new(1, 0, 1, game:GetService("GuiService"):GetGuiInset().Y),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 30,
		Parent = holder,
	})
	shade.Activated:Connect(function()
		PartyPanel.Close()
	end)
	panel = slab({
		Name = "Party",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		Active = true,
		ZIndex = 31,
		Parent = shade,
	})
	new("UIScale", { Parent = panel })
	title = text({
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = F.Title,
		TextSize = 30,
		ZIndex = 32,
		Parent = panel,
	})
	text({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 16),
		Text = spaced("Play together"),
		FontFace = F.Label,
		TextSize = 11,
		TextColor3 = C.Gold,
		ZIndex = 32,
		Parent = panel,
	})
	membersList = list(panel, 26, "Your party")
	playersList = list(panel, W - 26 - 344, "Players in this server")
	status = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 26, 1, -60),
		Size = UDim2.new(1, -52, 0, 20),
		FontFace = F.Italic,
		TextSize = 15,
		TextColor3 = C.Ash,
		TextWrapped = true,
		ZIndex = 32,
		Parent = panel,
	})
	leaveBtn = button(panel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 26, 1, -14),
		Size = UDim2.fromOffset(200, 40),
		Text = "Leave Party",
	}, C.Crimson, function()
		local ok, msg = call("Leave")
		setStatus(msg, if ok then C.Good else C.Bad)
	end)
	button(panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -26, 1, -14),
		Size = UDim2.fromOffset(200, 40),
		Text = "Done",
	}, Color3.fromRGB(28, 20, 36), function()
		PartyPanel.Close()
	end)
end

function PartyPanel.IsOpen()
	return isOpen
end

function PartyPanel.Open()
	if isOpen or not panel then
		return
	end
	isOpen = true
	setStatus("")
	render()
	local view = workspace.CurrentCamera.ViewportSize
	panel.UIScale.Scale = math.min(1, (view.X - 24) / W, (view.Y - 24) / H)
	panel.Parent.Visible = true
	local fit = panel.UIScale.Scale
	panel.UIScale.Scale = fit * 0.92
	tween(panel.UIScale, 0.28, { Scale = fit }, Enum.EasingStyle.Back)
end

function PartyPanel.Close()
	if not isOpen then
		return
	end
	isOpen = false
	panel.Parent.Visible = false
end

-- The current snapshot (nil when solo).
function PartyPanel.Party()
	return party
end

-------------------------------------------------------------------------------
-- Invite popups
-------------------------------------------------------------------------------

local function showInvite(info)
	if typeof(info) ~= "table" or typeof(info.From) ~= "number" then
		return
	end
	local old = invitesHolder:FindFirstChild(tostring(info.From))
	if old then
		old:Destroy()
	end
	local seconds = math.max(tonumber(info.Seconds) or 30, 1)
	local card = slab({
		Name = tostring(info.From),
		Size = UDim2.fromOffset(420, 112),
		ZIndex = 41,
		Parent = invitesHolder,
	})
	new("UIScale", { Parent = card })
	new("ImageLabel", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Ink,
		Image = headshot(info.From),
		ZIndex = 42,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(78, 12),
		Size = UDim2.new(1, -90, 0, 22),
		Text = `<b>{tostring(info.Name)}</b> invited you to their party`,
		RichText = true,
		FontFace = F.Body,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 42,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(78, 36),
		Size = UDim2.new(1, -90, 0, 18),
		Text = describe(info.Nation, info.Level),
		FontFace = F.Body,
		TextSize = 13,
		TextColor3 = C.Ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
		Parent = card,
	})
	local timer = new("Frame", {
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = C.Rift,
		BorderSizePixel = 0,
		ZIndex = 43,
		Parent = card,
	})
	tween(timer, seconds, { Size = UDim2.new(0, 0, 0, 4) }, Enum.EasingStyle.Linear)
	local function dismiss()
		if card.Parent then
			card:Destroy()
		end
	end
	button(card, {
		Position = UDim2.fromOffset(78, 62),
		Size = UDim2.fromOffset(150, 36),
		Text = "Accept",
		ZIndex = 43,
	}, C.Good:Lerp(C.Ink, 0.45), function()
		dismiss()
		local ok, msg = call("Accept", info.From)
		HUD.Toast(msg or (if ok then "Joined the party" else "Couldn't join"), if ok then C.Good else C.Bad)
	end)
	button(card, {
		Position = UDim2.fromOffset(240, 62),
		Size = UDim2.fromOffset(150, 36),
		Text = "Decline",
		ZIndex = 43,
	}, C.Crimson, function()
		dismiss()
		call("Decline", info.From)
	end)
	popIn(card)
	task.delay(seconds, dismiss)
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------

local function setParty(snapshot)
	party = if typeof(snapshot) == "table" then snapshot else nil
	if isOpen then
		render()
	end
	if PartyPanel.OnChanged then
		PartyPanel.OnChanged(party)
	end
end

function PartyPanel.Init(hud)
	HUD = hud
	local style = HUD.Style
	C, F, new, stroke, text, tween, spaced, slab, popIn =
		style.C, style.F, style.new, style.stroke, style.text, style.tween, style.spaced, style.slab, style.popIn

	gui = new("ScreenGui", {
		Name = "RiftboundParty",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	invitesHolder = new("Frame", {
		Name = "Invites",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 360),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = holder,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	buildPanel()

	UserInputService.InputBegan:Connect(function(input)
		if isOpen and input.KeyCode == Enum.KeyCode.Escape then
			PartyPanel.Close()
		end
	end)

	-- Re-draw the player list as people come, go, join parties or start matches.
	local function watch(p)
		for _, name in { "PartyId", "Level", "Nation", "InRift" } do
			p:GetAttributeChangedSignal(name):Connect(function()
				if isOpen then
					render()
				end
			end)
		end
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(function(p)
		watch(p)
		if isOpen then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		invited[p.UserId] = nil
		if isOpen then
			task.defer(render)
		end
	end)

	task.spawn(function()
		partyRemotes = Shared:WaitForChild("NationRemotes")
		partyRemotes:WaitForChild("PartyChanged").OnClientEvent:Connect(setParty)
		partyRemotes:WaitForChild("PartyInvite").OnClientEvent:Connect(showInvite)
		local action = partyRemotes:WaitForChild("PartyAction")
		local ok, snapshot = pcall(action.InvokeServer, action, "Get")
		if ok then
			setParty(snapshot)
		end
	end)
end

return PartyPanel
