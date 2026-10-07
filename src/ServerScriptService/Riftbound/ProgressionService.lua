-- Each player's level, XP and gold. Published to the client as player
-- attributes (Level, Xp, XpToNext, Gold) and to the player list as leaderstats.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Progression = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Progression"))

local LEVEL_UP_COLOR = Color3.fromRGB(255, 215, 90)

local ProgressionService = {}

-- Set by Main to send toasts to the client.
ProgressionService.OnNotify = function(_player, _text, _color) end

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
	local max = Progression.MaxHealth(d.Level)
	hum.MaxHealth = max
	if heal then
		hum.Health = max
	end
end

local function levelUpEffect(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = LEVEL_UP_COLOR
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 22, 22),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.65)
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
