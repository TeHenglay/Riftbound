-- Server-side validation and execution for Forge Crafting and Skill Awakening.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Crafting = require(Shared:WaitForChild("Crafting"))
local Skills = require(Shared:WaitForChild("Skills"))
local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressionService = require(script.Parent.ProgressionService)

local CraftingService = {}

-- Everyone nearby sees the ceremony (SkillVFX: Fusion / Awaken).
local function ceremony(player, payload)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local remotes = Shared:FindFirstChild("Remotes")
	local fx = remotes and remotes:FindFirstChild("SkillFx")
	if root and fx then
		payload.Target = root
		fx:FireAllClients(payload)
	end
end

-- Fuses two base skills at The Forge, consuming required materials and gold.
function CraftingService.Craft(player, recipeId)
	if typeof(recipeId) ~= "string" then
		return false, "Invalid request"
	end
	local recipe = Crafting.ForgeRecipes[recipeId]
	if not recipe then
		return false, "Recipe not found"
	end

	local build = BuildService.Snapshot(player)
	local inv = InventoryService.Snapshot(player)
	local gold = player:GetAttribute("Gold") or 0

	local ok, err = Crafting.CanCraft(recipeId, build.Skills, inv, gold)
	if not ok then
		return false, err
	end

	-- Deduct gold
	if not ProgressionService.SpendGold(player, recipe.Gold) then
		return false, "Failed to deduct gold"
	end

	-- Deduct materials
	for item, count in recipe.Materials do
		InventoryService.Take(player, item, count)
	end

	-- Execute the skill fusion
	local skillA, skillB = recipe.Skills[1], recipe.Skills[2]
	local success, result = BuildService.Merge(player, skillA, skillB)
	if not success then
		-- Refund on failure
		ProgressionService.AddGold(player, recipe.Gold)
		for item, count in recipe.Materials do
			InventoryService.Add(player, item, count)
		end
		return false, result
	end

	ceremony(player, { Type = "Fusion", A = skillA, B = skillB, Result = result })
	return true, result
end

-- Ascends a Level 5 base or fused skill at the Awakening Altar.
function CraftingService.Awaken(player, baseSkillId)
	if typeof(baseSkillId) ~= "string" then
		return false, "Invalid request"
	end
	local recipe = Crafting.AwakenRecipes[baseSkillId]
	if not recipe then
		return false, "Awakening recipe not found"
	end

	local build = BuildService.Snapshot(player)
	local inv = InventoryService.Snapshot(player)
	local gold = player:GetAttribute("Gold") or 0

	local ok, err = Crafting.CanAwaken(baseSkillId, build.Skills, inv, gold)
	if not ok then
		return false, err
	end

	-- Deduct gold
	if not ProgressionService.SpendGold(player, recipe.Gold) then
		return false, "Failed to deduct gold"
	end

	if recipe.Materials then
		-- Fused awakenings: both nations' Essences and Shards, plus Rift Shards.
		for item, count in recipe.Materials do
			InventoryService.Take(player, item, count)
		end
	else
		-- Deduct 1 Essence OR 2 Cores
		local essenceCount = inv[recipe.Essence] or 0
		if essenceCount >= 1 then
			InventoryService.Take(player, recipe.Essence, 1)
		else
			InventoryService.Take(player, recipe.Core, 2)
		end

		-- Deduct shards
		InventoryService.Take(player, recipe.Shard, recipe.ShardCount)
		InventoryService.Take(player, "RiftShard", recipe.RiftShardCount)
	end

	-- Execute ascension
	local success, result = BuildService.Awaken(player, baseSkillId, recipe.AwakenedSkill)
	if not success then
		-- Refund on failure
		ProgressionService.AddGold(player, recipe.Gold)
		return false, result
	end

	ceremony(player, { Type = "Awaken", Base = baseSkillId, Result = recipe.AwakenedSkill })

	return true, result
end

return CraftingService
