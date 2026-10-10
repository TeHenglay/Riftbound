-- Story mode wiring: builds missing story arenas, the StartStory remote, the
-- client-side OpenStoryLocal hook (the Play page's Story card fires it), the
-- exit gates and leaving runs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local remotes = Shared:WaitForChild("NationRemotes")
local NationService = require(script.Parent.NationService)
local StoryService = require(script.Parent.StoryService)
local StoryBuilder = require(script.Parent.StoryBuilder)

local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local StartStory = remote("RemoteFunction", "StartStory")
local StoryBanner = remote("RemoteEvent", "StoryBanner")
remote("BindableEvent", "OpenStoryLocal")

StoryService.OnNotify = function(player, text, color)
	local notify = Shared:WaitForChild("Remotes"):FindFirstChild("Notify")
	if notify then
		notify:FireClient(player, text, color)
	end
end
StoryService.OnBanner = function(player, payload)
	StoryBanner:FireClient(player, payload)
end

local arenas = StoryBuilder.BuildAll(false)

StartStory.OnServerInvoke = function(player, nationId, act, difficulty)
	if typeof(nationId) ~= "string" or typeof(act) ~= "number" or (difficulty ~= nil and typeof(difficulty) ~= "string") then
		return false, "Bad request"
	end
	return StoryService.Start(player, nationId, act, difficulty)
end

-- Exit gates (shown when an act is cleared) lead back to the Crossroads.
local lastTouch = {}
for _, gate in arenas:GetDescendants() do
	if gate:IsA("BasePart") and gate:GetAttribute("Travel") then
		gate.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or os.clock() - (lastTouch[player] or 0) < 2 then
				return
			end
			lastTouch[player] = os.clock()
			StoryService.Leave(player)
			-- Leaving a story counts as coming home from the Rift.
			player:SetAttribute("InRift", false)
			player:SetAttribute("Area", "Story")
			NationService.GoTo(player, gate:GetAttribute("Travel"))
		end)
	end
end

local function track(player)
	task.spawn(StoryService.Init, player)
	player:GetAttributeChangedSignal("Area"):Connect(function()
		if player:GetAttribute("Area") ~= "Story" then
			StoryService.Leave(player)
		end
	end)
end
Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastTouch[player] = nil
	StoryService.Remove(player)
end)
