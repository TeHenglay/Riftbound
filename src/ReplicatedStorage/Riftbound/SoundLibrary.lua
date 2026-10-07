-- Every sound in the game, and which game event plays which sound.
-- StarterPlayerScripts.Riftbound.SoundFX plays them on each client.
--
-- Sound effects come from the Pro Sound Effects library that Roblox licensed for
-- every creator (uploader "ProSoundEffects"); music comes from Roblox's licensed
-- APM and DistroKid catalogues. All are public, free and safe to ship.
--
-- Sound fields:
--   Id      one asset id, or Ids = { ... } to pick one at random each play
--   Volume  0-1 (multiplied by the sound's group volume)
--   Pitch   number, or { min, max } for a random pitch each play (also speeds it up)
--   Length  seconds before the sound fades out (trims long library takes)
--   Start   seconds into the file to start from (per-file values go in SoundLibrary.Starts)
--   Group   "SFX" (default), "UI", "Music" or "Ambient"
--   Range   studs before a 3D sound fades to silence (default 140)
--   Gap     minimum seconds between two plays of this sound (stops stacking)
--   Layer   names of other sounds to play at the same time
local SoundLibrary = {}

SoundLibrary.GroupVolumes = { SFX = 0.8, UI = 0.6, Music = 0.3, Ambient = 0.35 }

SoundLibrary.Sounds = {
	-- Rift Bolt (basic attack) --------------------------------------------
	RiftBoltCast = { Ids = { 9125648149, 9125648134, 9125647857 }, Volume = 0.3, Pitch = { 1.15, 1.35 }, Length = 0.45 },
	RiftBoltHit = { Id = 9116275998, Volume = 0.25, Pitch = { 1.4, 1.7 }, Length = 0.3 },

	-- Fire -----------------------------------------------------------------
	FireCast = { Ids = { 9114446852, 9114446802 }, Volume = 0.55, Pitch = { 0.95, 1.1 }, Length = 0.9 },
	FireExplode = { Id = 9114554567, Volume = 0.6, Pitch = { 1, 1.15 }, Length = 1.6 },
	FanTheFlames = { Id = 9114446277, Volume = 0.5, Pitch = 1.1, Length = 1 },

	-- Water ----------------------------------------------------------------
	WaveCrash = { Ids = { 9120589380, 9120585252 }, Volume = 0.6, Pitch = { 0.9, 1 }, Length = 1.8 },

	-- Earth ----------------------------------------------------------------
	EarthRumble = { Id = 9125869504, Volume = 0.3, Pitch = 0.8, Length = 0.5 },
	RockBurst = { Ids = { 9118612665, 9118613208, 9118614058 }, Volume = 0.65, Pitch = { 0.95, 1.1 }, Length = 1.6 },

	-- Air ------------------------------------------------------------------
	WindBlast = { Id = 9120769331, Volume = 0.6, Pitch = { 1, 1.15 }, Length = 1.4 },

	-- Lightning ------------------------------------------------------------
	ZapFirst = { Id = 9120985853, Volume = 0.5, Pitch = { 1, 1.1 }, Length = 0.8 },
	Zap = { Ids = { 9114277338, 9114277403, 9114277601 }, Volume = 0.4, Pitch = { 1.05, 1.3 }, Length = 0.45, Gap = 0.05 },
	ThunderCrack = { Id = 9120021794, Volume = 0.55, Pitch = { 1, 1.15 }, Length = 2.2, Gap = 0.25, Layer = { "ZapFirst" } },

	-- Fusions --------------------------------------------------------------
	SteamBurst = { Id = 9118882814, Volume = 0.5, Pitch = 0.85, Length = 1.4 },
	SteamLoop = { Id = 9113074084, Volume = 0.3, Pitch = 0.75 },
	MeteorFall = { Id = 9125645963, Volume = 0.55, Pitch = 0.7, Length = 1 },
	MeteorImpact = { Id = 9114224675, Volume = 0.75, Pitch = { 0.95, 1.05 }, Length = 2.6, Layer = { "FireExplode" } },
	LavaLoop = { Id = 9112752570, Volume = 0.3, Pitch = 0.45 },
	FireTornadoLoop = { Id = 9120610106, Volume = 0.45, Pitch = 0.8 },
	PlasmaCharge = { Id = 9120985853, Volume = 0.45, Pitch = 0.8, Length = 0.5 },
	-- "Time Warp Big Explosion" (the user's pick, 2026-10-07): a tonal boom with a long tail.
	PlasmaExplode = { Ids = { 9126102254, 9126102397, 9126102402, 9126102430, 9126102562, 9126102564 }, Volume = 0.7, Pitch = 1, Length = 2.5, Layer = { "PlasmaCrackle" } },
	PlasmaCrackle = { Id = 9116274415, Volume = 0.45, Pitch = 1, Length = 1.2 },
	BoulderRoll = { Id = 9118661490, Volume = 0.55, Pitch = 0.7, Length = 1.6 },
	BoulderCrash = { Id = 9125871203, Volume = 0.6, Pitch = 0.9, Length = 1.6 },
	Blizzard = { Id = 9125629904, Volume = 0.6, Pitch = { 1, 1.1 }, Length = 1.4 },
	Freeze = { Id = 9118762653, Volume = 0.4, Pitch = 1.4, Length = 0.8, Gap = 0.1 },
	LeapWhoosh = { Id = 9125647922, Volume = 0.45, Pitch = 0.75, Length = 0.9 },
	GroundSlam = { Id = 9118609396, Volume = 0.75, Pitch = { 0.85, 0.95 }, Length = 2 },
	MagnetHum = { Id = 9125550012, Volume = 0.7, Pitch = 1.2 },
	-- The pull: a reversed whoosh sucking in, with a rising electric reversed zap on top.
	MagnetPull = { Id = 9120698917, Volume = 0.8, Pitch = 1.25, Length = 0.8, Layer = { "MagnetPullZap" } },
	MagnetPullZap = { Id = 9120984466, Volume = 0.5, Pitch = 0.9, Length = 0.8 },
	MagnetBlast = { Id = 9116274992, Volume = 0.55, Pitch = 0.9, Length = 1.4, Layer = { "RockBurst", "MagnetBoom" } },
	MagnetBoom = { Id = 9114224675, Volume = 0.6, Pitch = 1.1, Length = 1.8 },
	StormLoop = { Id = 9112853422, Volume = 0.4, Pitch = 1 },

	-- Dash and block -------------------------------------------------------
	Dash = { Ids = { 9113840530, 9113840096 }, Volume = 0.45, Pitch = { 1.15, 1.3 }, Length = 0.5 },
	ShieldUp = { Id = 9125646705, Volume = 0.35, Pitch = 1.2, Length = 0.6 },
	BlockHit = { Ids = { 9119072660, 9119072674 }, Volume = 0.55, Pitch = { 0.95, 1.05 }, Length = 0.8 },
	Parry = { Id = 9119747138, Volume = 0.6, Pitch = 1.15, Length = 0.8, Layer = { "ParryRing" } },
	ParryRing = { Id = 9116394545, Volume = 0.9, Pitch = 1.4, Length = 1.2 },
	ShieldBreak = { Id = 9114855870, Volume = 0.6, Pitch = 0.8, Length = 1.2 },

	-- Player ---------------------------------------------------------------
	PlayerHurt = { Id = 9113520892, Volume = 0.45, Pitch = { 0.9, 1.1 }, Length = 0.5, Gap = 0.2, Group = "UI" },
	PlayerDeath = { Id = 9125652949, Volume = 0.6, Pitch = 1, Group = "UI" },

	-- Rift Husk ------------------------------------------------------------
	EnemySpawn = { Id = 9125646252, Volume = 0.35, Pitch = 0.7, Length = 1.2, Layer = { "EarthRumble" } },
	HuskWindup = { Ids = { 9113980644, 9113980319 }, Volume = 0.45, Pitch = { 1.05, 1.2 }, Length = 0.6 },
	HuskSlam = { Id = 9118598279, Volume = 0.6, Pitch = { 0.9, 1 }, Length = 0.6 },
	EnemyHit = { Id = 9118623491, Volume = 0.3, Pitch = { 0.85, 1.15 }, Length = 0.4, Gap = 0.08 },
	HuskDeath = { Id = 9114855870, Volume = 0.55, Pitch = { 1, 1.15 }, Length = 1.4 },

	-- Elemental reactions --------------------------------------------------
	Conduct = { Id = 9116276946, Volume = 0.5, Pitch = 1.1, Length = 0.9 },
	Evaporate = { Id = 9118884046, Volume = 0.45, Pitch = 1, Length = 1 },
	Shatter = { Id = 9114856749, Volume = 0.55, Pitch = 1.1, Length = 1 },

	-- Flask, loot and progression ------------------------------------------
	FlaskDrink = { Ids = { 9114171855, 9114172114 }, Volume = 0.5, Pitch = 1, Group = "UI" },
	Heal = { Id = 9116394545, Volume = 0.9, Pitch = 1.1, Length = 1.5 },
	Coin = { Id = 9113849375, Volume = 0.3, Pitch = { 1.2, 1.4 }, Length = 0.35, Gap = 0.06, Group = "UI" },
	XpPickup = { Id = 9116395085, Volume = 0.4, Pitch = { 1.5, 1.8 }, Length = 0.5, Gap = 0.06, Group = "UI" },
	ItemPickup = { Id = 9116395089, Volume = 0.45, Pitch = 1.6, Length = 0.6, Group = "UI" },
	LevelUp = { Id = 9119447936, Volume = 0.6, Pitch = 1, Length = 2.5, Layer = { "LevelUpGlow" } },
	LevelUpGlow = { Id = 9116395089, Volume = 0.5, Pitch = 0.9, Length = 2.5 },
	StatUp = { Id = 9116394876, Volume = 0.4, Pitch = 1.25, Length = 0.8, Group = "UI" },
	SkillGet = { Id = 9116395089, Volume = 0.5, Pitch = 1.1, Length = 1.5, Group = "UI" },
	SkillUp = { Id = 9116395089, Volume = 0.5, Pitch = 1.3, Length = 1.2, Group = "UI" },

	-- Forge ----------------------------------------------------------------
	ForgeOpen = { Id = 9125646712, Volume = 0.45, Pitch = 0.9, Length = 1.4, Group = "UI" },
	Fuse = { Id = 9113445305, Volume = 0.55, Pitch = 0.9, Length = 1.5, Group = "UI", Layer = { "FuseShimmer" } },
	FuseShimmer = { Id = 9119447936, Volume = 0.5, Pitch = 1.15, Length = 2, Group = "UI" },

	-- UI -------------------------------------------------------------------
	UIClick = { Id = 9119717523, Volume = 0.45, Pitch = { 1, 1.1 }, Group = "UI", Gap = 0.03 },
	UIHover = { Id = 9119717529, Volume = 0.12, Pitch = 1.6, Group = "UI", Gap = 0.05 },
	UIDeny = { Id = 9119717523, Volume = 0.4, Pitch = 0.6, Group = "UI" },

	-- Music and ambience -----------------------------------------------------
	MusicExplore = { Id = 92586093726730, Volume = 0.8, Group = "Music" }, -- "The Sunken Vault (Dungeon Ambience)"
	MusicCombat = { Id = 1848159364, Volume = 0.7, Group = "Music" }, -- APM "Darkness On The Edge Of Time D"
	AmbientRift = { Id = 9125351615, Volume = 0.5, Group = "Ambient" }, -- low otherworldly rumble
}

-- Leading silence to skip in each file (seconds into the file), measured in
-- Studio with an AudioAnalyzer: just before the level first passes 0.005 (0.02 for
-- the slow fade-ins, so they are loud straight away).
SoundLibrary.Starts = {
	[9113840530] = 0.96, -- Dash
	[9113840096] = 0.92, -- Dash
	[9125646705] = 0.79, -- ShieldUp
	[9125646712] = 1.26, -- ForgeOpen
	[9125629904] = 0.83, -- Blizzard
	[9114172114] = 0.47, -- FlaskDrink
	[9114171855] = 0.17, -- FlaskDrink
	[9118884046] = 0.49, -- Evaporate
	[9114856749] = 0.46, -- Shatter
	[9119447936] = 0.3, -- LevelUp, FuseShimmer
	[9125645963] = 0.3, -- MeteorFall
	[9113074084] = 0.39, -- SteamLoop
	[9125550012] = 0.28, -- MagnetHum
	[9125871203] = 0.28, -- BoulderCrash
	[9118609396] = 0.24, -- GroundSlam
	[9118882814] = 0.19, -- SteamBurst
	[9120985853] = 0.21, -- ZapFirst, PlasmaCharge
	[9118762653] = 0.09, -- Freeze
	[9114855870] = 0.17, -- ShieldBreak, HuskDeath
	[9120021794] = 0.15, -- ThunderCrack
	[9112752570] = 0.11, -- LavaLoop
	[9114446277] = 0.09, -- FanTheFlames
	[9114446802] = 0.17, -- FireCast
}

-- Which sound plays for each SkillFx event (Type) of each skill.
-- An entry is a sound name, or a table:
--   { "Sound", After = "Delay" }   wait the event's Delay field (or a number) first
--   { "Sound", For = "Duration" }  loop the sound for the event's Duration field
--   { "Sound", If = "Strike" }     only when the event's Strike field is true
--   { "Sound", Unless = "Strike" } only when it is not
-- or a list of entries to play several.
SoundLibrary.Skills = {
	RiftBolt = { Cast = "RiftBoltCast", ProjectileEnd = "RiftBoltHit" },
	Fireball = { Cast = "FireCast", ProjectileEnd = "FireExplode" },
	TidalWave = { Line = "WaveCrash" },
	StoneSpike = { Strike = { "EarthRumble", { "RockBurst", After = "Delay" } } },
	Gust = { Nova = { "WindBlast", After = "Windup" } },
	SparkBolt = { Bolt = { { "ZapFirst", If = "First" }, { "Zap", Unless = "First" } } },

	SteamCloud = { Zone = { "SteamBurst", { "SteamLoop", For = "Duration" } } },
	MagmaBurst = {
		Cast = "FireCast",
		Meteor = { "MeteorFall", { "MeteorImpact", After = "Delay" }, { "LavaLoop", After = "Delay", For = "Duration" } },
	},
	Firestorm = { Cast = "FireCast", Tornado = { "WindBlast", { "FireTornadoLoop", For = "Duration" } } },
	PlasmaLance = { Cast = "PlasmaCharge", ProjectileEnd = "PlasmaExplode" },
	MudTrap = { Roller = { { "BoulderRoll", After = "Windup" } }, RollerEnd = "BoulderCrash" },
	FrostGale = { Cone = { { "Blizzard", After = "Windup" } } },
	ChainShock = { Bolt = { { "ZapFirst", If = "First" }, { "Zap", Unless = "First" } } },
	Sandstorm = { Leap = "LeapWhoosh", LeapSlam = "GroundSlam" },
	MagnetQuake = { Magnet = { "MagnetPull", { "MagnetHum", For = "PullTime" } }, MagnetBlast = "MagnetBlast" },
	Thunderstorm = {
		Zone = { "ZapFirst", { "StormLoop", For = "Duration" } },
		Bolt = { { "ThunderCrack", If = "Strike" }, { "Zap", Unless = "Strike" } },
	},
}

-- Elemental reactions (the enemy's Reaction attribute) and other status cues.
SoundLibrary.Reactions = {
	Conduct = "Conduct",
	Evaporate = "Evaporate",
	Shatter = "Shatter",
	["Fan the Flames"] = "FanTheFlames",
}

return SoundLibrary
