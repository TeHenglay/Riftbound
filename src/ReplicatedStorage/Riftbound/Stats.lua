-- Attribute stats bought with points earned on level up. Shared so the
-- client can show exact bonuses and predict cooldowns.
local Stats = {}

Stats.MaxRank = 10
Stats.Order = { "Vitality", "Might", "Swiftness", "Focus" }

Stats.Defs = {
	Vitality = {
		Name = "Vitality",
		Color = Color3.fromRGB(232, 54, 74),
		Description = "Toughen your body. Raises your max health.",
		PerRank = 10, -- max health
		Format = function(rank)
			return `+{rank * 10} HP`
		end,
	},
	Might = {
		Name = "Might",
		Color = Color3.fromRGB(255, 138, 58),
		Description = "Strike harder. Raises the damage of every skill.",
		PerRank = 0.05, -- skill damage
		Format = function(rank)
			return `+{rank * 5}% damage`
		end,
	},
	Swiftness = {
		Name = "Swiftness",
		Color = Color3.fromRGB(159, 240, 216),
		Description = "Move like the wind. Raises your movement speed.",
		PerRank = 0.04, -- move speed
		Format = function(rank)
			return `+{rank * 4}% speed`
		end,
	},
	Focus = {
		Name = "Focus",
		Color = Color3.fromRGB(178, 108, 255),
		Description = "Sharpen your mind. Your skills recharge faster.",
		PerRank = 0.04, -- cooldown reduction
		Format = function(rank)
			return `-{rank * 4}% cooldowns`
		end,
	},
}

function Stats.HealthBonus(rank)
	return (rank or 0) * Stats.Defs.Vitality.PerRank
end

function Stats.DamageMult(rank)
	return 1 + (rank or 0) * Stats.Defs.Might.PerRank
end

function Stats.SpeedMult(rank)
	return 1 + (rank or 0) * Stats.Defs.Swiftness.PerRank
end

function Stats.CooldownMult(rank)
	return 1 - (rank or 0) * Stats.Defs.Focus.PerRank
end

return Stats
