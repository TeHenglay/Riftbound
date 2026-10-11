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
local CraftingService = require(script.Parent.CraftingService)
local SaveService = require(script.Parent.SaveService)

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
local CraftSkill = remote("RemoteFunction", "CraftSkill")
local AwakenSkill = remote("RemoteFunction", "AwakenSkill")
local GetBuild = remote("RemoteFunction", "GetBuild")
local BuildChanged = remote("RemoteEvent", "BuildChanged")
local Notify = remote("RemoteEvent", "Notify")
local OpenForge = remote("RemoteEvent", "OpenForge")
local OpenAwakening = remote("RemoteEvent", "OpenAwakening")
local SkillFx = remote("RemoteEvent", "SkillFx")
local UseFlask = remote("RemoteEvent", "UseFlask")
local Block = remote("RemoteEvent", "Block")
local GetInventory = remote("RemoteFunction", "GetInventory")
local InventoryChanged = remote("RemoteEvent", "InventoryChanged")
local SpendStat = remote("RemoteFunction", "SpendStat")
local RuneAction = remote("RemoteFunction", "Rune")
local LevelSkill = remote("RemoteFunction", "LevelSkill")
remote("RemoteEvent", "CooldownReset")
local TestEquipSkill = remote("RemoteFunction", "TestEquipSkill")
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
SaveService.OnNotify = BuildService.OnNotify
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
	-- Training skills are taken back when the player leaves Training (the Rift),
	-- including heading into a Story act or dying.
	player:GetAttributeChangedSignal("Area"):Connect(function()
		if player:GetAttribute("Area") ~= "Rift" then
			BuildService.ClearTemp(player)
		end
	end)
	-- Saved level, gold, items, skills and stats replace the fresh defaults.
	task.spawn(SaveService.Load, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	-- Take the save before the services forget the player, then write it.
	local save = SaveService.Collect(player)
	SaveService.Forget(player)
	task.spawn(SaveService.Write, player.UserId, save)
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

TestEquipSkill.OnServerInvoke = function(player, slot, id)
	if typeof(slot) ~= "string" or typeof(id) ~= "string" then
		return false, "Invalid request"
	end
	if slot ~= "Q" and slot ~= "E" then
		return false, "Slot must be Q or E"
	end
	local Skills = require(Shared:WaitForChild("Skills"))
	if not Skills.Defs[id] then
		return false, "Unknown skill"
	end
	-- Free test skills are only lent: never saved, gone when you leave Training.
	local b = BuildService.Snapshot(player)
	if not b or not b.Skills[id] then
		BuildService.Grant(player, id, true)
	end
	BuildService.Equip(player, slot, id)
	return true, id
end

-- ("Choose", offerIndex, slot or nil), ("Socket", pouchIndex, slot) or
-- ("Unsocket", skillId, socketIndex).
RuneAction.OnServerInvoke = function(player, action, a, b)
	if action == "Choose" and typeof(a) == "number" and (b == nil or typeof(b) == "string") then
		return BuildService.ChooseRune(player, a, b)
	elseif action == "Socket" and typeof(a) == "number" and typeof(b) == "string" then
		return BuildService.Socket(player, a, b)
	elseif action == "Unsocket" and typeof(a) == "string" and typeof(b) == "number" then
		return BuildService.Unsocket(player, a, b)
	end
	return false, "Invalid request"
end

-- Spends duplicate copies to level a skill up (Backpack button).
LevelSkill.OnServerInvoke = function(player, id)
	return BuildService.LevelUp(player, id)
end

-- Old free-fusion remote: fusing now always goes through the Forge recipe
-- (10,000 gold and materials), so this charges the same way.
MergeSkills.OnServerInvoke = function(player, idA, idB)
	if typeof(idA) ~= "string" or typeof(idB) ~= "string" then
		return false, "Invalid request"
	end
	local result = require(Shared:WaitForChild("Merge")).Result(idA, idB)
	if not result then
		return false, "Those skills can't be fused"
	end
	return CraftingService.Craft(player, result)
end

CraftSkill.OnServerInvoke = function(player, recipeId)
	return CraftingService.Craft(player, recipeId)
end

AwakenSkill.OnServerInvoke = function(player, baseSkillId)
	return CraftingService.Awaken(player, baseSkillId)
end

Cast.OnServerEvent:Connect(function(player, slot, target)
	if typeof(slot) ~= "string" or typeof(target) ~= "Vector3" then
		return
	end
	if target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return -- NaN
	end
	local id, level, mods = BuildService.TryCast(player, slot)
	if id then
		SkillEffects.Cast(player, id, level, target, mods)
	end
end)

UseFlask.OnServerEvent:Connect(FlaskService.Drink)

Block.OnServerEvent:Connect(function(player, on)
	BlockService.Set(player, on == true)
end)
