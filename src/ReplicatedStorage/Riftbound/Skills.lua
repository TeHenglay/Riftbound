-- Every skill in the game. Base skills have one element; fused skills have two.
-- To add a new fusion, add a skill with two elements: Merge picks it up automatically.
--
-- Kinds (implemented in ServerScriptService.Riftbound.SkillEffects):
--   Projectile  flies toward the aim point and explodes in Radius (launched
--               after Windup, if set)
--   Line        hits everything in a Length x Width strip in front of you
--   Cone        after Windup, sweeps outward over Sweep seconds and hits
--               everything within Length and Angle degrees of your aim
--   Nova        hits everything within Radius around you (after Windup, if set)
--   Strike      telegraphs at the aim point, then hits Radius after Delay
--   Zone        lingers at the aim point for Duration, hitting every TickRate
--   Chain       hits the enemy nearest the aim point, then jumps Jumps times
--   Tornado     a vortex at the aim point that pulls enemies in (Pull) and
--               ticks TickDamage every TickRate for Duration
--   Magnet      yanks enemies in Radius to the aim point for PullTime, then
--               hits everything gathered there
--   Roller      after Windup, a boulder rolls Length studs forward at Speed,
--               hitting each enemy within Radius of it once
--   Meteor      a rock lands on the aim point after Delay (hits Radius), then
--               leaves a pool (PoolRadius) ticking TickDamage for Duration
--   Leap        the caster jumps (JumpVelocity); on landing, spikes hit
--               InnerRadius, then a second ring hits out to Radius
--
-- Status keys: Burn {Dps}, Soak, Slow {Amount 0-1}, Stun, Shock (+20% damage taken),
-- Freeze (frozen solid: cannot move or attack).
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
		Damage = 10, Cooldown = 2.2, Radius = 16, Knockback = 70, Windup = 0.15,
		Description = "Draws the wind in, then blasts every nearby enemy away from you.",
	},
	SparkBolt = {
		Name = "Spark Bolt", Elements = { "Lightning" }, Kind = "Chain",
		Damage = 14, Cooldown = 1.8, Range = 60, Jumps = 3, JumpRange = 18,
		Status = { Shock = { Duration = 3 } },
		Description = "Lightning that jumps between enemies. Shocked enemies take extra damage.",
	},

	-- Awakened base skills (Vertical Pinnacle Ascension) -----------------
	FireballAwakened = {
		Name = "Fireball Awakened", Elements = { "Fire" }, Kind = "Projectile",
		Damage = 26.4, Cooldown = 1.6, Speed = 85, Range = 75, Radius = 10.4,
		Status = { Burn = { Duration = 3.5, Dps = 8 } },
		Awakened = true, BaseSkill = "Fireball", PerkName = "Molten Crater",
		Description = "Massive raging sun-sphere. Detonation leaves a fiery scorch crater ticking burn damage.",
	},
	TidalWaveAwakened = {
		Name = "Tidal Wave Awakened", Elements = { "Water" }, Kind = "Line",
		Damage = 19.2, Cooldown = 2.5, Length = 46, Width = 16, Knockback = 60,
		Status = { Soak = { Duration = 6 } },
		Awakened = true, BaseSkill = "TidalWave", PerkName = "Surging Rapids",
		Description = "Towering wall of foaming rapids with +50% knockback that leaves flooded ground.",
	},
	StoneSpikeAwakened = {
		Name = "Stone Spike Awakened", Elements = { "Earth" }, Kind = "Strike",
		Damage = 36, Cooldown = 3, Range = 55, Radius = 9.1, Delay = 0.45,
		Status = { Stun = { Duration = 1.6 } },
		Awakened = true, BaseSkill = "StoneSpike", PerkName = "Crush & Concuss",
		Description = "Three crystalline monoliths erupt from the earth, stunning for 1.6s and increasing earth damage taken.",
	},
	GustAwakened = {
		Name = "Gust Awakened", Elements = { "Air" }, Kind = "Nova",
		Damage = 12, Cooldown = 2.2, Radius = 21.6, Knockback = 90, Windup = 0.15,
		Awakened = true, BaseSkill = "Gust", PerkName = "Inward Vortex",
		Description = "Ferocious hurricane vortex that yanks nearby foes inward before blasting them away.",
	},
	SparkBoltAwakened = {
		Name = "Spark Bolt Awakened", Elements = { "Lightning" }, Kind = "Chain",
		Damage = 16.8, Cooldown = 1.8, Range = 65, Jumps = 5, JumpRange = 24,
		Status = { Shock = { Duration = 4 } },
		Awakened = true, BaseSkill = "SparkBolt", PerkName = "Static Tether",
		Description = "Blinding lightning that arcs across 5 targets, creating static tethers that shock foes who cross them.",
	},

	-- Fused skills -------------------------------------------------------
	SteamCloud = {
		Name = "Steam Cloud", Elements = { "Fire", "Water" }, Kind = "Zone",
		Damage = 0, TickDamage = 9, TickRate = 0.5, Duration = 5, Cooldown = 6, Range = 55, Radius = 14,
		Status = { Burn = { Duration = 2, Dps = 4 }, Slow = { Duration = 1, Amount = 0.4 } },
		Description = "A scalding cloud that burns and slows everything inside.",
	},
	MagmaBurst = {
		Name = "Magma Meteor", Elements = { "Fire", "Earth" }, Kind = "Meteor",
		Damage = 60, Cooldown = 6, Range = 50, Radius = 10, Delay = 0.75,
		Duration = 3, PoolRadius = 9, TickDamage = 9, TickRate = 0.5,
		Status = { Burn = { Duration = 3, Dps = 8 } },
		Description = "Calls a molten rock down from the sky. It leaves a pool of lava that burns for 3 seconds.",
	},
	Firestorm = {
		Name = "Firestorm", Elements = { "Fire", "Air" }, Kind = "Tornado",
		Damage = 14, TickDamage = 8, TickRate = 0.4, Duration = 2.6, Cooldown = 6, Range = 45, Radius = 15, Pull = 26,
		Status = { Burn = { Duration = 3, Dps = 7 } },
		Description = "Summons a fire tornado that drags enemies into its heart and burns them.",
	},
	PlasmaLance = {
		Name = "Plasma Lance", Elements = { "Fire", "Lightning" }, Kind = "Projectile",
		Damage = 52, Cooldown = 3.5, Speed = 140, Range = 70, Radius = 10, Windup = 0.22,
		Status = { Burn = { Duration = 4, Dps = 9 }, Shock = { Duration = 3 } },
		Description = "Hurls a spear of plasma that flies straight and explodes on impact, setting enemies ablaze.",
	},
	MudTrap = {
		Name = "Mudslide", Elements = { "Water", "Earth" }, Kind = "Roller",
		Damage = 38, Cooldown = 5, Speed = 34, Length = 45, Radius = 4.5, Windup = 0.3, Knockback = 45,
		Status = { Soak = { Duration = 3 }, Slow = { Duration = 3, Amount = 0.45 } },
		Description = "Heaves a giant mud boulder that rolls forward, flattening enemies and leaving them soaked and slowed.",
	},
	FrostGale = {
		Name = "Frost Gale", Elements = { "Water", "Air" }, Kind = "Cone",
		Damage = 30, Cooldown = 5, Length = 28, Angle = 70, Sweep = 0.45, Windup = 0.18,
		Status = { Freeze = { Duration = 2 }, Slow = { Duration = 4, Amount = 0.4 } },
		Description = "Breathes a blizzard in a wide cone, freezing enemies solid in blocks of ice.",
	},
	-- Id kept as ChainShock (saves, crafting and icons use it); it plays as
	-- Thunder Serpent now. Jumps = how many enemies it steers toward.
	ChainShock = {
		Name = "Thunder Serpent", Elements = { "Water", "Lightning" }, Kind = "Serpent",
		Damage = 22, Cooldown = 3, Range = 60, Jumps = 7, JumpRange = 22, Speed = 48, Radius = 3.5,
		Status = { Soak = { Duration = 3 }, Shock = { Duration = 3 } },
		Description = "A serpent of water and lightning that weaves through a crowd, biting, soaking and shocking every enemy it passes.",
	},
	Sandstorm = {
		Name = "Quake Leap", Elements = { "Earth", "Air" }, Kind = "Leap",
		Damage = 42, Cooldown = 6.5, JumpVelocity = 80, InnerRadius = 7, Radius = 13,
		Status = { Stun = { Duration = 0.8 }, Slow = { Duration = 2, Amount = 0.35 } },
		Description = "Leap high on a gust of wind, then slam down and raise two rings of stone spikes around you.",
	},
	MagnetQuake = {
		Name = "Magnet Quake", Elements = { "Earth", "Lightning" }, Kind = "Magnet",
		Damage = 48, Cooldown = 5.5, Range = 50, Radius = 22, PullTime = 0.6,
		Status = { Shock = { Duration = 4 }, Stun = { Duration = 1 } },
		Description = "A magnetic core yanks every nearby enemy into one spot, then detonates in a shock blast.",
	},
	Thunderstorm = {
		Name = "Thunderstorm", Elements = { "Air", "Lightning" }, Kind = "Zone",
		Damage = 0, TickDamage = 16, TickRate = 0.7, Duration = 5, Cooldown = 7, Range = 55, Radius = 20,
		Status = { Shock = { Duration = 2 } },
		Description = "A storm cloud that keeps striking enemies below it.",
	},
}

