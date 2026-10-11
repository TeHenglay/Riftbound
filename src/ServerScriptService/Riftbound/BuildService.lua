-- Each player's skill build: owned skills with levels, equipped slots,
-- cooldowns, fusion, and this run's runes. The server is the only source of
-- truth. Runes live only in memory: sockets start empty each run and are
-- wiped when it ends (see Runes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Merge = require(Shared:WaitForChild("Merge"))
local Nations = require(Shared:WaitForChild("Nations"))
local Runes = require(Shared:WaitForChild("Runes"))
local Skills = require(Shared:WaitForChild("Skills"))
local StatService = require(script.Parent.StatService)

local SLOTS = { "Q", "E" }
local BASIC_ATTACK = "RiftBolt"
local COOLDOWN_TOLERANCE = 0.1 -- allow for network jitter against the client's own timer

local BuildService = {}

-- Set by Main to push updates to clients.
BuildService.OnChanged = function(_player) end
BuildService.OnNotify = function(_player, _text, _color) end

local builds = {}

-- Grants the player's chosen Nation home skill into slot Q.
function BuildService.GrantHomeSkill(player, nationId)
	local b = builds[player]
	if not b or not nationId then
		return nil
	end
	local skillId = Nations.HomeSkillOf(nationId)
	if not skillId or not Skills.Defs[skillId] then
		return nil
	end
	-- Given once per player (saved), so fusing it away doesn't bring it back on rejoin.
	if b.HomeGranted then
		return skillId
	end
	b.HomeGranted = true
	if not b.Skills[skillId] then
		b.Skills[skillId] = 1
		if not b.Slots["Q"] then
			b.Slots["Q"] = skillId
		elseif not b.Slots["E"] then
			b.Slots["E"] = skillId
		end
		local def = Skills.Defs[skillId]
		BuildService.OnNotify(player, `Mastered Signature Skill: {def.Name}`, Elements.ColorOf(def.Elements))
		BuildService.OnChanged(player)
		return skillId
	elseif not b.Slots["Q"] and not b.Slots["E"] then
		b.Slots["Q"] = skillId
		BuildService.OnChanged(player)
		return skillId
	end
	return skillId
end

function BuildService.Init(player)
	-- Temp: skills lent for Training (shrines, the Forge's free test equip).
	-- They're never saved and are taken back when the player leaves Training.
	builds[player] = { Skills = {}, Copies = {}, Temp = {}, Slots = {}, Cooldowns = {}, Sockets = {}, Pouch = {} }

	-- If the player already has a Nation attribute (rejoining player)
	local currentNation = player:GetAttribute("Nation")
	if currentNation then
		BuildService.GrantHomeSkill(player, currentNation)
	end

	-- Listen for when the player picks a nation from the select screen
	player:GetAttributeChangedSignal("Nation"):Connect(function()
		local nation = player:GetAttribute("Nation")
		if nation then
			BuildService.GrantHomeSkill(player, nation)
		end
	end)
end

function BuildService.Remove(player)
	builds[player] = nil
end

-- Saving (SaveService): owned skills and levels, equipped slots and whether
-- the home skill was given. Runes and cooldowns are never saved.
function BuildService.Export(player)
	local b = builds[player]
	if not b then
		return nil
	end
	-- Training skills are left out; their slots save what was there before.
	local skills, copies, slots = {}, {}, {}
	for id, level in b.Skills do
		if not b.Temp[id] then
			skills[id] = level
			copies[id] = b.Copies[id]
		end
	end
	for _, slot in SLOTS do
		local id = b.Slots[slot]
		if id and b.Temp[id] then
			id = b.SavedSlots and b.SavedSlots[slot]
		end
		slots[slot] = if id and skills[id] then id else nil
	end
	return { Skills = skills, Copies = copies, Slots = slots, HomeGranted = b.HomeGranted == true }
end

function BuildService.Import(player, saved)
	local b = builds[player]
	if not b or type(saved) ~= "table" then
		return
	end
	table.clear(b.Skills)
	table.clear(b.Copies)
	table.clear(b.Slots)
	for id, level in type(saved.Skills) == "table" and saved.Skills or {} do
		level = math.floor(tonumber(level) or 0)
		if Skills.Defs[id] and id ~= BASIC_ATTACK and level >= 1 then
			b.Skills[id] = math.min(level, Skills.MaxLevel)
		end
	end
	for id, count in type(saved.Copies) == "table" and saved.Copies or {} do
		count = math.floor(tonumber(count) or 0)
		if b.Skills[id] and count > 0 then
			b.Copies[id] = count
		end
	end
	for _, slot in SLOTS do
		local id = type(saved.Slots) == "table" and saved.Slots[slot]
		if id and b.Skills[id] then
			b.Slots[slot] = id
		end
	end
	b.HomeGranted = saved.HomeGranted == true or next(b.Skills) ~= nil
	BuildService.OnChanged(player)
end

function BuildService.Snapshot(player)
	local b = builds[player]
	if not b then
		return { Skills = {}, Copies = {}, Temp = {}, Slots = {}, Sockets = {}, Pouch = {} }
	end
	local sockets = {}
	for skillId, list in b.Sockets do
		sockets[skillId] = table.clone(list)
	end
	local offer = b.Offer and { Ids = table.clone(b.Offer.Ids), Ends = b.Offer.Ends }
	return { Skills = table.clone(b.Skills), Copies = table.clone(b.Copies), Temp = table.clone(b.Temp), Slots = table.clone(b.Slots), Sockets = sockets, Pouch = table.clone(b.Pouch), Offer = offer }
end

-------------------------------------------------------------------------------
-- Runes (this run only)
-------------------------------------------------------------------------------

-- Sockets are keyed by skill id ("RiftBolt" for LMB), so runes follow the
-- skill wherever it is equipped.
local function skillAt(b, slot)
	if slot == "M1" then
		return BASIC_ATTACK
	end
	return b.Slots[slot]
end

local function socketsFor(b, skillId)
	local list = b.Sockets[skillId]
	if not list then
		list = {}
		b.Sockets[skillId] = list
	end
	return list
end

-- Empties every socket, the pouch and any open offer: called when a run
-- starts and ends.
function BuildService.ResetRunes(player)
	local b = builds[player]
	if not b then
		return
	end
	local had = next(b.Pouch) ~= nil or next(b.Sockets) ~= nil or b.Offer ~= nil
	table.clear(b.Sockets)
	table.clear(b.Pouch)
	b.Offer = nil
	if had then
		BuildService.OnChanged(player)
	end
end

-- Drops a rune straight into the pouch, waiting for the player to socket it.
function BuildService.GrantRune(player, id)
	local b = builds[player]
	if not b or not Runes.Defs[id] then
		return
	end
	table.insert(b.Pouch, id)
	local def = Runes.Defs[id]
	BuildService.OnNotify(player, `Rune found: {def.Name}`, Runes.Rarity[def.Rarity].Color)
	BuildService.OnChanged(player)
end

-- Offers a pick of `ids` (3 runes) until `seconds` pass.
function BuildService.OfferRunes(player, ids, seconds)
	local b = builds[player]
	if not b then
		return
	end
	b.Offer = { Ids = ids, Ends = workspace:GetServerTimeNow() + seconds }
	BuildService.OnChanged(player)
end

function BuildService.HasOffer(player)
	local b = builds[player]
	return b ~= nil and b.Offer ~= nil
end

-- Takes offered rune `index`, socketing it into the skill in `slot` (or into
-- the pouch when slot is nil). Returns ok, message.
function BuildService.ChooseRune(player, index, slot)
	local b = builds[player]
	local id = b and b.Offer and b.Offer.Ids[index]
	if not id then
		return false, "No rune to choose"
	end
	if slot then
		local skillId = skillAt(b, slot)
		if not skillId then
			return false, "No skill in that slot"
		end
		local list = socketsFor(b, skillId)
		local ok, why = Runes.CanSocket(list, id)
		if not ok then
			return false, why
		end
		table.insert(list, id)
	else
		table.insert(b.Pouch, id)
	end
	b.Offer = nil
	BuildService.OnChanged(player)
	return true
end

-- Time ran out: a random offered rune goes to the pouch.
function BuildService.ResolveOffer(player)
	local b = builds[player]
	if not b or not b.Offer then
		return
	end
	local ids = b.Offer.Ids
	local id = ids[math.random(1, #ids)]
	b.Offer = nil
	table.insert(b.Pouch, id)
	BuildService.OnNotify(player, `Time's up: {Runes.Defs[id].Name} went to your pouch (B)`, Runes.Rarity[Runes.Defs[id].Rarity].Color)
	BuildService.OnChanged(player)
end

-- Moves pouch rune `index` into the skill in `slot`. Returns ok, message.
function BuildService.Socket(player, index, slot)
	local b = builds[player]
	local skillId = b and skillAt(b, slot)
	local id = b and b.Pouch[index]
	if not skillId or not id then
		return false, "Invalid request"
	end
	local list = socketsFor(b, skillId)
	local ok, why = Runes.CanSocket(list, id)
	if not ok then
		return false, why
	end
	table.remove(b.Pouch, index)
	table.insert(list, id)
	BuildService.OnChanged(player)
	return true
end

-- Takes the rune in socket `index` of `skillId` back to the pouch.
function BuildService.Unsocket(player, skillId, index)
	local b = builds[player]
	local list = b and b.Sockets[skillId]
	if not list or not list[index] then
		return false, "Invalid request"
	end
	table.insert(b.Pouch, table.remove(list, index))
	BuildService.OnChanged(player)
	return true
end

-- Endless Cascade: the skill is ready again right away.
function BuildService.ResetCooldown(player, id)
	local b = builds[player]
	if b then
		b.Cooldowns[id] = nil
	end
end

local function firstFreeSlot(b)
	for _, slot in SLOTS do
		if not b.Slots[slot] then
			return slot
		end
	end
	return nil
end

-- Adds one duplicate copy of an owned skill (spent on levels). Returns the
-- new copy count.
local function addCopy(player, b, id)
	local def = Skills.Defs[id]
	b.Copies[id] = (b.Copies[id] or 0) + 1
	local need = Skills.CopiesToLevel(b.Skills[id])
	local have = b.Copies[id]
	local hint = if not need then "" elseif have >= need then "  ·  ready to level up (B)" else `  ·  {have}/{need} to level up`
	BuildService.OnNotify(player, `+1 {def.Name} copy{hint}`, Elements.ColorOf(def.Elements))
	return have
end

-- Gives a skill; a skill you already own adds a duplicate copy instead.
-- With `temp`, the skill is only lent for Training (see ClearTemp) and an
-- owned skill gains nothing. Returns the skill's level, and whether it was a copy.
function BuildService.Grant(player, id, temp)
	local b = builds[player]
	local def = Skills.Defs[id]
	if not b or not def or id == BASIC_ATTACK then
		return nil
	end
	local level = b.Skills[id]
	if temp then
		if level then
			return level, false
		end
		if next(b.Temp) == nil then
			b.SavedSlots = table.clone(b.Slots) -- put back when Training ends
		end
		b.Temp[id] = true
		b.Skills[id] = 1
		local slot = firstFreeSlot(b)
		if slot then
			b.Slots[slot] = id
		end
		BuildService.OnNotify(player, `Training skill: {def.Name} (until you leave)`, Elements.ColorOf(def.Elements))
		BuildService.OnChanged(player)
		return 1, false
	end
	if level and b.Temp[id] then
		-- A real copy of a skill you were only borrowing: now it's yours.
		b.Temp[id] = nil
		BuildService.OnNotify(player, `New skill: {def.Name}`, Elements.ColorOf(def.Elements))
		BuildService.OnChanged(player)
		return level, false
	end
	if level then
		addCopy(player, b, id)
		BuildService.OnChanged(player)
		return level, true
	end
	b.Skills[id] = 1
	local slot = firstFreeSlot(b)
	if slot then
		b.Slots[slot] = id
	end
	BuildService.OnNotify(player, `New skill: {def.Name}`, Elements.ColorOf(def.Elements))
	BuildService.OnChanged(player)
	return 1, false
end

function BuildService.Owns(player, id)
	local b = builds[player]
	return b ~= nil and b.Skills[id] ~= nil
end

function BuildService.IsTemp(player, id)
	local b = builds[player]
	return b ~= nil and b.Temp[id] == true
end

-- Takes back every Training skill and puts the slots back the way they were.
function BuildService.ClearTemp(player)
	local b = builds[player]
	if not b or next(b.Temp) == nil then
		return
	end
	for id in b.Temp do
		b.Skills[id] = nil
		b.Copies[id] = nil
		b.Sockets[id] = nil
		b.Cooldowns[id] = nil
	end
	table.clear(b.Temp)
	local saved = b.SavedSlots or {}
	b.SavedSlots = nil
	for _, slot in SLOTS do
		local id = b.Slots[slot]
		if not id or not b.Skills[id] then
			b.Slots[slot] = nil
			local back = saved[slot]
			if back and b.Skills[back] and b.Slots.Q ~= back and b.Slots.E ~= back then
				b.Slots[slot] = back
			end
		end
	end
	-- Anything still empty gets another owned skill.
	for _, slot in SLOTS do
		if not b.Slots[slot] then
			for id in b.Skills do
				if b.Slots.Q ~= id and b.Slots.E ~= id then
					b.Slots[slot] = id
					break
				end
			end
		end
	end
	BuildService.OnNotify(player, "Training skills returned", Color3.fromRGB(200, 190, 220))
	BuildService.OnChanged(player)
end

-- Spends duplicate copies to raise a skill one level (Skills.LevelCost).
-- Returns ok, message.
function BuildService.LevelUp(player, id)
	local b = builds[player]
	local def = typeof(id) == "string" and Skills.Defs[id]
	if not b or not def or not b.Skills[id] then
		return false, "You don't own that skill"
	end
	if b.Temp[id] then
		return false, "Training skills can't be levelled"
	end
	local level = b.Skills[id]
	local need = Skills.CopiesToLevel(level)
	if not need then
		return false, "Already max level"
	end
	local have = b.Copies[id] or 0
	if have < need then
		return false, `Need {need} copies ({have}/{need})`
	end
	b.Copies[id] = if have - need > 0 then have - need else nil
	b.Skills[id] = level + 1
	BuildService.OnNotify(player, `{def.Name} is now level {level + 1}`, Elements.ColorOf(def.Elements))
	BuildService.OnChanged(player)
	return true, level + 1
end

function BuildService.Equip(player, slot, id)
	local b = builds[player]
	if not b or not table.find(SLOTS, slot) or not b.Skills[id] then
		return
	end
	for _, other in SLOTS do
		if other ~= slot and b.Slots[other] == id then
			b.Slots[other] = b.Slots[slot]
		end
	end
	b.Slots[slot] = id
	BuildService.OnChanged(player)
end

-- Fuses two owned base skills. Both are consumed; the result
-- starts at level 1 (or, if you already own it, keeps its level and gains a
-- duplicate copy).
function BuildService.Merge(player, idA, idB)
	local b = builds[player]
	if not b or typeof(idA) ~= "string" or typeof(idB) ~= "string" then
		return false, "Invalid request"
	end
	if not b.Skills[idA] or not b.Skills[idB] then
		return false, "You don't own both skills"
	end
	if b.Temp[idA] or b.Temp[idB] then
		return false, "Training skills can't be fused"
	end
	local result = Merge.Result(idA, idB)
	if not result then
		return false, "Those skills can't be fused"
	end

	-- A new fusion starts at level 1; fusing one you already own keeps its
	-- level and adds a duplicate copy of it.
	local level = Merge.ResultLevel(b.Skills[idA], b.Skills[idB])
	local existing = b.Skills[result]
	if existing then
		level = math.max(existing, level)
		b.Copies[result] = (b.Copies[result] or 0) + 1
	end

	local freed = nil
	for _, slot in SLOTS do
		if b.Slots[slot] == idA or b.Slots[slot] == idB then
			b.Slots[slot] = nil
			freed = freed or slot
		end
	end
	b.Skills[idA] = nil
	b.Skills[idB] = nil
	b.Copies[idA] = nil -- spare copies go with the consumed skills
	b.Copies[idB] = nil
	-- Runes on the consumed skills go back to the pouch.
	for _, gone in { idA, idB } do
		for _, rune in b.Sockets[gone] or {} do
			table.insert(b.Pouch, rune)
		end
		b.Sockets[gone] = nil
	end
	b.Skills[result] = level

	local alreadyEquipped = false
	for _, slot in SLOTS do
		if b.Slots[slot] == result then
			alreadyEquipped = true
		end
	end
	if not alreadyEquipped then
		local slot = freed or firstFreeSlot(b)
		if slot then
			b.Slots[slot] = result
		end
	end

	local def = Skills.Defs[result]
	BuildService.OnNotify(player, `Fused: {def.Name}!`, Elements.ColorOf(def.Elements))
	BuildService.OnChanged(player)
	return true, result
end

-- Ascends a base or fused skill into its Awakened form. Preserves level, equipped slot,
-- and socketed runes.
function BuildService.Awaken(player, baseSkillId, awakenedId)
	local b = builds[player]
	if not b or typeof(baseSkillId) ~= "string" or typeof(awakenedId) ~= "string" then
		return false, "Invalid request"
	end
	if not b.Skills[baseSkillId] then
		return false, "Base skill not owned"
	end
	if b.Temp[baseSkillId] then
		return false, "Training skills can't be awakened"
	end
	if not Skills.Defs[awakenedId] then
		return false, "Unknown awakened skill"
	end

	local level = b.Skills[baseSkillId]
	b.Skills[awakenedId] = level
	b.Skills[baseSkillId] = nil
	-- Spare copies carry over to the awakened skill.
	b.Copies[awakenedId] = (b.Copies[awakenedId] or 0) + (b.Copies[baseSkillId] or 0)
	if b.Copies[awakenedId] == 0 then
		b.Copies[awakenedId] = nil
	end
	b.Copies[baseSkillId] = nil

	-- Preserve equipped slot
	for _, slot in SLOTS do
		if b.Slots[slot] == baseSkillId then
			b.Slots[slot] = awakenedId
		end
	end

	-- Move runes over to the awakened skill
	if b.Sockets[baseSkillId] then
		b.Sockets[awakenedId] = b.Sockets[baseSkillId]
		b.Sockets[baseSkillId] = nil
	end

	local def = Skills.Defs[awakenedId]
	BuildService.OnNotify(player, `ASCENDED: {def.Name}!`, Color3.fromRGB(110, 225, 255))
	BuildService.OnChanged(player)
	return true, awakenedId
end

-- Checks the slot and cooldown. Returns the skill id, level and the skill's
-- rune mods to cast with, or nil.
function BuildService.TryCast(player, slot)
	local b = builds[player]
	if not b then
		return nil
	end
	local id, level
	if slot == "M1" then
		id, level = BASIC_ATTACK, 1
	else
		id = b.Slots[slot]
		level = id and b.Skills[id]
	end
	if not id or not level then
		return nil
	end
	local now = os.clock()
	if now < (b.Cooldowns[id] or 0) then
		return nil
	end
	local runes = b.Sockets[id]
	b.Cooldowns[id] = now + Skills.CooldownOf(id, level) * StatService.CooldownMult(player) * Runes.CooldownMult(runes) - COOLDOWN_TOLERANCE
	return id, level, Runes.Mods(runes)
end

return BuildService
