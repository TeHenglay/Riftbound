-- Story runs: a player starts an act from the story screen and is sent to its
-- arena with their party (PartyService); every run is private, so two parties
-- on the same act each get their own copy of the arena (cloned on demand and
-- reused, ARENA_OFFSET apart). Only the party leader starts, retries or moves
-- on to the next act. Waves of husks rise
-- from the rift scars, then the act's boss if it has one. Mobs drop only gold
-- and XP; clearing pays gold plus the act's material bundle, unlocks the next
-- act and opens the exit gate. Each cleared wave pauses the run for up to
-- Runes.PickTime while every player picks 1 of 3 runes (this run only); runes
-- are wiped when a player starts or leaves a run.
-- Cleared acts are saved (DataStore "RiftboundStory_v1") and published as the
-- player attributes StoryProgress ("Fire:1,Water:1") and StoryCleared (count).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Story = require(Shared:WaitForChild("Story"))
local Nations = require(Shared:WaitForChild("Nations"))
local Runes = require(Shared:WaitForChild("Runes"))
local BuildService = require(script.Parent.BuildService)
local RunStats = require(script.Parent.RunStats)
local NationService = require(script.Parent.NationService)
local Enemies = require(script.Parent.Enemies)
local ProgressionService = require(script.Parent.ProgressionService)
local InventoryService = require(script.Parent.InventoryService)
local StoryBuilder = require(script.Parent.StoryBuilder)
local PartyService = require(script.Parent.PartyService)
local StatService = require(script.Parent.StatService)
local BlockService = require(script.Parent.BlockService)
local SaveService = require(script.Parent.SaveService)

-- Nation foes replace the husks when the NationFoes module is in the place:
-- every wave mob is the nation's element golem, the nation's named grunt and
-- elite are the Act 1 and Act 2 bosses (Boss.Foe), and Act 3 bosses stay as
-- they are.
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
local ARENA_OFFSET = Vector3.new(0, 0, 4000) -- between copies of one act's arena

local StoryService = {}

-- Set by Story.server.
StoryService.OnNotify = function(_player, _text, _color) end
StoryService.OnBanner = function(_player, _payload) end
StoryService.OnArenaCreated = function(_arena) end -- a new arena copy (hook its exit gate)

local store
pcall(function()
	store = DataStoreService:GetDataStore("RiftboundStory_v1")
end)

