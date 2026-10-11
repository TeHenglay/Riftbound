# Golem and Skill VFX: Handoff

Status as of 2026-10-11 (evening). Nothing in this handoff is committed. All code, art
and tools are uncommitted in the working tree, alongside earlier uncommitted
work (see `art/models/HANDOFF.md`).

## The pipeline

1. **Blender** builds the meshes and paints textures from Python (numpy), run
   through the Blender MCP. Each skill has a folder
   `art/skill_models/<skill>/` with a `.blend`, an `.fbx` and, when
   textured, a `<Skill>_Color.png`.
2. **The user imports the FBX** in Studio with Import 3D, then clicks
   **Start Import** in the Import Queue. The Studio MCP can upload images
   but not meshes, so this step always needs them.
3. **Claude moves the imported MeshParts** into
   `ReplicatedStorage.RiftboundVFX` under the names the code expects, sets
   them anchored and non-colliding, and removes the imported Model from
   Workspace.
4. **Textures do not survive the FBX import.** Upload the PNG separately
   (`upload_image`, served from a local `python -m http.server`) and set the
   MeshPart's `TextureID`.
5. **Code** in `SkillVFX.lua` clones those templates, colours them and
   animates them. Every new piece falls back to the old look if its template
   is missing.
6. **Test** in a Studio play test (start it with `start_stop_play`): on the
   Client, disable the ScreenGuis, build a floor at y≈2000 **on the client**
   (StreamingEnabled is on and a server floor that far away never streams in),
   and lock the camera with a `RenderStepped` connection stored in
   `_G.TestCamConn` (`BindToRenderStep` from execute_luau gets cleaned up).
   On the Server, fire the skill's event through
   `ReplicatedStorage.Riftbound.Remotes.SkillFx` in a loop, then take
   screenshots. Effects are short, so screenshots often miss them; take a few.
   Stopping the play test clears everything. Event payloads are in
   `src/ServerScriptService/Riftbound/SkillEffects.lua` (search `fx({ Type =`).

Style the user approved: anime look with **black ink shade** layers (black
copies of meshes, black streaks and shards, black ink lines in textures).

## Golem VFX (done)

- **Textures:** `tools/art/golem_vfx_textures.py` writes
  `art/vfx/textures/GolemFX_*.png` (glow, spark, smoke, flame, burst, ring,
  chunks, droplet, splash, wind, arc, star, swirl, beam, crack). All are
  uploaded; the ids are at the top of `tools/art/golem_vfx_studio.luau`.
- **Builder:** `tools/art/golem_vfx_studio.luau` (run in the Edit DataModel)
  rebuilds everything:
  - element particles (`GolemFX_*` emitters) on each template in
    `ServerStorage.RiftboundAssets.Foes.<Nation>Golem`;
  - `RiftboundVFX.GolemSpawn_<Nation>`, a one-off swirl when a golem spawns
    (the user asked for the swirl only on spawn, not always on);
  - `RiftboundVFX.GolemSlam_<Nation>`, the Brute/Elite slam impact.
- **Pack:** the swirl and slam layers come from the Creator Store pack
  "Zyron Aura System" (73732620614663), kept in
  `ServerStorage.ZyronAuraSystem` as the source for rebuilds. It has no
  scripts.
- **Code:** `Foes/NationGolem.lua` fires `GolemSpawn` from `foe.Setup` and
  `GolemSlam` from the slam, through the `SkillFx` remote.
  `SkillVFX.lua` has `onGolemSpawn` and `onGolemSlam`.
- **Not done:** the golem spawn and slam have no sound. The user said not
  now.

## Skill redesign (in progress)

There are 16 skills. The user reviews each one before the next.

