-- Nation lobbies: builds the lobby islands if the place doesn't have them,
-- handles spawning (characters load only after the saved nation is known),
-- the nation choice remote and the Rift portals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local NationService = require(script.Parent.NationService)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local MarketService = require(script.Parent.MarketService)

local remotes = Shared:FindFirstChild("NationRemotes") or Instance.new("Folder")
remotes.Name = "NationRemotes"
local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local ChooseNation = remote("RemoteFunction", "ChooseNation")
local Travel = remote("RemoteEvent", "Travel")
local Preview = remote("RemoteEvent", "Preview")
local TravelTo = remote("RemoteEvent", "TravelTo") -- client asks to go to an area
local OpenMarket = remote("RemoteEvent", "OpenMarket")
local MarketBuy = remote("RemoteFunction", "MarketBuy")
local MarketSell = remote("RemoteFunction", "MarketSell")
-- Client-side hook other UIs (e.g. the lobby menu) can :Fire("Shop"/"Merchant").
local openLocal = remotes:FindFirstChild("OpenMarketLocal") or Instance.new("BindableEvent")
openLocal.Name = "OpenMarketLocal"
openLocal.Parent = remotes
remotes.Parent = Shared

NationService.TravelRemote = Travel
NationService.OnNotify = function(player, text, color)
	local notify = Shared:WaitForChild("Remotes"):WaitForChild("Notify", 5)
	if notify then
		notify:FireClient(player, text, color)
	end
end

LobbyBuilder.BuildAll(false)

-- The select screen previews lobbies; stream the one being shown, since the
-- player has no character yet to stream around.
Preview.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "string" or player.Character or player:GetAttribute("Nation") then
		return
	end
	local lobby = workspace.NationLobbies:FindFirstChild(id)
	local spawn = lobby and lobby:FindFirstChild("Spawn")
	if spawn then
		player.ReplicationFocus = spawn
	end
end)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		player.ReplicationFocus = nil
	end)
end)

ChooseNation.OnServerInvoke = function(player, id)
	return typeof(id) == "string" and NationService.Choose(player, id)
end

-- Gates: walking through one travels to its area (Rift, Crossroads, Nation).
local lastTouch = {}
for _, gate in workspace.NationLobbies:GetDescendants() do
	if gate:IsA("BasePart") and gate:GetAttribute("Travel") then
		gate.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or os.clock() - (lastTouch[player] or 0) < 2 then
				return
			end
			lastTouch[player] = os.clock()
			NationService.GoTo(player, gate:GetAttribute("Travel"))
		end)
	end
end

TravelTo.OnServerEvent:Connect(function(player, area)
	if typeof(area) ~= "string" or area == "Rift" or os.clock() - (lastTouch[player] or 0) < 2 then
		return -- the Rift is entered through the gate or the Play button
	end
	lastTouch[player] = os.clock()
	NationService.GoTo(player, area)
end)

-- Market stalls in the Crossroads.
for _, counter in workspace.NationLobbies:GetDescendants() do
	if counter:IsA("BasePart") and counter:GetAttribute("Market") then
		local prompt = counter:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				OpenMarket:FireClient(player, counter:GetAttribute("Market"))
			end)
		end
	end
end
MarketBuy.OnServerInvoke = function(player, offerId)
	return MarketService.Buy(player, offerId)
end
MarketSell.OnServerInvoke = function(player, itemId, count)
	return MarketService.Sell(player, itemId, count)
end

Players.PlayerAdded:Connect(NationService.Init)
Players.PlayerRemoving:Connect(function(player)
	lastTouch[player] = nil
	NationService.Remove(player)
end)
for _, player in Players:GetPlayers() do
	NationService.Init(player)
end

-- Studio-only hooks for testing ("reset" forgets the player's nation).
local debug = ServerStorage:FindFirstChild("NationDebug") or Instance.new("BindableFunction")
debug.Name = "NationDebug"
debug.OnInvoke = function(action, player, ...)
	if action == "reset" then
		NationService.Reset(player)
	elseif action == "choose" then
		return NationService.Choose(player, ...)
	elseif action == "rift" then
		NationService.EnterRift(player)
	elseif action == "lobby" then
		NationService.ReturnToLobby(player)
	elseif action == "hub" then
		NationService.GoToCrossroads(player)
	elseif action == "gold" then
		require(script.Parent.ProgressionService).AddGold(player, ...)
	elseif action == "item" then
		require(script.Parent.InventoryService).Add(player, ...)
	end
	return true
end
debug.Parent = ServerStorage
