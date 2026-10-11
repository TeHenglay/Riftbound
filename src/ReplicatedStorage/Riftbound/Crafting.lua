-- Crafting and Skill Awakening definitions for Riftbound.
-- Specified in SKILL_EVOLUTION_AND_CRAFTING.md and STORY_DROPS_AND_MATERIALS.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skills = require(script.Parent:WaitForChild("Skills"))
local Items = require(script.Parent:WaitForChild("Items"))

local Crafting = {}

-- 1. Dual-Element Forge Recipes (The Forge)
-- Combines two base skills + materials + gold fee -> 1 Fused Skill.
Crafting.ForgeRecipes = {
	SteamCloud = {
		Result = "SteamCloud",
		Skills = { "Fireball", "TidalWave" },
		Materials = {
			FireShard = 4,
			WaterShard = 4,
			RiftShard = 8,
		},
		Gold = 1000,
		Title = "Steam Cloud",
		Description = "Scalding cloud that burns and slows targets inside.",
	},
	MagmaBurst = {
		Result = "MagmaBurst",
		Skills = { "Fireball", "StoneSpike" },
		Materials = {
			FireShard = 5,
			EarthShard = 5,
			EmberCore = 1,
			RiftShard = 12,
		},
		Gold = 1750,
		Title = "Magma Meteor",
		Description = "Molten meteor that crashes and leaves a pool of burning lava.",
	},
	Firestorm = {
		Result = "Firestorm",
		Skills = { "Fireball", "Gust" },
		Materials = {
			FireShard = 4,
			WindShard = 4,
			RiftShard = 8,
		},
		Gold = 1200,
		Title = "Firestorm",
		Description = "Fire tornado pulling enemies inward while dealing burn ticks.",
	},
	PlasmaLance = {
		Result = "PlasmaLance",
		Skills = { "Fireball", "SparkBolt" },
		Materials = {
			FireShard = 5,
			LightningShard = 5,
			EmberCore = 1,
			RiftShard = 12,
		},
		Gold = 1750,
		Title = "Plasma Lance",
		Description = "Piercing spear of plasma exploding on impact with Burn + Shock.",
	},
	MudTrap = {
		Result = "MudTrap",
		Skills = { "TidalWave", "StoneSpike" },
		Materials = {
			WaterShard = 4,
			EarthShard = 4,
			RiftShard = 8,
		},
		Gold = 1000,
		Title = "Mudslide",
		Description = "Massive rolling mud boulder that flattens, soaks, and slows.",
	},
	FrostGale = {
		Result = "FrostGale",
		Skills = { "TidalWave", "Gust" },
		Materials = {
			WaterShard = 4,
			WindShard = 4,
			RiftShard = 8,
		},
		Gold = 1200,
		Title = "Frost Gale",
		Description = "Freezing blizzard cone that slows and freezes enemies in ice.",
	},
	ChainShock = {
		Result = "ChainShock",
		Skills = { "TidalWave", "SparkBolt" },
		Materials = {
			WaterShard = 5,
			LightningShard = 5,
			VoltCore = 1,
			RiftShard = 12,
		},
		Gold = 1500,
		Title = "Thunder Serpent",
		Description = "A serpent of water and lightning that weaves through a crowd, biting, soaking and shocking every enemy it passes.",
	},
	Sandstorm = {
		Result = "Sandstorm",
		Skills = { "StoneSpike", "Gust" },
		Materials = {
			EarthShard = 4,
			WindShard = 4,
			RiftShard = 8,
		},
		Gold = 1200,
		Title = "Quake Leap",
		Description = "High leap slamming down with two rings of stone spikes.",
	},
	MagnetQuake = {
		Result = "MagnetQuake",
		Skills = { "StoneSpike", "SparkBolt" },
		Materials = {
			EarthShard = 5,
			LightningShard = 5,
			VoltCore = 1,
			RiftShard = 12,
		},
		Gold = 1750,
		Title = "Magnet Quake",
		Description = "Magnetic core that gathers enemies, then detonates in shock.",
	},
	Thunderstorm = {
		Result = "Thunderstorm",
		Skills = { "Gust", "SparkBolt" },
		Materials = {
			WindShard = 6,
			LightningShard = 6,
			VoltCore = 1,
			RiftShard = 14,
		},
		Gold = 2000,
		Title = "Thunderstorm",
		Description = "Persistent storm cloud raining down continuous lightning strikes.",
	},
}

