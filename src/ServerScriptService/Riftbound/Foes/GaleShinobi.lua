-- Wind: Gale Shinobi (elite: Cyclone Kunoichi). Zephyrax's masked scouts.
-- Grunt: comes in packs, blinks in a zigzag next to you, cuts once and
-- blinks away. Fragile. Elite: spins into a cyclone that pulls players in,
-- then throws its crescent blades out as boomerangs.
local FoeKit = require(script.Parent.FoeKit)

local Foe = {
	Id = "GaleShinobi",
	EliteId = "CycloneKunoichi",
	Name = "Gale Shinobi",
	EliteName = "Cyclone Kunoichi",
	Color = Color3.fromRGB(159, 240, 216),
	Stats = {
		Grunt = { Health = 0.6, Speed = 16 },
		Elite = { Health = 0.9, Speed = 14, Scale = 1.5 },
	},
}

local MINT = Color3.fromRGB(159, 240, 216)
local TEAL = Color3.fromRGB(46, 156, 134)
local CLOTH = Color3.fromRGB(43, 58, 56)
local WRAP = Color3.fromRGB(26, 38, 36)
local MASK = Color3.fromRGB(232, 242, 238)

function Foe.Build(b, elite)
	local d = b.Limbs({ Height = 6.0, Width = 1.4, LegH = 2.7, ArmH = 2.3, BodyColor = CLOTH, LimbColor = WRAP, LegColor = WRAP })
	local neon = { Material = Enum.Material.Neon }
	b.Part("StrapA", Vector3.new(0.2, 2.4, 0.06), CFrame.new(0, d.BodyTop - 1.1, -0.57) * CFrame.Angles(0, 0, 0.6), WRAP)
	b.Part("StrapB", Vector3.new(0.2, 2.4, 0.06), CFrame.new(0, d.BodyTop - 1.1, -0.57) * CFrame.Angles(0, 0, -0.6), WRAP)
	b.Part("Belt", Vector3.new(1.5, 0.28, 1.2), Vector3.new(0, d.BodyTop - 2.0, 0), MINT, neon)
	-- Hood, white mask with eye slits, and the two-tailed scarf.
	local hy = d.HeadY
	b.Part("Hood", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, hy + 0.05, 0.03), WRAP)
	b.Part("Mask", Vector3.new(0.95, 0.95, 0.08), Vector3.new(0, hy - 0.05, -0.55), MASK)
	b.Part("EyeL", Vector3.new(0.26, 0.07, 0.05), CFrame.new(-0.2, hy + 0.12, -0.6) * CFrame.Angles(0, 0, -0.15), MINT, neon)
	b.Part("EyeR", Vector3.new(0.26, 0.07, 0.05), CFrame.new(0.2, hy + 0.12, -0.6) * CFrame.Angles(0, 0, 0.15), MINT, neon)
	b.Part("Spiral", Vector3.new(0.22, 0.22, 0.05), Vector3.new(0, hy - 0.25, -0.6), TEAL, neon)
	b.Part("HoodEar", Vector3.new(0.2, 0.7, 0.3), CFrame.new(0.45, hy + 0.75, 0.1) * CFrame.Angles(0, 0, -0.6), WRAP)
	b.Part("Scarf", Vector3.new(1.3, 0.35, 1.25), Vector3.new(0, d.BodyTop - 0.05, 0), TEAL)
	b.Part("ScarfTailA", Vector3.new(0.35, 0.08, 3.2), CFrame.new(-0.25, d.BodyTop - 0.1, 2.0) * CFrame.Angles(0.15, 0.2, 0.3), TEAL)
	b.Part("ScarfTailB", Vector3.new(0.35, 0.08, 2.6), CFrame.new(0.25, d.BodyTop - 0.4, 1.7) * CFrame.Angles(0.3, -0.25, -0.3), MINT, { Transparency = 0.2 })
	-- Crescent wind blades on both forearms.
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "ArmL" else "ArmR"
		local x = side * (d.ArmX + 0.35)
		b.Part("BladeOuter" .. limb, Vector3.new(0.06, 0.35, 2.4), CFrame.new(x, d.HandY + 0.6, -0.4) * CFrame.Angles(0.5, 0, 0), MASK, { Material = Enum.Material.Glass, AttachTo = limb })
		b.Part("BladeEdge" .. limb, Vector3.new(0.08, 0.1, 2.4), CFrame.new(x, d.HandY + 0.5, -0.45) * CFrame.Angles(0.5, 0, 0), MINT, { Material = Enum.Material.Neon, AttachTo = limb })
	end
	if elite then
		b.Part("ScarfTailC", Vector3.new(0.35, 0.08, 3.6), CFrame.new(0, d.BodyTop - 0.2, 2.2) * CFrame.Angles(0.05, 0, 0), TEAL)
	end
	local light = Instance.new("PointLight")
	light.Color = MINT
	light.Range = 8
	light.Brightness = 1
	light.Parent = b.Model:FindFirstChild("Mask")
