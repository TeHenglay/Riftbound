-- Uploaded UI art (generated from tools/art/build.js; re-run the build and
-- upload, then regenerate this file when the art changes).
local UIAssets = {}

UIAssets.Icons = {
	Block = "rbxassetid://83635260484960",
	ChainShock = "rbxassetid://136738844608361",
	Dash = "rbxassetid://98311242245399",
	Empty = "rbxassetid://113982355002658",
	Flask = "rbxassetid://96315667475182",
	Fireball = "rbxassetid://98625522356369",
	Firestorm = "rbxassetid://77698979768335",
	FrostGale = "rbxassetid://96874784513520",
	Gust = "rbxassetid://135852996801933",
	MagmaBurst = "rbxassetid://89716643433628",
	MagnetQuake = "rbxassetid://73886640087333",
	MudTrap = "rbxassetid://138415075001101",
	PlasmaLance = "rbxassetid://73211581019620",
	RiftBolt = "rbxassetid://115248995600884",
	Sandstorm = "rbxassetid://72683305372499",
	SparkBolt = "rbxassetid://100838060488005",
	SteamCloud = "rbxassetid://127613942451312",
	StoneSpike = "rbxassetid://113644047149425",
	Thunderstorm = "rbxassetid://107012249265301",
	TidalWave = "rbxassetid://101393336222429",
}

UIAssets.Banner = "rbxassetid://84682450012208"
UIAssets.Bar = "rbxassetid://102404203272404"
UIAssets.Coin = "rbxassetid://73703220184899"
UIAssets.Grain = "rbxassetid://81841308901533"
UIAssets.Medallion = "rbxassetid://94631780222388"
UIAssets.Row = "rbxassetid://111718829057911"
UIAssets.Slab = "rbxassetid://140075709427196"
UIAssets.Smoke = "rbxassetid://110945432262261"
UIAssets.Vignette = "rbxassetid://89782694482060"

UIAssets.Items = {
	EmberCore = "rbxassetid://133390476578556",
	HuskIchor = "rbxassetid://81774452746485",
	RiftShard = "rbxassetid://136347395990865",
}
UIAssets.Bag = "rbxassetid://137592377080750"

-- Lobby menu tiles (menu_* in tools/art/build.js). LobbyMenu falls back to
-- plain slabs for any id missing here.
UIAssets.Menu = {
	Store = "rbxassetid://106487022967164",
	Items = "rbxassetid://117717009732639",
	Quests = "rbxassetid://97028418841931",
	Areas = "rbxassetid://123844829656953",
	Play = "rbxassetid://129909717567315",
	Guild = "rbxassetid://100527571727565",
	Profile = "rbxassetid://109307206721183",
	Calendar = "rbxassetid://132954542926671",
}

UIAssets.Stats = {
	Focus = "rbxassetid://89505312058081",
	Might = "rbxassetid://130407449315919",
	Swiftness = "rbxassetid://124576787127680",
	Vitality = "rbxassetid://120127868092452",
}

-- VFX textures (white, tinted in code). Drawn by tools/art/build.js (fx_*).
UIAssets.Fx = {
	Crescent = "rbxassetid://106045100291727",
	Crack = "rbxassetid://83983398208027",
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
