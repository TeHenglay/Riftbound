-- Lightning: Thunderfallen Herald (elite: Stormbreaker Paladin). Voltrex's
-- fallen temple knights. Grunt: marks a circle where you stand, then lands
-- there as a lightning bolt; the shock chains to a nearby player. Elite:
-- three bolts in a row toward you, then a ring of sparks around itself.
local FoeKit = require(script.Parent.FoeKit)

local Foe = {
	Id = "ThunderfallenHerald",
	EliteId = "StormbreakerPaladin",
	Name = "Thunderfallen Herald",
	EliteName = "Stormbreaker Paladin",
	Color = Color3.fromRGB(250, 225, 60),
	Stats = {
		Grunt = { Health = 1, Speed = 11 },
		Elite = { Health = 1.1, Speed = 10, Scale = 1.6 },
	},
}

local GOLD = Color3.fromRGB(250, 225, 60)
local SPARK = Color3.fromRGB(255, 246, 160)
local PLATE = Color3.fromRGB(226, 222, 240)
local VIOLET = Color3.fromRGB(70, 52, 138)
local DEEP = Color3.fromRGB(42, 32, 80)

function Foe.Build(b, elite)
	local d = b.Limbs({ Height = 6.4, Width = 1.8, LegH = 2.6, ArmH = 2.4, BodyColor = PLATE, LimbColor = DEEP, LegColor = PLATE })
	local neon = { Material = Enum.Material.Neon }
	local metal = { Material = Enum.Material.Metal }
	b.Model.Body.Material = Enum.Material.Metal
	b.Part("Tabard", Vector3.new(0.9, 3.2, 0.08), Vector3.new(0, d.BodyTop - 1.7, -0.58), VIOLET)
	b.Part("ChestBolt", Vector3.new(0.12, 1.1, 0.05), CFrame.new(0, d.BodyTop - 0.9, -0.64) * CFrame.Angles(0, 0, 0.35), GOLD, neon)
	b.Part("Belt", Vector3.new(1.9, 0.25, 1.2), Vector3.new(0, d.BodyTop - 2.05, 0), GOLD, metal)
	b.Part("Cape", Vector3.new(2.0, 4.2, 0.12), CFrame.new(0, d.BodyTop - 2.0, 0.65) * CFrame.Angles(-0.08, 0, 0), VIOLET)
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "ArmL" else "ArmR"
		b.Part("Pauldron" .. limb, Vector3.new(1.0, 0.6, 1.3), Vector3.new(side * (d.ArmX + 0.05), d.BodyTop - 0.1, 0), PLATE, { Material = Enum.Material.Metal, AttachTo = limb })
		b.Part("PauldronTrim" .. limb, Vector3.new(1.02, 0.1, 1.32), Vector3.new(side * (d.ArmX + 0.05), d.BodyTop - 0.4, 0), GOLD, { Material = Enum.Material.Metal, AttachTo = limb })
		b.Part("Gauntlet" .. limb, Vector3.new(0.8, 0.8, 0.8), Vector3.new(side * d.ArmX, d.HandY + 0.1, 0), PLATE, { Material = Enum.Material.Metal, AttachTo = limb })
	end
	-- Visored helm with a crest, and the broken halo behind it.
	local hy = d.HeadY
	b.Part("Helm", Vector3.new(1.1, 1.25, 1.1), Vector3.new(0, hy, 0), PLATE, metal)
	b.Part("Visor", Vector3.new(0.85, 0.12, 0.05), Vector3.new(0, hy + 0.05, -0.56), GOLD, neon)
	b.Part("Crest", Vector3.new(0.12, 0.7, 0.5), CFrame.new(0, hy + 0.85, -0.2) * CFrame.Angles(0.3, 0, 0), GOLD, metal)
	for i = 0, 8 do
		local a = math.rad(-110 + i * 30) -- a ring with a gap at the bottom-left
		b.Part("Halo" .. i, Vector3.new(0.14, 0.14, 0.62), CFrame.new(math.cos(a) * 1.05, hy + 0.3 + math.sin(a) * 1.05, 0.7) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(a, 0, 0), GOLD, neon)
	end
	-- Lightning wing(s): jagged neon spars off the back.
	local sides = if elite then { -1, 1 } else { -1 }
	for _, side in sides do
		for i = 0, 2 do
			b.Part("Wing" .. side .. i, Vector3.new(0.14, 0.14, 2.6 - i * 0.4), CFrame.new(side * (1.4 + i * 0.25), d.BodyTop - 0.3 + i * 0.6 - 0.6, 0.9) * CFrame.Angles(0, side * 1.2, side * (0.4 - i * 0.45)), SPARK, neon)
		end
	end
	-- Glaive: a long violet pole with a curved gold blade.
	local gx = d.ArmX + 0.1
	b.Part("Pole", Vector3.new(0.18, 7.4, 0.18), Vector3.new(gx, d.HandY + 1.8, -0.35), DEEP, { Material = Enum.Material.Metal, AttachTo = "ArmR" })
	local tipY = d.HandY + 5.5
	b.Part("GlaiveBlade", Vector3.new(0.08, 1.8, 0.6), CFrame.new(gx, tipY + 0.7, -0.6) * CFrame.Angles(0.35, 0, 0), PLATE, { Material = Enum.Material.Metal, AttachTo = "ArmR" })
	b.Part("GlaiveEdge", Vector3.new(0.1, 1.8, 0.1), CFrame.new(gx, tipY + 0.7, -0.92) * CFrame.Angles(0.35, 0, 0), GOLD, { Material = Enum.Material.Neon, AttachTo = "ArmR" })
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = b.Model:FindFirstChild("Visor")
end

