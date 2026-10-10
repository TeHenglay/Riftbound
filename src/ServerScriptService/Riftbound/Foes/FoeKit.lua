-- Shared pieces for the nation foes: targeting, ground telegraphs, hit
-- shapes, player status effects (burn, slow, root, knockback), dashes,
-- teleports and simple projectiles. Every attack shows a telegraph on the
-- floor first, then checks who is inside the shape when it lands.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Enemies = require(script.Parent.Parent.Enemies)

local FoeKit = {}

local fxFolder = workspace:FindFirstChild("FoeFX") or Instance.new("Folder")
fxFolder.Name = "FoeFX"
fxFolder.Parent = workspace

local function fxPart(props)
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
	p.Parent = fxFolder
	return p
end
FoeKit.FxPart = fxPart

-------------------------------------------------------------------------------
-- Targets
-------------------------------------------------------------------------------

local function aliveChar(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return char, root, hum
	end
	return nil
end

function FoeKit.Nearest(pos, maxDist)
	local best, bestDist = nil, maxDist
	for _, player in Players:GetPlayers() do
		local _, root = aliveChar(player)
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best, bestDist
end

-- Characters whose root is inside a flat circle (and roughly level with it).
function FoeKit.InCircle(pos, radius, minRadius)
	local out = {}
	for _, player in Players:GetPlayers() do
		local char, root = aliveChar(player)
		if char then
			local d = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude
			if d <= radius + 1 and d >= (minRadius or 0) - 1 and math.abs(root.Position.Y - pos.Y) < 10 then
				table.insert(out, char)
			end
		end
	end
	return out
end

-- Characters inside a flat rectangle from `origin` along `dir`.
function FoeKit.InLine(origin, dir, length, width)
	local out = {}
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for _, player in Players:GetPlayers() do
		local char, root = aliveChar(player)
		if char then
			local rel = root.Position - origin
			local along = rel:Dot(dir)
			local across = math.abs(rel:Dot(side))
			if along >= -1 and along <= length + 1 and across <= width / 2 + 1 and math.abs(rel.Y) < 10 then
				table.insert(out, char)
			end
		end
	end
	return out
end

-- Damages a character unless their shield blocks it. Returns true on a hit.
function FoeKit.Hit(foe, char, amount)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local player = Players:GetPlayerFromCharacter(char)
	if player and Enemies.BlockCheck and Enemies.BlockCheck(player, foe) then
		return false
	end
	hum:TakeDamage(amount)
	return true
end

-------------------------------------------------------------------------------
-- Player status effects
-------------------------------------------------------------------------------

-- Burn: damage over time, refreshed (not stacked) by repeat hits.
local burning = {}
function FoeKit.Burn(char, dps, duration)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local untilT = os.clock() + duration
	if burning[char] then
		burning[char].Until = math.max(burning[char].Until, untilT)
		burning[char].Dps = math.max(burning[char].Dps, dps)
		return
	end
	burning[char] = { Until = untilT, Dps = dps }
	task.spawn(function()
		while burning[char] and os.clock() < burning[char].Until and hum.Health > 0 do
			task.wait(0.5)
			if burning[char] then
				hum:TakeDamage(burning[char].Dps * 0.5)
			end
		end
		burning[char] = nil
	end)
end

-- Slow / root: scales WalkSpeed for a while. The speed is only restored if
-- nothing else changed it in the meantime (flask, shield, stat upgrades).
local slowed = {}
function FoeKit.Slow(char, mult, duration)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local st = slowed[char]
	if st then
		st.Until = math.max(st.Until, os.clock() + duration)
		if mult < st.Mult then
			st.Mult = mult
			st.Set = st.Base * mult
			hum.WalkSpeed = st.Set
		end
		return
	end
	st = { Base = hum.WalkSpeed, Mult = mult, Until = os.clock() + duration }
	st.Set = st.Base * mult
	slowed[char] = st
	hum.WalkSpeed = st.Set
	task.spawn(function()
		while os.clock() < st.Until do
			task.wait(0.1)
		end
		if hum.Parent and hum.WalkSpeed == st.Set then
			hum.WalkSpeed = st.Base
		end
		slowed[char] = nil
	end)
end

function FoeKit.Knock(char, velocity)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 18), velocity.Z)
	end
end

-------------------------------------------------------------------------------
-- Telegraphs and effects
-------------------------------------------------------------------------------