local cleared = {} -- [player] = { ["Fire:1"] = true }
local runs = {} -- [arenaName] = run
local pools = {} -- ["Fire_Act1"] = { Template = Model, Arenas = { Model, ... } }

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
					-- "Fire:1:Easy" etc. from the old difficulty tiers.
					local base, tier = key:match("^(.-:%d+):(%a+)$")
					if base and Story.LegacyDifficulty[tier] then
						key = base .. ":" .. Story.LegacyDifficulty[tier]
					end
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
		Color = if kind == "Grunt" then def.Deep else def.Color,
	}
	local model
	local foeBoss = kind == "Boss" and stats.Foe and NationFoes
	if foeBoss then
		model = NationFoes.SpawnFoe(run.Nation, stats.Foe, cframe, opts)
	elseif NationFoes and kind ~= "Boss" then
		model = NationFoes.Spawn(run.Nation, kind, cframe, opts)
	else
		model = Enemies.SpawnDummy(cframe, opts)
	end
	model:SetAttribute("StoryRun", run.Name)
	if kind == "Brute" or kind == "Elite" or kind == "Boss" then
		model:SetAttribute("Elite", true)
	end
	-- Bosses (and husk brutes, when nation foes are missing) are scaled up.
	-- Named-foe bosses already have their own size, so they grow less.
	if kind == "Boss" or (kind ~= "Grunt" and kind ~= "Swarmer" and not NationFoes) then
		local size = if foeBoss then 1.5 elseif kind == "Boss" then 2.2 else 1.35
		pcall(model.ScaleTo, model, model:GetScale() * size)
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
		SaveService.Commit(player) -- cleared: gold and XP from this run are kept
		local diff = Story.Difficulties[run.Difficulty]
		local key = Story.Key(run.Nation, run.Act)
		local tierKey = Story.Key(run.Nation, run.Act, run.Difficulty)
		local first = not cleared[player][tierKey]
		cleared[player][key] = true
		cleared[player][tierKey] = true
		publish(player)
		task.spawn(save, player)
		local gold = math.floor(Story.ClearGold[run.Act] * diff.Reward) * (if first then 2 else 1)
		local guaranteed, bonus = Story.Bundle(run.Nation, run.Act, run.Difficulty, player:GetAttribute("Nation") == run.Nation)
		local counts, order = {}, {}
		local function give(id, count)
			if count <= 0 then
				return
			end
			if not counts[id] then
				table.insert(order, id)
			end
			counts[id] = (counts[id] or 0) + count
		end
		for _, entry in guaranteed do
			give(entry.Id, entry.Count)
		end
		for _, entry in bonus do
			if math.random() < entry.Chance then
				give(entry.Id, 1)
			end
		end
		local items = {}
		for _, id in order do
			InventoryService.Add(player, id, counts[id])
			table.insert(items, { Id = id, Count = counts[id] })
		end
		ProgressionService.AddGold(player, gold)
		-- Act 1 can drop the nation's home skill (new, or +1 level).
		local skill
		local skillId, chance = Story.SkillDropOf(run.Nation, run.Act)
		if skillId and math.random() < chance then
			local level = BuildService.Grant(player, skillId)
			if level then
				skill = { Id = skillId, Level = level }
			end
		end
		StoryService.OnBanner(player, {
			Kind = "Cleared",
			Title = "Act " .. run.Act .. " Cleared",
			Difficulty = run.Difficulty,
			Subtitle = Story.Defs[run.Nation].Acts[run.Act].Name,
			Gold = gold,
			Items = items,
			Skill = skill,
			First = first,
			Nation = run.Nation,
			Act = run.Act,
			Time = math.floor(os.clock() - (run.StartedAt or os.clock())),
			Damage = math.floor(RunStats.Get(player).Damage),
			Kills = RunStats.Get(player).Kills,
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
	-- Spawns a mixed pack kind by kind, spread across the rift scars.
	local function spawnWave(wave, offset)
		local n = offset
		for _, kind in Story.KindOrder do
			for _ = 1, wave[kind] or 0 do
				if not alive() then
					return
				end
				n += 1
				spawnEnemy(run, kind, marks[n % #marks + 1], Story.Kinds[kind])
				task.wait(0.2)
			end
		end
	end
	-- The run holds (no spawns, arena empty) until everyone has picked a rune
	-- or the timer runs out; latecomers get a random one in their pouch.
	local function offerRunes(runWave)
		-- Players are frozen in place while they choose, like a pause.
		local frozen = {}
		for player in run.Players do
			BuildService.OfferRunes(player, Runes.RollChoices(runWave, Runes.Choices), Runes.PickTime)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and not root.Anchored then
				root.Anchored = true
				frozen[player] = root
			end
		end
		local function thaw(player)
			local root = frozen[player]
			frozen[player] = nil
			if root and root.Parent then
				root.Anchored = false
			end
		end
		local ends = os.clock() + Runes.PickTime
		while alive() and os.clock() < ends do
			local waiting = false
			for player in run.Players do
				if BuildService.HasOffer(player) then
					waiting = true
				else
					thaw(player) -- picked: free to move while others choose
				end
			end
			if not waiting then
				break
			end
			task.wait(0.2)
		end
		for player in run.Players do
			BuildService.ResolveOffer(player)
		end
		for player in frozen do
			thaw(player)
		end
	end
	local function waitClear()
		while alive() and aliveCount(run) > 0 do
			task.wait(0.5)
		end
		return alive()
	end

	bannerRun(run, { Kind = "Act", Title = "Act " .. run.Act .. ": " .. actDef.Name, Subtitle = "[" .. run.Difficulty:upper() .. "]  " .. actDef.Text, Color = story.Color })
	task.wait(START_DELAY)
	run.StartedAt = os.clock() -- the clear time counts from wave 1
	local total = #actDef.Waves + (if actDef.Boss then 1 else 0)
	for i, wave in actDef.Waves do
		if not alive() then
			return
		end
		bannerRun(run, { Kind = "Wave", Title = "Wave " .. i .. " / " .. total, Subtitle = Story.WaveSize(wave) .. " foes", Color = story.Color })
		spawnWave(wave, i)
		if not waitClear() then
			return
		end
		offerRunes(Runes.RunWave(run.Act, i))
		task.wait(WAVE_GAP)
	end
	if actDef.Boss and alive() then
		local boss = actDef.Boss
		bannerRun(run, { Kind = "Boss", Title = boss.Name, Subtitle = "Final wave", Color = story.Color })
		task.wait(2)
		local model = spawnEnemy(run, "Boss", spawns.BossSpawn, boss)
		-- As its health drops the boss calls a fresh pack (Story.BossCalls).
		local hum = model:FindFirstChildOfClass("Humanoid")
		local call = 1
		while alive() and Enemies.IsAlive(model) do
			local frac = hum.Health / hum.MaxHealth
			local pending = Story.BossCalls[call]
			if pending and frac <= pending.At then
				call += 1
				notifyRun(run, boss.Name .. " calls the Rift!", story.Color)
				spawnWave(pending.Wave, call * 3)
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

-- One pool of arenas per act: the built arena plus copies made when every one
-- is taken. Returns nil if the act has no built arena.
local function getPool(nationId, act)
	local name = StoryBuilder.Name(nationId, act)
	local pool = pools[name]
	if pool then
		return pool
	end
	local folder = workspace:FindFirstChild("StoryArenas")
	local base = folder and folder:FindFirstChild(name)
	if not base then
		return nil
	end
	-- Copied before any run touches it, so copies start with the gate hidden.
	pool = { Name = name, Template = base:Clone(), Arenas = { base }, Folder = folder }
	pools[name] = pool
	return pool
end

local function freeArena(pool)
	for _, arena in pool.Arenas do
		if not runs[arena.Name] then
			return arena
		end
	end
	local slot = #pool.Arenas
	local offset = ARENA_OFFSET * slot
	local arena = pool.Template:Clone()
	arena.Name = pool.Name .. "_" .. slot
	arena:PivotTo(arena:GetPivot() + offset)
	local center = arena:GetAttribute("Center")
	if center then
		arena:SetAttribute("Center", center + offset)
		workspace.Terrain:FillBlock(CFrame.new(center + offset + Vector3.new(0, 20, 0)), Vector3.new(680, 420, 680), Enum.Material.Air)
	end
	local exit = arena:FindFirstChild("ExitGate", true)
	local shown = exit and exit:GetAttribute("ShownPivot")
	if shown then
		exit:SetAttribute("ShownPivot", shown + offset)
	end
	arena.Parent = pool.Folder
	table.insert(pool.Arenas, arena)
	StoryService.OnArenaCreated(arena)
	return arena
end

local function newRun(nationId, act, difficulty)
	local pool = getPool(nationId, act)
	if not pool then
		return nil
	end
	local arena = freeArena(pool)
	local run = { Name = arena.Name, Nation = nationId, Act = act, Arena = arena, Players = {}, Enemies = {}, State = "Idle", Token = 0, Difficulty = difficulty }
	runs[run.Name] = run
	return run
end

local function release(run)
	cleanup(run)
	if runs[run.Name] == run then
		runs[run.Name] = nil
	end
end

-- A fresh start for a run: full speed (no leftover shield, flask or foe
-- slow), not frozen from a rune pick.
local function freshBody(player)
	BlockService.Reset(player)
	StatService.ClearSpeedMods(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
end

local function join(run, player)
	if not NationService.EnterArea(player, "Story", run.Arena.Entry) then
		return false
	end
	run.Players[player] = true
	player:SetAttribute("StoryRun", run.Name)
	BuildService.ResetRunes(player) -- every run starts with empty sockets
	RunStats.Reset(player)
	freshBody(player)
	SaveService.Checkpoint(player) -- run gold and XP only count once the act is cleared
	return true
end

-- Sends the player and `followers` into a fresh run of the act; `busy` are
-- party members who couldn't come. Returns ok, message.
local function begin(player, nationId, act, difficulty, followers, busy)
	local run = newRun(nationId, act, difficulty)
	if not run then
		return false, "This act isn't built yet"
	end
	if not join(run, player) then
		release(run)
		return false, "Can't travel right now"
	end
	local story = Story.Defs[nationId]
	local actName = story.Acts[act].Name
	for _, p in followers do
		if join(run, p) then
			StoryService.OnNotify(p, player.DisplayName .. " is taking the party to " .. actName, story.Color)
		end
	end
	for _, p in busy do
		StoryService.OnNotify(player, p.DisplayName .. " is busy and stayed behind", story.Color)
	end
	run.State = "Fighting"
	task.spawn(play, run)
	return true, "Entering " .. actName
end

-- Starts a private run for the player and the party members waiting in a
-- lobby. Returns ok, message.
function StoryService.Start(player, nationId, act, difficulty)
	difficulty = difficulty or Story.DefaultDifficulty
	local diff = Story.Difficulties[difficulty]
	if not Story.Defs[nationId] or typeof(act) ~= "number" or not Story.Defs[nationId].Acts[act] or not diff then
		return false, "Unknown act"
	end
	if not PartyService.CanStart(player) then
		return false, "Only your party leader can start"
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
	return begin(player, nationId, act, difficulty, PartyService.Followers(player))
end

local function runOf(player)
	local name = player:GetAttribute("StoryRun")
	return name and runs[name]
end

-- In a party, the leader picks Retry / Next for the run, unless they already
-- left it.
local function canChoose(player, run)
	local party = PartyService.Get(player)
	return not party or party.Leader == player or not run.Players[party.Leader]
end

-- Replays a cleared act for everyone still in it, on the same difficulty.
-- Returns ok, message.
function StoryService.Retry(player)
	local run = runOf(player)
	if not run then
		return false, "You're not in a story"
	end
	if run.State ~= "Cleared" then
		return false, "Finish the act first"
	end
	if not canChoose(player, run) then
		return false, "Your party leader chooses what's next"
	end
	local difficulty = run.Difficulty
	cleanup(run) -- clears leftovers, hides the exit gate, bumps the token
	run.Difficulty = difficulty
	run.State = "Fighting"
	local entry = run.Arena:FindFirstChild("Entry")
	for p in run.Players do
		BuildService.ResetRunes(p) -- a fresh run starts with empty sockets
		RunStats.Reset(p)
		freshBody(p)
		SaveService.Checkpoint(p)
		local char = p.Character
		if char and entry then
			char:PivotTo(entry.CFrame + Vector3.new(0, 4, 0))
		end
	end
	task.spawn(play, run)
	return true
end

-- Moves everyone in a cleared act straight into the next one. Hard falls
-- back to Normal if the next act hasn't been cleared on Normal yet.
function StoryService.Next(player)
	local run = runOf(player)
	if not run or run.State ~= "Cleared" then
		return false, "Finish the act first"
	end
	if not canChoose(player, run) then
		return false, "Your party leader chooses what's next"
	end
	local nationId, act = run.Nation, run.Act + 1
	if not Story.Defs[nationId].Acts[act] then
		return false, "That was the last act"
	end
	if not getPool(nationId, act) then
		return false, "The next act isn't built yet"
	end
	local difficulty = run.Difficulty
	local need = Story.Difficulties[difficulty].Needs
	if need and not (cleared[player] or {})[Story.Key(nationId, act, need)] then
		difficulty = Story.DefaultDifficulty
	end
	local companions = {}
	for p in run.Players do
		if p ~= player then
			table.insert(companions, p)
		end
	end
	for _, p in { player, table.unpack(companions) } do
		StoryService.Leave(p)
		p:SetAttribute("InRift", false) -- EnterArea only works from outside a run
	end
	local ok, message = begin(player, nationId, act, difficulty, companions, {})
	if not ok then
		-- Nowhere to go: send everyone home instead of leaving them in an empty arena.
		for _, p in { player, table.unpack(companions) } do
			NationService.GoTo(p, "Crossroads")
		end
	end
	return ok, message
end

-- Called when a player leaves a run (death, gate, quitting).
function StoryService.Leave(player)
	local name = player:GetAttribute("StoryRun")
	local run = name and runs[name]
	player:SetAttribute("StoryRun", nil)
	BuildService.ResetRunes(player) -- runes never leave the run
	-- Leaving before the act is cleared loses the gold and XP earned in it.
	if SaveService.Rollback(player) and player.Parent then
		StoryService.OnNotify(player, "Act not cleared: gold and XP from this run were lost", Color3.fromRGB(236, 80, 88))
	end
	if not run then
		return
	end
	run.Players[player] = nil
	if next(run.Players) == nil then
		release(run)
	end
end

function StoryService.Remove(player)
	StoryService.Leave(player)
	RunStats.Remove(player)
	cleared[player] = nil
end

return StoryService
