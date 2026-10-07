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
| F | Interact (take a shrine's skill, open the Forge) |
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
