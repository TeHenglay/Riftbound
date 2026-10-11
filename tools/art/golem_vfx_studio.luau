--!nocheck
-- Builds the nation golem VFX in Studio (run in the Edit DataModel, e.g. via
-- the Studio MCP execute_luau or the command bar).
--
--  * Aura: ParticleEmitters named GolemFX_* on the templates in
--    ServerStorage.RiftboundAssets.Foes.<Nation>Golem (they replicate with
--    the spawned golem and scale with Model:ScaleTo).
--  * Spawn: ReplicatedStorage.RiftboundVFX.GolemSpawn_<Nation>, a one-off
--    swirl of light under a golem as it appears (SkillVFX.onGolemSpawn).
--    Authored for a 4-stud radius.
--  * Slam: ReplicatedStorage.RiftboundVFX.GolemSlam_<Nation>, a Part whose
--    emitters follow the pack convention (EmitCount / EmitDelay attributes);
--    SkillVFX.onGolemSlam plays it. Authored for an 8-stud slam radius.
--
-- Textures come from tools/art/golem_vfx_textures.py (art/vfx/textures).
-- Set NATIONS to limit which nations are rebuilt. Re-running replaces the
-- previous GolemFX_* emitters and slam templates.
local NATIONS = NATIONS or { "Fire", "Earth", "Water", "Wind", "Lightning" }

