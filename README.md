# Riftbound

A Hades-style roguelike for Roblox where you collect element skills and fuse
pairs of them into new skills at the Forge.

## Status

Step (a) is done: the element and fusion system, combat, HUD and a test arena.
Next up: (b) room-by-room runs and real enemies, (c) the reward-choice screen
after each room, (d) a boss, permanent upgrades and saving, (e) art and polish.

## Controls (playtest)

| Input | Action |
| --- | --- |
| WASD | Move |
| Hold left mouse | Rift Bolt (basic attack, aims at cursor) |
| Q / E | Equipped skills |
| Shift | Dash |
| F | Interact (take a shrine's skill, open the Forge, refill at the Rift Well) |
| R | Drink the Rift Flask |
| B | Open the Backpack |
| C | Open Attributes (spend stat points) |
| Mouse wheel | Zoom |

## Levels, XP and gold

- Rift Husks drop XP orbs (blue) and gold coins when they die: 15 XP and 4-8
  gold each. Walk near a drop and it flies to you.
- XP needed per level: `40 * level ^ 1.35` (40, 102, 176, 260, ...), up to level 50.
- Each level gives +10 max health (fully healed on level up) and +5% skill damage.
- Level and gold show above the skill bar, in the top-right corner and in the player list.
- Gold isn't spent on anything yet. `ProgressionService.SpendGold` is ready for a shop.
- Progress resets when you leave; saving comes with the meta-progression step.
- Tuning: curve and bonuses are in `src/ReplicatedStorage/Riftbound/Progression.lua`;
  drop amounts per enemy are in `TestArena.server.lua` (`Xp`, `Gold`).

## Lobby menu

- In your nation's lobby, Shattered Obsidian buttons line the screen edges:
  **Store**, **Items**, **Quests**, **Areas**, **Play** on the left and
  **Profile** and **Calendar** on the right. They slide away when you
  enter the Rift (`InRift`) and stay hidden on the nation select screen.
- Items opens the Backpack (B). Play opens a full-screen mode select
  (`PlayScreen.lua`): your Riftwalker with level and name on the left, and
  Story, Raid (locked below level 25), Training and Daily Challenge cards on
  the right. Training (the current arena) fires `EnterRift("Training")` and the
  server sets `MatchMode`; the other cards are coming in a future update.
  Profile shows your avatar, nation, level, gold and
  attributes. Store opens the market and Areas offers travel once the
  Crossroads lobby provides them; until then they, Quests and Calendar open "coming soon"
  panels for now.
- Code: `src/StarterPlayer/StarterPlayerScripts/Riftbound/LobbyMenu.lua`. Tile art
  is `menu_*` in `tools/art/build.js`; its uploaded ids go in `UIAssets.Menu`.

## Rift Flask

- Press **R** to drink: after a short sip (you move at half speed) it restores
  35% of your max health. You start with 3 charges.
- The flask holds 3 charges. The **Rift Well** in the arena refills them (F),
  and levelling up refills them too.
- Tuning lives at the top of `src/ServerScriptService/Riftbound/FlaskService.lua`.

## Skill effects and cast animations

- Skills are resolved on the server (`SkillEffects.lua`), which fires the
  `SkillFx` remote; every client renders the visuals in `SkillVFX.lua`
  (particles, beams, trails, ground decals, debris, light flashes and camera
  shake via `CameraRig.Shake`). Particle textures are drawn by
  `tools/art/build.js` (`fx_*`) and listed in `UIAssets.Fx`.
- `CastAnimator.lua` layers a procedural cast move over the walk animation on
  the player's R15 joints (works with Motor6D and AnimationConstraint joints):
  flick (basic attack), throw (projectiles), push (lines), burst (novas),
  slam (strikes), summon (zones), point (chains) and a dash lean, with glowing
  hands in the skill's colour. Your own casts animate instantly; other players'
  casts animate from the server's Cast event.

- `StatusVFX.lua` shows status effects on enemies from the server's
  `Status_<Name>` attributes: Burn (flames, embers, smoke, flickering glow),
  Soak (dripping water, mist, ripples), Shock (crackling arcs, sparks, flicker),
  Slow (cold mist) and Stun (crystals orbiting the head), plus a burst when an
  elemental reaction fires (Conduct, Evaporate, Fan the Flames, Shatter).
- Workspace streaming is on, so client effect modules rescan enemies every half
  second instead of waiting once for their parts.

- Animated flipbook textures (flames, smoke, impacts, swirls, slashes,
  electricity, water, rocks, cracks) come from free Creator Store VFX packs and
  are listed in `src/ReplicatedStorage/Riftbound/VfxLibrary.lua` with their
  sprite-sheet layout. The packs were inserted into
  `ServerStorage.VFXQuarantine`, scanned (no scripts besides a read-me) and
  only their image ids are used; the folder can be deleted to keep the place small.

## Rift Husk model

- The Husk is an AI-generated mesh (Studio mesh generation), split into body,
  arms and legs with Studio's AI segmentation. The jointed template lives in the
  place at `ServerStorage.RiftboundAssets.RiftHuskRig` (the unsplit mesh is kept as
  `RiftHusk`). These are **not** in this repo, so save the place file; without
  them the Husk falls back to the old blocky body.
- `Enemies.lua` joins the pieces with Motor6Ds (waist, shoulders, hips) and
  `EnemyAnimator` (client) animates them: a stride-matched walk with arms swinging
  opposite the legs, idle breathing, a red-glowing 0.4 s windup with both arms
  raised, a two-handed slam with a forward lunge (dash away to dodge), a hit
  flinch and flash, a stun shake, a spawn rise and a death slump into a burst of
  rift crystal shards.

## Attributes (stat points)

- Every level gained gives **1 stat point**. Press **C** (or click the level
  medallion, which shows a "+N" badge while points are unspent) to spend them:
  - **Vitality**: +10 max health per rank
  - **Might**: +5% skill damage per rank
  - **Swiftness**: +4% movement speed per rank
  - **Focus**: -4% skill cooldowns per rank
- Each stat goes up to rank 10. Values live in `src/ReplicatedStorage/Riftbound/Stats.lua`.

## Backpack and loot

- Press **B** (or click the bag under your gold) to open the Backpack:
  equipment (LMB, Q, E, Shift, Flask), stats, collected items and powers.
- Rift Husks sometimes drop materials that fly to you like gold:
  Rift Shard (common, 60%), Husk Ichor (uncommon, 25%), Ember Core (rare, 6%).
  They are for crafting later. Items live in `src/ReplicatedStorage/Riftbound/Items.lua`,
  drop chances in `TestArena.server.lua` (`Loot`).
- The arrow tab on the Arsenal panel slides it off-screen and back.

## How fusion works

- Five elements: Fire, Water, Earth, Air, Lightning. Each grants one base skill.
- Fusing two base skills of different elements consumes both and gives the
  fused skill at the higher of the two levels (+1 if you already own it).
- Every pair has a fusion (10 total), e.g. Fire + Water = Steam Cloud.
- Elemental reactions: Lightning on a Soaked enemy deals x1.5 ("Conduct"),
  Fire on Soaked x1.25, Air on Burning x1.3, Earth on Stunned x1.4.
- To add a fusion or skill, add one entry to
  `src/ReplicatedStorage/Riftbound/Skills.lua`; `Merge.lua` picks up any skill
  with two elements automatically.

## Code layout

`src/` mirrors the Studio hierarchy (Rojo naming: `.server.lua` = Script,
`.client.lua` = LocalScript, plain `.lua` = ModuleScript).

- `ReplicatedStorage/Riftbound/` – shared data: `Elements`, `Skills`, `Merge`
- `ServerScriptService/Riftbound/`
  - `Main` – remotes, casting (the server validates every cast and cooldown)
  - `BuildService` – owned skills, slots, levels, fusion
  - `SkillEffects` – hit detection, damage and visuals per skill kind
  - `Enemies` – enemy registry, damage, status effects, test dummy rig
  - `TestArena` – shrines, Forge and dummy respawns; Studio-only debug hook
- `StarterPlayer/StarterPlayerScripts/Riftbound/` – `ClientMain`, `CameraRig`
  (top-down camera), `Controls`, `HUD` (skill bar, skill list, Forge screen)

## Tools

Needs Roblox Studio open with its MCP server enabled.

```bash
node tools/sync.js
```

Pushes everything in `src/` into the open place.

```bash
node tools/rbx.js luau @tools/BuildTestArena.luau
```

Rebuilds the test arena (Edit mode).

```bash
node tools/rbx.js luau @tools/tests/SkillSmokeTest.luau Server
```

During Play, casts every skill at the dummies and checks fusion.
