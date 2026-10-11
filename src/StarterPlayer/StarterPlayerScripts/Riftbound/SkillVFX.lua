-- Client-side skill visuals. The server fires Remotes.SkillFx with what
-- happened; this module renders it with particles, beams, trails, ground
-- decals, debris, light flashes and camera shake. Everything is local to the
-- client (folder Workspace.RiftVFX), so the server stays cheap.
--
-- Events (payload.Type): Cast, ProjectileStart, ProjectileEnd, Line, Cone,
-- Nova, Strike, Zone, Bolt, Tornado, Magnet, MagnetBlast, Impact. Each carries the skill id in payload.Skill.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Skills = require(Shared:WaitForChild("Skills"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local Lib = require(Shared:WaitForChild("VfxLibrary"))

local Fx = UIAssets.Fx
local TEX = {
	Glow = Fx.Glow,
	Spark = Fx.Spark,
	Ring = Fx.Ring,
	Telegraph = Fx.Telegraph,
	-- Animated flipbooks from VfxLibrary (Creator Store packs).
	Flame = Lib.Flame,
	Smoke = Lib.Smoke,
	FireBurst = Lib.FireBurst,
	Impact = Lib.Impact,
	SideImpact = Lib.SideImpact,
	Electric = Lib.Electric,
	Splash = Lib.Splash,
	WaterFoam = Lib.WaterFoam,
	Rocks = Lib.Rocks,
	Dust = Lib.Dust,
	Shockwave = Lib.Shockwave,
	SwirlBurst = Lib.SwirlBurst,
	Sparkle = Lib.Sparkle,
	Lightning = Fx.Lightning,
	Swirl = Lib.Swirl,
	Drop = Fx.Drop,
	Crack = Fx.Crack, -- our own transparent crack; the pack one has a black background
	ThunderWave = Lib.ThunderWave,
	Crescent = Lib.Slash,
	Shard = Fx.Shard,
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Per-element palette: Core (hottest), Main, Dark, Smoke.
local PAL = {
	Fire = { Core = rgb(255, 240, 190), Main = rgb(255, 122, 40), Dark = rgb(160, 30, 10), Smoke = rgb(105, 84, 76) },
	Water = { Core = rgb(225, 248, 255), Main = rgb(60, 155, 255), Dark = rgb(20, 60, 150), Smoke = rgb(195, 228, 255) },
	Earth = { Core = rgb(240, 205, 150), Main = rgb(185, 128, 70), Dark = rgb(80, 50, 25), Smoke = rgb(150, 118, 86) },
	Air = { Core = rgb(240, 255, 252), Main = rgb(160, 240, 220), Dark = rgb(60, 150, 130), Smoke = rgb(220, 245, 240) },
	Lightning = { Core = rgb(250, 252, 255), Main = rgb(255, 208, 80), Dark = rgb(150, 95, 255), Smoke = rgb(200, 190, 255) },
	Rift = { Core = rgb(245, 230, 255), Main = rgb(178, 108, 255), Dark = rgb(70, 25, 140), Smoke = rgb(110, 70, 160) },
}

local SkillVFX = {}

local camera -- CameraRig, for screen shake
local CastAnimator = require(script.Parent:WaitForChild("CastAnimator"))
local localPlayer = game:GetService("Players").LocalPlayer
local folder
local projectiles = {} -- [id] = { Part, Emitters, Conn }

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function palettes(id)
	local def = Skills.Defs[id]
	local elements = def and def.Elements or {}
	local a = PAL[elements[1] or "Rift"]
	local b = PAL[elements[2] or elements[1] or "Rift"]
	return a, b, def
end

local function cs(...)
	local colors = { ... }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(keys)
end

-- ns(0, a, 0.5, b, 1, c) -> NumberSequence
local function ns(...)
	local v = { ... }
	if #v == 1 then
		return NumberSequence.new(v[1])
	end
	local keys = {}
	for i = 1, #v, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(keys)
end

local FADE = ns(0, 0, 0.7, 0.3, 1, 1)

-- Recolours the pack's lightning templates: white-hot, gold, violet.
local ELECTRIC_TINT = cs(Color3.new(1, 1, 1), PAL.Lightning.Main, PAL.Lightning.Dark)

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function anchor(cf, size, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
	p.Parent = folder
	if life then
		Debris:AddItem(p, life)
	end
	return p
end

local function emitter(parent, s)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = s.Enabled == true
	Lib.Apply(e, s.Texture or TEX.Glow)
	e.Color = s.Color or cs(Color3.new(1, 1, 1))
	e.Size = s.Size or ns(1)
	e.Transparency = s.Transparency or FADE
	e.Lifetime = s.Lifetime or NumberRange.new(0.5)
	e.Speed = s.Speed or NumberRange.new(0)
	e.SpreadAngle = s.Spread or Vector2.zero
	e.Rotation = s.Rotation or NumberRange.new(0, 360)
	e.RotSpeed = s.RotSpeed or NumberRange.new(0)
	e.Acceleration = s.Accel or Vector3.zero
	e.Drag = s.Drag or 0
	e.LightEmission = s.Light or 0.7
	e.LightInfluence = 0
	e.Rate = s.Rate or 0
	e.LockedToPart = s.Locked == true
	e.EmissionDirection = s.Dir or Enum.NormalId.Top
	e.ZOffset = s.ZOffset or 0
	if s.Parallel then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	if s.Shape then
		e.Shape = s.Shape
		e.ShapeInOut = s.InOut or Enum.ParticleEmitterShapeInOut.Outward
		e.ShapeStyle = s.Style or Enum.ParticleEmitterShapeStyle.Volume
	end
	e.Parent = parent
	if s.Count then
		e:Emit(s.Count)
	end
	return e
end

-- One-shot particle burst at a point (or a shaped area if size is given).
local function burst(at, specs, life, size)
	local p = anchor(at, size, life or 2)
	for _, s in specs do
		emitter(p, s)
	end
	return p
end

local function flash(at, color, range, brightness, time)
	local p = anchor(at, nil, time + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness * 0.45
	light.Shadows = false
	light.Parent = p
	tween(light, time, { Brightness = 0 })
end

-- Flat decal on the ground. Grows from `from` to `to` (studs) and fades over `life`.
local function groundDecal(at, texture, color, from, to, life, opts)
	opts = opts or {}
	local floorY = opts.Floor or at.Y
	local spin = opts.Spin or 0
	local p = anchor(CFrame.new(at.X, floorY + 0.06 + (opts.Lift or 0), at.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0), Vector3.new(from, 0.05, from), life + 0.1)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = texture
	d.Color3 = color
	d.Transparency = opts.StartAlpha or 0
	d.Parent = p
	if opts.FadeIn then
		d.Transparency = 1
		tween(d, opts.FadeIn, { Transparency = opts.StartAlpha or 0 })
	end
	tween(p, opts.GrowTime or life, { Size = Vector3.new(to, 0.05, to), CFrame = p.CFrame * CFrame.Angles(0, spin, 0) }, opts.Style)
	task.delay(opts.Hold or 0, function()
		if d.Parent then
			tween(d, math.max(life - (opts.Hold or 0), 0.05), { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	return p, d
end

local function ring(at, color, from, to, life, floorY)
	return groundDecal(at, TEX.Ring, color, from, to, life, { Floor = floorY })
end

local function shake(amount, at)
	if camera then
		camera.Shake(amount, at)
	end
end

-------------------------------------------------------------------------------
-- Pre-built effect templates (ReplicatedStorage.RiftboundVFX): artist-made
-- effects from Creator Store packs (Euphoric "Anime" set, Yona heal) plus the
-- AI-generated skill meshes. Emitters use the pack convention: attributes
-- EmitCount / EmitDelay say how many particles to burst and when.
-------------------------------------------------------------------------------

local templates = ReplicatedStorage:FindFirstChild("RiftboundVFX")

local function scaleSeq(seq, k)
	local keys = {}
	for _, p in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(keys)
end

-- Plays template `name` at `cf`. opts: Scale, Color (ColorSequence), Follow (BasePart).
local function playTemplate(name, cf, opts)
	opts = opts or {}
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local source = templates and templates:FindFirstChild(name)
	if not source then
		return nil
	end
	local fx = source:Clone()
	local scale = opts.Scale or 1
	local life = 0.5
	local items = fx:GetDescendants()
	table.insert(items, fx)
	for _, d in items do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
			if scale ~= 1 then
				d.Size = scaleSeq(d.Size, scale)
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
				d.Acceleration *= scale
			end
			if opts.Color then
				d.Color = opts.Color
			end
			local delay = d:GetAttribute("EmitDelay") or 0
			local count = d:GetAttribute("EmitCount") or math.max(1, math.floor(d.Rate * 0.3))
			life = math.max(life, delay + d.Lifetime.Max)
			task.delay(delay, function()
				if d.Parent then
					d:Emit(count)
				end
			end)
		elseif d:IsA("Beam") or d:IsA("Trail") then
			Debris:AddItem(d, 0.35)
		end
	end
	if fx:IsA("BasePart") then
		fx.CFrame = cf
	else
		fx:PivotTo(cf)
	end
	fx.Parent = folder
	if opts.Follow then
		local follow = opts.Follow
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not fx.Parent or not follow.Parent then
				conn:Disconnect()
				return
			end
			if fx:IsA("BasePart") then
				fx.CFrame = follow.CFrame
			else
				fx:PivotTo(follow.CFrame)
			end
		end)
	end
	Debris:AddItem(fx, life + 0.6)
	return fx
end

-- Per-element impact templates (small, for every hit).
local IMPACT_TEMPLATE = {
	Fire = "Fire-01",
	Water = "Splash-01",
	Earth = "Punch-02",
	Air = "Wind-02",
	Lightning = "Lighting-01",
	Rift = "Slash-Impact-01",
}

-- Clones an AI-generated mesh template (e.g. "WaveMesh", "RockSpike").
local function meshTemplate(name)
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local source = templates and templates:FindFirstChild(name)
	if not source then
		return nil
	end
	local m = source:Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	return m
end


-- Forked, strobing lightning between two points: a soft violet halo, a
-- coloured glow and a thin white-hot core, with side forks branching off.
-- opts: Width, Life, Halo (halo colour), NoBranch.
local function lightning(from, to, color, opts)
	opts = opts or {}
	local life = opts.Life or 0.28
	local width = opts.Width or 0.6
	local halo = opts.Halo or PAL.Lightning.Dark
	local dist = (to - from).Magnitude
	local segments = math.clamp(math.floor(dist / 3), 3, 14)
	local base = anchor(CFrame.new(), nil, life + 0.1)
	local atts = {}
	for i = 0, segments do
		local a = Instance.new("Attachment")
		a.WorldPosition = from:Lerp(to, i / segments)
		a.Parent = base
		atts[i] = a
	end
	local beams = {}
	local function layer(texture, w, col, alpha, emission)
		for i = 1, segments do
			local b = Instance.new("Beam")
			b.Attachment0 = atts[i - 1]
			b.Attachment1 = atts[i]
			b.FaceCamera = true
			b.LightEmission = emission or 1
			b.LightInfluence = 0
			b.Segments = 1
			if texture then
				b.Texture = texture
			end
			b.Width0, b.Width1 = w, w
			b.Color = cs(col)
			b.Parent = base
			table.insert(beams, { Beam = b, Alpha = alpha })
		end
	end
	if opts.Ink then
		-- Anime shade: a solid black bolt on its own jagged path, no glow.
		layer(nil, width, Color3.new(0, 0, 0), 0.05, 0)
	else
		layer(TEX.Glow, width * 5, halo, 0.55)
		layer(TEX.Glow, width * 2.2, color, 0.2)
		layer(nil, width * 0.45, Color3.new(1, 1, 1), 0)
	end

	local jag = math.min(dist * 0.12, 2.6)
	local function rejitter()
		for i = 1, segments - 1 do
			local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * jag * 2
			atts[i].WorldPosition = from:Lerp(to, i / segments) + offset
		end
	end
	rejitter()

	-- Side forks off the main channel.
	if not opts.NoBranch and dist > 6 then
		local along = (to - from).Unit
		local side = along:Cross(Vector3.yAxis)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.xAxis
		for _ = 1, math.random(1, 2 + math.floor(dist / 15)) do
			local origin = atts[math.random(1, segments - 1)].WorldPosition
			local reach = dist * (0.15 + math.random() * 0.15)
			local tip = origin + along * reach + (side * (math.random() - 0.5) * 2 + Vector3.new(0, math.random() - 0.6, 0)) * reach
			lightning(origin, tip, color, { Width = width * 0.5, Life = life * 0.7, NoBranch = true, Halo = halo, Ink = opts.Ink })
		end
	end

	local start, last, blink = os.clock(), 0, false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > life or not base.Parent then
			conn:Disconnect()
			return
		end
		if t - last > 0.045 then
			last = t
			rejitter()
			-- Strobe: the channel briefly drops out, like real lightning.
			blink = math.random() < 0.2
		end
		local fade = math.clamp(t / life, 0, 1) ^ 2
		for _, item in beams do
			item.Beam.Transparency = ns(if blink then 0.85 else item.Alpha + (1 - item.Alpha) * fade)
		end
	end)
	return base
end

-- Rock / crystal chunks flung out in arcs.
local function debrisBurst(at, color, count, opts)
	opts = opts or {}
	local floorY = opts.Floor or at.Y - 2
	for _ = 1, count do
		-- opts.Wedge: angular rock chips instead of cubes.
		local chunk = Instance.new(if opts.Wedge then "WedgePart" else "Part")
		local s = (opts.Size or 0.6) * (0.6 + math.random() * 0.8)
		chunk.Size = Vector3.new(s, s * (0.7 + math.random() * 0.6), s)
		chunk.Material = opts.Material or Enum.Material.Slate
		chunk.Color = color
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.Parent = folder
		local angle = math.random() * math.pi * 2
		local reach = (opts.Reach or 6) * (0.5 + math.random() * 0.7)
		local apex = at + Vector3.new(math.cos(angle) * reach * 0.5, (opts.Height or 4) * (0.6 + math.random() * 0.6), math.sin(angle) * reach * 0.5)
		local land = Vector3.new(at.X + math.cos(angle) * reach, floorY + s / 2, at.Z + math.sin(angle) * reach)
		local spin = CFrame.Angles(math.random() * 4, math.random() * 4, math.random() * 4)
		local up = tween(chunk, 0.22, { CFrame = CFrame.new(apex) * spin }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		up.Completed:Connect(function()
			if chunk.Parent then
				tween(chunk, 0.26, { CFrame = CFrame.new(land) * spin * spin }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.6, function()
					if chunk.Parent then
						tween(chunk, 0.4, { Transparency = 1, Size = chunk.Size * 0.4 })
					end
				end)
			end
		end)
		Debris:AddItem(chunk, 1.4)
	end
end

-- Earth spikes erupting in a ring (and the centre).
local function spikes(at, radius, color, floorY, opts)
	opts = opts or {}
	local count = opts.Count or 7
	for i = 0, count do
		local offset = Vector3.zero
		local height = (opts.Height or 6) * 1.2
		if i > 0 then
			local angle = i / count * math.pi * 2 + math.random() * 0.3
			offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * (0.45 + math.random() * 0.25)
			height = (opts.Height or 6) * (0.7 + math.random() * 0.4)
		end
		local w = (opts.Width or 1.6) * (0.8 + math.random() * 0.4)
		-- opts.Mesh (e.g. the Blender StoneSpikeMesh), else the AI-generated
		-- rock spike mesh, else a plain wedge.
		local custom = opts.Mesh and meshTemplate(opts.Mesh)
		local spike = custom or meshTemplate("RockSpike")
		if custom then
			-- Blender spike is 1.1 x 3 studs (tall and slim); keep it chunky.
			spike.Size = Vector3.new(w * 1.5, height * 1.15, w * 1.5)
			height = spike.Size.Y
		elseif spike then
			spike.Size = Vector3.new(w * 1.4, height, w * 1.4)
		else
			spike = Instance.new("WedgePart")
			spike.Size = Vector3.new(w, height, w)
			spike.Material = opts.Material or Enum.Material.Slate
			spike.Color = color
			spike.Anchored = true
			spike.CanCollide = false
			spike.CanQuery = false
			spike.CanTouch = false
		end
		local lean = CFrame.Angles((math.random() - 0.5) * 0.5, math.random() * 6, (math.random() - 0.5) * 0.5)
		local base = CFrame.new(at.X + offset.X, floorY, at.Z + offset.Z) * lean
		spike.CFrame = base * CFrame.new(0, -height / 2, 0)
		spike.Parent = folder
		if custom then
			-- Staggered burst: each spike punches up with a twist, overshoots,
			-- then settles; a puff of dust and grit kicks out at its base.
			local delay = if i == 0 then 0 else math.random() * 0.12
			local up = base * CFrame.new(0, height / 2 - 0.3, 0)
			task.delay(delay, function()
				if not spike.Parent then
					return
				end
				spike.CFrame = base * CFrame.new(0, -height / 2, 0) * CFrame.Angles(0, -0.6, 0)
				tween(spike, 0.14, { CFrame = up * CFrame.new(0, height * 0.12, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.delay(0.14, function()
					if spike.Parent then
						tween(spike, 0.12, { CFrame = up }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
					end
				end)
				burst(Vector3.new(at.X + offset.X, floorY + 0.4, at.Z + offset.Z), {
					{ Texture = TEX.Dust, Count = 2, Light = 0, Size = ns(0, 1.5, 1, 3.5), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(3, 6), Spread = Vector2.new(180, 20), Color = cs(color) },
					{ Texture = TEX.Rocks, Count = 3, Light = 0, Size = ns(0, 0.6, 1, 0.4), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(10, 16), Spread = Vector2.new(50, 50), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(Color3.new(1, 1, 1)) },
				}, 1)
			end)
			task.delay((opts.Hold or 0.65) + delay, function()
				if spike.Parent then
					-- Crumble: shudder, then sink and break into chunks.
					tween(spike, 0.06, { CFrame = up * CFrame.Angles(0.05, 0, -0.05) })
					task.delay(0.06, function()
						if spike.Parent then
							debrisBurst(spike.Position, rgb(48, 38, 32), 3, { Floor = floorY, Size = w * 0.35, Height = 2.5, Reach = 2, Material = Enum.Material.Basalt, Wedge = true })
							tween(spike, 0.3, { CFrame = base * CFrame.new(0, -height / 2, 0), Size = spike.Size * Vector3.new(0.7, 1, 0.7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						end
					end)
				end
			end)
		else
			tween(spike, 0.12, { CFrame = base * CFrame.new(0, height / 2 - 0.3, 0) }, Enum.EasingStyle.Back)
			task.delay(opts.Hold or 0.65, function()
				if spike.Parent then
					tween(spike, 0.35, { CFrame = base * CFrame.new(0, -height / 2, 0), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
		end
		Debris:AddItem(spike, (opts.Hold or 0.65) + 0.6)
		if opts.Glow then
			local light = Instance.new("PointLight")
			light.Color = opts.Glow
			light.Range = 6
			light.Brightness = 1.5
			light.Parent = spike
		end
	end
end

-------------------------------------------------------------------------------
-- Plasma Lance: a spear of red-gold plasma, thrown like a javelin.
-------------------------------------------------------------------------------

local PLASMA = {
	White = rgb(255, 250, 225),
	Yellow = rgb(255, 212, 64),
	Orange = rgb(255, 128, 30),
	Red = rgb(225, 40, 20),
	Smoke = rgb(80, 52, 44),
}
-- Tail to tip: deep red, orange, gold, white-hot.
local PLASMA_SEQ = cs(PLASMA.Red, PLASMA.Orange, PLASMA.Yellow, PLASMA.White)
-- Over a flame's life: white-hot, gold, orange, red.
local PLASMA_FIRE = cs(PLASMA.White, PLASMA.Yellow, PLASMA.Orange, PLASMA.Red)

local function plasmaPart(shape, size, color)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Builds a plasma spear `length` studs long. Returns the root part (every
-- piece is parented under it) and place(cf), which puts the spear at cf with
-- its tip along cf.LookVector.
local function buildSpear(length)
	local root = anchor(CFrame.new(), Vector3.new(0.2, 0.2, 0.2))
	-- The AI-generated thunder spear (lightning-bolt blade, runed shaft); a
	-- neon shaft and tip if the template is missing.
	local model = meshTemplate("ThunderSpear")
	local shaft, tip
	if model then
		model.Size *= length / model.Size.Y
		model.Parent = root
	else
		shaft = plasmaPart(Enum.PartType.Cylinder, Vector3.new(length, 0.28, 0.28), PLASMA.Orange)
		shaft.Parent = root
		tip = plasmaPart(Enum.PartType.Block, Vector3.one, PLASMA.White)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(0.6, 0.6, 2.2)
		mesh.Parent = tip
		tip.Parent = root
	end
	-- Crackling energy wrapped around the blade.
	local bladeAtt = Instance.new("Attachment")
	bladeAtt.Position = Vector3.new(0, 0, -length * 0.4)
	bladeAtt.Parent = root
	emitter(bladeAtt, { Enabled = true, Texture = TEX.Electric, Rate = 18, Locked = true, Size = ns(0, 1.6, 1, 2.2), Lifetime = NumberRange.new(0.1, 0.16), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 })
	-- Red-to-gold glow along the whole spear, plus a wider soft aura.
	local tail, head = Instance.new("Attachment"), Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0, length / 2 + 0.6)
	head.Position = Vector3.new(0, 0, -length / 2 - 1.4)
	tail.Parent, head.Parent = root, root
	for _, spec in { { 0.8, 1.4, ns(0, 0.6, 1, 0.35) }, { 2.4, 3.2, ns(0, 0.9, 1, 0.6) } } do
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = tail, head
		beam.Texture = TEX.Glow
		beam.Width0, beam.Width1 = spec[1], spec[2]
		beam.Transparency = spec[3]
		beam.Color = PLASMA_SEQ
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = root
	end
	local light = Instance.new("PointLight")
	light.Color = PLASMA.Orange
	light.Range = 12
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = root
	local function place(cf)
		root.CFrame = cf
		if model then
			-- The mesh is modelled tip-up (+Y); lay it along the look vector.
			model.CFrame = cf * CFrame.Angles(-math.pi / 2, 0, 0)
		else
			shaft.CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
			tip.CFrame = cf * CFrame.new(0, 0, -length / 2 - 0.5)
		end
	end
	return root, place
end

-- The spear forming in the caster's raised hand during the throw windup.
local function plasmaReady(character, windup)
	local hand = character and character:FindFirstChild("RightHand")
	local body = character and character:FindFirstChild("HumanoidRootPart")
	if not hand or not body then
		return
	end
	local root, place = buildSpear(5)
	emitter(root, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 40, Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.15, 0.25), Speed = NumberRange.new(4, 8), Spread = Vector2.new(180, 180), Color = cs(PLASMA.Yellow, PLASMA.Red), Light = 1 })
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > windup or not hand.Parent then
			conn:Disconnect()
			root:Destroy()
			return
		end
		local look = body.CFrame.LookVector
		-- Held level with the shoulder, tip toward the target, crackling in.
		place(CFrame.lookAt(hand.Position, hand.Position + look) * CFrame.Angles(0.2, 0, os.clock() * 10) * CFrame.new(0, 0, 0.6))
	end)
	burst(hand.Position, {
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, 3, 1, 0), Lifetime = NumberRange.new(0.2), Color = cs(PLASMA.White, PLASMA.Orange) },
		{ Texture = TEX.Electric, Count = 1, Size = ns(0, 2.5, 1, 3), Lifetime = NumberRange.new(0.2), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 },
	}, 1)
end

local function launchPlasmaLance(e)
	local root, place = buildSpear(6)
	local emitters = {
		emitter(root, { Enabled = true, Texture = TEX.Flame, Rate = 90, Size = ns(0, 2, 1, 0.4), Lifetime = NumberRange.new(0.15, 0.28), Speed = NumberRange.new(2, 5), Spread = Vector2.new(15, 15), Dir = Enum.NormalId.Back, RotSpeed = NumberRange.new(-120, 120), Color = PLASMA_FIRE, Light = 0.9 }),
		emitter(root, { Enabled = true, Texture = TEX.Electric, Rate = 14, Locked = true, Size = ns(0, 2.4, 1, 3), Lifetime = NumberRange.new(0.12, 0.18), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 }),
		emitter(root, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 50, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(6, 14), Spread = Vector2.new(70, 70), Dir = Enum.NormalId.Back, Color = cs(PLASMA.Yellow, PLASMA.Red), Light = 1 }),
		emitter(root, { Enabled = true, Texture = TEX.Smoke, Rate = 12, Light = 0, Size = ns(0, 0.8, 1, 2.5), Transparency = ns(0, 0.6, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(0.5, 1.5), Color = cs(PLASMA.Smoke) }),
	}
	local att0, att1 = Instance.new("Attachment"), Instance.new("Attachment")
	att0.Position, att1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	att0.Parent, att1.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = att0, att1
	trail.Lifetime = 0.2
	trail.Color = cs(PLASMA.Yellow, PLASMA.Orange, PLASMA.Red)
	trail.Transparency = ns(0, 0.1, 1, 1)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.WidthScale = ns(0, 1, 1, 0)
	trail.Parent = root
	-- Black ink shade: a wider black trail and black smoke under the plasma glow.
	local ink0, ink1 = Instance.new("Attachment"), Instance.new("Attachment")
	ink0.Position, ink1.Position = Vector3.new(0, 0.8, 0.6), Vector3.new(0, -0.8, 0.6)
	ink0.Parent, ink1.Parent = root, root
	local inkTrail = Instance.new("Trail")
	inkTrail.Attachment0, inkTrail.Attachment1 = ink0, ink1
	inkTrail.Lifetime = 0.16
	inkTrail.Color = cs(Color3.new(0, 0, 0))
	inkTrail.Transparency = ns(0, 0.2, 1, 1)
	inkTrail.LightEmission = 0
	inkTrail.LightInfluence = 0
	inkTrail.FaceCamera = true
	inkTrail.WidthScale = ns(0, 1, 1, 0)
	inkTrail.Parent = root
	table.insert(emitters, emitter(root, { Enabled = true, Texture = TEX.Smoke, Rate = 25, Light = 0, Size = ns(0, 1.2, 1, 0.3), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.15, 0.25), Speed = NumberRange.new(1, 3), Dir = Enum.NormalId.Back, Color = cs(Color3.new(0, 0, 0)), ZOffset = -1 }))
	-- Ember rings shed off the spear as it flies.
	table.insert(emitters, emitter(root, { Enabled = true, Texture = TEX.Shockwave, Rate = 14, Size = ns(0, 1, 1, 3.5), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.18), Color = cs(PLASMA.Yellow, PLASMA.Red), Light = 1, Dir = Enum.NormalId.Back, Speed = NumberRange.new(0.5) }))

	-- Release flash at the hand.
	playTemplate("Fire-01", CFrame.new(e.From), { Scale = 0.6, Color = PLASMA_FIRE })
	burst(e.From, {
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, 4, 1, 0), Lifetime = NumberRange.new(0.18), Color = cs(PLASMA.White, PLASMA.Orange) },
		{ Texture = TEX.Spark, Count = 20, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(14, 26), Spread = Vector2.new(50, 50), Color = cs(PLASMA.Yellow, PLASMA.Red), Light = 1 },
	}, 1)
	flash(e.From, PLASMA.Orange, 12, 2.5, 0.2)

	local start, lastArc = os.clock(), 0
	local range = Skills.Defs.PlasmaLance.Range
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local d = math.min(t * e.Speed, range)
		local pos = e.From + e.Dir * d
		place(CFrame.lookAt(pos, pos + e.Dir) * CFrame.Angles(0, 0, t * 14))
		-- Plasma arcs crawling along the shaft.
		if t - lastArc > 0.07 then
			lastArc = t
			local jitter = function()
				return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
			end
			lightning(pos + e.Dir * 2 + jitter(), pos - e.Dir * 3 + jitter(), PLASMA.Yellow, { Width = 0.22, Life = 0.08, NoBranch = true, Halo = PLASMA.Red })
			-- Every other arc gets a black ink twin on its own path.
			if math.random() < 0.5 then
				lightning(pos + e.Dir * 1.5 + jitter(), pos - e.Dir * 3.5 + jitter(), Color3.new(0, 0, 0), { Width = 0.28, Life = 0.08, NoBranch = true, Ink = true })
			end
		end
	end)
	local function cleanup()
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("Beam") or d:IsA("PointLight") then
				d.Enabled = false
			end
		end
	end
	projectiles[e.Id] = { Part = root, Emitters = emitters, Conn = conn, Cleanup = cleanup }
	task.delay(range / e.Speed + 1, function()
		local p = projectiles[e.Id]
		if p then
			p.Conn:Disconnect()
			p.Part:Destroy()
			projectiles[e.Id] = nil
		end
	end)
end

-- Impact: a red-gold plasma detonation that leaves the ground burning.
local function plasmaExplosion(at, r, floorY)
	floorY = floorY or at.Y - 2.9
	playTemplate("Fire-03", CFrame.new(at), { Scale = 1.1, Color = PLASMA_FIRE })
	playTemplate("Lighting-03", CFrame.new(at), { Scale = 1.1, Color = cs(PLASMA.White, PLASMA.Yellow, PLASMA.Orange) })
	burst(at, {
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, 3, 0.25, r * 1.8, 1, r * 2.1), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 },
		{ Texture = TEX.FireBurst, Count = 4, Size = ns(0, r * 1.1, 1, r * 1.5), Transparency = ns(0, 0, 1, 0.4), Lifetime = NumberRange.new(0.45, 0.6), Spread = Vector2.new(40, 40), Speed = NumberRange.new(1, 3), Color = PLASMA_FIRE, Light = 0.85 },
		{ Texture = TEX.Electric, Count = 4, Size = ns(0, r * 0.7, 1, r), Lifetime = NumberRange.new(0.3), Spread = Vector2.new(180, 180), Speed = NumberRange.new(2, 5), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 },
		{ Texture = TEX.Flame, Count = 30, Size = ns(0, 4, 1, 1.2), Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(14, 26), Spread = Vector2.new(180, 180), Drag = 5, Accel = Vector3.new(0, 10, 0), RotSpeed = NumberRange.new(-150, 150), Color = PLASMA_FIRE, Light = 0.9 },
		{ Texture = TEX.Spark, Count = 70, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(30, 55), Spread = Vector2.new(180, 180), Drag = 3, Accel = Vector3.new(0, -30, 0), Color = cs(PLASMA.White, PLASMA.Yellow, PLASMA.Red), Light = 1 },
		{ Texture = TEX.Smoke, Count = 4, Light = 0, Size = ns(0, 3, 1, 6), Transparency = ns(0, 0.7, 1, 1), Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(3, 7), Spread = Vector2.new(180, 60), Accel = Vector3.new(0, 5, 0), Drag = 1.5, Color = cs(PLASMA.Smoke) },
	}, 2.5)
	-- Plasma arcs lashing out across the floor.
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + math.random() * 0.4
		local reach = r * (0.7 + math.random() * 0.5)
		lightning(at, Vector3.new(at.X + math.cos(angle) * reach, floorY + 0.5, at.Z + math.sin(angle) * reach), if i % 2 == 0 then PLASMA.Yellow else PLASMA.Orange, { Width = 0.45, Life = 0.3, Halo = PLASMA.Red })
	end
	ring(at, PLASMA.Yellow, 2, r * 2.6, 0.35, floorY)
	task.delay(0.06, function()
		ring(at, PLASMA.Red, 2, r * 2.1, 0.45, floorY)
	end)
	-- Black ink shade: ink shards, black arcs between the plasma arcs, a black
	-- shock ring on the ground and a red-black smoke column.
	burst(at, {
		{ Texture = TEX.Spark, Count = 20, Parallel = true, Light = 0, Size = ns(0, 1.3, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(30, 48), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Smoke, Count = 6, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(10, 16), Spread = Vector2.new(15, 15), Drag = 2, Color = cs(PLASMA.Red, Color3.new(0, 0, 0)), ZOffset = -1 },
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, r * 0.4, 1, r * 3), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1, ZOffset = 2 },
	}, 2)
	for i = 1, 5 do
		local angle = (i + 0.5) / 5 * math.pi * 2 + math.random() * 0.4
		local reach = r * (0.6 + math.random() * 0.5)
		lightning(at, Vector3.new(at.X + math.cos(angle) * reach, floorY + 0.5, at.Z + math.sin(angle) * reach), Color3.new(0, 0, 0), { Width = 0.5, Life = 0.3, Ink = true })
	end
	groundDecal(at, TEX.Ring, Color3.new(0, 0, 0), r * 0.6, r * 2.4, 0.6, { Floor = floorY, Lift = 0.03, StartAlpha = 0.1, GrowTime = 0.3 })
	-- A plasma dome swells and pops, then an aftershock of arcs crackles out.
	local dome = Instance.new("Part")
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Color = PLASMA.Orange
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.CastShadow = false
	dome.Size = Vector3.one * 2
	dome.CFrame = CFrame.new(at)
	dome.Transparency = 0
	dome.Parent = folder
	tween(dome, 0.3, { Size = Vector3.one * r * 2.2, Transparency = 1 })
	Debris:AddItem(dome, 0.35)
	task.delay(0.25, function()
		for i = 1, 4 do
			local angle = math.random() * math.pi * 2
			local reach = r * (0.4 + math.random() * 0.4)
			lightning(at + Vector3.new(0, 1, 0), Vector3.new(at.X + math.cos(angle) * reach, floorY + 0.4, at.Z + math.sin(angle) * reach), PLASMA.Yellow, { Width = 0.3, Life = 0.2, Halo = PLASMA.Red })
		end
		burst(at, {
			{ Texture = TEX.Electric, Count = 3, Size = ns(0, r * 0.5, 1, r * 0.8), Lifetime = NumberRange.new(0.25), Spread = Vector2.new(180, 180), Color = cs(PLASMA.White, PLASMA.Yellow), Light = 1 },
			{ Texture = TEX.Spark, Count = 30, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(25, 40), Spread = Vector2.new(25, 25), Accel = Vector3.new(0, -40, 0), Color = cs(PLASMA.White, PLASMA.Yellow, PLASMA.Red), Light = 1 },
		}, 1.5)
		shake(0.15, at)
	end)
	-- Scorched crater with plasma flames that keep burning for a moment.
	groundDecal(at, TEX.Crack, rgb(40, 14, 8), r * 1.2, r * 1.6, 3, { Floor = floorY, Hold = 2.2, GrowTime = 0.1, StartAlpha = 0.1 })
	groundDecal(at, TEX.Glow, PLASMA.Orange, r * 2, r * 1.6, 2.8, { Floor = floorY, Lift = 0.02, Hold = 1.8, StartAlpha = 0.45 })
	local patch = anchor(CFrame.new(at.X, floorY + 0.4, at.Z), Vector3.new(r * 1.5, 0.4, r * 1.5), 4.5)
	local flames = emitter(patch, { Enabled = true, Texture = TEX.Flame, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 40, Size = ns(0, 1.8, 1, 0.3), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(2, 4), Accel = Vector3.new(0, 6, 0), RotSpeed = NumberRange.new(-90, 90), Color = PLASMA_FIRE, Light = 0.8 })
	local embers = emitter(patch, { Enabled = true, Texture = TEX.Spark, Parallel = true, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 20, Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(3, 7), Accel = Vector3.new(0, 8, 0), Color = cs(PLASMA.Yellow, PLASMA.Red), Light = 1 })
	task.delay(2.5, function()
		flames.Enabled = false
		embers.Enabled = false
	end)
	flash(at, PLASMA.Orange, r * 4, 9, 0.5)
	shake(0.4, at)
end

-------------------------------------------------------------------------------
-- Frost Gale: a freezing breath that sweeps a cone, ice erupting in its wake.
-------------------------------------------------------------------------------

local FROST = {
	White = rgb(245, 252, 255),
	Ice = rgb(170, 225, 255),
	Blue = rgb(90, 170, 245),
	Deep = rgb(40, 90, 190),
}
-- Anime ice strip in the house 4-layer style (tools/art/anime_layer_textures.py,
-- strip("ice")): white core, pale blue body, highlights and navy ink streaks.
local ANIME_ICE_TRAIL = "rbxassetid://108063404350996"

-- An ice crystal cluster bursting out of the floor (the AI-generated mesh, or
-- a glassy wedge if it is missing). It shatters after `hold` seconds.
local function iceCrystal(at, floorY, height, hold)
	local crystal = meshTemplate("IceCrystal")
	if crystal then
		crystal.Size *= height / crystal.Size.Y
		-- Opaque, so the frost crack decals underneath don't draw through it
		-- (a see-through crystal is sorted with the decals and the cracks win).
		crystal.Transparency = 0
	else
		crystal = Instance.new("WedgePart")
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.CanQuery = false
		crystal.CanTouch = false
		crystal.CastShadow = false
		crystal.Material = Enum.Material.Glass
		crystal.Color = FROST.Ice
		crystal.Transparency = 0
		crystal.Size = Vector3.new(height * 0.5, height, height * 0.5)
	end
	local h = crystal.Size.Y
	local lean = CFrame.Angles((math.random() - 0.5) * 0.6, math.random() * math.pi * 2, (math.random() - 0.5) * 0.6)
	local base = CFrame.new(at.X, floorY, at.Z) * lean
	crystal.CFrame = base * CFrame.new(0, -h / 2, 0)
	crystal.Parent = folder
	tween(crystal, 0.14, { CFrame = base * CFrame.new(0, h / 2 - 0.25, 0) }, Enum.EasingStyle.Back)
	burst(Vector3.new(at.X, floorY + 0.5, at.Z), {
		{ Texture = TEX.Sparkles, Count = 4, Size = ns(0, 0.8, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(3, 6), Spread = Vector2.new(60, 60), Color = cs(FROST.White, FROST.Ice), Light = 1 },
	}, 1)
	task.delay(hold, function()
		if crystal.Parent then
			burst(crystal.Position, {
				{ Texture = TEX.Shard, Count = 10, Size = ns(0, 0.7, 1, 0.1), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(8, 16), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -35, 0), RotSpeed = NumberRange.new(-400, 400), Drag = 1, Color = cs(FROST.White, FROST.Ice), Light = 0.5 },
				-- Black ink shards in with the ice.
				{ Texture = TEX.Shard, Count = 5, Light = 0, Size = ns(0, 0.8, 1, 0.1), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(8, 14), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -35, 0), RotSpeed = NumberRange.new(-400, 400), Drag = 1, Color = cs(Color3.new(0, 0, 0)) },
			}, 1)
			tween(crystal, 0.25, { Transparency = 1, Size = crystal.Size * 0.6, CFrame = base * CFrame.new(0, h * 0.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	Debris:AddItem(crystal, hold + 0.4)
end

local function onCone(e)
	local floorY = e.Floor or e.From.Y - 2.9
	local dir = e.Dir
	local half = math.rad(e.Angle / 2)
	local windup = e.Windup or 0
	local mouth = e.From + dir * 2 + Vector3.new(0, 0.6, 0)
	local startPos = Vector3.new(e.From.X, floorY, e.From.Z)

	-- Gather: frost converges on the hands and a cold ring closes in at the feet.
	local gather = anchor(CFrame.lookAt(mouth, mouth + dir), Vector3.new(4, 4, 4), windup + 1.5)
	local gathering = {
		emitter(gather, { Enabled = true, Texture = TEX.Sparkles, Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface, InOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 120, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.15, 0.2), Speed = NumberRange.new(12, 16), Color = cs(FROST.White, FROST.Ice), Light = 1 }),
		emitter(gather, { Enabled = true, Texture = TEX.Glow, Rate = 30, Size = ns(0, 2.2, 1, 0), Lifetime = NumberRange.new(0.15), Color = cs(FROST.White, FROST.Blue), Light = 1 }),
	}
	ring(startPos, FROST.Ice, 10, 2, windup + 0.05, floorY)
	flash(mouth, FROST.Ice, 10, 3, windup + 0.2)

	task.delay(windup, function()
		for _, em in gathering do
			em.Enabled = false
		end
		local speed = e.Length / e.Sweep
		-- The breath: five nozzles fanned across the cone, each pouring out mist,
		-- wind, snow, ice shards and white streaks.
		local look = CFrame.lookAt(mouth, mouth + dir)
		local breath = {}
		for i = 0, 4 do
			local nozzle = anchor(look * CFrame.Angles(0, -half * 0.85 + i / 4 * half * 1.7, 0), Vector3.new(1, 1, 1), e.Sweep + 2)
			local function add(s)
				s.Enabled = true
				s.Dir = Enum.NormalId.Front
				table.insert(breath, emitter(nozzle, s))
			end
			add({ Texture = TEX.Smoke, Rate = 22, Light = 0.3, Size = ns(0, 1.5, 1, 6), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(e.Sweep * 0.9, e.Sweep * 1.1), Speed = NumberRange.new(speed * 0.85, speed * 1.05), Spread = Vector2.new(10, 10), RotSpeed = NumberRange.new(-60, 60), Color = cs(FROST.White, FROST.Ice) })
			add({ Texture = TEX.Swirl, Rate = 8, Size = ns(0, 2, 1, 4), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(e.Sweep * 0.8, e.Sweep), Speed = NumberRange.new(speed * 0.8, speed), Spread = Vector2.new(10, 10), RotSpeed = NumberRange.new(-200, 200), Color = cs(FROST.Ice), Light = 0.8 })
			add({ Texture = TEX.Sparkles, Rate = 30, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(e.Sweep * 0.8, e.Sweep * 1.1), Speed = NumberRange.new(speed * 0.7, speed * 1.1), Spread = Vector2.new(12, 12), Color = cs(FROST.White, FROST.Ice), Light = 1 })
			add({ Texture = TEX.Shard, Rate = 14, Size = ns(0, 0.8, 1, 0.3), Lifetime = NumberRange.new(e.Sweep * 0.8, e.Sweep), Speed = NumberRange.new(speed * 0.9, speed * 1.1), Spread = Vector2.new(8, 8), RotSpeed = NumberRange.new(-300, 300), Color = cs(FROST.White, FROST.Blue), Light = 0.6 })
			add({ Texture = TEX.Spark, Parallel = true, Rate = 18, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.25, 0.32), Speed = NumberRange.new(speed * 1.2, speed * 1.4), Spread = Vector2.new(6, 6), Color = cs(FROST.White), Light = 1 })
			-- Black ink shade: dark shards and ink streaks riding the gale.
			add({ Texture = TEX.Shard, Rate = 6, Light = 0, Size = ns(0, 0.9, 1, 0.3), Lifetime = NumberRange.new(e.Sweep * 0.7, e.Sweep * 0.9), Speed = NumberRange.new(speed * 0.9, speed * 1.1), Spread = Vector2.new(8, 8), RotSpeed = NumberRange.new(-300, 300), Color = cs(Color3.new(0, 0, 0)) })
			add({ Texture = TEX.Spark, Parallel = true, Rate = 8, Light = 0, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.25, 0.32), Speed = NumberRange.new(speed * 1.1, speed * 1.3), Spread = Vector2.new(8, 8), Color = cs(Color3.new(0, 0, 0)) })
		end
		-- Anime ice ribbons whipping down the cone, each with a navy ink twin.
		local ribbons = {}
		for i = 1, 6 do
			local p = anchor(CFrame.new(mouth), Vector3.new(0.2, 0.2, 0.2), e.Sweep + 1.5)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			local width = if i % 3 == 0 then 0.9 else 1.8
			a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
			a0.Parent, a1.Parent = p, p
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Texture = ANIME_ICE_TRAIL
			trail.TextureMode = Enum.TextureMode.Wrap
			trail.TextureLength = 7
			trail.Lifetime = 0.4
			trail.MinLength = 0.05
			-- Every third ribbon is a thin ink streak (the strip tinted black).
			trail.Color = cs(if i % 3 == 0 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1))
			trail.Transparency = ns(0, 0, 0.6, 0.3, 1, 1)
			trail.WidthScale = ns(0, 1, 1, 0.3)
			trail.LightEmission = if i % 3 == 0 then 0 else 0.4
			trail.LightInfluence = 0
			trail.FaceCamera = true
			trail.Parent = p
			table.insert(ribbons, { Part = p, Angle = (math.random() * 2 - 1) * half * 0.8, Phase = math.random() * 6, Delay = (i - 1) * 0.06 })
		end
		local rStart = os.clock()
		local rConn
		rConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - rStart
			if t > e.Sweep + 0.4 then
				rConn:Disconnect()
				return
			end
			for _, rb in ribbons do
				local k = math.clamp((t - rb.Delay) / (e.Sweep * 0.9), 0, 1)
				local d = 2 + (e.Length - 2) * (1 - (1 - k) ^ 1.6)
				local wobble = math.sin(t * 9 + rb.Phase) * (0.6 + d * 0.06)
				local heading = CFrame.Angles(0, rb.Angle, 0) * dir
				local sideV = heading:Cross(Vector3.yAxis)
				local y = 1.2 + math.sin(t * 6 + rb.Phase) * 0.8
				rb.Part.CFrame = CFrame.new(startPos + heading * d + sideV * wobble + Vector3.new(0, y, 0))
			end
		end)
		-- Release: a frost shockwave bursts from the hands.
		burst(mouth, {
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 1, 1, 9), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(FROST.White, FROST.Ice), Light = 1, ZOffset = 1 },
			{ Texture = TEX.Shard, Count = 14, Size = ns(0, 0.9, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(16, 26), Spread = Vector2.new(40, 40), RotSpeed = NumberRange.new(-400, 400), Color = cs(FROST.White, FROST.Ice), Light = 0.6 },
		}, 1)
		ring(startPos, FROST.White, 2, 12, 0.35, floorY)
		task.delay(e.Sweep, function()
			for _, em in breath do
				em.Enabled = false
			end
		end)

		-- The ground freezes as the breath passes, and ice crystals burst up.
		local rows = 6
		for i = 1, rows do
			local d = e.Length * i / rows
			local width = 2 * d * math.tan(half)
			task.delay(e.Sweep * i / rows, function()
				local mid = startPos + dir * d
				groundDecal(mid, TEX.Crack, FROST.Ice, 2, math.max(width * 0.8, 4), 2.6, { Floor = floorY, Hold = 1.8, GrowTime = 0.15, StartAlpha = 0.15 })
				-- Black ink cracks running through the frost.
				groundDecal(mid, TEX.Crack, Color3.new(0, 0, 0), 2, math.max(width * 0.6, 3), 2.6, { Floor = floorY, Lift = 0.03, Hold = 1.8, GrowTime = 0.15, StartAlpha = 0.3 })
				groundDecal(mid, TEX.Glow, FROST.Blue, width * 0.6, math.max(width, 4), 2.6, { Floor = floorY, Lift = 0.02, Hold = 1.8, GrowTime = 0.2, StartAlpha = 0.55 })
				for _ = 1, 1 + math.floor(width / 7) do
					local ang = (math.random() * 2 - 1) * half * 0.9
					local spot = startPos + (CFrame.Angles(0, ang, 0) * dir) * d * (0.9 + math.random() * 0.15)
					local height = 2.2 + (d / e.Length) * 2.5 + math.random() * 1.2
					-- All crystals shatter together, about a second after the breath ends.
					iceCrystal(spot, floorY, height, (e.Sweep - e.Sweep * i / rows) + 1 + math.random() * 0.3)
				end
			end)
		end

		-- Frost cloud rolling off the far edge.
		task.delay(e.Sweep, function()
			burst(startPos + dir * e.Length + Vector3.new(0, 1.5, 0), {
				{ Texture = TEX.Smoke, Count = 8, Light = 0.3, Size = ns(0, 3, 1, 8), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(3, 6), Spread = Vector2.new(180, 40), Color = cs(FROST.White, FROST.Ice) },
				{ Texture = TEX.Sparkles, Count = 16, Size = ns(0, 0.8, 1, 0), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(4, 9), Spread = Vector2.new(180, 180), Color = cs(FROST.White, FROST.Ice), Light = 1 },
			}, 2)
		end)
		flash(mouth + dir * 4, FROST.Ice, e.Length, 5, e.Sweep + 0.3)
		shake(0.18, startPos)
	end)
