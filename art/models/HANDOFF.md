# Nation Golems: Blender Handoff

Five element golems (Fire, Earth, Water, Wind, Lightning) built in Blender as the
story-mode wave mobs. They replace every story wave mob. The old named grunt and
elite foes became the Act 1 and Act 2 bosses.

Status as of 2026-10-11:

- **Done:**
  - all five golems are modelled, rigged, animated, baked and exported;
  - they are imported into Studio under `ServerStorage.RiftboundAssets.Foes`;
  - the story code uses them, and a Fire Act 1 test ran without errors.
- **Not done:** nothing is committed. The story code, the art and the tools are
  all uncommitted in the working tree.

## The look

All five golems share the same body, built in Roblox's blocky R15 style:

- a slim torso;
- a classic Roblox head (an upright cylinder with rounded rims);
- slim hands;
- no face except two angry glowing eyes;
- a glowing chest core.

There are no spikes, horns or shards anywhere. The user asked for them all to
be removed.

| Nation | In-game name | Surface | Glow colour |
|---|---|---|---|
| Fire | Magma Golem | dark basalt plates split by lava seams | orange, yellow-white |
| Earth | Moss Golem | brown stone, moss on upward faces | soft green veins, green crystal core |
| Water | Tide Golem | smooth rippling water (not rock), caustic light lines, foam on top | cyan |
| Wind | Gale Golem | misty grey-teal body, diagonal swirling streaks | mint |
| Lightning | Storm Golem | storm-dark stone, jagged branching bolts | yellow (the user changed it from violet) |

The user approved each look in the thread before it was exported. Keep these
looks unless the user asks for changes.

## Files

Each nation has its own folder, `art/models/<nation>/`. Taking Fire as the
example:

| File | What it is |
|---|---|
| `fire_golem.blend` | Working file. Procedural parts, rig, actions, baked low-poly copy. |
| `FireGolem.fbx` | One skinned mesh (about 18k tris) on the R15 armature. Not used in game yet. |
| `FireGolem_Idle/Walk/Attack.fbx` | Armature-only animation clips, one per file. Not used in game yet. |
| `FireGolem_Parts.fbx` | **The one the game uses.** Five meshes: Body, ArmL, ArmR, LegL, LegR. |
| `textures/FireGolem_{Color,Normal,Roughness,Emissive}.png` | 2048px baked maps, shared by every export. |
| `FireGolem.fbm/` | Texture copies the FBX exporter writes. Safe to regenerate. |
| `*_preview.png`, `fire_golem_face.png`, `fire_golem_anim_preview.mp4` | Renders shown to the user. |
| `*.blend1` | Blender autosave backups. Do not commit. |

There are two scripts in `tools/art/`. Run them inside Blender, for example
through the Blender MCP with `runpy.run_path(...)`:

- **`export_golem.py`** runs
  `export_golem(PREFIX, COLLECTION, RIG, OUT_DIR)`. It builds the low-poly copy,
  bakes the four maps in Cycles from the high-detail parts, and writes the
  skinned FBX plus the three animation FBXs.
- **`export_golem_parts.py`** runs `export_parts(PREFIX, OUT_DIR)`. It splits the
  baked mesh into the five FoeRig parts by vertex group, turns the copy to face
  -Z in Roblox, and writes `<Prefix>_Parts.fbx`.

## How a golem .blend is built

**Collection.** `<Nation>Golem` holds the 15 R15 parts: Head, UpperTorso,
LowerTorso, and Left/Right UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot.
It also holds the extras Core, EyeL and EyeR, and the armature
`<Nation>GolemRig`. One Blender unit is one stud. The golem stands on z = 0,
faces -Y and is about 5.4 studs tall.

**Surface detail.** Each body part is a beveled box with a Geometry Nodes
modifier:

- `MagmaRock` is used by Fire, Earth and Lightning. It subdivides the mesh,
  stores a world-space `rest` attribute, and displaces it with noise lumps plus
  Voronoi crack grooves.
- `WaterBody` (Water) and `WindBody` (Wind) are smooth. They use Catmull-Clark
  subdivision with gentle noise ripples.

**Materials.** Every material reads the `rest` attribute, so cracks and streaks
stick to the surface when the rig moves:

- MagmaRock / EarthRock / StormRock use Voronoi distance-to-edge for the glowing
  seams. StormRock also bends its seams with noise so they look like jagged
  bolts.
- WaterSurface uses noise-warped Voronoi caustics, a fresnel rim and foam on top.
- WindSurface uses a diagonal Wave texture (saw profile) for the streaks.

