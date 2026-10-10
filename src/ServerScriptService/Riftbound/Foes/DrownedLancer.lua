-- Water: Drowned Lancer (elite: Abyssal Court Knight). Nerevyn's drowned guard.
-- Grunt: keeps to mid range and throws tide spears along a blue line; when
-- crowded it splashes backwards and leaves a slowing puddle. Elite: a coral
-- shield that halves damage while it walks, and a wave that sweeps the arena.
local Debris = game:GetService("Debris")

local FoeKit = require(script.Parent.FoeKit)

local Foe = {
	Id = "DrownedLancer",
	EliteId = "AbyssalCourtKnight",
	Name = "Drowned Lancer",
	EliteName = "Abyssal Court Knight",
	Color = Color3.fromRGB(52, 152, 255),
	Stats = {
		Grunt = { Health = 0.9, Speed = 11 },
		Elite = { Health = 1.1, Speed = 9, Scale = 1.6 },
	},
}

local TIDE = Color3.fromRGB(79, 240, 255)
local NAVY = Color3.fromRGB(16, 46, 94)
local SKIN = Color3.fromRGB(207, 227, 234)
local CORAL = Color3.fromRGB(255, 122, 138)
local SILVER = Color3.fromRGB(200, 214, 224)

function Foe.Build(b, elite)
	local d = b.Limbs({ Height = 6.3, Width = 1.6, LegH = 2.6, ArmH = 2.4, BodyColor = NAVY, LimbColor = NAVY, LegColor = Color3.fromRGB(40, 110, 170) })
	local neon = { Material = Enum.Material.Neon }
	-- Legs are a column of sea spray.
	for _, name in { "LegL", "LegR" } do
		local leg = b.Model[name]
		leg.Material = Enum.Material.Glass
		leg.Transparency = 0.35
	end
	b.Part("CoatSkirt", Vector3.new(1.9, 2.2, 1.3), Vector3.new(0, d.BodyTop - 2.6, 0.05), NAVY)
	b.Part("Collar", Vector3.new(0.8, 1.4, 0.06), Vector3.new(0, d.BodyTop - 0.6, -0.56), SKIN)
	b.Part("TrimL", Vector3.new(0.08, 2.6, 0.06), CFrame.new(-0.35, d.BodyTop - 1.2, -0.57) * CFrame.Angles(0, 0, -0.18), TIDE, neon)
	b.Part("TrimR", Vector3.new(0.08, 2.6, 0.06), CFrame.new(0.35, d.BodyTop - 1.2, -0.57) * CFrame.Angles(0, 0, 0.18), TIDE, neon)
	b.Part("Sash", Vector3.new(1.7, 0.3, 1.2), Vector3.new(0, d.BodyTop - 1.9, 0), CORAL)
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "ArmL" else "ArmR"
		b.Part("Sleeve" .. limb, Vector3.new(1.0, 1.6, 1.0), Vector3.new(side * d.ArmX, d.BodyTop - 1.6, 0), NAVY, { AttachTo = limb })
		b.Part("Hand" .. limb, Vector3.new(0.5, 0.5, 0.5), Vector3.new(side * d.ArmX, d.HandY, 0), SKIN, { AttachTo = limb })
	end
	-- Head, floating hair, glowing eyes and a coral crown.
	local hy = d.HeadY
	b.Part("Skull", Vector3.new(1.0, 1.1, 1.0), Vector3.new(0, hy, 0), SKIN)
	b.Part("Hair", Vector3.new(1.15, 0.6, 1.15), Vector3.new(0, hy + 0.45, 0.05), Color3.fromRGB(11, 42, 92))
	b.Part("HairFlow", Vector3.new(1.0, 0.4, 2.2), CFrame.new(0, hy + 0.3, 1.2) * CFrame.Angles(0.5, 0, 0), Color3.fromRGB(30, 110, 150))
	b.Part("EyeL", Vector3.new(0.24, 0.1, 0.05), Vector3.new(-0.22, hy + 0.05, -0.51), TIDE, neon)
	b.Part("EyeR", Vector3.new(0.24, 0.1, 0.05), Vector3.new(0.22, hy + 0.05, -0.51), TIDE, neon)
	for i = -1, 1 do
		b.Part("Coral" .. i, Vector3.new(0.18, 0.8, 0.18), CFrame.new(i * 0.32, hy + 1.0, -0.1) * CFrame.Angles(0, 0, -i * 0.35), CORAL, neon)
	end
	-- Silver trident in the right hand, held upright.
	local tx = d.ArmX + 0.1
	b.Part("Shaft", Vector3.new(0.18, 7, 0.18), Vector3.new(tx, d.HandY + 1.5, -0.35), SILVER, { Material = Enum.Material.Metal, AttachTo = "ArmR" })
	local tipY = d.HandY + 5
	b.Part("Crossbar", Vector3.new(1.3, 0.14, 0.14), Vector3.new(tx, tipY, -0.35), SILVER, { Material = Enum.Material.Metal, AttachTo = "ArmR" })
	for i = -1, 1 do
		b.Part("Prong" .. i, Vector3.new(0.12, if i == 0 then 1.4 else 1.0, 0.12), Vector3.new(tx + i * 0.6, tipY + (if i == 0 then 0.7 else 0.5), -0.35), TIDE, { Material = Enum.Material.Neon, AttachTo = "ArmR" })
	end
	if elite then
		b.Part("Shield", Vector3.new(0.3, 3.2, 2.0), CFrame.new(-(d.ArmX + 0.4), d.HandY + 0.8, -0.6) * CFrame.Angles(0, 0.3, 0), CORAL, { Material = Enum.Material.Marble, AttachTo = "ArmL" })
		b.Part("ShieldGem", Vector3.new(0.12, 0.6, 0.6), CFrame.new(-(d.ArmX + 0.58), d.HandY + 0.9, -0.6) * CFrame.Angles(0, 0.3, 0), TIDE, { Material = Enum.Material.Neon, AttachTo = "ArmL" })
	end
	local light = Instance.new("PointLight")
	light.Color = TIDE
	light.Range = 9
	light.Brightness = 1.2
	light.Parent = b.Model:FindFirstChild("Skull")
