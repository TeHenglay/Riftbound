-- The five nations a player picks on their first join. Each one boosts skills
-- of its own element and adds one perk of its own. The choice is published as
-- the player attribute "Nation", so server and client read perks the same way.
local Nations = {}

Nations.Order = { "Fire", "Earth", "Water", "Wind", "Lightning" }

-- ELEMENT_BONUS: extra damage for skills that contain the nation's element.
Nations.ElementBonus = 0.10

Nations.Defs = {
	Fire = {
		Id = "Fire",
		Name = "Ember Dominion",
		Element = "Fire",
		Motto = "Burn bright, burn first.",
		Color = Color3.fromRGB(255, 106, 43),
		Deep = Color3.fromRGB(110, 26, 8),
		Perks = { Damage = 0.05 },
		PerkText = { "+10% Fire skill damage", "+5% damage on every skill" },
	},
	Earth = {
		Id = "Earth",
		Name = "Stonehold Clans",
		Element = "Earth",
		Motto = "The mountain does not kneel.",
		Color = Color3.fromRGB(176, 122, 64),
		Deep = Color3.fromRGB(62, 40, 18),
		Perks = { Health = 25 },
		PerkText = { "+10% Earth skill damage", "+25 max health" },
	},
	Water = {
		Id = "Water",
		Name = "Tidewater Court",
		Element = "Water",
		Motto = "Every tide returns.",
		Color = Color3.fromRGB(52, 152, 255),
		Deep = Color3.fromRGB(10, 40, 92),
		Perks = { FlaskHeal = 0.10 },
		PerkText = { "+10% Water skill damage", "Rift Flask heals 45% instead of 35%" },
	},
	Wind = {
		Id = "Wind",
		Name = "Skyreach Nomads",
		Element = "Air", -- the game's element id for Wind
		Motto = "Never caught, never still.",
		Color = Color3.fromRGB(159, 240, 216),
		Deep = Color3.fromRGB(26, 80, 72),
		Perks = { Speed = 0.08 },
		PerkText = { "+10% Wind skill damage", "+8% movement speed" },
	},
	Lightning = {
		Id = "Lightning",
		Name = "Stormcall Order",
		Element = "Lightning",
		Motto = "Strike before the thunder.",
		Color = Color3.fromRGB(250, 225, 60),
		Deep = Color3.fromRGB(70, 52, 120),
		Perks = { Cooldown = 0.08 },
		PerkText = { "+10% Lightning skill damage", "Skills recharge 8% faster" },
	},
}

function Nations.Of(player)
	local id = player and player:GetAttribute("Nation")
	return id and Nations.Defs[id] or nil
end

local function perk(player, key)
	local def = Nations.Of(player)
	return def and def.Perks[key] or 0
end

function Nations.DamageMult(player)
	return 1 + perk(player, "Damage")
end

function Nations.HealthBonus(player)
	return perk(player, "Health")
end

function Nations.SpeedMult(player)
	return 1 + perk(player, "Speed")
end

function Nations.CooldownMult(player)
	return 1 - perk(player, "Cooldown")
end

function Nations.FlaskBonus(player)
	return perk(player, "FlaskHeal")
end

-- Damage multiplier for a skill with the given element list.
function Nations.ElementMult(player, elements)
	local def = Nations.Of(player)
	if def and elements and table.find(elements, def.Element) then
		return 1 + Nations.ElementBonus
	end
	return 1
end

return Nations
