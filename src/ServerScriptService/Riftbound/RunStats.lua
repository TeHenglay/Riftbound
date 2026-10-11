-- Per-player numbers for the current run (story act): damage dealt with
-- skills and enemies defeated. SkillEffects adds to them; StoryService resets
-- them when a run starts and reads them for the results screen.
local RunStats = {}

local stats = {} -- [player] = { Damage = n, Kills = n }

local function get(player)
	local s = stats[player]
	if not s then
		s = { Damage = 0, Kills = 0 }
		stats[player] = s
	end
	return s
end

function RunStats.Reset(player)
	stats[player] = { Damage = 0, Kills = 0 }
end

function RunStats.AddDamage(player, amount)
	if player and amount > 0 then
		local s = get(player)
		s.Damage += amount
	end
end

function RunStats.AddKill(player)
	if player then
		local s = get(player)
		s.Kills += 1
	end
end

-- { Damage = n, Kills = n } (a copy).
function RunStats.Get(player)
	return table.clone(get(player))
end

function RunStats.Remove(player)
	stats[player] = nil
end

return RunStats
