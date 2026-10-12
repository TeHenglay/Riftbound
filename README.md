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
| F | Interact (take a shrine's skill, talk to the Skill Trainer, refill at the Rift Well) |
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
- Progress is saved (see "Saving" below).
- Tuning: curve and bonuses are in `src/ReplicatedStorage/Riftbound/Progression.lua`;
  drop amounts per enemy are in `TestArena.server.lua` (`Xp`, `Gold`).

## Lobby menu

- In your nation's lobby, bold framed buttons line the screen edges:
  **Store**, **Items**, **Quests**, **Areas**, **Play** on the left and
  **Profile** and **Calendar** on the right. They slide away when you
  enter the Rift (`InRift`) and stay hidden on the nation select screen.
- Items opens the Backpack (B). Play opens a full-screen mode select
  (`PlayScreen.lua`): your Riftwalker with level and name on the left, and
  **Story**, **Raid** (locked below level 25), **Training** and **Daily Challenge**
  cards on the right. Training (the current arena) fires `EnterRift("Training")`
  and the server sets `MatchMode`; the other cards are coming in a future update. Profile shows your avatar, nation, level, gold and
  attributes. Store, Quests, Areas and Calendar open "coming soon"
  panels for now.
- Code: `src/StarterPlayer/StarterPlayerScripts/Riftbound/LobbyMenu.lua`. Tile art
  is `menu_*` in `tools/art/build.js`; its uploaded ids go in `UIAssets.Menu`.

## Parties (multiplayer)

- Open **Play** and press **Party** in the bottom bar. The panel lists your
  party (up to 4 players, leader included) and everyone else in the server
  with an **Invite** button. Inviting makes you the party leader.
- The invited player gets a popup with **Accept** / **Decline** (it expires
  after 30 seconds). Party headshots show next to the Party button.
- Only the leader picks the match. Starting **Training** or a **Story** act
  brings every member who is waiting in a lobby; members already in a match
  stay behind (the leader is told). Other members see "Your party leader
  picks the match".
- Story runs are private: each party gets its own copy of the act's arena
  (cloned on demand 4000 studs apart and reused), so two parties on the same
  act never meet. On the results screen the leader picks **Retry** or
  **Next Act** for everyone; anyone can go back to the **Lobby**.
- The leader can remove members; anyone can leave. If the leader leaves, the
  next member leads; a party of one breaks up.
- Code: `PartyService.lua` / `Party.server.lua` (server, party size in
  `PartyService.Max`) and `PartyPanel.lua` (client panel and invite popups).

## Saving

- `SaveService.lua` saves level, XP, gold, backpack items, skills (fusions and
  awakenings, with levels and equipped slots) and stat points in the DataStore
  `RiftboundSave_v1`. The nation (`RiftboundNation_v1`) and cleared story acts
  (`RiftboundStory_v1`) have their own stores. Runes are never saved.
- Loaded on join; saved on leave, every 2 minutes and on server shutdown. If
  loading fails, that session isn't saved, so a failed load can't wipe a save.
- Story runs only pay out on a clear: the run snapshots your level, XP, gold
  and stat points when it starts. Clear the act and everything is kept; leave,
  die or disconnect first and you go back to the snapshot.
- In Studio, saving needs Game Settings > Security > Enable Studio Access to
  API Services.

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

## Nation foe models

- Each nation's story foe (Grunt and Elite) is an AI-generated mesh split into
  Body, ArmL, ArmR, LegL and LegR, rigged by `Foes/FoeRig.lua` like the Husk. The
  templates live in the place at `ServerStorage.RiftboundAssets.Foes.<Id>` and the
  raw generated meshes in `ServerStorage.RiftboundAssets.FoeSources`; they are
  **not** in this repo, so save the place file. Without them each foe falls back
  to its part-built stand-in.
- The foes are bare-handed: they punch and cast their nation skills. The
  Stormbreaker Paladin's wings are a separate part welded to its body.
- `tools/BuildFoeTemplates.luau` rebuilds the templates from `FoeSources` (it can
  also attach the generated weapon meshes with `WITH_WEAPONS`). `tools/meshview.js`
  renders any mesh model from the open place to a PNG, e.g.
  `tools/screens/foes-all.png`.

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
  fused skill at **level 1**, whatever the levels of the two skills (if you
  already own it, it keeps its level and you get a duplicate copy instead).

## Skill Trainer (Training Grounds)

- The Forge is gone from the Training Grounds; the **Skill Trainer** stands in
  its place (spawned by `TestArena.server.lua` at the old Forge spot, or at
  `SkillTrainerSpot` from `tools/BuildTestArena.luau`). Press F to open the
  picker (`SkillTrainer.lua`): **Base**, **Fused** and **Awakened** tabs, click
  a skill to see it, then **Equip on Q / E**.
- Skills you don't own are borrowed (Training skills: never saved, taken back
  when you leave). Fused and awakened skills can only be borrowed in Training;
  nothing can be borrowed during a story.

## Forge and Awakening costs

- **Fusing** two base skills costs 10,000 gold, plus 4 Shards (Act 1) and 3
  Cores (Act 2) from each of the two nations and 10 Rift Shards
  (`Crafting.lua`: `FUSE_*`).
- **Awakening** costs 10,000 gold (`Crafting.AwakenGold`). Base skills need
  level 2 (`Crafting.AwakenLevel`), their nation's Essence (or 2 Cores), 8 Shards and 15 Rift Shards.
- **Fused skills awaken too** (e.g. Steam Cloud Awakened): level 2, plus 2
  Essences (Act 3) and 6 Shards from each nation and 20 Rift Shards. Awakened
  fusions are made in `Skills.lua` from the fusion: +20% damage, +25% area,
  effects last 25% longer (zones +1s), +30% knockback. Awakened skills reuse
  their skill's visuals, sounds and icon until they get their own.