end

-------------------------------------------------------------------------------
-- Mudslide: a giant mud boulder rolling forward.
-------------------------------------------------------------------------------

local MUD = {
	Light = rgb(150, 110, 70),
	Main = rgb(96, 66, 42),
	Dark = rgb(52, 34, 22),
	Water = rgb(120, 150, 170),
}
local rollers = {} -- [Skill .. From] = { Stop = function(at) }
-- Anime water strip in the house 4-layer style (tools/art/anime_layer_textures.py,
-- strip("water")): core, body, white highlights and dark ink streaks.
local ANIME_WATER_TRAIL = "rbxassetid://97688629579971"

-- A Trail between two attachment positions on `parent`, textured with the
-- anime water strip. Starts disabled; the caller turns it on.
local function waterTrail(parent, p0, p1, life, opts)
	opts = opts or {}
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = p0, p1
	a0.Parent, a1.Parent = parent, parent
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Texture = ANIME_WATER_TRAIL
	t.TextureMode = Enum.TextureMode.Wrap
	t.TextureLength = opts.Length or 9
	t.Lifetime = life
	t.MinLength = 0.05
	t.Color = cs(Color3.new(1, 1, 1))
	t.Transparency = opts.Transparency or ns(0, 0, 0.6, 0.25, 1, 1)
	t.WidthScale = opts.WidthScale or ns(0, 1, 1, 0.35)
	t.LightEmission = opts.Light or 0.25
	t.LightInfluence = 0
	t.FaceCamera = opts.FaceCamera == true
	t.Enabled = false
	t.Parent = parent
	return t
end

-- The real floor height under a point (the server's estimate comes from the
-- caster's hip height, which can be a little off for scaled avatars).
local function floorAt(pos, fallback)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	local enemies = workspace:FindFirstChild("RiftEnemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
	return if result then result.Position.Y else fallback
end

local function onRoller(e)
	local floorY = floorAt(e.From + e.Dir * 3, e.Floor or e.From.Y - 2.9)
	local dir = e.Dir
	local side = dir:Cross(Vector3.yAxis)
	local diameter = e.Radius * 1.2
	local start = Vector3.new(e.From.X, floorY, e.From.Z) + dir * 3
	local boulder = meshTemplate("MudBoulder")
	if not boulder then
		boulder = Instance.new("Part")
		boulder.Shape = Enum.PartType.Ball
		boulder.Material = Enum.Material.Mud
		boulder.Color = MUD.Main
		boulder.Anchored = true
		boulder.CanCollide = false
		boulder.CanQuery = false
		boulder.CanTouch = false
	end
	boulder.Size = Vector3.one * diameter
	local r = diameter / 2
	-- Windup: the boulder heaves up out of the ground in front of you.
	boulder.CFrame = CFrame.new(start + Vector3.new(0, -r, 0))
	boulder.Parent = folder
	tween(boulder, e.Windup or 0.3, { CFrame = CFrame.new(start + Vector3.new(0, r, 0)) }, Enum.EasingStyle.Back)
	burst(start + Vector3.new(0, 0.5, 0), {
		{ Texture = TEX.Drop, Count = 20, Light = 0, Size = ns(0, 0.7, 1, 0.3), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(8, 16), Spread = Vector2.new(50, 50), Accel = Vector3.new(0, -45, 0), Color = cs(MUD.Light, MUD.Main) },
		{ Texture = TEX.Dust, Count = 4, Light = 0, Size = ns(0, 3, 1, 6), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(2, 4), Spread = Vector2.new(180, 20), Color = cs(MUD.Light) },
	}, 1.5)
	debrisBurst(start + Vector3.new(0, 0.5, 0), MUD.Dark, 6, { Material = Enum.Material.Mud, Size = 0.7, Height = 3, Reach = 5, Floor = floorY })

	-- Mud flung off the boulder while it rolls.
	local spray = anchor(CFrame.new(start), Vector3.new(diameter, 1, diameter), nil)
	local emitters = {
		emitter(spray, { Texture = TEX.Drop, Shape = Enum.ParticleEmitterShape.Box, Rate = 70, Light = 0, Size = ns(0, 0.6, 1, 0.25), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(6, 12), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -45, 0), Color = cs(MUD.Light, MUD.Main) }),
		emitter(spray, { Texture = TEX.Dust, Rate = 14, Light = 0, Size = ns(0, 2.5, 1, 5), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 3), Spread = Vector2.new(180, 20), Color = cs(MUD.Light) }),
		emitter(spray, { Texture = TEX.Rocks, Rate = 10, Light = 0, Size = ns(0, 0.9, 1, 0.6), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(8, 14), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -50, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(MUD.Light) }),
		-- Black ink shade: black mud splatter flung with the brown.
		emitter(spray, { Texture = TEX.Drop, Shape = Enum.ParticleEmitterShape.Box, Rate = 30, Light = 0, Size = ns(0, 0.7, 1, 0.3), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(7, 13), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -45, 0), Color = cs(Color3.new(0, 0, 0)) }),
		-- Muddy water spraying off the sides, catching the light.
		emitter(spray, { Texture = TEX.Drop, Shape = Enum.ParticleEmitterShape.Box, Rate = 40, Size = ns(0, 0.5, 1, 0.15), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 16), Spread = Vector2.new(80, 80), Accel = Vector3.new(0, -40, 0), Color = cs(Color3.new(1, 1, 1), MUD.Water), Light = 0.4 }),
	}
	-- A dark ink track pressed into the ground behind the boulder.
	local track0, track1 = Instance.new("Attachment"), Instance.new("Attachment")
	track0.Position, track1.Position = side * (diameter * 0.45) - Vector3.new(0, 0.4, 0), -side * (diameter * 0.45) - Vector3.new(0, 0.4, 0)
	track0.Parent, track1.Parent = spray, spray
	local track = Instance.new("Trail")
	track.Attachment0, track.Attachment1 = track0, track1
	track.Lifetime = 1.4
	-- The anime strip tinted black gives the track ragged ink edges.
	track.Texture = ANIME_WATER_TRAIL
	track.TextureMode = Enum.TextureMode.Wrap
	track.TextureLength = 12
	track.Color = cs(Color3.new(0, 0, 0))
	track.Transparency = ns(0, 0.3, 0.7, 0.55, 1, 1)
	track.LightEmission = 0
	track.LightInfluence = 0
	track.FaceCamera = false
	track.Enabled = false
	track.Parent = spray
	table.insert(emitters, track)
	-- Anime water wake: a wall of water peeling off each side, a sheet of water
	-- sliding along the ground behind, and a ribbon wrapped round the boulder
	-- that loops as it rolls.
	for _, s in { 1, -1 } do
		table.insert(emitters, waterTrail(spray, side * s * r * 1.05 + Vector3.new(0, -0.2, 0), side * s * r * 1.25 + Vector3.new(0, 2.6, 0), 0.55))
	end
	table.insert(emitters, waterTrail(spray, side * r * 1.35 - Vector3.new(0, 0.35, 0), -side * r * 1.35 - Vector3.new(0, 0.35, 0), 0.8, { Length = 14, Transparency = ns(0, 0.15, 0.6, 0.45, 1, 1), WidthScale = ns(0, 1, 1, 0.6) }))
	table.insert(emitters, waterTrail(boulder, Vector3.new(0, r * 1.05, 0) + side * 0.9, Vector3.new(0, r * 1.05, 0) - side * 0.9, 0.35, { Length = 6, Light = 0.4 }))

	local key = e.Skill .. tostring(e.From)
	local conn
	local stopped = false
	local function stop(at)
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		rollers[key] = nil
		for _, em in emitters do
			em.Enabled = false
		end
		Debris:AddItem(spray, 1.5)
		-- The boulder bursts into a wave of mud.
		local p = at or boulder.Position
		local ground = Vector3.new(p.X, floorY, p.Z)
		playTemplate("Splash-01", CFrame.new(ground + Vector3.new(0, 1, 0)), { Scale = 1.4, Color = cs(MUD.Light, MUD.Main) })
		burst(ground + Vector3.new(0, 1.5, 0), {
			{ Texture = TEX.Splash, Count = 3, Light = 0, Size = ns(0, 5, 1, 8), Lifetime = NumberRange.new(0.45), Color = cs(MUD.Light, MUD.Main) },
			{ Texture = TEX.Drop, Count = 40, Light = 0, Size = ns(0, 0.9, 1, 0.3), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(14, 26), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -50, 0), Color = cs(MUD.Light, MUD.Dark) },
			{ Texture = TEX.Dust, Count = 6, Light = 0, Size = ns(0, 4, 1, 9), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(3, 6), Spread = Vector2.new(180, 20), Color = cs(MUD.Light) },
		}, 2)
		debrisBurst(ground + Vector3.new(0, 1, 0), MUD.Main, 12, { Material = Enum.Material.Mud, Size = 0.9, Height = 5, Reach = 8, Floor = floorY })
		-- Black ink shade: a black splash and ink clods thrown with the mud.
		burst(ground + Vector3.new(0, 1.2, 0), {
			{ Texture = TEX.Splash, Count = 2, Light = 0, Size = ns(0, 4, 1, 7), Lifetime = NumberRange.new(0.4), Color = cs(Color3.new(0, 0, 0), MUD.Dark), ZOffset = -1 },
			{ Texture = TEX.Drop, Count = 24, Light = 0, Size = ns(0, 1, 1, 0.3), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(16, 28), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -50, 0), Color = cs(Color3.new(0, 0, 0)) },
			{ Texture = TEX.Drop, Count = 20, Size = ns(0, 0.6, 1, 0.2), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(18, 30), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -50, 0), Color = cs(Color3.new(1, 1, 1), MUD.Water), Light = 0.4 },
		}, 2)
		debrisBurst(ground + Vector3.new(0, 1, 0), Color3.new(0.06, 0.04, 0.03), 6, { Material = Enum.Material.Mud, Size = 0.7, Height = 6, Reach = 9, Floor = floorY })
		-- A mud wave rolls out across the ground with a black rim.
		ring(ground, MUD.Light, 2, diameter * 3, 0.45, floorY)
		task.delay(0.05, function()
			ring(ground, MUD.Dark, 2, diameter * 2.5, 0.5, floorY)
		end)
		groundDecal(ground, TEX.Ring, Color3.new(0, 0, 0), diameter * 0.8, diameter * 2.6, 0.7, { Floor = floorY, Lift = 0.03, StartAlpha = 0.15, GrowTime = 0.35 })
		-- A glossy puddle that bubbles for a moment.
		groundDecal(ground, TEX.Glow, MUD.Water, diameter * 1.4, diameter * 1.8, 3, { Floor = floorY, Lift = 0.02, Hold = 2, StartAlpha = 0.55 })
		local puddle = anchor(CFrame.new(ground + Vector3.new(0, 0.2, 0)), Vector3.new(diameter * 1.4, 0.2, diameter * 1.4), 3.5)
		local bubbles = emitter(puddle, { Enabled = true, Texture = TEX.Glow, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 16, Size = ns(0, 0.2, 0.8, 0.9, 1, 0), Transparency = ns(0, 0.3, 1, 0.5), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.2, 0.6), Color = cs(MUD.Light, MUD.Main), Light = 0 })
		task.delay(2.2, function()
			bubbles.Enabled = false
		end)
		groundDecal(ground, TEX.Glow, MUD.Main, 4, diameter * 2.4, 3, { Floor = floorY, Hold = 2, GrowTime = 0.15, StartAlpha = 0.1 })
		tween(boulder, 0.2, { Size = boulder.Size * Vector3.new(1.5, 0.3, 1.5), Transparency = 1 })
		Debris:AddItem(boulder, 0.3)
		shake(0.3, ground)
	end
	rollers[key] = { Stop = stop }

	task.delay(e.Windup or 0, function()
		if stopped then
			return
		end
		for _, em in emitters do
			em.Enabled = true
		end
		local t0 = os.clock()
		local lastMark, lastWave = 0, 0
		conn = RunService.RenderStepped:Connect(function()
			local d = math.min((os.clock() - t0) * e.Speed, e.Length + 2)
			local center = start + dir * d + Vector3.new(0, r, 0)
			-- Roll: spin about the side axis by distance / radius.
			boulder.CFrame = CFrame.new(center) * CFrame.fromAxisAngle(side, -d / r)
			spray.CFrame = CFrame.new(center - Vector3.new(0, r - 0.5, 0))
			-- Bow wave: mud and black splashes peeling off both sides.
			if d - lastWave > 2 then
				lastWave = d
				for _, s in { 1, -1 } do
					local at = Vector3.new(center.X, floorY + 0.6, center.Z) + side * s * r * 0.9
					burst(at, {
						{ Texture = TEX.Splash, Count = 1, Light = 0, Size = ns(0, 2.5, 1, 4.5), Lifetime = NumberRange.new(0.35), Color = cs(MUD.Light, MUD.Main) },
						{ Texture = TEX.Drop, Count = 6, Light = 0, Size = ns(0, 0.6, 1, 0.2), Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(8, 12), Spread = Vector2.new(40, 40), Accel = Vector3.new(0, -45, 0), Color = cs(Color3.new(0, 0, 0), MUD.Dark) },
					}, 1)
				end
			end
			-- Slick mud trail.
			if d - lastMark > 3 then
				lastMark = d
				groundDecal(Vector3.new(center.X, floorY, center.Z), TEX.Glow, MUD.Dark, diameter * 0.8, diameter * 1.1, 2.5, { Floor = floorY, Hold = 1.6, GrowTime = 0.1, StartAlpha = 0.25 })
			end
		end)
		-- Safety: finish even if the end event is lost.
		task.delay(e.Length / e.Speed + 1, function()
			stop()
		end)
	end)
	shake(0.12, start)
