-- Story runs: a player starts an act from the story screen and is sent to its
-- arena; others starting the same act join the same run. Waves of husks rise
-- from the rift scars, then the act's boss if it has one. Clearing pays gold
-- and Essence, unlocks the next act and opens the exit gate.
-- Cleared acts are saved (DataStore "RiftboundStory_v1") and published as the
-- player attributes StoryProgress ("Fire:1,Water:1") and StoryCleared (count).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Story = require(Shared:WaitForChild("Story"))
local Nations = require(Shared:WaitForChild("Nations"))
local NationService = require(script.Parent.NationService)
local Enemies = require(script.Parent.Enemies)
local ProgressionService = require(script.Parent.ProgressionService)
local InventoryService = require(script.Parent.InventoryService)
local StoryBuilder = require(script.Parent.StoryBuilder)

-- Nation foes (anime-style grunts and elites per nation) replace the husks
-- when the NationFoes module is in the place; bosses stay as they are.
local NationFoes
do
	local module = script.Parent:FindFirstChild("NationFoes")
	if module then
		local ok, result = pcall(require, module)
		NationFoes = if ok then result else nil
	end
end

local WAVE_GAP = 3 -- seconds between waves
local START_DELAY = 4

local StoryService = {}

-- Set by Story.server.
StoryService.OnNotify = function(_player, _text, _color) end
StoryService.OnBanner = function(_player, _payload) end

local store
pcall(function()
	store = DataStoreService:GetDataStore("RiftboundStory_v1")
end)

local cleared = {} -- [player] = { ["Fire:1"] = true }
local runs = {} -- [arenaName] = run

local function publish(player)
	local set = cleared[player] or {}
	local keys = {}
	for key in set do
		table.insert(keys, key)
	end
	table.sort(keys)
	local acts = 0
	for _, key in keys do
		if not key:match(":%a+$") then
			acts += 1 -- "Fire:1" counts; "Fire:1:Hard" only records the tier
		end
	end
	player:SetAttribute("StoryProgress", table.concat(keys, ","))
	player:SetAttribute("StoryCleared", acts)
end

local function save(player)
	if not store or not cleared[player] then
		return
	end
	local keys = {}
	for key in cleared[player] do
		table.insert(keys, key)
	end
	local ok, err = pcall(store.SetAsync, store, "u" .. player.UserId, HttpService:JSONEncode(keys), { player.UserId })
	if not ok then
		warn("[Story] save failed for", player.Name, err)
	end
end

function StoryService.Init(player)
	cleared[player] = {}
	if store then
		local ok, value = pcall(store.GetAsync, store, "u" .. player.UserId)
		if ok and type(value) == "string" then
			local decoded = select(2, pcall(HttpService.JSONDecode, HttpService, value))
			if type(decoded) == "table" then
				for _, key in decoded do
					cleared[player][key] = true
				end
			end
		end
	end
	publish(player)
end

function StoryService.IsUnlocked(player, nationId, act)
	if act == 1 then
		return true
	end
	return (cleared[player] or {})[Story.Key(nationId, act - 1)] == true
end

local function notifyRun(run, text, color)
	for player in run.Players do
		StoryService.OnNotify(player, text, color)
	end
end

local function bannerRun(run, payload)
	for player in run.Players do
		StoryService.OnBanner(player, payload)
	end
end

local function aliveCount(run)
	local n = 0
	for model in run.Enemies do
		if Enemies.IsAlive(model) then
			n += 1
		else
			run.Enemies[model] = nil
		end
	end
	return n
end

