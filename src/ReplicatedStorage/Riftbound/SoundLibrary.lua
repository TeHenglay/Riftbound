-- Every sound in the game, and which game event plays which sound.
-- StarterPlayerScripts.Riftbound.SoundFX plays them on each client.
--
-- Sound effects come from the Pro Sound Effects library that Roblox licensed for
-- every creator (uploader "ProSoundEffects"); music comes from Roblox's licensed
-- APM and DistroKid catalogues. All are public, free and safe to ship.
--
-- Most spell, combat, pickup and UI sounds are from "Pixel Combat" by Helton Yan
-- (heltonyan.itch.io/pixelcombat), CC BY 4.0: the game must credit
-- "Sound effects: Helton Yan - Pixel Combat". The player-death sting is from
-- Chequered Ink's 400 Sounds Pack (free for commercial use). Both were uploaded
-- privately by the owner.
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
	RiftBoltCast = { Ids = { 121658823184534, 104866894029516 }, Volume = 0.35, Pitch = { 0.95, 1.1 } },
	RiftBoltHit = { Ids = { 131282479801015, 94011801957710 }, Volume = 0.35, Pitch = { 0.95, 1.1 } },

	-- Fire -----------------------------------------------------------------
	FireCast = { Ids = { 134192015548215, 82915708772884 }, Volume = 0.5, Pitch = { 0.95, 1.05 } },
	FireExplode = { Ids = { 136419750833913, 123327994066045 }, Volume = 0.6, Pitch = { 0.95, 1.05 } },
	FanTheFlames = { Id = 74658953263791, Volume = 0.5 },

	-- Water ----------------------------------------------------------------
	WaveCrash = { Ids = { 107926517306411, 71001287937181 }, Volume = 0.6 },

	-- Earth ----------------------------------------------------------------
	EarthRumble = { Id = 9125869504, Volume = 0.3, Pitch = 0.8, Length = 0.5 },
	RockBurst = { Ids = { 125274851800597, 76835142099932 }, Volume = 0.6, Pitch = { 0.95, 1.05 } },

	-- Air ------------------------------------------------------------------
	WindBlast = { Ids = { 121640170557771, 107022836228252 }, Volume = 1 },

	-- Lightning ------------------------------------------------------------
	ZapFirst = { Id = 125995775704384, Volume = 0.5 },
	Zap = { Ids = { 140188901214206, 98616821053616 }, Volume = 0.8, Pitch = { 0.95, 1.15 }, Gap = 0.05 },
	ThunderCrack = { Ids = { 72222857358993, 82693638856993 }, Volume = 0.6, Gap = 0.25, Layer = { "ZapFirst" } },

	-- Fusions --------------------------------------------------------------
	SteamBurst = { Id = 9118882814, Volume = 0.5, Pitch = 0.85, Length = 1.4 },
	SteamLoop = { Id = 9113074084, Volume = 0.3, Pitch = 0.75 },
	MeteorFall = { Id = 9125645963, Volume = 0.55, Pitch = 0.7, Length = 1 },
	MeteorImpact = { Ids = { 132877989312932, 121728950168783 }, Volume = 0.75, Layer = { "FireExplode" } },
	LavaLoop = { Id = 9112752570, Volume = 0.3, Pitch = 0.45 },
	TornadoStart = { Id = 134709600120862, Volume = 0.6 },
	FireTornadoLoop = { Id = 9120610106, Volume = 0.45, Pitch = 0.8 },
	PlasmaCharge = { Id = 119095676067671, Volume = 0.45 },
	-- "Time Warp Big Explosion" (the user's pick, 2026-10-07): a tonal boom with a long tail.
	PlasmaExplode = { Ids = { 9126102254, 9126102397, 9126102402, 9126102562 }, Volume = 0.7, Pitch = 1, Length = 2.5, Layer = { "PlasmaCrackle" } },
	PlasmaCrackle = { Id = 9116274415, Volume = 0.45, Pitch = 1, Length = 1.2 },
	BoulderRoll = { Id = 9118661490, Volume = 0.55, Pitch = 0.7, Length = 1.6 },
	BoulderCrash = { Id = 9125871203, Volume = 0.6, Pitch = 0.9, Length = 1.6 },
	Blizzard = { Id = 9125629904, Volume = 0.6, Pitch = { 1, 1.1 }, Length = 1.4 },
	Freeze = { Id = 127850345401771, Volume = 0.45, Gap = 0.1 },
	LeapWhoosh = { Id = 130019457938272, Volume = 0.5 },
	GroundSlam = { Ids = { 87106924395745, 107272277405763 }, Volume = 1 },
	MagnetHum = { Id = 9125550012, Volume = 0.7, Pitch = 1.2 },
	-- The pull: a reversed whoosh sucking in, with a rising electric reversed zap on top.
	MagnetPull = { Id = 9120698917, Volume = 0.8, Pitch = 1.25, Length = 0.8, Layer = { "MagnetPullZap" } },
	MagnetPullZap = { Id = 9120984466, Volume = 0.5, Pitch = 0.9, Length = 0.8 },
	MagnetBlast = { Id = 9116274992, Volume = 0.55, Pitch = 0.9, Length = 1.4, Layer = { "RockBurst", "MagnetBoom" } },
	MagnetBoom = { Id = 9114224675, Volume = 0.6, Pitch = 1.1, Length = 1.8 },
	StormLoop = { Id = 9112853422, Volume = 0.4, Pitch = 1 },

	-- Dash and block -------------------------------------------------------
	Dash = { Ids = { 107387920423978, 88587059173651 }, Volume = 0.45, Pitch = { 1, 1.1 } },
	ShieldUp = { Id = 101879415748134, Volume = 0.45 },
	BlockHit = { Ids = { 101818717362356, 112846838372417 }, Volume = 0.9 },
	Parry = { Ids = { 131956829341009, 75621315180857 }, Volume = 0.9 },
	ParryRing = { Id = 9116394545, Volume = 0.9, Pitch = 1.4, Length = 1.2 },
	ShieldBreak = { Id = 94090259757453, Volume = 0.55 },

	-- Player ---------------------------------------------------------------
	PlayerHurt = { Ids = { 103166448217609, 107796053988946 }, Volume = 0.4, Gap = 0.2, Group = "UI" },
	PlayerDeath = { Id = 132026278313234, Volume = 0.5, Pitch = 1, Group = "UI" },

	-- Rift Husk ------------------------------------------------------------
	EnemySpawn = { Id = 74487219785978, Volume = 0.45, Layer = { "EarthRumble" } },
	HuskWindup = { Ids = { 9113980644, 9113980319 }, Volume = 0.45, Pitch = { 1.05, 1.2 }, Length = 0.6 },
	HuskSlam = { Id = 9118598279, Volume = 0.6, Pitch = { 0.9, 1 }, Length = 0.6 },
	EnemyHit = { Ids = { 122689329097985, 110670570771801, 123504504510960 }, Volume = 0.25, Pitch = { 0.95, 1.1 }, Gap = 0.08 },
	HuskDeath = { Id = 99233433897004, Volume = 0.5 },

	-- Elemental reactions --------------------------------------------------
	Conduct = { Id = 103594791893189, Volume = 0.5 },
	Evaporate = { Id = 9118884046, Volume = 0.45, Pitch = 1, Length = 1 },
	Shatter = { Id = 139281192599338, Volume = 0.55 },

	-- Flask, loot and progression ------------------------------------------
	FlaskDrink = { Id = 82906633107249, Volume = 0.5, Group = "UI" },
	Heal = { Id = 85950268306860, Volume = 0.5 },
	Coin = { Ids = { 125999707019231, 127129474740504 }, Volume = 0.35, Gap = 0.06, Group = "UI" },
	XpPickup = { Id = 132955985344340, Volume = 0.25, Pitch = { 1, 1.15 }, Gap = 0.06, Group = "UI" },
	ItemPickup = { Id = 138333127230518, Volume = 0.5, Group = "UI" },
	LevelUp = { Id = 126004530261272, Volume = 0.55 },
	StatUp = { Id = 107096409622186, Volume = 0.5, Group = "UI" },
	SkillGet = { Id = 98451543907155, Volume = 0.5, Group = "UI" },
	SkillUp = { Id = 98451543907155, Volume = 0.5, Pitch = 1.12, Group = "UI" },

	-- Forge ----------------------------------------------------------------
	ForgeOpen = { Id = 100752369665842, Volume = 0.5, Group = "UI" },
	Fuse = { Id = 9113445305, Volume = 0.55, Pitch = 0.9, Length = 1.5, Group = "UI", Layer = { "FuseShimmer" } },
	FuseShimmer = { Id = 107149510023542, Volume = 0.55, Group = "UI" },

	-- UI -------------------------------------------------------------------
	UIClick = { Ids = { 106642438444356, 127006080624447 }, Volume = 0.5, Group = "UI", Gap = 0.03 },
	UIHover = { Id = 135028017202421, Volume = 0.15, Group = "UI", Gap = 0.05 },
	UIDeny = { Id = 83910226909070, Volume = 0.45, Group = "UI" },

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
	[9120698917] = 2.55, -- MagnetPull: its suck-in peaks at 2.94 s file time; measured in game to land with the blast
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
	Firestorm = { Cast = "FireCast", Tornado = { "TornadoStart", { "FireTornadoLoop", For = "Duration" } } },
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
