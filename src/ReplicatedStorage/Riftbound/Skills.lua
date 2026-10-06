-- Every skill in the game. Base skills have one element; fused skills have two.
-- To add a new fusion, add a skill with two elements: Merge picks it up automatically.
--
-- Kinds (implemented in ServerScriptService.Riftbound.SkillEffects):
--   Projectile  flies toward the aim point and explodes in Radius
--   Line        hits everything in a Length x Width strip in front of you
--   Nova        hits everything within Radius around you
--   Strike      telegraphs at the aim point, then hits Radius after Delay
--   Zone        lingers at the aim point for Duration, hitting every TickRate
--   Chain       hits the enemy nearest the aim point, then jumps Jumps times
--
-- Status keys: Burn {Dps}, Soak, Slow {Amount 0-1}, Stun, Shock (+20% damage taken).
local Skills = {}

Skills.MaxLevel = 5

Skills.Defs = {
	RiftBolt = {
		Name = "Rift Bolt", Elements = {}, Kind = "Projectile",
		Damage = 8, Cooldown = 0.35, Speed = 120, Range = 70, Radius = 3,
		Description = "Your basic attack: a quick bolt of rift energy.",
	},

	-- Base element skills ------------------------------------------------
	Fireball = {
		Name = "Fireball", Elements = { "Fire" }, Kind = "Projectile",
		Damage = 22, Cooldown = 1.6, Speed = 80, Range = 70, Radius = 8,
		Status = { Burn = { Duration = 3, Dps = 6 } },
		Description = "Explodes on impact and sets enemies on fire.",
	},
	TidalWave = {
		Name = "Tidal Wave", Elements = { "Water" }, Kind = "Line",
		Damage = 16, Cooldown = 2.5, Length = 34, Width = 12, Knockback = 40,
		Status = { Soak = { Duration = 5 } },
		Description = "A wave that pushes enemies back and soaks them.",
	},
	StoneSpike = {
		Name = "Stone Spike", Elements = { "Earth" }, Kind = "Strike",
		Damage = 30, Cooldown = 3, Range = 50, Radius = 7, Delay = 0.45,
		Status = { Stun = { Duration = 1 } },
		Description = "Spikes burst from the ground after a short delay and stun.",
	},
	Gust = {
		Name = "Gust", Elements = { "Air" }, Kind = "Nova",
		Damage = 10, Cooldown = 2.2, Radius = 16, Knockback = 70,
		Description = "Blasts every nearby enemy away from you.",
	},
	SparkBolt = {
		Name = "Spark Bolt", Elements = { "Lightning" }, Kind = "Chain",
		Damage = 14, Cooldown = 1.8, Range = 60, Jumps = 3, JumpRange = 18,
		Status = { Shock = { Duration = 3 } },
		Description = "Lightning that jumps between enemies. Shocked enemies take extra damage.",
	},

	-- Fused skills -------------------------------------------------------
	SteamCloud = {
		Name = "Steam Cloud", Elements = { "Fire", "Water" }, Kind = "Zone",
		Damage = 0, TickDamage = 9, TickRate = 0.5, Duration = 5, Cooldown = 6, Range = 55, Radius = 14,
		Status = { Burn = { Duration = 2, Dps = 4 }, Slow = { Duration = 1, Amount = 0.4 } },
		Description = "A scalding cloud that burns and slows everything inside.",
	},
	MagmaBurst = {
		Name = "Magma Burst", Elements = { "Fire", "Earth" }, Kind = "Strike",
		Damage = 55, Cooldown = 4.5, Range = 50, Radius = 12, Delay = 0.6,
		Status = { Burn = { Duration = 4, Dps = 8 } },
		Description = "The ground erupts in molten rock.",
	},
	Firestorm = {
		Name = "Firestorm", Elements = { "Fire", "Air" }, Kind = "Nova",
		Damage = 28, Cooldown = 4, Radius = 24, Knockback = 60,
		Status = { Burn = { Duration = 4, Dps = 7 } },
		Description = "A ring of fire explodes outward from you.",
	},
	PlasmaLance = {
		Name = "Plasma Lance", Elements = { "Fire", "Lightning" }, Kind = "Line",
		Damage = 48, Cooldown = 3.5, Length = 60, Width = 5,
		Status = { Burn = { Duration = 2, Dps = 6 }, Shock = { Duration = 3 } },
		Description = "A beam that burns through everything in a long line.",
	},
	MudTrap = {
		Name = "Mud Trap", Elements = { "Water", "Earth" }, Kind = "Zone",
		Damage = 10, TickDamage = 4, TickRate = 0.5, Duration = 6, Cooldown = 7, Range = 55, Radius = 16,
		Status = { Slow = { Duration = 1, Amount = 0.7 }, Soak = { Duration = 3 } },
		Description = "A sticky swamp that nearly stops enemies and soaks them.",
	},
	FrostGale = {
		Name = "Frost Gale", Elements = { "Water", "Air" }, Kind = "Line",
		Damage = 24, Cooldown = 4, Length = 40, Width = 16, Knockback = 30,
		Status = { Stun = { Duration = 1.6 } },
		Description = "A freezing wind that locks enemies in place.",
	},
	ChainShock = {
		Name = "Chain Shock", Elements = { "Water", "Lightning" }, Kind = "Chain",
		Damage = 22, Cooldown = 3, Range = 60, Jumps = 7, JumpRange = 22,
		Status = { Soak = { Duration = 3 }, Shock = { Duration = 3 } },
		Description = "Lightning that leaps through a whole crowd and soaks it.",
	},
	Sandstorm = {
		Name = "Sandstorm", Elements = { "Earth", "Air" }, Kind = "Zone",
		Damage = 0, TickDamage = 7, TickRate = 0.4, Duration = 5, Cooldown = 6.5, Range = 55, Radius = 18,
		Status = { Slow = { Duration = 1, Amount = 0.35 } },
		Description = "A whirling storm of sand that shreds enemies inside.",
	},
	MagnetQuake = {
		Name = "Magnet Quake", Elements = { "Earth", "Lightning" }, Kind = "Strike",
		Damage = 40, Cooldown = 5, Range = 50, Radius = 20, Delay = 0.5, Pull = 60,
		Status = { Shock = { Duration = 4 }, Stun = { Duration = 0.6 } },
		Description = "Pulls enemies to the centre, then stuns them.",
	},
	Thunderstorm = {
		Name = "Thunderstorm", Elements = { "Air", "Lightning" }, Kind = "Zone",
		Damage = 0, TickDamage = 16, TickRate = 0.7, Duration = 5, Cooldown = 7, Range = 55, Radius = 20,
		Status = { Shock = { Duration = 2 } },
		Description = "A storm cloud that keeps striking enemies below it.",
	},
}

for id, def in Skills.Defs do
	def.Id = id
end

function Skills.DamageMult(level)
	return 1 + 0.25 * (level - 1)
end

function Skills.CooldownOf(id, level)
	return Skills.Defs[id].Cooldown * 0.92 ^ (level - 1)
end

function Skills.IsBase(id)
	local def = Skills.Defs[id]
	return def ~= nil and #def.Elements == 1
end

-- The base skill granted by an element (e.g. "Fire" -> "Fireball").
function Skills.BaseFor(element)
	for id, def in Skills.Defs do
		if #def.Elements == 1 and def.Elements[1] == element then
			return id
		end
	end
	return nil
end

return Skills