end

-- Elite shield: halves damage taken while it is not mid-attack.
function Foe.Setup(ctx)
	if not ctx.Elite then
		return
	end
	local hum = ctx.Hum
	local last = hum.Health
	hum.HealthChanged:Connect(function(hp)
		if hp > 0 and hp < last and not ctx.Attacking then
			hum.Health = hp + (last - hp) * 0.5
		end
		last = hum.Health
	end)
end

local function spear(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Spear")
	ctx.Attacking = true
	ctx.Hum:MoveTo(root.Position)
	local dir = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.5 then
		ctx.Attacking = false
		return
	end
	dir = dir.Unit
	FoeKit.Face(root, root.Position + dir)
	FoeKit.TelegraphLine(root.Position, dir, 40, 3, TIDE, 0.6)
	FoeKit.Windup(model, 0.6)
	if not ctx:Wait(0.6) then
		ctx.Attacking = false
		return
	end
	local lance = FoeKit.FxPart({ Size = Vector3.new(0.4, 0.4, 4), Color = TIDE })
	local origin = root.Position + Vector3.new(0, 0.5, 0)
	task.spawn(FoeKit.Projectile, lance, origin, dir, { Speed = 75, Range = 40, Radius = 2 }, function(char)
		if FoeKit.Hit(model, char, ctx.Damage * 1.2) then
			FoeKit.Slow(char, 0.6, 2)
		end
	end)
	ctx.Attacking = false
	ctx:Wait(0.4)
end

local function splashBack(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Splash")
	local away = (root.Position - ctx.Target.Position) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.5 then
		away = -root.CFrame.LookVector
	end
	FoeKit.Zone(root.Position, 5, TIDE, 3, function(char)
		FoeKit.Slow(char, 0.5, 0.8)
	end, 0.3)
	FoeKit.Burst(root.Position, TIDE, 8, 3)
	FoeKit.Dash(model, away.Unit, 12, 0.3)
	ctx:Wait(0.4)
end

local function wave(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Wave")
	ctx.Attacking = true
	ctx.Hum:MoveTo(root.Position)
	local dir = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.5 then
		ctx.Attacking = false
		return
	end
	dir = dir.Unit
	FoeKit.Face(root, root.Position + dir)
	FoeKit.TelegraphLine(root.Position, dir, 40, 14, TIDE, 1.2)
	FoeKit.Windup(model, 1.2)
	if not ctx:Wait(1.2) then
		ctx.Attacking = false
		return
	end
	local wall = FoeKit.FxPart({ Size = Vector3.new(14, 5, 2), Color = Color3.fromRGB(52, 152, 255), Transparency = 0.3 })
	local origin = Vector3.new(root.Position.X, FoeKit.FloorAt(root.Position) + 2.5, root.Position.Z)
	task.spawn(FoeKit.Projectile, wall, origin, dir, { Speed = 40, Range = 40, Radius = 7, Pierce = true }, function(char)
		if FoeKit.Hit(model, char, ctx.Damage * 1.3) then
			FoeKit.Knock(char, dir * 50)
			FoeKit.Slow(char, 0.6, 2)
		end
	end)
	Debris:AddItem(wall, 2)
	ctx.Attacking = false
	ctx:Wait(0.6)
end

function Foe.Think(ctx)
	local dist, root = ctx.Dist, ctx.Root
	if ctx.Elite and dist < 30 and ctx:Ready("Wave", 6) then
		return wave(ctx)
	end
	if dist < 9 and ctx:Ready("Splash", 4) then
		return splashBack(ctx)
	end
	if dist < 32 and ctx:Ready("Spear", if ctx.Elite then 3.5 else 2.6) then
		return spear(ctx)
	end
	if dist < 5 then
		return FoeKit.Melee(ctx, 5, 1)
	end
	-- Hold mid range: close in when far, back off when near.
	local flat = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dist > 20 then
		ctx.Hum:MoveTo(ctx.Target.Position)
	elseif dist < 12 and flat.Magnitude > 0.5 then
		ctx.Hum:MoveTo(root.Position - flat.Unit * 6)
	else
		ctx.Hum:MoveTo(root.Position + Vector3.new(-flat.Z, 0, flat.X).Unit * 4)
	end
end

return Foe
