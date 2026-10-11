-- Training arena summoning board: a board on the west side of the arena whose
-- prompt opens a panel listing every mob in the game (training dummies, the
-- nation golems at each wave size, and every story boss). Picking one asks the
-- server to summon it on the pad in front of the board. Summons drop no
-- rewards, and each player can keep a few alive at once.
--
-- Remotes.MobBoard (RemoteEvent)
--   server -> client  ("Open", catalog) | ("Count", alive, cap)
--   client -> server  ("Summon", id, kind?) | ("Clear")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local arena = workspace:FindFirstChild("RiftboundTestArena")
if not arena then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Story = require(Shared:WaitForChild("Story"))
local Enemies = require(script.Parent.Enemies)
local ok, NationFoes = pcall(require, script.Parent.NationFoes)
if not ok then
	warn("[MobBoard] nation foes unavailable: " .. tostring(NationFoes))
	NationFoes = nil
end

local remotes = Shared:WaitForChild("Remotes")
local MobBoard = remotes:FindFirstChild("MobBoard") or Instance.new("RemoteEvent")
MobBoard.Name = "MobBoard"
MobBoard.Parent = remotes

local PER_PLAYER = 6 -- summons a player can have alive at once
local TOTAL = 16 -- summons alive across the whole arena
local COOLDOWN = 0.4
local USE_RANGE = 30 -- studs from the board to summon

---------------------------------------------------------------------------
-- The board and the summon pad
---------------------------------------------------------------------------
local floor = arena:FindFirstChild("Floor")
local floorY = if floor then floor.Position.Y + floor.Size.Y / 2 else 1
local BOARD_AT = Vector3.new(-62, floorY, -10)
local PAD_AT = Vector3.new(-40, floorY, -10)

local function part(parent, name, size, cframe, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local board = arena:FindFirstChild("MobBoard")
if board then
	board:Destroy()
end
board = Instance.new("Model")
board.Name = "MobBoard"

-- Faces east (+X), toward the pad and the middle of the arena.
local facing = CFrame.lookAt(BOARD_AT, BOARD_AT + Vector3.new(1, 0, 0))
local stone = Color3.fromRGB(40, 32, 48)
local rift = Color3.fromRGB(178, 108, 255)
for _, side in { -1, 1 } do
	part(board, "Post", Vector3.new(1.2, 11, 1.2), facing * CFrame.new(side * 7.6, 5.5, 0), stone, { Material = Enum.Material.Slate })
end
local panel = part(board, "Panel", Vector3.new(14, 7.5, 0.6), facing * CFrame.new(0, 6.6, 0), Color3.fromRGB(14, 10, 20), { Material = Enum.Material.SmoothPlastic })
part(board, "Trim", Vector3.new(14.6, 0.3, 0.8), facing * CFrame.new(0, 10.5, 0), rift, { Material = Enum.Material.Neon })
part(board, "Trim", Vector3.new(14.6, 0.3, 0.8), facing * CFrame.new(0, 2.7, 0), rift, { Material = Enum.Material.Neon })
local base = part(board, "Base", Vector3.new(4, 1, 2), facing * CFrame.new(0, 0.5, -2), stone, { Material = Enum.Material.Slate })
board.PrimaryPart = panel

local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.LightInfluence = 0
gui.Parent = panel
local function label(text, y, h, size, color, weight)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -40, 0, h)
	l.Position = UDim2.new(0, 20, 0, y)
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.FontFace = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, weight)
	l.Parent = gui
	return l
end
label("SUMMONING BOARD", 30, 70, 64, Color3.fromRGB(233, 194, 122), Enum.FontWeight.Heavy)
label("Call any mob of the Rift onto the pad to practice against it.", 110, 40, 30, Color3.fromRGB(241, 227, 198), Enum.FontWeight.SemiBold)
label("Golems  ·  Bosses  ·  Training targets", 160, 40, 28, rift, Enum.FontWeight.Bold)
label("No rewards from summons", 230, 30, 24, Color3.fromRGB(156, 138, 123), Enum.FontWeight.Regular)

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Summon Mobs"
prompt.ObjectText = "Summoning Board"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = base

