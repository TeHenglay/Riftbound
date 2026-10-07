-- Client-side procedural animation for jointed enemies (the Rift Husk rig:
-- Motor6Ds Rig_Body, Rig_ArmL, Rig_ArmR, Rig_LegL, Rig_LegR).
--   Walk: alternating leg steps driven by actual ground speed (no foot slide),
--         arms swinging opposite the legs, torso twist/roll and a forward lean.
--   Idle: breathing and a slow arm sway.
--   Attack: arms raised overhead while leaning back (the red windup), then a
--         two-handed slam with a forward lunge, a short hold and a recovery.
--   Hit flinch + white flash, stun shake, spawn rise and a death slump.
-- The server drives it with model attributes: AttackAt, HitAt, SpawnAt
-- (server times) and Stunned. Motor6D.Transform is local to each client, so
-- this costs the server nothing.
--
-- Rig-space convention: every joint pivot faces the rig's front (-Z). For a
-- hanging limb a positive pitch swings it forward; for the torso a negative
-- pitch leans it forward.
local RunService = game:GetService("RunService")

local WINDUP = 0.4 -- must match Enemies.lua ATTACK_WINDUP
local STRIKE = 0.14
local HOLD = 0.16
local RECOVER = 0.35
local STRIDE = 0.5 -- leg-cycle radians per stud travelled
local WINDUP_COLOR = Color3.fromRGB(255, 60, 70)
local JOINTS = { "Body", "ArmL", "ArmR", "LegL", "LegR" }

local EnemyAnimator = {}

local rigs = {} -- [model] = { Motors, Root, Highlight, Phase, Walk, Speed, DiedAt }

local function easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function easeIn(x)
	x = math.clamp(x, 0, 1)
	return x * x
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function pose()
	local p = {}
	for _, j in JOINTS do
		p[j] = { Pitch = 0, Roll = 0, Yaw = 0, Y = 0, Z = 0 }
	end
	return p
end

local function blend(a, b, w)
	local out = pose()
	for _, j in JOINTS do
		for k in out[j] do
			out[j][k] = a[j][k] + (b[j][k] - a[j][k]) * w
		end
	end
	return out
end

local function track(model)
	if rigs[model] then
		return
	end
	local motors = {}
	for _, j in JOINTS do
		local m = model:FindFirstChild("Rig_" .. j, true)
		if not m then
			return
		end
		motors[j] = m
	end
	-- Reuse the highlight if this enemy is being re-tracked after streaming.
	local highlight = model:FindFirstChild("AnimatorHighlight") or Instance.new("Highlight")
	highlight.Name = "AnimatorHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	rigs[model] = {
		Motors = motors,
		Root = model:FindFirstChild("HumanoidRootPart"),
		Highlight = highlight,
		Phase = math.random() * 10,
		Walk = 0,
		Speed = 0,
	}
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

-- Walking / idle pose.
local function locomotion(rig, t, dt)
	local v = rig.Root.AssemblyLinearVelocity
	local ground = Vector3.new(v.X, 0, v.Z).Magnitude
	rig.Walk += ground * dt * STRIDE
	-- Smoothed 0..1 "how much are we walking", so starts and stops blend.
	rig.Speed += (math.min(ground / 9, 1) - rig.Speed) * math.min(dt * 8, 1)
	local s, w = rig.Speed, rig.Walk
	local breathe = math.sin(t * 1.8)

	local p = pose()
	p.LegL.Pitch = math.sin(w) * 0.6 * s
	p.LegR.Pitch = -math.sin(w) * 0.6 * s
	p.LegL.Y = math.max(0, math.cos(w)) * 0.15 * s -- lift the swinging foot a little
	p.LegR.Y = math.max(0, -math.cos(w)) * 0.15 * s

	p.ArmL.Pitch = -math.sin(w) * 0.45 * s + 0.06 * breathe * (1 - s)
	p.ArmR.Pitch = math.sin(w) * 0.45 * s + 0.06 * math.sin(t * 1.8 + 0.7) * (1 - s)
	p.ArmL.Roll = -0.05 - 0.03 * breathe * (1 - s)
	p.ArmR.Roll = 0.05 + 0.03 * breathe * (1 - s)

	p.Body.Pitch = -0.16 * s - 0.03 + 0.03 * breathe * (1 - s)
	p.Body.Roll = math.sin(w) * 0.06 * s
	p.Body.Yaw = math.sin(w) * 0.1 * s
	p.Body.Y = math.cos(2 * w) * 0.07 * s + 0.04 * breathe * (1 - s)
	return p
end

