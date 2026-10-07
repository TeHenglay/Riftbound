-- Client-side status effects on enemies, driven by the server's attributes
-- Status_Burn / Status_Soak / Status_Slow / Status_Stun / Status_Shock, plus a
-- burst when an elemental reaction fires (Reaction + ReactionAt).
--   Burn:  flames licking up the body, embers, smoke and a flickering glow.
--   Soak:  water dripping off, a damp mist and splash ripples at the feet.
--   Shock: lightning arcs crackling across the body, sparks, a stuttering light.
--   Slow:  cold mist creeping around the feet.
--   Stun:  rift crystals orbiting the head.
--   Freeze: encased in a block of ice with crystals jutting out; it shatters
--           when the freeze ends.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local UIAssets = require(Shared:WaitForChild("UIAssets"))
local Lib = require(Shared:WaitForChild("VfxLibrary"))

local Fx = UIAssets.Fx
local STATUSES = { "Burn", "Soak", "Slow", "Stun", "Shock", "Freeze" }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COLORS = {
	Burn = { Core = rgb(255, 240, 190), Main = rgb(255, 122, 40), Dark = rgb(150, 30, 10) },
	Soak = { Core = rgb(225, 248, 255), Main = rgb(70, 160, 255), Dark = rgb(25, 70, 160) },
	Slow = { Core = rgb(235, 250, 255), Main = rgb(150, 210, 255), Dark = rgb(80, 130, 200) },
	Stun = { Core = rgb(245, 230, 255), Main = rgb(200, 160, 255), Dark = rgb(110, 70, 180) },
	Shock = { Core = rgb(255, 255, 230), Main = rgb(250, 225, 60), Dark = rgb(170, 120, 255) },
	Freeze = { Core = rgb(245, 252, 255), Main = rgb(170, 225, 255), Dark = rgb(70, 140, 220) },
}

local StatusVFX = {}

local tracked = {} -- [model] = { Body, Head, Root, Effects = { [status] = effect } }

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

local function emitter(parent, s)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = s.Rate ~= nil and s.Rate > 0
	Lib.Apply(e, s.Texture or Fx.Glow)
	e.Color = s.Color
	e.Size = s.Size or ns(1)
	e.Transparency = s.Transparency or ns(0, 0, 0.7, 0.3, 1, 1)
	e.Lifetime = s.Lifetime or NumberRange.new(0.5)
	e.Speed = s.Speed or NumberRange.new(0)
	e.SpreadAngle = s.Spread or Vector2.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = s.RotSpeed or NumberRange.new(0)
	e.Acceleration = s.Accel or Vector3.zero
	e.Drag = s.Drag or 0
	e.LightEmission = s.Light or 0.7
	e.LightInfluence = 0
	e.Rate = s.Rate or 0
	e.EmissionDirection = s.Dir or Enum.NormalId.Top
	e.ZOffset = s.ZOffset or 0.5
	if s.Parallel then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	e.Parent = parent
	if s.Count then
		e:Emit(s.Count)
	end
	return e
end

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- A quick jagged arc between two attachments on the body.
local function arc(body, color)
	local size = body.Size
	local function randomPoint()
		return Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z)
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = randomPoint(), randomPoint()
	a0.Parent, a1.Parent = body, body
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Fx.Lightning
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Width0, beam.Width1 = 0.9, 0.9
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = cs(Color3.new(1, 1, 1):Lerp(color, 0.3))
	beam.CurveSize0 = (math.random() - 0.5) * 3
	beam.CurveSize1 = (math.random() - 0.5) * 3
	beam.Parent = body
	Debris:AddItem(beam, 0.09)
	Debris:AddItem(a0, 0.09)
	Debris:AddItem(a1, 0.09)
end