end

local function onRollerEnd(e)
	for key, roller in rollers do
		if key:sub(1, #e.Skill) == e.Skill then
			roller.Stop(e.At)
		end
	end
end

-------------------------------------------------------------------------------
-- Magma Meteor: a molten rock falls from the sky and leaves a lava pool.
-------------------------------------------------------------------------------

local LAVA = {
	White = rgb(255, 240, 190),
	Glow = rgb(255, 150, 40),
	Main = rgb(255, 90, 20),
	Dark = rgb(150, 30, 10),
	Crust = rgb(40, 20, 15),
	Smoke = rgb(70, 55, 50),
}
local LAVA_FIRE = cs(LAVA.White, LAVA.Glow, LAVA.Main, LAVA.Dark)

-- Blender-made lava pool (art/skill_models/lavapool): a splashy molten pool
-- with a raised crust rim, floating crust plates and a black ink outline
-- (LavaPool / LavaRim / LavaPlates / LavaInk in the Model
-- RiftboundVFX.LavaPoolModel). The molten part is 8 studs in radius. Each
-- part's "Offset" attribute is its centre relative to the pool centre on the floor.
local LAVA_POOL_PARTS = { "LavaPool", "LavaRim", "LavaPlates", "LavaInk" }

-- Spreads the pool out at `center` on floorY with a molten radius of pr, keeps
-- the plates drifting for `life` seconds, then sinks and fades it. Returns
-- false when the templates are missing.
local function lavaPoolModel(center, floorY, pr, life)
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local model = templates and templates:FindFirstChild("LavaPoolModel")
	if not (model and model:FindFirstChild("LavaPool")) then
		return false
	end
	local pieces = {}
	for _, name in LAVA_POOL_PARTS do
		local src = model:FindFirstChild(name)
		if src then
			local p = src:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			if name == "LavaInk" then
				p.Color = Color3.new(0, 0, 0)
			end
			p.Parent = folder
			table.insert(pieces, { Part = p, Size = p.Size, Offset = p:GetAttribute("Offset") or Vector3.zero, Plates = name == "LavaPlates" })
		end
	end
	local scale = pr / 8
	local base = Vector3.new(center.X, floorY, center.Z)
	local turn = math.random() * math.pi * 2
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- Splashes out past full size and settles (back-out), then sinks away at the end.
		local k = math.min(t / 0.3, 1)
		local grow = 1 + 2.2 * (k - 1) ^ 3 + 1.2 * (k - 1) ^ 2
		local sink = math.clamp((t - life) / 0.5, 0, 1)
		local s = scale * math.max(grow, 0.05) * (1 - 0.3 * sink)
		for _, pc in pieces do
			local spin = turn + (if pc.Plates then t * 0.25 else 0)
			local bob = if pc.Plates then math.sin(t * 2.5) * 0.06 else 0
			pc.Part.Size = pc.Size * s
			pc.Part.CFrame = CFrame.new(base + Vector3.new(0, bob - sink * 0.4, 0)) * CFrame.Angles(0, spin, 0) * CFrame.new(pc.Offset * s)
			pc.Part.Transparency = sink
		end
		if sink >= 1 then
			conn:Disconnect()
			for _, pc in pieces do
				pc.Part:Destroy()
			end
		end
	end)
	return true
end

local function onMeteor(e)
	local floorY = floorAt(e.At, e.At.Y)
	local center = Vector3.new(e.At.X, floorY, e.At.Z)
	local r = e.Radius
	local T = e.Delay
	local ground = Vector3.new(center.X, floorY, center.Z)

	-- Telegraph: a burning rune closing in on the landing spot.
	groundDecal(ground, TEX.Telegraph, LAVA.Main, r * 2.4, r * 2, T + 0.05, { Floor = floorY, Spin = math.pi, StartAlpha = 0.15, GrowTime = T })
	groundDecal(ground, TEX.Glow, LAVA.Glow, r * 0.5, r * 2, T, { Floor = floorY, Lift = 0.01, StartAlpha = 0.5, GrowTime = T, Style = Enum.EasingStyle.Quad })

	-- The meteor: comes in at a steep angle from behind the caster.
	local back = if e.Dir then -e.Dir else Vector3.new(1, 0, 0)
	local from = ground + back * 22 + Vector3.new(0, 55, 0)
	local rock = meshTemplate("MagmaRock")
	if not rock then
		rock = Instance.new("Part")
		rock.Shape = Enum.PartType.Ball
		rock.Material = Enum.Material.CrackedLava
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
	end
	rock.Size = Vector3.one * 5.5
	rock.CFrame = CFrame.new(from)
	rock.Parent = folder
	local trailEmitters = {
		emitter(rock, { Enabled = true, Texture = TEX.Flame, Rate = 120, Size = ns(0, 6, 1, 1.5), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(2, 5), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-120, 120), Color = LAVA_FIRE, Light = 0.9 }),
		emitter(rock, { Enabled = true, Texture = TEX.Smoke, Rate = 40, Light = 0, Size = ns(0, 3, 1, 8), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(1, 3), Spread = Vector2.new(180, 180), Color = cs(LAVA.Smoke) }),
		emitter(rock, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 60, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(6, 14), Spread = Vector2.new(180, 180), Color = cs(LAVA.White, LAVA.Main), Light = 1 }),
		-- Black ink shade: a tight black smoke streak trailing the rock.
		emitter(rock, { Enabled = true, Texture = TEX.Smoke, Rate = 50, Light = 0, Size = ns(0, 3.5, 1, 1), Transparency = ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0.5, 1.5), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-90, 90), Color = cs(Color3.new(0, 0, 0)), ZOffset = -1 }),
	}
	-- A fiery comet tail behind the rock.
	do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 2.2, 0), Vector3.new(0, -2.2, 0)
		a0.Parent, a1.Parent = rock, rock
		local tail = Instance.new("Trail")
		tail.Attachment0, tail.Attachment1 = a0, a1
		tail.Lifetime = 0.3
		tail.Color = cs(LAVA.White, LAVA.Glow, LAVA.Main)
		tail.Transparency = ns(0, 0, 0.6, 0.4, 1, 1)
		tail.WidthScale = ns(0, 1, 1, 0.2)
		tail.LightEmission = 1
		tail.LightInfluence = 0
		tail.FaceCamera = true
		tail.Texture = TEX.Glow
		tail.TextureMode = Enum.TextureMode.Stretch
		tail.Parent = rock
		table.insert(trailEmitters, tail)
	end
	local light = Instance.new("PointLight")
	light.Color = LAVA.Glow
	light.Range = 30
	light.Brightness = 3
	light.Shadows = false
	light.Parent = rock
	local spin = CFrame.Angles(math.random() * 6, math.random() * 6, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min((os.clock() - t0) / T, 1)
		local pos = from:Lerp(center + Vector3.new(0, 1.5, 0), k * k)
		rock.CFrame = CFrame.new(pos) * spin * CFrame.Angles(k * 8, k * 5, 0)
		if k >= 1 then
			conn:Disconnect()
		end
	end)

	task.delay(T, function()
		for _, em in trailEmitters do
			em.Enabled = false
		end
		-- Impact.
		playTemplate("Realistic-Explosion-01", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.3 })
		playTemplate("Fire-03", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.4, Color = LAVA_FIRE })
		playTemplate("Crack-01", CFrame.new(center + Vector3.new(0, 0.5, 0)), { Scale = r / 7 })
		burst(center + Vector3.new(0, 1, 0), {
			{ Texture = TEX.Glow, Count = 1, Size = ns(0, 4, 0.25, r * 2, 1, r * 2.3), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(LAVA.White, LAVA.Glow), Light = 1 },
			{ Texture = TEX.FireBurst, Count = 4, Size = ns(0, r * 1.2, 1, r * 1.6), Transparency = ns(0, 0, 1, 0.4), Lifetime = NumberRange.new(0.5, 0.6), Spread = Vector2.new(40, 40), Speed = NumberRange.new(1, 3), Color = LAVA_FIRE, Light = 0.85 },
			{ Texture = TEX.Flame, Count = 30, Size = ns(0, 4, 1, 1.2), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(14, 28), Spread = Vector2.new(180, 70), Drag = 4, Accel = Vector3.new(0, 10, 0), RotSpeed = NumberRange.new(-150, 150), Color = LAVA_FIRE, Light = 0.9 },
			{ Texture = TEX.Rocks, Count = 16, Light = 0, Size = ns(0, 1.4, 1, 1), Transparency = ns(0, 0, 0.8, 0, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(18, 32), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(rgb(255, 170, 120)) },
			{ Texture = TEX.Smoke, Count = 10, Light = 0, Size = ns(0, 4, 1, 9), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(5, 10), Spread = Vector2.new(180, 40), Drag = 2, Accel = Vector3.new(0, 4, 0), Color = cs(LAVA.Smoke) },
			-- Black ink shade: ink shards and a black smoke column.
			{ Texture = TEX.Spark, Count = 18, Parallel = true, Light = 0, Size = ns(0, 1.2, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(20, 34), Spread = Vector2.new(180, 60), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
			{ Texture = TEX.Smoke, Count = 6, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.7, 1), Speed = NumberRange.new(10, 16), Spread = Vector2.new(15, 15), Drag = 2, Color = cs(Color3.new(0, 0, 0)), ZOffset = -1 },
			-- Heat shockwave, an ember fountain and splashing lava drops.
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, r * 0.5, 1, r * 3), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.35), Color = cs(LAVA.White, LAVA.Glow), Light = 1, ZOffset = 2 },
			{ Texture = TEX.Spark, Count = 40, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(20, 38), Spread = Vector2.new(30, 30), Accel = Vector3.new(0, -30, 0), Color = cs(LAVA.White, LAVA.Glow, LAVA.Main), Light = 1 },
			{ Texture = TEX.Drop, Count = 20, Size = ns(0, 0.9, 1, 0.4), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(14, 24), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -50, 0), Color = cs(LAVA.Glow, LAVA.Main), Light = 1 },
		}, 2.5)
		groundDecal(center, TEX.Ring, Color3.new(0, 0, 0), r * 1.6, r * 2.5, 1, { Floor = floorY, Lift = 0.03, StartAlpha = 0.1, GrowTime = 0.25 })
		debrisBurst(center + Vector3.new(0, 0.5, 0), LAVA.Main, 12, { Material = Enum.Material.Neon, Size = 0.7, Height = 6, Reach = r, Floor = floorY })
		debrisBurst(center + Vector3.new(0, 0.5, 0), LAVA.Crust, 8, { Material = Enum.Material.Basalt, Size = 1, Height = 5, Reach = r * 0.8, Floor = floorY })
		ring(center, LAVA.White, 2, r * 2.8, 0.35, floorY)
		task.delay(0.07, function()
			ring(center, LAVA.Main, 2, r * 2.2, 0.45, floorY)
		end)
		flash(center + Vector3.new(0, 3, 0), LAVA.Glow, r * 4, 10, 0.6)
		shake(0.6, center)

		-- The rock stays half-buried in the crater, glowing as it cools.
		rock.CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0)) * spin
		light.Range = 18

		-- Lava pool.
		local pr = e.PoolRadius or r
		local life = (e.Duration or 3)
		local pool, crust
		if not lavaPoolModel(center, floorY, pr, life) then
			pool = Instance.new("Part")
			pool.Shape = Enum.PartType.Cylinder
			pool.Material = Enum.Material.Neon
			pool.Color = LAVA.Dark
			pool.Transparency = 0.1
			pool.Anchored = true
			pool.CanCollide = false
			pool.CanQuery = false
			pool.CanTouch = false
			pool.CastShadow = false
			local flat = CFrame.new(center.X, floorY + 0.05, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
			pool.Size = Vector3.new(0.2, 1, 1)
			pool.CFrame = flat
			pool.Parent = folder
			tween(pool, 0.25, { Size = Vector3.new(0.2, pr * 2, pr * 2) }, Enum.EasingStyle.Back)
			crust = pool:Clone()
			crust.Material = Enum.Material.CrackedLava
			crust.Color = LAVA.Glow
			crust.Transparency = 0
			crust.CFrame = flat * CFrame.new(0.04, 0, 0)
			crust.Parent = folder
			tween(crust, 0.25, { Size = Vector3.new(0.2, pr * 1.4, pr * 1.4) }, Enum.EasingStyle.Back)
		end
		groundDecal(center, TEX.Crack, LAVA.Crust, pr * 2.2, pr * 2.4, life + 1, { Floor = floorY, Hold = life, GrowTime = 0.15, StartAlpha = 0 })
		groundDecal(center, TEX.Glow, LAVA.Glow, pr * 2.6, pr * 2.6, life + 0.5, { Floor = floorY, Lift = 0.02, Hold = life - 0.3, StartAlpha = 0.3, FadeIn = 0.2 })
		local area = anchor(CFrame.new(center.X, floorY + 0.3, center.Z), Vector3.new(pr * 1.7, 0.3, pr * 1.7), life + 2)
		local poolEmitters = {
			-- Flames licking up from the surface.
			emitter(area, { Enabled = true, Texture = TEX.Flame, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 45, Size = ns(0, 2.2, 1, 0.4), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(2, 5), Accel = Vector3.new(0, 6, 0), RotSpeed = NumberRange.new(-90, 90), Color = LAVA_FIRE, Light = 0.8 }),
			-- Bubbles swelling and popping.
			emitter(area, { Enabled = true, Texture = TEX.Glow, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 20, Size = ns(0, 0.2, 0.8, 1.3, 1, 0), Transparency = ns(0, 0.1, 1, 0.4), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.2, 0.6), Color = cs(LAVA.White, LAVA.Glow), Light = 1 }),
			emitter(area, { Enabled = true, Texture = TEX.Spark, Parallel = true, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 25, Size = ns(0, 0.35, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(4, 9), Accel = Vector3.new(0, 6, 0), Color = cs(LAVA.White, LAVA.Main), Light = 1 }),
			emitter(area, { Enabled = true, Texture = TEX.Smoke, Shape = Enum.ParticleEmitterShape.Cylinder, Rate = 8, Light = 0, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.6, 1, 1), Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(1, 3), Accel = Vector3.new(0, 3, 0), Color = cs(LAVA.Smoke) }),
		}
		-- Pulsing glow, then the lava cools and sinks away.
		if pool then
			local p0 = os.clock()
			local pulse
			pulse = RunService.RenderStepped:Connect(function()
				local t = os.clock() - p0
				if t > life or not pool.Parent then
					pulse:Disconnect()
					return
				end
				pool.Color = LAVA.Dark:Lerp(LAVA.Main, 0.55 + 0.45 * math.sin(t * 6))
			end)
		end
		-- Lava bubbles burst across the pool, each with a black ink puff.
		task.spawn(function()
			local t = 0
			while t < life - 0.3 and (not pool or pool.Parent) do
				local angle = math.random() * math.pi * 2
				local at = Vector3.new(center.X, floorY + 0.4, center.Z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * pr * math.random() * 0.75
				burst(at, {
					{ Texture = TEX.Glow, Count = 1, Size = ns(0, 0.8, 0.7, 2.4, 1, 0), Transparency = ns(0, 0, 1, 0.3), Lifetime = NumberRange.new(0.25), Color = cs(LAVA.White, LAVA.Glow), Light = 1 },
					{ Texture = TEX.Drop, Count = 6, Size = ns(0, 0.5, 1, 0.2), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(6, 10), Spread = Vector2.new(50, 50), Accel = Vector3.new(0, -40, 0), Color = cs(LAVA.Glow, LAVA.Main), Light = 1 },
					{ Texture = TEX.Smoke, Count = 2, Light = 0, Size = ns(0, 1, 1, 2.5), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(2, 4), Color = cs(Color3.new(0, 0, 0)) },
				}, 1)
				local wait = 0.18 + math.random() * 0.2
				task.wait(wait)
				t += wait
			end
		end)
		task.delay(life, function()
			for _, em in poolEmitters do
				em.Enabled = false
			end
			if pool then
				tween(pool, 0.5, { Size = Vector3.new(0.2, pr * 1.2, pr * 1.2), Transparency = 1, Color = LAVA.Dark })
				tween(crust, 0.5, { Transparency = 1 })
				Debris:AddItem(pool, 0.6)
				Debris:AddItem(crust, 0.6)
			end
			tween(rock, 0.6, { Transparency = 1, CFrame = rock.CFrame * CFrame.new(0, -2, 0) })
			tween(light, 0.5, { Brightness = 0 })
			Debris:AddItem(rock, 0.7)
		end)
	end)
end

-------------------------------------------------------------------------------
-- Quake Leap: launch into the air on a gust, then slam down and raise two
-- rings of stone spikes around the landing point.
-------------------------------------------------------------------------------

local STONE = {
	Light = rgb(225, 200, 160),
	Main = rgb(170, 130, 90),
	Dark = rgb(80, 58, 40),
	Wind = rgb(220, 248, 240),
}

-- A ring of `count` rock spikes at `radius`, leaning outward. Uses the painted
-- Blender spike from Stone Spike when it is there, and crumbles it into dark
-- chips with black ink shards, like Stone Spike.
local function spikeRing(center, floorY, radius, count, height, hold)
	for i = 1, count do
		local angle = i / count * math.pi * 2 + (math.random() - 0.5) * 0.25
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = Vector3.new(center.X, floorY, center.Z) + radial * radius * (0.92 + math.random() * 0.16)
		local h = height * (0.8 + math.random() * 0.4)
		local w = h * 0.45
		local painted = meshTemplate("StoneSpikeMesh")
		local spike = painted or meshTemplate("RockSpike")
		if painted then
			-- The Blender spike is tall and slim; keep it chunky.
			spike.Size = Vector3.new(w * 1.1, h * 1.15, w * 1.1)
			h = spike.Size.Y
		elseif spike then
			spike.Size = Vector3.new(w * 1.4, h, w * 1.4)
		else
			spike = Instance.new("WedgePart")
			spike.Size = Vector3.new(w, h, w)
			spike.Material = Enum.Material.Slate
			spike.Color = STONE.Main
			spike.Anchored = true
			spike.CanCollide = false
			spike.CanQuery = false
			spike.CanTouch = false
		end
		-- Facing outward with the tip tilted away from the centre.
		local base = CFrame.lookAt(spot, spot + radial) * CFrame.Angles(-0.35, 0, 0) * CFrame.Angles(0, math.random() * 6, 0)
		spike.CFrame = base * CFrame.new(0, -h / 2, 0)
		spike.Parent = folder
		local up = base * CFrame.new(0, h / 2 - 0.4, 0)
		-- Punches up with a twist and overshoots, then settles.
		spike.CFrame = base * CFrame.new(0, -h / 2, 0) * CFrame.Angles(0, -0.6, 0)
		tween(spike, 0.13, { CFrame = up * CFrame.new(0, h * 0.12, 0) })
		task.delay(0.13, function()
			if spike.Parent then
				tween(spike, 0.1, { CFrame = up }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			end
		end)
		burst(spot + Vector3.new(0, 0.5, 0), {
			{ Texture = TEX.Dust, Count = 1, Light = 0, Size = ns(0, 2, 1, 4), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(1, 3), Spread = Vector2.new(60, 60), Color = cs(STONE.Light) },
			{ Texture = TEX.Rocks, Count = 3, Light = 0, Size = ns(0, 0.8, 1, 0.5), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(8, 14), Spread = Vector2.new(50, 50), Accel = Vector3.new(0, -50, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Light) },
			-- Black ink shade: a dark puff and black shards kicked out of the ground.
			{ Texture = TEX.Smoke, Count = 1, Light = 0, Size = ns(0, 1.2, 1, 3), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(2, 4), Spread = Vector2.new(60, 60), Color = cs(Color3.new(0, 0, 0)) },
			{ Texture = TEX.Shard, Count = 3, Light = 0, Size = ns(0, 0.7, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 16), Spread = Vector2.new(45, 45), Accel = Vector3.new(0, -50, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(0, 0, 0)) },
		}, 1)
		task.delay(hold, function()
			if spike.Parent then
				-- Crumble: shudder, break into dark chips, sink.
				tween(spike, 0.06, { CFrame = up * CFrame.Angles(0.05, 0, -0.05) })
				task.delay(0.06, function()
					if spike.Parent then
						debrisBurst(spike.Position, rgb(48, 38, 32), 2, { Floor = floorY, Size = w * 0.3, Height = 2.5, Reach = 2.5, Material = Enum.Material.Basalt, Wedge = true })
						tween(spike, 0.3, { CFrame = base * CFrame.new(0, -h / 2, 0), Size = spike.Size * Vector3.new(0.7, 1, 0.7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
				end)
			end
		end)
		Debris:AddItem(spike, hold + 0.4)
	end
end

local function onLeap(e)
	local root = e.Root
	if not root or not root.Parent then
		return
	end
	-- Your own character launches here (you own its physics).
	if e.Caster == localPlayer then
		local hum = root.Parent:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, e.JumpVelocity or 80, v.Z)
	end
	local feet = root.Position - Vector3.new(0, 2.5, 0)
	local floorY = floorAt(root.Position, feet.Y)
	-- Takeoff: a gust bursts out from under your feet.
	playTemplate("Wind-02", CFrame.new(feet), { Scale = 1.2, Color = cs(STONE.Wind, STONE.Light) })
	burst(Vector3.new(feet.X, floorY + 0.5, feet.Z), {
		{ Texture = TEX.Dust, Count = 6, Light = 0, Size = ns(0, 3, 1, 6), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(8, 14), Spread = Vector2.new(180, 10), Drag = 3, Color = cs(STONE.Light) },
		{ Texture = TEX.Swirl, Count = 4, Size = ns(0, 2, 1, 6), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.4), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Wind), Light = 0.6 },
		-- Black ink shade: dark dust, black swirls and black grit thrown out.
		{ Texture = TEX.Smoke, Count = 4, Light = 0, Size = ns(0, 2, 1, 4.5), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(10, 16), Spread = Vector2.new(180, 8), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Swirl, Count = 2, Light = 0, Size = ns(0, 1.5, 1, 5), Transparency = ns(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.35), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Spark, Count = 14, Parallel = true, Light = 0, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(18, 28), Spread = Vector2.new(180, 15), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Rocks, Count = 8, Light = 0, Size = ns(0, 0.7, 1, 0.4), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(10, 18), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Main, STONE.Dark) },
	}, 1.5)
	ring(feet, STONE.Wind, 2, 14, 0.4, floorY)
	ring(feet, Color3.new(0, 0, 0), 2, 17, 0.45, floorY)
	groundDecal(feet, TEX.Crack, Color3.new(0, 0, 0), 2, 7, 1, { Floor = floorY, Hold = 0.5, GrowTime = 0.08, StartAlpha = 0.25 })
	debrisBurst(Vector3.new(feet.X, floorY + 0.5, feet.Z), STONE.Main, 4, { Material = Enum.Material.Slate, Size = 0.6, Height = 3, Reach = 6, Floor = floorY, Wedge = true })
	-- Wind spiralling around you on the way up, and pebbles caught in it.
	local att = Instance.new("Attachment")
	att.Parent = root
	local trail = {
		emitter(att, { Enabled = true, Texture = TEX.Swirl, Rate = 30, Size = ns(0, 2, 1, 4), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(1, 3), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-400, 400), Color = cs(STONE.Wind), Light = 0.7 }),
		emitter(att, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 40, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(10, 18), Dir = Enum.NormalId.Bottom, Spread = Vector2.new(25, 25), Color = cs(STONE.Wind), Light = 1 }),
		emitter(att, { Enabled = true, Texture = TEX.Rocks, Rate = 12, Light = 0, Size = ns(0, 0.6, 1, 0.4), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(2, 5), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Light) }),
		-- Black ink streaks and swirls in the updraft.
		emitter(att, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 18, Light = 0, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(10, 16), Dir = Enum.NormalId.Bottom, Spread = Vector2.new(30, 30), Color = cs(Color3.new(0, 0, 0)) }),
		emitter(att, { Enabled = true, Texture = TEX.Swirl, Rate = 10, Light = 0, Size = ns(0, 1.5, 1, 3.5), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(1, 2), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(0, 0, 0)) }),
	}
	-- Wind trails that follow your body: a white streak down each side of the
	-- torso, each with a thinner black ink streak just outside it.
	local trails = {}
	for _, spec in {
		{ X = -1.1, Width = 1.6, Color = STONE.Wind, Alpha = 0.25, Light = 0.6 },
		{ X = 1.1, Width = 1.6, Color = STONE.Wind, Alpha = 0.25, Light = 0.6 },
		{ X = -1.5, Width = 0.7, Color = Color3.new(0, 0, 0), Alpha = 0.1, Light = 0 },
		{ X = 1.5, Width = 0.7, Color = Color3.new(0, 0, 0), Alpha = 0.1, Light = 0 },
	} do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = Vector3.new(spec.X, spec.Width / 2, 0)
		a1.Position = Vector3.new(spec.X, -spec.Width / 2, 0)
		a0.Parent, a1.Parent = root, root
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.3
		tr.MinLength = 0.05
		tr.Color = cs(spec.Color)
		tr.Transparency = ns(0, spec.Alpha, 1, 1)
		tr.WidthScale = ns(0, 1, 1, 0.15)
		tr.LightEmission = spec.Light
		tr.LightInfluence = 0
		tr.FaceCamera = true
		tr.Parent = root
		table.insert(trails, tr)
		Debris:AddItem(a0, 1.6)
		Debris:AddItem(a1, 1.6)
		Debris:AddItem(tr, 1.6)
	end
	task.delay(1.2, function()
		for _, em in trail do
			em.Enabled = false
		end
		for _, tr in trails do
			tr.Enabled = false
		end
		Debris:AddItem(att, 1)
	end)
	shake(0.12, feet)
