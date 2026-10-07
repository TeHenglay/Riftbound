-- Procedural cast animations for player characters (R15, with either Motor6D
-- or AnimationConstraint joints). Each skill kind has a two-keyframe move
-- (windup -> release) that is blended over the normal walk/idle animation, so
-- you can still move while casting. The casting hand(s) glow in the skill's
-- colour. Played locally for your own casts (instant) and from the server's
-- Cast effect event for other players.
--
-- Joint space convention (R15 rig attachments face the character's front,
-- -Z): for a hanging arm, +X rotation swings it forward/up (pi = overhead) and
-- +Z rotation swings the RIGHT arm outward (-Z for the left). For the torso,
-- -X leans forward and +Y twists to the left.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Elements = require(Shared:WaitForChild("Elements"))
local Skills = require(Shared:WaitForChild("Skills"))
local UIAssets = require(Shared:WaitForChild("UIAssets"))

local JOINTS = { "Waist", "Neck", "RightShoulder", "RightElbow", "LeftShoulder", "LeftElbow" }
local FADE_IN = 0.06
local FADE_OUT = 0.16

-- Each move: Duration, K1 (windup) at time A, K2 (release) at time B.
-- Keyframes map joint -> { X, Y, Z } rotation in radians.
local MOVES = {
	-- Basic attack: a snappy palm strike, alternating hands each shot. The hand
	-- draws back to the shoulder with the torso coiled, then punches out
	-- straight as the torso snaps the other way.
	FlickR = {
		Duration = 0.28, A = 0.06, B = 0.12, Hands = { "Right" },
		K1 = { RightShoulder = { 0.9, 0, 0.35 }, RightElbow = { 1.8, 0, 0 }, LeftShoulder = { 0.5, 0, -0.2 }, LeftElbow = { 0.8, 0, 0 }, Waist = { 0.05, 0.4, 0 }, Neck = { 0, -0.25, 0 } },
		K2 = { RightShoulder = { 1.6, 0, -0.05 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 0.2, 0, -0.25 }, LeftElbow = { 1, 0, 0 }, Waist = { -0.12, -0.35, 0 }, Neck = { 0, 0.25, 0 } },
	},
	FlickL = {
		Duration = 0.28, A = 0.06, B = 0.12, Hands = { "Left" },
		K1 = { LeftShoulder = { 0.9, 0, -0.35 }, LeftElbow = { 1.8, 0, 0 }, RightShoulder = { 0.5, 0, 0.2 }, RightElbow = { 0.8, 0, 0 }, Waist = { 0.05, -0.4, 0 }, Neck = { 0, 0.25, 0 } },
		K2 = { LeftShoulder = { 1.6, 0, 0.05 }, LeftElbow = { 0, 0, 0 }, RightShoulder = { 0.2, 0, 0.25 }, RightElbow = { 1, 0, 0 }, Waist = { -0.12, 0.35, 0 }, Neck = { 0, -0.25, 0 } },
	},
	-- Projectile: cock the arm back, then hurl forward.
	Throw = {
		Duration = 0.45, A = 0.15, B = 0.25, Hands = { "Right" },
		K1 = { RightShoulder = { -0.5, 0, 0.55 }, RightElbow = { 1.6, 0, 0 }, LeftShoulder = { 1.2, 0, 0 }, Waist = { 0.1, 0.5, 0 } },
		K2 = { RightShoulder = { 1.65, 0, 0 }, RightElbow = { 0.1, 0, 0 }, LeftShoulder = { 0.4, 0, -0.2 }, Waist = { -0.15, -0.35, 0 } },
	},
	-- Line: gather at the chest, then a two-handed push.
	Push = {
		Duration = 0.5, A = 0.15, B = 0.28, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { 0.4, 0, 0.2 }, LeftShoulder = { 0.4, 0, -0.2 }, RightElbow = { 1.9, 0, 0 }, LeftElbow = { 1.9, 0, 0 }, Waist = { 0.15, 0, 0 } },
		K2 = { RightShoulder = { 1.55, 0, -0.1 }, LeftShoulder = { 1.55, 0, 0.1 }, RightElbow = { 0.1, 0, 0 }, LeftElbow = { 0.1, 0, 0 }, Waist = { -0.25, 0, 0 } },
	},
	-- Nova: arms crossed and hunched, then flung wide.
	Burst = {
		Duration = 0.55, A = 0.15, B = 0.27, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { 0.8, 0, -0.5 }, LeftShoulder = { 0.8, 0, 0.5 }, RightElbow = { 1.6, 0, 0 }, LeftElbow = { 1.6, 0, 0 }, Waist = { -0.35, 0, 0 }, Neck = { -0.2, 0, 0 } },
		K2 = { RightShoulder = { 0.6, 0, 1.5 }, LeftShoulder = { 0.6, 0, -1.5 }, RightElbow = { 0, 0, 0 }, LeftElbow = { 0, 0, 0 }, Waist = { 0.15, 0, 0 }, Neck = { 0.15, 0, 0 } },
	},
	-- Strike: raise the arm overhead, then slam it down.
	Slam = {
		Duration = 0.6, A = 0.18, B = 0.3, Hands = { "Right" },
		K1 = { RightShoulder = { 3.0, 0, 0.1 }, RightElbow = { 0.3, 0, 0 }, LeftShoulder = { 0.5, 0, -0.4 }, Waist = { 0.25, 0.15, 0 }, Neck = { 0.2, 0, 0 } },
		K2 = { RightShoulder = { 0.9, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 0.2, 0, -0.3 }, Waist = { -0.45, 0, 0 }, Neck = { -0.2, 0, 0 } },
	},
	-- Zone: both arms raised to summon, then swept down to place it.
	Summon = {
		Duration = 0.65, A = 0.2, B = 0.36, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { 2.7, 0, 0.4 }, LeftShoulder = { 2.7, 0, -0.4 }, RightElbow = { 0.2, 0, 0 }, LeftElbow = { 0.2, 0, 0 }, Waist = { 0.15, 0, 0 }, Neck = { 0.3, 0, 0 } },
		K2 = { RightShoulder = { 1.4, 0, 0.6 }, LeftShoulder = { 1.4, 0, -0.6 }, RightElbow = { 0.1, 0, 0 }, LeftElbow = { 0.1, 0, 0 }, Waist = { -0.1, 0, 0 }, Neck = { -0.1, 0, 0 } },
	},
	-- Chain: snap a pointing arm forward; it trembles while the lightning jumps.
	Point = {
		Duration = 0.42, A = 0.07, B = 0.16, Hands = { "Right" }, Tremor = 0.07,
		K1 = { RightShoulder = { 1.4, 0, 0.1 }, RightElbow = { 0.4, 0, 0 }, LeftShoulder = { 0.3, 0, -0.2 } },
		K2 = { RightShoulder = { 1.65, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 0.2, 0, -0.3 }, Waist = { -0.1, -0.2, 0 } },
	},
	-- Magnet: thrust an open hand out, then yank it back to the chest.
	Yank = {
		Duration = 0.7, A = 0.14, B = 0.32, Hands = { "Right", "Left" }, Tremor = 0.05,
		K1 = { RightShoulder = { 1.7, 0, -0.15 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 1.5, 0, 0.15 }, LeftElbow = { 0.1, 0, 0 }, Waist = { -0.2, -0.15, 0 } },
		K2 = { RightShoulder = { 0.9, 0, 0.35 }, RightElbow = { 1.8, 0, 0 }, LeftShoulder = { 0.8, 0, -0.35 }, LeftElbow = { 1.8, 0, 0 }, Waist = { 0.25, 0, 0 }, Neck = { 0.1, 0, 0 } },
	},
	-- Plasma Lance: rear back with the spear raised behind the head, then
	-- hurl it like a javelin with the whole body.
	Javelin = {
		Duration = 0.62, A = 0.2, B = 0.3, Hands = { "Right" },
		K1 = { RightShoulder = { 2.9, 0, 0.35 }, RightElbow = { 1.1, 0, 0 }, LeftShoulder = { 1.5, 0, -0.1 }, Waist = { 0.25, 0.6, 0 }, Neck = { 0, -0.3, 0 } },
		K2 = { RightShoulder = { 1.5, 0, -0.05 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { -0.4, 0, -0.3 }, Waist = { -0.4, -0.5, 0 }, Neck = { 0.1, 0.2, 0 } },
	},
	-- Frost Gale: cup both hands at the hip to gather the cold, then thrust
	-- them forward and hold, trembling, while the blizzard pours out.
	Breath = {
		Duration = 0.75, A = 0.15, B = 0.23, Hands = { "Right", "Left" }, Tremor = 0.04,
		K1 = { RightShoulder = { 0.3, 0, 0.35 }, RightElbow = { 1.5, 0, 0 }, LeftShoulder = { 0.7, 0, 0.6 }, LeftElbow = { 1.6, 0, 0 }, Waist = { 0.15, 0.45, 0 }, Neck = { 0, -0.2, 0 } },
		K2 = { RightShoulder = { 1.6, 0, -0.15 }, RightElbow = { 0.05, 0, 0 }, LeftShoulder = { 1.6, 0, 0.15 }, LeftElbow = { 0.05, 0, 0 }, Waist = { -0.25, -0.1, 0 }, Neck = { -0.05, 0, 0 } },
	},
	-- Mudslide: crouch with both arms swung low behind, then heave the
	-- boulder forward underhand.
	Heave = {
		Duration = 0.7, A = 0.25, B = 0.38, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { -0.7, 0, 0.25 }, LeftShoulder = { -0.7, 0, -0.25 }, RightElbow = { 0.3, 0, 0 }, LeftElbow = { 0.3, 0, 0 }, Waist = { -0.45, 0, 0 }, Neck = { 0.3, 0, 0 } },
		K2 = { RightShoulder = { 1.5, 0, 0.1 }, LeftShoulder = { 1.5, 0, -0.1 }, RightElbow = { 0.1, 0, 0 }, LeftElbow = { 0.1, 0, 0 }, Waist = { 0.15, 0, 0 }, Neck = { -0.1, 0, 0 } },
	},
	-- Magma Meteor: both arms reach to the sky, then drag the meteor down
	-- onto the target.
	CallDown = {
		Duration = 0.8, A = 0.25, B = 0.42, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { 3.0, 0, 0.3 }, LeftShoulder = { 2.8, 0, -0.3 }, RightElbow = { 0.1, 0, 0 }, LeftElbow = { 0.1, 0, 0 }, Waist = { 0.25, 0, 0 }, Neck = { 0.4, 0, 0 } },
		K2 = { RightShoulder = { 1.1, 0, 0.1 }, LeftShoulder = { 1.0, 0, -0.1 }, RightElbow = { 0, 0, 0 }, LeftElbow = { 0, 0, 0 }, Waist = { -0.4, 0, 0 }, Neck = { -0.25, 0, 0 } },
	},
	-- Quake Leap: fists thrown overhead on the way up, then slammed down
	-- just as you land.
	Leap = {
		Duration = 1, A = 0.12, B = 0.8, Hands = { "Right", "Left" },
		K1 = { RightShoulder = { 2.9, 0, 0.3 }, LeftShoulder = { 2.9, 0, -0.3 }, RightElbow = { 0.6, 0, 0 }, LeftElbow = { 0.6, 0, 0 }, Waist = { 0.2, 0, 0 }, Neck = { 0.3, 0, 0 } },
		K2 = { RightShoulder = { 0.6, 0, 0.2 }, LeftShoulder = { 0.6, 0, -0.2 }, RightElbow = { 0, 0, 0 }, LeftElbow = { 0, 0, 0 }, Waist = { -0.5, 0, 0 }, Neck = { -0.2, 0, 0 } },
	},
	-- Dash: lean in with the arms swept back.
	Dash = {
		Duration = 0.26, A = 0.05, B = 0.1, Hands = {},
		K1 = { RightShoulder = { -0.7, 0, 0.2 }, LeftShoulder = { -0.7, 0, -0.2 }, Waist = { -0.35, 0, 0 }, Neck = { 0.2, 0, 0 } },
		K2 = { RightShoulder = { -0.8, 0, 0.25 }, LeftShoulder = { -0.8, 0, -0.25 }, Waist = { -0.4, 0, 0 }, Neck = { 0.25, 0, 0 } },
	},
}