-- Awakened fusions: every fused skill has an Awakened form (made at the
-- Awakening Altar). Built from the fusion: +20% damage, +25% area, effects
-- last 25% longer (zones +1s), +30% knockback. Visuals reuse the fusion's
-- (clients strip "Awakened" from the id).
local AWAKEN_AREA = { "Radius", "InnerRadius", "PoolRadius", "Width", "JumpRange" }
local fusions = {}
for id, def in Skills.Defs do
	if #def.Elements == 2 and not def.Awakened then
		table.insert(fusions, id)
	end
end
for _, id in fusions do
	local base = Skills.Defs[id]
	local def = table.clone(base)
	def.Name = base.Name .. " Awakened"
	def.Awakened = true
	def.BaseSkill = id
	def.PerkName = "Ascended " .. base.Name
	def.Damage = (base.Damage or 0) * 1.2
	if base.TickDamage then
		def.TickDamage = base.TickDamage * 1.2
	end
	for _, key in AWAKEN_AREA do
		if base[key] then
			def[key] = base[key] * 1.25
		end
	end
	if base.Duration then
		def.Duration = base.Duration + 1
	end
	if base.Knockback then
		def.Knockback = base.Knockback * 1.3
	end
	if base.Status then
		def.Status = {}
		for name, params in base.Status do
			params = table.clone(params)
			params.Duration = (params.Duration or 1) * 1.25
			def.Status[name] = params
		end
	end
	def.Description = base.Description .. " Awakened: hits 20% harder over a 25% bigger area, and its effects last longer."
	Skills.Defs[id .. "Awakened"] = def
end

for id, def in Skills.Defs do
	def.Id = id
end

-- Levelling up costs duplicate copies of the skill: getting a skill you
-- already own adds a copy, and the player spends them in the Backpack.
-- LevelCost[n] = copies used to go from level n - 1 to level n.
Skills.LevelCost = { [2] = 3, [3] = 6, [4] = 12, [5] = 15 }

-- Copies needed for the next level, or nil at max level.
function Skills.CopiesToLevel(level)
	return Skills.LevelCost[(level or 1) + 1]
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
		if #def.Elements == 1 and not def.Awakened and def.Elements[1] == element then
			return id
		end
	end
	return nil
end

return Skills
