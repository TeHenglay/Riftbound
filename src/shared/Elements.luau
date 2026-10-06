--!strict
-- Base elements. Each one applies a status effect when a skill infused with it hits.

local Types = require(script.Parent.Types)

local Elements: { [Types.ElementId]: Types.Element } = {
	Fire = {
		id = "Fire",
		displayName = "Fire",
		color = Color3.fromRGB(255, 110, 40),
		status = "Burn",
	},
	Ice = {
		id = "Ice",
		displayName = "Ice",
		color = Color3.fromRGB(120, 210, 255),
		status = "Chill",
	},
	Lightning = {
		id = "Lightning",
		displayName = "Lightning",
		color = Color3.fromRGB(250, 235, 90),
		status = "Shock",
	},
	Wind = {
		id = "Wind",
		displayName = "Wind",
		color = Color3.fromRGB(170, 255, 190),
		status = "Knockback",
	},
	Earth = {
		id = "Earth",
		displayName = "Earth",
		color = Color3.fromRGB(150, 110, 70),
		status = "Armor",
	},
	Shadow = {
		id = "Shadow",
		displayName = "Shadow",
		color = Color3.fromRGB(110, 60, 160),
		status = "Drain",
	},
}

return Elements
