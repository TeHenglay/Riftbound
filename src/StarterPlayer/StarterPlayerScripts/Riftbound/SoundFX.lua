-- Client-side sound. Plays the sounds in ReplicatedStorage.Riftbound.SoundLibrary
-- for everything that happens in the game, without any other script having to
-- call it: it listens to the same signals the visuals use.
--   SkillFx remote       skill casts, explosions, zones, bolts, shield, heal, level up
--   RiftEnemy models     SpawnAt / AttackAt / HitAt / Reaction / Status_Freeze attributes, death
--   Local player         health (hurt, death), Gold, Xp, FlaskCharges, StatPoints, dash
--   Notify / OpenForge   fusing, new skills, item pickups, the Forge screen
--   PlayerGui buttons    click and hover
-- Music crossfades from exploring to combat while Rift Husks are close by.
-- Your own casts play their cast sound instantly (it hooks CastAnimator.Play, which
-- Controls calls the moment you press the key) instead of waiting for the server.
-- Every sound file is loaded once into a template at startup and cloned to play,
-- so nothing has to load at the moment it is needed.
-- Other scripts can also call SoundFX.Play("Name") or SoundFX.PlayAt("Name", position).
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Library = require(Shared:WaitForChild("SoundLibrary"))

local player = Players.LocalPlayer

local ENEMY_TAG = "RiftEnemy"
local DEFAULT_RANGE = 140
local FADE_TIME = 0.15
local COMBAT_RADIUS = 60 -- a living Husk this close switches to combat music
local COMBAT_LINGER = 6 -- seconds of calm before the music settles again
local MUSIC_FADE = 2.5

local SoundFX = {}

local groups: { [string]: SoundGroup } = {}
local lastPlayed = {}
local anchor -- invisible part at the origin; 3D sounds play from attachments on it
local rng = Random.new()
local templates = {} -- [asset id] = loaded Sound to clone
local predicted = {} -- [skill id] = os.clock() of a cast sound played locally

local function group(name)
	return groups[name or "SFX"] or groups.SFX
end

