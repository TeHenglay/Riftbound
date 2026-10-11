-- Uploaded UI art (generated from tools/art/build.js; re-run the build and
-- upload, then regenerate this file when the art changes).
local UIAssets = {}

-- Skill, Block and Dash icons are diamond cuts of the skill paintings
-- (tools/art/diamond_icons.py -> art/skills/).
UIAssets.Icons = {
	Block = "rbxassetid://112012682245993",
	ChainShock = "rbxassetid://86844360225493",
	Dash = "rbxassetid://124371159174926",
	Empty = "rbxassetid://72395591330314",
	Flask = "rbxassetid://138654676272137", -- Rift Flask Icon
	Fireball = "rbxassetid://74419924017617",
	Firestorm = "rbxassetid://77230934862487",
	FrostGale = "rbxassetid://123624720955178",
	Gust = "rbxassetid://127137746635559",
	MagmaBurst = "rbxassetid://102749785176378",
	MagnetQuake = "rbxassetid://125272999454600",
	MudTrap = "rbxassetid://113474387663978",
	PlasmaLance = "rbxassetid://96252575455011",
	RiftBolt = "rbxassetid://82536976070916",
	Sandstorm = "rbxassetid://99343899934911",
	SparkBolt = "rbxassetid://77127384110596",
	SteamCloud = "rbxassetid://127291523439842",
	StoneSpike = "rbxassetid://123715437415790",
	Thunderstorm = "rbxassetid://121682361605198",
	TidalWave = "rbxassetid://106996248145687",
}
-- Awakened skills (base and fused) use their skill's icon until they get
-- their own art: Icons.SteamCloudAwakened -> Icons.SteamCloud.
setmetatable(UIAssets.Icons, {
	__index = function(icons, id)
		if type(id) == "string" and id:sub(-8) == "Awakened" then
			return rawget(icons, id:sub(1, -9))
		end
		return nil
	end,
})

UIAssets.Banner = "rbxassetid://84682450012208"
UIAssets.Bar = "rbxassetid://102404203272404"
UIAssets.Coin = "rbxassetid://108533370441504" -- coin.png, cropped tight
UIAssets.Grain = "rbxassetid://81841308901533"
UIAssets.Medallion = "rbxassetid://94631780222388"
UIAssets.Row = "rbxassetid://111718829057911"
UIAssets.Slab = "rbxassetid://140075709427196"
UIAssets.Smoke = "rbxassetid://110945432262261"
UIAssets.Vignette = "rbxassetid://89782694482060"

-- Material icons: painted art with the background cut out, 512px PNGs.
UIAssets.Items = {
	RiftShard = "rbxassetid://103455951058783",
	HuskIchor = "rbxassetid://128087333822016",
	-- Tier 1: nation shards
	FireShard = "rbxassetid://89447715067591",
	WaterShard = "rbxassetid://80784583683907",
	EarthShard = "rbxassetid://95993535944433",
	WindShard = "rbxassetid://136959863326870",
	LightningShard = "rbxassetid://98777451865523",
	-- Tier 2: nation cores
	EmberCore = "rbxassetid://90042622864500",
	AbyssalPearl = "rbxassetid://114017627600101",
	GraniteCore = "rbxassetid://70637448634037",
	ZephyrCore = "rbxassetid://74355105209520",
	VoltCore = "rbxassetid://112798036141025",
	-- Tier 3: nation essences
	FireEssence = "rbxassetid://102113139296293",
	WaterEssence = "rbxassetid://107521948827613",
	EarthEssence = "rbxassetid://102271496716160",
	WindEssence = "rbxassetid://124914184670420",
	LightningEssence = "rbxassetid://99920908584513",
}
UIAssets.Bag = "rbxassetid://137592377080750"

-- Lobby menu icons (menu_* in tools/art/build.js). LobbyMenu falls back to
-- plain slabs for any id missing here.
UIAssets.Menu = {
	Store = "rbxassetid://136896002273541",
	Items = "rbxassetid://130143909477000",
	Quests = "rbxassetid://90307868195421",
	Areas = "rbxassetid://117739538401007",
	Play = "rbxassetid://115350151284711",
	Profile = "rbxassetid://130689122437479",
	Calendar = "rbxassetid://70384539768002",
	Forge = "rbxassetid://132527579649611", -- not shown anywhere yet
}

-- Nation emblems (element art on transparent backgrounds).
UIAssets.Nations = {
	Fire = "rbxassetid://139451640565307",
	Earth = "rbxassetid://139540214188705",
	Water = "rbxassetid://71271151112170",
	Wind = "rbxassetid://82529662215492",
	Lightning = "rbxassetid://126617991615926",
}

-- Nation card backgrounds: each nation's home skill painting (square).
UIAssets.NationArt = {
	Fire = "rbxassetid://104082673589492", -- Fireball
	Earth = "rbxassetid://101247793483740", -- Stone Spike
	Water = "rbxassetid://115005749981220", -- Tidal Wave
	Wind = "rbxassetid://110644424298039", -- Gust
	Lightning = "rbxassetid://101588867062802", -- Spark Bolt
}

UIAssets.Stats = {
	Focus = "rbxassetid://115007593027726",
	Might = "rbxassetid://91423927051801",
	Swiftness = "rbxassetid://140071347125819",
	Vitality = "rbxassetid://101103619797080", -- "Core Stat Icons" (thorned heart)
}

-- VFX textures (white, tinted in code). Drawn by tools/art/build.js (fx_*).
UIAssets.Fx = {
	Crescent = "rbxassetid://106045100291727",
	Crack = "rbxassetid://112272651860387", -- "Crack 3" by RandoLaPotato (Creator Store decal 121823730618727)
	Drop = "rbxassetid://74522022532912",
	Flame = "rbxassetid://130625915452508",
	Glow = "rbxassetid://137061233389795",
	Lightning = "rbxassetid://104995083860718",
	Ring = "rbxassetid://111282615971243",
	Shard = "rbxassetid://93965377953382",
	Smoke = "rbxassetid://93882910202722",
	Spark = "rbxassetid://103087071905543",
	Swirl = "rbxassetid://126992744594740",
	Telegraph = "rbxassetid://107569955420721",
}

-- 9-slice margins (pixels in the source image).
UIAssets.SlabSlice = Rect.new(48, 48, 208, 208)
UIAssets.RowSlice = Rect.new(48, 48, 464, 80)
UIAssets.BannerSlice = Rect.new(90, 40, 710, 100)
UIAssets.BarSlice = Rect.new(24, 14, 226, 34)

return UIAssets
