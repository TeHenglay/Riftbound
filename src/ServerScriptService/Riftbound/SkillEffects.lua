-- Server-side skill execution: hit detection, damage and statuses. One function
-- per skill Kind (see ReplicatedStorage.Riftbound.Skills).
-- Visuals are not built here: the server fires the SkillFx remote with what
-- happened (cast, projectile flight, strike, zone, bolt, impact) and every
-- client renders it with StarterPlayerScripts.Riftbound.SkillVFX.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Skills = require(Shared:WaitForChild("Skills"))
local Enemies = require(script.Parent.Enemies)
local ProgressionService = require(script.Parent.ProgressionService)
local StatService = require(script.Parent.StatService)

local DEFAULT_RANGE = 60
local GROUND_OFFSET = 2.9 -- HumanoidRootPart height above the floor for a standard avatar
local PROJECTILE_START = 2.5 -- studs in front of the caster

local SkillEffects = {}
local Kinds = {}

local nextFxId = 0

-- Sends a visual event to every client (Main creates the SkillFx remote).
local function fx(payload)
	local remotes = Shared:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SkillFx")
	if remote then
		remote:FireAllClients(payload)
	end
end

local function hit(ctx, model, mult)
	Enemies.Damage(model, ctx.Damage * (mult or 1), ctx.Def.Elements, ctx.Color)
	if ctx.Def.Status then
		for name, params in ctx.Def.Status do
			Enemies.ApplyStatus(model, name, params)
		end
	end
	if model.PrimaryPart then
		fx({ Type = "Impact", Skill = ctx.Def.Id, At = model.PrimaryPart.Position })
	end
end

local function pushAway(model, center, force)
	local p = model.PrimaryPart.Position
	local away = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, 1)
	end
	Enemies.Push(model, away.Unit * force, 0.25)
end

function Kinds.Projectile(ctx)
	local def = ctx.Def
	if def.Windup and not ctx.Released then
		-- Let the throw animation reach its release point, from wherever the
		-- caster is standing by then.
		ctx.Released = true
		task.delay(def.Windup, function()
			local char = ctx.Player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				ctx.Origin = root.Position
				Kinds.Projectile(ctx)
			end
		end)
		return
	end
	local size = if def.Radius >= 6 then 2 else 1
	nextFxId += 1
	local id = nextFxId
	local pos = ctx.Origin + ctx.Dir * PROJECTILE_START
	fx({ Type = "ProjectileStart", Id = id, Skill = def.Id, From = pos, Dir = ctx.Dir, Speed = def.Speed, Range = def.Range, Floor = ctx.Floor, Caster = ctx.Player })

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("RiftFX"), Enemies.Folder, ctx.Player.Character }

	local travelled = 0
	local conn
	local function explode(at)
		conn:Disconnect()
		for _, model in Enemies.InRadius(at, def.Radius) do
			hit(ctx, model)
		end
		fx({ Type = "ProjectileEnd", Id = id, Skill = def.Id, At = at, Radius = def.Radius, Floor = ctx.Floor })
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		local step = ctx.Dir * def.Speed * dt
		local wall = workspace:Raycast(pos, step, params)
		if wall then
			explode(wall.Position)
			return
		end
		pos += step
		travelled += step.Magnitude
		for _, model in Enemies.GetAll() do
			if (model.PrimaryPart.Position - pos).Magnitude < 2.5 + size then
				explode(pos)
				return
			end
		end
		if travelled >= def.Range then
			explode(pos)
		end
	end)
end

function Kinds.Line(ctx)
	local def = ctx.Def
	local o, dir = ctx.Origin, ctx.Dir
	local sweep = 0.3
	fx({ Type = "Line", Skill = def.Id, From = o, Dir = dir, Length = def.Length, Width = def.Width, Sweep = sweep, Floor = ctx.Floor })
	for _, model in Enemies.GetAll() do
		local rel = model.PrimaryPart.Position - o
		local along = rel:Dot(dir)
		local side = rel - dir * along
		local perp = Vector3.new(side.X, 0, side.Z).Magnitude
		if along >= -1 and along <= def.Length and perp <= def.Width / 2 + 1.5 then
			task.delay(math.max(along, 0) / def.Length * sweep, function()
				if Enemies.IsAlive(model) then
					hit(ctx, model)
					if def.Knockback then
						Enemies.Push(model, dir * def.Knockback, 0.25)
					end
				end
			end)
		end
	end