end

local function puff(pos)
	FoeKit.Burst(pos + Vector3.new(0, 2, 0), MINT, 6, 2.5)
end

local function blinkStrike(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Blink")
	ctx.Hum:MoveTo(root.Position)
	-- Two zigzag hops toward the target, then one next to them.
	for i = 1, 2 do
		local t = ctx.Target
		if not t.Parent then
			return
		end
		local to = t.Position - root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude < 0.5 then
			break
		end
		local side = Vector3.new(-flat.Z, 0, flat.X).Unit * (if i == 1 then 5 else -5)
		local hop = root.Position + flat * 0.45 + side
		puff(root.Position)
		FoeKit.Teleport(model, hop, t.Position)
		if not ctx:Wait(0.22) then
			return
		end
	end
	local t = ctx.Target
	if not t.Parent then
		return
	end
	local flat = (t.Position - root.Position) * Vector3.new(1, 0, 1)
	local land = t.Position - (if flat.Magnitude > 0.5 then flat.Unit * 3 else Vector3.zero)
	puff(root.Position)
	FoeKit.Teleport(model, land, t.Position)
	local at = root.Position + root.CFrame.LookVector * 2.5
	FoeKit.TelegraphCircle(at, 4, MINT, 0.35)
	FoeKit.Windup(model, 0.35)
	if not ctx:Wait(0.35) then
		return
	end
	for _, char in FoeKit.InCircle(at, 4) do
		if FoeKit.Hit(model, char, ctx.Damage) then
			FoeKit.Knock(char, root.CFrame.LookVector * 40)
		end
	end
	if not ctx:Wait(0.25) then
		return
	end
	-- Blink away again.
	local away = -root.CFrame.LookVector * 14 + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	puff(root.Position)
	FoeKit.Teleport(model, root.Position + away, t.Position)
	ctx:Wait(0.5)
end

local function cyclone(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Cyclone")
	ctx.Hum:MoveTo(root.Position)
	local center = root.Position
	FoeKit.TelegraphCircle(center, 14, MINT, 0.8)
	FoeKit.Windup(model, 0.8)
	if not ctx:Wait(0.8) then
		return
	end
	local funnel = FoeKit.FxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 8, 8), Color = MINT, Transparency = 0.6,
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local t0 = os.clock()
	local tick = 0
	while os.clock() - t0 < 2 and ctx:Alive() do
		funnel.CFrame = CFrame.new(center) * CFrame.Angles(0, (os.clock() - t0) * 12, math.pi / 2)
		for _, char in FoeKit.InCircle(center, 14) do
			local r = char:FindFirstChild("HumanoidRootPart")
			if r then
				local pull = (center - r.Position) * Vector3.new(1, 0, 1)
				if pull.Magnitude > 2 then
					r.AssemblyLinearVelocity = pull.Unit * 18 + Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
				end
				if tick % 4 == 0 and pull.Magnitude < 5 then
					FoeKit.Hit(model, char, ctx.Damage * 0.4)
				end
			end
		end
		tick += 1
		task.wait(0.1)
	end
	funnel:Destroy()
	-- Boomerang blades at the nearest player.
	local target = FoeKit.Nearest(root.Position, 60)
	if target then
		local dir = (target.Position - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.5 then
			for _, turn in { -0.25, 0.25 } do
				local d = CFrame.Angles(0, turn, 0):VectorToWorldSpace(dir.Unit)
				FoeKit.TelegraphLine(root.Position, d, 26, 3, MINT, 0.3)
				local blade = FoeKit.FxPart({ Size = Vector3.new(3, 0.2, 0.8), Color = MINT })
				task.delay(0.3, FoeKit.Projectile, blade, root.Position, d, { Speed = 55, Range = 26, Radius = 2, Pierce = true, Return = true, Spin = 20 }, function(char)
					FoeKit.Hit(model, char, ctx.Damage * 0.8)
				end)
			end
		end
	end
	ctx:Wait(1)
end

function Foe.Think(ctx)
	local dist = ctx.Dist
	if ctx.Elite and dist < 12 and ctx:Ready("Cyclone", 7) then
		return cyclone(ctx)
	end
	if dist < 30 and ctx:Ready("Blink", if ctx.Elite then 3 else 2.4 + math.random()) then
		return blinkStrike(ctx)
	end
	if dist < 4 then
		return FoeKit.Melee(ctx, 4, 0.8)
	end
	-- Circle the target at a distance between strikes.
	local root = ctx.Root
	local flat = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dist > 16 or flat.Magnitude < 0.5 then
		ctx.Hum:MoveTo(ctx.Target.Position)
	else
		ctx.Hum:MoveTo(root.Position + Vector3.new(-flat.Z, 0, flat.X).Unit * 6 - flat.Unit * 2)
	end
end

return Foe
