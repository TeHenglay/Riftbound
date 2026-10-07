-- Enemy registry, damage, status effects and the test dummy rig.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Elements = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Elements"))
local Drops = require(script.Parent.Drops)

local TAG = "RiftEnemy"
local SHOCK_AMP = 1.2
local SOAK_SLOW = 0.2
local BURN_TICK = 0.5

local Enemies = {}
Enemies.Tag = TAG

local STATUS_COLORS = {
	Burn = Color3.fromRGB(255, 110, 40),
	Soak = Color3.fromRGB(60, 150, 255),
	Slow = Color3.fromRGB(140, 210, 255),
	Stun = Color3.fromRGB(220, 220, 220),
	Shock = Color3.fromRGB(250, 225, 60),
}
local STATUS_ORDER = { "Burn", "Soak", "Slow", "Stun", "Shock" }

local folder = workspace:FindFirstChild("RiftEnemies") or Instance.new("Folder")
folder.Name = "RiftEnemies"
folder.Parent = workspace
Enemies.Folder = folder

-- [model] = { Statuses = { [name] = { Expires, Dps?, Amount?, NextTick? } }, BaseSpeed, Gui }
local states = {}

function Enemies.IsAlive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and model.PrimaryPart ~= nil and states[model] ~= nil
end

function Enemies.GetAll()
	local list = {}
	for _, model in CollectionService:GetTagged(TAG) do
		if Enemies.IsAlive(model) then
			table.insert(list, model)
		end
	end
	return list
end

-- Enemies inside a vertical cylinder around pos.
function Enemies.InRadius(pos, radius)
	local list = {}
	for _, model in Enemies.GetAll() do
		local p = model.PrimaryPart.Position
		local flat = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
		if flat <= radius + 1.5 and math.abs(p.Y - pos.Y) < 14 then
			table.insert(list, model)
		end
	end
	return list
end

function Enemies.HasStatus(model, name)
	local st = states[model]
	return st ~= nil and st.Statuses[name] ~= nil
end

local function refresh(model)
	local st = states[model]
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not st or not hum then
		return
	end
	local s = st.Statuses
	local slow = 0
	if s.Slow then
		slow = math.max(slow, s.Slow.Amount or 0)
	end
	if s.Soak then
		slow = math.max(slow, SOAK_SLOW)
	end
	hum.WalkSpeed = if s.Stun then 0 else st.BaseSpeed * (1 - slow)

	local parts = {}
	for _, name in STATUS_ORDER do
		if s[name] then
			local c = STATUS_COLORS[name]
			table.insert(parts, string.format('<font color="rgb(%d,%d,%d)">%s</font>', c.R * 255, c.G * 255, c.B * 255, name:upper()))
		end
	end
	if st.Gui then
		st.Gui.Status.Text = table.concat(parts, "  ")
	end
end

function Enemies.ClearStatus(model, name)
	local st = states[model]
	if st and st.Statuses[name] then
		st.Statuses[name] = nil
		refresh(model)
	end
end

function Enemies.ApplyStatus(model, name, params)
	local st = states[model]
	if not st or not Enemies.IsAlive(model) then
		return
	end
	local expires = os.clock() + (params.Duration or 1)
	local cur = st.Statuses[name]
	if cur then
		cur.Expires = math.max(cur.Expires, expires)
		cur.Dps = math.max(cur.Dps or 0, params.Dps or 0)
		cur.Amount = math.max(cur.Amount or 0, params.Amount or 0)
	else
		st.Statuses[name] = {
			Expires = expires,
			Dps = params.Dps,
			Amount = params.Amount,
			NextTick = os.clock() + BURN_TICK,
		}
	end
	refresh(model)
end

local function showNumber(model, amount, color, label)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = if label then 24 else 20
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.3
	text.Text = if label then `{label}! {amount}` else tostring(amount)
	text.Parent = gui
	gui.Parent = head
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(text, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 0.85)
end

-- Deals damage, applying elemental reactions and Shock. `elements` is the
-- attacking skill's element list; pass {} for damage that shouldn't react.
function Enemies.Damage(model, amount, elements, color)
	if not Enemies.IsAlive(model) then
		return
	end
	local st = states[model]
	local mult = 1
	local reaction
	for _, r in Elements.Reactions do
		if st.Statuses[r.Needs] and table.find(elements, r.Hit) then
			mult *= r.Mult
			reaction = r.Name
			if r.Consume then
				Enemies.ClearStatus(model, r.Needs)
			end
		end
	end
	if st.Statuses.Shock then
		mult *= SHOCK_AMP
	end
	local final = math.floor(amount * mult + 0.5)
	if final <= 0 then
		return
	end
	st.LastHit = os.clock()
	model:FindFirstChildOfClass("Humanoid"):TakeDamage(final)
	showNumber(model, final, color or Elements.ColorOf(elements), reaction)
end

-- Shoves the enemy with a horizontal velocity for a short time.
function Enemies.Push(model, velocity, duration)
	local root = model.PrimaryPart
	if not root or not Enemies.IsAlive(model) then
		return
	end
	local att = root:FindFirstChild("PushAttachment")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "PushAttachment"
		att.Parent = root
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	lv.Parent = root
	Debris:AddItem(lv, duration or 0.25)
