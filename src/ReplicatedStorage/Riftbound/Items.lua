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

-- Display order in the backpack.
Items.Order = { "RiftShard", "HuskIchor", "EmberCore", "FireEssence", "EarthEssence", "WaterEssence", "WindEssence", "LightningEssence" }

for id, def in Items.Defs do
	def.Id = id
end

return Items