**Rig.** Bone names match R15: HumanoidRootPart, LowerTorso, UpperTorso, Head,
and Left/Right UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot. Each part has
one vertex group, weighted 1.0 to its bone, followed by an Armature modifier
named `Rig`.

**Actions.**

| Action | Frames | Motion |
|---|---|---|
| Idle | 1–81, loops | breathing sway |
| Walk | 1–41, loops | stomp in place, no root motion |
| Attack | 1–51 | arms overhead, crouch, two-fist slam on frame 22 |

An NLA track named "Preview" chains the three actions for the preview render.

**Bake and export copies.** `<Nation>Golem_HP` is the joined high-detail mesh,
hidden after the bake. `<Nation>Golem` is the baked low-poly mesh, made from the
base parts with grooves off and subdivision 0, using smart-UV and the material
`<Nation>Golem_Baked`.

## In game

**Studio** (done by another session):

- `ServerStorage.RiftboundAssets.Foes.{Fire,Earth,Water,Wind,Lightning}Golem`
  each hold the MeshParts Body, ArmL, ArmR, LegL and LegR.
- Each part has a SurfaceAppearance using the baked maps.
- The old `Minions.Lightning` and `FoeSources.Gen_M_Lightning` were deleted
  because Roblox moderation had removed a mesh from them.

**Code** (all uncommitted):

- **`Foes/NationGolem.lua`** is the golem foe for each nation. It sets the size
  per wave kind: Swarmer 0.75, Grunt 1, Brute 1.3, Elite 1.6. Brutes and Elites
  get a ground slam. If there is no Studio template, it builds a block golem in
  the element's colours.
- **`NationFoes.lua`**: `Spawn` now spawns the golem for every wave kind. The
  new `SpawnFoe` spawns the named foe (Ashen Ronin and so on) as a boss.
- **`StoryService.lua`**: when a boss has `Foe` set, it is spawned through
  `SpawnFoe` and scaled to 1.5x. Act 3 anime bosses are unchanged.
- **`Story.lua`**: Act 1 and Act 2 of each nation now have a `Boss` entry.
  - Act 1 uses `Foe = "Grunt"`, 900 health.
  - Act 2 uses `Foe = "Elite"`, 1400 health.

  This file already held another thread's uncommitted changes (Swarmer and
  Brute kinds, anime Act 3 bosses). The edits above sit on top of them.

The game moves the five-part golems with the client's procedural
EnemyAnimator, through FoeRig's Motor6Ds. The Blender Idle, Walk and Attack
clips are not used yet.

## Known issues and gotchas

- **The FBX imports 100x too big.** The FBX unit setting makes Studio read the
  file at 100x. The import session scaled the golems back down by hand. For
  future exports, either export with `apply_scale_options='FBX_SCALE_UNITS'` or
  set the importer's unit correctly, and check the size after importing.
- **Left and right are mirrored in the R15 rig.** The parts and bones named
  `Left...` sit on Blender -X. With the golem facing -Y, that is its right
  side.
  - `export_golem_parts.py` corrects for this: Left becomes ArmR and LegR.
  - The skinned `<Nation>Golem.fbx` and the animation FBXs still carry the
    mirrored names. Fix this before using them as a real R15 Humanoid rig: swap
    the bone and vertex group names, or mirror the parts.
- **Water is opaque in game.** The textures can't carry transparency, so the
  Water golem looks like solid water in Roblox.
- **Fine seams.** Smart-UV split the beveled boxes into many small islands, so
  faint texture seams can show close up. A hand-made UV unwrap would fix this.
- **Small rock flakes** stick up along the head rims of the rock golems. They
  are hard to see at game distance.
- **The working-tree copy is big.** `art/models` is about 370 MB:
  - `.blend` files about 70 MB;
  - `.blend1` backups about 70 MB;
  - `.fbm` copies about 140 MB;
  - textures about 70 MB;
  - FBX files about 8 MB.

  Before committing, ignore `*.blend1` and `*.fbm/`, and consider Git LFS for
  `.blend` files and textures.

## Ideas for later

- Use the Blender animations in game: an AnimationController with uploaded
  Idle, Walk and Attack, on the skinned FBX once the left/right names are fixed.
- Add hit and death animations. They were offered, but the user hasn't asked
  for them.
- Add a per-golem emissive in Studio (SurfaceAppearance emissive) from
  `<Nation>Golem_Emissive.png`, if the place's SurfaceAppearance version
  supports it.
