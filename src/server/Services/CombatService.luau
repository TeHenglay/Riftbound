--!strict
-- Server-authoritative skill use: cooldowns, hit detection, damage and status effects.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Elements = require(Shared.Elements)
local Fusions = require(Shared.Fusions)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Types = require(Shared.Types)

local LoadoutService = require(script.Parent.LoadoutService)
local StatusEffects = require(script.Parent.StatusEffects)

local SHATTER_MULTIPLIER = 1.5 -- bonus when an enemy is both burning and chilled
local DASH_IFRAMES = 0.25
local NEUTRAL_COLOR = Color3.fromRGB(255, 255, 255)

local CombatService = {}

local lastUsed: { [Player]: { [string]: number } } = {}

local function onCooldown(player: Player, skill: Types.Skill): boolean
	local times = lastUsed[player]
	if not times then
		times = {}
		lastUsed[player] = times
	end
	local now = os.clock()
	-- Small tolerance for network jitter.
	if times[skill.slot] and now - times[skill.slot] < skill.cooldown * 0.9 then
		return true
	end
	times[skill.slot] = now
	return false
end

-- Works out what a slot does right now: statuses to apply, damage, radius and colour.
local function resolve(skill: Types.Skill, state: Types.SlotState)
	local statuses: { { status: Types.StatusId, level: number } } = {}
	local damage = skill.damage
	local radius = skill.radius
	local color = NEUTRAL_COLOR

	local fusion = state.fusion and Fusions.get(state.fusion)
	if fusion then
		damage *= fusion.damageMultiplier
		radius *= fusion.radiusMultiplier
		color = fusion.color
		for _, status in fusion.statuses do
			table.insert(statuses, { status = status, level = Fusions.REQUIRED_LEVEL })
		end
	end

	local strongest = 0
	for elementId, level in state.elements do
		local element = Elements[elementId]
		table.insert(statuses, { status = element.status, level = level })
		if not fusion and level > strongest then
			strongest = level
			color = element.color
		end
	end

	return statuses, damage, radius, color
end

local function enemiesNear(center: Vector3, radius: number): { Model }
	local hits = {}
	for _, enemy in CollectionService:GetTagged("Enemy") do
		if enemy:IsA("Model") and enemy.PrimaryPart then
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			local offset = enemy.PrimaryPart.Position - center
			-- Flat distance so height differences do not matter on the arena floor.
			if
				humanoid
				and humanoid.Health > 0
				and Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius
			then
				table.insert(hits, enemy)
			end
		end
	end
	return hits
end

local function useSkill(player: Player, slot: Types.SlotId, aim: Vector3)
	local skill = Skills[slot]
	local loadout = LoadoutService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not skill or not loadout or not character or not root then
		return
	end
	if onCooldown(player, skill) then
		return
	end

	local flat = Vector3.new(aim.X, 0, aim.Z)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
	local statuses, damage, radius, color = resolve(skill, loadout[slot])

	local center = root.Position + direction * skill.range
	if slot == "Dash" then
		-- Dash grants brief invulnerability; with an element it also hits around where you land.
		character:SetAttribute("Invulnerable", true)
		task.delay(DASH_IFRAMES, function()
			character:SetAttribute("Invulnerable", nil)
		end)
		if #statuses == 0 then
			return
		end
		center = root.Position
	end

	Remotes.SkillFx:FireAllClients(center, radius, color)

	for _, enemy in enemiesNear(center, radius) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid") :: Humanoid
		local dealt = damage
		if StatusEffects.has(enemy, "Burn") and StatusEffects.has(enemy, "Chill") then
			dealt *= SHATTER_MULTIPLIER
		end
		humanoid:TakeDamage(dealt)
		for _, entry in statuses do
			StatusEffects.apply(enemy, entry.status, {
				source = player,
				damage = dealt,
				level = entry.level,
				origin = root.Position,
			})
		end
	end
end

function CombatService.start()
	Remotes.UseSkill.OnServerEvent:Connect(function(player, slot, aim)
		if typeof(slot) == "string" and typeof(aim) == "Vector3" and Skills[slot :: any] then
			useSkill(player, slot :: any, aim)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUsed[player] = nil
	end)
end

return CombatService
