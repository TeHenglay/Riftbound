-- Wires up the test arena: element shrines grant skills, the Skill Trainer
-- (who stands where the old Forge was) opens the skill picker to borrow any
-- base, fused or awakened skill for Training, and dummy spawn points keep
-- enemies coming back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local arena = workspace:FindFirstChild("RiftboundTestArena")
if not arena then
	return
end

local BuildService = require(script.Parent.BuildService)
local FlaskService = require(script.Parent.FlaskService)
local InventoryService = require(script.Parent.InventoryService)
local StatService = require(script.Parent.StatService)
local Enemies = require(script.Parent.Enemies)
local remotes = ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Remotes")
local OpenSkillTrainer = remotes:FindFirstChild("OpenSkillTrainer") or Instance.new("RemoteEvent")
OpenSkillTrainer.Name = "OpenSkillTrainer"
OpenSkillTrainer.Parent = remotes

local TRAINER_COLOR = Color3.fromRGB(170, 120, 255)

-- The Skill Trainer: a robed Riftwalker standing at `cframe`.
local function spawnTrainer(cframe)
	local model
	local ok = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local robe = Color3.fromRGB(58, 34, 92)
		desc.HeadColor = Color3.fromRGB(234, 200, 170)
		desc.LeftArmColor, desc.RightArmColor = robe, robe
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(36, 22, 58), Color3.fromRGB(36, 22, 58)
		desc.TorsoColor = robe
		model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		-- Fallback: a simple robed pillar figure.
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "HumanoidRootPart"
		body.Size = Vector3.new(2, 5, 1.2)
		body.Color = Color3.fromRGB(58, 34, 92)
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = "SkillTrainer"
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	model.PrimaryPart = root
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = p == root
			p.CanCollide = false
		end
	end
	root.CanCollide = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:PivotTo(cframe)
	-- A rift orb floating over the trainer's head.
	local head = model:FindFirstChild("Head") or root
	local orb = Instance.new("Part")
	orb.Name = "TrainerOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.2, 1.2, 1.2)
	orb.Material = Enum.Material.Neon
	orb.Color = TRAINER_COLOR
	orb.Anchored = true
	orb.CanCollide = false
	orb.CFrame = head.CFrame + Vector3.new(0, 2.6, 0)
	orb.Parent = model
	local light = Instance.new("PointLight")
	light.Color = TRAINER_COLOR
	light.Range = 14
	light.Brightness = 2
	light.Parent = orb
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 56)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 80
	bb.Parent = orb
	for i, line in { { "SKILL TRAINER", 22, Color3.fromRGB(220, 200, 255) }, { "Try any skill", 15, Color3.fromRGB(235, 235, 245) } } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, (i - 1) * 28)
		label.Size = UDim2.new(1, 0, 0, if i == 1 then 28 else 22)
		label.Text = line[1]
		label.TextSize = line[2]
		label.TextColor3 = line[3]
		label.TextStrokeTransparency = 0.4
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", if i == 1 then Enum.FontWeight.Heavy else Enum.FontWeight.Medium)
		label.Parent = bb
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Choose Skills"
	prompt.ObjectText = "Skill Trainer"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		OpenSkillTrainer:FireClient(player)
	end)
	model.Parent = arena
	return model
end

-- The old Forge spot (or a SkillTrainerSpot marker from BuildTestArena) gets
-- the trainer; the Forge itself is removed.
do
	local spot
	local forge = arena:FindFirstChild("Forge")
	if forge then
		local base = forge:FindFirstChild("Base") or forge.PrimaryPart
		local pos = if base then base.Position else forge:GetPivot().Position
		spot = CFrame.new(pos.X, pos.Y - (if base then base.Size.Y / 2 else 0) + 3, pos.Z)
		forge:Destroy()
	end
	local marker = arena:FindFirstChild("SkillTrainerSpot", true)
	if marker and marker:IsA("BasePart") then
		spot = marker.CFrame + Vector3.new(0, 3 - marker.Size.Y / 2, 0)
	end
	if spot then
		-- Face the middle of the arena.
		local center = arena:GetPivot().Position
		spawnTrainer(CFrame.lookAt(spot.Position, Vector3.new(center.X, spot.Position.Y, center.Z)))
	end
end

local RESPAWN_TIME = 3

for _, prompt in arena:GetDescendants() do
	if prompt:IsA("ProximityPrompt") then
		local grant = prompt:GetAttribute("GrantSkill")
		if grant then
			-- Shrines lend a skill for Training only: it isn't saved and is
			-- taken back when you leave (BuildService.ClearTemp).
			prompt.Triggered:Connect(function(player)
				if BuildService.Owns(player, grant) then
					BuildService.OnNotify(player, "You already have this skill.", Color3.fromRGB(200, 160, 160))
				else
					BuildService.Grant(player, grant, true)
				end
			end)
		end
		if prompt:GetAttribute("FlaskRefill") then
			prompt.Triggered:Connect(function(player)
				FlaskService.Refill(player)
			end)
		end
	end
end

local function spawnAt(marker)
	local training = marker:GetAttribute("Kind") == "Training"
	local model = Enemies.SpawnDummy(marker.CFrame * CFrame.new(0, -marker.Size.Y / 2, 0), {
		Name = if training then "Training Dummy" else "Rift Husk",
		Visual = if training then nil else "RiftHusk",
		Health = if training then 400 else 120,
		Speed = if training then 0 else 11,
		Chase = not training,
		Regen = training,
		Damage = 6,
		Xp = if training then nil else 15,
		Gold = if training then nil else { 30, 50 },
		Color = if training then Color3.fromRGB(95, 80, 70) else Color3.fromRGB(60, 40, 90),
	})
	model:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		task.wait(RESPAWN_TIME)
		spawnAt(marker)
	end)
end

for _, marker in arena:WaitForChild("DummySpawns"):GetChildren() do
	spawnAt(marker)
end

-- Studio-only hook so tooling (MCP / command bar) can drive the live modules,
-- e.g. ServerStorage.RiftboundDebug:Invoke("Grant", player, "Fireball").
if RunService:IsStudio() then
	local SkillEffects = require(script.Parent.SkillEffects)
	local ProgressionService = require(script.Parent.ProgressionService)
	local debugHook = Instance.new("BindableFunction")
	debugHook.Name = "RiftboundDebug"
	debugHook.OnInvoke = function(action, ...)
		if action == "Grant" then
			return BuildService.Grant(...)
		elseif action == "GrantRune" then
			return BuildService.GrantRune(...)
		elseif action == "Merge" then
			return BuildService.Merge(...)
		elseif action == "Snapshot" then
			return BuildService.Snapshot(...)
		elseif action == "Cast" then
			return SkillEffects.Cast(...)
		elseif action == "Enemies" then
			return Enemies.GetAll()
		elseif action == "AddXp" then
			return ProgressionService.AddXp(...)
		elseif action == "AddGold" then
			return ProgressionService.AddGold(...)
		elseif action == "SpendStat" then
			return StatService.Spend(...)
		elseif action == "StatRank" then
			return StatService.Rank(...)
		elseif action == "AddItem" then
			return InventoryService.Add(...)
		elseif action == "Inventory" then
			return InventoryService.Snapshot(...)
		elseif action == "Flask" then
			return FlaskService.Get(...)
		elseif action == "FlaskRefill" then
			return FlaskService.Refill(...)
		elseif action == "Progress" then
			return ProgressionService.Get(...)
		end
		return nil
	end
	debugHook.Parent = game:GetService("ServerStorage")
end
