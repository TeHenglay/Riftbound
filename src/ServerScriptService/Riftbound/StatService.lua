-- Stat points: 1 per level gained, spent on Vitality / Might / Swiftness / Focus.
-- Published as player attributes StatPoints and Stat_<Name> (rank).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Stats"))

local BASE_WALK_SPEED = 16

local StatService = {}

-- Set by Main.
StatService.OnNotify = function(_player, _text, _color) end
StatService.OnHealthChanged = function(_player) end -- re-apply max health after Vitality

local data = {}

local function publish(player)
	local d = data[player]
	if not d then
		return
	end
	player:SetAttribute("StatPoints", d.Points)
	for _, id in Stats.Order do
		player:SetAttribute("Stat_" .. id, d.Ranks[id])
	end
end

local function applySpeed(player)
	local d = data[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if d and hum then
		hum.WalkSpeed = BASE_WALK_SPEED * Stats.SpeedMult(d.Ranks.Swiftness)
	end
end

function StatService.Init(player)
	local ranks = {}
	for _, id in Stats.Order do
		ranks[id] = 0
	end
	data[player] = { Points = 0, Ranks = ranks }
	publish(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applySpeed(player)
	end)
	if player.Character then
		applySpeed(player)
	end
end

function StatService.Remove(player)
	data[player] = nil
end

function StatService.GrantPoints(player, count)
	local d = data[player]
	if not d or count <= 0 then
		return
	end
	d.Points += count
	publish(player)
	StatService.OnNotify(player, `+{count} Stat Point{if count > 1 then "s" else ""}   ·   press C`, Color3.fromRGB(233, 194, 122))
end

-- Spends one point on a stat. Returns true on success.
function StatService.Spend(player, id)
	local d = data[player]
	if not d or not Stats.Defs[id] or d.Points <= 0 or d.Ranks[id] >= Stats.MaxRank then
		return false
	end
	d.Points -= 1
	d.Ranks[id] += 1
	publish(player)
	if id == "Vitality" then
		StatService.OnHealthChanged(player)
	elseif id == "Swiftness" then
		applySpeed(player)
	end
	return true
end

function StatService.Rank(player, id)
	local d = data[player]
	return d and d.Ranks[id] or 0
end

function StatService.HealthBonus(player)
	return Stats.HealthBonus(StatService.Rank(player, "Vitality"))
end

function StatService.DamageMult(player)
	return Stats.DamageMult(StatService.Rank(player, "Might"))
end

function StatService.CooldownMult(player)
	return Stats.CooldownMult(StatService.Rank(player, "Focus"))
end

return StatService
