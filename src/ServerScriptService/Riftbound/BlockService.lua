-- Block (right mouse, hold): a rift shield forms around the player and stops
-- enemy attacks. You move at half speed while it is up.
--   The shield holds for GUARD_TIME, then breaks (long cooldown).
--   Lowering it starts a short cooldown.
--   Perfect block: an attack that lands within PARRY_WINDOW of raising the
--   shield is parried, stunning the attacker and knocking it back.
-- Published to clients as player attributes Blocking (true while up) and
-- BlockReadyAt (server time the shield can be raised again); visuals go
-- through the SkillFx remote (Shield, Blocked).
local Enemies = require(script.Parent.Enemies)

local GUARD_TIME = 3
local COOLDOWN = 0.6
local BREAK_COOLDOWN = 3
local PARRY_WINDOW = 0.3
local SLOW = 0.5

local BlockService = {}

local states = {} -- [player] = { Raised, Since, ReadyAt, Speed, Token }

local function fx(payload)
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Riftbound"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SkillFx")
	if remote then
		remote:FireAllClients(payload)
	end
end

local function parts(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root
	end
	return nil, nil
end

local function lower(player, broken)
	local st = states[player]
	if not st or not st.Raised then
		return
	end
	st.Raised = false
	local hum, root = parts(player)
	if hum and st.Speed then
		hum.WalkSpeed = st.Speed
	end
	local cooldown = if broken then BREAK_COOLDOWN else COOLDOWN
	st.ReadyAt = os.clock() + cooldown
	player:SetAttribute("Blocking", nil)
	player:SetAttribute("BlockReadyAt", workspace:GetServerTimeNow() + cooldown)
	if root then
		fx({ Type = "Shield", Target = root, Up = false, Broken = broken })
	end
end

-- Raise (on = true) or lower the shield.
function BlockService.Set(player, on)
	local st = states[player]
	if not st then
		st = { Raised = false, ReadyAt = 0, Token = 0 }
		states[player] = st
	end
	if not on then
		lower(player, false)
		return
	end
	local hum, root = parts(player)
	if st.Raised or os.clock() < st.ReadyAt or not hum then
		return
	end
	st.Raised = true
	st.Since = os.clock()
	st.Token += 1
	st.Speed = hum.WalkSpeed
	hum.WalkSpeed = st.Speed * SLOW
	player:SetAttribute("Blocking", true)
	fx({ Type = "Shield", Target = root, Up = true, GuardTime = GUARD_TIME })
	local token = st.Token
	task.delay(GUARD_TIME, function()
		if st.Raised and st.Token == token then
			lower(player, true)
		end
	end)
end

-- Called by Enemies when an attack would hit this player. Returns true if the
-- shield stopped it.
function BlockService.TryBlock(player, attacker)
	local st = states[player]
	local _, root = parts(player)
	if not st or not st.Raised or not root then
		return false
	end
	local parry = os.clock() - st.Since <= PARRY_WINDOW
	local from = attacker.PrimaryPart and attacker.PrimaryPart.Position or root.Position
	fx({ Type = "Blocked", Target = root, From = from, Parry = parry })
	if parry then
		Enemies.ApplyStatus(attacker, "Stun", { Duration = 1.2 })
		local away = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
		if away.Magnitude > 0.1 then
			Enemies.Push(attacker, away.Unit * 45, 0.25)
		end
	end
	return true
end

function BlockService.Remove(player)
	states[player] = nil
end

function BlockService.Reset(player)
	local st = states[player]
	if st then
		st.Raised = false
		st.ReadyAt = 0
	end
	player:SetAttribute("Blocking", nil)
end

Enemies.BlockCheck = BlockService.TryBlock

return BlockService
