-- Animated (flipbook) particle textures picked from free Creator Store VFX
-- packs ("MASSIVE Vfx Pack" 99987311514598, "VFX PACK" 112672322113504 and
-- "BIG VFX PACK" 17290956157). The packs were inserted into a quarantine
-- folder, checked for scripts (none besides a read-me), and only these image
-- ids are used. Layout is the sprite-sheet grid; Mode is how a particle plays it.
--
-- A texture entry can be passed anywhere SkillVFX / StatusVFX accept a
-- particle texture; plain strings are still fine for static images.
local VfxLibrary = {
	Flame = { Id = 71869624437521, Layout = "Grid4x4", Mode = "OneShot" }, -- wispy detailed flame
	FireBurst = { Id = 86557036458920, Layout = "Grid4x4", Mode = "OneShot" }, -- stylised fire burst
	FireLick = { Id = 90245314496175, Layout = "Grid4x4", Mode = "OneShot" }, -- small flame licks
	Smoke = { Id = 87158052323401, Layout = "Grid2x2", Mode = "Random" }, -- soft smoke puffs (4 variants)
	FloorSmoke = { Id = 139366737447979, Layout = "Grid4x4", Mode = "OneShot" }, -- ground smoke roll
	Dust = { Id = 105131408419595, Layout = "Grid8x8", Mode = "OneShot" }, -- dust burst
	Impact = { Id = 130341645640774, Layout = "Grid4x4", Mode = "OneShot" }, -- star-shaped hit burst
	SideImpact = { Id = 17522349862, Layout = "Grid4x4", Mode = "OneShot" }, -- sharp hit spark
	Swirl = { Id = 95017544923091, Layout = "Grid4x4", Mode = "OneShot" }, -- spinning wind swirl
	SwirlBurst = { Id = 74232351928497, Layout = "Grid4x4", Mode = "OneShot" }, -- swirl that bursts into puffs
	Shockwave = { Id = 110426971501742, Layout = "Grid4x4", Mode = "OneShot" }, -- swirling shockwave ring
	ThunderWave = { Id = 16511741323, Layout = "Grid4x4", Mode = "OneShot" }, -- crackling shock ring
	Slash = { Id = 15081467386, Layout = "Grid4x4", Mode = "OneShot" }, -- crescent slash
	SlashThin = { Id = 16940401365, Layout = "Grid4x4", Mode = "OneShot" }, -- thin crescent slash
	Electric = { Id = 127905207342396, Layout = "Grid4x4", Mode = "OneShot" }, -- electricity zaps
	Lightning = { Id = 14431633138, Layout = "Grid4x4", Mode = "OneShot" }, -- lightning coil
	Sparkle = { Id = 115317702570755, Layout = "Grid4x4", Mode = "OneShot" }, -- star sparkles
	Splash = { Id = 84551112950263, Layout = "Grid4x4", Mode = "OneShot" }, -- water splash
	WaterFoam = { Id = 16924704235, Layout = "Grid4x4", Mode = "OneShot" }, -- churning water
	WaterCrescent = { Id = 89798462580462, Layout = "Grid4x4", Mode = "OneShot" }, -- water crescent
	Rocks = { Id = 12111686783, Layout = "Grid2x2", Mode = "Random" }, -- painted rock chunks (4 variants)
}

-- Static ground decals from the same packs.
VfxLibrary.Decals = {
	Crack = "rbxassetid://16937144632", -- glowing shattered-floor crack
	ImpactCrack = "rbxassetid://16957275379", -- impact crater
}

-- Applies a texture (string or library entry) to a ParticleEmitter.
function VfxLibrary.Apply(emitter, texture)
	if type(texture) == "table" then
		emitter.Texture = "rbxassetid://" .. texture.Id
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout[texture.Layout]
		emitter.FlipbookMode = Enum.ParticleFlipbookMode[texture.Mode]
		emitter.FlipbookStartRandom = texture.Mode == "Random"
	else
		emitter.Texture = texture
	end
end

return VfxLibrary
