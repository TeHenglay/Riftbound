-- Puts a foe's body on its HumanoidRootPart as a jointed rig the client's
-- EnemyAnimator can drive (Motor6Ds Rig_Body, Rig_ArmL, Rig_ArmR, Rig_LegL,
-- Rig_LegR, the same convention as the Rift Husk).
--
-- Template: a Model with parts named Body, ArmL, ArmR, LegL, LegR, facing -Z
-- and standing on its lowest point. Any other part (weapon, hat, scarf, halo)
-- is welded to the part named by its "AttachTo" attribute (default Body).
-- The AI-generated templates live in ServerStorage.RiftboundAssets.Foes.<Id>;
-- if one is missing, the foe module builds a part-based stand-in instead.
local ServerStorage = game:GetService("ServerStorage")

local FoeRig = {}

local LIMBS = { "Body", "ArmL", "ArmR", "LegL", "LegR" }

function FoeRig.Template(id)
	local assets = ServerStorage:FindFirstChild("RiftboundAssets")
	local foes = assets and assets:FindFirstChild("Foes")
	local t = foes and foes:FindFirstChild(id)
	if t and t:IsA("Model") then
		for _, name in LIMBS do
			if not t:FindFirstChild(name) then
				warn("[NationFoes] template " .. id .. " is missing " .. name)
				return nil
			end
		end
		return t
	end
	return nil
end

-- Attaches a clone of `template` scaled by `scale`. Returns the height of the
-- top of the body above the root centre.
function FoeRig.Attach(model, root, template, scale)
	local src = template:Clone()
	if scale and scale ~= 1 then
		src:ScaleTo(src:GetScale() * scale)
	end
	local floorY = math.huge
	local topY = -math.huge
	for _, p in src:GetDescendants() do
		if p:IsA("BasePart") then
			floorY = math.min(floorY, p.Position.Y - p.Size.Y / 2)
			topY = math.max(topY, p.Position.Y + p.Size.Y / 2)
		end
	end
	local s = scale or 1
	-- Root sits 2 studs above the floor in template space, at the body's X/Z.
	local body = src.Body
	local rootT = CFrame.new(body.Position.X, floorY + 2, body.Position.Z)
	local toWorld = root.CFrame * rootT:Inverse()

	local function top(p, inset)
		return p.Position + Vector3.new(0, p.Size.Y / 2 - inset * s, 0)
	end
	local pivots = {
		Body = { Parent = nil, At = Vector3.new(body.Position.X, body.Position.Y - body.Size.Y / 2 + 0.5 * s, body.Position.Z) },
		ArmL = { Parent = "Body", At = top(src.ArmL, 0.45) },
		ArmR = { Parent = "Body", At = top(src.ArmR, 0.45) },
		LegL = { Parent = nil, At = top(src.LegL, 0.2) },
		LegR = { Parent = nil, At = top(src.LegR, 0.2) },
	}
	local templateCF = {}
	for _, name in LIMBS do
		templateCF[name] = src[name].CFrame
	end

	local parts = {}
	for _, p in src:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CFrame = toWorld * p.CFrame
		end
	end
	for _, name in LIMBS do
		parts[name] = src[name]
	end
	for name, info in pivots do
		local pivot = CFrame.new(info.At)
		local part0 = if info.Parent then parts[info.Parent] else root
		local part0T = if info.Parent then templateCF[info.Parent] else rootT
		local motor = Instance.new("Motor6D")
		motor.Name = "Rig_" .. name
		motor.Part0 = part0
		motor.Part1 = parts[name]
		motor.C0 = part0T:Inverse() * pivot
		motor.C1 = templateCF[name]:Inverse() * pivot
		motor.Parent = parts[name]
	end
	-- Extras ride on their limb.
	for _, p in src:GetDescendants() do
		if p:IsA("BasePart") and not table.find(LIMBS, p.Name) then
			local to = parts[p:GetAttribute("AttachTo") or "Body"] or parts.Body
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = p
			weld.Parent = p
		end
	end
	for _, child in src:GetChildren() do
		child.Parent = model
	end
	src:Destroy()
	return topY - (floorY + 2)
end

-------------------------------------------------------------------------------
-- Stand-in builder: a quick part figure in template space (floor at y = 0,
-- facing -Z), used until the AI-generated template exists.
-------------------------------------------------------------------------------

function FoeRig.Builder()
	local m = Instance.new("Model")
	local b = { Model = m }
	-- part(name, size, position, color, props?) ; position is the part centre.
	function b.Part(name, size, pos, color, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = if typeof(pos) == "CFrame" then pos else CFrame.new(pos)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			if k == "AttachTo" then
				p:SetAttribute("AttachTo", v)
			else
				p[k] = v
			end
		end
		p.Parent = m
		return p
	end
	-- Standard humanoid limbs. dims: { Height, Width, LegH, ArmH, BodyColor, LimbColor, LegColor }
	function b.Limbs(d)
		local legH = d.LegH
		local bodyH = d.Height - legH - 1.2
		b.Part("LegL", Vector3.new(0.8, legH, 0.8), Vector3.new(-0.5, legH / 2, 0), d.LegColor)
		b.Part("LegR", Vector3.new(0.8, legH, 0.8), Vector3.new(0.5, legH / 2, 0), d.LegColor)
		b.Part("Body", Vector3.new(d.Width, bodyH, 1.1), Vector3.new(0, legH + bodyH / 2, 0), d.BodyColor)
		local armY = legH + bodyH - d.ArmH / 2
		b.Part("ArmL", Vector3.new(0.7, d.ArmH, 0.7), Vector3.new(-(d.Width / 2 + 0.4), armY, 0), d.LimbColor)
		b.Part("ArmR", Vector3.new(0.7, d.ArmH, 0.7), Vector3.new(d.Width / 2 + 0.4, armY, 0), d.LimbColor)
		local headY = legH + bodyH + 0.6
		return { HeadY = headY, BodyTop = legH + bodyH, HandY = armY - d.ArmH / 2, ArmX = d.Width / 2 + 0.4 }
	end
	return b
end

return FoeRig
