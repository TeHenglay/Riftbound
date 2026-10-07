-- Player level curve and per-level bonuses, shared by server and client.
local Progression = {}

Progression.MaxLevel = 50
Progression.BaseHealth = 100
Progression.HealthPerLevel = 10
Progression.DamagePerLevel = 0.05 -- +5% skill damage per level above 1

-- XP needed to go from `level` to `level + 1`.
function Progression.XpToNext(level)
	return math.floor(40 * level ^ 1.35 + 0.5)
end

function Progression.MaxHealth(level)
	return Progression.BaseHealth + Progression.HealthPerLevel * (level - 1)
end

function Progression.DamageMult(level)
	return 1 + Progression.DamagePerLevel * (level - 1)
end

return Progression
