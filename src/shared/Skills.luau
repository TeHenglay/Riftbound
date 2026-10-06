--!strict
-- Base skill for each loadout slot. Elements and fusions modify these at runtime.

local Types = require(script.Parent.Types)

local Skills: { [Types.SlotId]: Types.Skill } = {
	Attack = {
		slot = "Attack",
		displayName = "Strike",
		damage = 10,
		cooldown = 0.35,
		range = 5,
		radius = 5,
	},
	Special = {
		slot = "Special",
		displayName = "Heavy Blow",
		damage = 25,
		cooldown = 1.5,
		range = 7,
		radius = 7,
	},
	Cast = {
		slot = "Cast",
		displayName = "Bolt",
		damage = 15,
		cooldown = 3,
		range = 30,
		radius = 6,
	},
	Dash = {
		slot = "Dash",
		displayName = "Dash",
		damage = 0,
		cooldown = 0.8,
		range = 0,
		radius = 6,
	},
}

return Skills
