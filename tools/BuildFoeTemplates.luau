-- Builds the nation foe rig templates in ServerStorage.RiftboundAssets.Foes from
-- AI-generated meshes kept in ServerStorage.RiftboundAssets.FoeSources (or a
-- Workspace.FoeStage folder while generating):
--   Gen_<Id>      a body already split (segment_mesh) into Body, ArmL, ArmR, LegL, LegR
--   Gen_W_<Name>  a single weapon mesh
-- Any other part in Gen_<Id> (wings split off before the limbs) rides on the Body.
-- The generator usually faces characters +Z (FacesNegZ marks one that doesn't); templates face -Z, stand on y = 0 and are
-- centred on x = z = 0 (see FoeRig.lua). Elite templates are pre-scaled by the
-- foe's elite Scale, because FoeRig uses an elite template at scale 1.
-- Check the result offline with: node tools/meshview.js game.ServerStorage.RiftboundAssets.Foes.<Id> out.png
-- Run in Edit mode: node tools/rbx.js luau @tools/BuildFoeTemplates.luau
local ServerStorage = game:GetService("ServerStorage")

-- The user chose bare-handed foes that punch and cast; flip on to attach the weapon meshes.
local WITH_WEAPONS = false

local FOES = {
	{ Id = "AshenRonin", Height = 6.2, Color = Color3.fromRGB(255, 106, 43), Weapons = { { "Nodachi", "ArmR" } } },
	{ Id = "KilnOniCaptain", Height = 6.2, Scale = 1.6, Color = Color3.fromRGB(255, 106, 43), Weapons = { { "Kanabo", "ArmR" } } },
	{ Id = "ShalecragMonk", Height = 6.4, Color = Color3.fromRGB(255, 176, 59), Weapons = { { "StoneFist", "ArmR" }, { "StoneFist", "ArmL" } } },
	{ Id = "GravemawWarden", Height = 6.4, Scale = 1.8, Color = Color3.fromRGB(255, 176, 59), Weapons = { { "BeadChain", "ArmR" }, { "StoneFist", "ArmL" } } },
	{ Id = "DrownedLancer", Height = 6.3, Color = Color3.fromRGB(64, 200, 255), Weapons = { { "Trident", "ArmR" } } },
	{ Id = "AbyssalCourtKnight", Height = 6.3, Scale = 1.6, Color = Color3.fromRGB(64, 200, 255), Weapons = { { "Trident", "ArmR" }, { "CoralShield", "ArmL" } } },
	{ Id = "GaleShinobi", Height = 6.0, Color = Color3.fromRGB(120, 255, 200), Weapons = { { "WindBlade", "ArmR" }, { "WindBlade", "ArmL" } } },
	{ Id = "CycloneKunoichi", Height = 6.0, Scale = 1.5, Color = Color3.fromRGB(120, 255, 200), Weapons = { { "WindBlade", "ArmR" }, { "WindBlade", "ArmL" } } },
	{ Id = "ThunderfallenHerald", Height = 6.4, Color = Color3.fromRGB(255, 226, 77), Weapons = { { "Glaive", "ArmR" } } },
	{ Id = "StormbreakerPaladin", Height = 6.4, Scale = 1.6, FacesNegZ = true, Color = Color3.fromRGB(255, 226, 77), Weapons = { { "Glaive", "ArmR" } } },
}

-- How each generated weapon sits in the hand (grunt-sized template space).
--   Axis:   tail-to-head direction in the mesh's local space, in half-sizes
--           (so (1,-1,-1) is the box diagonal for a sword generated on a slant).
--   Side:   a local direction across the weapon, mapped onto To.Side.
--   Length: size along Axis, in studs.
--   Grip:   where the hand holds it, as a fraction of Axis from the tail.
--   To:     world direction for Axis and Side (x is flipped for the left arm).
--   Offset: extra shift from the hand (x is flipped for the left arm).
local WEAPONS = {
	Nodachi = { Axis = Vector3.new(1, -1, -1), Side = Vector3.yAxis, To = { Dir = Vector3.new(0, -0.2, -1), Side = Vector3.yAxis }, Length = 5.6, Grip = 0.08 },
	Kanabo = { Axis = Vector3.yAxis, Side = Vector3.zAxis, To = { Dir = Vector3.new(0, -0.25, -1), Side = Vector3.yAxis }, Length = 4.6, Grip = 0.1 },
	Trident = { Axis = Vector3.yAxis, Side = Vector3.xAxis, To = { Dir = Vector3.yAxis, Side = Vector3.xAxis }, Length = 7, Grip = 0.32 },
	Glaive = { Axis = Vector3.yAxis, Side = -Vector3.xAxis, To = { Dir = Vector3.yAxis, Side = -Vector3.zAxis }, Length = 7.4, Grip = 0.32 },
	-- Generated knuckles-up facing +Z: flip so the knuckles hang down and face forward.
	StoneFist = { Axis = -Vector3.yAxis, Side = Vector3.zAxis, To = { Dir = -Vector3.yAxis, Side = -Vector3.zAxis }, Length = 2.0, Grip = 0.15, Offset = Vector3.new(0, 0.2, -0.05) },
	-- A juzu ring lying flat with its tassel bead at -Z: hold the tassel bead, ring hangs.
	BeadChain = { Axis = Vector3.zAxis, Side = Vector3.xAxis, To = { Dir = Vector3.new(0, -1, -0.12), Side = Vector3.xAxis }, Length = 2.8, Grip = 0.03 },
	-- Decorated face points -Z already; stand it at the left hand.
	CoralShield = { Axis = Vector3.yAxis, Side = -Vector3.zAxis, To = { Dir = Vector3.yAxis, Side = -Vector3.zAxis }, Length = 3.2, Grip = 0.35, Offset = Vector3.new(0.45, 0, -0.55) },
	-- Crescent in the XY plane: stand it in the arm's side plane along the forearm, tips forward.
	WindBlade = { Axis = Vector3.yAxis, Side = Vector3.xAxis, To = { Dir = Vector3.new(0.15, 1, 0.35), Side = -Vector3.zAxis }, Length = 2.2, Grip = 0.55, Offset = Vector3.new(0.4, 0.55, -0.25) },
}

local LIMBS = { "Body", "ArmL", "ArmR", "LegL", "LegR" }
local assets = ServerStorage:FindFirstChild("RiftboundAssets")
local stage = workspace:FindFirstChild("FoeStage") or assets:FindFirstChild("FoeSources")
assert(stage, "no FoeStage / FoeSources folder")
local folder = assets:FindFirstChild("Foes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Foes"
	folder.Parent = assets
end

local function prep(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
end

-- Rotation taking local directions (a, b) onto world directions (d, e).
local function orient(a, b, d, e)
	a, d = a.Unit, d.Unit
	b = (b - a * b:Dot(a)).Unit
	e = (e - d * e:Dot(d)).Unit
	local src = CFrame.fromMatrix(Vector3.zero, a, b, a:Cross(b))
	local dst = CFrame.fromMatrix(Vector3.zero, d, e, d:Cross(e))
	return dst * src:Inverse()
end

local function addWeapon(model, name, limb, n)
	local w = WEAPONS[name]
	local gen = stage:FindFirstChild("Gen_W_" .. name)
	local src = gen and gen:FindFirstChildWhichIsA("MeshPart", true)
	if not (w and src) then
		return name .. " missing"
	end
	local p = src:Clone()
	prep(p)
	p.Name = if n == 1 then "Weapon" else "Weapon" .. n
	p:SetAttribute("AttachTo", limb)
	-- Tail-to-head vector in the part's local space, then scale it to Length.
	local axis = w.Axis * p.Size / 2
	p.Size = p.Size * (w.Length / (axis.Magnitude * 2))
	axis = w.Axis * p.Size / 2
	local arm = model[limb]
	local side = if limb == "ArmL" then -1 else 1
	local handAt = arm.Position - Vector3.new(0, arm.Size.Y / 2 - 0.2, 0)
	local offset = w.Offset or Vector3.zero
	local at = handAt + Vector3.new(offset.X * side, offset.Y, offset.Z)
	local dir = Vector3.new(w.To.Dir.X * side, w.To.Dir.Y, w.To.Dir.Z)
	local rot = orient(axis, w.Side, dir, w.To.Side)
	local gripLocal = -axis + axis * 2 * w.Grip
	p.CFrame = CFrame.new(at) * rot * CFrame.new(-gripLocal)
	p.Parent = model
	return nil
end

local report = {}
for _, foe in FOES do
	local gen = stage:FindFirstChild("Gen_" .. foe.Id)
	local parts = {}
	local extras = {}
	if gen then
		for _, d in gen:GetDescendants() do
			if d:IsA("BasePart") then
				if table.find(LIMBS, d.Name) then
					parts[d.Name] = d
				else
					table.insert(extras, d)
				end
			end
		end
	end
	local missing = {}
	for _, name in LIMBS do
		if not (parts[name] and parts[name]:IsA("BasePart")) then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		table.insert(report, foe.Id .. ": skipped, missing " .. table.concat(missing, ","))
		continue
	end

	local model = Instance.new("Model")
	model.Name = foe.Id
	for _, name in LIMBS do
		local p = parts[name]:Clone()
		prep(p)
		p.Name = name
		p.Parent = model
	end
	for _, e in extras do
		local p = e:Clone()
		prep(p)
		p:SetAttribute("AttachTo", "Body")
		p.Parent = model
	end
	-- Face -Z, scale to height, stand on the floor at the origin.
	if not foe.FacesNegZ then
		model:PivotTo(CFrame.Angles(0, math.pi, 0) * model:GetPivot())
	end
	local cf, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * foe.Height / size.Y)
	cf, size = model:GetBoundingBox()
	local body = model.Body
	model:PivotTo(model:GetPivot() + Vector3.new(-body.Position.X, size.Y / 2 - cf.Position.Y, -body.Position.Z))
	-- Facing -Z the character's left is -X; fix any swapped labels from the split.
	if model.ArmL.Position.X > model.ArmR.Position.X then
		model.ArmL.Name, model.ArmR.Name = "ArmR", "ArmL"
	end
	if model.LegL.Position.X > model.LegR.Position.X then
		model.LegL.Name, model.LegR.Name = "LegR", "LegL"
	end

	local notes = {}
	for i, spec in if WITH_WEAPONS then foe.Weapons else {} do
		local err = addWeapon(model, spec[1], spec[2], i)
		if err then
			table.insert(notes, err)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = foe.Color
	light.Range = 9
	light.Brightness = 1.2
	light.Parent = model.Body

	if foe.Scale then
		model:ScaleTo(model:GetScale() * foe.Scale)
	end
	-- Stand on the lowest point (weapons included) again after any scaling.
	cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, size.Y / 2 - cf.Position.Y, 0))

	local old = folder:FindFirstChild(foe.Id)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	table.insert(report, string.format("%s: built %.1f x %.1f x %.1f%s", foe.Id, size.X, size.Y, size.Z, if #notes > 0 then " (" .. table.concat(notes, "; ") .. ")" else ""))
end
return table.concat(report, "\n")