-- Expanding ring decal on the floor under the enemy.
local function floorRing(root, color, size, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 0.05, 1)
	p.CFrame = CFrame.new(root.Position.X, root.Position.Y - 1.95, root.Position.Z)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Fx.Ring
	d.Color3 = color
	d.Transparency = 0.2
	d.Parent = p
	p.Parent = workspace:FindFirstChild("RiftVFX") or workspace
	TweenService:Create(p, TweenInfo.new(life), { Size = Vector3.new(size, 0.05, size) }):Play()
	TweenService:Create(d, TweenInfo.new(life), { Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.05)
end

-------------------------------------------------------------------------------
-- Status effects. Each returns { Instances, Update(dt, t) }.
-------------------------------------------------------------------------------

local MAKERS = {}

function MAKERS.Burn(rig)
	local c = COLORS.Burn
	local body = rig.Body
	local items = {
		emitter(body, { Texture = Lib.Flame, Rate = 22, Size = ns(0, 2.2, 0.5, 3, 1, 1.6), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(2, 4), Spread = Vector2.new(20, 20), Accel = Vector3.new(0, 7, 0), RotSpeed = NumberRange.new(-80, 80), Color = cs(c.Core, c.Main, c.Dark), Light = 0.8 }),
		emitter(body, { Texture = Lib.FireLick, Rate = 14, Size = ns(0, 1.6, 1, 1.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(1, 3), Accel = Vector3.new(0, 6, 0), Color = cs(c.Main), Light = 0.8 }),
		emitter(body, { Texture = Fx.Spark, Parallel = true, Rate = 12, Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 6), Spread = Vector2.new(35, 35), Accel = Vector3.new(0, 9, 0), Color = cs(c.Core, c.Main), Light = 1 }),
		emitter(body, { Texture = Lib.Smoke, Rate = 6, Light = 0, Size = ns(0, 1.2, 1, 3.5), Transparency = ns(0, 0.6, 1, 1), Lifetime = NumberRange.new(0.9, 1.3), Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 4, 0), Color = cs(rgb(60, 40, 36)) }),
	}
	local light = pointLight(body, c.Main, 10, 1.4)
	table.insert(items, light)
	return {
		Instances = items,
		Update = function(_, t)
			-- Fire flicker.
			light.Brightness = 1 + math.noise(t * 9, 0.3) * 0.8 + 0.3 * math.sin(t * 23)
		end,
	}
end

function MAKERS.Soak(rig)
	local c = COLORS.Soak
	local body = rig.Body
	local nextRipple = 0
	local items = {
		emitter(body, { Texture = Fx.Drop, Rate = 16, Size = ns(0, 0.35, 1, 0.25), Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(0, 1), Dir = Enum.NormalId.Bottom, Accel = Vector3.new(0, -35, 0), Color = cs(c.Core, c.Main), Light = 0.5, Transparency = ns(0, 0.15, 1, 0.6) }),
		emitter(body, { Texture = Fx.Glow, Rate = 8, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0.3, 0.8), Spread = Vector2.new(180, 180), Color = cs(c.Main), Transparency = ns(0, 0.5, 1, 1), Light = 0.6 }),
		emitter(body, { Texture = Fx.Smoke, Rate = 5, Light = 0, Size = ns(0, 1.5, 1, 3), Transparency = ns(0, 0.75, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.3, 0.8), Color = cs(c.Core) }),
	}
	return {
		Instances = items,
		Update = function(_, t)
			if t > nextRipple and rig.Root.Parent then
				nextRipple = t + 0.7 + math.random() * 0.4
				floorRing(rig.Root, c.Main, 5, 0.6)
			end
		end,
	}
end

