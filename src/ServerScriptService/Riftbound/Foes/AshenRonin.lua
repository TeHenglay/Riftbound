-- Fire: Ashen Ronin (elite: Kiln Oni Captain). Vashra's burnt fire-wardens.
-- Grunt: walks in, crouches behind a red line, then iaido-dashes through it
-- and leaves burning ground. Elite: a three-hit kanabo combo ending in a
-- slam that leaves a ring of fire.
local FoeKit = require(script.Parent.FoeKit)

local Foe = {
	Id = "AshenRonin",
	EliteId = "KilnOniCaptain",
	Name = "Ashen Ronin",
	EliteName = "Kiln Oni Captain",
	Color = Color3.fromRGB(255, 106, 43),
	Stats = {
		Grunt = { Health = 1, Speed = 13 },
		Elite = { Health = 1, Speed = 10, Scale = 1.6 },
	},
}

local FIRE = Color3.fromRGB(255, 106, 43)
local EMBER = Color3.fromRGB(255, 190, 90)
local ASH = Color3.fromRGB(228, 216, 206)
local OBSIDIAN = Color3.fromRGB(28, 23, 22)
local CRIMSON = Color3.fromRGB(168, 36, 26)

function Foe.Build(b, elite)
	local d = b.Limbs({ Height = 6.2, Width = 1.8, LegH = 2.6, ArmH = 2.3, BodyColor = OBSIDIAN, LimbColor = OBSIDIAN, LegColor = Color3.fromRGB(31, 21, 21) })
	local neon = { Material = Enum.Material.Neon }
	-- Haori, obi and lava cracks.
	b.Part("CoatL", Vector3.new(0.25, 3.6, 1.25), Vector3.new(-0.98, d.BodyTop - 1.9, 0), CRIMSON)
	b.Part("CoatR", Vector3.new(0.25, 3.6, 1.25), Vector3.new(0.98, d.BodyTop - 1.9, 0), CRIMSON)
	b.Part("CoatBack", Vector3.new(2.1, 3.8, 0.15), Vector3.new(0, d.BodyTop - 2, 0.62), CRIMSON)
	b.Part("Obi", Vector3.new(1.9, 0.35, 1.2), Vector3.new(0, d.BodyTop - 2.05, 0), Color3.fromRGB(194, 43, 20))
	b.Part("Crack", Vector3.new(0.12, 1.2, 0.05), CFrame.new(0.2, d.BodyTop - 0.9, -0.57) * CFrame.Angles(0, 0, 0.4), FIRE, neon)
	-- Lamellar shoulder plates.
	for _, side in { -1, 1 } do
		b.Part(if side < 0 then "PlateL" else "PlateR", Vector3.new(0.9, 0.35, 1.3), CFrame.new(side * (d.ArmX + 0.05), d.BodyTop - 0.05, 0) * CFrame.Angles(0, 0, side * -0.35), Color3.fromRGB(42, 34, 32), { AttachTo = if side < 0 then "ArmL" else "ArmR" })
	end
	-- Head, flame hair, oni mask and horn.
	local hy = d.HeadY
	b.Part("Skull", Vector3.new(1.1, 1.15, 1.05), Vector3.new(0, hy, 0), ASH)
	b.Part("Hair", Vector3.new(1.2, 0.9, 1.15), CFrame.new(0, hy + 0.75, 0.05) * CFrame.Angles(0.2, 0, 0), EMBER, neon)
	b.Part("HairTip", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0, hy + 1.3, 0.15) * CFrame.Angles(0.3, 0.6, 0), FIRE, neon)
	b.Part("EyeL", Vector3.new(0.28, 0.08, 0.05), Vector3.new(-0.24, hy + 0.1, -0.53), FIRE, neon)
	b.Part("EyeR", Vector3.new(0.28, 0.08, 0.05), Vector3.new(0.24, hy + 0.1, -0.53), FIRE, neon)
	b.Part("Mask", Vector3.new(1.14, if elite then 1.1 else 0.5, 0.12), Vector3.new(0, if elite then hy else hy - 0.3, -0.53), Color3.fromRGB(26, 16, 16))
	b.Part("Teeth", Vector3.new(0.7, 0.08, 0.05), Vector3.new(0, hy - 0.35, -0.6), FIRE, neon)
	b.Part("Horn", Vector3.new(0.18, 0.9, 0.18), CFrame.new(0.4, hy + 0.85, -0.2) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(26, 16, 16))
	if elite then
		b.Part("HornL", Vector3.new(0.18, 0.9, 0.18), CFrame.new(-0.4, hy + 0.85, -0.2) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(26, 16, 16))
		-- Kanabo: a studded iron club in the right hand.
		b.Part("Kanabo", Vector3.new(0.5, 0.5, 4.2), Vector3.new(d.ArmX, d.HandY, -1.8), Color3.fromRGB(40, 32, 30), { AttachTo = "ArmR" })
		for i = 0, 3 do
			b.Part("Stud" .. i, Vector3.new(0.62, 0.14, 0.14), Vector3.new(d.ArmX, d.HandY, -2.4 - i * 0.45), FIRE, { Material = Enum.Material.Neon, AttachTo = "ArmR" })
		end
	else
		-- Nodachi with a molten edge, and the sheath at the left hip.
		b.Part("Tsuka", Vector3.new(0.22, 0.22, 0.9), Vector3.new(d.ArmX, d.HandY, -0.2), Color3.fromRGB(60, 20, 14), { AttachTo = "ArmR" })
		b.Part("Tsuba", Vector3.new(0.5, 0.5, 0.08), Vector3.new(d.ArmX, d.HandY, -0.68), EMBER, { AttachTo = "ArmR" })
		b.Part("Blade", Vector3.new(0.08, 0.32, 4.8), CFrame.new(d.ArmX, d.HandY - 0.1, -3.1) * CFrame.Angles(0.06, 0, 0), Color3.fromRGB(70, 60, 58), { Material = Enum.Material.Metal, AttachTo = "ArmR" })
		b.Part("Edge", Vector3.new(0.1, 0.08, 4.8), CFrame.new(d.ArmX, d.HandY - 0.27, -3.1) * CFrame.Angles(0.06, 0, 0), EMBER, { Material = Enum.Material.Neon, AttachTo = "ArmR" })
		b.Part("Saya", Vector3.new(0.22, 0.22, 3.4), CFrame.new(-1.05, d.BodyTop - 2.1, 0.3) * CFrame.Angles(-0.35, 0, 0), Color3.fromRGB(43, 13, 8))
	end
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = b.Model:FindFirstChild("Hair")
end