local function floorAt(pos)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { Enemies.Folder, fxFolder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, p in Players:GetPlayers() do
		if p.Character then
			params:AddToFilter(p.Character)
		end
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or pos.Y - 3
end
FoeKit.FloorAt = floorAt

-- A flat disc that fills in over `time`: outline at full size, inner disc grows.
function FoeKit.TelegraphCircle(pos, radius, color, time, minRadius)
	local y = floorAt(pos) + 0.08
	local center = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	local outline = fxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, radius * 2, radius * 2),
		CFrame = center, Color = color, Transparency = 0.65,
	})
	local fill = fxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.2, 0.2),
		CFrame = center * CFrame.new(0.02, 0, 0), Color = color, Transparency = 0.35,
	})
	TweenService:Create(fill, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = Vector3.new(0.06, radius * 2, radius * 2) }):Play()
	local hole
	if minRadius then
		hole = fxPart({
			Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, minRadius * 2, minRadius * 2),
			CFrame = center * CFrame.new(0.04, 0, 0), Color = Color3.new(0, 0, 0), Transparency = 0.4,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	Debris:AddItem(outline, time)
	Debris:AddItem(fill, time)
	if hole then
		Debris:AddItem(hole, time)
	end
end

-- A flat strip from `origin` along `dir` that fills from the start over `time`.
function FoeKit.TelegraphLine(origin, dir, length, width, color, time)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local y = floorAt(origin) + 0.08
	local start = Vector3.new(origin.X, y, origin.Z)
	local look = CFrame.lookAt(start, start + dir)
	local outline = fxPart({
		Size = Vector3.new(width, 0.05, length), CFrame = look * CFrame.new(0, 0, -length / 2),
		Color = color, Transparency = 0.65,
	})
	local fill = fxPart({
		Size = Vector3.new(width, 0.06, 0.2), CFrame = look * CFrame.new(0, 0.01, -0.1),
		Color = color, Transparency = 0.35,
	})
	TweenService:Create(fill, TweenInfo.new(time, Enum.EasingStyle.Linear), {
		Size = Vector3.new(width, 0.06, length), CFrame = look * CFrame.new(0, 0.01, -length / 2),
	}):Play()
	Debris:AddItem(outline, time)
	Debris:AddItem(fill, time)
end

-- Expanding ring flash where an attack lands.
function FoeKit.Shockwave(pos, radius, color)
	local y = floorAt(pos) + 0.2
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1, 1),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Transparency = 0.1,
	})
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)
end

-- A burst of small neon shards (death, impacts).
function FoeKit.Burst(pos, color, count, reach)
	for i = 1, count or 10 do
		local shard = fxPart({
			Size = Vector3.new(0.4, 0.4 + math.random() * 1, 0.4), Color = color,
			CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		})
		local angle = i / (count or 10) * math.pi * 2
		local r = (reach or 4) + math.random() * 2
		TweenService:Create(shard, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * r, 1.5 + math.random() * 2.5, math.sin(angle) * r)),
			Transparency = 1, Size = shard.Size * 0.3,
		}):Play()
		Debris:AddItem(shard, 0.6)
	end
end

-- A vertical bolt from the sky (Lightning teleports and strikes).
function FoeKit.Bolt(pos, color)
	local y = floorAt(pos)
	local bolt = fxPart({
		Size = Vector3.new(1.2, 60, 1.2), CFrame = CFrame.new(pos.X, y + 30, pos.Z), Color = color,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 6
	light.Parent = bolt
	TweenService:Create(bolt, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.2, 60, 0.2) }):Play()
	Debris:AddItem(bolt, 0.32)
end

-- A lingering floor zone that ticks `onTick(char)` for each player inside.
function FoeKit.Zone(pos, radius, color, duration, onTick, tick)
	local y = floorAt(pos) + 0.1
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Transparency = 0.45,
	})
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.95 }):Play()
	Debris:AddItem(disc, duration)
	task.spawn(function()
		local t = 0
		while t < duration do
			for _, char in FoeKit.InCircle(pos, radius) do
				onTick(char)
			end
			task.wait(tick or 0.5)
			t += tick or 0.5
		end
	end)
end

-------------------------------------------------------------------------------
-- Movement
-------------------------------------------------------------------------------

function FoeKit.Face(root, pos)
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Rushes `distance` studs along `dir` in `time` seconds.
function FoeKit.Dash(model, dir, distance, time)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	Enemies.Push(model, dir * (distance / time), time)
end

-- Instantly moves the foe to `pos` (on the floor), facing `facePos`.
function FoeKit.Teleport(model, pos, facePos)
	local root = model.PrimaryPart
	local y = floorAt(pos) + 2 + (root.Size.Y / 2 - 1)
	local at = Vector3.new(pos.X, y, pos.Z)
	local look = facePos and Vector3.new(facePos.X, y, facePos.Z) or at + root.CFrame.LookVector
	if (look - at).Magnitude < 0.1 then
		look = at + root.CFrame.LookVector
	end
	model:PivotTo(CFrame.lookAt(at, look))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- Tells the client animator to play the windup now and strike at `delay`.