## Skill levels (duplicates)

- Getting a skill you already own (Story drops, fusing one you have) adds a
  **copy** of it. Spend copies in the Backpack (B) with **Level Up**:

  | Level | Copies used |
  | --- | --- |
  | 1 → 2 | 3 |
  | 2 → 3 | 6 |
  | 3 → 4 | 12 |
  | 4 → 5 (max) | 15 |

- Costs live in `Skills.LevelCost`. Copies are saved; spare copies carry over
  when a skill is awakened and are lost when it's fused away.
- Training skills are only borrowed: skills from the Training shrines and the
  Forge's free test equip are never saved, can't be levelled, fused or
  awakened, and are taken back (with your old Q/E restored) when you leave
  Training, start a Story act or die.
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
  - `TestArena` – shrines, the Skill Trainer and dummy respawns; Studio-only debug hook
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

## Nations and lobbies

- On their first join a player picks one of five nations on the select screen
  (`Nation.client.lua`). The choice is saved in the `RiftboundNation_v1`
  DataStore and published as the player attribute `Nation`.
- Each nation gives +10% damage to skills containing its element (fusions
  included) plus one perk:

  | Nation | Element | Extra perk |
  | --- | --- | --- |
  | Ember Dominion | Fire | +5% damage on every skill |
  | Stonehold Clans | Earth | +25 max health |
  | Tidewater Court | Water | Rift Flask heals 45% instead of 35% |
  | Skyreach Nomads | Wind (Air) | +8% movement speed |
  | Stormcall Order | Lightning | Skills recharge 8% faster |

  Tuning lives in `src/ReplicatedStorage/Riftbound/Nations.lua`.
- Players spawn on their nation's floating lobby island (`workspace.NationLobbies`,
  far from the arena at Z = 2600). Walking through the Rift portal moves them to
  the gameplay spawn (attribute `InRift = true`); dying in the Rift respawns them
  in their lobby. `Lobby.server.lua` turns off `CharacterAutoLoads` and
  `NationService` does all spawning through `Player.RespawnLocation`.
- Themes: Fire has a smoking volcano, lava pools and falling ash; Earth is ringed
  by mountains; Water is a lagoon with a waterfall; Wind has windmills and
  floating rocks; Lightning is a cloud temple with a Zeus statue and lightning
  strikes. Each lobby also tints the sky while you stand in it (client only).
- `LobbyBuilder.lua` builds any lobby the place is missing at server start. The
  props it places (AI-generated monuments, volcano, mountains, waterfall cliff,
  windmills, coral, lava rocks and a Creator Store oak) live only in the place
  at `ServerStorage.LobbyAssets`; without them it falls back to plain parts.
- Saving needs **Game Settings > Security > Enable Studio Access to API Services**
  in Studio; without it the choice lasts for the session only.
- Studio testing: `game.ServerStorage.NationDebug:Invoke("reset", player)` forgets
  a player's nation; `"rift"` / `"lobby"` move them between the two.

## The Crossroads (main lobby)

- A shared floating plaza (`workspace.NationLobbies.Crossroads`) where players of
  every nation meet. The rift gate in each nation lobby leads here; the
  Crossroads has a **Your Nation** gate (north) back home. Training in the
  arena starts from the lobby menu's Play button (`NationService.EnterRift`).
- Player attribute `Area` is `"Nation"`, `"Crossroads"` or `"Rift"`.
  `NationService.GoTo(player, area)` travels; clients can ask with
  `NationRemotes.TravelTo:FireServer("Crossroads" | "Nation")`.
- **The Rift Shop** sells Flask Refills (25 g), Tomes of Insight (+1 stat point,
  150 g) and materials. **The Goods Merchant** buys Rift Shards (6 g), Husk Ichor
  (16 g) and Ember Cores (45 g). Walk up to a stall and press F. Prices are in
  `src/ReplicatedStorage/Riftbound/Market.lua`; `MarketService.lua` checks you
  stand at the stall before trading.
- Other client UI can open the screens with
  `NationRemotes.OpenMarketLocal:Fire("Shop" | "Merchant")`.

## Story mode

- One story per nation, three acts each (`src/ReplicatedStorage/Riftbound/Story.lua`).
  Acts 1 and 2 of all five stories are built (`workspace.StoryArenas`, made by
  `StoryBuilder.lua`; `StoryBuilder.BuiltActs` and Story.client's `BUILT`);
  Act 3 shows as coming soon.
- Act 1's boss is the nation's named foe (e.g. Shalecrag Monk). Act 2's boss is
  its elite (Kiln Oni Captain, Gravemaw Warden, Abyssal Court Knight, Cyclone
  Kunoichi, Stormbreaker Paladin) in an arena ringed by rift obelisks. Act 2
  clears pay the nation's Core (Ember Core, Abyssal Pearl, ...), needed for
  fusions.
- Open the story screen from the Play page's Story card
  (`NationRemotes.OpenStoryLocal:Fire()`): pick a map (story), an act and a
  difficulty, then Start. Easy and Medium are open; Hard needs the act cleared
  on Medium, Nightmare on Hard. Each run is private to you and your party.
- A run is waves of husks and brutes (plus a boss in Act 3). Clearing pays gold
  (double on a first clear per difficulty) and that nation's Essence (×1.5 in your
  own nation's story), unlocks the next act and opens a gate back to the
  Crossroads. Cleared acts save to the `RiftboundStory_v1` DataStore and show as
  the player attributes `StoryProgress` and `StoryCleared`.
- Map pictures are screenshots of each Act 1 arena (`art/ui/story_*.png`,
  uploaded; ids in `Story.lua`).
