-- Riftbound server entry point: remotes, player lifecycle, casting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local BuildService = require(script.Parent.BuildService)
local FlaskService = require(script.Parent.FlaskService)
local BlockService = require(script.Parent.BlockService)
local InventoryService = require(script.Parent.InventoryService)
local StatService = require(script.Parent.StatService)
local ProgressionService = require(script.Parent.ProgressionService)
local SkillEffects = require(script.Parent.SkillEffects)

local remotes = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"

local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end

local Cast = remote("RemoteEvent", "Cast")
local Equip = remote("RemoteEvent", "Equip")
local MergeSkills = remote("RemoteFunction", "Merge")
local GetBuild = remote("RemoteFunction", "GetBuild")
local BuildChanged = remote("RemoteEvent", "BuildChanged")
local Notify = remote("RemoteEvent", "Notify")
remote("RemoteEvent", "OpenForge")
remote("RemoteEvent", "SkillFx")
local UseFlask = remote("RemoteEvent", "UseFlask")
local Block = remote("RemoteEvent", "Block")
local GetInventory = remote("RemoteFunction", "GetInventory")
local InventoryChanged = remote("RemoteEvent", "InventoryChanged")
local SpendStat = remote("RemoteFunction", "SpendStat")
remotes.Parent = Shared

BuildService.OnChanged = function(player)
	BuildChanged:FireClient(player, BuildService.Snapshot(player))
end
BuildService.OnNotify = function(player, text, color)
	Notify:FireClient(player, text, color)
end
ProgressionService.OnNotify = BuildService.OnNotify
FlaskService.OnNotify = BuildService.OnNotify
InventoryService.OnNotify = BuildService.OnNotify
InventoryService.OnChanged = function(player, snapshot)
	InventoryChanged:FireClient(player, snapshot)
end
StatService.OnNotify = BuildService.OnNotify
StatService.OnHealthChanged = ProgressionService.RefreshHealth
ProgressionService.HealthBonus = StatService.HealthBonus
ProgressionService.OnLevelUp = function(player, _level, gained)
	FlaskService.Refill(player, true)
	StatService.GrantPoints(player, gained)
end

local function onPlayerAdded(player)
	BuildService.Init(player)
	ProgressionService.Init(player)
	FlaskService.Init(player)
	InventoryService.Init(player)
	StatService.Init(player)
	player.CharacterAdded:Connect(function()
		BlockService.Reset(player)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	BuildService.Remove(player)
	ProgressionService.Remove(player)
	FlaskService.Remove(player)
	InventoryService.Remove(player)
	StatService.Remove(player)
	BlockService.Remove(player)
end)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

SpendStat.OnServerInvoke = function(player, id)
	return typeof(id) == "string" and StatService.Spend(player, id)
end

GetInventory.OnServerInvoke = function(player)
	return InventoryService.Snapshot(player)
end

GetBuild.OnServerInvoke = function(player)
	return BuildService.Snapshot(player)
end

Equip.OnServerEvent:Connect(function(player, slot, id)
	if typeof(slot) == "string" and typeof(id) == "string" then
		BuildService.Equip(player, slot, id)
	end
end)

MergeSkills.OnServerInvoke = function(player, idA, idB)
	return BuildService.Merge(player, idA, idB)
end

Cast.OnServerEvent:Connect(function(player, slot, target)
	if typeof(slot) ~= "string" or typeof(target) ~= "Vector3" then
		return
	end
	if target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return -- NaN
	end
	local id, level = BuildService.TryCast(player, slot)
	if id then
		SkillEffects.Cast(player, id, level, target)
	end
end)

UseFlask.OnServerEvent:Connect(FlaskService.Drink)

Block.OnServerEvent:Connect(function(player, on)
	BlockService.Set(player, on == true)
end)
