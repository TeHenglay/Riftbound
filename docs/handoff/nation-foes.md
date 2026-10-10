# Handoff: Nation foes (story-mode enemies)

Written 2026-10-10 for a fresh session. No chat history is needed.

## Goal

Each of the 5 nation stories gets its own anime-styled regular enemy (plus an elite
version) instead of the Rift Husk. The Rift Husk is not deleted: it moves to the
**Daily Challenge** mode later (not started; no code for that yet).

The user approved all 5 designs and asked to "build all 5", and added: **use the
nicest model for each foe's weapon** (separate, high-detail weapon meshes).

Concept sheet (approved): https://claude.ai/artifact/HAWRPqGmoNd3ndQ6bycvfb

## The 5 approved designs

| Nation | Foe (Id) | Elite (EliteId) | Look | Weapon(s) | Behaviour | Status on player |
|---|---|---|---|---|---|---|
| Fire (Pyrelord Vashra) | Ashen Ronin (`AshenRonin`) | Kiln Oni Captain (`KilnOniCaptain`) | Burnt samurai: black lava-cracked lamellar plates, torn crimson haori, one-horned oni half-mask, white hair burning to flame | Nodachi with molten orange edge; elite: studded oni kanabo | Iaido dash: red line telegraph, dashes through it, leaves burning trail. Elite: 2 swipes + fire-ring slam | Burn |
| Earth (Gravemaw the Colossus) | Shalecrag Monk (`ShalecragMonk`) | Gravemaw Warden (`GravemawWarden`) | Stone-grown monk: stone kasa hat, shadowed face with amber eyes, mossy boulder shoulders, stone prayer beads, torn robe | Giant runed stone fists; elite: giant stone prayer-bead chain | Slow tank; stone guard blocks first hit (regrows after 6 s); amber ring then slam that roots. Elite: wide 14-stud slam + thrown boulders | Root |
| Water (Queen Nerevyn) | Drowned Lancer (`DrownedLancer`) | Abyssal Court Knight (`AbyssalCourtKnight`) | Pale drowned court guard, cyan glow lines, floating hair, red coral crown, navy court coat, legs dissolve into sea spray | Silver coral-tipped trident; elite: coral tower shield | Keeps mid range, throws tide spear along a blue line; splashes back leaving a slowing puddle. Elite: shield halves damage while not attacking; wave sweeps arena | Soaked / slow |
| Wind (Zephyrax the Unbound) | Gale Shinobi (`GaleShinobi`) | Cyclone Kunoichi (`CycloneKunoichi`) | Slim masked ninja, white mask with wind spiral, mint eye slits, two-tailed scarf, hovers | Crescent wind blades on both forearms | Packs; zigzag blink next to you, one cut + knockback, blink away. Fragile. Elite: cyclone that pulls players in, then boomerang blades | Knockback |
| Lightning (Voltrex the Fallen Herald) | Thunderfallen Herald (`ThunderfallenHerald`) | Stormbreaker Paladin (`StormbreakerPaladin`) | Fallen temple knight: cracked white/violet plate, gold trim, visored helm with yellow slit, broken halo, one lightning wing | Gold-edged glaive | Marks a circle, teleports there as a lightning bolt; shock chains to a nearby player. Elite: two wings, 3 bolts in a row + spark ring (safe close in) | Shock / chain |

## What's built (code)

