-- Playtest smoke test. Run in the Server datamodel during Play:
--   node tools/rbx.js luau @tools/tests/SkillSmokeTest.luau Server
-- Casts every skill at the training dummies (moved in front of the player),
-- reports the damage dealt, then checks fusion through BuildService.
-- Goes through ServerStorage.RiftboundDebug so it uses the live game modules
-- (requiring them here would give this script its own separate copies).
local Skills = require(game.ReplicatedStorage.Riftbound.Skills)
local Merge = require(game.ReplicatedStorage.Riftbound.Merge)
local Debug = game.ServerStorage:WaitForChild("RiftboundDebug")

local player = game.Players:GetPlayers()[1]
local root = player.Character.HumanoidRootPart
local out = {}

local function dummies()
	local list = {}
	for _, m in workspace.RiftEnemies:GetChildren() do
		if m.Name == "Training Dummy" and m.Humanoid.Health > 0 then
			m:SetAttribute("Regen", nil)
			table.insert(list, m)
		end
	end
	return list
end

local OFFSETS = { Vector3.new(0, 0, 0), Vector3.new(4, 0, -3), Vector3.new(-4, 0, 3) }

local function setup()
	for _, m in workspace.RiftEnemies:GetChildren() do
		if m.Name == "Rift Husk" then
			m.Humanoid.Health = 0
		end
	end
	local origin = root.Position
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z).Unit
	local target = Vector3.new(origin.X, origin.Y - 2.9, origin.Z) + dir * 12
	for i, m in dummies() do
		m.Humanoid.Health = m.Humanoid.MaxHealth
		m.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		m:PivotTo(CFrame.new(target + OFFSETS[i] + Vector3.new(0, 2, 0)))
	end
	return target
end

local function damageTaken()
	local sum = 0
	for _, m in dummies() do
		sum += m.Humanoid.MaxHealth - m.Humanoid.Health
	end
	return sum
end

local ids = {}
for id in Skills.Defs do
	table.insert(ids, id)
end
table.sort(ids)

local failures = 0
for _, id in ids do
	local target = setup()
	task.wait(0.3)
	local ok, err = pcall(Debug.Invoke, Debug, "Cast", player, id, 1, target)
	task.wait(if Skills.Defs[id].Kind == "Zone" then 2.2 else 1.2)
	local dmg = damageTaken()
	if dmg <= 0 or not ok then
		failures += 1
	end
	table.insert(out, string.format("%-13s %-10s dmg=%d %s", id, Skills.Defs[id].Kind, dmg, if ok then "" else "ERR " .. tostring(err)))
end
setup()

Debug:Invoke("Grant", player, "Fireball")
Debug:Invoke("Grant", player, "Fireball")
Debug:Invoke("Grant", player, "TidalWave")
local ok, result = Debug:Invoke("Merge", player, "Fireball", "TidalWave")
local snap = Debug:Invoke("Snapshot", player)
table.insert(out, `merge Fireball+TidalWave -> ok={ok} result={result} level={snap.Skills[result]} Q={snap.Slots.Q} E={snap.Slots.E}`)
table.insert(out, `consumed inputs: {snap.Skills.Fireball == nil and snap.Skills.TidalWave == nil}`)
local bad = Debug:Invoke("Merge", player, "SteamCloud", "Gust")
table.insert(out, `fused+base merge rejected: {not bad}`)
local count = 0
for _ in Merge.All() do
	count += 1
end
table.insert(out, `recipes: {count}`)
table.insert(out, `skills with no damage: {failures}`)
return table.concat(out, "\n")
