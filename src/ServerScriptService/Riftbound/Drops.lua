-- XP orbs, gold coins and item crystals dropped by enemies. They pop out, then fly to any
-- player who walks close enough and are collected on touch.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local InventoryService = require(script.Parent.InventoryService)
local ProgressionService = require(script.Parent.ProgressionService)
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("Riftbound"):WaitForChild("Items"))

local MAGNET_RADIUS = 18
local PICKUP_RADIUS = 3
local MAGNET_SPEED = 55
local ARM_TIME = 0.6 -- seconds before a fresh drop can be picked up
local LIFETIME = 60
local XP_COLOR = Color3.fromRGB(120, 200, 255)
local GOLD_COLOR = Color3.fromRGB(255, 200, 60)

local Drops = {}

local folder = workspace:FindFirstChild("RiftDrops") or Instance.new("Folder")
folder.Name = "RiftDrops"
folder.Parent = workspace

-- [part] = { Kind = "Xp" | "Gold", Amount, Born }
local active = {}

-- Splits `total` into at most `pieces` roughly equal whole amounts.
local function split(total, pieces)
	pieces = math.clamp(pieces, 1, math.max(total, 1))
	local out = {}
	local base = math.floor(total / pieces)
	local extra = total - base * pieces
	for i = 1, pieces do
		table.insert(out, base + (if i <= extra then 1 else 0))
	end
	return out
end

local function spawnPiece(origin, groundY, kind, amount, itemId)
	local p = Instance.new("Part")
	p.Name = kind
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if kind == "Xp" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 0.9
		p.Color = XP_COLOR
	elseif kind == "Item" then
		-- Items are chunky spinning crystals in their own colour.
		p.Size = Vector3.new(0.9, 1.4, 0.9)
		p.Color = Items.Defs[itemId].Color
	else
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 1.3, 1.3)
		p.Color = GOLD_COLOR
	end
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 5
	light.Brightness = 1.5
	light.Parent = p

	local angle = math.random() * math.pi * 2
	local dist = 1.5 + math.random() * 3
	local landing = Vector3.new(origin.X + math.cos(angle) * dist, groundY + 0.9, origin.Z + math.sin(angle) * dist)
	p.CFrame = CFrame.new(origin)
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(landing),
	}):Play()

	active[p] = { Kind = kind, Amount = amount, ItemId = itemId, Born = os.clock() }
end

-- Drops `xp`, `gold` and `items` ({ [itemId] = count }) around `position`
-- (an enemy's root position).
function Drops.Spawn(position, xp, gold, groundY, items)
	groundY = groundY or position.Y - 2
	if xp and xp > 0 then
		for _, amount in split(xp, math.ceil(xp / 5)) do
			spawnPiece(position, groundY, "Xp", amount)
		end
	end
	if gold and gold > 0 then
		for _, amount in split(gold, math.min(gold, 5)) do
			spawnPiece(position, groundY, "Gold", amount)
		end
	end
	for id, count in items or {} do
		if Items.Defs[id] then
			for _ = 1, count do
				spawnPiece(position, groundY, "Item", 1, id)
			end
		end
	end
end

local function nearestRoot(pos)
	local best, bestDist = nil, MAGNET_RADIUS
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best, bestDist
end

local function collect(part, info, player)
	active[part] = nil
	part:Destroy()
	if info.Kind == "Xp" then
		ProgressionService.AddXp(player, info.Amount)
	elseif info.Kind == "Item" then
		InventoryService.Add(player, info.ItemId, info.Amount)
	else
		ProgressionService.AddGold(player, info.Amount)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for part, info in active do
		if not part.Parent or now - info.Born > LIFETIME then
			active[part] = nil
			part:Destroy()
			continue
		end
		if info.Kind == "Gold" then
			part.CFrame *= CFrame.Angles(dt * 3, 0, 0)
		elseif info.Kind == "Item" then
			part.CFrame *= CFrame.Angles(0, dt * 2.5, 0)
		end
		if now - info.Born < ARM_TIME then
			continue
		end
		local player, dist = nearestRoot(part.Position)
		if player then
			if dist <= PICKUP_RADIUS then
				collect(part, info, player)
			else
				local target = player.Character.HumanoidRootPart.Position
				local step = math.min(MAGNET_SPEED * dt, dist)
				part.CFrame = CFrame.new(part.Position + (target - part.Position).Unit * step) * part.CFrame.Rotation
			end
		end
	end
end)

return Drops