-- Shocks a character, then chains to the nearest other player within 12.
local function shock(model, char, amount, chained)
	if not FoeKit.Hit(model, char, amount) then
		return
	end
	FoeKit.Slow(char, 0.7, 0.6)
	local r = char:FindFirstChild("HumanoidRootPart")
	if chained or not r then
		return
	end
	for _, other in FoeKit.InCircle(r.Position, 12) do
		if other ~= char then
			local o = other:FindFirstChild("HumanoidRootPart")
			if o then
				local mid = (r.Position + o.Position) / 2
				local arc = FoeKit.FxPart({
					Size = Vector3.new(0.3, 0.3, (o.Position - r.Position).Magnitude), Color = SPARK,
					CFrame = CFrame.lookAt(mid, o.Position),
				})
				game:GetService("Debris"):AddItem(arc, 0.15)
				shock(model, other, amount * 0.5, true)
			end
			break
		end
	end
end

local function thunderStep(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Step")
	ctx.Hum:MoveTo(root.Position)
	local spot = ctx.Target.Position
	FoeKit.TelegraphCircle(spot, 6, GOLD, 0.9)
	FoeKit.Windup(model, 0.9)
	if not ctx:Wait(0.9) then
		return
	end
	FoeKit.Bolt(root.Position, SPARK)
	FoeKit.Teleport(model, spot, ctx.Target.Position)
	FoeKit.Bolt(spot, SPARK)
	FoeKit.Shockwave(spot, 6, GOLD)
	for _, char in FoeKit.InCircle(spot, 6) do
		shock(model, char, ctx.Damage * 1.3)
	end
	ctx:Wait(0.7)
end

local function boltLine(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Line")
	ctx.Hum:MoveTo(root.Position)
	local dir = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	FoeKit.Face(root, root.Position + dir)
	FoeKit.Windup(model, 0.9)
	local spots = {}
	for i = 1, 3 do
		spots[i] = root.Position + dir * (6 + i * 7)
		FoeKit.TelegraphCircle(spots[i], 5, GOLD, 0.8 + i * 0.25)
	end
	if not ctx:Wait(0.8) then
		return
	end
	for i = 1, 3 do
		FoeKit.Bolt(spots[i], SPARK)
		FoeKit.Shockwave(spots[i], 5, GOLD)
		for _, char in FoeKit.InCircle(spots[i], 5) do
			shock(model, char, ctx.Damage)
		end
		if not ctx:Wait(0.25) then
			return
		end
	end
	-- Ring of sparks: safe right next to the paladin.
	FoeKit.TelegraphCircle(root.Position, 13, GOLD, 1.0, 5)
	if not ctx:Wait(1.0) then
		return
	end
	FoeKit.Shockwave(root.Position, 13, SPARK)
	for _, char in FoeKit.InCircle(root.Position, 13, 5) do
		shock(model, char, ctx.Damage * 1.2)
	end
	ctx:Wait(0.8)
end

function Foe.Think(ctx)
	local dist = ctx.Dist
	if ctx.Elite and dist < 30 and ctx:Ready("Line", 6) then
		return boltLine(ctx)
	end
	if dist > 8 and dist < 45 and ctx:Ready("Step", if ctx.Elite then 4.5 else 3.5) then
		return thunderStep(ctx)
	end
	if dist < 6 then
		return FoeKit.Melee(ctx, 7, 1.1)
	end
	ctx.Hum:MoveTo(ctx.Target.Position)
end

return Foe
