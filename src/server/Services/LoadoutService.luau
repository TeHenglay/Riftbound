--!strict
-- Keeps each player's run loadout: which elements are infused into which slot, and fusions.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Elements = require(Shared.Elements)
local Fusions = require(Shared.Fusions)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Types = require(Shared.Types)

local MAX_ELEMENT_LEVEL = 3

local LoadoutService = {}

local loadouts: { [Player]: Types.Loadout } = {}

local function newLoadout(): Types.Loadout
	return {
		Attack = { elements = {} },
		Special = { elements = {} },
		Cast = { elements = {} },
		Dash = { elements = {} },
	}
end

local function sync(player: Player)
	Remotes.LoadoutChanged:FireClient(player, loadouts[player])
end

function LoadoutService.get(player: Player): Types.Loadout?
	return loadouts[player]
end

function LoadoutService.reset(player: Player)
	loadouts[player] = newLoadout()
	sync(player)
end

-- Adds one level of an element to a slot. Returns false if the request is invalid.
function LoadoutService.infuse(player: Player, slot: Types.SlotId, element: Types.ElementId): boolean
	local loadout = loadouts[player]
	if not loadout or not Skills[slot] or not Elements[element] then
		return false
	end
	local state = loadout[slot]
	local level = state.elements[element] or 0
	if level >= MAX_ELEMENT_LEVEL then
		return false
	end
	state.elements[element] = level + 1
	sync(player)
	return true
end

-- Merges two ready elements on a slot into a fusion. The two elements are consumed.
function LoadoutService.fuse(player: Player, slot: Types.SlotId, fusionId: string): boolean
	local loadout = loadouts[player]
	if not loadout or not Skills[slot] then
		return false
	end
	local state = loadout[slot]
	if state.fusion then
		return false
	end
	for _, fusion in Fusions.available(state) do
		if fusion.id == fusionId then
			for _, element in fusion.elements do
				state.elements[element] = nil
			end
			state.fusion = fusion.id
			sync(player)
			return true
		end
	end
	return false
end

function LoadoutService.start()
	Players.PlayerAdded:Connect(LoadoutService.reset)
	for _, player in Players:GetPlayers() do
		LoadoutService.reset(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		loadouts[player] = nil
	end)

	Remotes.Infuse.OnServerEvent:Connect(function(player, slot, element)
		if typeof(slot) == "string" and typeof(element) == "string" then
			LoadoutService.infuse(player, slot :: any, element :: any)
		end
	end)
	Remotes.Fuse.OnServerEvent:Connect(function(player, slot, fusionId)
		if typeof(slot) == "string" and typeof(fusionId) == "string" then
			LoadoutService.fuse(player, slot :: any, fusionId)
		end
	end)
end

return LoadoutService