local KIND_MOVE = { Projectile = "Throw", Line = "Push", Cone = "Breath", Nova = "Burst", Strike = "Slam", Zone = "Summon", Chain = "Point", Tornado = "Summon", Magnet = "Yank", Roller = "Heave", Meteor = "CallDown", Leap = "Leap" }
-- Skills with their own move instead of their kind's.
local SKILL_MOVE = { PlasmaLance = "Javelin" }

-- Block: forearms crossed in front of the chest, braced.
local GUARD = { RightShoulder = { 1.35, 0, -0.55 }, RightElbow = { 1.3, 0, 0 }, LeftShoulder = { 1.35, 0, 0.55 }, LeftElbow = { 1.3, 0, 0 }, Waist = { -0.12, 0, 0 }, Neck = { -0.1, 0, 0 } }
local GUARD_BLEND = 12 -- per second
local guards = {} -- [character] = { W, HitAt }
local predictedAt = -math.huge -- local player's guard, shown before the server confirms
local castHand = setmetatable({}, { __mode = "k" }) -- [character] = "RightHand" | "LeftHand"

local CastAnimator = {}

local playing = {} -- [character] = { Move, Start, Joints, Glows }
local jointCache = setmetatable({}, { __mode = "k" })

local function easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function easeIn(x)
	x = math.clamp(x, 0, 1)
	return x * x