end

function Kinds.Cone(ctx)
	local def = ctx.Def
	local o, dir = ctx.Origin, ctx.Dir
	local halfAngle = math.rad(def.Angle / 2)
	fx({ Type = "Cone", Skill = def.Id, From = o, Dir = dir, Length = def.Length, Angle = def.Angle, Sweep = def.Sweep, Windup = def.Windup, Floor = ctx.Floor })
	task.delay(def.Windup or 0, function()
		for _, model in Enemies.GetAll() do
			local rel = model.PrimaryPart.Position - o
			local flat = Vector3.new(rel.X, 0, rel.Z)
			local dist = flat.Magnitude
			-- Inside the angle, with a little slack for the enemy's own width.
			local inCone = dist < 2.5 or math.acos(math.clamp(flat.Unit:Dot(dir), -1, 1)) <= halfAngle + math.atan2(1.5, dist)
			if dist <= def.Length + 1.5 and inCone and math.abs(rel.Y) < 14 then
				task.delay(dist / def.Length * def.Sweep, function()
					if Enemies.IsAlive(model) then
						hit(ctx, model)
					end
				end)
			end
		end
	end)
end

function Kinds.Roller(ctx)
	local def = ctx.Def
	local dir = ctx.Dir
	local side = dir:Cross(Vector3.yAxis)
	fx({ Type = "Roller", Skill = def.Id, From = ctx.Origin, Dir = dir, Speed = def.Speed, Length = def.Length, Radius = def.Radius, Windup = def.Windup, Floor = ctx.Floor })
	task.delay(def.Windup or 0, function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { workspace:FindFirstChild("RiftFX"), Enemies.Folder, ctx.Player.Character }
		local pos = ctx.Origin + dir * 3
		local travelled = 0
		local struck = {}
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			local step = dir * def.Speed * dt
			local wall = workspace:Raycast(pos, step, params)
			travelled += step.Magnitude
			pos += step
			for _, model in Enemies.InRadius(pos, def.Radius) do
				if not struck[model] then
					struck[model] = true
					hit(ctx, model)
					-- Flattened and flung off to the side of the boulder's path.
					local rel = model.PrimaryPart.Position - pos
					local away = if rel:Dot(side) >= 0 then side else -side
					Enemies.Push(model, (dir * 0.7 + away).Unit * (def.Knockback or 0), 0.3)
				end
			end
			if wall or travelled >= def.Length then
				conn:Disconnect()
				fx({ Type = "RollerEnd", Skill = def.Id, At = pos, Floor = ctx.Floor })
			end
		end)
	end)
end

function Kinds.Meteor(ctx)
	local def = ctx.Def
	local center = ctx.Target
	local tickDamage = (def.TickDamage or 0) * Skills.DamageMult(ctx.Level) * ctx.PowerMult
	fx({ Type = "Meteor", Skill = def.Id, At = center, Dir = ctx.Dir, Radius = def.Radius, Delay = def.Delay, Duration = def.Duration, PoolRadius = def.PoolRadius })
	task.delay(def.Delay, function()
		for _, model in Enemies.InRadius(center, def.Radius) do
			hit(ctx, model)
			pushAway(model, center, 25)
		end
		-- The lava pool left behind.
		local elapsed = 0
		while elapsed < def.Duration do
			task.wait(def.TickRate)
			elapsed += def.TickRate
			for _, model in Enemies.InRadius(center, def.PoolRadius) do
				Enemies.Damage(model, tickDamage, def.Elements, ctx.Color)
				for name, params in def.Status or {} do
					Enemies.ApplyStatus(model, name, params)
				end
			end
		end
	end)
end

