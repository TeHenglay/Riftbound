-- Collectible items (materials) that enemies drop into the player's backpack.
local Items = {}

Items.Rarity = {
	Common = { Name = "Common", Color = Color3.fromRGB(185, 166, 143) },
	Uncommon = { Name = "Uncommon", Color = Color3.fromRGB(111, 211, 138) },
	Rare = { Name = "Rare", Color = Color3.fromRGB(90, 168, 255) },
}

Items.Defs = {
	RiftShard = {
		Name = "Rift Shard",
		Rarity = "Common",
		Color = Color3.fromRGB(198, 155, 255),
		Description = "A splinter of the rift itself, still humming. A crafting material.",
	},
	HuskIchor = {
		Name = "Husk Ichor",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(122, 211, 107),
		Description = "Thick, glowing ichor drained from a Rift Husk. A crafting material.",
	},
	EmberCore = {
		Name = "Ember Core",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 122, 43),
		Description = "A smouldering heart that never cools. A rare crafting material.",
	},
	AbyssalPearl = {
		Name = "Abyssal Pearl",
		Rarity = "Rare",
		Color = Color3.fromRGB(90, 168, 255),
		Description = "A pearl charged with the pressure of the ocean deep. A rare crafting material.",
	},
	GraniteCore = {
		Name = "Granite Core",
		Rarity = "Rare",
		Color = Color3.fromRGB(140, 100, 50),
		Description = "A hardened nucleus of the mountain heart. A rare crafting material.",
	},
	ZephyrCore = {
		Name = "Zephyr Core",
		Rarity = "Rare",
		Color = Color3.fromRGB(130, 225, 200),
		Description = "A swirling vortex locked in a jade sphere. A rare crafting material.",
	},
	VoltCore = {
		Name = "Volt Core",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 235, 90),
		Description = "A supercharged magnetic dynamo core. A rare crafting material.",
	},

	-- Tier 1 Elemental Shards: earned on Act 1 clears and act bundles
	FireShard = {
		Name = "Fire Shard",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(255, 106, 43),
		Description = "A burning fragment of ember crystal. Used for crafting and skill awakening.",
	},
	WaterShard = {
		Name = "Water Shard",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(52, 152, 255),
		Description = "A cooled condensation crystal. Used for crafting and skill awakening.",
	},
	EarthShard = {
		Name = "Earth Shard",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(176, 122, 64),
		Description = "A dense shard of living bedrock. Used for crafting and skill awakening.",
	},
	WindShard = {
		Name = "Wind Shard",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(159, 240, 216),
		Description = "A crystallized sliver of gale force. Used for crafting and skill awakening.",
	},
	LightningShard = {
		Name = "Lightning Shard",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(250, 225, 60),
		Description = "A crackling shard of fulgurite. Used for crafting and skill awakening.",
	},
}

-- Essences: earned by clearing story acts, one per nation's story.
for _, e in {
	{ "Fire", "Fire Essence", Color3.fromRGB(255, 106, 43) },
	{ "Earth", "Earth Essence", Color3.fromRGB(176, 122, 64) },
	{ "Water", "Water Essence", Color3.fromRGB(52, 152, 255) },
	{ "Wind", "Wind Essence", Color3.fromRGB(159, 240, 216) },
	{ "Lightning", "Lightning Essence", Color3.fromRGB(250, 225, 60) },
} do
	Items.Defs[e[1] .. "Essence"] = {
		Name = e[2],
		Rarity = "Rare",
		Color = e[3],
		Description = "Distilled from a nation's story. Used to evolve skills.",
	}
end

Items.NationShards = {
	Fire = "FireShard",
	Water = "WaterShard",
	Earth = "EarthShard",
	Wind = "WindShard",
	Lightning = "LightningShard",
}

Items.NationCores = {
	Fire = "EmberCore",
	Water = "AbyssalPearl",
	Earth = "GraniteCore",
	Wind = "ZephyrCore",
	Lightning = "VoltCore",
}

-- Display order in the backpack.
Items.Order = {
	"RiftShard", "HuskIchor",
	"FireShard", "WaterShard", "EarthShard", "WindShard", "LightningShard",
	"EmberCore", "AbyssalPearl", "GraniteCore", "ZephyrCore", "VoltCore",
	"FireEssence", "WaterEssence", "EarthEssence", "WindEssence", "LightningEssence",
}

for id, def in Items.Defs do
	def.Id = id
end

return Items