part(board, "SummonPad", Vector3.new(0.2, 16, 16), CFrame.new(PAD_AT + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2), rift, {
	Shape = Enum.PartType.Cylinder,
	Material = Enum.Material.Neon,
	Transparency = 0.65,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
board.Parent = arena

---------------------------------------------------------------------------
-- Catalog
---------------------------------------------------------------------------
-- Entries sent to the client: { Id, Name, Group, Sub, Color, Kinds? }.
-- Spawn specs stay on the server, keyed by Id.
local catalog = {}
local specs = {}

local function add(entry, spec)
	table.insert(catalog, entry)
	specs[entry.Id] = spec
end

add({ Id = "TrainingDummy", Name = "Training Dummy", Group = "Training", Sub = "Stands still, heals itself", Color = Color3.fromRGB(150, 125, 105) }, {
	Spawn = function(cframe)
		return Enemies.SpawnDummy(cframe, { Name = "Training Dummy", Health = 400, Speed = 0, Chase = false, Regen = true, Damage = 6, Color = Color3.fromRGB(95, 80, 70) })
	end,
})
add({ Id = "RiftHusk", Name = "Rift Husk", Group = "Training", Sub = "Daily Challenge mob", Color = rift }, {
	Spawn = function(cframe)
		return Enemies.SpawnDummy(cframe, { Name = "Rift Husk", Visual = "RiftHusk", Health = 120, Speed = 11, Chase = true, Damage = 6, Color = Color3.fromRGB(60, 40, 90) })
	end,
})

local KINDS = { "Swarmer", "Grunt", "Brute", "Elite" }
for _, nation in Story.Order do
	local story = Story.Defs[nation]
	if NationFoes and NationFoes.Golems[nation] then
		local golem = NationFoes.Golems[nation]
		add({ Id = golem.Id, Name = golem.Name, Group = "Golems", Sub = nation .. " wave mob", Color = story.Color, Kinds = KINDS }, {
			Spawn = function(cframe, kind)
				local stats = Story.Kinds[kind]
				return NationFoes.Spawn(nation, kind, cframe, { Health = stats.Health, Speed = stats.Speed, Damage = stats.Damage })
			end,
		})
	end
	for act, def in story.Acts do
		local boss = def.Boss
		if boss and (NationFoes or not boss.Foe) then
			local scale = Story.Scale[act]
			add({ Id = nation .. "Boss" .. act, Name = boss.Name, Group = "Bosses", Sub = nation .. " · Act " .. act .. " boss", Color = story.Color }, {
				Spawn = function(cframe)
					local opts = {
						Name = boss.Name,
						Visual = "RiftHusk",
						Health = math.floor(boss.Health * scale),
						Speed = boss.Speed,
						Chase = true,
						Damage = math.floor(boss.Damage * scale),
						Color = story.Color,
					}
					local model
					if boss.Foe then
						model = NationFoes.SpawnFoe(nation, boss.Foe, cframe, opts)
					else
						model = Enemies.SpawnDummy(cframe, opts)
					end
					-- Same sizes the story uses for its bosses.
					pcall(model.ScaleTo, model, model:GetScale() * (if boss.Foe then 1.5 else 2.2))
					model:SetAttribute("Elite", true)
					model:SetAttribute("Boss", true)
					model:SetAttribute("BossName", boss.Name)
					return model
				end,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Summoning
---------------------------------------------------------------------------
local summons = {} -- player -> { [model] = true }
local lastUse = {}

local function alive(player)
	local n = 0
	for model in summons[player] or {} do
		if Enemies.IsAlive(model) and model.Parent then
			n += 1
		else
			summons[player][model] = nil
		end
	end
	return n
end

local function totalAlive()
	local n = 0
	for player in summons do
		n += alive(player)
	end
	return n
end

local function sendCount(player)
	MobBoard:FireClient(player, "Count", alive(player), PER_PLAYER)
end

local function nearBoard(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return false
	end
	return (root.Position - base.Position).Magnitude <= USE_RANGE
end

local function clear(player)
	for model in summons[player] or {} do
		if model.Parent then
			model:Destroy()
		end
	end
	summons[player] = {}
end

prompt.Triggered:Connect(function(player)
	MobBoard:FireClient(player, "Open", catalog)
	sendCount(player)
end)

MobBoard.OnServerEvent:Connect(function(player, action, id, kind)
	if action == "Clear" then
		clear(player)
		sendCount(player)
		return
	end
	if action ~= "Summon" or type(id) ~= "string" then
		return
	end
	local spec = specs[id]
	if not spec or not nearBoard(player) then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return
	end
	lastUse[player] = now

	local entry
	for _, e in catalog do
		if e.Id == id then
			entry = e
			break
		end
	end
	if entry.Kinds then
		if not table.find(entry.Kinds, kind) then
			kind = "Grunt"
		end
	else
		kind = nil
	end

	summons[player] = summons[player] or {}
	if alive(player) >= PER_PLAYER then
		MobBoard:FireClient(player, "Full", PER_PLAYER)
		return
	end
	if totalAlive() >= TOTAL then
		MobBoard:FireClient(player, "Full", TOTAL)
		return
	end

	local offset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	local at = PAD_AT + offset
	local cframe = CFrame.lookAt(at, at + Vector3.new(1, 0, 0))
	local spawned, model = pcall(spec.Spawn, cframe, kind)
	if not spawned then
		warn("[MobBoard] could not summon " .. id .. ": " .. tostring(model))
		return
	end
	model:SetAttribute("Summoned", player.UserId)
	summons[player][model] = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			if summons[player] then
				summons[player][model] = nil
				if player.Parent then
					sendCount(player)
				end
			end
		end)
	end
	sendCount(player)
end)

Players.PlayerRemoving:Connect(function(player)
	clear(player)
	summons[player] = nil
	lastUse[player] = nil
end)