end

local function jointsOf(character)
	local cached = jointCache[character]
	if cached then
		return cached
	end
	local joints = {}
	for _, name in JOINTS do
		for _, d in character:GetDescendants() do
			if d.Name == name and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
				joints[name] = d
				break
			end
		end
	end
	jointCache[character] = joints
	return joints
end

local function angles(keyframe, joint)
	local a = keyframe[joint]
	if a then
		return a[1], a[2], a[3]
	end
	return 0, 0, 0
end

-- Glowing hands while casting.
local function handGlow(character, hands, color, duration)
	local glows = {}
	for _, side in hands do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand then
			local att = Instance.new("Attachment")
			att.Name = "CastGlow"
			att.Position = Vector3.new(0, -0.3, 0)
			att.Parent = hand
			local glow = Instance.new("ParticleEmitter")
			glow.Texture = UIAssets.Fx.Glow
			glow.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.4), color)
			glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
			glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			glow.Lifetime = NumberRange.new(0.15, 0.25)
			glow.Rate = 45
			glow.LightEmission = 0.8
			glow.LightInfluence = 0
			glow.Speed = NumberRange.new(0.5, 1.5)
			glow.SpreadAngle = Vector2.new(180, 180)
			glow.Parent = att
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = UIAssets.Fx.Spark
			sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
			sparks.Color = ColorSequence.new(color)
			sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			sparks.Lifetime = NumberRange.new(0.15, 0.3)
			sparks.Rate = 25
			sparks.Speed = NumberRange.new(4, 9)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.LightEmission = 0.8
			sparks.LightInfluence = 0
			sparks.Parent = att
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 7
			light.Brightness = 1.2
			light.Parent = att
			table.insert(glows, att)
			task.delay(duration, function()
				glow.Enabled = false
				sparks.Enabled = false
				light.Enabled = false
				task.delay(0.4, function()
					att:Destroy()
				end)
			end)
		end
	end
	return glows