local T = {
	Glow = "rbxassetid://133879442443868",
	Spark = "rbxassetid://102883744868571",
	Smoke = "rbxassetid://90940524468614",
	Flame = "rbxassetid://74326893978725",
	Burst = "rbxassetid://83486050427676",
	Ring = "rbxassetid://78697244931583",
	Chunks = "rbxassetid://134519485832555",
	Droplet = "rbxassetid://80823453568268",
	Splash = "rbxassetid://88417665267852",
	Wind = "rbxassetid://125936982089913",
	Arc = "rbxassetid://85802019034933",
	Star = "rbxassetid://92250318265527",
	Swirl = "rbxassetid://72894756255979",
	Beam = "rbxassetid://107993264375581",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- ns(v) or ns(t0, v0, t1, v1, ...)
local function ns(...)
	local a = { ... }
	if #a == 1 then
		return NumberSequence.new(a[1])
	end
	local keys = {}
	for i = 1, #a, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(keys)
end

-- cs(c) or cs(c0, c1) or cs(c0, c1, c2) evenly spaced.
local function cs(...)
	local a = { ... }
	if #a == 1 then
		return ColorSequence.new(a[1])
	end
	local keys = {}
	for i, c in a do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#a - 1), c))
	end
	return ColorSequence.new(keys)
end

local function nr(a, b)
	return NumberRange.new(a, b or a)
end

local GRID = { [4] = Enum.ParticleFlipbookLayout.Grid4x4, [2] = Enum.ParticleFlipbookLayout.Grid2x2 }

-- Emitter defaults: light, no shadows, glow-friendly.
local function emitter(name, p)
	local e = Instance.new("ParticleEmitter")
	e.Name = "GolemFX_" .. name
	e.Texture = p.Texture
	e.Rate = p.Rate or 0
	e.Lifetime = p.Lifetime or nr(1)
	e.Speed = p.Speed or nr(0)
	e.SpreadAngle = p.Spread or Vector2.new(0, 0)
	e.Size = p.Size or ns(1)
	e.Transparency = p.Transparency or ns(0, 0, 0.7, 0.2, 1, 1)
	e.Color = p.Color or cs(Color3.new(1, 1, 1))
	e.LightEmission = p.Light or 1
	e.LightInfluence = p.LightInfluence or (p.Light == 0 and 1 or 0)
	e.Brightness = p.Brightness or 1
	e.Acceleration = p.Accel or Vector3.zero
	e.Drag = p.Drag or 0
	e.Rotation = p.Rotation or nr(0, 360)
	e.RotSpeed = p.RotSpeed or nr(0)
	e.ZOffset = p.ZOffset or 0
	e.EmissionDirection = p.Direction or Enum.NormalId.Top
	e.Orientation = p.Orientation or Enum.ParticleOrientation.FacingCamera
	e.LockedToPart = p.Locked or false
	e.Squash = p.Squash or ns(0)
	if p.Surface then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	elseif p.Shape then
		e.Shape = p.Shape
		e.ShapeStyle = p.ShapeStyle or Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = p.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	end
	if p.Grid then
		e.FlipbookLayout = GRID[p.Grid]
		e.FlipbookMode = p.Flipbook or Enum.ParticleFlipbookMode.OneShot
		e.FlipbookFramerate = nr(p.Fps or 16)
		e.FlipbookStartRandom = p.StartRandom or false
	end
	if p.Count then
		e:SetAttribute("EmitCount", p.Count)
	end
	if p.Delay then
		e:SetAttribute("EmitDelay", p.Delay)
	end
	return e
end

-------------------------------------------------------------------------------
-- Specs. Aura entries: Part (limb name), At (attachment offset in the part's
-- space; omit to emit from the whole part volume). Slam entries: At (offset
-- from the floor centre).
-------------------------------------------------------------------------------

local SPECS = {}

do -- Fire: embers and flame licks off the shoulders and head.
	local core, main, dark = rgb(255, 220, 120), rgb(255, 110, 20), rgb(200, 40, 0)
	local yel = rgb(255, 200, 80)
	local smoke = rgb(40, 32, 30)
	local function licks(part, rate)
		return { Name = "Licks", Part = part, Texture = T.Flame, Grid = 4, Rate = rate, Surface = true,
			Lifetime = nr(0.45, 0.7), Speed = nr(0.2, 0.5), Spread = Vector2.new(8, 8), Accel = Vector3.new(0, 3, 0),
			Rotation = nr(-8, 8), Light = 0.7, Brightness = 3, ZOffset = 0.8,
			Size = ns(0, 1, 1, 0.7), Transparency = ns(0, 0, 0.5, 0.1, 1, 1), Color = cs(core, main, dark) }
	end
	SPECS.Fire = {
		Aura = {
			{ Name = "Embers", Part = "Body", Texture = T.Glow, Rate = 8, Surface = true, Lifetime = nr(1.4, 2.2),
				Speed = nr(2, 4), Spread = Vector2.new(30, 30), Accel = Vector3.new(0, 1.5, 0), Drag = 0.5,
				Brightness = 3, ZOffset = 0.8, Size = ns(0, 0.3, 1, 0), Transparency = ns(0, 0, 0.8, 0.2, 1, 1),
				Color = cs(rgb(255, 240, 180), main, dark) },
			licks("Body", 9),
			licks("ArmL", 5),
			licks("ArmR", 5),
		},
		Slam = {
			{ Name = "Ring", Texture = T.Ring, Grid = 4, Count = 1, Lifetime = nr(0.45), Speed = nr(0.01),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Rotation = nr(0, 360), Light = 0.6,
				Brightness = 2, Size = ns(17), Transparency = ns(0), Color = cs(yel, main), ZOffset = 0.5 },
			{ Name = "Flash", Texture = T.Burst, Grid = 4, Count = 1, Lifetime = nr(0.35), At = Vector3.new(0, 1.5, 0),
				Light = 0.7, Size = ns(6), Transparency = ns(0), Color = cs(yel, main), ZOffset = 2 },
			{ Name = "Flames", Texture = T.Flame, Grid = 4, Count = 12, Lifetime = nr(0.45, 0.7), Speed = nr(14, 22),
				Direction = Enum.NormalId.Front, Spread = Vector2.new(6, 180), Drag = 4, Rotation = nr(-15, 15),
				At = Vector3.new(0, 0.8, 0), Light = 0.5, Brightness = 2,
				Size = ns(0, 2.2, 1, 1.2), Transparency = ns(0, 0.1, 0.6, 0.3, 1, 1), Color = cs(yel, main, dark) },
			{ Name = "Embers", Texture = T.Glow, Count = 26, Lifetime = nr(0.6, 1.2), Speed = nr(12, 26),
				Spread = Vector2.new(55, 55), Accel = Vector3.new(0, -30, 0), Drag = 1.5, At = Vector3.new(0, 0.5, 0),
				Brightness = 3, Size = ns(0, 0.35, 1, 0), Transparency = ns(0, 0, 0.8, 0.1, 1, 1), Color = cs(yel, main) },
			{ Name = "Rocks", Texture = T.Chunks, Grid = 2, Flipbook = Enum.ParticleFlipbookMode.Loop, Fps = 0,
				StartRandom = true, Count = 9, Lifetime = nr(0.7, 1), Speed = nr(14, 24), Spread = Vector2.new(45, 45),
				Accel = Vector3.new(0, -70, 0), RotSpeed = nr(-360, 360), Light = 0, At = Vector3.new(0, 0.5, 0),
				Size = ns(0, 0.7, 1, 0.5), Transparency = ns(0, 0, 0.85, 0, 1, 1), Color = cs(rgb(52, 40, 36)) },
			{ Name = "Smoke", Texture = T.Smoke, Grid = 4, Count = 7, Lifetime = nr(0.9, 1.4), Speed = nr(10, 16),
				Direction = Enum.NormalId.Front, Spread = Vector2.new(5, 180), Drag = 3, Light = 0, At = Vector3.new(0, 1, 0),
				Size = ns(0, 2.5, 1, 5.5), Transparency = ns(0, 0.45, 1, 1), Color = cs(smoke) },
		},
	}
end

-- Shared slam layers: a flat ring and a flash in the nation's colours.
local function ringAndFlash(core, main)
	return {
		Name = "Ring", Texture = T.Ring, Grid = 4, Count = 1, Lifetime = nr(0.45), Speed = nr(0.01),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Rotation = nr(0, 360),
		Size = ns(17), Transparency = ns(0), Color = cs(core, main), ZOffset = 0.5,
	}, {
		Name = "Flash", Texture = T.Burst, Grid = 4, Count = 1, Lifetime = nr(0.35), At = Vector3.new(0, 1.5, 0),
		Size = ns(7), Transparency = ns(0), Color = cs(core, main), ZOffset = 2,
	}
end

local function rocks(color, count)
	return {
		Name = "Rocks", Texture = T.Chunks, Grid = 2, Flipbook = Enum.ParticleFlipbookMode.Loop, Fps = 0,
		StartRandom = true, Count = count or 9, Lifetime = nr(0.7, 1), Speed = nr(14, 24), Spread = Vector2.new(45, 45),
		Accel = Vector3.new(0, -70, 0), RotSpeed = nr(-360, 360), Light = 0, At = Vector3.new(0, 0.5, 0),
		Size = ns(0, 0.7, 1, 0.5), Transparency = ns(0, 0, 0.85, 0, 1, 1), Color = cs(color),
	}
end

do -- Earth: drifting dust and green moss motes; slam throws dust and stone.
	local core, main = rgb(200, 255, 190), rgb(70, 210, 90)
	local dust = rgb(150, 122, 92)
	local ring, flash = ringAndFlash(core, main)
	SPECS.Earth = {
		Aura = {
			{ Name = "Motes", Part = "Body", Texture = T.Glow, Rate = 5, Lifetime = nr(1.6, 2.4), Speed = nr(0.6, 1.4),
				Spread = Vector2.new(60, 60), Accel = Vector3.new(0, 0.6, 0), Drag = 0.5,
				Size = ns(0, 0, 0.2, 0.22, 1, 0), Transparency = ns(0, 0.1, 0.8, 0.3, 1, 1), Color = cs(core, main) },
			{ Name = "Dust", Part = "LegL", At = Vector3.new(0, -0.9, 0), Texture = T.Smoke, Grid = 4, Rate = 1,
				Lifetime = nr(1.5, 2), Speed = nr(0.5, 1), Spread = Vector2.new(70, 70), Light = 0,
				Size = ns(0, 0.8, 1, 2), Transparency = ns(0, 0.7, 1, 1), Color = cs(dust) },
			{ Name = "Dust", Part = "LegR", At = Vector3.new(0, -0.9, 0), Texture = T.Smoke, Grid = 4, Rate = 1,
				Lifetime = nr(1.5, 2), Speed = nr(0.5, 1), Spread = Vector2.new(70, 70), Light = 0,
				Size = ns(0, 0.8, 1, 2), Transparency = ns(0, 0.7, 1, 1), Color = cs(dust) },
		},
		Slam = {
			ring, flash,
			{ Name = "Dust", Texture = T.Smoke, Grid = 4, Count = 10, Lifetime = nr(1, 1.5), Speed = nr(12, 18),
				Direction = Enum.NormalId.Front, Spread = Vector2.new(5, 180), Drag = 3, Light = 0, At = Vector3.new(0, 1, 0),
				Size = ns(0, 3, 1, 6.5), Transparency = ns(0, 0.3, 1, 1), Color = cs(dust) },
			rocks(rgb(110, 86, 62), 14),
			{ Name = "Motes", Texture = T.Glow, Count = 16, Lifetime = nr(0.8, 1.4), Speed = nr(6, 14),
				Spread = Vector2.new(60, 60), Accel = Vector3.new(0, -6, 0), Drag = 2, At = Vector3.new(0, 0.8, 0),
				Size = ns(0, 0.35, 1, 0), Transparency = ns(0, 0, 0.8, 0.2, 1, 1), Color = cs(core, main) },
		},
	}
end

do -- Water: falling droplets and a faint mist; slam splashes outward.
	local core, main = rgb(230, 250, 255), rgb(150, 230, 255)
	local deep = rgb(60, 170, 240)
	local ring, flash = ringAndFlash(core, main)
	SPECS.Water = {
		Aura = {
			{ Name = "Drips", Part = "Body", Texture = T.Droplet, Rate = 5, Lifetime = nr(0.6, 0.9), Speed = nr(0.5, 1),
				Direction = Enum.NormalId.Bottom, Accel = Vector3.new(0, -14, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.22, 1, 0.18), Transparency = ns(0, 0.1, 0.8, 0.2, 1, 1), Color = cs(core, main) },
			{ Name = "Drips", Part = "ArmL", Texture = T.Droplet, Rate = 2, Lifetime = nr(0.5, 0.8), Speed = nr(0.5, 1),
				Direction = Enum.NormalId.Bottom, Accel = Vector3.new(0, -14, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.2, 1, 0.16), Transparency = ns(0, 0.1, 0.8, 0.2, 1, 1), Color = cs(core, main) },
			{ Name = "Drips", Part = "ArmR", Texture = T.Droplet, Rate = 2, Lifetime = nr(0.5, 0.8), Speed = nr(0.5, 1),
				Direction = Enum.NormalId.Bottom, Accel = Vector3.new(0, -14, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.2, 1, 0.16), Transparency = ns(0, 0.1, 0.8, 0.2, 1, 1), Color = cs(core, main) },
			{ Name = "Mist", Part = "Body", Texture = T.Smoke, Grid = 4, Rate = 1.5, Lifetime = nr(1.6, 2.2),
				Speed = nr(0.3, 0.8), Spread = Vector2.new(90, 90), Light = 0.3,
				Size = ns(0, 1.2, 1, 2.6), Transparency = ns(0, 0.8, 1, 1), Color = cs(core) },
		},
		Slam = {
			ring, flash,
			{ Name = "Splash", Texture = T.Splash, Grid = 4, Count = 6, Lifetime = nr(0.5, 0.7), Speed = nr(0.01),
				At = Vector3.new(0, 1.6, 0), Size = ns(0, 3.5, 1, 4.5), Transparency = ns(0, 0, 0.7, 0.1, 1, 1),
				Rotation = nr(-10, 10), Color = cs(core, main), Light = 0.6, Shape = Enum.ParticleEmitterShape.Disc },
			{ Name = "Droplets", Texture = T.Droplet, Count = 30, Lifetime = nr(0.6, 1), Speed = nr(12, 26),
				Spread = Vector2.new(55, 55), Accel = Vector3.new(0, -60, 0), At = Vector3.new(0, 0.5, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.45, 1, 0.3), Transparency = ns(0, 0, 0.85, 0.1, 1, 1), Color = cs(core, main), Light = 0.6 },
			{ Name = "Spray", Texture = T.Smoke, Grid = 4, Count = 8, Lifetime = nr(0.8, 1.2), Speed = nr(10, 16),
				Direction = Enum.NormalId.Front, Spread = Vector2.new(5, 180), Drag = 3, Light = 0.4, At = Vector3.new(0, 1, 0),
				Size = ns(0, 2.5, 1, 5.5), Transparency = ns(0, 0.5, 1, 1), Color = cs(core, deep) },
		},
	}
end

do -- Wind: mint gusts circling the body; slam is a spinning burst of streaks.
	local core, main = rgb(235, 255, 248), rgb(120, 255, 210)
	local ring, flash = ringAndFlash(core, main)
	SPECS.Wind = {
		Aura = {
			{ Name = "Swirl", Part = "Body", Texture = T.Wind, Grid = 4, Rate = 3, Lifetime = nr(0.7, 1), Speed = nr(0),
				Rotation = nr(0, 360), RotSpeed = nr(-200, 200), Locked = true,
				Size = ns(0, 3.2, 1, 4), Transparency = ns(0, 0.25, 1, 0.5), Color = cs(core, main) },
			{ Name = "Motes", Part = "Body", Texture = T.Glow, Rate = 4, Lifetime = nr(1, 1.6), Speed = nr(1, 2.5),
				Spread = Vector2.new(90, 90), Drag = 1,
				Size = ns(0, 0.18, 1, 0), Transparency = ns(0, 0.1, 0.8, 0.3, 1, 1), Color = cs(core, main) },
			{ Name = "FootGust", Part = "LegL", At = Vector3.new(0.55, -0.9, 0), Texture = T.Wind, Grid = 4, Rate = 1.5,
				Lifetime = nr(0.6, 0.8), Speed = nr(0.01), Rotation = nr(0, 360), Locked = true,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Size = ns(0, 2.5, 1, 3.5), Transparency = ns(0, 0.35, 1, 0.6), Color = cs(core, main) },
		},
		Slam = {
			ring, flash,
			{ Name = "Gusts", Texture = T.Wind, Grid = 4, Count = 5, Lifetime = nr(0.45, 0.6), Speed = nr(0.01),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Rotation = nr(0, 360), RotSpeed = nr(-300, -200),
				At = Vector3.new(0, 0.6, 0), Size = ns(0, 6, 1, 15), Transparency = ns(0, 0.1, 1, 0.6), Color = cs(core, main) },
			{ Name = "Swirl", Texture = T.Wind, Grid = 4, Count = 4, Lifetime = nr(0.5, 0.7), Speed = nr(0.01),
				Rotation = nr(0, 360), RotSpeed = nr(200, 300), At = Vector3.new(0, 2, 0),
				Size = ns(0, 4, 1, 8), Transparency = ns(0, 0.2, 1, 0.7), Color = cs(core, main) },
			{ Name = "Dust", Texture = T.Smoke, Grid = 4, Count = 8, Lifetime = nr(0.7, 1), Speed = nr(16, 24),
				Direction = Enum.NormalId.Front, Spread = Vector2.new(5, 180), Drag = 4, Light = 0.2, At = Vector3.new(0, 0.8, 0),
				Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.55, 1, 1), Color = cs(core) },
			{ Name = "Motes", Texture = T.Glow, Count = 18, Lifetime = nr(0.5, 0.9), Speed = nr(14, 26),
				Spread = Vector2.new(70, 70), Drag = 3, At = Vector3.new(0, 1, 0),
				Size = ns(0, 0.3, 1, 0), Transparency = ns(0, 0, 0.8, 0.2, 1, 1), Color = cs(core, main) },
		},
	}