function MAKERS.Shock(rig)
	local c = COLORS.Shock
	local body = rig.Body
	local nextArc = 0
	local items = {
		emitter(body, { Texture = Fx.Spark, Parallel = true, Rate = 22, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.12, 0.25), Speed = NumberRange.new(8, 16), Spread = Vector2.new(180, 180), Drag = 4, Color = cs(c.Core, c.Main), Light = 1 }),
		emitter(body, { Texture = Lib.Electric, Rate = 7, Size = ns(0, 2.6, 1, 3.2), Lifetime = NumberRange.new(0.25, 0.3), Color = cs(c.Core, c.Main), Light = 1 }),
	}
	local light = pointLight(body, c.Main, 9, 0)
	table.insert(items, light)
	return {
		Instances = items,
		Update = function(_, t)
			if t > nextArc then
				nextArc = t + 0.08 + math.random() * 0.18
				arc(body, if math.random() < 0.3 then c.Dark else c.Main)
				light.Brightness = 2.2
			else
				light.Brightness = math.max(light.Brightness - 0.35, 0)
			end
		end,
	}
end

function MAKERS.Slow(rig)
	local c = COLORS.Slow
	local items = {
		emitter(rig.Body, { Texture = Fx.Smoke, Rate = 9, Light = 0.2, Size = ns(0, 1.5, 1, 3.5), Transparency = ns(0, 0.55, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.5, 1), Dir = Enum.NormalId.Bottom, Accel = Vector3.new(0, -1, 0), Color = cs(c.Core, c.Main) }),
		emitter(rig.Body, { Texture = Fx.Swirl, Rate = 4, Size = ns(0, 1, 1, 2), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(0.5, 1), RotSpeed = NumberRange.new(-150, 150), Color = cs(c.Main), Transparency = ns(0, 0.5, 1, 1) }),
	}
	return { Instances = items, Update = function() end }
end

function MAKERS.Stun(rig)
	local c = COLORS.Stun
	local crystals = {}
	for i = 1, 3 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = if i == 2 then c.Core else c.Main
		p.Size = Vector3.new(0.35, 0.7, 0.35)
		p.Parent = workspace:FindFirstChild("RiftVFX") or workspace
		pointLight(p, c.Main, 4, 0.8)
		table.insert(crystals, p)
	end
	local haze = emitter(rig.Body, { Texture = Fx.Glow, Rate = 6, Size = ns(0, 1, 1, 0), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(1, 2), Spread = Vector2.new(30, 30), Color = cs(c.Main), Transparency = ns(0, 0.5, 1, 1) })
	local items = { haze }
	for _, p in crystals do
		table.insert(items, p)
	end
	return {
		Instances = items,
		Update = function(_, t)
			local head = rig.Head
			if not head or not head.Parent then
				return
			end
			local top = head.Position + Vector3.new(0, 1.3, 0)
			for i, p in crystals do
				local a = t * 4 + i / 3 * math.pi * 2
				p.CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 1.3, math.sin(t * 6 + i) * 0.15, math.sin(a) * 1.3)) * CFrame.Angles(0, -a, 0.4)
			end
		end,
	}
end