-- Fusion materials come from both elements' nations' stories:
--   Act 1: FUSE_SHARDS of each nation's Shard
--   Act 2: FUSE_CORES of each nation's Core (Ember Core, Abyssal Pearl, ...)
-- plus Rift Shards. E.g. Steam Cloud (Fire + Water) needs Fire Shard,
-- Water Shard, Ember Core and Abyssal Pearl. (Essences, from Act 3, are for
-- Awakening only.) This replaces the Materials written in the recipes above.
local FUSE_SHARDS, FUSE_CORES, FUSE_RIFT = 4, 3, 10
local FUSE_GOLD = 10000 -- every fusion
Crafting.AwakenGold = 10000 -- every awakening, base or fused
Crafting.AwakenLevel = 2 -- skill level needed to awaken, base or fused
local NATION_OF = { Fire = "Fire", Water = "Water", Earth = "Earth", Air = "Wind", Lightning = "Lightning" }

for _, recipe in Crafting.ForgeRecipes do
	local materials = { RiftShard = FUSE_RIFT }
	for _, skillId in recipe.Skills do
		local nation = NATION_OF[Skills.Defs[skillId].Elements[1]]
		materials[Items.NationShards[nation]] = FUSE_SHARDS
		materials[Items.NationCores[nation]] = FUSE_CORES
	end
	recipe.Materials = materials
	recipe.Gold = FUSE_GOLD
end

-- Ordered list of forge recipes for clean UI rendering.
Crafting.ForgeOrder = {
	"SteamCloud",
	"MagmaBurst",
	"Firestorm",
	"PlasmaLance",
	"MudTrap",
	"FrostGale",
	"ChainShock",
	"Sandstorm",
	"MagnetQuake",
	"Thunderstorm",
}

-- 2. Base Skill Awakening Recipes (The Awakening Altar)
-- Requires the skill at level Crafting.AwakenLevel (2) + Nation Essence/Cores + 8 Nation Shards + 15 Rift Shards + gold
-- (Crafting.AwakenGold, set below; the Gold written here is replaced).
Crafting.AwakenRecipes = {
	Fireball = {
		BaseSkill = "Fireball",
		AwakenedSkill = "FireballAwakened",
		RequiredLevel = 5,
		Essence = "FireEssence",
		Core = "EmberCore",
		Shard = "FireShard",
		ShardCount = 8,
		RiftShardCount = 15,
		Gold = 2500,
		Title = "Fireball Awakened",
		PerkName = "Molten Crater",
		Description = "+20% Damage, +30% Radius. Leaves a scorch patch ticking 8 burn damage/sec.",
	},
	TidalWave = {
		BaseSkill = "TidalWave",
		AwakenedSkill = "TidalWaveAwakened",
		RequiredLevel = 5,
		Essence = "WaterEssence",
		Core = "AbyssalPearl",
		Shard = "WaterShard",
		ShardCount = 8,
		RiftShardCount = 15,
		Gold = 2500,
		Title = "Tidal Wave Awakened",
		PerkName = "Surging Rapids",
		Description = "+20% Damage, +35% Size, +50% Knockback. Leaves flooded ground that soaks enemies.",
	},
	StoneSpike = {
		BaseSkill = "StoneSpike",
		AwakenedSkill = "StoneSpikeAwakened",
		RequiredLevel = 5,
		Essence = "EarthEssence",
		Core = "GraniteCore",
		Shard = "EarthShard",
		ShardCount = 8,
		RiftShardCount = 15,
		Gold = 2500,
		Title = "Stone Spike Awakened",
		PerkName = "Crush & Concuss",
		Description = "+20% Damage, +30% Radius, +0.6s Stun. Enemies crushed take +15% Earth damage.",
	},
	Gust = {
		BaseSkill = "Gust",
		AwakenedSkill = "GustAwakened",
		RequiredLevel = 5,
		Essence = "WindEssence",
		Core = "ZephyrCore",
		Shard = "WindShard",
		ShardCount = 8,
		RiftShardCount = 15,
		Gold = 2500,
		Title = "Gust Awakened",
		PerkName = "Inward Vortex",
		Description = "+20% Damage, +35% Radius. Pulls all nearby enemies inward before blasting them away.",
	},
	SparkBolt = {
		BaseSkill = "SparkBolt",
		AwakenedSkill = "SparkBoltAwakened",
		RequiredLevel = 5,
		Essence = "LightningEssence",
		Core = "VoltCore",
		Shard = "LightningShard",
		ShardCount = 8,
		RiftShardCount = 15,
		Gold = 2500,
		Title = "Spark Bolt Awakened",
		PerkName = "Static Tether",
		Description = "+20% Damage, 5 Chain Jumps. Leaves electric tethers that damage enemies walking between them.",
	},
}

