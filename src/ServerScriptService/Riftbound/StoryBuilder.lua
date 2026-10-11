-- Builds the story arenas into workspace.StoryArenas: one floating arena per
-- nation per act, themed like that nation's lobby, with an entry pad, enemy
-- spawn points and a hidden exit gate that StoryService reveals on clear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftbound")
local Nations = require(Shared:WaitForChild("Nations"))
local Story = require(Shared:WaitForChild("Story"))
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local L = LobbyBuilder.Lib
local StoryBuilder = {}

StoryBuilder.Spacing = 900
StoryBuilder.Height = 150
StoryBuilder.Z = 4700

-- Acts that have arenas so far: Act 1 (named-foe boss) and Act 2 (the
-- nation's elite boss, e.g. Gravemaw Warden). Keep Story.client's BUILT in step.
StoryBuilder.BuiltActs = { 1, 2 }

function StoryBuilder.Center(nationId, act)
	local index = table.find(Story.Order, nationId)
	return Vector3.new((index - 3) * StoryBuilder.Spacing, StoryBuilder.Height, StoryBuilder.Z + act * StoryBuilder.Spacing)
end

function StoryBuilder.Name(nationId, act)
	return nationId .. "_Act" .. act
end

function StoryBuilder.Build(nationId, act)
	local def = Nations.Defs[nationId]
	local story = Story.Defs[nationId]
	local theme = L.Themes[nationId]
	local c = StoryBuilder.Center(nationId, act)
	local rng = Random.new(table.find(Story.Order, nationId) * 131 + act)
	local arena = Instance.new("Model")
	arena.Name = StoryBuilder.Name(nationId, act)
	arena:SetAttribute("Center", c)
	arena:SetAttribute("Nation", nationId)
	arena:SetAttribute("Act", act)
	arena:SetAttribute("StoryArena", true)
	workspace.Terrain:FillBlock(CFrame.new(c + Vector3.new(0, 20, 0)), Vector3.new(680, 420, 680), Enum.Material.Air)

	L.buildIsland(arena, def, theme, c, rng)
	L.Decor[nationId](arena, def, theme, c, rng)

	-- Arrival pad on the south edge.
	local entry = L.part({ Name = "Entry", Size = Vector3.new(12, 1, 12), CFrame = CFrame.lookAt(c + Vector3.new(0, 0.5, 50), c + Vector3.new(0, 0.5, 0)), Material = theme.Plaza, Color = theme.PlazaColor, Parent = arena })
	L.disc(arena, entry.Position + Vector3.new(0, 0.55, 0), 9, 0.1, Enum.Material.Neon, L.Colors.Rift, { Name = "EntryGlow", Transparency = 0.4, CanCollide = false })

	-- Where enemies rise: a fan across the north half, plus a centre mark for bosses.
	local spawns = Instance.new("Folder")
	spawns.Name = "EnemySpawns"
	spawns.Parent = arena
	for i = 0, 7 do
		local a = math.rad(200 + i * 20)
		local r = 26 + (i % 3) * 8
		local mark = L.part({ Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = spawns })
		L.disc(arena, mark.Position + Vector3.new(0, 0.1, 0), 5, 0.1, Enum.Material.Neon, story.Color, { Name = "RiftScar", Transparency = 0.5, CanCollide = false })
	end
	L.part({ Name = "BossSpawn", Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(c + Vector3.new(0, 0.5, -20)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = spawns })

	-- Act 2+: the elite's lair. A ring of rift obelisks glowing in the
	-- nation's colour around the fight, and a boss circle where it rises.
	if act >= 2 then
		for i = 0, 5 do
			local a = math.rad(i * 60 + 30)
			local at = c + Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)
			L.part({ Name = "RiftObelisk", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(at + Vector3.new(0, 7, 0)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(-6, 6))), Material = theme.Plaza, Color = theme.PlazaColor, Parent = arena })
			L.part({ Name = "ObeliskCrystal", Size = Vector3.new(1.6, 4, 1.6), CFrame = CFrame.new(at + Vector3.new(0, 16, 0)) * CFrame.Angles(0, a + math.rad(45), 0), Material = Enum.Material.Neon, Color = story.Color, CanCollide = false, Parent = arena })
		end
		L.disc(arena, c + Vector3.new(0, 0.12, -20), 26, 0.1, Enum.Material.Neon, story.Color, { Name = "BossCircle", Transparency = 0.65, CanCollide = false })
		L.disc(arena, c + Vector3.new(0, 0.14, -20), 20, 0.1, Enum.Material.Neon, L.Colors.Rift, { Name = "BossCircleInner", Transparency = 0.75, CanCollide = false })
	end

	-- Act title over the arrival pad.
	L.billboard(entry, `A C T   {act}`, `{story.Title} · {story.Acts[act].Name}`, story.Color, 14)

	-- The exit gate is built, then stored until the act is cleared.
	local exitHolder = Instance.new("Model")
	exitHolder.Name = "ExitHolder"
	L.buildPortal(exitHolder, def, c, {
		Offset = Vector3.new(0, 0, -56),
		Travel = "Crossroads",
		Name = "ExitGate",
		Title = "A C T   C L E A R E D",
		Subtitle = "walk through to return to the Crossroads",
		Veil = Color3.fromRGB(150, 104, 40),
		Glow = L.Colors.Gold,
	})
	local exit = exitHolder:FindFirstChild("ExitGate")
	exit.Parent = nil
	exitHolder:Destroy()
	exit.Name = "ExitGate"
	local stash = Instance.new("Folder")
	stash.Name = "Hidden"
	stash.Parent = arena
	exit.Parent = stash
	-- Parts under a folder still render, so keep the gate out of the world.
	exit:PivotTo(exit:GetPivot() + Vector3.new(0, -300, 0))
	exit:SetAttribute("ShownPivot", exit:GetPivot() + Vector3.new(0, 300, 0))

	L.applyVariants(arena, theme)
	return arena
end

function StoryBuilder.BuildAll(rebuild)
	local folder = workspace:FindFirstChild("StoryArenas")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "StoryArenas"
		folder.Parent = workspace
	end
	for _, nationId in Story.Order do
		for _, act in StoryBuilder.BuiltActs do
			local name = StoryBuilder.Name(nationId, act)
			local existing = folder:FindFirstChild(name)
			if existing and rebuild then
				existing:Destroy()
				existing = nil
			end
			if not existing then
				StoryBuilder.Build(nationId, act).Parent = folder
			end
		end
	end
	return folder
end

return StoryBuilder
