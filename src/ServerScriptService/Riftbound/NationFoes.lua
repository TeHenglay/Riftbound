-- The regular foes of each nation's story (they replace the Rift Husk there;
-- the Husk moves to Daily Challenge). One foe per nation, each with a
-- regular version for the waves and a bigger elite that replaces the Brute.
--
-- Story hook:
--   NationFoes.Spawn(nation, kind, cframe, opts) -> model
--     nation: "Fire" | "Earth" | "Water" | "Wind" | "Lightning"
--     kind:   "Grunt" | "Elite"
--     opts:   the same table Enemies.SpawnDummy takes (Health, Damage, Speed,
--             Xp, Gold, Loot). Name, Chase and Visual are set here; Health
--             and Speed are adjusted per foe (tanks get more health, assassins
--             less, each foe has its own speed).
--   NationFoes.Names(nation) -> gruntName, eliteName
local Enemies = require(script.Parent.Enemies)
local Foes = script.Parent:WaitForChild("Foes")
local FoeKit = require(Foes.FoeKit)
local FoeRig = require(Foes.FoeRig)

local NationFoes = {}

NationFoes.ByNation = {
	Fire = require(Foes.AshenRonin),
	Earth = require(Foes.ShalecragMonk),
	Water = require(Foes.DrownedLancer),
	Wind = require(Foes.GaleShinobi),
	Lightning = require(Foes.ThunderfallenHerald),
}

function NationFoes.Names(nation)
	local foe = NationFoes.ByNation[nation]
	if foe then
		return foe.Name, foe.EliteName
	end
	return nil
end

-- Swaps the placeholder dummy body for the foe's rig (AI template if present,
-- otherwise the part-built stand-in) and moves the health bar above it.
local function dress(model, foe, elite, scale)
	local root = model.PrimaryPart
	for _, name in { "Body", "Eye" } do
		local p = model:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	local template = (elite and FoeRig.Template(foe.EliteId)) or FoeRig.Template(foe.Id)
	local templateScale = if elite and template and template.Name == foe.EliteId then 1 else scale
	local built
	if not template then
		local b = FoeRig.Builder()
		foe.Build(b, elite)
		built = b.Model
		template = built
	end
	local top = FoeRig.Attach(model, root, template, templateScale)
	if built then
		built:Destroy()
	end

	local head = model:FindFirstChild("Head")
	if head then
		for _, c in head:GetChildren() do
			if c:IsA("WeldConstraint") then
				c:Destroy()
			end
		end
		head.Transparency = 1
		head.CanCollide = false
		head.CanQuery = false
		head.Size = Vector3.new(1, 1, 1)
		head.CFrame = root.CFrame * CFrame.new(0, top + 0.3, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = head
		weld.Parent = head
		local gui = head:FindFirstChild("RiftHealth")
		if gui then
			gui.StudsOffset = Vector3.new(0, 1.2, 0)
		end
	end
end

function NationFoes.Spawn(nation, kind, cframe, opts)
	local foe = NationFoes.ByNation[nation]
	assert(foe, "NationFoes: unknown nation " .. tostring(nation))
	local elite = kind == "Elite"
	local stats = if elite then foe.Stats.Elite else foe.Stats.Grunt

	local o = table.clone(opts or {})
	o.Name = if elite then foe.EliteName else foe.Name
	o.Health = math.floor((o.Health or 120) * (stats.Health or 1) + 0.5)
	o.Speed = stats.Speed or o.Speed
	o.Chase = false
	o.Visual = nil
	o.Color = foe.Color

	local model = Enemies.SpawnDummy(cframe, o)
	model:SetAttribute("Foe", if elite then foe.EliteId else foe.Id)
	model:SetAttribute("Nation", nation)
	model:SetAttribute("Elite", elite)
	dress(model, foe, elite, stats.Scale or 1)

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.Died:Connect(function()
		local root = model.PrimaryPart
		if root then
			FoeKit.Burst(root.Position + Vector3.new(0, 1.5, 0), foe.Color, 12, 4)
		end
	end)

	local ctx = { Elite = elite, Damage = o.Damage or 6, Color = foe.Color, Opts = o }
	FoeKit.Run(model, hum, ctx, foe.Think)
	if foe.Setup then
		foe.Setup(ctx)
	end
	return model
end

return NationFoes