end

local function onLeapSlam(e)
	local floorY = floorAt(e.At + Vector3.new(0, 3, 0), e.At.Y)
	local center = Vector3.new(e.At.X, floorY, e.At.Z)
	local inner, outer = e.Inner or 7, e.Radius or 13
	-- Impact.
	playTemplate("Punch-02", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.4 })
	playTemplate("Crack-01", CFrame.new(center + Vector3.new(0, 0.5, 0)), { Scale = outer / 7 })
	playTemplate("Wind-01", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.4, Color = cs(STONE.Wind, STONE.Light) })
	burst(center + Vector3.new(0, 1, 0), {
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 2, 1, outer * 2.2), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.35), Color = cs(STONE.Wind), Light = 0.6, ZOffset = 1 },
		{ Texture = TEX.Dust, Count = 10, Light = 0, Size = ns(0, 4, 1, 9), Transparency = ns(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(14, 24), Spread = Vector2.new(180, 8), Drag = 3, Color = cs(STONE.Light, STONE.Main) },
		{ Texture = TEX.Rocks, Count = 18, Light = 0, Size = ns(0, 1.2, 1, 0.8), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(16, 30), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Light) },
	}, 2)
	-- Black ink shade: an ink shockwave just behind the white one, black dust
	-- rolling out along the ground, black shards and a column of dark grit.
	burst(center + Vector3.new(0, 1, 0), {
		{ Texture = TEX.Shockwave, Count = 1, Light = 0, Size = ns(0, 2, 1, outer * 2.6), Transparency = ns(0, 0.15, 1, 1), Lifetime = NumberRange.new(0.42), Color = cs(Color3.new(0, 0, 0)), ZOffset = 0.5 },
		{ Texture = TEX.Smoke, Count = 10, Light = 0, Size = ns(0, 3, 1, 6), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(18, 28), Spread = Vector2.new(180, 6), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Shard, Count = 14, Light = 0, Size = ns(0, 1, 1, 0.3), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(16, 28), Spread = Vector2.new(65, 65), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Spark, Count = 20, Parallel = true, Light = 0, Size = ns(0, 0.9, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(24, 38), Spread = Vector2.new(180, 20), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
	}, 2)
	-- A column of dust and grit thrown straight up from the impact.
	burst(center + Vector3.new(0, 0.5, 0), {
		{ Texture = TEX.Dust, Count = 6, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.7, 1), Speed = NumberRange.new(16, 26), Spread = Vector2.new(12, 12), Drag = 3, Color = cs(STONE.Light, STONE.Main) },
		{ Texture = TEX.Rocks, Count = 10, Light = 0, Size = ns(0, 1, 1, 0.6), Lifetime = NumberRange.new(0.7, 1), Speed = NumberRange.new(20, 34), Spread = Vector2.new(20, 20), Accel = Vector3.new(0, -70, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(STONE.Main, STONE.Dark) },
	}, 2)
	debrisBurst(center + Vector3.new(0, 0.5, 0), STONE.Main, 10, { Material = Enum.Material.Slate, Size = 0.9, Height = 6, Reach = outer, Floor = floorY })
	debrisBurst(center + Vector3.new(0, 0.5, 0), rgb(48, 38, 32), 6, { Material = Enum.Material.Basalt, Size = 0.8, Height = 5, Reach = outer * 0.8, Floor = floorY, Wedge = true })
	groundDecal(center, TEX.Crack, rgb(45, 30, 20), outer * 0.9, outer * 2, 2.6, { Floor = floorY, Hold = 1.8, GrowTime = 0.12, StartAlpha = 0.05 })
	-- Black ink cracks over the earth-brown ones.
	groundDecal(center, TEX.Crack, Color3.new(0, 0, 0), outer * 0.7, outer * 1.6, 2.6, { Floor = floorY, Lift = 0.03, Hold = 1.8, GrowTime = 0.12, StartAlpha = 0.15 })
	ring(center, STONE.Wind, 2, outer * 2.6, 0.4, floorY)
	ring(center, Color3.new(0, 0, 0), 2, outer * 3, 0.5, floorY)
	-- Two layers of spikes: the inner ring first, then a taller outer ring.
	spikeRing(center, floorY, inner * 0.75, 8, 5, 1.2)
	task.delay(0.15, function()
		ring(center, STONE.Light, inner, outer * 2.2, 0.4, floorY)
		spikeRing(center, floorY, outer * 0.85, 13, 7.5, 1.1)
	end)
	flash(center + Vector3.new(0, 3, 0), STONE.Light, outer * 2.5, 4, 0.35)
	shake(0.6, center)
end

-------------------------------------------------------------------------------
-- Nation golems: a swirl of light as one spawns (RiftboundVFX.GolemSpawn_<Nation>,
-- authored for a 4-stud radius) and the two-fist slam of Brutes and Elites
-- (RiftboundVFX.GolemSlam_<Nation>, authored for an 8-stud radius).
-------------------------------------------------------------------------------

local function onGolemSpawn(e)
	local floorY = floorAt(e.At + Vector3.new(0, 3, 0), e.At.Y)
	local center = Vector3.new(e.At.X, floorY, e.At.Z)
	playTemplate("GolemSpawn_" .. tostring(e.Nation), CFrame.new(center + Vector3.new(0, 0.15, 0)), { Scale = (e.Radius or 4) / 4 })
end

local function onGolemSlam(e)
	local floorY = floorAt(e.At + Vector3.new(0, 3, 0), e.At.Y)
	local center = Vector3.new(e.At.X, floorY, e.At.Z)
	local radius = e.Radius or 8
	playTemplate("GolemSlam_" .. tostring(e.Nation), CFrame.new(center + Vector3.new(0, 0.3, 0)), { Scale = radius / 8 })
	if e.Color then
		flash(center + Vector3.new(0, 3, 0), e.Color, radius * 1.5, 1.5, 0.25)
	end
	shake(0.25, center)
end

-------------------------------------------------------------------------------
-- Rift Bolt: a twisting shard of rift energy fired from alternating hands.
-------------------------------------------------------------------------------

local RIFT = {
	White = rgb(250, 240, 255),
	Lilac = rgb(214, 170, 255),
	Main = rgb(178, 108, 255),
	Pink = rgb(255, 110, 210),
	Deep = rgb(70, 25, 140),
}

local function neonPart(size, color)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- A small rift tear: a ring snapping open and shut with a spray of shards.
local function riftTear(at, scale)
	burst(at, {
		{ Texture = TEX.Ring, Count = 1, Size = ns(0, 0.4 * scale, 0.4, 3 * scale, 1, 3.4 * scale), Transparency = ns(0, 0, 0.6, 0.2, 1, 1), Lifetime = NumberRange.new(0.18), Color = cs(RIFT.White, RIFT.Main), Light = 1, ZOffset = 1 },
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, 2.4 * scale, 1, 0), Lifetime = NumberRange.new(0.14), Color = cs(RIFT.White, RIFT.Main), Light = 1 },
		{ Texture = TEX.Shard, Count = math.floor(5 * scale), Size = ns(0, 0.55, 1, 0), Lifetime = NumberRange.new(0.18, 0.3), Speed = NumberRange.new(8, 16), Spread = Vector2.new(70, 70), RotSpeed = NumberRange.new(-400, 400), Drag = 3, Color = cs(RIFT.Lilac, RIFT.Main), Light = 0.8 },
	}, 0.8)
end

local function launchRiftBolt(e)
	-- Start from the hand that threw it (when we can see the caster).
	local muzzle = e.From
	local caster = e.Caster and e.Caster.Character
	if caster then
		local hand = caster:FindFirstChild(CastAnimator.CastHand(caster))
		if hand and (hand.Position - e.From).Magnitude < 6 then
			muzzle = hand.Position
		end
	end
	riftTear(muzzle, 0.7)

	-- Core: a white-hot elongated shard inside a violet glow.
	local root = anchor(CFrame.lookAt(muzzle, muzzle + e.Dir), Vector3.new(0.2, 0.2, 0.2))
	local core = neonPart(Vector3.one, RIFT.White)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.55, 0.55, 2.8)
	mesh.Parent = core
	core.Parent = root
	local shell = neonPart(Vector3.one, RIFT.Main)
	shell.Transparency = 0.55
	local shellMesh = mesh:Clone()
	shellMesh.Scale = Vector3.new(1.15, 1.15, 3.8)
	shellMesh.Parent = shell
	shell.Parent = root
	local emitters = {
		emitter(root, { Enabled = true, Texture = TEX.Glow, Locked = true, Rate = 40, Size = ns(0, 3.4, 1, 2), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.1, 0.14), Color = cs(RIFT.Lilac, RIFT.Main), Light = 1 }),
		emitter(root, { Enabled = true, Texture = TEX.Sparkles, Rate = 30, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(1, 3), Spread = Vector2.new(180, 180), Color = cs(RIFT.Lilac, RIFT.Pink), Light = 1 }),
		emitter(root, { Enabled = true, Texture = TEX.Shard, Rate = 10, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(2, 4), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-300, 300), Color = cs(RIFT.Lilac, RIFT.Main), Light = 0.8 }),
	}
	-- Two trails offset from the spinning core twist into a violet/pink helix.
	for i, color in { RIFT.Main, RIFT.Pink } do
		local side = if i == 1 then 1 else -1
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0.55 * side, 0.12, 0.6), Vector3.new(0.55 * side, -0.12, 0.6)
		a0.Parent, a1.Parent = root, root
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.22
		trail.Color = cs(RIFT.White, color)
		trail.Transparency = ns(0, 0.05, 1, 1)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.WidthScale = ns(0, 1, 1, 0)
		trail.Parent = root
	end
	local light = Instance.new("PointLight")
	light.Color = RIFT.Main
	light.Range = 9
	light.Brightness = 2.2
	light.Shadows = false
	light.Parent = root

	local start = os.clock()
	local range = e.Range or 70
	local offset = muzzle - e.From
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local d = math.min(t * e.Speed, range)
		-- Blend from the hand onto the true flight line over the first instant.
		local pos = e.From + e.Dir * d + offset * (1 - math.min(t / 0.08, 1))
		local cf = CFrame.lookAt(pos, pos + e.Dir) * CFrame.Angles(0, 0, t * 30)
		root.CFrame = cf
		core.CFrame = cf
		shell.CFrame = cf * CFrame.Angles(0, 0, -t * 12)
	end)
	projectiles[e.Id] = {
		Part = root,
		Emitters = emitters,
		Conn = conn,
		Cleanup = function()
			core.Transparency, shell.Transparency = 1, 1
			light.Enabled = false
		end,
	}
	task.delay(range / e.Speed + 1, function()
		local p = projectiles[e.Id]
		if p then
			p.Conn:Disconnect()
			p.Part:Destroy()
			projectiles[e.Id] = nil
		end
	end)
end

local function riftBoltImpact(at, floorY)
	riftTear(at, 1.1)
	playTemplate("Slash-Impact-01", CFrame.new(at), { Scale = 0.45, Color = cs(RIFT.White, RIFT.Main, RIFT.Deep) })
	burst(at, {
		{ Texture = TEX.Sparkle, Count = 1, Size = ns(0, 2.2, 1, 3), Lifetime = NumberRange.new(0.22), Color = cs(RIFT.White, RIFT.Lilac), Light = 1 },
		{ Texture = TEX.Spark, Count = 8, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(14, 24), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(RIFT.White, RIFT.Pink), Light = 1 },
		-- Black ink shade: a black tear ring, black shards and streaks.
		{ Texture = TEX.Ring, Count = 1, Light = 0, Size = ns(0, 0.5, 0.4, 3.6, 1, 4.2), Transparency = ns(0, 0.1, 0.6, 0.3, 1, 1), Lifetime = NumberRange.new(0.22), Color = cs(Color3.new(0, 0, 0)), ZOffset = 0.5 },
		{ Texture = TEX.Shard, Count = 6, Light = 0, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(10, 18), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-400, 400), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Spark, Count = 6, Parallel = true, Light = 0, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.15, 0.25), Speed = NumberRange.new(14, 24), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
	}, 1)
	-- A rift shockwave, an X of rift slashes, sparkles and a lingering crackle.
	burst(at, {
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 0.6, 1, 5), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.22), Color = cs(RIFT.White, RIFT.Main), Light = 1, ZOffset = 1 },
		{ Texture = TEX.Spark, Count = 2, Parallel = true, Size = ns(0, 3.2, 1, 0), Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(0.5, 1), Spread = Vector2.new(180, 180), Color = cs(RIFT.White, RIFT.Pink), Light = 1, ZOffset = 1.5 },
		{ Texture = TEX.Spark, Count = 2, Parallel = true, Light = 0, Size = ns(0, 3.6, 1, 0), Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(0.5, 1), Spread = Vector2.new(180, 180), Color = cs(Color3.new(0, 0, 0)), ZOffset = 1.2 },
		{ Texture = TEX.Sparkles, Count = 8, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 8), Spread = Vector2.new(180, 180), Drag = 2, Color = cs(RIFT.Lilac, RIFT.Pink), Light = 1 },
		{ Texture = TEX.Electric, Count = 1, Size = ns(0, 1.6, 1, 2.4), Lifetime = NumberRange.new(0.25), RotSpeed = NumberRange.new(-200, 200), Color = cs(RIFT.White, RIFT.Main), Light = 1 },
	}, 1)
	ring(at, RIFT.Main, 0.8, 5, 0.25, floorY)
	ring(at, Color3.new(0, 0, 0), 0.8, 6.5, 0.3, floorY)
	if floorY and at.Y - floorY < 4 then
		-- A small scorch where the bolt lands near the ground.
		groundDecal(at, TEX.Crack, RIFT.Main, 0.8, 2.6, 0.9, { Floor = floorY, Hold = 0.4, GrowTime = 0.06, StartAlpha = 0.2 })
		groundDecal(at, TEX.Crack, Color3.new(0, 0, 0), 0.6, 2, 0.9, { Floor = floorY, Lift = 0.03, Hold = 0.4, GrowTime = 0.06, StartAlpha = 0.25 })
	end
	flash(at, RIFT.Main, 8, 2.5, 0.15)
end

-------------------------------------------------------------------------------
-- Block: a rift shield around the player.
-------------------------------------------------------------------------------

local shields = {} -- [root] = { Bubble, Sheen, Rune, Emitters, Light, Conn }

local function popText(root, text, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0.05, 0.02, 0.08)
	label.TextStrokeTransparency = 0
	label.FontFace = Font.new("rbxasset://fonts/families/Bangers.json")
	label.TextSize = size
	label.Parent = gui
	gui.Parent = folder
	tween(gui, 0.6, { StudsOffset = Vector3.new(0, 6, 0) })
	task.delay(0.3, function()
		tween(label, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(gui, 0.7)
end

local function lowerShield(root, broken)
	local s = shields[root]
	if not s then
		return
	end
	shields[root] = nil
	s.Conn:Disconnect()
	for _, em in s.Emitters do
		em.Enabled = false
	end
	if broken then
		-- Guard broken: the bubble shatters.
		local at = s.Bubble.Position
		burst(at, {
			{ Texture = TEX.Shard, Count = 36, Size = ns(0, 0.9, 1, 0.2), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(16, 28), Spread = Vector2.new(180, 180), Drag = 2, Accel = Vector3.new(0, -30, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(RIFT.White, RIFT.Main), Light = 0.8 },
			{ Texture = TEX.Glow, Count = 1, Size = ns(0, 6, 1, 12), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.25), Color = cs(RIFT.Lilac, RIFT.Main), Light = 1 },
		}, 1.5)
		debrisBurst(at, RIFT.Lilac, 10, { Material = Enum.Material.Glass, Size = 0.6, Height = 4, Reach = 7, Floor = at.Y - 2.9 })
		popText(root, "GUARD BROKEN", rgb(255, 120, 140), 26)
		shake(0.2, at)
		tween(s.Bubble, 0.15, { Size = s.Bubble.Size * 1.3, Transparency = 1 })
	else
		tween(s.Bubble, 0.15, { Size = Vector3.one * 0.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	tween(s.Sheen, 0.15, { Size = Vector3.one * 0.5, Transparency = 1 })
	tween(s.RuneDecal, 0.2, { Transparency = 1 })
	tween(s.Light, 0.2, { Brightness = 0 })
	for _, item in { s.Bubble, s.Sheen, s.Rune } do
		Debris:AddItem(item, 0.3)
	end
end

local function onShield(e)
	local root = e.Target
	if not root or not root.Parent then
		return
	end
	if not e.Up then
		lowerShield(root, e.Broken)
		return
	end
	if shields[root] then
		lowerShield(root, false)
	end
	local SIZE = 8.5
	local bubble = Instance.new("Part")
	bubble.Shape = Enum.PartType.Ball
	bubble.Material = Enum.Material.ForceField
	bubble.Color = RIFT.Main
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Size = Vector3.one * 0.5
	bubble.CFrame = root.CFrame
	bubble.Parent = folder
	tween(bubble, 0.2, { Size = Vector3.one * SIZE }, Enum.EasingStyle.Back)
	local sheen = bubble:Clone()
	sheen.Material = Enum.Material.Neon
	sheen.Color = RIFT.Main
	sheen.Transparency = 0.86
	sheen.Parent = folder
	tween(sheen, 0.2, { Size = Vector3.one * (SIZE - 0.3) }, Enum.EasingStyle.Back)
	-- Spinning rune circle on the floor under you.
	local rune = anchor(CFrame.new(root.Position), Vector3.new(SIZE * 1.15, 0.05, SIZE * 1.15))
	local runeDecal = Instance.new("Decal")
	runeDecal.Face = Enum.NormalId.Top
	runeDecal.Texture = TEX.Telegraph
	runeDecal.Color3 = RIFT.Main
	runeDecal.Transparency = 0.15
	runeDecal.Parent = rune
	local emitters = {
		emitter(bubble, { Enabled = true, Texture = TEX.Glow, Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface, Rate = 30, Size = ns(0, 1.6, 1, 0), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.3, 0.5), Color = cs(RIFT.Lilac, RIFT.Main), Light = 1 }),
		emitter(bubble, { Enabled = true, Texture = TEX.Sparkles, Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface, Rate = 40, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0.3, 0.8), Color = cs(RIFT.White, RIFT.Lilac), Light = 1 }),
		emitter(rune, { Enabled = true, Texture = TEX.Glow, Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface, Rate = 18, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(2, 4), Color = cs(RIFT.Lilac, RIFT.Main), Light = 1 }),
	}
	local light = Instance.new("PointLight")
	light.Color = RIFT.Main
	light.Range = 12
	light.Brightness = 2.4
	light.Shadows = false
	light.Parent = bubble
	burst(root.Position, {
		{ Texture = TEX.Ring, Count = 1, Size = ns(0, 1, 1, SIZE * 1.4), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.25), Color = cs(RIFT.White, RIFT.Main), Light = 1 },
	}, 1)
	local start = os.clock()
	local guardTime = e.GuardTime or 3
	local conn = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			lowerShield(root, false)
			return
		end
		local t = os.clock() - start
		local pos = root.Position - Vector3.new(0, 0.4, 0)
		bubble.CFrame = CFrame.new(pos)
		sheen.CFrame = CFrame.new(pos)
		rune.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.85, root.Position.Z) * CFrame.Angles(0, t * 1.5, 0)
		-- Last moments before the guard breaks: the shield flickers red.
		local left = guardTime - t
		if left < 0.8 then
			local blink = math.sin(t * 40) > 0
			bubble.Color = if blink then rgb(255, 90, 120) else RIFT.Main
		end
	end)
	shields[root] = { Bubble = bubble, Sheen = sheen, Rune = rune, RuneDecal = runeDecal, Emitters = emitters, Light = light, Conn = conn }
end

local function onBlocked(e)
	local root = e.Target
	if not root or not root.Parent then
		return
	end
	local s = shields[root]
	local center = root.Position
	local toward = Vector3.new(e.From.X - center.X, 0, e.From.Z - center.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else root.CFrame.LookVector
	local at = center + toward * 4.2
	CastAnimator.GuardHit(root.Parent)
	if s then
		-- The shell flashes and ripples where it was hit.
		s.Bubble.Color = RIFT.White
		s.Bubble.Size = Vector3.one * 9.4
		tween(s.Bubble, 0.2, { Size = Vector3.one * 8.5, Color = RIFT.Main })
		s.Light.Brightness = 5
		tween(s.Light, 0.25, { Brightness = 2.4 })
	end
	local look = CFrame.lookAt(at, at + toward)
	burst(look, {
		{ Texture = TEX.Impact, Count = 1, Size = ns(0, 3, 1, 4.5), Lifetime = NumberRange.new(0.2), Color = cs(RIFT.White, RIFT.Lilac), Light = 1 },
		{ Texture = TEX.Spark, Count = 18, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(16, 28), Spread = Vector2.new(60, 60), Dir = Enum.NormalId.Front, Drag = 3, Color = cs(RIFT.White, RIFT.Main), Light = 1 },
	}, 1)
	if e.Parry then
		-- Perfect block: a bright counter-flash that throws the attacker back.
		playTemplate("Slash-Impact-01", look, { Scale = 0.9, Color = cs(rgb(255, 250, 220), rgb(255, 210, 120), RIFT.Main) })
		burst(at, {
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 1, 1, 12), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(rgb(255, 245, 210), RIFT.Lilac), Light = 1 },
			{ Texture = TEX.Sparkle, Count = 2, Size = ns(0, 4, 1, 6), Lifetime = NumberRange.new(0.3), Color = cs(rgb(255, 245, 210)), Light = 1 },
		}, 1)
		flash(at, rgb(255, 230, 170), 16, 6, 0.3)
		popText(root, "PARRY!", rgb(255, 225, 140), 34)
		shake(0.3, at)
	else
		popText(root, "BLOCK", RIFT.Lilac, 24)
		shake(0.1, at)
	end
end

-------------------------------------------------------------------------------
-- Cast + impact
-------------------------------------------------------------------------------

local function onCast(e)
	-- Your own cast animation plays instantly from Controls; animate everyone else here.
	if e.Caster and e.Caster ~= localPlayer then
		CastAnimator.Play(e.Caster.Character, e.Skill)
	end
	if e.Skill == "PlasmaLance" and e.Caster then
		plasmaReady(e.Caster.Character, Skills.Defs.PlasmaLance.Windup)
	end
	local a = palettes(e.Skill)
	local small = e.Skill == "RiftBolt"
	burst(e.At + e.Dir * 1.5, {
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, if small then 1.5 else 3, 1, 0), Lifetime = NumberRange.new(0.15), Color = cs(a.Core, a.Main) },
		{ Texture = TEX.Spark, Count = if small then 3 else 8, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(10, 18), Spread = Vector2.new(60, 60), Color = cs(a.Core, a.Main) },
	}, 1)
end

local function onImpact(e)
	local a, _, def = palettes(e.Skill)
	local element = def and def.Elements[1] or "Rift"
	if e.Skill == "FrostGale" then
		-- Ice shards instead of a water splash.
		burst(e.At, {
			{ Texture = TEX.Shard, Count = 12, Size = ns(0, 0.8, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 18), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -30, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(1, 1, 1), rgb(170, 225, 255)), Light = 0.6 },
			{ Texture = TEX.Sparkles, Count = 8, Size = ns(0, 0.9, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 8), Spread = Vector2.new(180, 180), Color = cs(rgb(170, 225, 255)), Light = 1 },
		}, 1)
	else
		playTemplate(IMPACT_TEMPLATE[element] or "Punch-01", CFrame.new(e.At), { Scale = 0.55, Color = if element == "Lightning" then ELECTRIC_TINT else nil })
	end
	burst(e.At, {
		{ Texture = TEX.Impact, Count = 1, Size = ns(0, 3.5, 1, 4.5), Transparency = ns(0, 0, 1, 0.3), Lifetime = NumberRange.new(0.25), Color = cs(a.Core, a.Main), Light = 0.8 },
		{ Texture = TEX.SideImpact, Count = 1, Size = ns(0, 2.5, 1, 3.5), Lifetime = NumberRange.new(0.2), Color = cs(Color3.new(1, 1, 1)), Light = 0.9 },
		{ Texture = TEX.Spark, Count = 6, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(12, 22), Spread = Vector2.new(180, 180), Color = cs(a.Core, a.Main), Drag = 4 },
	}, 1)
end

-------------------------------------------------------------------------------
-- Projectiles
-------------------------------------------------------------------------------

-- Blender-made Fireball (art/skill_models/fireball): three nested flame shells
-- (FireballCore / FireballMid / FireballOuter in RiftboundVFX) that spin at
-- different speeds around the flight axis and pulse. Each template may carry
-- an "Orient" CFrame attribute that turns its tail to +Z (behind the flight).
local SHADE
local FIREBALL_SHELLS = {
	{ Name = "FireballOuter", Spin = -3, Pulse = 0.04, Alpha = 0.15, Scale = Vector3.new(0.62, 1.4, 0.62), Back = 1.7, Shade = true },
	{ Name = "FireballCore", Spin = 9, Pulse = 0.08, Alpha = 0, Color = Color3.fromRGB(255, 236, 170) },
	{ Name = "FireballMid", Spin = -6, Pulse = 0.06, Alpha = 0.15, Color = Color3.fromRGB(255, 130, 30) },
	{ Name = "FireballOuter", Spin = 4, Pulse = 0.05, Alpha = 0.45, Color = Color3.fromRGB(235, 55, 10) },
}

local function fireballShells()
	local shells = {}
	for _, spec in FIREBALL_SHELLS do
		local m = meshTemplate(spec.Name)
		if not m then
			for _, made in shells do
				made.Part:Destroy()
			end
			return nil
		end
		if spec.Shade then
			m.Material = Enum.Material.SmoothPlastic
			m.Color = Color3.new(0, 0, 0)
		else
			m.Material = Enum.Material.Neon
			m.Color = spec.Color or Color3.new(1, 1, 1)
		end
		m.Transparency = spec.Alpha
		m.Parent = folder
		table.insert(shells, { Part = m, Spec = spec, Size = m.Size * (spec.Scale or Vector3.one), Orient = m:GetAttribute("Orient") or CFrame.identity })
	end
	return shells
end

local function moveShells(shells, cf, t)
	for _, sh in shells do
		local k = 1 + sh.Spec.Pulse * math.sin(t * 14 + sh.Spec.Spin)
		sh.Part.Size = sh.Size * k
		sh.Part.CFrame = cf * CFrame.new(0, 0, sh.Spec.Back or 0) * CFrame.Angles(0, 0, t * sh.Spec.Spin) * sh.Orient
	end
end

-- Blender-made Fireball blast: a flame dome bursting up out of a glowing core
-- with a jagged shockwave ring, grown from nothing and faded out. Authored for
-- a 3-stud blast radius.
local FIREBALL_BLAST = {
	-- A black ring just outside the glowing one gives the blast an ink rim.
	{ Name = "FireballRing", Grow = 0.35, Life = 0.45, Alpha = 0.05, Scale = 1.45, Lift = false, Shade = true },
	{ Name = "FireballBlastCore", Grow = 0.18, Life = 0.35, Alpha = 0, Scale = 0.75, Lift = true, Color = Color3.fromRGB(255, 236, 170) },
	{ Name = "FireballBlast", Grow = 0.25, Life = 0.5, Alpha = 0.3, Scale = 0.8, Lift = true, Color = Color3.fromRGB(255, 100, 20) },
	{ Name = "FireballRing", Grow = 0.3, Life = 0.4, Alpha = 0.2, Scale = 1.1, Lift = false, Color = Color3.fromRGB(255, 170, 60) },
}