end

-- Plays the cast animation for a skill id (or "Dash") on a character.
function CastAnimator.Play(character, skillId)
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return
	end
	local moveName
	if skillId == "Dash" then
		moveName = "Dash"
	elseif skillId == "RiftBolt" then
		-- Alternate hands every shot.
		moveName = if castHand[character] == "RightHand" then "FlickL" else "FlickR"
		castHand[character] = if moveName == "FlickR" then "RightHand" else "LeftHand"
	elseif SKILL_MOVE[skillId] then
		moveName = SKILL_MOVE[skillId]
	else
		local def = Skills.Defs[skillId]
		moveName = def and KIND_MOVE[def.Kind]
	end
	local move = moveName and MOVES[moveName]
	if not move then
		return
	end
	local def = Skills.Defs[skillId]
	local color = if def then Elements.ColorOf(def.Elements) else Elements.NeutralColor
	playing[character] = {
		Move = move,
		Start = os.clock(),
		Joints = jointsOf(character),
	}
	if #move.Hands > 0 then
		handGlow(character, move.Hands, color, move.Duration)
	end
end

-- The hand the character last cast the basic attack from.
function CastAnimator.CastHand(character)
	return castHand[character] or "RightHand"
end

-- Shows the local player's guard immediately while the server confirms it.
function CastAnimator.PredictGuard()
	predictedAt = os.clock()