-- Two-handed overhead slam. `dt` is time relative to AttackAt (the strike).
local function attackPose(dt)
	local p = pose()
	local raised = pose()
	raised.ArmL.Pitch, raised.ArmR.Pitch = 2.6, 2.6
	raised.ArmL.Roll, raised.ArmR.Roll = -0.25, 0.25
	raised.Body.Pitch, raised.Body.Y = 0.3, 0.2
	raised.LegL.Pitch, raised.LegR.Pitch = -0.15, 0.25

	local slammed = pose()
	slammed.ArmL.Pitch, slammed.ArmR.Pitch = 0.55, 0.55
	slammed.ArmL.Roll, slammed.ArmR.Roll = 0.08, -0.08
	slammed.Body.Pitch, slammed.Body.Y, slammed.Body.Z = -0.5, -0.25, -0.6
	slammed.LegL.Pitch, slammed.LegR.Pitch = 0.35, -0.25

	if dt < 0 then
		return blend(p, raised, easeOut((dt + WINDUP) / WINDUP))
	elseif dt < STRIKE then
		return blend(raised, slammed, easeIn(dt / STRIKE))
	end
	return slammed
end

local function apply(rig, p, shake)
	for _, j in JOINTS do
		local q = p[j]
		rig.Motors[j].Transform = CFrame.new(0, q.Y, q.Z) * CFrame.Angles(q.Pitch, q.Yaw, q.Roll + (shake or 0))
	end
end

local function step(dt)
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, rig in rigs do
		if not model.Parent or not rig.Root or not rig.Root.Parent then
			rigs[model] = nil
			continue
		end
		local t = clock + rig.Phase
		local hum = model:FindFirstChildOfClass("Humanoid")
		local alive = hum ~= nil and hum.Health > 0
		local p = locomotion(rig, t, dt)
		local fill, fillColor = 1, Color3.new(1, 1, 1)

		-- Attack: blend in the slam, then recover back to locomotion.
		local attackAt = model:GetAttribute("AttackAt")
		if attackAt and alive then
			local a = now - attackAt
			if a >= -WINDUP and a < STRIKE + HOLD then
				p = blend(p, attackPose(a), 1)
				if a < 0 then
					local k = easeOut((a + WINDUP) / WINDUP)
					fill, fillColor = 1 - 0.55 * k, WINDUP_COLOR
				end
			elseif a >= STRIKE + HOLD and a < STRIKE + HOLD + RECOVER then
				p = blend(p, attackPose(a), 1 - smooth((a - STRIKE - HOLD) / RECOVER))
			end
		end

		-- Hit: flinch back and flash white.
		local hitAt = model:GetAttribute("HitAt")
		if hitAt and now - hitAt < 0.2 then
			local k = 1 - (now - hitAt) / 0.2
			p.Body.Pitch += 0.25 * k
			p.Body.Z += 0.3 * k
			p.ArmL.Pitch -= 0.3 * k
			p.ArmR.Pitch -= 0.3 * k
			fill = math.min(fill, 1 - 0.75 * k)
			fillColor = Color3.new(1, 1, 1)
		end

		-- Spawn: rise out of the floor.
		local spawnAt = model:GetAttribute("SpawnAt")
		if spawnAt and now - spawnAt < 0.8 then
			local drop = 5 * (1 - easeOut((now - spawnAt) / 0.8))
			for _, j in { "Body", "LegL", "LegR" } do
				p[j].Y -= drop
			end
		end

		-- Death: slump forward, arms dropping.
		if not alive then
			rig.DiedAt = rig.DiedAt or clock
			local k = easeOut((clock - rig.DiedAt) / 0.45)
			local slump = pose()
			slump.Body.Pitch, slump.Body.Y = -0.9, -0.8
			slump.ArmL.Pitch, slump.ArmR.Pitch = 0.9, 0.9
			slump.LegL.Pitch, slump.LegR.Pitch = 0.4, -0.2
			p = blend(p, slump, k)
		end

		if alive and model:GetAttribute("Status_Freeze") then
			-- Frozen solid: hold the last pose, tinted ice blue.
			rig.Highlight.FillTransparency = 0.45
			rig.Highlight.FillColor = Color3.fromRGB(170, 225, 255)
			continue
		end

		local shake
		if alive and model:GetAttribute("Stunned") then
			shake = math.sin(clock * 40) * 0.04
		end

		apply(rig, p, shake)
		rig.Highlight.FillTransparency = fill
		rig.Highlight.FillColor = fillColor
	end
end

function EnemyAnimator.Init()
	local folder = workspace:WaitForChild("RiftEnemies")
	-- Workspace streaming can deliver joints late (or replace them when an
	-- enemy streams out and back in), so rescan instead of waiting once.
	task.spawn(function()
		while true do
			for _, model in folder:GetChildren() do
				local rig = rigs[model]
				if rig and not rig.Motors.Body.Parent then
					rigs[model] = nil
				end
				if not rigs[model] and model:FindFirstChild("Rig_LegR", true) and model:FindFirstChild("Rig_Body", true) then
					track(model)
				end
			end
			task.wait(0.5)
		end
	end)
	RunService.PreSimulation:Connect(step)
end

return EnemyAnimator
