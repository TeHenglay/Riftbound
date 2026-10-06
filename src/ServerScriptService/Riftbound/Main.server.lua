-- Riftbound server entry point: remotes, player lifecycle, casting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local BuildService = require(script.Parent.BuildService)
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
remotes.Parent = Shared

BuildService.OnChanged = function(player)
	BuildChanged:FireClient(player, BuildService.Snapshot(player))
end
BuildService.OnNotify = function(player, text, color)
	Notify:FireClient(player, text, color)
end

Players.PlayerAdded:Connect(BuildService.Init)
Players.PlayerRemoving:Connect(BuildService.Remove)
for _, player in Players:GetPlayers() do
	BuildService.Init(player)
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