-- Ink-black accent colours for the dark-shade layers.
SHADE = { Ink = Color3.new(0, 0, 0), Ember = Color3.fromRGB(45, 8, 0) }

local function fireballBlast(at, r, floorY)
	local base = Vector3.new(at.X, (floorY or at.Y - 2) + 0.1, at.Z)
	local spin = math.random() * math.pi * 2
	for _, spec in FIREBALL_BLAST do
		local m = meshTemplate(spec.Name)
		if m then
			local full = m.Size * (r / 3) * spec.Scale
			local orient = m:GetAttribute("Orient") or CFrame.identity
			local function place(size, turn)
				local lift = if spec.Lift then size.Y * 0.5 else 0
				return CFrame.new(base + Vector3.new(0, lift, 0)) * CFrame.Angles(0, turn, 0) * orient
			end
			if spec.Shade then
				m.Material = Enum.Material.SmoothPlastic
				m.Color = SHADE.Ink
				m.CastShadow = false
			else
				m.Material = Enum.Material.Neon
				m.Color = spec.Color or Color3.new(1, 1, 1)
			end
			m.Transparency = spec.Alpha
			m.Size = full * 0.15
			m.CFrame = place(m.Size, spin)
			m.Parent = folder
			TweenService:Create(m, TweenInfo.new(spec.Grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = full,
				CFrame = place(full, spin + 0.6),
			}):Play()
			task.delay(spec.Grow, function()
				tween(m, spec.Life, { Transparency = 1, Size = full * 1.15, CFrame = place(full * 1.15, spin + 0.9) })
			end)
			Debris:AddItem(m, spec.Grow + spec.Life + 0.1)
		end
	end
end

local function onProjectileStart(e)
	if e.Skill == "PlasmaLance" then
		launchPlasmaLance(e)
		return
	elseif e.Skill == "RiftBolt" then
		launchRiftBolt(e)
		return
	end
	local a, _, def = palettes(e.Skill)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.CFrame = CFrame.lookAt(e.From, e.From + e.Dir)
	local emitters = {}
	local shells
	if e.Skill == "RiftBolt" then
		-- A small spinning rift crystal with a violet streak.
		part.Size = Vector3.new(0.45, 0.45, 1.7)
		part.Color = a.Core
		table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Glow, Rate = 60, Size = ns(0, 1.6, 1, 0), Lifetime = NumberRange.new(0.12, 0.18), Color = cs(a.Core, a.Main) }))
		table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Sparkles, Rate = 25, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.25), Speed = NumberRange.new(1, 3), Spread = Vector2.new(180, 180), Color = cs(a.Main) }))
	else
		-- Fireball (and any other projectile): a roaring flame core.
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * 1.4
		part.Color = a.Core
		shells = if e.Skill == "Fireball" then fireballShells() else nil
		if shells then
			part.Transparency = 1
		end
		if e.Skill == "Fireball" then
			-- Ink-black flame licks and sparks behind the ball for contrast.
			table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Flame, Rate = 28, Light = 0, Size = ns(0, 1.6, 1, 0.2), Transparency = ns(0, 0.15, 1, 1), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(2, 5), Dir = Enum.NormalId.Back, Spread = Vector2.new(20, 20), RotSpeed = NumberRange.new(-120, 120), Color = cs(SHADE.Ink, SHADE.Ember), ZOffset = -0.5 }))
			table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 14, Light = 0, Size = ns(0, 0.45, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 9), Dir = Enum.NormalId.Back, Spread = Vector2.new(70, 70), Color = cs(SHADE.Ink) }))
		end
		table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Flame, Rate = 70, Size = ns(0, 2.6, 1, 0.3), Lifetime = NumberRange.new(0.22, 0.35), Speed = NumberRange.new(1, 3), Spread = Vector2.new(25, 25), Accel = Vector3.new(0, 6, 0), RotSpeed = NumberRange.new(-90, 90), Color = cs(a.Core, a.Main, a.Dark) }))
		table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 30, Size = ns(0, 0.35, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(3, 8), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, 10, 0), Color = cs(a.Core, a.Main) }))
		table.insert(emitters, emitter(part, { Enabled = true, Texture = TEX.Smoke, Rate = 14, Light = 0, Size = ns(0, 1.2, 1, 3), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(0.5, 1.5), Accel = Vector3.new(0, 4, 0), Color = cs(a.Smoke) }))
	end
	local att0, att1 = Instance.new("Attachment"), Instance.new("Attachment")
	att0.Position, att1.Position = Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0)
	att0.Parent, att1.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = att0, att1
	trail.Lifetime = if e.Skill == "RiftBolt" then 0.12 else 0.2
	trail.Color = cs(a.Core, a.Main)
	trail.Transparency = ns(0, 0.1, 1, 1)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.WidthScale = ns(0, 1, 1, 0)
	trail.Parent = part
	local light = Instance.new("PointLight")
	light.Color = a.Main
	light.Range = if e.Skill == "RiftBolt" then 8 else 14
	light.Brightness = 2
	light.Parent = part
	part.Parent = folder

	local start = os.clock()
	local range = def and def.Range or 70
	local conn = RunService.RenderStepped:Connect(function()
		local d = math.min((os.clock() - start) * e.Speed, range)
		local pos = e.From + e.Dir * d
		part.CFrame = CFrame.lookAt(pos, pos + e.Dir) * CFrame.Angles(0, 0, os.clock() * 12)
		if shells then
			moveShells(shells, CFrame.lookAt(pos, pos + e.Dir), os.clock() - start)
		end
	end)
	local cleanup = shells and function()
		for _, sh in shells do
			sh.Part:Destroy()
		end
	end
	projectiles[e.Id] = { Part = part, Emitters = emitters, Conn = conn, Cleanup = cleanup }
	-- Safety: if the end event is lost, clean up anyway.
	task.delay(range / e.Speed + 1, function()
		local p = projectiles[e.Id]
		if p then
			p.Conn:Disconnect()
			p.Part:Destroy()
			if p.Cleanup then
				p.Cleanup()
			end
			projectiles[e.Id] = nil
		end
	end)
end

local function onProjectileEnd(e)
	local a, _, def = palettes(e.Skill)
	local p = projectiles[e.Id]
	if p then
		projectiles[e.Id] = nil
		p.Conn:Disconnect()
		for _, em in p.Emitters do
			em.Enabled = false
		end
		p.Part.Transparency = 1
		if p.Cleanup then
			p.Cleanup()
		end
		Debris:AddItem(p.Part, 1)
	end
	local r = e.Radius or 3
	if e.Skill == "PlasmaLance" then
		plasmaExplosion(e.At, r, e.Floor)
		return
	end
	if e.Skill == "RiftBolt" then
		riftBoltImpact(e.At, e.Floor)
		return
	end
	-- Fireball explosion.
	if e.Skill == "Fireball" then
		fireballBlast(e.At, r, e.Floor)
		-- Black spikes and flames thrown out with the blast.
		burst(e.At, {
			{ Texture = TEX.Spark, Count = 14, Parallel = true, Light = 0, Size = ns(0, 1.3, 1, 0), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(30, 50), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(SHADE.Ink) },
			{ Texture = TEX.Flame, Count = 10, Light = 0, Size = ns(0, 3, 1, 0.8), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(12, 20), Spread = Vector2.new(180, 180), Drag = 5, RotSpeed = NumberRange.new(-120, 120), Color = cs(SHADE.Ink, SHADE.Ember), ZOffset = -1 },
		}, 1.5)
	end
	playTemplate("Realistic-Explosion-01", CFrame.new(e.At), { Scale = 0.9 })
	burst(e.At, {
		{ Texture = TEX.Glow, Count = 1, Size = ns(0, 2, 0.3, r * 1.5, 1, r * 1.8), Transparency = ns(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.25), Color = cs(a.Core, a.Main) },
		{ Texture = TEX.FireBurst, Count = 3, Size = ns(0, r * 1.1, 1, r * 1.4), Transparency = ns(0, 0, 1, 0.4), Lifetime = NumberRange.new(0.45, 0.55), Spread = Vector2.new(30, 30), Speed = NumberRange.new(1, 2), Color = cs(a.Core, a.Main), Light = 0.75 },
		{ Texture = TEX.Flame, Count = 24, Size = ns(0, 4, 1, 1.5), Lifetime = NumberRange.new(0.4, 0.65), Speed = NumberRange.new(10, 20), Spread = Vector2.new(180, 180), Drag = 5, Accel = Vector3.new(0, 8, 0), RotSpeed = NumberRange.new(-120, 120), Color = cs(a.Core, a.Main, a.Dark) },
		{ Texture = TEX.Spark, Count = 40, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(25, 45), Spread = Vector2.new(180, 180), Drag = 3, Accel = Vector3.new(0, -30, 0), Color = cs(a.Core, a.Main) },
		{ Texture = TEX.Smoke, Count = 6, Light = 0, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.6, 1, 1), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(2, 6), Spread = Vector2.new(180, 60), Accel = Vector3.new(0, 5, 0), Drag = 1.5, Color = cs(a.Smoke) },
	}, 2.5)
	flash(e.At, a.Main, r * 3.5, 6, 0.45)
	ring(e.At, a.Core, 2, r * 2.6, 0.35, e.Floor)
	groundDecal(e.At, TEX.Crack, if e.Skill == "Fireball" then rgb(255, 140, 60) else rgb(30, 12, 8), r * 1.4, r * 2, 2.5, { Floor = e.Floor, Hold = 1.6, GrowTime = 0.1, StartAlpha = 0.15 })
	shake(0.28, e.At)
end

-------------------------------------------------------------------------------
-- Lines: Tidal Wave
-------------------------------------------------------------------------------

-- Blender-made Tidal Wave (art/skill_models/tidalwave): a curling wave in four
-- pieces (TidalBody / TidalCrest / TidalShade / TidalStreaks in the Model
-- RiftboundVFX.TidalWaveModel). Body is the reference: its bottom sits on the
-- floor, its width runs across the path and its curl faces -Z (the travel
-- direction). Each piece keeps its offset from the body, so the wave can be
-- stretched per axis (rise and crash) without the pieces drifting apart.
local TIDAL_LOOK = {
	-- Body carries the painted texture (TidalWave_Color.png): white so it shows true.
	TidalBody = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1), Alpha = 0.05 },
	TidalStreaks = { Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 210, 255), Alpha = 0.1 },
	TidalCrest = { Material = Enum.Material.Neon, Color = Color3.fromRGB(225, 248, 255), Alpha = 0 },
	TidalShade = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Alpha = 0 },
}

-- The model is authored low; stretch it up so the wave towers over players.
local TIDAL_HEIGHT = 1.7

local function tidalWaveModel()
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local source = templates and templates:FindFirstChild("TidalWaveModel")
	local body = source and source:FindFirstChild("TidalBody")
	if not body then
		return nil
	end
	local pieces = {}
	for _, src in source:GetChildren() do
		local look = src:IsA("MeshPart") and TIDAL_LOOK[src.Name]
		if look then
			local p = src:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = look.Material
			p.Color = look.Color
			p.Transparency = look.Alpha
			p.Parent = folder
			table.insert(pieces, { Part = p, Size = src.Size, Rel = body.CFrame:ToObjectSpace(src.CFrame), Alpha = look.Alpha })
		end
	end
	return { Pieces = pieces, BodySize = body.Size }
end

-- Places the wave with its base centre at `base` (a CFrame facing the travel
-- direction), stretched by `stretch` (per-axis, in the wave's own space).
local function placeTidalWave(wave, base, stretch)
	local bodyCF = base * CFrame.new(0, wave.BodySize.Y * stretch.Y / 2, 0)
	for _, piece in wave.Pieces do
		piece.Part.Size = piece.Size * stretch
		piece.Part.CFrame = bodyCF * CFrame.new(piece.Rel.Position * stretch) * piece.Rel.Rotation
	end
end

local function onLine(e)
	local a, b = palettes(e.Skill)
	local floorY = e.Floor or e.From.Y - 2.9
	local startPos = Vector3.new(e.From.X, floorY, e.From.Z)
	local endPos = startPos + e.Dir * e.Length
	local look = CFrame.lookAt(startPos, endPos)


	-- Sweeping wave (Tidal Wave, Frost Gale and any other line).
	local frost = e.Skill == "FrostGale"
	local mover = anchor(look * CFrame.new(0, 1, -1), Vector3.new(e.Width, 1, 1.5), e.Sweep + 1.5)
	local spray = emitter(mover, {
		Enabled = true,
		-- Spray streaks rather than the cartoon drop icon.
		Texture = if frost then TEX.Swirl else TEX.Spark,
		Parallel = not frost,
		Shape = Enum.ParticleEmitterShape.Box,
		InOut = Enum.ParticleEmitterShapeInOut.Outward,
		Rate = if frost then 160 else 260,
		Size = if frost then ns(0, 2.2, 1, 0) else ns(0, 0.5, 1, 0.15),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(8, 15),
		Spread = Vector2.new(30, 30),
		Accel = if frost then Vector3.zero else Vector3.new(0, -45, 0),
		RotSpeed = NumberRange.new(-200, 200),
		Color = cs(a.Core, a.Main),
		Light = if frost then 1 else 0.6,
	})
	local foam = emitter(mover, {
		Enabled = true,
		Texture = if frost then TEX.Spark else TEX.WaterFoam,
		Parallel = frost,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = if frost then 120 else 90,
		Size = if frost then ns(0, 0.8, 1, 0) else ns(0, 2, 1, 4),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = if frost then NumberRange.new(20, 35) else NumberRange.new(1, 3),
		Dir = if frost then Enum.NormalId.Front else Enum.NormalId.Top,
		Color = cs(Color3.new(1, 1, 1), b.Smoke),
		Transparency = ns(0, 0.3, 1, 1),
		Light = 0.5,
	})
	-- Wave body riding with the emitter: the Blender curling wave for Tidal
	-- Wave, the older AI wave mesh if that is missing, a translucent wedge
	-- otherwise.
	local tidal = (not frost) and tidalWaveModel()
	if tidal then
		local k = e.Width / math.max(tidal.BodySize.X, 0.1)
		local wstart = os.clock()
		local wtotal = e.Sweep + 0.25
		local wconn
		playTemplate("Water-01", CFrame.new(startPos + Vector3.new(0, 1, 0)), { Scale = 1.2 })
		wconn = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - wstart) / wtotal, 1)
			-- Rises fast, rolls forward with a slight surge, then holds height.
			local rise = 1 - (1 - math.min(t * 3, 1)) ^ 3
			local surge = 1 + 0.06 * math.sin(t * math.pi * 6)
			placeTidalWave(tidal, look * CFrame.new(0, 0, -e.Length * t), Vector3.new(k, k * TIDAL_HEIGHT * (0.2 + 0.8 * rise) * surge, k))
			if t >= 1 then
				wconn:Disconnect()
				-- Crash: the curl slams down and spreads out as it fades.
				local crashStart = os.clock()
				local cconn
				cconn = RunService.RenderStepped:Connect(function()
					local c = math.min((os.clock() - crashStart) / 0.35, 1)
					placeTidalWave(tidal, look * CFrame.new(0, 0, -e.Length - c * 2), Vector3.new(k * (1 + 0.25 * c), k * TIDAL_HEIGHT * (1 - 0.8 * c), k * (1 + 0.6 * c)))
					for _, piece in tidal.Pieces do
						piece.Part.Transparency = piece.Alpha + (1 - piece.Alpha) * c
					end
					if c >= 1 then
						cconn:Disconnect()
						for _, piece in tidal.Pieces do
							piece.Part:Destroy()
						end
					end
				end)
			end
		end)
		for i = 1, 2 do
			task.delay(e.Sweep * i / 3, function()
				playTemplate("Water-02", CFrame.new(startPos + e.Dir * (e.Length * i / 3) + Vector3.new(0, 1, 0)), { Scale = 1 })
			end)
		end
		task.delay(e.Sweep, function()
			playTemplate("Splash-01", CFrame.new(endPos + Vector3.new(0, 1, 0)), { Scale = 1.4 })
		end)
	end
	local waveMesh = (not frost) and (not tidal) and meshTemplate("WaveMesh")
	if waveMesh then
		local base = waveMesh.Size
		local k = e.Width / math.max(base.Z, 0.1)
		waveMesh.Size = base * k * Vector3.new(1, 0.15, 1)
		waveMesh.Parent = folder
		Debris:AddItem(waveMesh, e.Sweep + 0.8)
		playTemplate("Water-01", CFrame.new(startPos + Vector3.new(0, 1, 0)), { Scale = 1.2 })
		local wstart = os.clock()
		local wtotal = e.Sweep + 0.25
		local wconn
		wconn = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - wstart) / wtotal, 1)
			local rise = math.sin(math.pi * math.min(t * 1.1, 1))
			waveMesh.Size = base * k * Vector3.new(1, 0.25 + 0.75 * rise, 1)
			-- Width across the path, crest leaning into the direction of travel.
			waveMesh.CFrame = look * CFrame.new(0, waveMesh.Size.Y / 2 - 0.3, -e.Length * t) * CFrame.Angles(0, math.pi / 2, 0)
			if t >= 1 then
				wconn:Disconnect()
				tween(waveMesh, 0.3, { Transparency = 1, Size = waveMesh.Size * Vector3.new(1.2, 0.2, 1.2) })
			end
		end)
		for i = 1, 2 do
			task.delay(e.Sweep * i / 3, function()
				playTemplate("Water-02", CFrame.new(startPos + e.Dir * (e.Length * i / 3) + Vector3.new(0, 1, 0)), { Scale = 1 })
			end)
		end
		task.delay(e.Sweep, function()
			playTemplate("Splash-01", CFrame.new(endPos + Vector3.new(0, 1, 0)), { Scale = 1.4 })
		end)
	end
	local wave = Instance.new("WedgePart")
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.CastShadow = false
	wave.Material = if frost then Enum.Material.Ice else Enum.Material.Glass
	wave.Color = a.Main
	wave.Transparency = if waveMesh or tidal then 1 else 0.35
	wave.Size = Vector3.new(e.Width, 0.5, 2.5)
	wave.Parent = folder
	Debris:AddItem(wave, e.Sweep + 0.6)
	local start = os.clock()
	local total = e.Sweep + 0.12
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / total, 1)
		local d = e.Length * t
		mover.CFrame = look * CFrame.new(0, 1, -d)
		local h = 3.2 * math.sin(math.pi * math.min(t * 1.15, 1))
		wave.Size = Vector3.new(e.Width, math.max(h, 0.2), 3)
		wave.CFrame = look * CFrame.new(0, h / 2, -d) * CFrame.Angles(0, math.pi, 0)
		if t >= 1 then
			conn:Disconnect()
			spray.Enabled, foam.Enabled = false, false
			tween(wave, 0.3, { Transparency = 1 })
		end
	end)
	-- Ripples / frost patches left along the path.
	for i = 1, 4 do
		local p = startPos + e.Dir * (e.Length * i / 5)
		task.delay(e.Sweep * i / 5, function()
			if frost then
				groundDecal(p, TEX.Crack, a.Core, 3, e.Width * 0.6, 2.2, { Floor = floorY, Hold = 1.4, GrowTime = 0.15, StartAlpha = 0.25 })
				debrisBurst(p + Vector3.new(0, 0.5, 0), a.Core, 2, { Material = Enum.Material.Ice, Size = 0.7, Height = 2, Reach = 3, Floor = floorY })
			else
				ring(p, a.Core, 1, e.Width * 0.9, 0.6, floorY)
			end
		end)
	end
	task.delay(e.Sweep, function()
		burst(endPos + Vector3.new(0, 1.5, 0), {
			{ Texture = if frost then TEX.Shard else TEX.Splash, Count = 26, Size = ns(0, 0.9, 1, 0.2), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(10, 20), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -40, 0), RotSpeed = NumberRange.new(-200, 200), Color = cs(a.Core, a.Main), Light = 0.6 },
		}, 1.2)
	end)
	shake(0.12, startPos)
end

-------------------------------------------------------------------------------
-- Novas: Gust, Firestorm
-------------------------------------------------------------------------------

-- Gust: a two-beat wind spell timed with the cast animation.
--   Gather (Windup): streaks and swirls are sucked inward, a ground ring shrinks.
--   Release: glowing wind ribbons spiral outward in a cyclone, a funnel twists
--   up at your feet, crescent blades and an air dome burst out, dust kicks up.
--   Settle: motes drift down and a soft swirl fades.
-- Blender-made Gust (art/skill_models/gust): a shallow vortex of layered
-- crescent wind arcs, an outer swirl 16 studs wide and a tighter inner swirl,
-- each with ink-black copies of some arcs for the dark accent (GustOuter /
-- GustOuterShade / GustInner / GustInnerShade in the Model
-- RiftboundVFX.GustModel). Each part's "Offset" attribute is its centre
-- relative to the vortex centre on the floor.
local GUST_LOOK = {
	-- The arcs carry the painted lime texture (Gust_Color.png), so they stay white.
	GustOuter = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1), Alpha = 0 },
	GustOuterShade = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Alpha = 0.15 },
	GustInner = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1), Alpha = 0 },
	GustInnerShade = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Alpha = 0.15 },
}
-- Gust's own lime palette, matching the painted arcs.
local GUST_PAL = { Core = rgb(252, 255, 230), Main = rgb(220, 255, 140), Dark = rgb(150, 230, 90) }

local function gustPiece(name)
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local model = templates and templates:FindFirstChild("GustModel")
	local src = model and model:FindFirstChild(name)
	local look = GUST_LOOK[name]
	if not (src and look) then
		return nil
	end
	local p = src:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = look.Material
	p.Color = look.Color
	p.Transparency = look.Alpha
	p.Parent = folder
	return p, look.Alpha
end

-- Plays the Blender pieces at `center` (floor at floorY) for a blast of radius r:
-- the vortex spins open from a tight knot to the edge of the blast, the inner
-- swirl turning faster than the outer, rising from flat to full height, then
-- everything fades while still spinning.
local function gustModel(center, floorY, r)
	local pieces = {}
	for _, name in { "GustOuter", "GustOuterShade", "GustInner", "GustInnerShade" } do
		local p, alpha = gustPiece(name)
		if p then
			pieces[name] = { Part = p, Size = p.Size, Alpha = alpha, Offset = p:GetAttribute("Offset") or Vector3.zero }
		end
	end
	if not pieces.GustOuter then
		for _, pc in pieces do
			pc.Part:Destroy()
		end
		return false
	end
	-- One scale for every piece so the inner and outer swirls keep their proportions.
	local scale = r * 2 / math.max(pieces.GustOuter.Size.X, 0.1)
	local base = Vector3.new(center.X, floorY + 0.05, center.Z)
	local start = os.clock()
	local LIFE = 0.75
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / LIFE, 1)
		local out = 1 - (1 - t) ^ 3
		local fade = math.clamp((t - 0.5) / 0.5, 0, 1)
		for name, pc in pieces do
			local inner = name:find("Inner") ~= nil
			local shade = name:find("Shade") ~= nil
			-- Spins hardest at the start and keeps drifting as it fades.
			local spin = (if inner then 9 else 5.5) * (0.7 * out + 0.3 * t) * (if shade then 0.92 else 1)
			local k = scale * (if inner then 0.45 + 0.65 * out else 0.3 + 0.7 * out)
			local ky = scale * (0.35 + 0.65 * out)
			pc.Part.Size = pc.Size * Vector3.new(k, ky, k)
			pc.Part.CFrame = CFrame.new(base) * CFrame.Angles(0, spin, 0) * CFrame.new(pc.Offset * Vector3.new(k, ky, k))
			pc.Part.Transparency = pc.Alpha + (1 - pc.Alpha) * fade
		end
		if t >= 1 then
			conn:Disconnect()
			for _, pc in pieces do
				pc.Part:Destroy()
			end
		end
	end)
	return true
end

local function gust(e)
	local a = GUST_PAL
	local white = Color3.new(1, 1, 1)
	local floorY = e.Floor or e.At.Y - 2.9
	local center = Vector3.new(e.At.X, floorY + 1.2, e.At.Z)
	local r = e.Radius
	local windup = e.Windup or 0.15
	local Cylinder = Enum.ParticleEmitterShape.Cylinder
	local Surface = Enum.ParticleEmitterShapeStyle.Surface

	-- 1) Gather.
	local gather = anchor(center, Vector3.new(r * 1.6, 2.5, r * 1.6), windup + 1)
	local pullIn = emitter(gather, {
		Enabled = true, Texture = TEX.Spark, Parallel = true,
		Shape = Cylinder, Style = Surface, InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 220, Size = ns(0, 0.25, 0.5, 0.55, 1, 0.2), Lifetime = NumberRange.new(0.14, 0.2),
		Speed = NumberRange.new(r * 4, r * 5), Color = cs(white, a.Main),
		Transparency = ns(0, 0.6, 0.5, 0.1, 1, 0.8), Light = 0.8,
	})
	local swirlIn = emitter(gather, {
		Enabled = true, Texture = TEX.Swirl,
		Shape = Cylinder, Style = Surface, InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 40, Size = ns(0, 3, 1, 1), Lifetime = NumberRange.new(0.15, 0.2),
		Speed = NumberRange.new(r * 3, r * 4), RotSpeed = NumberRange.new(-300, 300),
		Color = cs(white, a.Main), Transparency = ns(0, 0.7, 0.5, 0.3, 1, 1), Light = 0.6,
	})
	groundDecal(center, TEX.Ring, a.Main, r * 1.7, 2, windup + 0.05, { Floor = floorY, StartAlpha = 0.45, GrowTime = windup })

	local function release()
		pullIn.Enabled = false
		swirlIn.Enabled = false

		-- 2a) Cyclone ribbons (trails on points spiralling outward, low to the ground).
		local ribbons = {}
		local function ribbon(base, height, width)
			local p = anchor(center, Vector3.new(0.2, 0.2, 0.2), 1.6)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
			a0.Parent, a1.Parent = p, p
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.42
			trail.MinLength = 0.05
			trail.Color = cs(white, a.Main)
			trail.Transparency = ns(0, 0, 0.5, 0.35, 1, 1)
			trail.WidthScale = ns(0, 1, 1, 0.1)
			trail.LightEmission = 0.9
			trail.LightInfluence = 0
			trail.FaceCamera = true
			trail.Texture = TEX.Glow
			trail.TextureMode = Enum.TextureMode.Stretch
			trail.Parent = p
			table.insert(ribbons, { Part = p, Base = base, Height = height })
		end
		for i = 1, 7 do
			ribbon(i / 7 * math.pi * 2, 0.4 + math.random() * 1.4, 1.7)
		end
		local start = os.clock()
		local LIFE = 0.55
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - start) / LIFE
			if t >= 1 then
				conn:Disconnect()
				return
			end
			local out = 1 - (1 - t) * (1 - t)
			for _, rb in ribbons do
				local radius = 1.2 + (r * 1.05 - 1.2) * out
				local angle = rb.Base + t * 7.5
				local y = rb.Height * math.sin(math.pi * t) - 0.6
				rb.Part.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius))
			end
		end)

		-- 2b) Crescent blades, streaks and dust flying out along the ground.
		local disc = anchor(center, Vector3.new(2, 0.2, 2), 2.5)
		local function radial(s)
			s.Shape = Enum.ParticleEmitterShape.Disc
			s.Style = Surface
			s.InOut = Enum.ParticleEmitterShapeInOut.Outward
			return emitter(disc, s)
		end
		local function blades(count, scale)
			radial({ Texture = TEX.Crescent, Count = count, Parallel = true, Size = ns(0, 2.4 * scale, 0.4, 4.2 * scale, 1, 5 * scale), Transparency = ns(0, 0, 0.7, 0.25, 1, 1), Lifetime = NumberRange.new(0.3, 0.4), Speed = NumberRange.new(r * 2.6, r * 3.2), Color = cs(white, a.Main), Light = 0.8 })
		end
		blades(10, 1)
		task.delay(0.09, function()
			if disc.Parent then
				blades(8, 0.75)
			end
		end)
		radial({ Texture = TEX.Spark, Count = 36, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(r * 3, r * 4.2), Color = cs(white, a.Main), Light = 0.9 })
		radial({ Texture = TEX.Smoke, Count = 22, Light = 0, Size = ns(0, 1.5, 1, 4.5), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(r * 1.4, r * 1.9), Drag = 2.5, Color = cs(rgb(214, 202, 178)) })

		burst(center + Vector3.new(0, 1, 0), {
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, r * 0.8, 1, r * 2.4), Transparency = ns(0, 0, 1, 0.2), Lifetime = NumberRange.new(0.45), Color = cs(white, a.Main), Light = 0.8, ZOffset = 1 },
			{ Texture = TEX.SwirlBurst, Count = 1, Size = ns(0, 5, 1, 9), Lifetime = NumberRange.new(0.5), Color = cs(white, a.Main), Light = 0.6, ZOffset = 1 },
		}, 1.2)

		playTemplate("Wind-01", CFrame.new(center), { Scale = 1.3 })
		playTemplate("Wind-02", CFrame.new(center), { Scale = 1.3 })
		gustModel(center, floorY, r)
		-- Twinkling star sparkles drifting out over the vortex.
		radial({ Texture = TEX.Sparkle, Count = 18, Size = ns(0, 0.9, 0.5, 0.6, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(r * 0.6, r * 1.6), Drag = 3, RotSpeed = NumberRange.new(-90, 90), Color = cs(white, a.Main), Light = 1 })

		-- 2c) Shimmering air dome and ground rings.
		local bubble = Instance.new("Part")
		bubble.Shape = Enum.PartType.Ball
		bubble.Material = Enum.Material.ForceField
		bubble.Color = a.Main
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.CastShadow = false
		bubble.Size = Vector3.one * 3
		bubble.CFrame = CFrame.new(center)
		bubble.Transparency = 0.1
		bubble.Parent = folder
		tween(bubble, 0.35, { Size = Vector3.one * r * 2.1, Transparency = 1 })
		Debris:AddItem(bubble, 0.4)
		ring(center, a.Core, 2, r * 2.3, 0.4, floorY)
		task.delay(0.08, function()
			ring(center, a.Main, 2, r * 1.6, 0.35, floorY)
		end)

		-- 3) Settle: motes drift down over the blast area.
		local settle = anchor(center + Vector3.new(0, 3, 0), Vector3.new(r * 1.6, 1, r * 1.6), 2)
		local motes = emitter(settle, { Enabled = true, Shape = Cylinder, Texture = TEX.Glow, Rate = 30, Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(0.5, 1.5), Dir = Enum.NormalId.Bottom, Accel = Vector3.new(0, -2, 0), Color = cs(white, a.Main), Light = 0.7 })
		task.delay(0.6, function()
			motes.Enabled = false
		end)
		shake(0.2, center)
	end

	task.delay(windup, release)
