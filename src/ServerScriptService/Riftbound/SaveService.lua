-- Saves each player's progress in the DataStore "RiftboundSave_v1" (key
-- "u<UserId>"): level, XP, gold, backpack items, owned skills (fusions and
-- awakenings included) with their levels and slots, and stat points.
-- Runes and cooldowns are never saved. The nation and story progress have
-- their own stores (NationService, StoryService).
--
-- Loaded when the player joins; saved when they leave, every AUTOSAVE seconds
-- and when the server shuts down. If loading fails, nothing is saved for that
-- player this session, so a hiccup can never wipe their real save.
--
-- Story runs: StoryService calls Checkpoint when a run starts. Until the act
-- is cleared (Commit), saves use the checkpoint's level, XP, gold and stat
-- points, and leaving, dying or disconnecting first (Rollback) puts them back,
-- so gold and XP from an unfinished story are never kept.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProgressionService = require(script.Parent.ProgressionService)
local StatService = require(script.Parent.StatService)
local InventoryService = require(script.Parent.InventoryService)
local BuildService = require(script.Parent.BuildService)

local STORE_NAME = "RiftboundSave_v1"
local VERSION = 1
local AUTOSAVE = 120
local RETRIES = 3

local SaveService = {}

-- Set by Main to send a toast.
SaveService.OnNotify = function(_player, _text, _color) end

local store
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn("[Save] DataStore unavailable, progress lasts for this session only:", result)
	end
end

local loaded = {} -- [player] = true once their save was read (or they're new)
local checkpoints = {} -- [player] = { Progress, Stats } while in an uncleared story run

local function key(userId)
	return "u" .. userId
end

local function retry(fn, ...)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(fn, ...)
		if ok then
			return true, result
		end
		if attempt < RETRIES then
			task.wait(attempt * 2)
		end
	end
	return false, result
end

-- Reads the player's save and hands each part to its service.
function SaveService.Load(player)
	if not store then
		return
	end
	local ok, saved = retry(store.GetAsync, store, key(player.UserId))
	if player.Parent ~= Players then
		return
	end
	if not ok then
		warn("[Save] load failed for", player.Name, saved)
		local message = if RunService:IsStudio()
			then "Saving is off in Studio: Game Settings > Security > Enable Studio Access to API Services"
			else "Your progress couldn't load. It won't be saved this session; rejoin to try again."
		SaveService.OnNotify(player, message, Color3.fromRGB(236, 80, 88))
		return
	end
	if type(saved) == "table" then
		ProgressionService.Import(player, saved.Progress)
		StatService.Import(player, saved.Stats)
		InventoryService.Import(player, saved.Items)
		BuildService.Import(player, saved.Build)
	end
	loaded[player] = true
end

-- Everything to save for the player right now (nil if their save never
-- loaded). Call it before the services forget a leaving player.
function SaveService.Collect(player)
	if not loaded[player] then
		return nil
	end
	local cp = checkpoints[player]
	return {
		Version = VERSION,
		Progress = if cp then cp.Progress else ProgressionService.Export(player),
		Stats = if cp then cp.Stats else StatService.Export(player),
		Items = InventoryService.Export(player),
		Build = BuildService.Export(player),
		SavedAt = os.time(),
	}
end

function SaveService.Write(userId, data)
	if not store or not data then
		return false
	end
	local ok, err = retry(store.SetAsync, store, key(userId), data, { userId })
	if not ok then
		warn("[Save] save failed for", userId, err)
	end
	return ok
end

function SaveService.Save(player)
	return SaveService.Write(player.UserId, SaveService.Collect(player))
end

-- Called after Collect when a player leaves.
function SaveService.Forget(player)
	loaded[player] = nil
	checkpoints[player] = nil
end

-------------------------------------------------------------------------------
-- Story runs
-------------------------------------------------------------------------------

-- A story run starts: remember what the player had.
function SaveService.Checkpoint(player)
	local progress, stats = ProgressionService.Export(player), StatService.Export(player)
	if progress and stats then
		checkpoints[player] = { Progress = progress, Stats = stats }
	end
end

-- The act was cleared: keep everything earned in the run.
function SaveService.Commit(player)
	checkpoints[player] = nil
end

-- The run ended without a clear: back to what the player had at the start.
-- Returns true if anything was rolled back.
function SaveService.Rollback(player)
	local cp = checkpoints[player]
	checkpoints[player] = nil
	if not cp then
		return false
	end
	local now = ProgressionService.Export(player)
	if not now then
		return false
	end
	ProgressionService.Import(player, cp.Progress)
	StatService.Import(player, cp.Stats)
	return now.Gold ~= cp.Progress.Gold or now.Xp ~= cp.Progress.Xp or now.Level ~= cp.Progress.Level
end

-------------------------------------------------------------------------------
-- Autosave and shutdown
-------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for _, player in Players:GetPlayers() do
			if loaded[player] then
				task.spawn(SaveService.Save, player)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		local data = SaveService.Collect(player)
		if data then
			pending += 1
			task.spawn(function()
				SaveService.Write(player.UserId, data)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

return SaveService