Repo: github.com/TeHenglay/riftbound, branch **`claude/nation-enemies-sex1jh`**,
commit **`d68ed6c`** "Add the five nation foes for story mode" (on top of `d8d1ef8`).
No PR opened yet. Commits are authored as TeHenglay ("Henglay
<tehenglay098@gmail.com>") with no Co-Authored-By / Claude lines.

New files only (nothing existing was edited):

- `src/ServerScriptService/Riftbound/NationFoes.lua` — the spawn hook (API below).
- `src/ServerScriptService/Riftbound/Foes/FoeKit.lua` — targeting, floor telegraphs
  (circle, line, donut), hit shapes, player Burn/Slow/Root/Knock, dash, teleport,
  projectiles, lob, the think loop (`FoeKit.Run`) and a fallback melee.
- `src/ServerScriptService/Riftbound/Foes/FoeRig.lua` — attaches a body as a jointed
  rig (Motor6Ds `Rig_Body/ArmL/ArmR/LegL/LegR`, same convention as the Rift Husk, so
  the existing client `EnemyAnimator` animates it), plus a part-figure builder.
- `Foes/AshenRonin.lua`, `ShalecragMonk.lua`, `DrownedLancer.lua`,
  `GaleShinobi.lua`, `ThunderfallenHerald.lua` — per-foe stats, stand-in figure
  (`Build`), optional `Setup`, and moves (`Think`).

Uses only the stable Enemies API (`SpawnDummy` with `Chase = false`, `IsAlive`,
`HasStatus`, `Push`, `BlockCheck`, `Folder`). Compiles with luau-compile; untested in
Studio.

## API (for the story code)

```lua
local NationFoes = require(game.ServerScriptService.Riftbound.NationFoes)
NationFoes.Spawn(nation, kind, cframe, opts) -> model
--   nation: "Fire" | "Earth" | "Water" | "Wind" | "Lightning"
--   kind:   "Grunt" | "Elite"
--   opts:   same table as Enemies.SpawnDummy (Health, Damage, Speed, Xp, Gold, Loot).
--           Name/Chase/Visual are set inside; Health is multiplied and Speed set per foe.
NationFoes.Names(nation) -> gruntName, eliteName
```

Returned models are normal registered enemies (tagged, drops on death). Attributes set:
`Foe`, `Nation`, `Elite`.

## Story swap (owned by the Nation lobby thread)

The Nation lobby side has already coded the swap: StoryService calls
`NationFoes.Spawn` when the module exists, otherwise it spawns husks. **It is not
synced into Studio yet**; sync it after the foe modules are in. Bosses are unchanged.
Story.lua names should become the foe names above (Grunt / Elite).

## Pending

1. **Studio sync** of the 8 new files. From the user's checkout
   (`C:\Users\LayPl\OneDrive\Documents\GitHub\Roblox game`):
   `git fetch origin claude/nation-enemies-sex1jh`, then
   `git checkout origin/claude/nation-enemies-sex1jh -- src/ServerScriptService/Riftbound/NationFoes.lua src/ServerScriptService/Riftbound/Foes`
   and `node tools/sync.js <those files>` (Studio MCP via `tools/rbx.js`). Then sync
   the lobby thread's StoryService swap.
   - A Remote Control session was started for this on 2026-10-10 01:31 UTC but went
     idle right away and never reported back, so **assume nothing was synced or
     generated**. Check Studio for `ServerScriptService.Riftbound.NationFoes` and
     `ServerStorage.RiftboundAssets.Foes` before redoing.
2. **AI meshes + weapons** into `ServerStorage.RiftboundAssets.Foes.<Id>` (and
   optionally `<EliteId>`; otherwise the grunt template is scaled 1.5-1.8x).
   Template format (see `FoeRig.lua`): a Model with parts `Body, ArmL, ArmR, LegL,
   LegR`, facing -Z, standing on its lowest point; any other part (weapon, hat, scarf,
   halo, wing) is welded to the limb named by its `AttachTo` attribute (default
   Body). Copy the method used for `ServerStorage.RiftboundAssets.RiftHuskRig`
   (AI-generated mesh split into jointed segments). Weapons: separate high-detail
   meshes, `AttachTo = "ArmR"` (shield `ArmL`). If AI generation is unavailable, use
   top-quality Creator Store meshes. Without a template, each foe falls back to its
   part-built stand-in, so the game still runs. Save the place so assets persist.
3. **Playtest**: in your own playtest, spawn each nation's Grunt and Elite near the
   player, e.g. `NationFoes.Spawn("Fire", "Grunt", cf, { Health = 120, Damage = 6,
   Xp = 15, Gold = {4, 8} })`; check output log, movement, telegraphs, attacks;
   screenshot to `tools/screens/foe-<Id>.png`. Tune numbers in each foe module.
4. Open a PR for the branch once it plays well.
5. Later: Rift Husk as the Daily Challenge enemy.

## Studio etiquette

- Studio is shared by several threads: only one session works in Studio at a time.
  Ask the project's coordinator for the slot first and say when you hand it back.
- Use the Studio instance named "Riftbound" if several are listed.
- If Studio is in Play mode, that's the user playing: wait. **Never stop a playtest you
  didn't start.**
- Player avatar is the classic blocky R15 body; the user likes anime-flavoured but not
  childish, and realistic / latest AI-generated models where they help. The Chinese
  ink theme idea was cancelled by the user.