end

local function onNova(e)
	if e.Skill == "Gust" then
		gust(e)
		return
	end
	local a, b = palettes(e.Skill)
	local floorY = e.Floor or e.At.Y - 2.9
	local center = Vector3.new(e.At.X, floorY + 1.2, e.At.Z)
	local r = e.Radius
	local fire = e.Skill == "Firestorm"
	-- Radial burst from a flat disc: particles fly outward along the ground.
	-- Particles start on a small ring (not one point) so they don't clump at the centre.
	local ringSize = if fire then math.max(r * 0.35, 2) else 2
	local disc = anchor(center, Vector3.new(ringSize, 0.2, ringSize), 2.5)
	local function radial(s)
		s.Shape = Enum.ParticleEmitterShape.Disc
		s.Style = Enum.ParticleEmitterShapeStyle.Surface
		s.InOut = Enum.ParticleEmitterShapeInOut.Outward
		return emitter(disc, s)
	end
	if fire then
		playTemplate("Fire-03", CFrame.new(center), { Scale = 1.4 })
		playTemplate("Fire-02", CFrame.new(center), { Scale = 1.1 })
		radial({ Texture = TEX.Flame, Count = 36, Light = 0.45, Size = ns(0, 3, 1, 1), Transparency = ns(0, 0.15, 0.6, 0.35, 1, 1), Lifetime = NumberRange.new(0.45, 0.6), Speed = NumberRange.new(r * 1.6, r * 2.1), Drag = 2, Accel = Vector3.new(0, 10, 0), RotSpeed = NumberRange.new(-120, 120), Color = cs(a.Main, a.Main, a.Dark) })
		radial({ Texture = TEX.Spark, Count = 50, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(r * 2, r * 3), Accel = Vector3.new(0, 12, 0), Color = cs(a.Core, a.Main) })
		radial({ Texture = TEX.Swirl, Count = 8, Size = ns(0, 3, 1, 5), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(r * 1.5, r * 2), RotSpeed = NumberRange.new(-300, 300), Color = cs(b.Core, b.Main) })
		flash(center, a.Main, r * 2.5, 7, 0.5)
		groundDecal(center, TEX.Crack, rgb(35, 12, 8), r * 0.8, r * 1.4, 2.6, { Floor = floorY, Hold = 1.6, GrowTime = 0.15, StartAlpha = 0.2 })
		-- A lingering ring of flame where the wave stopped.
		task.delay(0.3, function()
			local edge = anchor(center, Vector3.new(r * 2, 0.2, r * 2), 1.6)
			local flames = emitter(edge, { Enabled = true, Texture = TEX.Flame, Shape = Enum.ParticleEmitterShape.Disc, Style = Enum.ParticleEmitterShapeStyle.Surface, InOut = Enum.ParticleEmitterShapeInOut.Outward, Rate = 120, Size = ns(0, 2.4, 1, 0.3), Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 14, 0), Color = cs(a.Core, a.Main, a.Dark) })
			task.delay(0.7, function()
				flames.Enabled = false
			end)
		end)
		shake(0.35, center)
	else
		-- Gust: a whirlwind spins up at your feet, then hurls crescent wind
		-- blades outward behind a shimmering air shockwave and a ring of dust.
		local white = Color3.new(1, 1, 1)
		local vortex = anchor(center + Vector3.new(0, 1.2, 0), Vector3.new(5, 3.5, 5), 1.6)
		local function vortexEmitter(s)
			s.Enabled = true
			s.Locked = true
			s.Shape = Enum.ParticleEmitterShape.Cylinder
			s.Style = Enum.ParticleEmitterShapeStyle.Surface
			s.InOut = Enum.ParticleEmitterShapeInOut.Outward
			return emitter(vortex, s)
		end
		local spin = {
			vortexEmitter({ Texture = TEX.Swirl, Rate = 80, Size = ns(0, 2.2, 1, 3.5), Transparency = ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(0.5, 1.5), Accel = Vector3.new(0, 12, 0), RotSpeed = NumberRange.new(-250, 250), Color = cs(white, a.Main), Light = 0.6 }),
			vortexEmitter({ Texture = TEX.Spark, Parallel = true, Rate = 70, Size = ns(0, 0.45, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(2, 5), Accel = Vector3.new(0, 30, 0), Color = cs(white, a.Main), Light = 0.8 }),
		}
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			vortex.CFrame = CFrame.new(vortex.Position) * CFrame.Angles(0, t * 16, 0)
			if t > 0.45 then
				conn:Disconnect()
				for _, em in spin do
					em.Enabled = false
				end
			end
		end)

		-- Crescent wind blades in two staggered waves (the arc leads the flight).
		local function blades(count, scale)
			radial({ Texture = TEX.Crescent, Count = count, Parallel = true, Size = ns(0, 2.4 * scale, 0.4, 4.2 * scale, 1, 5 * scale), Transparency = ns(0, 0, 0.7, 0.25, 1, 1), Lifetime = NumberRange.new(0.3, 0.4), Speed = NumberRange.new(r * 2.6, r * 3.2), Color = cs(white, a.Main), Light = 0.8 })
		end
		blades(10, 1)
		task.delay(0.09, function()
			if disc.Parent then
				blades(8, 0.75)
			end
		end)
		radial({ Texture = TEX.Spark, Count = 36, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(r * 3, r * 4.2), Color = cs(white, a.Main), Light = 0.9 })
		radial({ Texture = TEX.Smoke, Count = 22, Light = 0, Size = ns(0, 1.5, 1, 4.5), Transparency = ns(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(r * 1.4, r * 1.9), Drag = 2.5, Color = cs(rgb(214, 202, 178)) })

		-- Shimmering air shockwave.
		local bubble = Instance.new("Part")
		bubble.Shape = Enum.PartType.Ball
		bubble.Material = Enum.Material.ForceField
		bubble.Color = a.Main
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.CastShadow = false
		bubble.Size = Vector3.one * 3
		bubble.CFrame = CFrame.new(center)
		bubble.Transparency = 0.1
		bubble.Parent = folder
		tween(bubble, 0.35, { Size = Vector3.one * r * 2.1, Transparency = 1 })
		Debris:AddItem(bubble, 0.4)
		shake(0.18, center)
	end
	ring(center, a.Core, 2, r * 2.3, 0.4, floorY)
	task.delay(0.08, function()
		ring(center, a.Main, 2, r * 1.6, 0.35, floorY)
	end)
end

-------------------------------------------------------------------------------
-- Strikes: Stone Spike, Magma Burst, Magnet Quake
-------------------------------------------------------------------------------

local function onStrike(e)
	local a, b = palettes(e.Skill)
	local floorY = e.At.Y
	local center = e.At
	local r = e.Radius

	-- Telegraph: a spinning rune circle and a filling glow during the delay.
	groundDecal(center, TEX.Telegraph, a.Main, r * 2, r * 2, e.Delay + 0.15, { Floor = floorY, Spin = math.pi * 0.6, FadeIn = 0.1, StartAlpha = 0.15, Hold = e.Delay, Style = Enum.EasingStyle.Linear })
	groundDecal(center, TEX.Glow, a.Main, 0.5, r * 2.2, e.Delay + 0.1, { Floor = floorY, Lift = 0.02, StartAlpha = 0.35, Hold = e.Delay, GrowTime = e.Delay, Style = Enum.EasingStyle.Quad })
	if e.Skill == "MagnetQuake" then
		playTemplate("Charge-01", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.4 })
		-- Arcs crawling in from the rim during the windup.
		task.spawn(function()
			local t = 0
			while t < e.Delay do
				local angle = math.random() * math.pi * 2
				local rim = center + Vector3.new(math.cos(angle) * r, 0.8, math.sin(angle) * r)
				lightning(rim, center + Vector3.new(0, 1, 0), b.Main, { Width = 0.35, Life = 0.15 })
				task.wait(0.07)
				t += 0.07
			end
		end)
	end

	task.delay(e.Delay, function()
		local magma = e.Skill == "MagmaBurst"
		local magnet = e.Skill == "MagnetQuake"
		playTemplate("Crack-01", CFrame.new(center + Vector3.new(0, 0.5, 0)), { Scale = r / 7 })
		if magma then
			playTemplate("Realistic-Explosion-01", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.2 })
			playTemplate("Fire-01", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.3 })
		elseif magnet then
			playTemplate("Lighting-03", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.3, Color = ELECTRIC_TINT })
		else
			playTemplate("Punch-02", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.2 })
		end
		spikes(center, r, if magma then rgb(60, 30, 20) else PAL.Earth.Main, floorY, {
			Count = if r > 10 then 10 else 7,
			Height = if magma then 7 else 6,
			Material = if magma then Enum.Material.Basalt else Enum.Material.Slate,
			Glow = if magma then a.Main elseif magnet then b.Main elseif e.Skill == "StoneSpike" then rgb(255, 160, 50) else nil,
			Mesh = if e.Skill == "StoneSpike" then "StoneSpikeMesh" else nil,
		})
		if e.Skill == "StoneSpike" then
			-- Ink-black shards and grit thrown out with the eruption.
			burst(center + Vector3.new(0, 1, 0), {
				{ Texture = TEX.Spark, Count = 16, Parallel = true, Light = 0, Size = ns(0, 1.4, 1, 0), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(28, 46), Spread = Vector2.new(70, 70), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
				{ Texture = TEX.Rocks, Count = 10, Light = 0, Size = ns(0, 1, 1, 0.6), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(16, 28), Spread = Vector2.new(55, 55), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(Color3.new(0.08, 0.06, 0.05)) },
			}, 1.5)
		end
		local stone = e.Skill == "StoneSpike"
		debrisBurst(center + Vector3.new(0, 0.5, 0), if magma then rgb(255, 120, 40) elseif stone then rgb(48, 38, 32) else PAL.Earth.Dark, if magma then 14 else 12, {
			Floor = floorY,
			Reach = r * 1.1,
			Height = 6,
			Material = if magma then Enum.Material.Neon elseif stone then Enum.Material.Basalt else Enum.Material.Slate,
			Wedge = stone,
		})
		burst(center + Vector3.new(0, 1, 0), {
			{ Texture = TEX.Rocks, Count = 14, Light = 0, Size = ns(0, 1.3, 1, 0.9), Transparency = ns(0, 0, 0.8, 0, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(18, 32), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -60, 0), RotSpeed = NumberRange.new(-300, 300), Color = cs(if magma then rgb(255, 170, 120) else Color3.new(1, 1, 1)) },
			{ Texture = TEX.Dust, Count = 5, Light = 0, Size = ns(0, r * 0.7, 1, r * 1.1), Transparency = ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.7, 0.9), Speed = NumberRange.new(2, 4), Spread = Vector2.new(180, 30), Color = cs(if magma then a.Smoke else PAL.Earth.Smoke) },
			{ Texture = TEX.Smoke, Count = 14, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(6, 14), Spread = Vector2.new(180, 40), Drag = 3, Accel = Vector3.new(0, 3, 0), Color = cs(if magma then a.Smoke else PAL.Earth.Smoke) },
		}, 2)
		groundDecal(center, TEX.Crack, if magma then a.Main else rgb(45, 30, 20), r * 0.8, r * 1.8, if magma then 3 else 2.2, { Floor = floorY, Hold = if magma then 2 else 1.4, GrowTime = 0.12, StartAlpha = 0.1 })
		ring(center, a.Core, 2, r * 2.6, 0.4, floorY)
		if magma then
			-- Lava fountain.
			burst(center + Vector3.new(0, 1, 0), {
				{ Texture = TEX.Flame, Count = 45, Size = ns(0, 4, 1, 1), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(18, 32), Spread = Vector2.new(25, 25), Accel = Vector3.new(0, -35, 0), RotSpeed = NumberRange.new(-120, 120), Color = cs(b.Core, a.Main, a.Dark) },
				{ Texture = TEX.Spark, Count = 50, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(20, 40), Spread = Vector2.new(50, 50), Accel = Vector3.new(0, -40, 0), Color = cs(a.Core, a.Main) },
			}, 2)
			flash(center + Vector3.new(0, 3, 0), a.Main, r * 3, 7, 0.7)
			shake(0.5, center)
		elseif magnet then
			for i = 1, 8 do
				local angle = i / 8 * math.pi * 2
				lightning(center + Vector3.new(0, 1, 0), center + Vector3.new(math.cos(angle) * r * 1.1, 0.6, math.sin(angle) * r * 1.1), b.Main, { Width = 0.5, Life = 0.3 })
			end
			burst(center + Vector3.new(0, 1, 0), {
				{ Texture = TEX.Spark, Count = 60, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(25, 45), Spread = Vector2.new(180, 60), Drag = 2, Color = cs(b.Core, b.Main) },
			}, 1.5)
			flash(center + Vector3.new(0, 3, 0), b.Main, r * 2.5, 7, 0.5)
			shake(0.45, center)
		else
			flash(center + Vector3.new(0, 3, 0), a.Core, r * 2, 3, 0.35)
			shake(0.38, center)
		end
	end)
end

-------------------------------------------------------------------------------
-- Zones: Steam Cloud, Thunderstorm
-------------------------------------------------------------------------------

-- Thunderstorm: gold lightning under a charcoal cloud, with black ink (no
-- purple, matching Magnet Quake).
local STORM = {
	Yellow = rgb(255, 225, 60),
	Amber = rgb(255, 150, 20),
	Cloud = rgb(96, 98, 110),
	CloudDark = rgb(46, 46, 56),
}
local STORM_TINT = cs(Color3.new(1, 1, 1), STORM.Yellow, STORM.Amber)

local function onZone(e)
	local a, b = palettes(e.Skill)
	local floorY = e.At.Y
	local center = e.At
	local r = e.Radius
	local life = e.Duration + 0.6

	ring(center, a.Core, 1, r * 2.2, 0.45, floorY)
	local _, edge = groundDecal(center, TEX.Ring, a.Main, r * 2, r * 2, life, { Floor = floorY, FadeIn = 0.2, StartAlpha = 0.25, Hold = e.Duration })
	groundDecal(center, TEX.Glow, a.Main, r * 2.2, r * 2.2, life, { Floor = floorY, Lift = 0.01, FadeIn = 0.25, StartAlpha = 0.65, Hold = e.Duration })
	local area = anchor(center + Vector3.new(0, 0.6, 0), Vector3.new(r * 1.8, 0.4, r * 1.8), life + 2)
	local emitters = {}
	local function add(s)
		s.Enabled = true
		s.Shape = s.Shape or Enum.ParticleEmitterShape.Cylinder
		s.Style = s.Style or Enum.ParticleEmitterShapeStyle.Volume
		s.InOut = s.InOut or Enum.ParticleEmitterShapeInOut.Outward
		table.insert(emitters, emitter(area, s))
	end
	local spinning
	if e.Skill == "SteamCloud" then
		add({ Texture = TEX.Smoke, Rate = 45, Light = 0.2, Size = ns(0, 3, 1, 8), Transparency = ns(0, 0.6, 0.3, 0.35, 1, 1), Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(1, 3), Accel = Vector3.new(0, 3, 0), RotSpeed = NumberRange.new(-30, 30), Color = cs(Color3.new(1, 1, 1), b.Smoke) })
		add({ Texture = TEX.Spark, Parallel = true, Rate = 25, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 6), Accel = Vector3.new(0, 8, 0), Color = cs(a.Core, a.Main) })
		add({ Texture = TEX.Drop, Rate = 15, Size = ns(0, 0.4, 1, 0.2), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(4, 8), Accel = Vector3.new(0, -20, 0), Color = cs(b.Core, b.Main), Light = 0.5 })
		-- Black ink shade: dark wisps curling low under the white steam, and an
		-- ink ring on the ground at the cloud's edge.
		add({ Texture = TEX.Smoke, Rate = 10, Light = 0, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.75, 0.3, 0.45, 1, 1), Lifetime = NumberRange.new(0.9, 1.4), Speed = NumberRange.new(0.5, 1.5), Accel = Vector3.new(0, 1.5, 0), RotSpeed = NumberRange.new(-60, 60), Color = cs(Color3.new(0, 0, 0)), ZOffset = -1 })
		groundDecal(center, TEX.Ring, Color3.new(0, 0, 0), r * 2.05, r * 2.05, life, { Floor = floorY, Lift = 0.02, FadeIn = 0.2, StartAlpha = 0.35, Hold = e.Duration })
		-- Boiling bubbles and rising heat swirls.
		add({ Texture = TEX.Glow, Rate = 30, Size = ns(0, 0.5, 0.8, 0.3, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(2, 4), Accel = Vector3.new(0, 6, 0), Color = cs(Color3.new(1, 1, 1), b.Core), Light = 0.6 })
		add({ Texture = TEX.Swirl, Rate = 6, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.55, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(2, 3), RotSpeed = NumberRange.new(-120, 120), Color = cs(Color3.new(1, 1, 1), b.Main), Light = 0.4 })
	elseif e.Skill == "Thunderstorm" then
		local cloud = anchor(center + Vector3.new(0, 12, 0), Vector3.new(r * 1.8, 2, r * 1.8), life + 2)
		local function addCloud(s)
			s.Enabled = true
			s.Shape = Enum.ParticleEmitterShape.Box
			table.insert(emitters, emitter(cloud, s))
		end
		addCloud({ Texture = TEX.Smoke, Rate = 28, Light = 0, Size = ns(0, 5, 1, 8), Transparency = ns(0, 0.85, 0.3, 0.55, 1, 1), Lifetime = NumberRange.new(1.5, 2.2), Speed = NumberRange.new(0.3, 1), RotSpeed = NumberRange.new(-20, 20), Color = cs(STORM.Cloud, STORM.CloudDark) })
		-- Black ink shade: a dark underbelly of black smoke below the grey cloud.
		addCloud({ Texture = TEX.Smoke, Rate = 16, Light = 0, Size = ns(0, 4, 1, 7), Transparency = ns(0, 0.9, 0.3, 0.5, 1, 1), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.3, 0.8), Dir = Enum.NormalId.Bottom, RotSpeed = NumberRange.new(-20, 20), Color = cs(Color3.new(0, 0, 0)), ZOffset = -1 })
		addCloud({ Texture = TEX.Glow, Rate = 5, Size = ns(0, 2.5, 1, 0), Lifetime = NumberRange.new(0.1, 0.2), Transparency = ns(0, 0.4, 1, 1), Color = cs(Color3.new(1, 1, 1), STORM.Yellow) })
		-- Driving rain: white streaks with black ink streaks among them.
		addCloud({ Texture = TEX.Spark, Parallel = true, Rate = 90, Size = ns(0, 1.1, 1, 0.8), Transparency = ns(0, 0.15, 1, 0.6), Lifetime = NumberRange.new(0.25, 0.32), Speed = NumberRange.new(38, 46), Dir = Enum.NormalId.Bottom, Spread = Vector2.new(6, 6), Color = cs(rgb(225, 235, 255)), Light = 0.4 })
		addCloud({ Texture = TEX.Spark, Parallel = true, Rate = 30, Size = ns(0, 1.2, 1, 0.8), Transparency = ns(0, 0.05, 1, 0.5), Lifetime = NumberRange.new(0.25, 0.32), Speed = NumberRange.new(38, 46), Dir = Enum.NormalId.Bottom, Spread = Vector2.new(6, 6), Color = cs(Color3.new(0, 0, 0)), Light = 0 })
		add({ Texture = TEX.Swirl, Rate = 12, Size = ns(0, 2, 1, 4), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(1, 2), RotSpeed = NumberRange.new(-200, 200), Color = cs(a.Core, a.Main), Transparency = ns(0, 0.5, 1, 1) })
		add({ Texture = TEX.Swirl, Rate = 6, Light = 0, Size = ns(0, 1.5, 1, 3.5), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(1, 2), RotSpeed = NumberRange.new(-250, 250), Color = cs(Color3.new(0, 0, 0)), Transparency = ns(0, 0.45, 1, 1) })
		-- Rain splashes across the ground.
		add({ Texture = TEX.Spark, Parallel = true, Rate = 30, Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.12, 0.2), Speed = NumberRange.new(6, 10), Spread = Vector2.new(60, 60), Color = cs(rgb(225, 235, 255)), Light = 0.4 })
		-- Ink ring at the storm's edge.
		groundDecal(center, TEX.Ring, Color3.new(0, 0, 0), r * 2.1, r * 2.1, life, { Floor = floorY, Lift = 0.02, FadeIn = 0.2, StartAlpha = 0.3, Hold = e.Duration })
		-- Ambient crackle inside the cloud, some arcs in black ink.
		task.spawn(function()
			local t = 0
			while t < e.Duration do
				local p1 = cloud.Position + Vector3.new((math.random() - 0.5) * r * 1.6, 0, (math.random() - 0.5) * r * 1.6)
				local p2 = cloud.Position + Vector3.new((math.random() - 0.5) * r * 1.6, (math.random() - 0.5) * 2, (math.random() - 0.5) * r * 1.6)
				if math.random() < 0.35 then
					lightning(p1, p2, Color3.new(0, 0, 0), { Width = 0.3, Life = 0.12, Ink = true })
				else
					lightning(p1, p2, STORM.Yellow, { Width = 0.3, Life = 0.12, Halo = STORM.Amber })
				end
				task.wait(0.18 + math.random() * 0.2)
				t += 0.28
			end
		end)
	else
		add({ Texture = TEX.Glow, Rate = 30, Size = ns(0, 1.5, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2), Color = cs(a.Core, a.Main) })
	end

	-- Pulse on every damage tick.
	task.spawn(function()
		local t = 0
		while t < e.Duration do
			task.wait(e.TickRate)
			t += e.TickRate
			if e.Skill ~= "Thunderstorm" then
				ring(center, a.Core, r * 0.3, r * 1.6, 0.4, floorY)
				local pulse = ({ SteamCloud = "Smoke-01" })[e.Skill]
				if pulse then
					local angle = math.random() * math.pi * 2
					local at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r * math.random() * 0.7
					playTemplate(pulse, CFrame.new(at + Vector3.new(0, 1, 0)), { Scale = 0.9 })
				end
				if e.Skill == "SteamCloud" then
					-- A scalding steam geyser bursts from a random spot, with a black puff at its base.
					local angle = math.random() * math.pi * 2
					local at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r * math.random() * 0.75
					burst(at + Vector3.new(0, 0.5, 0), {
						{ Texture = TEX.Smoke, Count = 8, Light = 0.2, Size = ns(0, 1.5, 1, 4.5), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(14, 20), Spread = Vector2.new(12, 12), Drag = 2, Color = cs(Color3.new(1, 1, 1), b.Smoke) },
						{ Texture = TEX.Smoke, Count = 3, Light = 0, Size = ns(0, 1.5, 1, 3), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(2, 4), Spread = Vector2.new(80, 80), Color = cs(Color3.new(0, 0, 0)) },
						{ Texture = TEX.Spark, Count = 8, Parallel = true, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 16), Spread = Vector2.new(25, 25), Color = cs(a.Core, a.Main), Light = 1 },
					}, 1.2)
				end
			end
		end
	end)
	local start = os.clock()
	local conn
	if spinning then
		conn = RunService.RenderStepped:Connect(function()
			spinning.CFrame = CFrame.new(spinning.Position) * CFrame.Angles(0, (os.clock() - start) * 4, 0)
		end)
	end
	task.delay(e.Duration, function()
		for _, em in emitters do
			em.Enabled = false
		end
		if conn then
			task.delay(1.5, function()
				conn:Disconnect()
			end)
		end
		if edge.Parent then
			tween(edge, 0.5, { Transparency = 1 })
		end
	end)
end

-------------------------------------------------------------------------------
-- Bolts: Spark Bolt / Chain Shock jumps, Thunderstorm strikes, fizzles
-------------------------------------------------------------------------------