| Skill | State | Templates in RiftboundVFX | Notes |
|---|---|---|---|
| Fireball | done, approved | FireballCore/Mid/Outer, FireballBlastCore, FireballBlast, FireballRing | Three spinning flame shells plus a black shade shell. Blast dome and ring with a black rim. Shells are coloured in code (they import white). User approved the explosion as is. |
| Tidal Wave | done, approved | Model `TidalWaveModel` (TidalBody, TidalCrest, TidalShade, TidalStreaks) | Curling wave, painted texture (rbxassetid://76161921181195 on TidalBody), 1.7x height (`TIDAL_HEIGHT`). Rises, rolls, crashes. Water-drop icon replaced by spray streaks. |
| Stone Spike | done, approved | StoneSpikeMesh | Textured spike (rbxassetid://90486514514085). Staggered eruption, crumble, black shards, dark wedge chips. New heavy SFX: `StoneSpikeImpact` + `StoneSpikeShatter` in `SoundLibrary.lua` (Pro Sound Effects, pitched down). |
| Gust | done, approved | Model `GustModel` (GustOuter, GustOuterShade, GustInner, GustInnerShade) | Reshaped to the user's reference: low vortex of layered lime crescent arcs (16 outer, 11 inner) with ink copies. Texture rbxassetid://93821798295049. Gust uses its own lime palette `GUST_PAL`; star sparkles added; tall funnel trails removed. |
| Spark Bolt | done, approved | none | User kept the old bolt. Added `Ink` option to `lightning()` (solid black bolt on its own path), muzzle crackle, spark shower, ink shards, shock ring. |
| Steam Cloud | done, approved | none | Black wisps, black ground ring, bubbles, heat swirls, steam geyser with black puff per tick. |
| Magma Meteor | done, approved | Model `LavaPoolModel` (LavaPool, LavaRim, LavaPlates, LavaInk) | Black smoke streak, comet tail, ink shards, shockwave, embers, lava drops, pool bubbles. Blender lava pool, texture rbxassetid://71136653183731, falls back to the old cylinder pool. |
| Firestorm | done, approved | Model `FirestormModel` (FireLayer1-4, FireSpiralBottom, FireSpiralTop) | Built like halisavakis.com "tornado" write-up: 4 nested noise layers spun at different speeds (Roblox can't pan UVs), spiral planes, dissolve by swapping eroded textures (`FIRESTORM_ERODE`). Texture bakes the user's waterfall shader look: warped noise, 5-step bands, bottom/top colours, white foam at base. Atlas rbxassetid://126054946830656. Red (`FIRESTORM_RED/BLOOD`) beside black shade. New SFX: `FireTornadoIgnite` + `FireTornadoLoop` (PSE Fire Whoosh; the old loop was a water sound). |
| Plasma Lance | done, approved | none | Black ink trail/smoke, ink arcs, ember rings, plasma dome, aftershock. SFX: `PlasmaFlight` (PSE Fire Whoosh 15 + Electric Arcing 4) on ProjectileStart, `PlasmaBoom` layered under the user's `PlasmaExplode`. |
| Mudslide (`MudTrap`) | done, approved | none | Black splatter, bow-wave splashes, water spray, black splash and clods, mud wave ring, bubbling puddle. Anime water wake (`waterTrail()` with `ANIME_WATER_TRAIL` rbxassetid://97688629579971): side water walls, ground sheet, ribbon looping round the boulder. Ground track uses the strip tinted black. The user first said the trail was not good, then "yes nice" after the track fix. |
| Frost Gale | done, approved | none | Added `ANIME_ICE_TRAIL` (rbxassetid://108063404350996, new `ice` palette): 6 ice ribbons whip down the cone (every third is a black ink streak). Black shards and streaks in the breath, black ink cracks on the frozen ground, black shards when crystals shatter, frost shockwave and shard burst at release, white ring at the feet. Ice crystals are opaque (a see-through crystal let the crack decals draw over it). New SFX: `FrostWind` (+`FrostWindBlast`), `FrostIceRise`, `FrostIceShatter` (+`FrostIceShatterHigh`). |
| Chain Shock → **Thunder Serpent** | done, approved (2026-10-11) | SerpentModel.SerpentHead | The user wanted it replaced because it played like Spark Bolt and picked Thunder Serpent. Skill id stays `ChainShock` (saves, crafting, icons); `Skills.lua` now has Name "Thunder Serpent", Kind `Serpent`, Speed 48, Radius 3.5. Server `Kinds.Serpent` routes through up to `Jumps` enemies and bites anything within Radius of the head (10% less per bite); events `Serpent` (Points, Speed, Floor), `SerpentBite`, `SerpentDive`. Client `onSerpent` body is 16 neon orbs following the head's path with ink shades, water wake trail, arcs; bite = crossed jaw slashes, splash, bolt up through the victim; dive = water column, radial bolts. The orb body read as a cute worm; the user said yes to a Blender model and asked for SFX and for the wide trails back. Blender: `tools/art/thunder_serpent.py` builds `art/skill_models/thunderserpent/` (ThunderSerpent.fbx, thunderserpent.blend, ThunderSerpent_Color.png uploaded as rbxassetid://98048402932489). The user found the first pieces "shapes stuck together", so each piece is now fused into one smooth surface (`fuse()`: voxel remesh 0.03, smooth, decimate, UVs copied back with a Data Transfer). They did not want one head-to-tail body. Pieces (snout toward -Y; Roblox Size / Offset, mapped (x,y,z) -> (-x,z,y)): SerpentHead (2.863, 2.489, 4.198) / (-0.007, -0.104, -0.152); SerpentSegment (1.855, 1.53, 1.5) / (0, 0.259, 0); SerpentTail (0.683, 1.741, 2.473) / (0, 0, 0.636). The user then rejected the self-made model and picked a free Creator Store mesh: "Dragon Head" (1513601847, by Narutorobert), now `RiftboundVFX.SerpentModel.SerpentHead` (water-blue SmoothPlastic, 3.8 studs long, attribute `Orient` = CFrame.Angles(0, pi/2, 0) because its snout points +X). Code uses it with a black ink copy under it; with the head present and no SerpentSegment/SerpentTail, the body is only the water, ink and lightning trails (no orbs). The Blender files in `art/skill_models/thunderserpent/` are unused. The user needs to Ctrl+S to keep the template in the place file. SFX: `SerpentRise` (+`SerpentCrackle`), `SerpentRush` looped for `Duration`, `SerpentBite` (+`Zap`, `SerpentStatic`), `SerpentDive` (+`PlasmaCrackle`). Crafting title/description, HUD headline and CastAnimator move (`Push`) updated. |
| Quake Leap (`Sandstorm`) | done, approved | StoneSpikeMesh (reused) | Spike rings now use the painted Stone Spike mesh with the punch-up and crumble into dark chips. Takeoff: black dust, swirls, grit streaks, black ring, ink crack, rock chips; white wind trails down each side of the torso plus thinner black ink trails just outside them, all attached to the root so they follow the body (the user rejected trails spinning around the player). Slam: black ink shockwave, black dust wave, black shards and streaks, dust-and-grit column, dark wedge chips, black ink cracks over the brown, black outer ring. No SFX changes yet. Test: the player has no character in a play test until `plr:LoadCharacter()` on the Server; test the real jump by firing `Leap` with `Caster = plr` (the client launches it with physics) and `LeapSlam` once `hum.FloorMaterial` is no longer Air. Moving the root by CFrame from the server looks choppy. |
| Magnet Quake | done, approved | none | Pull: black rune circle spinning the other way, black ring closing in, black ink streaks, dark dust and rocks dragged inward, black shards spiralling into the core, small arcs (some black ink) from the core to the ground, jagged bolts alternating black ink and glow along each enemy tether (a black Beam tether looked like a stiff straight line, so it was dropped). Blast: black ink bolt beside every other discharge bolt, black ink shockwave, black smoke wave, black shards and streaks, light and dark rock chips, black ink cracks, black outer ring. The user asked for no purple: the accent is `MAGNET.Yellow`, bolt halos are `MAGNET.Amber`, pack templates use `MAGNET_TINT`. No SFX changes. Test: the client finds tether targets in `workspace.RiftEnemies` (Model with Humanoid + HumanoidRootPart); make dummies there on the Client. |
| Thunderstorm | done, approved | none | No purple (like Magnet Quake): `STORM` palette, charcoal cloud with a black smoke underbelly, gold lightning with amber halos (`STORM_TINT` on pack templates). Rain streaks (white plus black ink) and ground splashes, black swirls, black ink ring at the edge, cloud crackle with some black ink arcs. Strike (`onBolt` with `Strike`): two black ink bolts beside the gold one, black streaks, shards and smoke, gold and black shockwaves, dark chips, black ink crack over the gold. The ground ring and glow are still the Air palette (cyan). No SFX changes. |
| Rift Bolt | done, approved | none | The user likes the projectile as it is: `launchRiftBolt` is unchanged (an ink tail and ink trail were tried and reverted). Only the hit (`riftBoltImpact`) changed: black tear ring, black shards and streaks, rift shockwave, an X of rift slashes (white-pink with black copies), sparkles, a crackle, black ground ring, small violet and black scorch when it lands near the ground. Real speed is 120; test at Speed 12 to screenshot it in flight. |

**How the user wants each skill done:** keep the existing effect, add a black
ink shade and more VFX. Red alongside the black works for fire skills. Build a
Blender model only when the user asks (they did for Gust, the lava pool and
the Firestorm tornado). When a skill needs a trail or a mesh texture, use the
house style below. Add or fix SFX when asked; use Pro Sound Effects
(uploader "ProSoundEffects") from the Creator Store, which are licensed for
every creator. Wire sounds in `SoundLibrary.lua` (`SoundLibrary.Skills` maps
each skill's event Type to sounds; see the comment above it).
The user reviews every skill in Studio before moving on. They reply tersely
("nice", "move on"); "nice" after a change means approved.

**House style (approved 2026-10-11):** the 4-layer anime texture from
`tools/art/anime_layer_textures.py` (core, body, white highlights, dark ink;
palettes fire, water, rift, wind, ice, lightning), modelled on a reference
picture of glowing anime tornadoes the user sent. Run it in Blender:
`ns = {}; exec(open(path).read(), ns)`, then `ns["bake"](element, folder, name)`
for a 2x2 mesh atlas plus two eroded copies, or `ns["strip"](element)` for a
1024x256 Trail/Beam strip. Firestorm uses the atlas (rbxassetid://137367659409740,
erode 134760698364137 / 109304087267820) on a slim-waisted funnel; Mudslide and
Frost Gale use strips. Use it for other skills in each skill's colour.

Notes:
- Imports come in at 100x (or less when a part would exceed 2048 studs). Set each
  MeshPart's Size and an "Offset" attribute from the Blender bounding box,
  mapped Blender (x, y, z) -> Roblox (-x, z, y).
- Serve textures for upload with `python -m http.server 8765 --bind 127.0.0.1`
  (the user approved this) and stop it right after.
- Rojo may or may not be running; check the Studio script length against the
  file before play-testing.
- `ContentProvider:PreloadAsync` on RiftboundVFX runs at SkillVFX start so
  meshes don't flash white on first cast (in a fresh play test the first cast
  can still be white while the texture downloads).
- The Studio instance id changes when Studio restarts; call
  `list_roblox_studios` again.
- Roblox can't pan UVs or run custom shaders. Fake panning by spinning layers
  at different speeds; fake dissolves by swapping to more-eroded textures; bake
  shader looks (banding, warping, colour ramps) into the PNG.

## Other changes in this session

- **Ground crack** for every skill now uses the Creator Store decal
  "Crack 3" (image rbxassetid://112272651860387), set in `UIAssets.lua`
  (`Fx.Crack`). Fireball tints it orange. The Blender crack generator
  (`crack()` in `golem_vfx_textures.py`) is kept but no longer used.
- **Black shade** colours live in `SHADE` in `SkillVFX.lua`.

## Files touched

- `src/StarterPlayer/StarterPlayerScripts/Riftbound/SkillVFX.lua`: golem
  handlers, every skill above, `lightning()` Ink option, `waterTrail()`,
  texture preload.
- `src/ServerScriptService/Riftbound/Foes/NationGolem.lua`: spawn and slam
  events.
- `src/ReplicatedStorage/Riftbound/UIAssets.lua`: crack texture id.
- `src/ReplicatedStorage/Riftbound/SoundLibrary.lua`: Stone Spike, Firestorm
  (`FireTornadoIgnite`, `FireTornadoLoop`) and Plasma Lance (`PlasmaFlight`,
  `PlasmaBoom`) sounds.
- `tools/art/golem_vfx_textures.py`, `tools/art/golem_vfx_studio.luau`,
  `tools/art/anime_layer_textures.py`.
- `art/vfx/` (textures incl. `AnimeWaterTrail.png`, `AnimeIceTrail.png`,
  previews, `golem_vfx.blend`) and `art/skill_models/{fireball,tidalwave,
  stonespike,gust,lavapool,firestorm,sparkbolt}/` (sparkbolt is an unused
  model the user turned down; they kept the old bolt).

## Gotchas

- **Studio changes need Ctrl+S.** The templates in RiftboundVFX and the golem
  emitters live in the place file, not in the repo.
- **Import and Edit-mode work fail during a play test.** Stop the play test
  first.
- **FBX textures don't import.** Always upload the PNG and set TextureID.
- **Imported meshes come in white.** Colour them in code or via a texture.
- **Rojo syncs only `src/`.** To run a long Luau script in Studio, copy it
  into `src/ReplicatedStorage/Riftbound/` as a temporary ModuleScript,
  `require` it, then delete the file.
- **Roblox moderates uploads.** Keep textures plainly abstract.
- **Commits:** ask the user before committing or pushing. Ignore
  `*.blend1` and `*.fbm/`.
