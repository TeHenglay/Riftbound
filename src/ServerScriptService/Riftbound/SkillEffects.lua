-- Server-side skill execution: hit detection, damage, statuses and visuals.
-- One function per skill Kind (see ReplicatedStorage.Riftbound.Skills).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Skills = require(Shared:WaitForChild("Skills"))
local Enemies = require(script.Parent.Enemies)

local DEFAULT_RANGE = 60
local GROUND_OFFSET = 2.9 -- HumanoidRootPart height above the floor for a standard avatar

local fx = workspace:FindFirstChild("RiftFX") or Instance.new("Folder")
fx.Name = "RiftFX"
fx.Parent = workspace

local SkillEffects = {}
local Kinds = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = fx
	return p
end

local function tween(inst, t, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function fadeOut(p, t, goal)
	goal = goal or {}
	goal.Transparency = 1
	tween(p, t, goal)
	Debris:AddItem(p, t + 0.05)
end

-- A flat disc lying on the ground (cylinders point along X, so roll 90 degrees).
local function disc(pos, radius, color, transparency)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency or 0.5,
	})
end

local function bolt(from, to, color, width)
	local points = { from }
	local segments = 4
	for i = 1, segments - 1 do
		local p = from:Lerp(to, i / segments)
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.5
		table.insert(points, p + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local seg = part({
			Size = Vector3.new(width or 0.4, width or 0.4, len),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color,
		})
		fadeOut(seg, 0.25)
	end
end

local function hit(ctx, model, mult)
	Enemies.Damage(model, ctx.Damage * (mult or 1), ctx.Def.Elements, ctx.Color)
	if ctx.Def.Status then
		for name, params in ctx.Def.Status do
			Enemies.ApplyStatus(model, name, params)
		end
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
	local size = if def.Radius >= 6 then 2 else 1
	local ball = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(ctx.Origin + ctx.Dir * 2.5),
		Color = ctx.Color,
	})
	local light = Instance.new("PointLight")
	light.Color = ctx.Color
	light.Range = 10
	light.Parent = ball

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fx, Enemies.Folder, ctx.Player.Character }

	local travelled = 0
	local conn
	local function explode(pos)
		conn:Disconnect()
		ball:Destroy()
		for _, model in Enemies.InRadius(pos, def.Radius) do
			hit(ctx, model)
		end
		local burst = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one,
			CFrame = CFrame.new(pos),
			Color = ctx.Color,
			Transparency = 0.2,
		})
		fadeOut(burst, 0.3, { Size = Vector3.one * def.Radius * 2 })
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		local from = ball.Position
		local step = ctx.Dir * def.Speed * dt
		local wall = workspace:Raycast(from, step, params)
		if wall then
			explode(wall.Position)
			return
		end
		local pos = from + step
		ball.Position = pos
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
	local base = CFrame.lookAt(o, o + dir) * CFrame.new(0, -1.5, 0)
	local slab = part({
		Size = Vector3.new(def.Width, 3, 1),
		CFrame = base * CFrame.new(0, 0, -0.5),
		Color = ctx.Color,
		Transparency = 0.3,
	})
	tween(slab, sweep, { Size = Vector3.new(def.Width, 3, def.Length), CFrame = base * CFrame.new(0, 0, -def.Length / 2) })
	task.delay(sweep, function()
		fadeOut(slab, 0.35)
	end)
end

function Kinds.Nova(ctx)
	local def = ctx.Def
	local center = ctx.Origin
	for _, model in Enemies.InRadius(center, def.Radius) do
		hit(ctx, model)
		if def.Knockback then
			pushAway(model, center, def.Knockback)
		end
	end
	local ring = disc(center - Vector3.new(0, GROUND_OFFSET - 0.2, 0), 2, ctx.Color, 0.2)
	fadeOut(ring, 0.4, { Size = Vector3.new(0.3, def.Radius * 2, def.Radius * 2) })
	local dome = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(center),
		Color = ctx.Color,
		Transparency = 0.5,
	})
	fadeOut(dome, 0.35, { Size = Vector3.one * def.Radius * 1.6 })
end

function Kinds.Strike(ctx)
	local def = ctx.Def
	local center = ctx.Target
	local warn = disc(center + Vector3.new(0, 0.2, 0), def.Radius, ctx.Color, 0.75)
	tween(warn, def.Delay, { Transparency = 0.45 }, Enum.EasingStyle.Linear)
	task.delay(def.Delay, function()
		warn:Destroy()
		local targets = Enemies.InRadius(center, def.Radius)
		for _, model in targets do
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
		local column = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, def.Radius * 1.2, def.Radius * 1.2),
			CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
			Color = ctx.Color,
			Transparency = 0.15,
		})
		fadeOut(column, 0.45, {
			Size = Vector3.new(14, def.Radius * 2, def.Radius * 2),
			CFrame = CFrame.new(center + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		})
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * def.Radius * 0.55
			local spike = part({
				Size = Vector3.new(1.4, 0.5, 1.4),
				CFrame = CFrame.new(center + offset) * CFrame.Angles(math.random() * 0.5, angle, math.random() * 0.5),
				Color = ctx.Color,
				Material = Enum.Material.Slate,
			})
			tween(spike, 0.15, { Size = Vector3.new(1.4, 6, 1.4) })
			task.delay(0.5, function()
				fadeOut(spike, 0.3)
			end)
		end
	end)
end

function Kinds.Zone(ctx)
	local def = ctx.Def
	local center = ctx.Target
	local tickDamage = (def.TickDamage or 0) * Skills.DamageMult(ctx.Level)
	local isStorm = table.find(def.Elements, "Lightning") ~= nil

	local zone = disc(center + Vector3.new(0, 0.2, 0), 1, ctx.Color, 0.55)
	tween(zone, 0.25, { Size = Vector3.new(0.3, def.Radius * 2, def.Radius * 2) })
	local cloud = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(def.Radius * 2, 4, def.Radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, if isStorm then 14 else 3, 0)),
		Color = ctx.Color,
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
	})

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
				bolt(p + Vector3.new(0, 14, 0), p, ctx.Color, 0.6)
			end
		end
		fadeOut(zone, 0.4)
		fadeOut(cloud, 0.4)
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
		bolt(ctx.Origin, ctx.Target + Vector3.new(0, 1, 0), ctx.Color, 0.3)
		return
	end

	task.spawn(function()
		local from = ctx.Origin
		local current = first
		local mult = 1
		for _ = 0, def.Jumps do
			if not current then
				break
			end
			hitSet[current] = true
			local to = current.PrimaryPart.Position
			bolt(from, to, ctx.Color, 0.45)
			hit(ctx, current, mult)
			mult *= 0.85
			from = to
			task.wait(0.08)
			current = nearest(from, def.JumpRange)
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

	Kinds[def.Kind]({
		Player = player,
		Def = def,
		Level = level,
		Damage = def.Damage * Skills.DamageMult(level),
		Color = Elements.ColorOf(def.Elements),
		Origin = origin,
		Target = target,
		Dir = dir,
	})
end

return SkillEffects