local function onBolt(e)
	local a, b = palettes(e.Skill)
	local light = if e.Skill == "ChainShock" then b else a
	if e.Strike then
		-- Thunderstorm strike: a thick gold bolt with black ink bolts beside it.
		local floorY = e.To.Y - 2
		local ground = Vector3.new(e.To.X, floorY, e.To.Z)
		playTemplate("Lighting-03", CFrame.new(e.To), { Scale = 1, Color = STORM_TINT })
		lightning(e.From, e.To, Color3.new(0, 0, 0), { Width = 0.8, Life = 0.38, Ink = true })
		lightning(e.From + Vector3.new(-1.2, 0, 0.6), e.To, Color3.new(0, 0, 0), { Width = 0.4, Life = 0.28, Ink = true, NoBranch = true })
		lightning(e.From, e.To, STORM.Yellow, { Width = 1.2, Life = 0.35, Halo = STORM.Amber })
		lightning(e.From + Vector3.new(1, 0, 0), e.To, Color3.new(1, 1, 1), { Width = 0.5, Life = 0.2, Halo = STORM.Amber })
		burst(e.To, {
			{ Texture = TEX.Glow, Count = 1, Size = ns(0, 6, 1, 0), Lifetime = NumberRange.new(0.2), Color = cs(Color3.new(1, 1, 1), STORM.Yellow) },
			{ Texture = TEX.Spark, Count = 30, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(20, 35), Spread = Vector2.new(180, 60), Drag = 3, Color = cs(Color3.new(1, 1, 1), STORM.Yellow) },
			{ Texture = TEX.Electric, Count = 2, Size = ns(0, 3, 1, 4.5), Lifetime = NumberRange.new(0.3), RotSpeed = NumberRange.new(-200, 200), Color = cs(Color3.new(1, 1, 1), STORM.Yellow), Light = 1 },
			-- Black ink shade: black streaks, shards and a puff of dark smoke.
			{ Texture = TEX.Spark, Count = 14, Parallel = true, Light = 0, Size = ns(0, 0.8, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(18, 30), Spread = Vector2.new(180, 50), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
			{ Texture = TEX.Shard, Count = 8, Light = 0, Size = ns(0, 0.8, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(12, 20), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -50, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(Color3.new(0, 0, 0)) },
			{ Texture = TEX.Smoke, Count = 4, Light = 0, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(6, 10), Spread = Vector2.new(180, 20), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
		}, 1)
		burst(ground + Vector3.new(0, 0.6, 0), {
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 1, 1, 10), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(Color3.new(1, 1, 1), STORM.Yellow), Light = 1, ZOffset = 1 },
			{ Texture = TEX.Shockwave, Count = 1, Light = 0, Size = ns(0, 1, 1, 13), Transparency = ns(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.38), Color = cs(Color3.new(0, 0, 0)), ZOffset = 0.5 },
		}, 1)
		debrisBurst(ground + Vector3.new(0, 0.5, 0), rgb(48, 38, 32), 3, { Material = Enum.Material.Basalt, Size = 0.5, Height = 3, Reach = 4, Floor = floorY, Wedge = true })
		ring(e.To, Color3.new(1, 1, 1), 1, 8, 0.3, floorY)
		ring(e.To, Color3.new(0, 0, 0), 1, 12, 0.4, floorY)
		groundDecal(e.To, TEX.Crack, STORM.Yellow, 3, 5, 1.2, { Floor = floorY, Hold = 0.6, GrowTime = 0.08, StartAlpha = 0.2 })
		groundDecal(e.To, TEX.Crack, Color3.new(0, 0, 0), 2.5, 4.2, 1.2, { Floor = floorY, Lift = 0.03, Hold = 0.6, GrowTime = 0.08, StartAlpha = 0.15 })
		flash(e.To + Vector3.new(0, 4, 0), STORM.Yellow, 22, 6, 0.15)
		shake(0.18, e.To)
		return
	end
	if e.Fizzle then
		lightning(e.From, e.To, light.Main, { Width = 0.35, Life = 0.2 })
		burst(e.To, { { Texture = TEX.Spark, Count = 8, Parallel = true, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.2), Speed = NumberRange.new(8, 14), Spread = Vector2.new(180, 180), Color = cs(light.Core, light.Main) } }, 1)
		return
	end
	if e.Skill == "SparkBolt" then
		-- Black ink shade bolts under the glow, each on its own jagged path.
		lightning(e.From, e.To, Color3.new(0, 0, 0), { Width = 0.55, Life = 0.32, Ink = true })
		lightning(e.From, e.To, Color3.new(0, 0, 0), { Width = 0.3, Life = 0.22, Ink = true, NoBranch = true })
	end
	lightning(e.From, e.To, light.Main, { Width = 0.7, Life = 0.3 })
	lightning(e.From, e.To, light.Core, { Width = 0.3, Life = 0.2 })
	playTemplate("Lighting-02", CFrame.new(e.To), { Scale = 0.75, Color = ELECTRIC_TINT })
	if e.Skill == "SparkBolt" then
		-- Muzzle crackle where the bolt leaves, and a bigger hit: a spark
		-- shower, black ink shards, a lingering crackle and a quick shock ring.
		burst(e.From, {
			{ Texture = TEX.Sparkle, Count = 1, Size = ns(0, 1.6, 1, 2.4), Lifetime = NumberRange.new(0.15), Color = cs(light.Core), Light = 1 },
			{ Texture = TEX.Spark, Count = 8, Parallel = true, Size = ns(0, 0.35, 1, 0), Lifetime = NumberRange.new(0.12, 0.2), Speed = NumberRange.new(10, 18), Spread = Vector2.new(180, 180), Color = cs(light.Core, light.Main), Light = 1 },
		}, 0.5)
		burst(e.To, {
			{ Texture = TEX.Spark, Count = 22, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(16, 28), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(light.Core, light.Main), Light = 1 },
			{ Texture = TEX.Spark, Count = 10, Parallel = true, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(12, 22), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(Color3.new(0, 0, 0)), Light = 0 },
			{ Texture = TEX.Electric, Count = 3, Size = ns(0, 2.5, 1, 3.5), Lifetime = NumberRange.new(0.35, 0.5), RotSpeed = NumberRange.new(-200, 200), Color = cs(light.Core, light.Main), Light = 1 },
			{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 1, 1, 7), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.25), Color = cs(light.Core, light.Main), Light = 1, ZOffset = 1 },
		}, 1)
	end
	burst(e.To, {
		{ Texture = TEX.Electric, Count = 2, Size = ns(0, 4, 1, 5), Lifetime = NumberRange.new(0.3), Color = cs(light.Core, light.Main), Light = 1 },
		{ Texture = TEX.Sparkle, Count = 1, Size = ns(0, 2.5, 1, 3), Lifetime = NumberRange.new(0.3), Color = cs(light.Core), Light = 1 },
	}, 1)
	flash(e.To, light.Core, 14, 4, 0.15)
	if e.Skill == "ChainShock" then
		burst(e.To, { { Texture = TEX.Drop, Count = 12, Light = 0.6, Size = ns(0, 0.6, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(8, 14), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -35, 0), Color = cs(a.Core, a.Main) } }, 1)
	end
end

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Firestorm: a fire tornado that drags enemies into its centre.
-------------------------------------------------------------------------------

-- Blender-made fire tornado (art/skill_models/firestorm), built the way Harry
-- Alisavakis's stylised tornado is: four nested, noise-displaced funnel layers
-- painted with 45-degree noise streaks in banded colours with holes cut out
-- (white-hot inside to red-black outside), plus spiral planes at the bottom and
-- top (FireLayer1-4 / FireSpiralBottom / FireSpiralTop in the Model
-- RiftboundVFX.FirestormModel). Roblox can't pan textures, so each layer spins
-- at its own speed instead, which turns the tilted streaks into a rising swirl.
-- About 14 studs tall. Each part's "Offset" attribute is its centre relative to
-- the funnel's base on the floor.
local FIRESTORM_PARTS = {
	-- Spin speeds (radians per second); inner layers spin fastest.
	FireLayer1 = 9,
	FireLayer2 = 7,
	FireLayer3 = 5.5,
	FireLayer4 = 4,
	FireSpiralBottom = 3,
	FireSpiralTop = 4.5,
}
-- The same atlas with more of the noise cut away, swapped in to dissolve it.
local FIRESTORM_ERODE = { "rbxassetid://134760698364137", "rbxassetid://109304087267820" }

-- Preload the VFX templates' textures (and the dissolve textures) so the
-- first cast doesn't flash untextured white meshes.
task.spawn(function()
	local list = table.clone(FIRESTORM_ERODE)
	local vfx = ReplicatedStorage:WaitForChild("RiftboundVFX", 10)
	if vfx then
		table.insert(list, vfx)
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

-- Plays the funnel at `center` on floorY for D seconds: it twists up out of the
-- ground, sways while it spins, then erodes away. Returns false when the
-- templates are missing.
local function firestormModel(center, floorY, D)
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local model = templates and templates:FindFirstChild("FirestormModel")
	if not (model and model:FindFirstChild("FireLayer1")) then
		return false
	end
	local pieces = {}
	for name, speed in FIRESTORM_PARTS do
		local src = model:FindFirstChild(name)
		if src then
			local p = src:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = folder
			table.insert(pieces, { Part = p, Size = p.Size, Offset = p:GetAttribute("Offset") or Vector3.zero, Speed = speed, Flat = name == "FireSpiralBottom" })
		end
	end
	local base = Vector3.new(center.X, floorY, center.Z)
	local start = os.clock()
	local erodeStep = 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local grow = math.clamp(t / 0.35, 0, 1)
		grow = 1 - (1 - grow) ^ 3
		-- Dissolve: two more-eroded textures, then a short fade.
		local out = t - D
		local step = if out > 0.3 then 2 elseif out > 0 then 1 else 0
		if step ~= erodeStep then
			erodeStep = step
			for _, pc in pieces do
				pc.Part.TextureID = FIRESTORM_ERODE[step]
			end
		end
		local fade = math.clamp((out - 0.3) / 0.35, 0, 1)
		local h = math.max(grow, 0.02) * (1 + 0.15 * math.clamp(out / 0.6, 0, 1))
		local w = 0.5 + 0.5 * grow + 0.2 * math.clamp(out / 0.6, 0, 1)
		-- A slow sway so the funnel leans and snakes as it spins.
		local sway = CFrame.Angles(math.sin(t * 2.3) * 0.06, 0, math.cos(t * 1.9) * 0.06)
		for _, pc in pieces do
			local sy = if pc.Flat then 1 else h
			pc.Part.Size = pc.Size * Vector3.new(w, sy, w)
			local tilt = if pc.Flat then CFrame.identity else sway
			pc.Part.CFrame = CFrame.new(base) * tilt * CFrame.Angles(0, t * pc.Speed, 0) * CFrame.new(pc.Offset * Vector3.new(w, sy, w))
			pc.Part.Transparency = fade
		end
		if fade >= 1 then
			conn:Disconnect()
			for _, pc in pieces do
				pc.Part:Destroy()
			end
		end
	end)
	return true
end

-- Deep red that sits alongside the black shade in Firestorm.
local FIRESTORM_RED = rgb(225, 30, 20)
local FIRESTORM_BLOOD = rgb(110, 0, 8)

local function onTornado(e)
	local a = palettes(e.Skill)
	local center = e.At
	local floorY = center.Y
	local r = e.Radius
	local D = e.Duration
	local white = Color3.new(1, 1, 1)
	local emitters, spinners, cleanup = {}, {}, {}

	playTemplate("Fire-03", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.3 })
	firestormModel(center, floorY, D)
	ring(center, a.Core, 2, r * 2.4, 0.4, floorY)
	local _, edge = groundDecal(center, TEX.Ring, a.Main, r * 2, r * 2, D + 0.6, { Floor = floorY, FadeIn = 0.2, StartAlpha = 0.15, Hold = D, Spin = math.pi * 2 })
	groundDecal(center, TEX.Glow, a.Main, r * 1.2, r * 2.2, D + 0.6, { Floor = floorY, Lift = 0.01, FadeIn = 0.3, StartAlpha = 0.45, Hold = D })
	groundDecal(center, TEX.Crack, rgb(40, 14, 8), r * 0.8, r * 1.3, D + 2, { Floor = floorY, Lift = 0.02, StartAlpha = 0.25, Hold = D + 0.8, GrowTime = 0.3 })

	-- The funnel: stacked spinning rings with flames locked to them, widening upwards.
	local LAYERS = 5
	for i = 0, LAYERS - 1 do
		local height = 0.8 + i * 2.3
		local radius = 1.4 + i * 1.25
		local layer = anchor(CFrame.new(center + Vector3.new(0, height, 0)), Vector3.new(radius * 2, 0.6, radius * 2), D + 2)
		local flames = emitter(layer, {
			Enabled = true, Texture = TEX.Flame, Locked = true,
			Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 34 - i * 3, Size = ns(0, 2.4 + i * 0.35, 1, 1.4 + i * 0.3), Transparency = ns(0, 0.1, 0.7, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(0.5, 1.5), Accel = Vector3.new(0, 6, 0),
			Color = cs(a.Core, a.Main, a.Dark), Light = 0.6,
		})
		table.insert(emitters, flames)
		if i >= 2 then
			table.insert(emitters, emitter(layer, {
				Enabled = true, Texture = TEX.Swirl, Locked = true,
				Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
				Rate = 6, Size = ns(0, 3, 1, 5), Transparency = ns(0, 0.35, 1, 1),
				Lifetime = NumberRange.new(0.4, 0.6), Color = cs(a.Core, a.Main), Light = 0.6,
			}))
		end
		table.insert(spinners, { Part = layer, Speed = 9 - i * 0.9, Y = height })
	end

	-- Fire ribbons spiralling up the funnel.
	local ribbons = {}
	for i = 1, 3 do
		local p = anchor(CFrame.new(center), Vector3.new(0.2, 0.2, 0.2), D + 1)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
		a0.Parent, a1.Parent = p, p
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.35
		trail.Color = cs(a.Core, a.Main)
		trail.Transparency = ns(0, 0.05, 0.6, 0.45, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.1)
		trail.LightEmission = 0.9
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Texture = TEX.Glow
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Parent = p
		table.insert(ribbons, { Part = p, Trail = trail, Phase = i / 3, Scale = 1 })
	end
	-- Black ink shade: two black smoke ribbons spiralling just outside the fire.
	for i = 1, 2 do
		local p = anchor(CFrame.new(center), Vector3.new(0.2, 0.2, 0.2), D + 1)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.45, 0), Vector3.new(0, -0.45, 0)
		a0.Parent, a1.Parent = p, p
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.3
		trail.Color = cs(Color3.new(0, 0, 0))
		trail.Transparency = ns(0, 0.1, 0.6, 0.5, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.1)
		trail.LightEmission = 0
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Parent = p
		table.insert(ribbons, { Part = p, Trail = trail, Phase = i / 2 + 0.17, Scale = 1.2 })
	end
	-- Deep red ribbons between the fire and the black shade.
	for i = 1, 2 do
		local p = anchor(CFrame.new(center), Vector3.new(0.2, 0.2, 0.2), D + 1)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.6, 0), Vector3.new(0, -0.6, 0)
		a0.Parent, a1.Parent = p, p
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.32
		trail.Color = cs(FIRESTORM_RED, FIRESTORM_BLOOD)
		trail.Transparency = ns(0, 0.05, 0.6, 0.45, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.1)
		trail.LightEmission = 0.5
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Texture = TEX.Glow
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Parent = p
		table.insert(ribbons, { Part = p, Trail = trail, Phase = i / 2 + 0.42, Scale = 1.1 })
	end

	-- Embers sucked inward from the edge (the pull, made visible).
	local field = anchor(CFrame.new(center + Vector3.new(0, 1.5, 0)), Vector3.new(r * 2, 2, r * 2), D + 2)
	table.insert(emitters, emitter(field, {
		Enabled = true, Texture = TEX.Spark, Parallel = true,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 70, Size = ns(0, 0.5, 1, 0.1), Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(r * 1.6, r * 2.2), Accel = Vector3.new(0, 8, 0), Color = cs(a.Core, a.Main), Light = 0.9,
	}))
	table.insert(emitters, emitter(field, {
		Enabled = true, Texture = TEX.Spark, Parallel = true, Light = 0,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 25, Size = ns(0, 0.8, 1, 0.1), Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(r * 1.6, r * 2.2), Accel = Vector3.new(0, 8, 0), Color = cs(Color3.new(0, 0, 0)),
	}))
	groundDecal(center, TEX.Ring, Color3.new(0, 0, 0), r * 2.1, r * 2.1, D + 0.6, { Floor = floorY, Lift = 0.03, FadeIn = 0.2, StartAlpha = 0.3, Hold = D })
	-- Red alongside the black: crimson embers in the pull, a blood-red glow and ring under the funnel.
	table.insert(emitters, emitter(field, {
		Enabled = true, Texture = TEX.Spark, Parallel = true, Light = 0.5,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 35, Size = ns(0, 0.7, 1, 0.1), Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(r * 1.6, r * 2.2), Accel = Vector3.new(0, 8, 0), Color = cs(FIRESTORM_RED, FIRESTORM_BLOOD),
	}))
	groundDecal(center, TEX.Glow, FIRESTORM_RED, r * 1.4, r * 2.4, D + 0.6, { Floor = floorY, Lift = 0.015, FadeIn = 0.25, StartAlpha = 0.5, Hold = D })
	groundDecal(center, TEX.Ring, FIRESTORM_BLOOD, r * 1.85, r * 1.85, D + 0.6, { Floor = floorY, Lift = 0.025, FadeIn = 0.2, StartAlpha = 0.35, Hold = D, Spin = -math.pi * 2 })
	-- A roaring flame column up the core, and a ring of low flames around the edge.
	local core = anchor(CFrame.new(center + Vector3.new(0, 0.5, 0)), Vector3.new(2, 0.5, 2), D + 2)
	table.insert(emitters, emitter(core, {
		Enabled = true, Texture = TEX.Flame, Shape = Enum.ParticleEmitterShape.Cylinder,
		Rate = 40, Size = ns(0, 3, 0.6, 2.4, 1, 0.6), Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(16, 22), RotSpeed = NumberRange.new(-120, 120), Color = cs(a.Core, a.Main, FIRESTORM_RED), Light = 0.9,
	}))
	local edgeFire = anchor(CFrame.new(center + Vector3.new(0, 0.3, 0)), Vector3.new(r * 1.9, 0.3, r * 1.9), D + 2)
	table.insert(emitters, emitter(edgeFire, {
		Enabled = true, Texture = TEX.Flame,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = 50, Size = ns(0, 1.8, 1, 0.4), Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(2, 4), Accel = Vector3.new(0, 6, 0), RotSpeed = NumberRange.new(-90, 90), Color = cs(a.Core, a.Main, FIRESTORM_RED), Light = 0.8,
	}))
	-- Ignition: a fire burst, a red-black shockwave and flung cinders.
	burst(center + Vector3.new(0, 1.5, 0), {
		{ Texture = TEX.FireBurst, Count = 3, Size = ns(0, r * 0.6, 1, r * 1.2), Transparency = ns(0, 0, 1, 0.4), Lifetime = NumberRange.new(0.4, 0.5), Color = cs(a.Core, a.Main, FIRESTORM_RED), Light = 0.85 },
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, r * 0.4, 1, r * 2.6), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.35), Color = cs(a.Core, FIRESTORM_RED), Light = 1, ZOffset = 1 },
		{ Texture = TEX.Spark, Count = 30, Parallel = true, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(20, 32), Spread = Vector2.new(180, 50), Drag = 2, Color = cs(a.Core, FIRESTORM_RED), Light = 1 },
		{ Texture = TEX.Spark, Count = 14, Parallel = true, Light = 0, Size = ns(0, 0.9, 1, 0), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(16, 26), Spread = Vector2.new(180, 50), Drag = 2, Color = cs(Color3.new(0, 0, 0)) },
	}, 1.5)
	-- Fire crescents whipping around the top of the funnel, and embers flung off the rim.
	table.insert(emitters, emitter(spinners[LAYERS].Part, {
		Enabled = true, Texture = TEX.Crescent, Locked = true,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = 10, Size = ns(0, 3, 1, 5), Transparency = ns(0, 0.1, 0.7, 0.4, 1, 1),
		Lifetime = NumberRange.new(0.25, 0.35), Color = cs(a.Core, a.Main), Light = 0.9,
	}))
	table.insert(emitters, emitter(spinners[LAYERS].Part, {
		Enabled = true, Texture = TEX.Spark, Parallel = true,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = 40, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(8, 14), Spread = Vector2.new(40, 40), Accel = Vector3.new(0, -12, 0), Color = cs(a.Core, a.Main), Light = 1,
	}))
	-- Heat pulses rippling out across the ground.
	task.spawn(function()
		local t = 0
		while t < D do
			ring(center, a.Main, r * 0.3, r * 1.9, 0.45, floorY)
			task.wait(0.5)
			t += 0.5
		end
	end)
	-- Smoke venting from the top.
	local top = anchor(CFrame.new(center + Vector3.new(0, 12, 0)), Vector3.new(6, 1, 6), D + 3)
	table.insert(emitters, emitter(top, {
		Enabled = true, Texture = TEX.Smoke, Rate = 12, Light = 0, Size = ns(0, 4, 1, 9),
		Transparency = ns(0, 0.55, 1, 1), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(2, 4),
		RotSpeed = NumberRange.new(-60, 60), Color = cs(FIRESTORM_BLOOD, Color3.new(0.05, 0.03, 0.03)),
	}))
	local glow = Instance.new("PointLight")
	glow.Color = a.Main
	glow.Range = r * 2.2
	glow.Shadows = false
	glow.Parent = spinners[3].Part

	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- Grow in over 0.3 s, shrink out over the last 0.4 s.
		local grow = math.clamp(t / 0.3, 0, 1) * math.clamp((D - t) / 0.4 + 1, 0, 1)
		for _, sp in spinners do
			sp.Part.CFrame = CFrame.new(center + Vector3.new(0, sp.Y * (0.4 + 0.6 * grow), 0)) * CFrame.Angles(0, t * sp.Speed, 0)
		end
		for _, rb in ribbons do
			local k = (t * 0.9 + rb.Phase) % 1
			local height = k * 11
			local radius = (1.4 + height * 0.55) * (0.4 + 0.6 * grow) * rb.Scale
			local angle = t * 11 + rb.Phase * math.pi * 2
			if k < 0.03 then
				rb.Trail:Clear()
			end
			rb.Part.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, 0.6 + height, math.sin(angle) * radius))
		end
		glow.Brightness = (1.4 + math.noise(t * 8, 0.5) * 0.8) * grow
		if t > D then
			conn:Disconnect()
			for _, em in emitters do
				em.Enabled = false
			end
			for _, rb in ribbons do
				rb.Trail.Enabled = false
			end
			glow.Enabled = false
			playTemplate("Fire-02", CFrame.new(center + Vector3.new(0, 2, 0)), { Scale = 1.2 })
			-- Collapse: the funnel bursts apart in fire, red and black.
			burst(center + Vector3.new(0, 4, 0), {
				{ Texture = TEX.Flame, Count = 24, Size = ns(0, 3, 1, 0.8), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(14, 24), Spread = Vector2.new(180, 180), Drag = 3, RotSpeed = NumberRange.new(-150, 150), Color = cs(a.Core, a.Main, FIRESTORM_RED), Light = 0.9 },
				{ Texture = TEX.Smoke, Count = 8, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(6, 12), Spread = Vector2.new(180, 180), Drag = 2, Color = cs(FIRESTORM_BLOOD, Color3.new(0, 0, 0)) },
				{ Texture = TEX.Spark, Count = 16, Parallel = true, Light = 0, Size = ns(0, 1, 1, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(18, 28), Spread = Vector2.new(180, 180), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
			}, 2)
			ring(center, FIRESTORM_RED, 2, r * 2.4, 0.4, floorY)
			if edge.Parent then
				tween(edge, 0.4, { Transparency = 1 })
			end
		end
	end)
	shake(0.25, center)
end

-------------------------------------------------------------------------------
-- Magnet Quake: a magnetic core that yanks enemies in, then detonates.
-------------------------------------------------------------------------------

local magnets = {} -- [skill event] -> state, so the blast can find its core
-- Magnet Quake is gold and yellow with black ink (the user asked for no purple).
local MAGNET = { Yellow = rgb(255, 225, 60), Amber = rgb(255, 150, 20) }
local MAGNET_TINT = cs(Color3.new(1, 1, 1), MAGNET.Yellow, MAGNET.Amber)

local function nearbyEnemies(center, radius)
	local list = {}
	local enemies = workspace:FindFirstChild("RiftEnemies")
	for _, m in (enemies and enemies:GetChildren() or {}) do
		local root = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
			if d <= radius then
				table.insert(list, root)
			end
		end
	end
	return list
end

local function onMagnet(e)
	local a, b = palettes(e.Skill) -- Earth, Lightning
	local center = e.At
	local floorY = center.Y
	local r = e.Radius
	local T = e.PullTime or 0.6
	local yellow = MAGNET.Yellow
	local orbPos = center + Vector3.new(0, 3.5, 0)

	-- Imploding rune circle.
	groundDecal(center, TEX.Telegraph, b.Main, r * 2.2, 2, T + 0.1, { Floor = floorY, Spin = math.pi * 3, StartAlpha = 0.1, GrowTime = T, Style = Enum.EasingStyle.Quad })
	groundDecal(center, TEX.Ring, yellow, r * 2.4, 1, T, { Floor = floorY, Lift = 0.01, StartAlpha = 0.2, GrowTime = T })
	-- Black ink shade: a second rune circle turning the other way, and a black
	-- ring closing in just outside the yellow one.
	groundDecal(center, TEX.Telegraph, Color3.new(0, 0, 0), r * 2.5, 2.5, T + 0.1, { Floor = floorY, Lift = 0.02, Spin = -math.pi * 2, StartAlpha = 0.35, GrowTime = T, Style = Enum.EasingStyle.Quad })
	groundDecal(center, TEX.Ring, Color3.new(0, 0, 0), r * 2.7, 1.5, T, { Floor = floorY, Lift = 0.03, StartAlpha = 0.15, GrowTime = T })

	-- The core: a crackling orb inside a pulsing field.
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = b.Core
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Size = Vector3.one * 0.5
	core.CFrame = CFrame.new(orbPos)
	core.Parent = folder
	local field = core:Clone()
	field.Material = Enum.Material.ForceField
	field.Color = yellow
	field.Size = Vector3.one * 2
	field.Parent = folder
	tween(core, T, { Size = Vector3.one * 1.8 }, Enum.EasingStyle.Back)
	local coreAtt = Instance.new("Attachment")
	coreAtt.Parent = core
	local light = Instance.new("PointLight")
	light.Color = b.Main
	light.Range = r * 1.6
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core
	emitter(core, { Enabled = true, Texture = TEX.Electric, Rate = 14, Size = ns(0, 3, 1, 4), Lifetime = NumberRange.new(0.25, 0.3), Color = cs(b.Core, b.Main), Light = 1 })
	emitter(core, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 40, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.15, 0.25), Speed = NumberRange.new(8, 14), Spread = Vector2.new(180, 180), Color = cs(b.Core, yellow), Light = 1 })
	playTemplate("Charge-01", CFrame.new(orbPos), { Scale = 1.3, Color = MAGNET_TINT })

	-- Inward streaks across the whole field.
	local pullField = anchor(CFrame.new(center + Vector3.new(0, 1.5, 0)), Vector3.new(r * 2, 3, r * 2), T + 1.5)
	local streaks = emitter(pullField, {
		Enabled = true, Texture = TEX.Spark, Parallel = true,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 160, Size = ns(0, 0.4, 0.5, 0.7, 1, 0.2), Lifetime = NumberRange.new(0.18, 0.25),
		Speed = NumberRange.new(r * 4, r * 5.5), Color = cs(b.Core, yellow), Light = 1,
	})
	-- Black ink streaks, dark dust and rocks torn off the ground, all dragged in.
	local inkStreaks = emitter(pullField, {
		Enabled = true, Texture = TEX.Spark, Parallel = true,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 60, Size = ns(0, 0.6, 0.5, 0.9, 1, 0.3), Lifetime = NumberRange.new(0.18, 0.25),
		Speed = NumberRange.new(r * 4, r * 5.5), Color = cs(Color3.new(0, 0, 0)), Light = 0,
	})
	local pullRocks = emitter(pullField, {
		Enabled = true, Texture = TEX.Rocks,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 30, Size = ns(0, 0.9, 1, 0.3), Lifetime = NumberRange.new(0.3, 0.4),
		Speed = NumberRange.new(r * 2.5, r * 3), RotSpeed = NumberRange.new(-400, 400), Color = cs(a.Main, Color3.new(0, 0, 0)), Light = 0,
	})
	local pullDust = emitter(pullField, {
		Enabled = true, Texture = TEX.Smoke,
		Shape = Enum.ParticleEmitterShape.Cylinder, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 20, Size = ns(0, 3, 1, 1), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.35, 0.45),
		Speed = NumberRange.new(r * 2, r * 2.5), RotSpeed = NumberRange.new(-200, 200), Color = cs(Color3.new(0, 0, 0)), Light = 0,
	})
	-- Black shards spiralling into the core.
	local coreInk = emitter(core, {
		Enabled = true, Texture = TEX.Shard,
		Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface,
		InOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 30, Size = ns(0, 0.8, 1, 0.2), Lifetime = NumberRange.new(0.2, 0.3),
		Speed = NumberRange.new(10, 14), RotSpeed = NumberRange.new(-500, 500), Color = cs(Color3.new(0, 0, 0)), Light = 0,
	})
	-- Magnetic arcs snapping from the core to the ground, some in black ink.
	task.spawn(function()
		local t = 0
		while t < T do
			local angle = math.random() * math.pi * 2
			local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r * (0.3 + math.random() * 0.5) + Vector3.new(0, 0.3, 0)
			if math.random() < 0.4 then
				lightning(orbPos, spot, Color3.new(0, 0, 0), { Width = 0.35, Life = 0.15, Ink = true, NoBranch = true, Halo = MAGNET.Amber })
			else
				lightning(orbPos, spot, if math.random() < 0.5 then b.Main else yellow, { Width = 0.4, Life = 0.15, NoBranch = true, Halo = MAGNET.Amber })
			end
			task.wait(0.07)
			t += 0.07
		end
	end)

	-- Lightning tethers from the core to every enemy being dragged in.
	local tethers = {} -- [enemyRoot] = { Beam, Att }
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > T or not core.Parent then
			conn:Disconnect()
			streaks.Enabled = false
			inkStreaks.Enabled, pullRocks.Enabled, pullDust.Enabled, coreInk.Enabled = false, false, false, false
			for _, tether in tethers do
				tether.Beam:Destroy()
				tether.Att:Destroy()
			end
			return
		end
		field.Size = Vector3.one * (2 + math.sin(t * 30) * 0.4 + t * 3)
		field.CFrame = CFrame.new(orbPos) * CFrame.Angles(t * 3, t * 5, 0)
		for _, root in nearbyEnemies(center, r) do
			local tether = tethers[root]
			if not tether then
				local att = Instance.new("Attachment")
				att.Parent = core
				local beam = Instance.new("Beam")
				beam.Attachment0 = coreAtt
				beam.Attachment1 = att
				beam.Texture = TEX.Lightning
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = 6
				beam.TextureSpeed = 8
				beam.Width0, beam.Width1 = 1.2, 0.7
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Color = cs(b.Core, yellow)
				beam.Parent = core
				tether = { Beam = beam, Att = att, Next = 0, Ink = true }
				tethers[root] = tether
			end
			tether.Att.WorldPosition = root.Position
			tether.Beam.CurveSize0 = (math.random() - 0.5) * 4
			tether.Beam.CurveSize1 = (math.random() - 0.5) * 4
			-- Jagged bolts flickering along the tether, alternating black ink and glow.
			if t >= tether.Next then
				tether.Next = t + 0.08
				tether.Ink = not tether.Ink
				if tether.Ink then
					lightning(orbPos, root.Position, Color3.new(0, 0, 0), { Width = 0.3, Life = 0.1, Ink = true, NoBranch = true, Halo = MAGNET.Amber })
				else
					lightning(orbPos, root.Position, if math.random() < 0.5 then b.Main else yellow, { Width = 0.35, Life = 0.1, NoBranch = true, Halo = MAGNET.Amber })
				end
			end
		end
	end)
	magnets[e.Skill .. tostring(center)] = { Core = core, Field = field }
	task.delay(T + 2, function()
		magnets[e.Skill .. tostring(center)] = nil
		if core.Parent then
			core:Destroy()
		end
		if field.Parent then
			field:Destroy()
		end
	end)
	shake(0.15, center)
