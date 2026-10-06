--!strict
-- Creates remotes on the server and finds them on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"UseSkill", -- client -> server: (slot, aimDirection)
	"Infuse", -- client -> server: (slot, element)   debug only until rewards exist
	"Fuse", -- client -> server: (slot, fusionId)
	"LoadoutChanged", -- server -> client: (loadout)
	"SkillFx", -- server -> all clients: (position, radius, color)
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	UseSkill = get("UseSkill"),
	Infuse = get("Infuse"),
	Fuse = get("Fuse"),
	LoadoutChanged = get("LoadoutChanged"),
	SkillFx = get("SkillFx"),
}
