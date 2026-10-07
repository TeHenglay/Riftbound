-- Each player's skill build: owned skills with levels, equipped slots,
-- cooldowns, and fusion. The server is the only source of truth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Merge = require(Shared:WaitForChild("Merge"))
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

function BuildService.Init(player)
	builds[player] = { Skills = {}, Slots = {}, Cooldowns = {} }
end

function BuildService.Remove(player)
	builds[player] = nil
end

function BuildService.Snapshot(player)
	local b = builds[player]
	if not b then
		return { Skills = {}, Slots = {} }
	end
	return { Skills = table.clone(b.Skills), Slots = table.clone(b.Slots) }
end

local function firstFreeSlot(b)
	for _, slot in SLOTS do
		if not b.Slots[slot] then
			return slot
		end
	end
	return nil
end

-- Gives a skill, or levels it up if already owned. Returns the new level.
function BuildService.Grant(player, id)
	local b = builds[player]
	local def = Skills.Defs[id]
	if not b or not def or id == BASIC_ATTACK then
		return nil
	end
	local level = b.Skills[id]
	if level then
		level = math.min(level + 1, Skills.MaxLevel)
		BuildService.OnNotify(player, `{def.Name} is now level {level}`, Elements.ColorOf(def.Elements))
	else
		level = 1
		local slot = firstFreeSlot(b)
		if slot then
			b.Slots[slot] = id
		end
		BuildService.OnNotify(player, `New skill: {def.Name}`, Elements.ColorOf(def.Elements))
	end
	b.Skills[id] = level
	BuildService.OnChanged(player)
	return level
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

-- Fuses two owned base skills. Both are consumed; the result keeps the
-- higher level (or gains a level if you already own it).
function BuildService.Merge(player, idA, idB)
	local b = builds[player]
	if not b or typeof(idA) ~= "string" or typeof(idB) ~= "string" then
		return false, "Invalid request"
	end
	if not b.Skills[idA] or not b.Skills[idB] then
		return false, "You don't own both skills"
	end
	local result = Merge.Result(idA, idB)
	if not result then
		return false, "Those skills can't be fused"
	end

	local level = Merge.ResultLevel(b.Skills[idA], b.Skills[idB])
	local existing = b.Skills[result]
	if existing then
		level = math.min(math.max(existing, level) + 1, Skills.MaxLevel)
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

-- Checks the slot and cooldown. Returns the skill id and level to cast, or nil.
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
	b.Cooldowns[id] = now + Skills.CooldownOf(id, level) * StatService.CooldownMult(player) - COOLDOWN_TOLERANCE
	return id, level
end

return BuildService