end

do -- Lightning: crackling arcs on the body and fists; slam is a burst of bolts.
	local core, main = rgb(255, 252, 225), rgb(255, 220, 60)
	local ring, flash = ringAndFlash(core, main)
	local function arc(part, at, rate, size)
		return { Name = "Arcs", Part = part, At = at, Texture = T.Arc, Grid = 4, Rate = rate,
			Flipbook = Enum.ParticleFlipbookMode.Random, Fps = 30, Lifetime = nr(0.12, 0.2), Speed = nr(0),
			Rotation = nr(0, 360), Locked = true, Brightness = 2,
			Size = ns(size), Transparency = ns(0, 0, 1, 0.3), Color = cs(core, main) }
	end
	SPECS.Lightning = {
		Aura = {
			arc("Body", nil, 4, 1.8),
			arc("ArmL", Vector3.new(0, -1.1, 0), 3, 1.1),
			arc("ArmR", Vector3.new(0, -1.1, 0), 3, 1.1),
			{ Name = "Sparks", Part = "Body", Texture = T.Spark, Rate = 4, Lifetime = nr(0.25, 0.45), Speed = nr(5, 9),
				Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -20, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.18, 1, 0.06), Transparency = ns(0, 0, 1, 0.4), Color = cs(core, main), Brightness = 2 },
		},
		Slam = {
			ring, flash,
			{ Name = "Bolts", Texture = T.Arc, Grid = 4, Flipbook = Enum.ParticleFlipbookMode.Random, Fps = 24,
				Count = 7, Lifetime = nr(0.2, 0.35), Speed = nr(0.01), Rotation = nr(0, 360), At = Vector3.new(0, 1.5, 0),
				Shape = Enum.ParticleEmitterShape.Disc, Size = ns(0, 5, 1, 6), Transparency = ns(0, 0, 1, 0.5),
				Color = cs(core, main), Brightness = 3 },
			{ Name = "GroundArcs", Texture = T.Arc, Grid = 4, Flipbook = Enum.ParticleFlipbookMode.Random, Fps = 24,
				Count = 5, Lifetime = nr(0.25, 0.4), Speed = nr(0.01), Rotation = nr(0, 360), At = Vector3.new(0, 0.3, 0),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Delay = 0.05,
				Size = ns(0, 9, 1, 13), Transparency = ns(0, 0, 1, 0.6), Color = cs(core, main), Brightness = 2 },
			{ Name = "Sparks", Texture = T.Spark, Count = 30, Lifetime = nr(0.3, 0.6), Speed = nr(18, 34),
				Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -40, 0), Drag = 2, At = Vector3.new(0, 0.6, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel, Rotation = nr(0),
				Size = ns(0, 0.3, 1, 0.1), Transparency = ns(0, 0, 1, 0.3), Color = cs(core, main), Brightness = 2 },
			rocks(rgb(40, 38, 46), 7),
		},
	}