Crafting.AwakenOrder = {
	"Fireball",
	"TidalWave",
	"StoneSpike",
	"Gust",
	"SparkBolt",
}

-- Fused skills awaken too. They need the fusion at Crafting.AwakenLevel and, from both of
-- its nations, 2 Essences (Act 3) and Shards, plus Rift Shards. These recipes
-- list their costs in Materials (base awakenings use Essence / Core / Shard).
local AWAKEN_FUSED_ESSENCE, AWAKEN_FUSED_SHARDS, AWAKEN_FUSED_RIFT = 2, 6, 20
for _, fusionId in Crafting.ForgeOrder do
	local forge = Crafting.ForgeRecipes[fusionId]
	local awakened = Skills.Defs[fusionId .. "Awakened"]
	if forge and awakened then
		local materials = { RiftShard = AWAKEN_FUSED_RIFT }
		for _, skillId in forge.Skills do
			local nation = NATION_OF[Skills.Defs[skillId].Elements[1]]
			materials[nation .. "Essence"] = AWAKEN_FUSED_ESSENCE
			materials[Items.NationShards[nation]] = AWAKEN_FUSED_SHARDS
		end
		Crafting.AwakenRecipes[fusionId] = {
			BaseSkill = fusionId,
			AwakenedSkill = fusionId .. "Awakened",
			RequiredLevel = 5,
			Materials = materials,
			Title = awakened.Name,
			PerkName = awakened.PerkName,
			Fused = true,
			Description = "+20% Damage, +25% Area, effects last 25% longer (zones +1s), +30% Knockback.",
		}
		table.insert(Crafting.AwakenOrder, fusionId)
	end
end

for _, recipe in Crafting.AwakenRecipes do
	recipe.Gold = Crafting.AwakenGold
	recipe.RequiredLevel = Crafting.AwakenLevel
end

-- Checks if a player meets all crafting conditions for a Forge recipe.
function Crafting.CanCraft(recipeId, ownedSkills, inventory, playerGold)
	local recipe = Crafting.ForgeRecipes[recipeId]
	if not recipe then
		return false, "Recipe not found"
	end
	for _, reqSkill in recipe.Skills do
		if not ownedSkills or not ownedSkills[reqSkill] then
			return false, `Missing required skill: {reqSkill}`
		end
	end
	if (playerGold or 0) < recipe.Gold then
		return false, `Insufficient Gold ({playerGold or 0}/{recipe.Gold})`
	end
	for item, count in recipe.Materials do
		local owned = inventory and inventory[item] or 0
		if owned < count then
			local itemDef = Items.Defs[item]
			local itemName = itemDef and itemDef.Name or item
			return false, `Missing materials: {itemName} ({owned}/{count})`
		end
	end
	return true
end

-- Checks if a player meets all conditions to Awaken a base skill.
function Crafting.CanAwaken(baseSkillId, ownedSkills, inventory, playerGold)
	local recipe = Crafting.AwakenRecipes[baseSkillId]
	if not recipe then
		return false, "Awakening recipe not found"
	end
	local skillLevel = ownedSkills and ownedSkills[baseSkillId]
	if not skillLevel or skillLevel < recipe.RequiredLevel then
		return false, `Skill must reach level {recipe.RequiredLevel} (Current: Lv {skillLevel or 0})`
	end
	if (playerGold or 0) < recipe.Gold then
		return false, `Insufficient Gold ({playerGold or 0}/{recipe.Gold})`
	end
	-- Fused awakenings list their exact materials.
	if recipe.Materials then
		for item, count in recipe.Materials do
			local owned = inventory and inventory[item] or 0
			if owned < count then
				local itemDef = Items.Defs[item]
				return false, `Missing materials: {itemDef and itemDef.Name or item} ({owned}/{count})`
			end
		end
		return true
	end
	-- Requires 1x Essence OR 2x Cores
	local essenceCount = inventory and inventory[recipe.Essence] or 0
	local coreCount = inventory and inventory[recipe.Core] or 0
	if essenceCount < 1 and coreCount < 2 then
		return false, `Requires 1x {recipe.Essence} or 2x {recipe.Core}`
	end
	local shardCount = inventory and inventory[recipe.Shard] or 0
	if shardCount < recipe.ShardCount then
		return false, `Requires {recipe.ShardCount}x {recipe.Shard} ({shardCount}/{recipe.ShardCount})`
	end
	local riftCount = inventory and inventory.RiftShard or 0
	if riftCount < recipe.RiftShardCount then
		return false, `Requires {recipe.RiftShardCount}x Rift Shards ({riftCount}/{recipe.RiftShardCount})`
	end
	return true
end

return Crafting
