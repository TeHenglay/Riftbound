-- Stat points: 1 per level gained, spent on Vitality / Might / Swiftness / Focus.
-- Published as player attributes StatPoints and Stat_<Name> (rank).
-- Also the one place that sets a player's WalkSpeed: base speed (Swiftness and
-- nation) times every active speed modifier (shield, flask sip, foe slows).
-- Modifiers are keyed, so overlapping slows can never leave you stuck slow,
-- and they're cleared on respawn and at the start of every run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Stats"))
local Nations = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Nations"))

local BASE_WALK_SPEED = 16

local StatService = {}

-- Set by Main.
StatService.OnNotify = function(_player, _text, _color) end
StatService.OnHealthChanged = function(_player) end -- re-apply max health after Vitality

local data = {}
local speedMods = {} -- [player] = { [key] = multiplier }

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
		local mult = 1
		for _, m in speedMods[player] or {} do
			mult *= m
		end
		hum.WalkSpeed = BASE_WALK_SPEED * Stats.SpeedMult(d.Ranks.Swiftness) * Nations.SpeedMult(player) * mult
	end
end

-- Sets (or with nil, removes) a speed modifier, e.g. ("Block", 0.5).
function StatService.SetSpeedMod(player, key, mult)
	if not data[player] then
		return
	end
	speedMods[player] = speedMods[player] or {}
	speedMods[player][key] = mult
	applySpeed(player)
end

-- Drops every modifier: back to full speed.
function StatService.ClearSpeedMods(player)
	speedMods[player] = nil
	applySpeed(player)
end

function StatService.Init(player)
	local ranks = {}
	for _, id in Stats.Order do
		ranks[id] = 0
	end
	data[player] = { Points = 0, Ranks = ranks }
	publish(player)
	player.CharacterAdded:Connect(function(char)
		speedMods[player] = nil -- a new body starts at full speed
		char:WaitForChild("Humanoid")
		applySpeed(player)
	end)
	if player.Character then
		applySpeed(player)
	end
	-- Nation perks change speed and max health.
	player:GetAttributeChangedSignal("Nation"):Connect(function()
		applySpeed(player)
		StatService.OnHealthChanged(player)
	end)
end

function StatService.Remove(player)
	data[player] = nil
	speedMods[player] = nil
end

-- Saving (SaveService): a plain copy, and loading one back.
function StatService.Export(player)
	local d = data[player]
	return d and { Points = d.Points, Ranks = table.clone(d.Ranks) }
end

function StatService.Import(player, saved)
	local d = data[player]
	if not d or type(saved) ~= "table" then
		return
	end
	d.Points = math.max(0, math.floor(tonumber(saved.Points) or 0))
	local ranks = type(saved.Ranks) == "table" and saved.Ranks or {}
	for _, id in Stats.Order do
		d.Ranks[id] = math.clamp(math.floor(tonumber(ranks[id]) or 0), 0, Stats.MaxRank)
	end
	publish(player)
	applySpeed(player)
	StatService.OnHealthChanged(player)
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
	return Stats.HealthBonus(StatService.Rank(player, "Vitality")) + Nations.HealthBonus(player)
end

function StatService.DamageMult(player)
	return Stats.DamageMult(StatService.Rank(player, "Might")) * Nations.DamageMult(player)
end

function StatService.CooldownMult(player)
	return Stats.CooldownMult(StatService.Rank(player, "Focus")) * Nations.CooldownMult(player)
end

return StatService