end

-------------------------------------------------------------------------------
-- Anime layers from the Zyron Aura System pack (Creator Store 73732620614663,
-- kept in ServerStorage.ZyronAuraSystem as the source for rebuilds):
--  * spawn: Level1's ground swirl and star sparkles, played once as a golem
--    appears;
--  * slam: Level2's star burst, arcs and ground cracks, scaled to the slam.
-- Both are recoloured to the nation palette; black and white stay as accents.
-------------------------------------------------------------------------------

local PAL = {
	Fire = { Core = rgb(255, 220, 120), Main = rgb(255, 110, 20) },
	Earth = { Core = rgb(200, 255, 190), Main = rgb(70, 210, 90) },
	Water = { Core = rgb(225, 250, 255), Main = rgb(80, 200, 255) },
	Wind = { Core = rgb(235, 255, 248), Main = rgb(120, 255, 210) },
	Lightning = { Core = rgb(255, 252, 215), Main = rgb(255, 215, 40) },
}

local ZSPAWN_SCALE = 0.3 -- Level1 is authored for a ~14-stud radius
local ZSPAWN_COUNT = 0.6
local ZSLAM_SCALE = 0.45 -- Level2 is authored for a ~18-stud radius
local ZSLAM_COUNT = 0.5 -- halve its burst counts