end

-- A blocked hit jolts the guard.
function CastAnimator.GuardHit(character)
	local g = guards[character]
	if g then
		g.HitAt = os.clock()
	end
end

local Players = game:GetService("Players")

local function stepGuards(dt)
	local now = os.clock()
	local localPlayer = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local up = player:GetAttribute("Blocking") == true
			if player == localPlayer and now - predictedAt < 0.3 then
				up = true
			end
			local g = guards[character]
			if not g then
				if not up then
					continue
				end
				g = { W = 0, HitAt = -math.huge }
				guards[character] = g
			end
			g.W = math.clamp(g.W + (if up then dt else -dt) * GUARD_BLEND, 0, 1)
			if g.W <= 0 and not up then
				guards[character] = nil
				continue
			end
			-- Pushed back a little when a hit lands on the shield.
			local jolt = math.max(0, 1 - (now - g.HitAt) / 0.18)
			for name, joint in jointsOf(character) do
				local pose = GUARD[name]
				if pose and joint.Parent then
					local x = pose[1] + (if name == "Waist" then 0.3 * jolt else 0)
					joint.Transform = joint.Transform:Lerp(CFrame.Angles(x, pose[2], pose[3]), g.W)
				end
			end
		end
	end
	for character in guards do
		if not character.Parent then
			guards[character] = nil
		end
	end
end

local function step(dt)
	local now = os.clock()
	for character, anim in playing do
		local move = anim.Move
		local t = now - anim.Start
		if not character.Parent or t > move.Duration + FADE_OUT then
			playing[character] = nil
			continue
		end
		-- Blend weight over the animator's own pose.
		local w = if t < FADE_IN then t / FADE_IN elseif t > move.Duration then 1 - (t - move.Duration) / FADE_OUT else 1
		for name, joint in anim.Joints do
			if joint.Parent then
				local x1, y1, z1 = angles(move.K1, name)
				local x2, y2, z2 = angles(move.K2, name)
				local x, y, z
				if t < move.A then
					local k = easeOut(t / move.A)
					x, y, z = x1 * k, y1 * k, z1 * k
				elseif t < move.B then
					local k = easeIn((t - move.A) / (move.B - move.A))
					x, y, z = x1 + (x2 - x1) * k, y1 + (y2 - y1) * k, z1 + (z2 - z1) * k
				else
					x, y, z = x2, y2, z2
					if move.Tremor and name == "RightShoulder" then
						z += math.sin(now * 60) * move.Tremor
					end
				end
				if x ~= 0 or y ~= 0 or z ~= 0 then
					joint.Transform = joint.Transform:Lerp(CFrame.Angles(x, y, z), w)
				end
			end
		end
	end
	stepGuards(dt)
end

function CastAnimator.Init()
	-- PreSimulation runs after the Animator has written this frame's joint
	-- transforms, so the cast pose layers on top of the walk/idle animation.
	RunService.PreSimulation:Connect(step)
end

return CastAnimator
