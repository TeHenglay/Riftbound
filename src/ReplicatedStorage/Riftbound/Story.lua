-- Story mode: one story per nation, three acts each. Acts unlock in order
-- inside a story; every story is open from the start, and your own nation's
-- story pays out extra Essence. Shared so the story screen can show it all.
local Story = {}

-- Bonus reward multiplier for playing your own nation's story.
Story.HomeBonus = 1.5

-- Wave entry: { Count = n, Kind = "Grunt" | "Elite" }.
-- Kind stats are scaled per act by Story.Scale.
Story.Kinds = {
	Grunt = { Health = 120, Speed = 11, Damage = 6, Xp = 15, Gold = { 4, 8 } },
	Elite = { Health = 420, Speed = 9, Damage = 14, Xp = 45, Gold = { 12, 20 } },
}
Story.Scale = { 1, 1.5, 2.1 } -- health/damage per act

Story.Order = { "Fire", "Earth", "Water", "Wind", "Lightning" }

Story.Defs = {
	Fire = {
		Title = "The Ashen Uprising",
		Blurb = "The Rift has cracked open beneath the Ember Dominion. Its volcano wakes, and the forges burn with something that is not fire.",
		Grunt = "Cinder Husk",
		Elite = "Ember Brute",
		Color = Color3.fromRGB(255, 106, 43),
		Acts = {
			{
				Name = "Cinder Outskirts",
				Text = "Ash rains on the border villages. Husks made of cinder crawl out of the cracks. Push them back.",
				Waves = { { Count = 4, Kind = "Grunt" }, { Count = 6, Kind = "Grunt" }, { Count = 5, Kind = "Grunt" }, { Count = 1, Kind = "Elite" } },
			},
			{
				Name = "The Magma Forges",
				Text = "The great forges run red with rift-fire. Ember Brutes guard the bellows. Break their hold.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" }, { Count = 6, Kind = "Grunt" }, { Count = 3, Kind = "Elite" } },
			},
			{
				Name = "Caldera Throne",
				Text = "At the volcano's heart waits Pyrelord Vashra, a fallen fire-warden who opened the Rift to burn the world clean.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" } },
				Boss = { Name = "Pyrelord Vashra", Health = 3200, Speed = 9, Damage = 22, Xp = 400, Gold = { 150, 200 } },
			},
		},
	},
	Earth = {
		Title = "The Breaking Mountain",
		Blurb = "The Stonehold's sacred mountain is splitting apart. Something huge is pushing up through the rock.",
		Grunt = "Stone Husk",
		Elite = "Granite Brute",
		Color = Color3.fromRGB(176, 122, 64),
		Acts = {
			{
				Name = "The Fallen Quarry",
				Text = "Rockslides bury the quarry and husks of living stone dig out of the rubble.",
				Waves = { { Count = 4, Kind = "Grunt" }, { Count = 6, Kind = "Grunt" }, { Count = 5, Kind = "Grunt" }, { Count = 1, Kind = "Elite" } },
			},
			{
				Name = "The Root Caverns",
				Text = "Beneath the mountain, roots older than the clans are being torn up. Granite Brutes stand in the dark.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" }, { Count = 6, Kind = "Grunt" }, { Count = 3, Kind = "Elite" } },
			},
			{
				Name = "Heart of the Mountain",
				Text = "Gravemaw the Colossus, the mountain's own guardian, has been twisted by the Rift. Bring it down.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" } },
				Boss = { Name = "Gravemaw the Colossus", Health = 3600, Speed = 7, Damage = 26, Xp = 400, Gold = { 150, 200 } },
			},
		},
	},
	Water = {
		Title = "The Drowned Court",
		Blurb = "The Tidewater Court's sea has turned black. The tides no longer return; they rise.",
		Grunt = "Tide Husk",
		Elite = "Abyssal Brute",
		Color = Color3.fromRGB(52, 152, 255),
		Acts = {
			{
				Name = "The Sunken Shore",
				Text = "The shoreline is flooding with rift-water, and the drowned are walking out of it.",
				Waves = { { Count = 4, Kind = "Grunt" }, { Count = 6, Kind = "Grunt" }, { Count = 5, Kind = "Grunt" }, { Count = 1, Kind = "Elite" } },
			},
			{
				Name = "The Coral Halls",
				Text = "The court's coral palace is half under the sea. Abyssal Brutes hold its halls.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" }, { Count = 6, Kind = "Grunt" }, { Count = 3, Kind = "Elite" } },
			},
			{
				Name = "The Abyssal Throne",
				Text = "Queen Nerevyn sold the tides to the Rift for eternal life. Take back the sea.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" } },
				Boss = { Name = "Queen Nerevyn of the Deep", Health = 3000, Speed = 11, Damage = 20, Xp = 400, Gold = { 150, 200 } },
			},
		},
	},
	Wind = {
		Title = "The Shattered Sky",
		Blurb = "The Skyreach islands are falling. The winds that held them up are being drained into the Rift.",
		Grunt = "Gale Husk",
		Elite = "Cyclone Brute",
		Color = Color3.fromRGB(159, 240, 216),
		Acts = {
			{
				Name = "The Broken Bridges",
				Text = "The rope bridges between the islands are snapping. Gale Husks ride the gusts.",
				Waves = { { Count = 4, Kind = "Grunt" }, { Count = 6, Kind = "Grunt" }, { Count = 5, Kind = "Grunt" }, { Count = 1, Kind = "Elite" } },
			},
			{
				Name = "The Cyclone Ruins",
				Text = "A ruined monastery spins in a cyclone of its own making. Cyclone Brutes guard the shrine.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" }, { Count = 6, Kind = "Grunt" }, { Count = 3, Kind = "Elite" } },
			},
			{
				Name = "Eye of the Storm",
				Text = "Zephyrax the Unbound, the first wind, has broken its chains. Calm it before the sky falls.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" } },
				Boss = { Name = "Zephyrax the Unbound", Health = 2800, Speed = 14, Damage = 18, Xp = 400, Gold = { 150, 200 } },
			},
		},
	},
	Lightning = {
		Title = "The Thunder Rebellion",
		Blurb = "Storms strike the Stormcall temples without end. One of the Order's own heralds has turned the lightning against them.",
		Grunt = "Storm Husk",
		Elite = "Volt Brute",
		Color = Color3.fromRGB(250, 225, 60),
		Acts = {
			{
				Name = "The Storm Outpost",
				Text = "The watch outpost on the cloud road has gone silent. Storm Husks crackle on the walls.",
				Waves = { { Count = 4, Kind = "Grunt" }, { Count = 6, Kind = "Grunt" }, { Count = 5, Kind = "Grunt" }, { Count = 1, Kind = "Elite" } },
			},
			{
				Name = "The Conductor Spires",
				Text = "The great spires that tame the storm now feed it. Volt Brutes charge the coils.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" }, { Count = 6, Kind = "Grunt" }, { Count = 3, Kind = "Elite" } },
			},
			{
				Name = "The Sky Throne",
				Text = "Voltrex, the Fallen Herald, has seized the throne of the storm. Strike before the thunder.",
				Waves = { { Count = 6, Kind = "Grunt" }, { Count = 2, Kind = "Elite" } },
				Boss = { Name = "Voltrex the Fallen Herald", Health = 3000, Speed = 12, Damage = 22, Xp = 400, Gold = { 150, 200 } },
			},
		},
	},
}

-- Essence earned per act (by act number), before the home bonus.
Story.EssenceReward = { 3, 5, 10 }
-- Gold paid for clearing an act, on top of what enemies drop.
Story.ClearGold = { 40, 70, 150 }

function Story.EssenceId(nationId)
	return nationId .. "Essence"
end

-- "Fire:2" style keys for the cleared-acts set.
function Story.Key(nationId, act)
	return nationId .. ":" .. act
end

return Story
