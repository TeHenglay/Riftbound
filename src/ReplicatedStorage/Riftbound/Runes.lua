-- Runes: temporary in-run powerups (the Hades boon model). Every skill has 3
-- sockets (keyed by skill id, so runes follow the skill, not the key) that
-- start empty every run. Clearing a wave pauses the run while each player
-- picks 1 of 3 runes; every rune is wiped when the run ends. Runes never reach
-- the lobby backpack. Shared so the HUD can show sockets and predict cooldowns.
--
-- Each rune's Mods are summed per slot by Runes.Mods (see that function for
-- what each key does). Runes with Ready = false are in the catalog but don't
-- work yet, so they never drop.
local Runes = {}

Runes.Sockets = 3
Runes.Slots = { "M1", "Q", "E" } -- the keys you can socket into; Dash and Block have none
Runes.Choices = 3 -- runes offered per wave clear
Runes.PickTime = 10 -- seconds the run waits for the pick
Runes.SlotKeys = { M1 = "LMB", Q = "Q", E = "E" }
Runes.MaxLegendary = 1 -- per slot
Runes.MaxCooldownCut = 0.8

-- MinWave is the run wave (see Runes.RunWave) from which a rarity can drop;
-- Weight is how often a rune of that rarity is rolled. Every rarity has the
-- same weight and drops from wave 1, so every working rune is equally likely.
Runes.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }
Runes.Rarity = {
	Common = { Name = "Common", Color = Color3.fromRGB(200, 204, 212), Weight = 1, MinWave = 1 },
	Rare = { Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 1, MinWave = 1 },
	Epic = { Name = "Epic", Color = Color3.fromRGB(160, 80, 240), Weight = 1, MinWave = 1 },
	Legendary = { Name = "Legendary", Color = Color3.fromRGB(255, 200, 70), Weight = 1, MinWave = 1 },
}

local function rune(rarity, name, effect, mods, ready)
	return { Rarity = rarity, Name = name, Effect = effect, Mods = mods or {}, Ready = ready ~= false }
end

Runes.Defs = {
	-- Common
	Might = rune("Common", "Rune of Might", "+15% skill damage", { Damage = 0.15 }),
	Expansion = rune("Common", "Rune of Expansion", "+15% area, radius and width", { Area = 0.15 }),
	Haste = rune("Common", "Rune of Haste", "-12% cooldown", { Cooldown = 0.12 }),
	Reach = rune("Common", "Rune of Reach", "+30% range and travel distance", { Range = 0.3 }),
	Impact = rune("Common", "Rune of Impact", "+50% knockback", { Knockback = 0.5 }),
	Lingering = rune("Common", "Rune of Lingering", "+1.5s zone and status duration", { Duration = 1.5 }),
	Prospector = rune("Common", "Rune of the Prospector", "+20% gold and XP from enemies it hits", { Loot = 0.2 }),
	HeavyMass = rune("Common", "Rune of Heavy Mass", "+10% damage, -5% projectile speed", { Damage = 0.1, Speed = -0.05 }),

	-- Rare
	Multishot = rune("Rare", "Rune of Multishot", "+1 projectile in a tight fan", { Projectiles = 1 }),
	Piercing = rune("Rare", "Rune of Piercing", "Projectiles pierce 2 enemies", { Pierce = 2 }, false),
	Ricochet = rune("Rare", "Rune of Ricochet", "Hits bounce to 1 nearby enemy", { Bounce = 1 }, false),
	Precision = rune("Rare", "Rune of Precision", "+18% crit chance (crits deal 175%)", { Crit = 0.18 }),
	Executioner = rune("Rare", "Rune of the Executioner", "+10% damage to targets below 35% HP", { Execute = 0.1 }),
	GiantHunter = rune("Rare", "Rune of the Giant Hunter", "+25% damage vs Elites and Bosses", { GiantHunter = 0.25 }),
	DeepChill = rune("Rare", "Rune of Deep Chill", "Hits slow by 15% for 3s", { Chill = 1 }),
	Tremor = rune("Rare", "Rune of Tremor", "+0.8s stun on skills that stun", { Stun = 0.8 }),
	Momentum = rune("Rare", "Rune of Momentum", "+3% move speed per hit for 4s (max 5)", { Momentum = 1 }, false),

	-- Epic
	Aftershock = rune("Epic", "Rune of the Aftershock", "0.5s after impact, a burst deals 45% damage", { Aftershock = 0.45 }),
	Graviton = rune("Epic", "Rune of the Graviton Vortex", "Impact pulls enemies within 16 studs inward", { Gravity = 16 }),
	MagmaTrail = rune("Epic", "Rune of the Magma Trail", "Projectiles leave a burning trail", { Trail = 1 }, false),
	TwinSpark = rune("Epic", "Rune of Twin Spark", "22% chance to cast a second time for free", { Twin = 0.22 }),
	ThermalShock = rune("Epic", "Rune of Thermal Shock", "Fire on Soaked enemies stuns nearby targets", { Thermal = 1 }, false),
	Overload = rune("Epic", "Rune of Overloaded Voltage", "Shocked enemies arc to 3 nearby targets", { Overload = 1 }, false),
	BloodSiphon = rune("Epic", "Rune of the Blood Siphon", "Heal for 4% of damage dealt", { Siphon = 0.04 }),
	AegisWard = rune("Epic", "Rune of the Aegis Ward", "Hitting 3+ enemies grants a shield", { Aegis = 1 }, false),
	Windrunner = rune("Epic", "Rune of the Windrunner", "Casting refreshes Dash", { Windrunner = 1 }, false),

	-- Legendary
	PhantomTwin = rune("Legendary", "Rune of the Phantom Twin", "A spectral clone casts the skill with you", { Clone = 1 }, false),
	CelestialOrbit = rune("Legendary", "Rune of the Celestial Orbit", "Projectiles orbit you for 8s", { Orbit = 1 }, false),
	ChainReaction = rune("Legendary", "Rune of the Chain Reaction", "Enemies it kills detonate", { Detonate = 0.5 }),
	Singularity = rune("Legendary", "Rune of the Singularity", "Impact collapses into a black hole", { Gravity = 40 }),
	EndlessCascade = rune("Legendary", "Rune of the Endless Cascade", "Kills reset this skill's cooldown", { Cascade = 1 }),
	TripleCharge = rune("Legendary", "Rune of the Triple Charge", "3 rechargeable charges", { Charges = 3 }, false),
	DashWeaver = rune("Legendary", "Rune of the Dash Weaver", "Dashing casts this skill for free", { DashCast = 1 }, false),
	Prism = rune("Legendary", "Rune of the Prismatic Prism", "Adds a rotating second element", { Prism = 1 }, false),
	AbsoluteZero = rune("Legendary", "Rune of Absolute Zero", "Hits freeze; frozen targets below 25% shatter", { Shatter = 0.25 }, false),
	Cataclysm = rune("Legendary", "Rune of the Cataclysm", "+120% area", { Area = 1.2 }),
	SpellTotem = rune("Legendary", "Rune of the Spell-Totem", "A totem recasts the skill for 6s", { Totem = 1 }, false),
	BloodPact = rune("Legendary", "Rune of the Blood Pact", "-80% cooldown; casting costs 5% HP (refunded on 3+ hits)", { Cooldown = 0.8, BloodPact = 0.05 }),
}

