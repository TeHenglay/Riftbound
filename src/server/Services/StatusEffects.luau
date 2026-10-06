--!strict
-- Status effects applied to enemies (and the player for Armor/Drain).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared.Types)

local BURN_DPS_PER_LEVEL = 3
local BURN_DURATION = 3
local CHILL_DURATION = 2
local CHILL_SLOW = 0.5
local SHOCK_DAMAGE_PER_LEVEL = 6
local SHOCK_RANGE = 14
local KNOCKBACK_SPEED_PER_LEVEL = 25
local ARMOR_DURATION = 4
local DRAIN_FRACTION_PER_LEVEL = 0.1

export type HitContext = {
	source: Player,
	damage: number,
	level: number,
	origin: Vector3,
}

local StatusEffects = {}

-- Active effects per enemy model: status -> expiry time.
local active: { [Model]: { [Types.StatusId]: number } } = {}

local function humanoidOf(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

local function mark(model: Model, status: Types.StatusId, duration: number)
	local effects = active[model]
	if not effects then
		effects = {}
		active[model] = effects
		model.Destroying:Connect(function()
			active[model] = nil
		end)
	end
	effects[status] = os.clock() + duration
	model:SetAttribute(status, true)
	task.delay(duration, function()
		local current = active[model]
		if current and current[status] and current[status] <= os.clock() then
			current[status] = nil
			model:SetAttribute(status, nil)
		end
	end)
end

function StatusEffects.has(model: Model, status: Types.StatusId): boolean
	local effects = active[model]
	return effects ~= nil and effects[status] ~= nil and effects[status] > os.clock()
end

local handlers: { [Types.StatusId]: (Model, HitContext) -> () } = {
	Burn = function(model, ctx)
		local alreadyBurning = StatusEffects.has(model, "Burn")
		mark(model, "Burn", BURN_DURATION)
		if alreadyBurning then
			return -- refresh duration only, one burn loop at a time
		end
		task.spawn(function()
			while StatusEffects.has(model, "Burn") do
				local humanoid = humanoidOf(model)
				if not humanoid or humanoid.Health <= 0 then
					return
				end
				humanoid:TakeDamage(BURN_DPS_PER_LEVEL * ctx.level)
				task.wait(1)
			end
		end)
	end,

	Chill = function(model, _ctx)
		local humanoid = humanoidOf(model)
		if not humanoid then
			return
		end
		if not StatusEffects.has(model, "Chill") then
			local baseSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = baseSpeed * CHILL_SLOW
			task.delay(CHILL_DURATION, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = baseSpeed
				end
			end)
		end
		mark(model, "Chill", CHILL_DURATION)
	end,

	Shock = function(model, ctx)
		local root = model.PrimaryPart
		if not root then
			return
		end
		-- Chain to the nearest other enemy.
		local nearest: Model? = nil
		local nearestDistance = SHOCK_RANGE
		for _, other in CollectionService:GetTagged("Enemy") do
			if other ~= model and other:IsA("Model") and other.PrimaryPart then
				local distance = (other.PrimaryPart.Position - root.Position).Magnitude
				if distance < nearestDistance then
					nearest = other
					nearestDistance = distance
				end
			end
		end
		if nearest then
			local humanoid = humanoidOf(nearest)
			if humanoid then
				humanoid:TakeDamage(SHOCK_DAMAGE_PER_LEVEL * ctx.level)
			end
		end
	end,

	Knockback = function(model, ctx)
		local root = model.PrimaryPart
		if not root or root.Anchored then
			return
		end
		local away = root.Position - ctx.origin
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0 then
			root.AssemblyLinearVelocity = away.Unit * KNOCKBACK_SPEED_PER_LEVEL * ctx.level
				+ Vector3.yAxis * 10
		end
	end,

	Armor = function(_model, ctx)
		-- Shields the attacker. Damage reduction is read by player damage code later.
		local character = ctx.source.Character
		if character then
			character:SetAttribute("ArmorLevel", ctx.level)
			task.delay(ARMOR_DURATION, function()
				if character:GetAttribute("ArmorLevel") == ctx.level then
					character:SetAttribute("ArmorLevel", nil)
				end
			end)
		end
	end,

	Drain = function(_model, ctx)
		local character = ctx.source.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = math.min(
				humanoid.MaxHealth,
				humanoid.Health + ctx.damage * DRAIN_FRACTION_PER_LEVEL * ctx.level
			)
		end
	end,
}

function StatusEffects.apply(model: Model, status: Types.StatusId, ctx: HitContext)
	local handler = handlers[status]
	if handler then
		handler(model, ctx)
	end
end

return StatusEffects
