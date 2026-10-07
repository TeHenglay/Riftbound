-- Enemy registry, damage, status effects and the test dummy rig.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Elements = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Elements"))
local Drops = require(script.Parent.Drops)

local TAG = "RiftEnemy"
local SHOCK_AMP = 1.2
local SOAK_SLOW = 0.2
local BURN_TICK = 0.5

local Enemies = {}
Enemies.Tag = TAG
-- Set by BlockService: (player, attacker) -> true if the player's shield stopped the hit.
Enemies.BlockCheck = nil

local STATUS_COLORS = {
	Burn = Color3.fromRGB(255, 110, 40),
	Soak = Color3.fromRGB(60, 150, 255),
	Slow = Color3.fromRGB(140, 210, 255),
	Stun = Color3.fromRGB(220, 220, 220),
	Shock = Color3.fromRGB(250, 225, 60),
	Freeze = Color3.fromRGB(170, 230, 255),
}
local STATUS_ORDER = { "Burn", "Soak", "Slow", "Stun", "Shock", "Freeze" }

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

-- Stunned or frozen: the enemy can neither move nor attack.
local function isHeld(model)
	return Enemies.HasStatus(model, "Stun") or Enemies.HasStatus(model, "Freeze")
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
	local held = s.Stun ~= nil or s.Freeze ~= nil
	hum.WalkSpeed = if held then 0 else st.BaseSpeed * (1 - slow)
	model:SetAttribute("Stunned", held)
	for _, name in STATUS_ORDER do
		model:SetAttribute("Status_" .. name, if s[name] then true else nil)
	end

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
	model:SetAttribute("HitAt", workspace:GetServerTimeNow())
	model:FindFirstChildOfClass("Humanoid"):TakeDamage(final)
	showNumber(model, final, color or Elements.ColorOf(elements), reaction)
	if reaction then
		model:SetAttribute("Reaction", reaction)
		model:SetAttribute("ReactionAt", workspace:GetServerTimeNow())
	end
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
	-- Replace any push still in effect, so repeated pulls don't stack.
	local existing = root:FindFirstChild("Push")
	if existing then
		existing:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Push"
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
-- Xp (number), Gold (number or {min, max}) and Loot ({ { Id, Chance, Min, Max } })
-- dropped on death
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

local ATTACK_RANGE = 6
local ATTACK_REACH = 8 -- still hits if you are this close when the strike lands
local ATTACK_WINDUP = 0.4
local ATTACK_COOLDOWN = 1.4

local function runChaseAI(model, hum, opts)
	local lastAttack = 0
	task.spawn(function()
		while Enemies.IsAlive(model) do
			local root = model.PrimaryPart
			local target, dist = nearestPlayerRoot(root.Position, 80)
			if target and not isHeld(model) then
				if dist < ATTACK_RANGE and os.clock() - lastAttack > ATTACK_COOLDOWN then
					-- Telegraph: stop, face the player and rear back (the client animates
					-- the windup from AttackAt), then strike if they did not dodge.
					lastAttack = os.clock()
					hum:MoveTo(root.Position)
					local flat = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
					root.CFrame = CFrame.lookAt(root.Position, flat)
					model:SetAttribute("AttackAt", workspace:GetServerTimeNow() + ATTACK_WINDUP)
					task.wait(ATTACK_WINDUP)
					if Enemies.IsAlive(model) and not isHeld(model) and target.Parent then
						if (target.Position - root.Position).Magnitude < ATTACK_REACH then
							local victim = target.Parent:FindFirstChildOfClass("Humanoid")
							local blocker = Players:GetPlayerFromCharacter(target.Parent)
							local blocked = blocker ~= nil and Enemies.BlockCheck ~= nil and Enemies.BlockCheck(blocker, model)
							if victim and not blocked then
								victim:TakeDamage(opts.Damage or 5)
							end
						end
					end
					task.wait(0.25)
				else
					hum:MoveTo(target.Position)
				end
			elseif not target then
				hum:MoveTo(root.Position)
			end
			task.wait(0.2)
		end
	end)
end

-- Crystal shards burst outward when a husk dies.
local function shardBurst(position, color)
	for i = 1, 10 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.5, 0.5 + math.random() * 1.2, 0.5)
		shard.Material = Enum.Material.Neon
		shard.Color = color
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Anchored = true
		shard.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		shard.Parent = workspace
		local angle = i / 10 * math.pi * 2
		local reach = 4 + math.random() * 3
		local goal = position + Vector3.new(math.cos(angle) * reach, 2 + math.random() * 3, math.sin(angle) * reach)
		TweenService:Create(shard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(goal) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Transparency = 1,
			Size = shard.Size * 0.3,
		}):Play()
		Debris:AddItem(shard, 0.65)
	end
end

