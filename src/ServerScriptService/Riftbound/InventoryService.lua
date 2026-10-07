-- Each player's collected items: { [itemId] = count }. Server-authoritative;
-- clients get a snapshot through Main's InventoryChanged remote.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Items"))

local InventoryService = {}

-- Set by Main.
InventoryService.OnChanged = function(_player, _snapshot) end
InventoryService.OnNotify = function(_player, _text, _color) end

local data = {}

function InventoryService.Init(player)
	data[player] = {}
end

function InventoryService.Remove(player)
	data[player] = nil
end

function InventoryService.Snapshot(player)
	return table.clone(data[player] or {})
end

function InventoryService.Add(player, id, count)
	local items = data[player]
	local def = Items.Defs[id]
	count = count or 1
	if not items or not def or count <= 0 then
		return
	end
	items[id] = (items[id] or 0) + count
	InventoryService.OnChanged(player, InventoryService.Snapshot(player))
	InventoryService.OnNotify(player, `+{count}  {def.Name}`, def.Color)
end

-- Removes items if the player has enough. Returns true on success.
function InventoryService.Take(player, id, count)
	local items = data[player]
	if not items or (items[id] or 0) < count then
		return false
	end
	items[id] -= count
	if items[id] <= 0 then
		items[id] = nil
	end
	InventoryService.OnChanged(player, InventoryService.Snapshot(player))
	return true
end

return InventoryService