local function pickId(def)
	local id = def.Id
	if def.Ids then
		id = def.Ids[rng:NextInteger(1, #def.Ids)]
	end
	return id
end

local templateFolder

local function template(id)
	local t = templates[id]
	if not t then
		t = Instance.new("Sound")
		t.Name = tostring(id)
		t.SoundId = "rbxassetid://" .. tostring(id)
		t.Volume = 0
		t.Parent = templateFolder
		templates[id] = t
	end
	return t
end

local function pickPitch(def)
	local p = def.Pitch
	if type(p) == "table" then
		return rng:NextNumber(p[1], p[2])
	end
	return p or 1
end

local function fadeOut(sound, time)
	if not sound.Parent then
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(time or FADE_TIME), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Builds and starts one sound. `parent` is an Attachment (3D) or SoundService (2D).
local function start(name, parent, looped)
	local def = Library.Sounds[name]
	if not def then
		warn("SoundFX: no sound named", name)
		return nil
	end
	local now = os.clock()
	if def.Gap and now - (lastPlayed[name] or 0) < def.Gap then
		return nil
	end
	lastPlayed[name] = now

	local id = pickId(def)
	local sound = template(id):Clone()
	sound.Name = name
	sound.Volume = def.Volume or 0.5
	sound.PlaybackSpeed = pickPitch(def)
	sound.Looped = looped == true
	sound.SoundGroup = group(def.Group)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 15
	sound.RollOffMaxDistance = def.Range or DEFAULT_RANGE
	local offset = Library.Starts[id] or def.Start
	if offset then
		sound.TimePosition = offset
	end
	sound.Parent = parent
	sound:Play()

	if not looped then
		if def.Length then
			-- Length is in real seconds; the file plays faster at higher pitch.
			task.delay(def.Length, fadeOut, sound)
		end
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(30, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end

	for _, layer in def.Layer or {} do
		start(layer, parent)
	end
	return sound
end

local function anchorAt(position, life)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = anchor
	task.delay(life or 6, function()
		att:Destroy()
	end)
	return att
end

-- Plays a 2D sound (heard the same everywhere): UI, pickups, your own hurt sounds.
function SoundFX.Play(name)
	return start(name, SoundService)
end

-- Plays a 3D sound at a world position.
function SoundFX.PlayAt(name, position)
	if typeof(position) ~= "Vector3" then
		return SoundFX.Play(name)
	end
	local def = Library.Sounds[name]
	return start(name, anchorAt(position, (def and def.Length or 4) + 2))
end

-- Loops a 3D sound at a position for `duration` seconds, then fades it out.
function SoundFX.LoopAt(name, position, duration)
	local att = anchorAt(position, duration + 2)
	local sound = start(name, att, true)
	if sound then
		task.delay(duration, fadeOut, sound, 0.6)
	end
	return sound
end

-- Changes a group's volume (SFX, UI, Music, Ambient), e.g. from a settings menu.
function SoundFX.SetVolume(groupName, volume)
	if groups[groupName] then
		groups[groupName].Volume = volume
	end
end

---------------------------------------------------------------------------
-- Skill events

local function eventPosition(e)
	if typeof(e.At) == "Vector3" then
		return e.At
	end
	if typeof(e.From) == "Vector3" then
		if typeof(e.Dir) == "Vector3" and type(e.Length) == "number" then
			return e.From + e.Dir * (e.Length * 0.4)
		end
		return e.From
	end
	if typeof(e.To) == "Vector3" then
		return e.To
	end
	for _, key in { "Target", "Root" } do
		local part = e[key]
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			return part.Position
		end
	end
	return nil
end

local function seconds(e, value)
	if type(value) == "number" then
		return value
	elseif type(value) == "string" and type(e[value]) == "number" then
		return e[value]
	end
	return 0
end

local function runEntry(entry, e, position)
	if type(entry) == "string" then
		SoundFX.PlayAt(entry, position)
		return
	end
	if entry[1] == nil then
		return
	end
	if #entry > 1 or type(entry[1]) == "table" then
		for _, sub in entry do
			runEntry(sub, e, position)
		end
		return
	end
	if entry.If and not e[entry.If] then
		return
	end
	if entry.Unless and e[entry.Unless] then
		return
	end
	local name = entry[1]
	local play = function()
		if entry.For then
			SoundFX.LoopAt(name, position, seconds(e, entry.For))
		else
			SoundFX.PlayAt(name, position)
		end
	end
	local wait = seconds(e, entry.After)
	if wait > 0 then
		task.delay(wait, play)
	else
		play()
	end
end

local function isMine(e)
	if e.Caster == player then
		return true
	end
	local char = player.Character
	local part = e.Target or e.Root
	return char ~= nil and typeof(part) == "Instance" and part:IsDescendantOf(char)
end

local PLAYER_EVENTS = {
	Shield = function(e, pos)
		if e.Up then
			SoundFX.PlayAt("ShieldUp", pos)
		elseif e.Broken then
			SoundFX.PlayAt("ShieldBreak", pos)
		end
	end,
	Blocked = function(e, pos)
		SoundFX.PlayAt(if e.Parry then "Parry" else "BlockHit", pos)
	end,
	Heal = function(_e, pos)
		SoundFX.PlayAt("Heal", pos)
	end,
	LevelUp = function(e, pos)
		if isMine(e) then
			SoundFX.Play("LevelUp")
		else
			SoundFX.PlayAt("LevelUp", pos)
		end
	end,
}

local function onSkillFx(e)
	if typeof(e) ~= "table" or type(e.Type) ~= "string" then
		return
	end
	local position = eventPosition(e)
	local special = PLAYER_EVENTS[e.Type]
	if special then
		special(e, position)
		return
	end
	local skill = type(e.Skill) == "string" and Library.Skills[e.Skill]
	local entry = skill and skill[e.Type]
	if e.Type == "Cast" and e.Caster == player and os.clock() - (predicted[e.Skill] or 0) < 1 then
		predicted[e.Skill] = nil
		return -- already played locally the moment you cast
	end
	if entry and position then
		runEntry(entry, e, position)
	end
end

---------------------------------------------------------------------------
-- Enemies

local watched = {}
local lastCombat = -math.huge

local function enemyAlive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function enemyPosition(model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function watchEnemy(model)
	if watched[model] or not model:IsA("Model") then
		return
	end
	watched[model] = true

	local function onAttribute(name)
		local pos = enemyPosition(model)
		if not pos then
			return
		end
		if name == "HitAt" then
			SoundFX.PlayAt("EnemyHit", pos)
			if model:GetAttribute("DisplayName") ~= "Training Dummy" then
				lastCombat = os.clock()
			end
		elseif name == "AttackAt" then
			local at = model:GetAttribute("AttackAt")
			if type(at) ~= "number" then
				return
			end
			lastCombat = os.clock()
			SoundFX.PlayAt("HuskWindup", pos)
			task.delay(math.max(0, at - workspace:GetServerTimeNow()), function()
				local now = enemyPosition(model)
				if model.Parent and now and enemyAlive(model) then
					SoundFX.PlayAt("HuskSlam", now)
				end
			end)
		elseif name == "SpawnAt" then
			SoundFX.PlayAt("EnemySpawn", pos)
		elseif name == "ReactionAt" then
			local sound = Library.Reactions[model:GetAttribute("Reaction") or ""]
			if sound then
				SoundFX.PlayAt(sound, pos)
			end
		elseif name == "Status_Freeze" and model:GetAttribute("Status_Freeze") then
			SoundFX.PlayAt("Freeze", pos)
		end
	end
	model.AttributeChanged:Connect(onAttribute)

	-- The spawn attribute is usually set before the model reaches this client.
	local spawnAt = model:GetAttribute("SpawnAt")
	if type(spawnAt) == "number" and workspace:GetServerTimeNow() - spawnAt < 1 then
		onAttribute("SpawnAt")
	end

	local function hookHumanoid(hum)
		local dead = false
		hum.HealthChanged:Connect(function(health)
			if health <= 0 and not dead then
				dead = true
				local pos = enemyPosition(model)
				if pos then
					SoundFX.PlayAt("HuskDeath", pos)
				end
			end
		end)
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hookHumanoid(hum)
	else
		task.spawn(function()
			local h = model:WaitForChild("Humanoid", 10)
			if h then
				hookHumanoid(h)
			end
		end)
	end
	model.Destroying:Connect(function()
		watched[model] = nil
	end)
end

---------------------------------------------------------------------------
-- Local player

local function watchCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return
	end
	-- Hear the world from the character, not from the high top-down camera.
	SoundService:SetListener(Enum.ListenerType.ObjectPosition, root)

	local health = hum.Health
	local dead = false
	hum.HealthChanged:Connect(function(now)
		if now <= 0 then
			if not dead then
				dead = true
				SoundFX.Play("PlayerDeath")
			end
		elseif now < health - 0.5 then
			SoundFX.Play("PlayerHurt")
			lastCombat = os.clock()
		end
		health = now
	end)

	-- Controls.dash pushes the root with a LinearVelocity.
	root.ChildAdded:Connect(function(child)
		if child:IsA("LinearVelocity") then
			SoundFX.Play("Dash")
		end
	end)
end

local function watchStat(name, onUp, onDown)
	local last = player:GetAttribute(name)
	player:GetAttributeChangedSignal(name):Connect(function()
		local now = player:GetAttribute(name)
		if type(now) == "number" and type(last) == "number" then
			if now > last and onUp then
				SoundFX.Play(onUp)
			elseif now < last and onDown then
				SoundFX.Play(onDown)
			end
		end
		last = now
	end)
end

local function onNotify(text)
	if type(text) ~= "string" then
		return
	end
	if text:find("^Fused") then
		SoundFX.Play("Fuse")
	elseif text:find("^New skill") then
		SoundFX.Play("SkillGet")
	elseif text:find("is now level") then
		SoundFX.Play("SkillUp")
	elseif text:find("^%+%d+%s") and not text:find("Stat Point") then
		SoundFX.Play("ItemPickup")
	elseif text:find("refilled") then
		SoundFX.Play("Heal")
	elseif text:find("empty") or text:find("^Already") then
		SoundFX.Play("UIDeny")
	end
end

---------------------------------------------------------------------------
-- UI buttons

local function hookButton(button)
	if not button:IsA("GuiButton") or button:GetAttribute("Silent") then
		return
	end
	button.Activated:Connect(function()
		SoundFX.Play("UIClick")
	end)
	button.MouseEnter:Connect(function()
		SoundFX.Play("UIHover")
	end)
end

---------------------------------------------------------------------------
-- Music: exploring <-> combat

local function startMusic()
	local explore = start("MusicExplore", SoundService, true)
	local combat = start("MusicCombat", SoundService, true)
	start("AmbientRift", SoundService, true)
	if not explore or not combat then
		return
	end
	local exploreVolume = explore.Volume
	local combatVolume = combat.Volume
	combat.Volume = 0
	local inCombat = false
	task.spawn(function()
		while true do
			task.wait(0.5)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				for _, model in CollectionService:GetTagged(ENEMY_TAG) do
					local pos = enemyPosition(model)
					if
						pos
						and model:GetAttribute("DisplayName") ~= "Training Dummy"
						and enemyAlive(model)
						and (pos - root.Position).Magnitude < COMBAT_RADIUS
					then
						lastCombat = os.clock()
						break
					end
				end
			end
			local want = os.clock() - lastCombat < COMBAT_LINGER
			if want ~= inCombat then
				inCombat = want
				local info = TweenInfo.new(MUSIC_FADE)
				TweenService:Create(combat, info, { Volume = if want then combatVolume else 0 }):Play()
				TweenService:Create(explore, info, { Volume = if want then 0 else exploreVolume }):Play()
			end
		end
	end)
end

---------------------------------------------------------------------------

-- Loads every sound file into its template: short effects first, music last.
local function preload()
	local effects, long = {}, {}
	for _, def in Library.Sounds do
		for _, id in def.Ids or { def.Id } do
			local list = if def.Group == "Music" or def.Group == "Ambient" then long else effects
			table.insert(list, template(id))
		end
	end
	ContentProvider:PreloadAsync(effects)
	ContentProvider:PreloadAsync(long)
end

-- Plays your own cast sound the instant Controls starts the cast animation.
local function hookLocalCasts()
	local ok, CastAnimator = pcall(require, script.Parent:WaitForChild("CastAnimator", 5))
	if not ok or type(CastAnimator) ~= "table" or type(CastAnimator.Play) ~= "function" then
		return
	end
	local play = CastAnimator.Play
	CastAnimator.Play = function(character, skillId, ...)
		if character ~= nil and character == player.Character and type(skillId) == "string" then
			local skill = Library.Skills[skillId]
			local root = character:FindFirstChild("HumanoidRootPart")
			if skill and skill.Cast and root then
				predicted[skillId] = os.clock()
				pcall(runEntry, skill.Cast, {}, root.Position)
			end
		end
		return play(character, skillId, ...)
	end
end

function SoundFX.Init(Remotes)
	for name, volume in Library.GroupVolumes do
		local g = SoundService:FindFirstChild("Riftbound" .. name) or Instance.new("SoundGroup")
		g.Name = "Riftbound" .. name
		g.Volume = volume
		g.Parent = SoundService
		groups[name] = g
	end
	anchor = Instance.new("Part")
	anchor.Name = "RiftSounds"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new()
	anchor.Parent = workspace

	templateFolder = Instance.new("Folder")
	templateFolder.Name = "RiftboundSoundTemplates"
	templateFolder.Parent = SoundService
	task.spawn(preload)
	hookLocalCasts()

	Remotes:WaitForChild("SkillFx").OnClientEvent:Connect(function(e)
		local ok, err = pcall(onSkillFx, e)
		if not ok then
			warn("SoundFX", typeof(e) == "table" and e.Type, err)
		end
	end)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(onNotify)
	Remotes:WaitForChild("OpenForge").OnClientEvent:Connect(function()
		SoundFX.Play("ForgeOpen")
	end)

	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(watchEnemy)
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		watchEnemy(model)
	end

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	watchStat("Gold", "Coin")
	watchStat("Xp", "XpPickup")
	watchStat("FlaskCharges", nil, "FlaskDrink")
	watchStat("StatPoints", nil, "StatUp")

	local gui = player:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(hookButton)
	for _, d in gui:GetDescendants() do
		hookButton(d)
	end

	startMusic()
end

return SoundFX