-- Attaches the segmented Rift Husk (ServerStorage.RiftboundAssets.RiftHuskRig:
-- Body, ArmL, ArmR, LegL, LegR) with Motor6Ds at the waist, shoulders and hips.
-- The client's EnemyAnimator drives the joints. Template space: origin is the
-- original mesh centre and the creature faces +Z; the rig faces -Z.
local function attachHuskRig(model, root, template)
	local src = {}
	for _, name in { "Body", "ArmL", "ArmR", "LegL", "LegR" } do
		src[name] = template:FindFirstChild(name)
		if not src[name] then
			return nil
		end
	end
	local floorY = math.huge
	for _, p in src do
		floorY = math.min(floorY, p.Position.Y - p.Size.Y / 2)
	end
	local turn = CFrame.Angles(0, math.pi, 0)
	-- Where the root sits in template space: 2 studs above the floor, facing -Z.
	local rootT = CFrame.new(0, floorY + 2, 0) * turn
	local toWorld = root.CFrame * rootT:Inverse()

	local parts = {}
	for name, p in src do
		local part = p:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = toWorld * p.CFrame
		part.Parent = model
		parts[name] = part
	end

	-- Joint pivots (template space), oriented like the rig so the client's
	-- Motor6D.Transform rotations read in rig space.
	local function top(p, inset)
		return p.Position + Vector3.new(0, p.Size.Y / 2 - inset, 0)
	end
	local body = src.Body
	local pivots = {
		Body = { Parent = nil, At = Vector3.new(body.Position.X, body.Position.Y - body.Size.Y / 2 + 0.5, body.Position.Z) },
		ArmL = { Parent = "Body", At = top(src.ArmL, 0.45) },
		ArmR = { Parent = "Body", At = top(src.ArmR, 0.45) },
		LegL = { Parent = nil, At = top(src.LegL, 0.2) },
		LegR = { Parent = nil, At = top(src.LegR, 0.2) },
	}
	for name, info in pivots do
		local pivot = CFrame.new(info.At) * turn
		local part0 = if info.Parent then parts[info.Parent] else root
		local part0T = if info.Parent then src[info.Parent].CFrame else rootT
		local motor = Instance.new("Motor6D")
		motor.Name = "Rig_" .. name
		motor.Part0 = part0
		motor.Part1 = parts[name]
		motor.C0 = part0T:Inverse() * pivot
		motor.C1 = src[name].CFrame:Inverse() * pivot
		motor.Parent = parts[name]
	end
	return parts.Body, floorY
end

-- Attaches the Rift Husk visual: the jointed rig if available, otherwise the
-- single AI mesh (ServerStorage.RiftboundAssets.RiftHusk). Returns false if
-- neither template exists, so the caller can fall back to the blocky body.
local function attachHuskVisual(model, root)
	local assets = ServerStorage:FindFirstChild("RiftboundAssets")
	if not assets then
		return false
	end
	local body, top
	local rigTemplate = assets:FindFirstChild("RiftHuskRig")
	if rigTemplate then
		local floorY
		body, floorY = attachHuskRig(model, root, rigTemplate)
		if body then
			-- Height of the top of the body above the root centre.
			local b = rigTemplate.Body
			top = (b.Position.Y + b.Size.Y / 2) - (floorY + 2)
		end
	end
	if not body then
		local template = assets:FindFirstChild("RiftHusk")
		if not template then
			return false
		end
		body = template:Clone()
		body.Anchored = false
		body.CanCollide = false
		body.CanTouch = false
		body.Massless = true
		local lift = body.Size.Y / 2 - 2
		local motor = Instance.new("Motor6D")
		motor.Name = "VisualMotor"
		motor.Part0 = root
		motor.Part1 = body
		motor.C0 = CFrame.new(0, lift, 0)
		motor.C1 = CFrame.Angles(0, math.pi, 0)
		body.CFrame = root.CFrame * motor.C0 * motor.C1:Inverse()
		motor.Parent = root
		body.Parent = model
		top = lift + body.Size.Y / 2
	end
	model:SetAttribute("HasVisual", true)

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(178, 108, 255)
	glow.Range = 12
	glow.Brightness = 1.6
	glow.Parent = body

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "RiftAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(Color3.fromRGB(231, 200, 255), Color3.fromRGB(150, 70, 255))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Rate = 10
	aura.Speed = NumberRange.new(1.5, 3)
	aura.SpreadAngle = Vector2.new(25, 25)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Parent = body

	-- Invisible anchor for the health bar, just above the skull.
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Transparency = 1
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.CFrame = root.CFrame * CFrame.new(0, top - 0.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head
	head.Parent = model
	return true
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
	model.PrimaryPart = root
	if not (opts.Visual == "RiftHusk" and attachHuskVisual(model, root)) then
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
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 1
	hum.MaxHealth = opts.Health or 120
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = opts.Speed or 10
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	model:SetAttribute("SpawnAt", workspace:GetServerTimeNow())
	model.Parent = folder
	root:SetNetworkOwner(nil)
	Enemies.Register(model)

	hum.Died:Connect(function()
		if model:GetAttribute("HasVisual") then
			shardBurst(root.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(178, 108, 255))
		end
		local gold = opts.Gold
		if type(gold) == "table" then
			gold = math.random(gold[1], gold[2])
		end
		local items = {}
		for _, entry in opts.Loot or {} do
			if math.random() < entry.Chance then
				items[entry.Id] = (items[entry.Id] or 0) + math.random(entry.Min or 1, entry.Max or 1)
			end
		end
		if (opts.Xp or 0) > 0 or (gold or 0) > 0 or next(items) then
			Drops.Spawn(root.Position, opts.Xp, gold, root.Position.Y - 2, items)
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
