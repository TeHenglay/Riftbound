-- Fusion rules: two base skills of different elements fuse into the skill
-- whose Elements list is exactly that pair. Built from Skills.Defs.
local Skills = require(script.Parent.Skills)

local Merge = {}

local recipes = {}

local function key(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. "+" .. b
end

for id, def in Skills.Defs do
	if #def.Elements == 2 then
		recipes[key(def.Elements[1], def.Elements[2])] = id
	end
end

-- Returns the fused skill id for two owned skill ids, or nil if they can't fuse.
function Merge.Result(idA, idB)
	local a, b = Skills.Defs[idA], Skills.Defs[idB]
	if not a or not b or idA == idB then
		return nil
	end
	if #a.Elements ~= 1 or #b.Elements ~= 1 then
		return nil
	end
	return recipes[key(a.Elements[1], b.Elements[1])]
end

-- { ["Fire+Water"] = "SteamCloud", ... }
function Merge.All()
	return recipes
end

-- Fused level: the higher of the two inputs.
function Merge.ResultLevel(levelA, levelB)
	return math.max(levelA, levelB)
end

return Merge
