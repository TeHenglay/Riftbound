-- The story's wave mobs: one element golem per nation (Magma, Moss, Tide,
-- Gale, Storm). Every wave kind is the same golem at a different size:
-- Swarmers are small and quick, Grunts are the base golem, Brutes and Elites
-- are bigger and add a ground slam.
-- The Blender-made golem lives in ServerStorage.RiftboundAssets.Foes.<Id>
-- (art/models/<nation>/<Nation>Golem_Parts.fbx); until it is imported the
-- golem is built from blocks in its element colours.
-- VFX: the element particles (flames, motes, drips...) are part of each Studio
-- template. The spawn swirl and the slam impact are the templates
-- ReplicatedStorage.RiftboundVFX.GolemSpawn_<Nation> / GolemSlam_<Nation>,
-- played on every client through the SkillFx remote (SkillVFX.onGolemSpawn /
-- onGolemSlam).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FoeKit = require(script.Parent.FoeKit)

local NationGolem = {}

-- Size and stat multipliers per wave kind (on top of Story.Kinds).
NationGolem.Kinds = {
	Swarmer = { Scale = 0.75, Health = 1, Slam = false },
	Grunt = { Scale = 1, Health = 1, Slam = false },
	Brute = { Scale = 1.3, Health = 1, Slam = true },
	Elite = { Scale = 1.6, Health = 1, Slam = true },
}

local LOOKS = {
	Fire = { Name = "Magma Golem", Rock = Color3.fromRGB(38, 30, 28), Glow = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Basalt },
	Earth = { Name = "Moss Golem", Rock = Color3.fromRGB(92, 72, 52), Glow = Color3.fromRGB(70, 210, 90), Material = Enum.Material.Slate },
	Water = { Name = "Tide Golem", Rock = Color3.fromRGB(28, 92, 160), Glow = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Glass },
	Wind = { Name = "Gale Golem", Rock = Color3.fromRGB(120, 150, 150), Glow = Color3.fromRGB(120, 255, 210), Material = Enum.Material.SmoothPlastic },
	Lightning = { Name = "Storm Golem", Rock = Color3.fromRGB(30, 28, 36), Glow = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Basalt },
}

local function build(look)
	return function(b)
		local neon = { Material = Enum.Material.Neon }
		local rock = { Material = look.Material }
		-- Blocky R15-style golem: chunky limbs, slim torso, Roblox head.
		b.Part("LegL", Vector3.new(1, 2, 1), Vector3.new(-0.55, 1, 0), look.Rock, rock)
		b.Part("LegR", Vector3.new(1, 2, 1), Vector3.new(0.55, 1, 0), look.Rock, rock)
		b.Part("Body", Vector3.new(1.95, 2.1, 1.15), Vector3.new(0, 3.05, 0), look.Rock, rock)
		b.Part("ArmL", Vector3.new(1.1, 2.3, 1.1), Vector3.new(-1.55, 2.95, 0), look.Rock, rock)
		b.Part("ArmR", Vector3.new(1.1, 2.3, 1.1), Vector3.new(1.55, 2.95, 0), look.Rock, rock)
		-- Not "Head": the dummy's own Head carries the health bar.
		b.Part("GolemHead", Vector3.new(1.2, 1.25, 1.25), CFrame.new(0, 4.75, 0) * CFrame.Angles(0, 0, math.pi / 2), look.Rock, { Material = look.Material, Shape = Enum.PartType.Cylinder })
		b.Part("EyeL", Vector3.new(0.34, 0.1, 0.05), CFrame.new(-0.26, 4.9, -0.63) * CFrame.Angles(0, 0, -0.35), look.Glow, neon)
		b.Part("EyeR", Vector3.new(0.34, 0.1, 0.05), CFrame.new(0.26, 4.9, -0.63) * CFrame.Angles(0, 0, 0.35), look.Glow, neon)
		b.Part("Core", Vector3.new(0.5, 0.5, 0.1), Vector3.new(0, 3.45, -0.6), look.Glow, neon)
		local light = Instance.new("PointLight")
		light.Color = look.Glow
		light.Range = 8
		light.Brightness = 1
		light.Parent = b.Model.Core
	end
end

-- Plays a golem effect (`kind` is "Slam" or "Spawn") on every client.
-- Returns false if the template or remote is missing, so the caller can
-- fall back to parts.
local function golemFx(kind, nation, look, pos, radius)
	local vfx = ReplicatedStorage:FindFirstChild("RiftboundVFX")
	local shared = ReplicatedStorage:FindFirstChild("Riftbound")
	local remotes = shared and shared:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SkillFx")
	if not (vfx and vfx:FindFirstChild("Golem" .. kind .. "_" .. nation) and remote) then
		return false
	end
	remote:FireAllClients({ Type = "Golem" .. kind, Nation = nation, At = pos, Radius = radius, Color = look.Glow })
	return true
end

local function slam(ctx, nation, look, radius)
	local model, root = ctx.Model, ctx.Root
	ctx:Use("Slam")
	ctx.Hum:MoveTo(root.Position)
	FoeKit.Face(root, ctx.Target.Position)
	FoeKit.TelegraphCircle(root.Position, radius, look.Glow, 1.0)
	FoeKit.Windup(model, 1.0)
	if not ctx:Wait(1.0) then
		return
	end
	if not golemFx("Slam", nation, look, root.Position, radius) then
		FoeKit.Shockwave(root.Position, radius, look.Glow)
		FoeKit.Burst(root.Position, look.Rock, 10, radius * 0.6)
	end
	for _, char in FoeKit.InCircle(root.Position, radius) do
		FoeKit.Hit(model, char, ctx.Damage * 1.3)
	end
	ctx:Wait(0.8)
end

-- Returns a foe module in the NationFoes shape for one nation.
function NationGolem.For(nation)
	local look = LOOKS[nation]
	local id = nation .. "Golem"
	local foe = {
		Id = id,
		EliteId = id,
		Name = look.Name,
		EliteName = look.Name,
		Color = look.Glow,
		Build = build(look),
	}
	-- A one-off swirl of light under the golem as it appears.
	function foe.Setup(ctx)
		local kind = NationGolem.Kinds[ctx.Kind] or NationGolem.Kinds.Grunt
		if ctx.Root then
			golemFx("Spawn", nation, look, ctx.Root.Position, 4 * kind.Scale)
		end
	end
	function foe.Think(ctx)
		local dist = ctx.Dist
		local kind = NationGolem.Kinds[ctx.Kind] or NationGolem.Kinds.Grunt
		if kind.Slam and dist < 10 and ctx:Ready("Slam", 5) then
			return slam(ctx, nation, look, 8 * kind.Scale)
		end
		if dist < 4 * kind.Scale + 1 then
			return FoeKit.Melee(ctx, 4 * kind.Scale + 2, 1)
		end
		ctx.Hum:MoveTo(ctx.Target.Position)
	end
	return foe
end

return NationGolem