local function spawnEnemy(run, kind, at, stats)
	local story = Story.Defs[run.Nation]
	local def = Nations.Defs[run.Nation]
	local diff = Story.Difficulties[run.Difficulty]
	local scale = Story.Scale[run.Act]
	local cframe = at.CFrame * CFrame.new(math.random(-2, 2), 0, math.random(-2, 2))
	local opts = {
		Name = stats.Name or story[kind],
		Visual = "RiftHusk",
		Health = math.floor(stats.Health * scale * diff.Health),
		Speed = stats.Speed,
		Chase = true,
		Damage = math.floor(stats.Damage * scale * diff.Damage),
		Xp = stats.Xp,
		Gold = stats.Gold,
		Loot = {
			{ Id = "RiftShard", Chance = 0.6, Min = 1, Max = 2 },
			{ Id = "HuskIchor", Chance = if kind == "Grunt" then 0.25 else 0.6 },
			{ Id = "EmberCore", Chance = if kind == "Grunt" then 0.04 else 0.15 },
		},
		Color = if kind == "Grunt" then def.Deep else def.Color,
	}
	local model
	if NationFoes and kind ~= "Boss" then
		model = NationFoes.Spawn(run.Nation, kind, cframe, opts)
	else
		model = Enemies.SpawnDummy(cframe, opts)
	end
	model:SetAttribute("StoryRun", run.Name)
	if kind ~= "Grunt" then
		model:SetAttribute("Elite", true)
	end
	-- Bosses (and husk brutes, when nation foes are missing) are scaled up.
	if kind == "Boss" or (kind == "Elite" and not NationFoes) then
		pcall(model.ScaleTo, model, if kind == "Boss" then 2.2 else 1.35)
	end
	if kind == "Boss" then
		model:SetAttribute("Boss", true)
		model:SetAttribute("BossName", stats.Name)
	end
	run.Enemies[model] = true
	return model
end

local function cleanup(run)
	for model in run.Enemies do
		if model.Parent then
			model:Destroy()
		end
	end
	table.clear(run.Enemies)
	local exit = run.Arena:FindFirstChild("ExitGate", true)
	local shown = exit and exit:GetAttribute("HiddenPivot")
	if shown then
		exit:PivotTo(shown)
		exit:SetAttribute("HiddenPivot", nil)
	end
	run.State = "Idle"
	run.Token += 1
end

local function reward(run)
	for player in run.Players do
		local diff = Story.Difficulties[run.Difficulty]
		local key = Story.Key(run.Nation, run.Act)
		local tierKey = Story.Key(run.Nation, run.Act, run.Difficulty)
		local first = not cleared[player][tierKey]
		cleared[player][key] = true
		cleared[player][tierKey] = true
		publish(player)
		task.spawn(save, player)
		local gold = math.floor(Story.ClearGold[run.Act] * diff.Reward) * (if first then 2 else 1)
		local essence = Story.EssenceReward[run.Act] * diff.Reward
		if player:GetAttribute("Nation") == run.Nation then
			essence *= Story.HomeBonus
		end
		essence = math.floor(essence)
		ProgressionService.AddGold(player, gold)
		InventoryService.Add(player, Story.EssenceId(run.Nation), essence)
		StoryService.OnBanner(player, {
			Kind = "Cleared",
			Title = "Act " .. run.Act .. " Cleared",
			Difficulty = run.Difficulty,
			Subtitle = Story.Defs[run.Nation].Acts[run.Act].Name,
			Gold = gold,
			Essence = essence,
			EssenceId = Story.EssenceId(run.Nation),
			First = first,
			Color = Story.Defs[run.Nation].Color,
		})
	end
end

local function showExit(run)
	local exit = run.Arena:FindFirstChild("ExitGate", true)
	local target = exit and exit:GetAttribute("ShownPivot")
	if target then
		exit:SetAttribute("HiddenPivot", exit:GetPivot())
		exit:PivotTo(target)
	end
end

