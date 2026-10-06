--!strict
-- Fusion recipes: two elements merged at the Forge become a new skill effect.
-- Adding a fusion is one entry in this table.

local Types = require(script.Parent.Types)

local Fusions = {}

-- Minimum level both elements need on a slot before they can be fused.
Fusions.REQUIRED_LEVEL = 2

Fusions.Recipes = {
	{
		id = "SteamBurst",
		displayName = "Steam Burst",
		elements = { "Fire", "Ice" },
		color = Color3.fromRGB(230, 230, 230),
		damageMultiplier = 1.4,
		radiusMultiplier = 1.8,
		statuses = { "Burn", "Chill" },
		description = "A wide scalding cloud that burns and slows.",
	},
	{
		id = "PlasmaLance",
		displayName = "Plasma Lance",
		elements = { "Fire", "Lightning" },
		color = Color3.fromRGB(255, 120, 230),
		damageMultiplier = 1.8,
		radiusMultiplier = 1.0,
		statuses = { "Burn", "Shock" },
		description = "A searing bolt that chains to nearby enemies.",
	},
	{
		id = "Blizzard",
		displayName = "Blizzard",
		elements = { "Ice", "Wind" },
		color = Color3.fromRGB(200, 240, 255),
		damageMultiplier = 1.2,
		radiusMultiplier = 2.2,
		statuses = { "Chill", "Knockback" },
		description = "A freezing gale that slows and pushes enemies back.",
	},
	{
		id = "StormChain",
		displayName = "Storm Chain",
		elements = { "Lightning", "Wind" },
		color = Color3.fromRGB(180, 255, 120),
		damageMultiplier = 1.5,
		radiusMultiplier = 1.4,
		statuses = { "Shock", "Knockback" },
		description = "Lightning carried on the wind, hitting a crowd.",
	},
	{
		id = "MagmaField",
		displayName = "Magma Field",
		elements = { "Earth", "Fire" },
		color = Color3.fromRGB(200, 70, 20),
		damageMultiplier = 1.6,
		radiusMultiplier = 1.5,
		statuses = { "Burn", "Armor" },
		description = "Molten ground that burns and shields you.",
	},
	{
		id = "FrostLance",
		displayName = "Frost Lance",
		elements = { "Ice", "Lightning" },
		color = Color3.fromRGB(140, 180, 255),
		damageMultiplier = 1.5,
		radiusMultiplier = 1.0,
		statuses = { "Chill", "Shock" },
		description = "A crackling icicle that chains a freezing shock.",
	},
} :: { Types.Fusion }

local function pairKey(a: string, b: string): string
	if a < b then
		return a .. "+" .. b
	end
	return b .. "+" .. a
end

local byPair: { [string]: Types.Fusion } = {}
local byId: { [string]: Types.Fusion } = {}
for _, recipe in Fusions.Recipes do
	byPair[pairKey(recipe.elements[1], recipe.elements[2])] = recipe
	byId[recipe.id] = recipe
end

-- Returns the fusion made from two elements, or nil if no recipe exists.
function Fusions.find(a: Types.ElementId, b: Types.ElementId): Types.Fusion?
	return byPair[pairKey(a, b)]
end

function Fusions.get(id: string): Types.Fusion?
	return byId[id]
end

-- Returns every fusion the slot can make right now.
function Fusions.available(slot: Types.SlotState): { Types.Fusion }
	local ready: { Types.ElementId } = {}
	for element, level in slot.elements do
		if level >= Fusions.REQUIRED_LEVEL then
			table.insert(ready, element)
		end
	end

	local result = {}
	for i = 1, #ready do
		for j = i + 1, #ready do
			local fusion = Fusions.find(ready[i], ready[j])
			if fusion then
				table.insert(result, fusion)
			end
		end
	end
	return result
end

return Fusions
