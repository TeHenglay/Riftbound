-- Buying from the Rift Shop and selling loot to the Goods Merchant, both in
-- the Crossroads. Prices live in ReplicatedStorage.Riftbound.Market.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Market = require(Shared:WaitForChild("Market"))
local Items = require(Shared:WaitForChild("Items"))
local ProgressionService = require(script.Parent.ProgressionService)
local InventoryService = require(script.Parent.InventoryService)
local FlaskService = require(script.Parent.FlaskService)
local StatService = require(script.Parent.StatService)

local MarketService = {}

-- True when the player stands near a stall of this kind.
local function nearStall(player, kind)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local lobbies = workspace:FindFirstChild("NationLobbies")
	if not root or not lobbies or player:GetAttribute("Area") ~= "Crossroads" then
		return false
	end
	for _, counter in lobbies:GetDescendants() do
		if counter:IsA("BasePart") and counter:GetAttribute("Market") == kind and (counter.Position - root.Position).Magnitude <= Market.Reach then
			return true
		end
	end
	return false
end

-- Returns ok, message.
function MarketService.Buy(player, offerId)
	local offer = typeof(offerId) == "string" and Market.Shop[offerId]
	if not offer then
		return false, "Unknown item"
	end
	if not nearStall(player, "Shop") then
		return false, "Walk up to the shop first"
	end
	if offerId == "FlaskRefill" then
		local charges, max = player:GetAttribute("FlaskCharges"), player:GetAttribute("FlaskMax")
		if charges and max and charges >= max then
			return false, "Your flask is already full"
		end
	end
	if not ProgressionService.SpendGold(player, offer.Price) then
		return false, "Not enough gold"
	end
	if offerId == "FlaskRefill" then
		FlaskService.Refill(player)
	elseif offerId == "Tome" then
		StatService.GrantPoints(player, 1)
	elseif offer.Item then
		InventoryService.Add(player, offer.Item, offer.Count or 1)
	end
	return true, "Bought"
end

-- Sells `count` of an item (or all of it when count is "all").
function MarketService.Sell(player, itemId, count)
	local price = typeof(itemId) == "string" and Market.SellPrice[itemId]
	if not price or not Items.Defs[itemId] then
		return false, "The merchant doesn't want that"
	end
	if not nearStall(player, "Merchant") then
		return false, "Walk up to the merchant first"
	end
	local owned = InventoryService.Snapshot(player)[itemId] or 0
	if count == "all" then
		count = owned
	end
	if typeof(count) ~= "number" or count < 1 or count ~= math.floor(count) then
		return false, "Nothing to sell"
	end
	if not InventoryService.Take(player, itemId, count) then
		return false, "You don't have that many"
	end
	ProgressionService.AddGold(player, price * count)
	return true, `Sold {count} for {price * count} gold`
end

return MarketService
