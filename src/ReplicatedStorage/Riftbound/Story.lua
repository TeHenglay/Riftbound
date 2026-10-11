-- Story mode: one story per nation, three acts each. Acts unlock in order
-- inside a story; every story is open from the start, and your own nation's
-- story pays out extra materials. Shared so the story screen can show it all.
local Items = require(script.Parent:WaitForChild("Items"))
local Nations = require(script.Parent:WaitForChild("Nations"))

local Story = {}

-- Bonus reward multiplier for playing your own nation's story.
Story.HomeBonus = 1.5

-- A wave is a mixed pack: { Swarmer = n, Grunt = n, Brute = n, Elite = n },
-- spawned in Story.KindOrder. Every kind spawns the nation's element golem at
-- a different size. Kind stats are scaled per act by Story.Scale.
-- Act 1 and Act 2 bosses are the nation's named foes: Boss.Foe = "Grunt"
-- spawns the story's Grunt (e.g. Ashen Ronin), "Elite" its Elite.
Story.Kinds = {
	Swarmer = { Health = 45, Speed = 13, Damage = 3, Xp = 2, Gold = { 10, 25 } },
	Grunt = { Health = 95, Speed = 10, Damage = 5, Xp = 4, Gold = { 30, 50 } },
	Brute = { Health = 220, Speed = 7.5, Damage = 10, Xp = 12, Gold = { 80, 140 } },
	Elite = { Health = 420, Speed = 8.5, Damage = 14, Xp = 30, Gold = { 150, 250 } },
}
Story.Scale = { 1, 1.5, 2.1 } -- health/damage per act
Story.KindOrder = { "Swarmer", "Grunt", "Brute", "Elite" }

-- Every wave is at least 10 mobs: fragile Swarmers to sweep with AoE, a
-- Grunt frontline and one or two Brute/Elite anchors. Shared by every story.
local WAVES = {
	{ -- Act 1: 46 mobs
		{ Swarmer = 6, Grunt = 4 },
		{ Swarmer = 6, Grunt = 4, Brute = 1 },
		{ Swarmer = 5, Grunt = 6, Brute = 1 },
		{ Swarmer = 6, Grunt = 5, Brute = 1, Elite = 1 },
	},
	{ -- Act 2: 52 mobs
		{ Swarmer = 7, Grunt = 5 },
		{ Swarmer = 6, Grunt = 5, Brute = 2 },
		{ Swarmer = 5, Grunt = 6, Brute = 1, Elite = 1 },
		{ Swarmer = 6, Grunt = 5, Brute = 2, Elite = 1 },
	},
	{ -- Act 3: 27 mobs, then the boss
		{ Swarmer = 6, Grunt = 5, Brute = 2 },
		{ Swarmer = 6, Grunt = 5, Brute = 2, Elite = 1 },
	},
}

-- Bosses call the Rift for help as their health drops.
Story.BossCalls = {
	{ At = 0.75, Wave = { Swarmer = 10 } },
	{ At = 0.4, Wave = { Swarmer = 6, Grunt = 4 } },
}

function Story.WaveSize(wave)
	local n = 0
	for _, kind in Story.KindOrder do
		n += wave[kind] or 0
	end
	return n
end

Story.Order = { "Fire", "Earth", "Water", "Wind", "Lightning" }