local function scaleSeq(seq, k)
	local keys = {}
	for _, p in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(keys)
end

local function recolor(seq, pal)
	local keys = {}
	for _, p in seq.Keypoints do
		local c = p.Value
		local hi = math.max(c.R, c.G, c.B)
		local lo = math.min(c.R, c.G, c.B)
		local sat = hi > 0 and (hi - lo) / hi or 0
		local out = c
		if hi > 0.15 and sat > 0.08 then
			out = pal.Main:Lerp(pal.Core, math.clamp((0.75 - sat) / 0.5, 0, 1))
		end
		table.insert(keys, ColorSequenceKeypoint.new(p.Time, out))
	end
	return ColorSequence.new(keys)
end

local function zclone(e, scale, pal, name)
	local c = e:Clone()
	c.Name = "GolemFX_Z" .. name
	c.Size = scaleSeq(c.Size, scale)
	c.Speed = NumberRange.new(c.Speed.Min * scale, c.Speed.Max * scale)
	c.Acceleration *= scale
	-- The pack pushes layers 2-10 studs toward the camera; at golem size that
	-- lifts flat ground layers off the floor, so shrink it with the effect.
	c.ZOffset *= scale
	c.Color = recolor(c.Color, pal)
	return c
end

local function zpack()
	return game:GetService("ServerStorage"):FindFirstChild("ZyronAuraSystem")
