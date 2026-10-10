-- Earth: Shalecrag Monk (elite: Gravemaw Warden). Stone-grown mountain monks.
-- Grunt: slow tank whose stone guard shrugs off the first hit, then a
-- two-fist slam that roots players. Elite: a wide prayer-bead chain sweep
-- and boulders thrown from range.
local FoeKit = require(script.Parent.FoeKit)

local Foe = {
	Id = "ShalecragMonk",
	EliteId = "GravemawWarden",
	Name = "Shalecrag Monk",
	EliteName = "Gravemaw Warden",
	Color = Color3.fromRGB(217, 162, 94),
	Stats = {
		Grunt = { Health = 1.5, Speed = 8 },
		Elite = { Health = 1.4, Speed = 7, Scale = 1.8 },
	},
}

local AMBER = Color3.fromRGB(255, 184, 74)
local STONE = Color3.fromRGB(110, 96, 80)
local DARKSTONE = Color3.fromRGB(62, 52, 42)
local ROBE = Color3.fromRGB(122, 64, 26)
local MOSS = Color3.fromRGB(93, 122, 58)
local GUARD_REGEN = 6

function Foe.Build(b, elite)
	local d = b.Limbs({ Height = 6.4, Width = 2.6, LegH = 2.2, ArmH = 2.6, BodyColor = ROBE, LimbColor = Color3.fromRGB(74, 36, 16), LegColor = Color3.fromRGB(44, 32, 24) })
	local neon = { Material = Enum.Material.Neon }
	local slate = { Material = Enum.Material.Slate }
	b.Part("Sash", Vector3.new(0.4, 3.4, 1.2), CFrame.new(0, d.BodyTop - 1.6, -0.02) * CFrame.Angles(0, 0, 0.55), Color3.fromRGB(217, 162, 94))
	-- Prayer beads and the amber heart stone.
	for i = -3, 3 do
		local a = i / 3 * 1.0
		b.Part("Bead" .. i, Vector3.new(0.35, 0.35, 0.35), Vector3.new(math.sin(a) * 1.1, d.BodyTop - 0.3 - math.cos(a) * 0.55, -0.6), Color3.fromRGB(90, 74, 58), { Shape = Enum.PartType.Ball })
	end
	b.Part("HeartStone", Vector3.new(0.45, 0.45, 0.2), Vector3.new(0, d.BodyTop - 0.95, -0.66), AMBER, neon)
	-- Boulder shoulders with moss and runes.
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "ArmL" else "ArmR"
		local sx = side * (d.ArmX + 0.1)
		b.Part("Pauldron" .. limb, Vector3.new(1.7, 1.2, 1.7), CFrame.new(sx, d.BodyTop + 0.1, 0) * CFrame.Angles(0.2, 0.4, side * 0.2), STONE, { Material = Enum.Material.Slate, AttachTo = limb })
		b.Part("Moss" .. limb, Vector3.new(1.3, 0.25, 1.3), CFrame.new(sx, d.BodyTop + 0.75, 0) * CFrame.Angles(0.2, 0.4, side * 0.2), MOSS, { Material = Enum.Material.Grass, AttachTo = limb })
		b.Part("Rune" .. limb, Vector3.new(0.6, 0.1, 0.05), Vector3.new(sx, d.BodyTop, -0.88), AMBER, { Material = Enum.Material.Neon, AttachTo = limb })
		-- Huge stone fists: the monk's weapon.
		b.Part("Fist" .. limb, Vector3.new(1.5, 1.4, 1.5), CFrame.new(side * d.ArmX, d.HandY - 0.2, -0.1) * CFrame.Angles(0.1, side * 0.3, 0), DARKSTONE, { Material = Enum.Material.Basalt, AttachTo = limb })
		b.Part("FistRune" .. limb, Vector3.new(0.9, 0.12, 0.05), Vector3.new(side * d.ArmX, d.HandY - 0.1, -0.88), AMBER, { Material = Enum.Material.Neon, AttachTo = limb })
	end
	-- Shadowed face under a stone kasa.
	local hy = d.HeadY
	b.Part("Face", Vector3.new(1.1, 1.1, 1.0), Vector3.new(0, hy, 0), Color3.fromRGB(26, 20, 14))
	b.Part("EyeL", Vector3.new(0.18, 0.18, 0.05), Vector3.new(-0.22, hy, -0.51), AMBER, neon)
	b.Part("EyeR", Vector3.new(0.18, 0.18, 0.05), Vector3.new(0.22, hy, -0.51), AMBER, neon)
	b.Part("Kasa", Vector3.new(3.4, 0.4, 3.4), Vector3.new(0, hy + 0.65, 0), STONE, slate)
	b.Part("KasaTop", Vector3.new(1.6, 0.5, 1.6), Vector3.new(0, hy + 1.05, 0), STONE, slate)
	b.Part("KasaPeak", Vector3.new(0.6, 0.35, 0.6), Vector3.new(0, hy + 1.4, 0), STONE, slate)
	if elite then
		-- Giant prayer-bead chain looped from the right fist.
		for i = 0, 5 do
			b.Part("ChainBead" .. i, Vector3.new(0.7, 0.7, 0.7), Vector3.new(d.ArmX + 0.2, d.HandY - 0.9 - i * 0.55, -0.4 - i * 0.2), Color3.fromRGB(90, 74, 58), { Shape = Enum.PartType.Ball, Material = Enum.Material.Slate, AttachTo = "ArmR" })
		end
	end
	local light = Instance.new("PointLight")
	light.Color = AMBER
	light.Range = 9
	light.Brightness = 1.2
	light.Parent = b.Model:FindFirstChild("HeartStone")