Story.Defs = {
	Fire = {
		Image = "rbxassetid://114310667299338", -- Act 1 arena screenshot
		Title = "The Ashen Uprising",
		Blurb = "The Rift has cracked open beneath the Ember Dominion. Its volcano wakes, and the forges burn with something that is not fire.",
		Grunt = "Ashen Ronin",
		Elite = "Kiln Oni Captain",
		Color = Color3.fromRGB(255, 106, 43),
		Acts = {
			{
				Name = "Cinder Outskirts",
				Text = "Ash rains on the border villages. Husks made of cinder crawl out of the cracks. Push them back.",
				Waves = WAVES[1],
				Boss = { Foe = "Grunt", Name = "Ashen Ronin", Health = 900, Speed = 10, Damage = 12, Xp = 80, Gold = { 400, 600 } },
			},
			{
				Name = "The Magma Forges",
				Text = "The great forges run red with rift-fire. Ember Brutes guard the bellows. Break their hold.",
				Waves = WAVES[2],
				Boss = { Foe = "Elite", Name = "Kiln Oni Captain", Health = 1400, Speed = 9, Damage = 15, Xp = 150, Gold = { 900, 1200 } },
			},
			{
				Name = "Caldera Throne",
				Text = "At the volcano's heart waits Portgas D. Ace, master of the Flame-Flame Arts.",
				Waves = WAVES[3],
				Boss = { Name = "Portgas D. Ace", Health = 2800, Speed = 11.5, Damage = 18, Xp = 250, Gold = { 2000, 2500 } },
			},
		},
	},
	Earth = {
		Image = "rbxassetid://132404872798119", -- Act 1 arena screenshot
		Title = "The Breaking Mountain",
		Blurb = "The Stonehold's sacred mountain is splitting apart. Something huge is pushing up through the rock.",
		Grunt = "Shalecrag Monk",
		Elite = "Gravemaw Warden",
		Color = Color3.fromRGB(176, 122, 64),
		Acts = {
			{
				Name = "The Fallen Quarry",
				Text = "Rockslides bury the quarry and husks of living stone dig out of the rubble.",
				Waves = WAVES[1],
				Boss = { Foe = "Grunt", Name = "Shalecrag Monk", Health = 900, Speed = 10, Damage = 12, Xp = 80, Gold = { 400, 600 } },
			},
			{
				Name = "The Root Caverns",
				Text = "Beneath the mountain, roots older than the clans are being torn up. Granite Brutes stand in the dark.",
				Waves = WAVES[2],
				Boss = { Foe = "Elite", Name = "Gravemaw Warden", Health = 1400, Speed = 9, Damage = 15, Xp = 150, Gold = { 900, 1200 } },
			},
			{
				Name = "Heart of the Mountain",
				Text = "Deep in the mountain caverns waits Toph Beifong, the blind earth-bending master.",
				Waves = WAVES[3],
				Boss = { Name = "Toph Beifong", Health = 3200, Speed = 9.5, Damage = 20, Xp = 250, Gold = { 2000, 2500 } },
			},
		},
	},
	Water = {
		Image = "rbxassetid://99020583212934", -- Act 1 arena screenshot
		Title = "The Drowned Court",
		Blurb = "The Tidewater Court's sea has turned black. The tides no longer return; they rise.",
		Grunt = "Drowned Lancer",
		Elite = "Abyssal Court Knight",
		Color = Color3.fromRGB(52, 152, 255),
		Acts = {
			{
				Name = "The Sunken Shore",
				Text = "The shoreline is flooding with rift-water, and the drowned are walking out of it.",
				Waves = WAVES[1],
				Boss = { Foe = "Grunt", Name = "Drowned Lancer", Health = 900, Speed = 10, Damage = 12, Xp = 80, Gold = { 400, 600 } },
			},
			{
				Name = "The Coral Halls",
				Text = "The court's coral palace is half under the sea. Abyssal Brutes hold its halls.",
				Waves = WAVES[2],
				Boss = { Foe = "Elite", Name = "Abyssal Court Knight", Health = 1400, Speed = 9, Damage = 15, Xp = 150, Gold = { 900, 1200 } },
			},
			{
				Name = "The Abyssal Throne",
				Text = "At the sunken temple sits Jinbe, the Knight of the Sea and Fish-Man Karate grandmaster.",
				Waves = WAVES[3],
				Boss = { Name = "Jinbe", Health = 3100, Speed = 10, Damage = 18, Xp = 250, Gold = { 2000, 2500 } },
			},
		},
	},
	Wind = {
		Image = "rbxassetid://124292358043159", -- Act 1 arena screenshot
		Title = "The Shattered Sky",
		Blurb = "The Skyreach islands are falling. The winds that held them up are being drained into the Rift.",
		Grunt = "Gale Shinobi",
		Elite = "Cyclone Kunoichi",
		Color = Color3.fromRGB(159, 240, 216),
		Acts = {
			{
				Name = "The Broken Bridges",
				Text = "The rope bridges between the islands are snapping. Gale Husks ride the gusts.",
				Waves = WAVES[1],
				Boss = { Foe = "Grunt", Name = "Gale Shinobi", Health = 900, Speed = 10, Damage = 12, Xp = 80, Gold = { 400, 600 } },
			},
			{
				Name = "The Cyclone Ruins",
				Text = "A ruined monastery spins in a cyclone of its own making. Cyclone Brutes guard the shrine.",
				Waves = WAVES[2],
				Boss = { Foe = "Elite", Name = "Cyclone Kunoichi", Health = 1400, Speed = 9, Damage = 15, Xp = 150, Gold = { 900, 1200 } },
			},
			{
				Name = "Eye of the Storm",
				Text = "At the Broken Cloud Summit stands Naruto Uzumaki, Sage of the Hidden Leaf.",
				Waves = WAVES[3],
				Boss = { Name = "Naruto Uzumaki", Health = 2800, Speed = 13, Damage = 18, Xp = 250, Gold = { 2000, 2500 } },
			},
		},
	},
	Lightning = {
		Image = "rbxassetid://138471750074863", -- Act 1 arena screenshot
		Title = "The Thunder Rebellion",
		Blurb = "Storms strike the Stormcall temples without end. One of the Order's own heralds has turned the lightning against them.",
		Grunt = "Thunderfallen Herald",
		Elite = "Stormbreaker Paladin",
		Color = Color3.fromRGB(250, 225, 60),
		Acts = {
			{
				Name = "The Storm Outpost",
				Text = "The watch outpost on the cloud road has gone silent. Storm Husks crackle on the walls.",
				Waves = WAVES[1],
				Boss = { Foe = "Grunt", Name = "Thunderfallen Herald", Health = 900, Speed = 10, Damage = 12, Xp = 80, Gold = { 400, 600 } },
			},
			{
				Name = "The Conductor Spires",
				Text = "The great spires that tame the storm now feed it. Volt Brutes charge the coils.",
				Waves = WAVES[2],
				Boss = { Foe = "Elite", Name = "Stormbreaker Paladin", Health = 1400, Speed = 9, Damage = 15, Xp = 150, Gold = { 900, 1200 } },
			},
			{
				Name = "The Sky Throne",
				Text = "High above the storm coils waits Sasuke Uchiha, wielder of the lightning Chidori.",
				Waves = WAVES[3],
				Boss = { Name = "Sasuke Uchiha", Health = 2800, Speed = 13, Damage = 20, Xp = 250, Gold = { 2000, 2500 } },
			},
		},
	},
}