-- Story acts have 2-4 waves, so the wave counter runs across the story:
-- Act 1 is waves 1-4, Act 2 is 5-8, Act 3 is 9+.
function Runes.RunWave(act, wave)
	return (act - 1) * 4 + wave
end

-- Picks a ready rune for the given run wave, weighted by rarity.
function Runes.Roll(runWave, rng)
	rng = rng or Random.new()
	local pool, total = {}, 0
	for id, def in Runes.Defs do
		local rarity = Runes.Rarity[def.Rarity]
		if def.Ready and runWave >= rarity.MinWave then
			table.insert(pool, { Id = id, Weight = rarity.Weight })
			total += rarity.Weight
		end
	end
	table.sort(pool, function(a, b)
		return a.Id < b.Id
	end)
	local pick = rng:NextNumber() * total
	for _, entry in pool do
		pick -= entry.Weight
		if pick <= 0 then
			return entry.Id
		end
	end
	return pool[#pool].Id
end

-- `n` different runes for one wave-clear pick.
function Runes.RollChoices(runWave, n, rng)
	rng = rng or Random.new()
	local picks = {}
	for _ = 1, 30 do
		if #picks >= n then
			break
		end
		local id = Runes.Roll(runWave, rng)
		if not table.find(picks, id) then
			table.insert(picks, id)
		end
	end
	return picks
end

function Runes.CountLegendary(list, skip)
	local n = 0
	for i, id in list do
		if i ~= skip and Runes.Defs[id] and Runes.Defs[id].Rarity == "Legendary" then
			n += 1
		end
	end
	return n
end

-- Can `id` go into a slot whose sockets hold `list`?
function Runes.CanSocket(list, id)
	local def = Runes.Defs[id]
	if not def then
		return false, "Unknown rune"
	end
	if #list >= Runes.Sockets then
		return false, "Sockets full"
	end
	if def.Rarity == "Legendary" and Runes.CountLegendary(list) >= Runes.MaxLegendary then
		return false, "One Legendary per skill"
	end
	return true
end

-- Sums the Mods of the runes in one slot. Keys:
--   Damage, Area, Range, Knockback, Speed  additive fractions (+0.15 = +15%)
--   Cooldown     fraction cut, capped at MaxCooldownCut
--   Duration     seconds added to zones, pools, vortexes and statuses
--   Loot         extra gold/XP fraction from enemies it hits
--   Projectiles  extra projectiles (Projectile skills)
--   Crit, Execute, GiantHunter, Siphon, Twin, Aftershock  chances/fractions
--   Chill, Stun, Gravity, Cascade, Detonate, BloodPact  see SkillEffects
function Runes.Mods(list)
	local mods = {}
	for _, id in list or {} do
		local def = Runes.Defs[id]
		if def then
			for key, value in def.Mods do
				mods[key] = (mods[key] or 0) + value
			end
		end
	end
	mods.Cooldown = math.min(mods.Cooldown or 0, Runes.MaxCooldownCut)
	return mods
end

function Runes.CooldownMult(list)
	return 1 - Runes.Mods(list).Cooldown
end

return Runes