end

local function makeHealthGui(model, hum)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RiftHealth"
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140

	local name = Instance.new("TextLabel")
	name.Name = "EnemyName"
	name.Size = UDim2.new(1, 0, 0, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 12
	name.TextColor3 = Color3.fromRGB(235, 225, 255)
	name.TextStrokeTransparency = 0.4
	name.Text = model:GetAttribute("DisplayName") or model.Name
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(10, 15)
	back.Size = UDim2.new(1, -20, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(25, 15, 35)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(0, 25)
	status.Size = UDim2.new(1, 0, 0, 14)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextSize = 11
	status.RichText = true
	status.TextStrokeTransparency = 0.4
	status.Text = ""
	status.Parent = gui

	gui.Parent = model:FindFirstChild("Head") or model.PrimaryPart
	hum.HealthChanged:Connect(function(hp)
		fill.Size = UDim2.fromScale(math.clamp(hp / hum.MaxHealth, 0, 1), 1)
	end)
	return gui
end

function Enemies.Register(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	states[model] = { Statuses = {}, BaseSpeed = hum.WalkSpeed, LastHit = 0 }
	states[model].Gui = makeHealthGui(model, hum)
	CollectionService:AddTag(model, TAG)
	hum.Died:Connect(function()
		states[model] = nil
	end)
	model.Destroying:Connect(function()
		states[model] = nil
	end)
end

-- Status ticking: expiry, burn damage, training-dummy regen.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, st in states do
		local changed = false
		for name, s in st.Statuses do
			if now >= s.Expires then
				st.Statuses[name] = nil
				changed = true
			elseif name == "Burn" and now >= s.NextTick then
				s.NextTick += BURN_TICK
				Enemies.Damage(model, (s.Dps or 0) * BURN_TICK, {}, STATUS_COLORS.Burn)
			end
		end
		if changed and states[model] then
			refresh(model)
		end
		if model:GetAttribute("Regen") and now - st.LastHit > 4 then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
				hum.Health = hum.MaxHealth
			end
		end
	end
end)

-------------------------------------------------------------------------------
-- Test dummies. opts: Name, Health, Speed, Chase (bool), Damage, Color, Regen,
-- Xp (number) and Gold (number or {min, max}) dropped on death
-------------------------------------------------------------------------------

local function nearestPlayerRoot(pos, maxDist)
	local best, bestDist = nil, maxDist
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best, bestDist
end

local function runChaseAI(model, hum, opts)
	local lastAttack = 0
	task.spawn(function()
		while Enemies.IsAlive(model) do
			local root = model.PrimaryPart
			local target, dist = nearestPlayerRoot(root.Position, 80)
			if target and not Enemies.HasStatus(model, "Stun") then
				hum:MoveTo(target.Position)
				if dist < 5.5 and os.clock() - lastAttack > 1.2 then
					lastAttack = os.clock()
					local victim = target.Parent:FindFirstChildOfClass("Humanoid")
					if victim then
						victim:TakeDamage(opts.Damage or 5)
					end
				end
			elseif not target then
				hum:MoveTo(root.Position)
			end
			task.wait(0.25)
		end
	end)
end

function Enemies.SpawnDummy(cframe, opts)
	opts = opts or {}
	local color = opts.Color or Color3.fromRGB(60, 40, 90)

	local model = Instance.new("Model")
	model.Name = opts.Name or "Rift Husk"
	model:SetAttribute("DisplayName", opts.Name or "Rift Husk")
	if opts.Regen then
		model:SetAttribute("Regen", true)
	end

	local function part(name, size, offset, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			p[k] = v
		end
		p.Parent = model
		return p
	end

	-- Root sits 1 stud above the floor (HipHeight 1); the body reaches down to it.
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 2, 0), {
		Transparency = 1, CanCollide = true, Massless = false,
	})
	local body = part("Body", Vector3.new(3, 3.4, 2), CFrame.new(0, 1.7, 0))
	local head = part("Head", Vector3.new(2, 2, 2), CFrame.new(0, 4.4, 0))
	local eye = part("Eye", Vector3.new(1.4, 0.35, 0.2), CFrame.new(0, 4.6, -1.0), {
		Color = Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon,
	})
	for _, p in { body, head, eye } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	model.PrimaryPart = root

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 1
	hum.MaxHealth = opts.Health or 120
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = opts.Speed or 10
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	model.Parent = folder
	root:SetNetworkOwner(nil)
	Enemies.Register(model)

	hum.Died:Connect(function()
		local gold = opts.Gold
		if type(gold) == "table" then
			gold = math.random(gold[1], gold[2])
		end
		if (opts.Xp or 0) > 0 or (gold or 0) > 0 then
			Drops.Spawn(root.Position, opts.Xp, gold, root.Position.Y - 2)
		end
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= root then
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1, Size = p.Size * 0.3 }):Play()
			end
		end
		Debris:AddItem(model, 0.7)
	end)

	if opts.Chase then
		runChaseAI(model, hum, opts)
	end
	return model
end

return Enemies