end

local function onMagnetBlast(e)
	local a, b = palettes(e.Skill)
	local center = e.At
	local floorY = center.Y
	local r = e.Radius
	local yellow = MAGNET.Yellow
	local orbPos = center + Vector3.new(0, 3.5, 0)
	local state = magnets[e.Skill .. tostring(center)]
	if state then
		tween(state.Core, 0.12, { Size = Vector3.one * 6, Transparency = 1 })
		tween(state.Field, 0.2, { Size = Vector3.one * r * 1.6, Transparency = 1 })
	end
	-- Radial discharge.
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2 + math.random() * 0.3
		local reach = r * (0.7 + math.random() * 0.5)
		local tip = center + Vector3.new(math.cos(angle) * reach, 0.6, math.sin(angle) * reach)
		lightning(orbPos, tip, if i % 2 == 0 then b.Main else yellow, { Width = 0.7, Life = 0.35, Halo = MAGNET.Amber })
		-- Black ink bolt on its own path beside every other one.
		if i % 2 == 1 then
			lightning(orbPos, tip, Color3.new(0, 0, 0), { Width = 0.45, Life = 0.32, Ink = true })
		end
	end
	-- Black ink shade: an ink shockwave behind the glowing one, black smoke
	-- rolling out, black shards and streaks flung outward.
	burst(orbPos, {
		{ Texture = TEX.Shockwave, Count = 1, Light = 0, Size = ns(0, r * 0.5, 1, r * 2.6), Transparency = ns(0, 0.15, 1, 1), Lifetime = NumberRange.new(0.45), Color = cs(Color3.new(0, 0, 0)), ZOffset = 0.5 },
		{ Texture = TEX.Smoke, Count = 12, Light = 0, Size = ns(0, 3, 1, 7), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(20, 32), Spread = Vector2.new(180, 25), Drag = 4, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Shard, Count = 18, Light = 0, Size = ns(0, 1, 1, 0.3), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(25, 40), Spread = Vector2.new(180, 60), Drag = 2, RotSpeed = NumberRange.new(-500, 500), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Spark, Count = 30, Parallel = true, Light = 0, Size = ns(0, 1, 1, 0), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(35, 55), Spread = Vector2.new(180, 70), Drag = 2, Color = cs(Color3.new(0, 0, 0)) },
	}, 2)
	-- Rocks blown off the ground, light and dark.
	debrisBurst(center + Vector3.new(0, 0.5, 0), a.Main, 8, { Material = Enum.Material.Slate, Size = 0.9, Height = 6, Reach = r * 0.9, Floor = floorY })
	debrisBurst(center + Vector3.new(0, 0.5, 0), rgb(48, 38, 32), 6, { Material = Enum.Material.Basalt, Size = 0.8, Height = 5, Reach = r * 0.7, Floor = floorY, Wedge = true })
	playTemplate("Lighting-03", CFrame.new(center + Vector3.new(0, 1, 0)), { Scale = 1.6, Color = MAGNET_TINT })
	burst(orbPos, {
		{ Texture = TEX.ThunderWave, Count = 1, Size = ns(0, r * 0.6, 1, r * 2), Transparency = ns(0, 0, 1, 0.3), Lifetime = NumberRange.new(0.4), Color = cs(b.Core, b.Main), Light = 1, ZOffset = 1 },
		{ Texture = TEX.Electric, Count = 5, Size = ns(0, 5, 1, 7), Lifetime = NumberRange.new(0.3), Spread = Vector2.new(180, 180), Speed = NumberRange.new(4, 8), Color = cs(b.Core, yellow), Light = 1 },
		{ Texture = TEX.Spark, Count = 70, Parallel = true, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(30, 55), Spread = Vector2.new(180, 70), Drag = 2, Color = cs(b.Core, b.Main), Light = 1 },
		{ Texture = TEX.Dust, Count = 4, Light = 0, Size = ns(0, r * 0.6, 1, r), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.6, 0.8), Speed = NumberRange.new(2, 4), Spread = Vector2.new(180, 20), Color = cs(PAL.Earth.Smoke) },
	}, 2)
	ring(center, b.Core, 2, r * 2.6, 0.35, floorY)
	task.delay(0.07, function()
		ring(center, yellow, 2, r * 2, 0.4, floorY)
	end)
	groundDecal(center, TEX.Crack, b.Main, r * 0.6, r * 1.2, 2, { Floor = floorY, Lift = 0.02, StartAlpha = 0.1, Hold = 1.2, GrowTime = 0.1 })
	-- Black ink cracks over the glowing ones, and a black ring just outside.
	groundDecal(center, TEX.Crack, Color3.new(0, 0, 0), r * 0.5, r * 1.05, 2, { Floor = floorY, Lift = 0.04, StartAlpha = 0.2, Hold = 1.2, GrowTime = 0.1 })
	task.delay(0.1, function()
		ring(center, Color3.new(0, 0, 0), 2, r * 3, 0.45, floorY)
	end)
	flash(orbPos, b.Main, r * 3, 9, 0.5)
	shake(0.6, center)
end

-------------------------------------------------------------------------------
-- Thunder Serpent (skill id ChainShock): a serpent of water with lightning
-- running through it slithers along the ground through the crowd, biting as
-- it goes, then dives into the ground. The body is a set of trails left by a
-- weaving head: the anime water strip, a white-hot lightning core and a black
-- ink shade, with sparks arcing along it.
-------------------------------------------------------------------------------

local SERPENT = {
	White = rgb(240, 252, 255),
	Aqua = rgb(120, 220, 255),
	Blue = rgb(40, 140, 235),
	Deep = rgb(20, 60, 150),
	Volt = rgb(255, 235, 120),
}
-- Blender serpent size (1 Blender unit = 1 stud at scale 1) and body length.
local SERPENT_SCALE = 0.9
local SERPENT_SEGMENTS = 11

local function serpentTrail(parent, width, life, color, opts)
	opts = opts or {}
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0) + (opts.Offset or Vector3.zero)
	a1.Position = Vector3.new(0, -width / 2, 0) + (opts.Offset or Vector3.zero)
	a0.Parent, a1.Parent = parent, parent
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	if opts.Texture then
		t.Texture = opts.Texture
		t.TextureMode = Enum.TextureMode.Wrap
		t.TextureLength = opts.TextureLength or 8
	end
	t.Lifetime = life
	t.MinLength = 0.05
	t.Color = cs(color)
	t.Transparency = opts.Transparency or ns(0, 0, 0.7, 0.3, 1, 1)
	t.WidthScale = opts.WidthScale or ns(0, 1, 0.15, 1.1, 1, 0.1)
	t.LightEmission = opts.Light or 0
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Parent = parent
	return t
end

local function onSerpent(e)
	local points = e.Points
	if not points or #points < 2 then
		return
	end
	local floorY = e.Floor or points[1].Y
	local speed = e.Speed or 48
	-- Cumulative distance along the route.
	local dists = { 0 }
	for i = 2, #points do
		dists[i] = dists[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	local total = dists[#points]
	local duration = total / speed
	local function along(d)
		for i = 2, #points do
			if d <= dists[i] or i == #points then
				local seg = dists[i] - dists[i - 1]
				local k = if seg > 0 then math.clamp((d - dists[i - 1]) / seg, 0, 1) else 1
				return points[i - 1]:Lerp(points[i], k), (points[i] - points[i - 1])
			end
		end
		return points[#points], points[#points] - points[#points - 1]
	end

	-- Burst out of the ground in front of the caster.
	local start = points[1]
	burst(start + Vector3.new(0, 0.5, 0), {
		{ Texture = TEX.Splash, Count = 10, Size = ns(0, 1.2, 1, 0.4), Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(10, 16), Spread = Vector2.new(40, 40), Accel = Vector3.new(0, -45, 0), Color = cs(SERPENT.White, SERPENT.Aqua), Light = 0.5 },
		{ Texture = TEX.Smoke, Count = 3, Light = 0, Size = ns(0, 1.5, 1, 3), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(4, 7), Spread = Vector2.new(70, 70), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Spark, Count = 10, Parallel = true, Size = ns(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(14, 22), Spread = Vector2.new(60, 60), Color = cs(Color3.new(1, 1, 1), SERPENT.Volt), Light = 1 },
	}, 1)
	ring(start, SERPENT.Aqua, 1, 7, 0.35, floorY)
	ring(start, Color3.new(0, 0, 0), 1, 9, 0.4, floorY)

	-- A ball-shaped neon part with an optional SpecialMesh stretch.
	local function orb(color, material, scale)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Material = material or Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.one
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		if scale then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Scale = scale
			m.Parent = p
		end
		p.Parent = folder
		return p
	end

	-- The serpent itself. RiftboundVFX.SerpentModel may hold SerpentHead (the
	-- free Creator Store "Dragon Head" 1513601847, tinted water-blue), and the
	-- Blender SerpentSegment / SerpentTail. Each template can carry "Offset"
	-- (pivot to the piece's origin) and "Orient" (turns it to face -Z). Any
	-- piece that is missing falls back to glowing orbs with black ink shades.
	-- Each piece: { Part, Rel (offset from its spine point), Size (base size),
	-- Pulse (size wobble) }. Body entries also carry Back: studs behind the head.
	local head = anchor(CFrame.new(start), Vector3.new(0.2, 0.2, 0.2), duration + 1.5)
	templates = templates or ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local model = templates and templates:FindFirstChild("SerpentModel")
	local function meshPiece(name, scale)
		local src = model and model:FindFirstChild(name)
		if not src then
			return nil
		end
		local p = src:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = src.Size * scale
		p.Parent = folder
		local rel = CFrame.new((src:GetAttribute("Offset") or Vector3.zero) * scale) * (src:GetAttribute("Orient") or CFrame.identity)
		return { Part = p, Rel = rel, Size = p.Size, Pulse = 0.04 }
	end
	local headParts, body = {}, {}
	local SPACING = 0.85
	local meshHead = meshPiece("SerpentHead", SERPENT_SCALE)
	if meshHead then
		table.insert(headParts, meshHead)
		-- Black ink shade: a dark copy just under and behind the head.
		local ink = meshPiece("SerpentHead", SERPENT_SCALE * 1.05)
		ink.Part.Material = Enum.Material.SmoothPlastic
		ink.Part.Color = Color3.new(0, 0, 0)
		ink.Part.Transparency = 0.15
		ink.Rel = CFrame.new(0, -0.18, 0.12) * ink.Rel
		table.insert(headParts, ink)
	else
		local skull = orb(SERPENT.Aqua, nil, Vector3.new(1.7, 1.3, 2.6))
		local inkSkull = orb(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Vector3.new(1.8, 1.1, 2.8))
		inkSkull.Transparency = 0.1
		local snout = orb(SERPENT.White, nil, Vector3.new(0.9, 0.7, 1.4))
		for _, spec in {
			{ skull, CFrame.identity },
			{ inkSkull, CFrame.new(0, -0.3, 0.15) },
			{ snout, CFrame.new(0, -0.1, -1.1) },
			{ orb(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Vector3.new(0.35, 0.3, 0.5)), CFrame.new(0.55, 0.45, -0.55) },
			{ orb(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Vector3.new(0.35, 0.3, 0.5)), CFrame.new(-0.55, 0.45, -0.55) },
		} do
			table.insert(headParts, { Part = spec[1], Rel = spec[2], Size = spec[1].Size, Pulse = 0 })
		end
	end
	-- The neck starts behind the head.
	local neck = if meshHead then 1.3 * SERPENT_SCALE else 0.6
	if model and model:FindFirstChild("SerpentSegment") and model:FindFirstChild("SerpentTail") then
		local back = neck
		for i = 1, SERPENT_SEGMENTS do
			local k = (i - 1) / (SERPENT_SEGMENTS - 1)
			local s = SERPENT_SCALE * (1.05 - 0.55 * k)
			back += 1.05 * s
			table.insert(body, { Back = back, Parts = { meshPiece("SerpentSegment", s) } })
		end
		local tailScale = SERPENT_SCALE * 0.55
		back += 0.9 * tailScale
		table.insert(body, { Back = back, Parts = { meshPiece("SerpentTail", tailScale) } })
	elseif not meshHead then
		-- No model at all: a glowing orb body. With the dragon head the body is
		-- just the water, ink and lightning trails streaming behind it.
		for i = 1, 16 do
			local k = i / 16
			local size = 1.9 * (1 - k) + 0.45 * k
			local seg = orb(SERPENT.Aqua:Lerp(SERPENT.Blue, k), nil, nil)
			seg.Size = Vector3.one * size
			seg.Transparency = 0.05 + 0.25 * k
			local ink = orb(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, nil)
			ink.Size = Vector3.one * size * 1.08
			ink.Transparency = 0.15
			local parts = {
				{ Part = seg, Rel = CFrame.identity, Size = seg.Size, Pulse = 0.08 },
				{ Part = ink, Rel = CFrame.new(0, -size * 0.18, 0), Size = ink.Size, Pulse = 0.08 },
			}
			if i % 4 == 2 then
				local spark = orb(SERPENT.Volt, nil, nil)
				spark.Size = Vector3.one * size * 0.45
				table.insert(parts, { Part = spark, Rel = CFrame.new(0, size * 0.15, 0), Size = spark.Size, Pulse = 0 })
			end
			table.insert(body, { Back = neck + (i - 1) * SPACING, Parts = parts })
		end
	end
	local bodyLength = if #body > 0 then body[#body].Back else 9
	local light = Instance.new("PointLight")
	light.Color = SERPENT.Aqua
	light.Range = 12
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = head
	-- Trails streaming behind the head: the wide anime water ribbon, a black ink
	-- shade under it, a gold lightning core and a thin white streak on top.
	local trails = {
		serpentTrail(head, 2.8, 0.42, Color3.new(1, 1, 1), { Texture = ANIME_WATER_TRAIL, TextureLength = 7, Light = 0.35 }),
		serpentTrail(head, 3.4, 0.36, Color3.new(0, 0, 0), { Offset = Vector3.new(0, -0.5, 0), Transparency = ns(0, 0.2, 0.7, 0.45, 1, 1) }),
		serpentTrail(head, 0.7, 0.34, SERPENT.Volt, { Light = 1, Transparency = ns(0, 0, 0.8, 0.4, 1, 1) }),
		serpentTrail(head, 0.3, 0.38, Color3.new(1, 1, 1), { Light = 1, Offset = Vector3.new(0, 0.6, 0), Transparency = ns(0, 0, 1, 1) }),
	}
	local emitters = {
		-- Spray and foam thrown off the head, black splatter, crackling sparks.
		emitter(head, { Enabled = true, Texture = TEX.Splash, Rate = 40, Size = ns(0, 0.8, 1, 0.3), Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(5, 10), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -40, 0), Color = cs(SERPENT.White, SERPENT.Aqua), Light = 0.5 }),
		emitter(head, { Enabled = true, Texture = TEX.Drop, Rate = 14, Light = 0, Size = ns(0, 0.5, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(5, 9), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -40, 0), Color = cs(Color3.new(0, 0, 0)) }),
		emitter(head, { Enabled = true, Texture = TEX.Spark, Parallel = true, Rate = 40, Size = ns(0, 0.45, 1, 0), Lifetime = NumberRange.new(0.12, 0.22), Speed = NumberRange.new(8, 16), Spread = Vector2.new(180, 180), Color = cs(Color3.new(1, 1, 1), SERPENT.Volt), Light = 1 }),
		emitter(head, { Enabled = true, Texture = TEX.Electric, Rate = 8, Size = ns(0, 2.2, 1, 3), Lifetime = NumberRange.new(0.15, 0.2), RotSpeed = NumberRange.new(-200, 200), Color = cs(Color3.new(1, 1, 1), SERPENT.Aqua), Light = 1 }),
	}

	-- Path history: where the head has been and how far it had travelled.
	local history = { { Pos = start + Vector3.new(0, -1, 0), D = 0 } }
	local travelled = 0
	local function bodyAt(back)
		-- Position `back` studs behind the head along its own path.
		local target = travelled - back
		for i = #history, 2, -1 do
			local a, b = history[i - 1], history[i]
			if a.D <= target then
				local span = b.D - a.D
				local k = if span > 0 then (target - a.D) / span else 0
				return a.Pos:Lerp(b.Pos, k)
			end
		end
		return history[1].Pos
	end

	local startClock = os.clock()
	local lastArc, lastWake = 0, 0
	local ended, endClock = false, 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startClock
		local d = math.min(t * speed, total)
		local pos, segDir = along(d)
		local fwd = if segDir.Magnitude > 0.01 then segDir.Unit else Vector3.zAxis
		local side = fwd:Cross(Vector3.yAxis)
		-- Weave side to side and bob, rising out of the ground at the start
		-- and diving back in at the end.
		local rise = math.clamp(t / 0.15, 0, 1)
		local dive = math.clamp((d - (total - 4)) / 4, 0, 1)
		local weave = math.sin(t * 14) * 1.4
		local bob = 1.5 + math.sin(t * 8) * 0.5
		local p = pos + side * weave + Vector3.new(0, -1 + (bob + 1) * rise - (bob + 2.5) * dive, 0)
		local last = history[#history]
		local step = (p - last.Pos).Magnitude
		if step > 0.05 then
			travelled += step
			table.insert(history, { Pos = p, D = travelled })
			if #history > 200 then
				table.remove(history, 1)
			end
		end
		local ahead = p - bodyAt(0.6)
		local cf = CFrame.lookAt(p, p + (if ahead.Magnitude > 0.01 then ahead else fwd))
		head.CFrame = cf
		for _, piece in headParts do
			piece.Part.CFrame = cf * piece.Rel
		end
		for i, seg in body do
			-- Each segment faces along the body, toward the one in front of it.
			local at = bodyAt(seg.Back)
			local toward = bodyAt(math.max(seg.Back - 0.6, 0)) - at
			local segCf = if toward.Magnitude > 0.01 then CFrame.lookAt(at, at + toward) else CFrame.new(at)
			local pulse = math.sin(t * 20 - i * 0.7)
			for _, piece in seg.Parts do
				piece.Part.Size = piece.Size * (1 + piece.Pulse * pulse)
				piece.Part.CFrame = segCf * piece.Rel
			end
		end
		-- Lightning arcing along the body, some in black ink.
		if t - lastArc > 0.05 and travelled > 4 then
			lastArc = t
			local from = math.random() * bodyLength * 0.8
			local a, b = bodyAt(from), bodyAt(from + 2 + math.random() * 2)
			if math.random() < 0.35 then
				lightning(a, b, Color3.new(0, 0, 0), { Width = 0.3, Life = 0.1, Ink = true, NoBranch = true })
			else
				lightning(a, b, SERPENT.Volt, { Width = 0.35, Life = 0.1, NoBranch = true, Halo = SERPENT.Blue })
			end
		end
		-- Wake on the ground: ripples and a blue glow.
		if d - lastWake > 3 then
			lastWake = d
			ring(pos, SERPENT.Aqua, 0.5, 4.5, 0.35, floorY)
			groundDecal(pos, TEX.Glow, SERPENT.Blue, 2, 3.5, 0.6, { Floor = floorY, Lift = 0.01, StartAlpha = 0.5, GrowTime = 0.1 })
		end
		if d >= total and not ended then
			ended, endClock = true, os.clock()
			for _, em in emitters do
				em.Enabled = false
			end
			for _, tr in trails do
				tr.Enabled = false
			end
			tween(light, 0.3, { Brightness = 0 })
			for _, piece in headParts do
				piece.Part:Destroy()
			end
		end
		-- After the head dives, the body keeps pouring into the ground behind it.
		if ended then
			travelled += speed * (os.clock() - endClock)
			endClock = os.clock()
			table.insert(history, { Pos = p, D = travelled })
			if os.clock() - startClock > duration + (bodyLength + 1) / speed + 0.1 then
				conn:Disconnect()
				for _, seg in body do
					for _, piece in seg.Parts do
						piece.Part:Destroy()
					end
				end
			end
		end
	end)
	shake(0.1, start)
end

local function onSerpentBite(e)
	local at = e.At
	local floorY = e.Floor or at.Y - 2.9
	-- Jaws: two crossed white slashes snapping shut, each with a black copy.
	burst(at, {
		{ Texture = TEX.Spark, Count = 2, Parallel = true, Size = ns(0, 3.4, 1, 0), Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(0.5, 1), Spread = Vector2.new(180, 180), Color = cs(Color3.new(1, 1, 1), SERPENT.Aqua), Light = 1, ZOffset = 1.5 },
		{ Texture = TEX.Spark, Count = 2, Parallel = true, Light = 0, Size = ns(0, 3.8, 1, 0), Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(0.5, 1), Spread = Vector2.new(180, 180), Color = cs(Color3.new(0, 0, 0)), ZOffset = 1.2 },
		{ Texture = TEX.Splash, Count = 12, Size = ns(0, 1, 1, 0.3), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 16), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -45, 0), Color = cs(SERPENT.White, SERPENT.Aqua), Light = 0.5 },
		{ Texture = TEX.Drop, Count = 6, Light = 0, Size = ns(0, 0.6, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(8, 13), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -45, 0), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Electric, Count = 2, Size = ns(0, 3, 1, 4), Lifetime = NumberRange.new(0.25), RotSpeed = NumberRange.new(-200, 200), Color = cs(Color3.new(1, 1, 1), SERPENT.Volt), Light = 1 },
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 0.8, 1, 6), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.25), Color = cs(Color3.new(1, 1, 1), SERPENT.Aqua), Light = 1, ZOffset = 1 },
	}, 1)
	-- A jolt of lightning up through the victim, and a black one beside it.
	lightning(Vector3.new(at.X, floorY, at.Z), at + Vector3.new(0, 4, 0), SERPENT.Volt, { Width = 0.5, Life = 0.2, Halo = SERPENT.Blue })
	lightning(Vector3.new(at.X + 0.6, floorY, at.Z), at + Vector3.new(0.4, 3.5, 0), Color3.new(0, 0, 0), { Width = 0.35, Life = 0.18, Ink = true, NoBranch = true })
	ring(at, SERPENT.Aqua, 1, 6, 0.3, floorY)
	ring(at, Color3.new(0, 0, 0), 1, 7.5, 0.35, floorY)
	flash(at, SERPENT.Aqua, 10, 3, 0.15)
end

local function onSerpentDive(e)
	local at = e.At
	local floorY = e.Floor or at.Y
	local ground = Vector3.new(at.X, floorY, at.Z)
	-- The serpent plunges in: a water column, a splash ring, black splatter
	-- and lightning discharging into the ground.
	burst(ground + Vector3.new(0, 0.5, 0), {
		{ Texture = TEX.Splash, Count = 22, Size = ns(0, 1.4, 1, 0.4), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(16, 26), Spread = Vector2.new(25, 25), Accel = Vector3.new(0, -50, 0), Color = cs(SERPENT.White, SERPENT.Aqua), Light = 0.5 },
		{ Texture = TEX.WaterFoam, Count = 4, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(2, 4), Spread = Vector2.new(180, 20), Color = cs(SERPENT.White), Light = 0.4 },
		{ Texture = TEX.Drop, Count = 10, Light = 0, Size = ns(0, 0.7, 1, 0.2), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(10, 18), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -50, 0), Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Smoke, Count = 4, Light = 0, Size = ns(0, 2, 1, 4.5), Transparency = ns(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(6, 10), Spread = Vector2.new(180, 15), Drag = 3, Color = cs(Color3.new(0, 0, 0)) },
		{ Texture = TEX.Shockwave, Count = 1, Size = ns(0, 1, 1, 9), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.3), Color = cs(Color3.new(1, 1, 1), SERPENT.Aqua), Light = 1, ZOffset = 1 },
	}, 1.5)
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2 + math.random() * 0.4
		local tip = ground + Vector3.new(math.cos(angle) * 5, 0.3, math.sin(angle) * 5)
		if i % 2 == 0 then
			lightning(ground + Vector3.new(0, 1, 0), tip, Color3.new(0, 0, 0), { Width = 0.35, Life = 0.2, Ink = true, NoBranch = true })
		else
			lightning(ground + Vector3.new(0, 1, 0), tip, SERPENT.Volt, { Width = 0.45, Life = 0.22, NoBranch = true, Halo = SERPENT.Blue })
		end
	end
	ring(ground, SERPENT.Aqua, 1, 10, 0.4, floorY)
	ring(ground, Color3.new(0, 0, 0), 1, 12, 0.45, floorY)
	groundDecal(ground, TEX.Crack, Color3.new(0, 0, 0), 2, 4.5, 1.2, { Floor = floorY, Lift = 0.03, Hold = 0.6, GrowTime = 0.08, StartAlpha = 0.2 })
	flash(ground + Vector3.new(0, 2, 0), SERPENT.Aqua, 14, 4, 0.25)
	shake(0.15, ground)
end

local function onHeal(e)
	local root = e.Target
	if root and root.Parent then
		playTemplate("Heal", root.CFrame, { Follow = root })
	end
end

local function onLevelUp(e)
	local root = e.Target
	if root and root.Parent then
		playTemplate("Shiny-01", root.CFrame, { Follow = root, Scale = 1.2 })
		playTemplate("Charge-01", root.CFrame * CFrame.new(0, -2, 0), { Scale = 1.1 })
		ring(root.Position, rgb(255, 215, 90), 2, 22, 0.6, root.Position.Y - 2.9)
	end
end

local HANDLERS = {
	Shield = onShield,
	Blocked = onBlocked,
	Roller = onRoller,
	RollerEnd = onRollerEnd,
	Meteor = onMeteor,
	Leap = onLeap,
	LeapSlam = onLeapSlam,
	GolemSlam = onGolemSlam,
	GolemSpawn = onGolemSpawn,
	Cone = onCone,
	Tornado = onTornado,
	Magnet = onMagnet,
	MagnetBlast = onMagnetBlast,
	Serpent = onSerpent,
	SerpentBite = onSerpentBite,
	SerpentDive = onSerpentDive,
	Heal = onHeal,
	LevelUp = onLevelUp,
	Cast = onCast,
	Impact = onImpact,
	ProjectileStart = onProjectileStart,
	ProjectileEnd = onProjectileEnd,
	Line = onLine,
	Nova = onNova,
	Strike = onStrike,
	Zone = onZone,
	Bolt = onBolt,
}

function SkillVFX.Init(Remotes, cameraRig)
	camera = cameraRig
	folder = Instance.new("Folder")
	folder.Name = "RiftVFX"
	folder.Parent = workspace
	Remotes:WaitForChild("SkillFx").OnClientEvent:Connect(function(e)
		local handler = typeof(e) == "table" and HANDLERS[e.Type]
		-- Awakened skills look like their skill (bigger numbers come in the event).
		if handler and type(e.Skill) == "string" and e.Skill:sub(-8) == "Awakened" then
			e.Skill = e.Skill:sub(1, -9)
		end
		if handler then
			local ok, err = pcall(handler, e)
			if not ok then
				warn("SkillVFX", e.Type, e.Skill, err)
			end
		end
	end)
end

return SkillVFX