-- Difficulty tiers: enemy health/damage and reward multipliers. Normal is
-- open; Hard needs the act cleared on Normal.
Story.DifficultyOrder = { "Normal", "Hard" }
Story.DefaultDifficulty = "Normal"
Story.Difficulties = {
	Normal = { Health = 1, Damage = 1, Reward = 1, Color = Color3.fromRGB(143, 227, 107) },
	Hard = { Health = 2.4, Damage = 1.9, Reward = 2, Color = Color3.fromRGB(255, 138, 58), Needs = "Normal" },
}
-- Saved clears from the old four tiers map onto the two that remain.
Story.LegacyDifficulty = { Easy = "Normal", Medium = "Normal", Nightmare = "Hard" }

-- Act clears can drop the story nation's home skill (Nations HomeSkill):
-- a new skill if you don't own it, or +1 level if you do. [act] = chance.
Story.SkillDrop = { [1] = 0.5 }

-- The home skill id and drop chance for clearing `act`, or nil.
function Story.SkillDropOf(nationId, act)
	local chance = Story.SkillDrop[act]
	local def = Nations.Defs[nationId]
	if chance and def and def.HomeSkill then
		return def.HomeSkill, chance
	end
	return nil
end

-- Gold paid for clearing an act, on top of what enemies drop.
Story.ClearGold = { 500, 1000, 2500 }

-- Materials never drop in combat (mobs only drop gold and XP); they are paid
-- out as one bundle when the act is cleared. "Shard", "Core" and "Essence"
-- mean the story nation's own material. Guaranteed counts scale with the
-- difficulty's Reward and the home bonus; bonus rolls are one extra each.
Story.Bundles = {
	{ -- Act 1
		Items = { { "Shard", 1 }, { "RiftShard", 3 } },
		Bonus = { { "Shard", 0.4 }, { "HuskIchor", 0.1 } },
	},
	{ -- Act 2
		Items = { { "Core", 1 }, { "Shard", 1 }, { "RiftShard", 5 } },
		Bonus = { { "Shard", 0.5 }, { "HuskIchor", 0.25 } },
	},
	{ -- Act 3
		Items = { { "Essence", 1 }, { "Core", 1 }, { "Shard", 2 }, { "RiftShard", 8 } },
		Bonus = { { "Core", 0.35 }, { "Shard", 0.5 } },
	},
}

local function materialId(nationId, id)
	if id == "Shard" then
		return Items.NationShards[nationId]
	elseif id == "Core" then
		return Items.NationCores[nationId]
	elseif id == "Essence" then
		return nationId .. "Essence"
	end
	return id
end

-- The act-clear bundle: guaranteed = { { Id, Count } }, bonus = { { Id, Chance } }.
function Story.Bundle(nationId, act, difficulty, home)
	local mult = Story.Difficulties[difficulty].Reward * (if home then Story.HomeBonus else 1)
	local def = Story.Bundles[act]
	local guaranteed, bonus = {}, {}
	for _, entry in def.Items do
		table.insert(guaranteed, { Id = materialId(nationId, entry[1]), Count = math.floor(entry[2] * mult) })
	end
	for _, entry in def.Bonus do
		table.insert(bonus, { Id = materialId(nationId, entry[1]), Chance = entry[2] })
	end
	return guaranteed, bonus
end

-- "Fire:2" style keys for the cleared-acts set; "Fire:2:Hard" records the
-- difficulty it was cleared on.
function Story.Key(nationId, act, difficulty)
	return nationId .. ":" .. act .. (if difficulty then ":" .. difficulty else "")
end

return Story