local function play(run)
	local token = run.Token
	local story = Story.Defs[run.Nation]
	local actDef = story.Acts[run.Act]
	local spawns = run.Arena.EnemySpawns
	local marks = {}
	for _, m in spawns:GetChildren() do
		if m.Name == "Spawn" then
			table.insert(marks, m)
		end
	end
	local function alive()
		return run.Token == token and next(run.Players) ~= nil
	end
	local function waitClear()
		while alive() and aliveCount(run) > 0 do
			task.wait(0.5)
		end
		return alive()
	end

	bannerRun(run, { Kind = "Act", Title = "Act " .. run.Act .. ": " .. actDef.Name, Subtitle = "[" .. run.Difficulty:upper() .. "]  " .. actDef.Text, Color = story.Color })
	task.wait(START_DELAY)
	local total = #actDef.Waves + (if actDef.Boss then 1 else 0)
	for i, wave in actDef.Waves do
		if not alive() then
			return
		end
		bannerRun(run, { Kind = "Wave", Title = "Wave " .. i .. " / " .. total, Color = story.Color })
		local stats = Story.Kinds[wave.Kind]
		for n = 1, wave.Count do
			spawnEnemy(run, wave.Kind, marks[(n + i) % #marks + 1], stats)
			task.wait(0.25)
		end
		if not waitClear() then
			return
		end
		task.wait(WAVE_GAP)
	end
	if actDef.Boss and alive() then
		local boss = actDef.Boss
		bannerRun(run, { Kind = "Boss", Title = boss.Name, Subtitle = "Final wave", Color = story.Color })
		task.wait(2)
		local model = spawnEnemy(run, "Boss", spawns.BossSpawn, boss)
		-- At two-thirds and one-third health the boss calls for help.
		local hum = model:FindFirstChildOfClass("Humanoid")
		local calls = { 0.66, 0.33 }
		while alive() and Enemies.IsAlive(model) do
			local frac = hum.Health / hum.MaxHealth
			if calls[1] and frac <= calls[1] then
				table.remove(calls, 1)
				notifyRun(run, boss.Name .. " calls the Rift!", story.Color)
				for n = 1, 3 do
					spawnEnemy(run, "Grunt", marks[n * 2], Story.Kinds.Grunt)
				end
			end
			task.wait(0.3)
		end
		if not waitClear() then
			return
		end
	end
	if not alive() then
		return
	end
	run.State = "Cleared"
	reward(run)
	showExit(run)
end

local function getRun(nationId, act)
	local name = StoryBuilder.Name(nationId, act)
	local arenas = workspace:FindFirstChild("StoryArenas")
	local arena = arenas and arenas:FindFirstChild(name)
	if not arena then
		return nil
	end
	local run = runs[name]
	if not run then
		run = { Name = name, Nation = nationId, Act = act, Arena = arena, Players = {}, Enemies = {}, State = "Idle", Token = 0, Difficulty = "Easy" }
		runs[name] = run
	end
	return run
end

-- Returns ok, message.
function StoryService.Start(player, nationId, act, difficulty)
	difficulty = difficulty or "Easy"
	local diff = Story.Difficulties[difficulty]
	if not Story.Defs[nationId] or typeof(act) ~= "number" or not Story.Defs[nationId].Acts[act] or not diff then
		return false, "Unknown act"
	end
	if not StoryService.IsUnlocked(player, nationId, act) then
		return false, "Clear the previous act first"
	end
	if diff.Needs and not (cleared[player] or {})[Story.Key(nationId, act, diff.Needs)] then
		return false, "Clear this act on " .. diff.Needs .. " first"
	end
	if player:GetAttribute("InRift") or not player:GetAttribute("Nation") or not player.Character then
		return false, "Start a story from a lobby"
	end
	local run = getRun(nationId, act)
	if not run then
		return false, "This act isn't built yet"
	end
	if run.State == "Cleared" and next(run.Players) == nil then
		cleanup(run)
	end
	if not NationService.EnterArea(player, "Story", run.Arena.Entry) then
		return false, "Can't travel right now"
	end
	run.Players[player] = true
	player:SetAttribute("StoryRun", run.Name)
	if run.State == "Idle" then
		run.Difficulty = difficulty
		run.State = "Fighting"
		task.spawn(play, run)
	elseif run.Difficulty ~= difficulty then
		StoryService.OnNotify(player, "Joined a run already in progress on " .. run.Difficulty, Story.Defs[nationId].Color)
	elseif run.State == "Cleared" then
		StoryService.OnNotify(player, "This act was just cleared. Walk through the gate to leave.", Story.Defs[nationId].Color)
	end
	return true, "Entering " .. Story.Defs[nationId].Acts[act].Name
end

-- Called when a player leaves a run (death, gate, quitting).
function StoryService.Leave(player)
	local name = player:GetAttribute("StoryRun")
	local run = name and runs[name]
	player:SetAttribute("StoryRun", nil)
	if not run then
		return
	end
	run.Players[player] = nil
	if next(run.Players) == nil then
		cleanup(run)
	end
end

function StoryService.Remove(player)
	StoryService.Leave(player)
	cleared[player] = nil
end

return StoryService