end

-- Stone guard: blocks the first hit, then regrows after GUARD_REGEN seconds.
function Foe.Setup(ctx)
	local hum = ctx.Hum
	local guard = true
	local last = hum.Health
	ctx.Model:SetAttribute("Guarded", true)
	hum.HealthChanged:Connect(function(hp)
		if hp <= 0 then
			return
		end
		if hp < last and guard then
			guard = false
			ctx.Model:SetAttribute("Guarded", false)
			hum.Health = last
			FoeKit.Burst(ctx.Root.Position + Vector3.new(0, 2, 0), STONE, 8, 3)
			task.delay(GUARD_REGEN, function()
				if hum.Health > 0 then
					guard = true
					ctx.Model:SetAttribute("Guarded", true)
				end
			end)
			return
		end
		last = hum.Health
	end)
end

local function slam(ctx, radius, mult)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Slam")
	ctx.Hum:MoveTo(root.Position)
	FoeKit.Face(root, ctx.Target.Position)
	FoeKit.TelegraphCircle(root.Position, radius, AMBER, 1.0)
	FoeKit.Windup(model, 1.0)
	if not ctx:Wait(1.0) then
		return
	end
	FoeKit.Shockwave(root.Position, radius, AMBER)
	FoeKit.Burst(root.Position, STONE, 12, radius * 0.6)
	for _, char in FoeKit.InCircle(root.Position, radius) do
		if FoeKit.Hit(model, char, ctx.Damage * mult) then
			FoeKit.Slow(char, 0, 1.2)
		end
	end
	ctx:Wait(0.9)
end

local function boulder(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Boulder")
	ctx.Hum:MoveTo(root.Position)
	FoeKit.Face(root, ctx.Target.Position)
	local landing = ctx.Target.Position
	FoeKit.TelegraphCircle(landing, 5, AMBER, 1.1)
	FoeKit.Windup(model, 0.4)
	if not ctx:Wait(0.4) then
		return
	end
	local rock = FoeKit.FxPart({
		Size = Vector3.new(3, 3, 3), Color = STONE, Material = Enum.Material.Slate, Shape = Enum.PartType.Ball,
	})
	local floorY = FoeKit.FloorAt(landing)
	task.spawn(function()
		FoeKit.Lob(rock, root.Position + Vector3.new(0, 5, 0), Vector3.new(landing.X, floorY + 1.5, landing.Z), 0.7, 12)
		FoeKit.Shockwave(landing, 5, AMBER)
		FoeKit.Burst(landing, STONE, 10, 4)
		for _, char in FoeKit.InCircle(landing, 5) do
			FoeKit.Hit(model, char, ctx.Damage)
		end
	end)
	ctx:Wait(0.8)
end

function Foe.Think(ctx)
	local dist = ctx.Dist
	if ctx.Elite then
		if dist < 13 and ctx:Ready("Slam", 4) then
			return slam(ctx, 14, 1.3)
		elseif dist > 15 and dist < 45 and ctx:Ready("Boulder", 3.5) then
			return boulder(ctx)
		end
	elseif dist < 9 and ctx:Ready("Slam", 4) then
		return slam(ctx, 11, 1.2)
	end
	if dist < 5 then
		return FoeKit.Melee(ctx, 6, 1)
	end
	ctx.Hum:MoveTo(ctx.Target.Position)
end

return Foe