local function iaido(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Dash")
	ctx.Hum:MoveTo(root.Position)
	local dir = (ctx.Target.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local length = 24
	local start = root.Position
	FoeKit.Face(root, start + dir)
	FoeKit.TelegraphLine(start, dir, length, 4, Color3.fromRGB(255, 60, 40), 0.7)
	FoeKit.Windup(model, 0.7)
	if not ctx:Wait(0.7) then
		return
	end
	FoeKit.Dash(model, dir, length, 0.18)
	task.wait(0.05)
	for _, char in FoeKit.InLine(start, dir, length, 4) do
		if FoeKit.Hit(model, char, ctx.Damage * 1.4) then
			FoeKit.Burn(char, ctx.Damage * 0.3, 3)
		end
	end
	-- Burning trail along the path.
	for i = 1, 4 do
		FoeKit.Zone(start + dir * (i * length / 5), 2.6, FIRE, 2.5, function(char)
			FoeKit.Burn(char, ctx.Damage * 0.3, 1.5)
		end, 0.5)
	end
	ctx:Wait(0.6)
end

local function combo(ctx)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Combo")
	ctx.Hum:MoveTo(root.Position)
	for i = 1, 2 do
		if not ctx.Target.Parent then
			return
		end
		FoeKit.Face(root, ctx.Target.Position)
		local at = root.Position + root.CFrame.LookVector * 5
		FoeKit.TelegraphCircle(at, 5, Color3.fromRGB(255, 60, 40), 0.45)
		FoeKit.Windup(model, 0.45)
		if not ctx:Wait(0.45) then
			return
		end
		FoeKit.Dash(model, root.CFrame.LookVector, 3, 0.12)
		FoeKit.Shockwave(at, 5, FIRE)
		for _, char in FoeKit.InCircle(at, 5) do
			FoeKit.Hit(model, char, ctx.Damage)
		end
		if not ctx:Wait(0.25) then
			return
		end
	end
	-- Final slam: fire ring around the oni.
	FoeKit.TelegraphCircle(root.Position, 10, Color3.fromRGB(255, 60, 40), 0.8)
	FoeKit.Windup(model, 0.8)
	if not ctx:Wait(0.8) then
		return
	end
	FoeKit.Shockwave(root.Position, 10, FIRE)
	FoeKit.Burst(root.Position, FIRE, 14, 6)
	for _, char in FoeKit.InCircle(root.Position, 10) do
		if FoeKit.Hit(model, char, ctx.Damage * 1.5) then
			FoeKit.Burn(char, ctx.Damage * 0.3, 3)
		end
	end
	FoeKit.Zone(root.Position, 10, FIRE, 3, function(char)
		FoeKit.Burn(char, ctx.Damage * 0.25, 1)
	end, 0.5)
	ctx:Wait(0.8)
end

function Foe.Think(ctx)
	local dist = ctx.Dist
	if ctx.Elite then
		if dist < 8 and ctx:Ready("Combo", 3.5) then
			return combo(ctx)
		elseif dist < 5 then
			return FoeKit.Melee(ctx, 6, 1)
		end
	else
		if dist < 18 and dist > 5 and ctx:Ready("Dash", 3) then
			return iaido(ctx)
		elseif dist < 5 then
			return FoeKit.Melee(ctx, 5, 1)
		end
	end
	ctx.Hum:MoveTo(ctx.Target.Position)
end

return Foe
