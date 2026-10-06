-- Wires up the test arena: element shrines grant skills, the Forge opens the
-- fusion screen, and dummy spawn points keep enemies coming back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local arena = workspace:FindFirstChild("RiftboundTestArena")
if not arena then
	return
end

local BuildService = require(script.Parent.BuildService)
local Enemies = require(script.Parent.Enemies)
local OpenForge = ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Remotes"):WaitForChild("OpenForge")

local RESPAWN_TIME = 3

for _, prompt in arena:GetDescendants() do
	if prompt:IsA("ProximityPrompt") then
		local grant = prompt:GetAttribute("GrantSkill")
		if grant then
			prompt.Triggered:Connect(function(player)
				BuildService.Grant(player, grant)
			end)
		end
		if prompt:GetAttribute("Forge") then
			prompt.Triggered:Connect(function(player)
				OpenForge:FireClient(player)
			end)
		end
	end
end

local function spawnAt(marker)
	local training = marker:GetAttribute("Kind") == "Training"
	local model = Enemies.SpawnDummy(marker.CFrame * CFrame.new(0, -marker.Size.Y / 2, 0), {
		Name = if training then "Training Dummy" else "Rift Husk",
		Health = if training then 400 else 120,
		Speed = if training then 0 else 11,
		Chase = not training,
		Regen = training,
		Damage = 6,
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
	local debugHook = Instance.new("BindableFunction")
	debugHook.Name = "RiftboundDebug"
	debugHook.OnInvoke = function(action, ...)
		if action == "Grant" then
			return BuildService.Grant(...)
		elseif action == "Merge" then
			return BuildService.Merge(...)
		elseif action == "Snapshot" then
			return BuildService.Snapshot(...)
		elseif action == "Cast" then
			return SkillEffects.Cast(...)
		elseif action == "Enemies" then
			return Enemies.GetAll()
		end
		return nil
	end
	debugHook.Parent = game:GetService("ServerStorage")
end