function MAKERS.Freeze(rig)
	local c = COLORS.Freeze
	local model = rig.Root.Parent
	local vfx = workspace:FindFirstChild("RiftVFX") or workspace
	local boxCf, boxSize = model:GetBoundingBox()
	boxSize = Vector3.new(math.min(boxSize.X, 7), math.min(boxSize.Y, 9), math.min(boxSize.Z, 7)) * 1.08
	local rel = rig.Root.CFrame:ToObjectSpace(boxCf)
	local function solid(p)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = vfx
		return p
	end
	-- A block of clear ice around the body...
	local block = Instance.new("Part")
	block.Material = Enum.Material.Glass
	block.Color = c.Main
	block.Transparency = 0.5
	block.Size = boxSize * 0.4
	solid(block)
	TweenService:Create(block, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = boxSize }):Play()
	-- ...with ice crystals jutting out around its base.
	local crystals = {}
	local source = ReplicatedStorage:FindFirstChild("RiftboundVFX")
	source = source and source:FindFirstChild("IceCrystal")
	for i = 1, 5 do
		local p = if source then source:Clone() else Instance.new("WedgePart")
		local h = boxSize.Y * (0.35 + math.random() * 0.25)
		p.Size = if source then p.Size * (h / p.Size.Y) else Vector3.new(h * 0.4, h, h * 0.4)
		if not source then
			p.Material = Enum.Material.Glass
			p.Color = c.Main
		end
		solid(p)
		local angle = i / 5 * math.pi * 2 + math.random() * 0.5
		local offset = CFrame.new(math.cos(angle) * boxSize.X * 0.45, -boxSize.Y / 2 + h * 0.4, math.sin(angle) * boxSize.Z * 0.45)
			* CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, -0.45)
		table.insert(crystals, { Part = p, Offset = rel * offset })
	end
	local items = {
		block,
		emitter(rig.Body, { Texture = Fx.Smoke, Rate = 6, Light = 0.2, Size = ns(0, 1.5, 1, 3), Transparency = ns(0, 0.6, 1, 1), Lifetime = NumberRange.new(1, 1.4), Speed = NumberRange.new(0.3, 0.8), Dir = Enum.NormalId.Bottom, Color = cs(c.Core, c.Main) }),
		emitter(rig.Body, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 6, Size = ns(0, 0.7, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0.5, 1), Spread = Vector2.new(180, 180), Color = cs(c.Core), Light = 1 }),
	}
	for _, crystal in crystals do
		table.insert(items, crystal.Part)
	end
	return {
		Instances = items,
		Update = function()
			if not rig.Root.Parent then
				return
			end
			local cf = rig.Root.CFrame
			block.CFrame = cf * rel
			for _, crystal in crystals do
				crystal.Part.CFrame = cf * crystal.Offset
			end
		end,
		-- The ice shatters when the freeze ends (or the enemy dies).
		OnRemove = function()
			emitter(rig.Body, { Texture = Fx.Shard, Count = 30, Size = ns(0, 1.1, 1, 0.3), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(14, 26), Spread = Vector2.new(180, 180), Drag = 2, Accel = Vector3.new(0, -35, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(c.Core, c.Main), Light = 0.6 })
			emitter(rig.Body, { Texture = Fx.Smoke, Count = 6, Light = 0.2, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(3, 6), Spread = Vector2.new(180, 180), Color = cs(c.Core, c.Main) })
			floorRing(rig.Root, c.Main, 10, 0.4)
		end,
	}
end

-------------------------------------------------------------------------------
-- Reaction bursts
-------------------------------------------------------------------------------

local REACTIONS = {
	Conduct = function(rig)
		local c = COLORS.Shock
		for _ = 1, 6 do
			arc(rig.Body, c.Main)
		end
		emitter(rig.Body, { Texture = Lib.Electric, Count = 3, Size = ns(0, 5, 1, 6), Lifetime = NumberRange.new(0.3), Color = cs(c.Core, c.Main), Light = 1 })
		emitter(rig.Body, { Texture = Fx.Spark, Parallel = true, Count = 40, Size = ns(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(20, 35), Spread = Vector2.new(180, 180), Drag = 3, Color = cs(c.Core, c.Main), Light = 1 })
		emitter(rig.Body, { Texture = Fx.Drop, Count = 16, Size = ns(0, 0.5, 1, 0.2), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(10, 16), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -30, 0), Color = cs(COLORS.Soak.Core, COLORS.Soak.Main) })
	end,
	Evaporate = function(rig)
		emitter(rig.Body, { Texture = Lib.Smoke, Count = 18, Light = 0.2, Size = ns(0, 2, 1, 6), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(4, 9), Spread = Vector2.new(60, 60), Accel = Vector3.new(0, 6, 0), Color = cs(Color3.new(1, 1, 1), COLORS.Soak.Core) })
		emitter(rig.Body, { Texture = Fx.Spark, Parallel = true, Count = 20, Size = ns(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 18), Spread = Vector2.new(180, 180), Color = cs(COLORS.Burn.Core, COLORS.Burn.Main) })
	end,
	["Fan the Flames"] = function(rig)
		local c = COLORS.Burn
		emitter(rig.Body, { Texture = Lib.FireBurst, Count = 3, Size = ns(0, 5, 1, 7), Lifetime = NumberRange.new(0.45), Color = cs(c.Core, c.Main), Light = 0.8 })
		emitter(rig.Body, { Texture = Lib.Flame, Count = 18, Size = ns(0, 2.5, 1, 1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(8, 16), Spread = Vector2.new(180, 60), Accel = Vector3.new(0, 12, 0), RotSpeed = NumberRange.new(-120, 120), Color = cs(c.Core, c.Main, c.Dark), Light = 0.8 })
		emitter(rig.Body, { Texture = Fx.Swirl, Count = 6, Size = ns(0, 2, 1, 4), Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(6, 10), Spread = Vector2.new(180, 30), Color = cs(rgb(240, 255, 252)), Transparency = ns(0, 0.3, 1, 1) })
	end,
	Shatter = function(rig)
		emitter(rig.Body, { Texture = Fx.Shard, Count = 22, Size = ns(0, 1.1, 1, 0.3), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(14, 24), Spread = Vector2.new(180, 180), Drag = 2, Accel = Vector3.new(0, -25, 0), RotSpeed = NumberRange.new(-400, 400), Color = cs(COLORS.Stun.Core, rgb(190, 140, 90)), Light = 0.6 })
		floorRing(rig.Root, COLORS.Stun.Main, 9, 0.4)
	end,
}

-------------------------------------------------------------------------------

local function removeEffect(rig, status)
	local effect = rig.Effects[status]
	if not effect then
		return
	end
	rig.Effects[status] = nil
	if effect.OnRemove then
		effect.OnRemove()
	end
	for _, inst in effect.Instances do
		if inst:IsA("ParticleEmitter") then
			inst.Enabled = false
			Debris:AddItem(inst, 1.5)
		else
			inst:Destroy()
		end
	end
end

local function sync(model, rig)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local alive = hum ~= nil and hum.Health > 0
	for _, status in STATUSES do
		local on = alive and model:GetAttribute("Status_" .. status) == true
		if on and not rig.Effects[status] then
			rig.Effects[status] = MAKERS[status](rig)
		elseif not on and rig.Effects[status] then
			removeEffect(rig, status)
		end
	end
end

local function track(model)
	if tracked[model] then
		return
	end
	local body = model:FindFirstChild("Body")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not body or not root then
		return
	end
	local rig = { Body = body, Head = model:FindFirstChild("Head"), Root = root, Effects = {}, Start = os.clock() }
	tracked[model] = rig
	model.AttributeChanged:Connect(function(name)
		if name:sub(1, 7) == "Status_" then
			sync(model, rig)
		elseif name == "ReactionAt" then
			local burst = REACTIONS[model:GetAttribute("Reaction")]
			if burst then
				burst(rig)
			end
		end
	end)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			sync(model, rig)
		end)
	end
	model.Destroying:Connect(function()
		for status in rig.Effects do
			removeEffect(rig, status)
		end
		tracked[model] = nil
	end)
	sync(model, rig)
end

function StatusVFX.Init()
	local folder = workspace:WaitForChild("RiftEnemies")
	-- Workspace streaming can deliver an enemy's parts late (or swap them when
	-- it streams out and back in), so rescan instead of waiting once.
	task.spawn(function()
		while true do
			for _, model in folder:GetChildren() do
				local rig = tracked[model]
				if rig and not rig.Body.Parent then
					for status in rig.Effects do
						removeEffect(rig, status)
					end
					tracked[model] = nil
				end
				if not tracked[model] and model:FindFirstChild("Body") and model:FindFirstChild("HumanoidRootPart") then
					track(model)
				end
			end
			task.wait(0.5)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for model, rig in tracked do
			if not model.Parent then
				tracked[model] = nil
				continue
			end
			for _, effect in rig.Effects do
				effect.Update(dt, t)
			end
		end
	end)
end

return StatusVFX