end

-------------------------------------------------------------------------------
-- Builders

-------------------------------------------------------------------------------

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function clearFx(model)
	for _, d in model:GetDescendants() do
		if d.Name:match("^GolemFX_") then
			d:Destroy()
		end
	end
end

local function buildAura(nation, spec)
	local model = ServerStorage.RiftboundAssets.Foes:FindFirstChild(nation .. "Golem")
	if not model then
		return nation .. ": no template"
	end
	clearFx(model)
	local scale = model:GetScale()
	for _, p in spec.Aura do
		local part = model[p.Part]
		-- Body-volume emitters spawn on the skin (not buried in the mesh) and
		-- draw a little in front of it.
		if not p.At and p.Surface == nil then
			p.Surface = true
		end
		p.ZOffset = p.ZOffset or 0.8
		local e = emitter(p.Name, p)
		-- Studio models were imported at 100x and scaled down with ScaleTo,
		-- so the authored stud sizes are already world sizes here.
		if p.At then
			local att = Instance.new("Attachment")
			att.Name = "GolemFX_" .. p.Name
			att.Position = p.At
			att.Parent = part
			e.Parent = att
		else
			e.Parent = part
		end
	end
	return nation .. ": aura " .. #spec.Aura .. " (scale " .. scale .. ")"