function Kinds.Leap(ctx)
	local def = ctx.Def
	local char = ctx.Player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	-- The caster's client launches the jump (it owns the character's physics).
	fx({ Type = "Leap", Skill = def.Id, Root = root, Caster = ctx.Player, JumpVelocity = def.JumpVelocity })
	task.spawn(function()
		local start = os.clock()
		task.wait(0.25)
		while os.clock() - start < 2.5 and hum.FloorMaterial == Enum.Material.Air and root.Parent do
			task.wait()
		end
		local at = root.Position - Vector3.new(0, GROUND_OFFSET, 0)
		fx({ Type = "LeapSlam", Skill = def.Id, At = at, Inner = def.InnerRadius, Radius = def.Radius })
		local struck = {}
		for _, model in Enemies.InRadius(at, def.InnerRadius) do
			struck[model] = true
			hit(ctx, model)
		end
		task.wait(0.15)
		for _, model in Enemies.InRadius(at, def.Radius) do
			if not struck[model] then
				hit(ctx, model)
				pushAway(model, at, 30)
			end
		end
	end)
end

function Kinds.Nova(ctx)
	local def = ctx.Def
	local center = ctx.Origin
	local windup = def.Windup or 0
	fx({ Type = "Nova", Skill = def.Id, At = center, Radius = def.Radius, Floor = ctx.Floor, Windup = windup })
	-- The hit lands on the visual release (and the cast animation's fling).
	task.delay(windup, function()
		for _, model in Enemies.InRadius(center, def.Radius) do
			hit(ctx, model)
			if def.Knockback then
				pushAway(model, center, def.Knockback)
			end
		end
	end)
end

function Kinds.Strike(ctx)
	local def = ctx.Def
	local center = ctx.Target
	fx({ Type = "Strike", Skill = def.Id, At = center, Radius = def.Radius, Delay = def.Delay, Pull = def.Pull ~= nil })
	task.delay(def.Delay, function()
		for _, model in Enemies.InRadius(center, def.Radius) do
			if def.Pull then
				local p = model.PrimaryPart.Position
				local toCenter = Vector3.new(center.X - p.X, 0, center.Z - p.Z)
				local speed = math.min(toCenter.Magnitude / 0.2, def.Pull)
				if toCenter.Magnitude > 0.5 then
					Enemies.Push(model, toCenter.Unit * speed, 0.2)
				end
			end
			hit(ctx, model)
		end
	end)
end

function Kinds.Zone(ctx)
	local def = ctx.Def
	local center = ctx.Target
	local tickDamage = (def.TickDamage or 0) * Skills.DamageMult(ctx.Level) * ctx.PowerMult
	local isStorm = table.find(def.Elements, "Lightning") ~= nil
	fx({ Type = "Zone", Skill = def.Id, At = center, Radius = def.Radius, Duration = def.Duration, TickRate = def.TickRate })

	for _, model in Enemies.InRadius(center, def.Radius) do
		if ctx.Damage > 0 then
			hit(ctx, model)
		end
	end

	task.spawn(function()
		local elapsed = 0
		while elapsed < def.Duration do
			task.wait(def.TickRate)
			elapsed += def.TickRate
			local inside = Enemies.InRadius(center, def.Radius)
			for _, model in inside do
				Enemies.Damage(model, tickDamage, def.Elements, ctx.Color)
				for name, params in def.Status or {} do
					Enemies.ApplyStatus(model, name, params)
				end
			end
			if isStorm and #inside > 0 then
				local victim = inside[math.random(1, #inside)]
				local p = victim.PrimaryPart.Position
				fx({ Type = "Bolt", Skill = def.Id, From = p + Vector3.new(0, 16, 0), To = p, Strike = true })
			end
		end
	end)
end

function Kinds.Chain(ctx)
	local def = ctx.Def
	local hitSet = {}
	local function nearest(pos, maxDist)
		local best, bestDist = nil, maxDist
		for _, model in Enemies.GetAll() do
			if not hitSet[model] then
				local d = (model.PrimaryPart.Position - pos).Magnitude
				if d < bestDist then
					best, bestDist = model, d
				end
			end
		end
		return best
	end

	local first = nearest(ctx.Target, 16)
	if not first or (first.PrimaryPart.Position - ctx.Origin).Magnitude > (def.Range or DEFAULT_RANGE) + 5 then
		fx({ Type = "Bolt", Skill = def.Id, From = ctx.Origin, To = ctx.Target + Vector3.new(0, 1, 0), Fizzle = true })
		return
	end

	task.spawn(function()
		local from = ctx.Origin
		local current = first
		local mult = 1
		for jump = 0, def.Jumps do
			if not current then
				break
			end
			hitSet[current] = true
			local to = current.PrimaryPart.Position
			fx({ Type = "Bolt", Skill = def.Id, From = from, To = to, First = jump == 0 })
			hit(ctx, current, mult)
			mult *= 0.85
			from = to
			task.wait(0.08)
			current = nearest(from, def.JumpRange)
		end
	end)
end

-- Pulls every enemy within `reach` of `center` toward it. `speed` caps the pull.
local function pullIn(center, reach, speed, duration)
	for _, model in Enemies.InRadius(center, reach) do
		local p = model.PrimaryPart.Position
		local toCenter = Vector3.new(center.X - p.X, 0, center.Z - p.Z)
		local dist = toCenter.Magnitude
		if dist > 1 then
			Enemies.Push(model, toCenter.Unit * math.min(dist / math.max(duration, 0.05), speed), duration)
		end
	end
end

function Kinds.Tornado(ctx)
	local def = ctx.Def
	local center = ctx.Target
	local tickDamage = (def.TickDamage or 0) * Skills.DamageMult(ctx.Level) * ctx.PowerMult
	fx({ Type = "Tornado", Skill = def.Id, At = center, Radius = def.Radius, Duration = def.Duration })
	for _, model in Enemies.InRadius(center, def.Radius) do
		hit(ctx, model)
	end
	task.spawn(function()
		local elapsed, nextTick = 0, def.TickRate
		while elapsed < def.Duration do
			task.wait(0.15)
			elapsed += 0.15
			-- Constant inward drag, stronger the further out an enemy is.
			pullIn(center, def.Radius * 1.4, def.Pull, 0.2)
			if elapsed >= nextTick then
				nextTick += def.TickRate
				for _, model in Enemies.InRadius(center, def.Radius) do
					Enemies.Damage(model, tickDamage, def.Elements, ctx.Color)
					for name, params in def.Status or {} do
						Enemies.ApplyStatus(model, name, params)
					end
				end
			end
		end
	end)
end

function Kinds.Magnet(ctx)
	local def = ctx.Def
	local center = ctx.Target
	fx({ Type = "Magnet", Skill = def.Id, At = center, Radius = def.Radius, PullTime = def.PullTime })
	task.spawn(function()
		-- Yank phase: fast pulls toward the core.
		local elapsed = 0
		while elapsed < def.PullTime do
			pullIn(center, def.Radius, 95, 0.12)
			task.wait(0.1)
			elapsed += 0.1
		end
		-- Detonation: everything gathered at the core is held in place and hit.
		fx({ Type = "MagnetBlast", Skill = def.Id, At = center, Radius = def.Radius })
		for _, model in Enemies.InRadius(center, def.Radius * 0.55) do
			Enemies.Push(model, Vector3.zero, 0.2)
			hit(ctx, model)
		end
	end)
end

function SkillEffects.Cast(player, id, level, targetPos)
	local def = Skills.Defs[id]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not def or not root then
		return
	end
	local origin = root.Position
	local flat = Vector3.new(targetPos.X - origin.X, 0, targetPos.Z - origin.Z)
	local dir
	if flat.Magnitude > 0.1 then
		dir = flat.Unit
	else
		local look = root.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z).Unit
	end
	local range = def.Range or DEFAULT_RANGE
	local groundY = origin.Y - GROUND_OFFSET
	local target = Vector3.new(targetPos.X, math.clamp(targetPos.Y, groundY - 4, groundY + 4), targetPos.Z)
	if flat.Magnitude > range then
		target = Vector3.new(origin.X, target.Y, origin.Z) + dir * range
	end

	fx({ Type = "Cast", Skill = id, At = origin, Dir = dir, Caster = player })

	local powerMult = ProgressionService.DamageMult(player) * StatService.DamageMult(player)
	Kinds[def.Kind]({
		Player = player,
		Def = def,
		Level = level,
		Damage = def.Damage * Skills.DamageMult(level) * powerMult,
		PowerMult = powerMult,
		Color = Elements.ColorOf(def.Elements),
		Origin = origin,
		Target = target,
		Dir = dir,
		Floor = groundY,
	})
end

return SkillEffects
