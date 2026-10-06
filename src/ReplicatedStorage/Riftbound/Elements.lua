-- Element definitions and elemental reactions, shared by server and client.
local Elements = {}

Elements.List = {
	Fire = { Name = "Fire", Color = Color3.fromRGB(255, 106, 43) },
	Water = { Name = "Water", Color = Color3.fromRGB(52, 152, 255) },
	Earth = { Name = "Earth", Color = Color3.fromRGB(176, 122, 64) },
	Air = { Name = "Air", Color = Color3.fromRGB(170, 245, 225) },
	Lightning = { Name = "Lightning", Color = Color3.fromRGB(250, 225, 60) },
}

Elements.Order = { "Fire", "Water", "Earth", "Air", "Lightning" }

-- Colour used for skills with no element (the basic attack).
Elements.NeutralColor = Color3.fromRGB(170, 120, 255)

-- Hitting an enemy that has the `Needs` status with a skill containing the
-- `Hit` element multiplies the damage. `Consume` removes the status afterwards.
Elements.Reactions = {
	{ Name = "Conduct", Needs = "Soak", Hit = "Lightning", Mult = 1.5, Consume = true },
	{ Name = "Evaporate", Needs = "Soak", Hit = "Fire", Mult = 1.25, Consume = true },
	{ Name = "Fan the Flames", Needs = "Burn", Hit = "Air", Mult = 1.3, Consume = false },
	{ Name = "Shatter", Needs = "Stun", Hit = "Earth", Mult = 1.4, Consume = true },
}

function Elements.ColorOf(elements)
	if #elements == 0 then
		return Elements.NeutralColor
	end
	local r, g, b = 0, 0, 0
	for _, name in elements do
		local c = Elements.List[name].Color
		r += c.R
		g += c.G
		b += c.B
	end
	local n = #elements
	return Color3.new(r / n, g / n, b / n)
end

-- A gradient running through each element's colour, for icons.
function Elements.SequenceOf(elements)
	if #elements == 0 then
		return ColorSequence.new(Elements.NeutralColor)
	end
	if #elements == 1 then
		return ColorSequence.new(Elements.List[elements[1]].Color)
	end
	local keys = {}
	for i, name in elements do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#elements - 1), Elements.List[name].Color))
	end
	return ColorSequence.new(keys)
end

return Elements