end

local function fxRoot(vfx, name)
	local old = vfx:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Part")
	root.Name = name
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	return root
end

-- The spawn swirl: Level1 of the pack, shrunk to the golem's footprint.
local function buildSpawn(nation)
	local z = zpack()
	local vfx = ReplicatedStorage:FindFirstChild("RiftboundVFX")
	if not (z and vfx) then
		return nation .. ": no spawn (pack or RiftboundVFX missing)"
	end
	local root = fxRoot(vfx, "GolemSpawn_" .. nation)
	local att = Instance.new("Attachment")
	att.Name = "ZSwirl"
	att.Parent = root
	for _, e in z.Level1.Attachment:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = zclone(e, ZSPAWN_SCALE, PAL[nation], "Spawn" .. e.Name)
			c.Enabled = false
			c:SetAttribute("EmitCount", math.max(1, math.ceil((e:GetAttribute("EmitCount") or 1) * ZSPAWN_COUNT)))
			c.Parent = att
		end
	end
	root.Parent = vfx
	return nation .. ": spawn " .. #att:GetChildren() .. " emitters"
end

local function buildSlam(nation, spec)
	local vfx = ReplicatedStorage:FindFirstChild("RiftboundVFX")
	if not vfx then
		vfx = Instance.new("Folder")
		vfx.Name = "RiftboundVFX"
		vfx.Parent = ReplicatedStorage
	end
	local old = vfx:FindFirstChild("GolemSlam_" .. nation)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Part")
	root.Name = "GolemSlam_" .. nation
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	local z = zpack()
	for _, p in spec.Slam do
		if z and (p.Name == "Ring" or p.Name == "Flash") then
			continue
		end
		local e = emitter(p.Name, p)
		local att = Instance.new("Attachment")
		att.Name = p.Name
		att.Position = p.At or Vector3.zero
		att.Parent = root
		e.Enabled = false
		e.Parent = att
	end
	if z then
		local att = Instance.new("Attachment")
		att.Name = "ZBurst"
		att.Position = Vector3.new(0, 0.2, 0)
		att.Parent = root
		for _, e in z.Level2.Attachment:GetChildren() do
			if e:IsA("ParticleEmitter") then
				local c = zclone(e, ZSLAM_SCALE, PAL[nation], "Slam" .. e.Name)
				c.Enabled = false
				c:SetAttribute("EmitCount", math.max(1, math.ceil((e:GetAttribute("EmitCount") or 1) * ZSLAM_COUNT)))
				c.Parent = att
			end
		end
	end
	root.Parent = vfx
	return nation .. ": slam " .. #root:GetDescendants() .. " instances"
end

local log = {}
for _, nation in NATIONS do
	local spec = SPECS[nation]
	if spec then
		table.insert(log, buildAura(nation, spec))
		table.insert(log, buildSpawn(nation))
		table.insert(log, buildSlam(nation, spec))
	end
end
return table.concat(log, "\n")
