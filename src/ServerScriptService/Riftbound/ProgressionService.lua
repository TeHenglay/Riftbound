-- Each player's level, XP and gold. Published to the client as player
-- attributes (Level, Xp, XpToNext, Gold) and to the player list as leaderstats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Progression"))

local LEVEL_UP_COLOR = Color3.fromRGB(255, 215, 90)

local ProgressionService = {}

-- Set by Main to send toasts to the client.
ProgressionService.OnNotify = function(_player, _text, _color) end
-- Set by Main; called after a player gains one or more levels.
ProgressionService.OnLevelUp = function(_player, _level, _gained) end
-- Set by Main; extra max health from stats.
ProgressionService.HealthBonus = function(_player)
	return 0
end

local data = {}

local function publish(player)
	local d = data[player]
	if not d then
		return
	end
	player:SetAttribute("Level", d.Level)
	player:SetAttribute("Xp", d.Xp)
	player:SetAttribute("XpToNext", if d.Level >= Progression.MaxLevel then 0 else Progression.XpToNext(d.Level))
	player:SetAttribute("Gold", d.Gold)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = d.Level
		stats.Gold.Value = d.Gold
	end
end

local function applyHealth(player, heal)
	local d = data[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not d or not hum then
		return
	end
	local max = Progression.MaxHealth(d.Level) + ProgressionService.HealthBonus(player)
	local gained = max - hum.MaxHealth
	hum.MaxHealth = max
	if heal then
		hum.Health = max
	elseif gained > 0 and hum.Health > 0 then
		hum.Health = math.min(max, hum.Health + gained)
	end
end

-- Re-applies max health (e.g. after a Vitality point), granting the added health.
function ProgressionService.RefreshHealth(player)
	applyHealth(player, false)
end

-- Asks every client to play a player effect (rendered by SkillVFX).
local function playerFx(kind, root)
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Riftbound"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SkillFx")
	if remote then
		remote:FireAllClients({ Type = kind, Target = root })
	end
end

local function levelUpEffect(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		playerFx("LevelUp", root)
	end
end

function ProgressionService.Init(player)
	data[player] = { Level = 1, Xp = 0, Gold = 0 }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Level", "Gold" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	publish(player)

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applyHealth(player, true)
	end)
	if player.Character then
		applyHealth(player, true)
	end
end

function ProgressionService.Remove(player)
	data[player] = nil
end

function ProgressionService.Get(player)
	local d = data[player]
	return d and table.clone(d)
end

function ProgressionService.AddXp(player, amount)
	local d = data[player]
	if not d or amount <= 0 or d.Level >= Progression.MaxLevel then
		return
	end
	d.Xp += amount
	local startLevel = d.Level
	local leveled = false
	while d.Level < Progression.MaxLevel and d.Xp >= Progression.XpToNext(d.Level) do
		d.Xp -= Progression.XpToNext(d.Level)
		d.Level += 1
		leveled = true
	end
	if d.Level >= Progression.MaxLevel then
		d.Xp = 0
	end
	publish(player)
	if leveled then
		applyHealth(player, true)
		levelUpEffect(player)
		ProgressionService.OnNotify(player, `Level up! You are now level {d.Level}`, LEVEL_UP_COLOR)
		ProgressionService.OnLevelUp(player, d.Level, d.Level - startLevel)
	end
end

function ProgressionService.AddGold(player, amount)
	local d = data[player]
	if not d or amount <= 0 then
		return
	end
	d.Gold += amount
	publish(player)
end

-- Returns true and deducts the gold if the player can afford it.
function ProgressionService.SpendGold(player, amount)
	local d = data[player]
	if not d or amount < 0 or d.Gold < amount then
		return false
	end
	d.Gold -= amount
	publish(player)
	return true
end

function ProgressionService.DamageMult(player)
	local d = data[player]
	return Progression.DamageMult(d and d.Level or 1)
end

return ProgressionService
