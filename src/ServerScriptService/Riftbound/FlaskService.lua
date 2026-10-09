-- The Rift Flask: a healing item with 3 charges. Press R to drink; a short sip
-- slows you, then heals a share of max health. Refilled at the Rift Well and on
-- level up.
-- Published to the client as player attributes FlaskCharges / FlaskMax.

local CHARGES = 3
local HEAL_FRACTION = 0.35
local SIP_TIME = 0.45
local SIP_SLOW = 0.5
local COOLDOWN = 1
local HEAL_COLOR = Color3.fromRGB(255, 84, 104)

local Nations = require(game:GetService("ReplicatedStorage"):WaitForChild("Riftbound"):WaitForChild("Nations"))

local FlaskService = {}

-- Set by Main to send toasts to the client.
FlaskService.OnNotify = function(_player, _text, _color) end

local data = {}

local function publish(player)
	local d = data[player]
	if d then
		player:SetAttribute("FlaskCharges", d.Charges)
		player:SetAttribute("FlaskMax", d.Max)
	end
end

-- Asks every client to play a player effect (rendered by SkillVFX).
local function playerFx(kind, root)
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Riftbound"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SkillFx")
	if remote then
		remote:FireAllClients({ Type = kind, Target = root })
	end
end

local function healEffect(root)
	playerFx("Heal", root)
end

function FlaskService.Init(player)
	data[player] = { Charges = CHARGES, Max = CHARGES, LastUse = 0, Drinking = false }
	publish(player)
end

function FlaskService.Remove(player)
	data[player] = nil
end

function FlaskService.Drink(player)
	local d = data[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not d or not hum or not root or hum.Health <= 0 or d.Drinking then
		return
	end
	if os.clock() - d.LastUse < COOLDOWN then
		return
	end
	if d.Charges <= 0 then
		FlaskService.OnNotify(player, "Your flask is empty", Color3.fromRGB(200, 160, 160))
		return
	end
	if hum.Health >= hum.MaxHealth then
		FlaskService.OnNotify(player, "Already at full health", Color3.fromRGB(200, 160, 160))
		return
	end

	d.Drinking = true
	d.LastUse = os.clock()
	d.Charges -= 1
	publish(player)

	local speed = hum.WalkSpeed
	hum.WalkSpeed = speed * SIP_SLOW
	task.delay(SIP_TIME, function()
		d.Drinking = false
		if hum.Parent and hum.Health > 0 then
			hum.WalkSpeed = speed
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * (HEAL_FRACTION + Nations.FlaskBonus(player)))
			if root.Parent then
				healEffect(root)
			end
		end
	end)
end

-- Fills every charge. `silent` skips the toast (used on level up).
function FlaskService.Refill(player, silent)
	local d = data[player]
	if not d then
		return
	end
	local missing = d.Max - d.Charges
	d.Charges = d.Max
	publish(player)
	if not silent then
		FlaskService.OnNotify(player, if missing > 0 then "Flasks refilled" else "Your flasks are already full", HEAL_COLOR)
	end
end

function FlaskService.Get(player)
	local d = data[player]
	return d and { Charges = d.Charges, Max = d.Max }
end

return FlaskService
