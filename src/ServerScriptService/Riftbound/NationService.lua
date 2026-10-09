-- Nation choice, saving and lobby spawning.
-- A player picks a nation once (first join); it's saved in a DataStore and
-- published as the player attribute "Nation". Players spawn in their nation's
-- lobby; the lobby portal sends them into the Rift (gameplay) and dying there
-- brings them back to the lobby. "InRift" is true while in gameplay.
-- "Area" says where the player is: "Nation" (their lobby), "Crossroads" (the
-- shared main lobby where every nation meets) or "Rift".
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nations = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Nations"))

local STORE_NAME = "RiftboundNation_v1"
local RIFT_SPAWN_NAME = "SpawnLocation" -- gameplay spawn in workspace

local NationService = {}

-- Set by the lobby script.
NationService.OnNotify = function(_player, _text, _color) end
NationService.TravelRemote = nil -- RemoteEvent: client fades and moves itself

local store
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn("[Nation] DataStore unavailable, choices last for this session only:", result)
	end
end

local loaded = {} -- [player] = true once the saved nation was read

local function lobbySpawn(id)
	local lobbies = workspace:FindFirstChild("NationLobbies")
	local lobby = lobbies and lobbies:FindFirstChild(id)
	return lobby and lobby:FindFirstChild("Spawn", true)
end

local function riftSpawn()
	return workspace:FindFirstChild(RIFT_SPAWN_NAME)
end

local function hubSpawn()
	local lobbies = workspace:FindFirstChild("NationLobbies")
	local hub = lobbies and lobbies:FindFirstChild("Crossroads")
	return hub and hub:FindFirstChild("Spawn", true)
end

-- Where the player's next character should appear.
local function chooseRespawn(player)
	local id = player:GetAttribute("Nation")
	local spawn = if id and not player:GetAttribute("InRift") then lobbySpawn(id) else nil
	player.RespawnLocation = spawn or riftSpawn()
end

-- Players without a nation get no character: they wait on the select screen.
local function spawnCharacter(player)
	if player.Parent ~= Players then
		return
	end
	if not player:GetAttribute("Nation") then
		if player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
		return
	end
	chooseRespawn(player)
	player:LoadCharacter()
end

local function load(player)
	local id
	if store then
		for attempt = 1, 3 do
			local ok, value = pcall(store.GetAsync, store, "u" .. player.UserId)
			if ok then
				id = value
				break
			end
			warn("[Nation] load failed for", player.Name, value)
			task.wait(attempt)
		end
	end
	if id and Nations.Defs[id] then
		player:SetAttribute("Nation", id)
	else
		player:SetAttribute("NeedsNation", true)
	end
	loaded[player] = true
end

function NationService.Init(player)
	player:SetAttribute("InRift", false)
	player:SetAttribute("Area", "Nation")
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			-- Death in the Rift returns you to your nation's lobby.
			player:SetAttribute("InRift", false)
			player:SetAttribute("Area", "Nation")
			task.delay(Players.RespawnTime, function()
				if player.Character == char then
					spawnCharacter(player)
				end
			end)
		end)
	end)
	task.spawn(function()
		load(player)
		spawnCharacter(player)
	end)
end

function NationService.Remove(player)
	loaded[player] = nil
end

-- First-time choice from the select screen. Returns true on success.
function NationService.Choose(player, id)
	if not loaded[player] or player:GetAttribute("Nation") or not Nations.Defs[id] then
		return false
	end
	if store then
		-- One nation per player, ever: if a nation is already saved (e.g. the
		-- load above failed), keep that one instead of overwriting it.
		local existing
		local ok, err = pcall(store.UpdateAsync, store, "u" .. player.UserId, function(old)
			if old and Nations.Defs[old] then
				existing = old
				return nil -- cancel: keep the saved nation
			end
			return id
		end)
		if existing then
			id = existing
		elseif not ok then
			warn("[Nation] save failed for", player.Name, err)
		end
	end
	player:SetAttribute("NeedsNation", nil)
	player:SetAttribute("Nation", id)
	local def = Nations.Defs[id]
	NationService.OnNotify(player, `Sworn to the {def.Name}`, def.Color)
	task.delay(0.6, spawnCharacter, player)
	return true
end

-- Moves a living player between the lobby and the Rift without respawning.
local function travel(player, target)
	if not target or not player.Character then
		return
	end
	local cf = target.CFrame * CFrame.new(0, target.Size.Y / 2 + 3, 0)
	pcall(player.RequestStreamAroundAsync, player, cf.Position, 5)
	if NationService.TravelRemote then
		NationService.TravelRemote:FireClient(player, cf)
	end
end

function NationService.EnterRift(player)
	if player:GetAttribute("InRift") or not player:GetAttribute("Nation") then
		return
	end
	player:SetAttribute("InRift", true)
	player:SetAttribute("Area", "Rift")
	chooseRespawn(player)
	travel(player, riftSpawn())
end

function NationService.ReturnToLobby(player)
	local id = player:GetAttribute("Nation")
	if not id then
		return
	end
	player:SetAttribute("InRift", false)
	player:SetAttribute("Area", "Nation")
	chooseRespawn(player)
	travel(player, lobbySpawn(id))
end

-- The Crossroads: the main lobby shared by every nation (shop, merchant).
function NationService.GoToCrossroads(player)
	if not player:GetAttribute("Nation") or player:GetAttribute("Area") == "Crossroads" then
		return
	end
	player:SetAttribute("InRift", false)
	player:SetAttribute("Area", "Crossroads")
	chooseRespawn(player)
	travel(player, hubSpawn())
end

-- Sends a lobby player into another fighting area (e.g. a story arena),
-- arriving on  (a BasePart). Dying there returns them to their lobby.
function NationService.EnterArea(player, area, target)
	if player:GetAttribute("InRift") or not player:GetAttribute("Nation") or not target then
		return false
	end
	player:SetAttribute("InRift", true)
	player:SetAttribute("Area", area)
	chooseRespawn(player)
	travel(player, target)
	return true
end

-- Travel by area name ("Nation", "Crossroads" or "Rift").
function NationService.GoTo(player, area)
	if area == "Rift" then
		NationService.EnterRift(player)
	elseif area == "Crossroads" then
		NationService.GoToCrossroads(player)
	elseif area == "Nation" and player:GetAttribute("Area") ~= "Nation" then
		NationService.ReturnToLobby(player)
	end
end

-- Studio testing: forget a player's nation so the select screen shows again.
function NationService.Reset(player)
	if store then
		pcall(store.RemoveAsync, store, "u" .. player.UserId)
	end
	player:SetAttribute("Nation", nil)
	player:SetAttribute("InRift", false)
	player:SetAttribute("Area", "Nation")
	player:SetAttribute("NeedsNation", true)
	spawnCharacter(player)
end

return NationService