function FoeKit.Windup(model, delay)
	model:SetAttribute("AttackAt", workspace:GetServerTimeNow() + delay)
end

-------------------------------------------------------------------------------
-- Projectiles
-------------------------------------------------------------------------------

-- Flies `part` (already parented, anchored) from origin along dir. Calls
-- onHit(char) once per character within `radius`; returns when done.
-- opts: Speed, Range, Radius, Pierce (bool), Return (boomerang)
function FoeKit.Projectile(part, origin, dir, opts, onHit)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local hit = {}
	local travelled = 0
	local back = false
	local pos = origin
	local look = CFrame.lookAt(origin, origin + dir)
	part.CFrame = look
	local spin = 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		local step = opts.Speed * dt
		travelled += step
		if not back and travelled >= opts.Range then
			if opts.Return then
				back = true
				travelled = 0
				hit = {}
			else
				break
			end
		elseif back and travelled >= opts.Range then
			break
		end
		pos += (if back then -dir else dir) * step
		if opts.Spin then
			spin += dt * opts.Spin
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, spin, 0)
		else
			part.CFrame = CFrame.lookAt(pos, pos + (if back then -dir else dir))
		end
		local stop = false
		for _, char in FoeKit.InCircle(pos, opts.Radius) do
			if not hit[char] then
				hit[char] = true
				onHit(char, pos)
				if not opts.Pierce then
					stop = true
				end
			end
		end
		if stop then
			break
		end
	end
	TweenService:Create(part, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.16)
	return pos
end

-- Lobs `part` in an arc from `from` to `to` over `time` seconds (blocks).
function FoeKit.Lob(part, from, to, time, height)
	local t0 = os.clock()
	while true do
		local a = math.min((os.clock() - t0) / time, 1)
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		part.CFrame = CFrame.new(p) * CFrame.Angles(a * 6, a * 4, 0)
		if a >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	Debris:AddItem(part, 0)
end

-------------------------------------------------------------------------------
-- The think loop
-------------------------------------------------------------------------------

local function held(model)
	return Enemies.HasStatus(model, "Stun") or Enemies.HasStatus(model, "Freeze")
end
FoeKit.Held = held

-- Runs `think(ctx)` while the foe lives. ctx carries Model, Hum, Root, Opts,
-- Elite, Color, Damage, and per-move cooldowns via ctx:Ready(name, seconds).
function FoeKit.Run(model, hum, ctx, think)
	ctx.Model = model
	ctx.Hum = hum
	ctx.Root = model.PrimaryPart
	ctx.Cooldowns = {}
	function ctx:Ready(name, seconds)
		local t = self.Cooldowns[name]
		return t == nil or os.clock() - t >= seconds
	end
	function ctx:Use(name)
		self.Cooldowns[name] = os.clock()
	end
	function ctx:Alive()
		return Enemies.IsAlive(self.Model) and not held(self.Model)
	end
	-- Wait that bails out early if the foe dies or gets stunned.
	function ctx:Wait(seconds)
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			task.wait(0.05)
			if not Enemies.IsAlive(self.Model) then
				return false
			end
		end
		return not held(self.Model)
	end
	task.spawn(function()
		-- Short spawn-in pause so the rise animation plays before moving.
		task.wait(0.6)
		while Enemies.IsAlive(model) do
			if held(model) then
				task.wait(0.1)
			else
				local target, dist = FoeKit.Nearest(ctx.Root.Position, 90)
				if target then
					ctx.Target, ctx.Dist = target, dist
					local ok, err = pcall(think, ctx)
					if not ok then
						warn("[NationFoes] " .. tostring(err))
						task.wait(0.5)
					end
				else
					hum:MoveTo(ctx.Root.Position)
				end
				task.wait(0.1)
			end
		end
	end)
end

-- The plain close-range strike every foe falls back on.
function FoeKit.Melee(ctx, reach, mult)
	local model, root, target = ctx.Model, ctx.Root, ctx.Target
	ctx.Hum:MoveTo(root.Position)
	FoeKit.Face(root, target.Position)
	FoeKit.Windup(model, 0.4)
	if not ctx:Wait(0.4) then
		return
	end
	for _, char in FoeKit.InCircle(root.Position + root.CFrame.LookVector * (reach / 2), reach / 2 + 1.5) do
		FoeKit.Hit(model, char, ctx.Damage * (mult or 1))
	end
	ctx:Wait(0.3)
end

return FoeKit
