# Handoff: lobby menu and Bold Vanguard HUD restyle

Repo `tehenglay/riftbound` (GitHub now redirects to `TeHenglay/Riftbound`). Branch `claude/lobby-menu-buttons-5nu9t8`.
Commit identity used on this branch: `git -c user.name=Henglay -c user.email=tehenglay098@gmail.com commit`, with no Claude or Co-Authored-By lines.

## Done and live in Studio
These were installed and playtested earlier, up to commit 482634e:
- **Lobby menu** (`src/StarterPlayer/StarterPlayerScripts/Riftbound/LobbyMenu.lua`).
  - Left column: wide Store bar, then Items / Quests / Areas / Play. Right column: Profile / Calendar.
  - Events, Summon, Units, Battlepass and Guild are removed on purpose, and so is the old HUD bag button.
  - Shown only in the nation lobby. The buttons slide away in the Rift. Escape closes panels.
- **Button actions.**
  - Items calls `HUD.ToggleBackpack`.
  - Play opens `PlayScreen`.
  - Store fires `NationRemotes.OpenMarketLocal:Fire("Shop")`, or shows a placeholder panel.
  - Areas uses `NationRemotes.TravelTo` ("Crossroads" / "Nation").
  - Profile shows the player's level and stats.
  - Quests and Calendar open placeholder panels.
- **Play page** (`PlayScreen.lua`): a full-screen mode select with four cards.
  - Story fires `NationRemotes.OpenStoryLocal` and shows StoryCleared/15.
  - Raid is locked until Lv 25.
  - Training fires `Remotes.EnterRift("Training")`.
  - Daily Challenge is card only, with UTC reset timers.
- **Server** (`src/ServerScriptService/Riftbound/LobbyMenu.server.lua`): `EnterRift(mode)` with a 2 s cooldown.
  - Sets the `MatchMode` attribute and calls `NationService.EnterRift(player)`.
  - Clears `MatchMode` when `InRift` goes false.
- **Classic avatar** (`ClassicAvatar.server.lua`).
  - Classic blocky R15 body. The player's own head stays (the user's is a frog head).
  - No layered 3D clothing.
  - Heads wider than 1.7 studs are shrunk with HeadScale.
- **Icons:** the 7 obsidian-style menu icons are uploaded. Their ids are in `src/ReplicatedStorage/Riftbound/UIAssets.lua` → `UIAssets.Menu`.

## Pending: Bold Vanguard restyle (coded and pushed, NOT in Studio)
Commits `0dcb736` and `d5622f4` (a README wording change) are on the branch.
- **`LobbyMenu.lua`.** Buttons are now built in-engine with the `framed()` helper:
  - a dark face with a UIGradient tinted by the button colour
  - a 3 px coloured UIStroke rim
  - a black "Outline" frame that also forms a drop shadow below
  - a faint white inner shine
  - white Heavy labels with a 2.5 px black UIStroke, from `outlined()`
  - black key badges
  - hover brightens the rim and scales to 1.07; press scales to 0.94
  - `GAP` went from 8 to 22 so the outlines don't merge
  - new tints: Store 255,77,109; Items 56,163,255; Quests 255,159,28; Areas 47,211,122; Play 168,85,247; Profile 79,125,255; Calendar 255,200,61
- **`HUD.lua` font block only.** `local TYPEFACE = Enum.Font.TitilliumWeb`. Every `F.*` face now uses it: Title Bold, TitleBold Heavy, Body SemiBold, BodyBold Bold, Label Bold, Italic Regular Italic. The header comment is updated too.
- **`tools/art/build.js`.** `menuTile()` is replaced by `menuIcon()`: bright painted icons with ink outlines and a transparent background. The new PNGs are committed at `art/ui/menu_{Store,Items,Quests,Areas,Play,Profile,Calendar}.png`.
- **The 7 new PNGs are NOT uploaded yet.** Until they are, `UIAssets.Menu` still points at the old obsidian tiles, which would draw a tile inside the new frame. Upload the PNGs before syncing, or in the same go.

## Uncommitted on the PC
- The PC copy of `HUD.lua` carries the Nation thread's uncommitted perk edits, merged in. So **do not overwrite HUD.lua wholesale**. Apply only the `F` block change by hand (diff: `git show 0dcb736 -- src/StarterPlayer/StarterPlayerScripts/Riftbound/HUD.lua`).
- The PC session couldn't `git fetch` or push in the past. Code was pasted to it and committed from the cloud. If fetch works now, pull the branch. Otherwise copy `LobbyMenu.lua`, `build.js` and the 7 PNGs from the commit.
- The PC repo folder is under `~\OneDrive\Documents\GitHub\` (the Remote Control session ran in `Roblox game`). Confirm the path on the machine.

## Install steps (PC, Studio open with the MCP server enabled)
1. Get a Studio slot from the coordinator first (see etiquette below).
2. Put the new `LobbyMenu.lua`, `build.js` and the 7 `art/ui/menu_*.png` on the PC. Apply only the font block to `HUD.lua`. Optionally re-render the PNGs on the PC with `node tools/art/build.js menu_Store menu_Items menu_Quests menu_Areas menu_Play menu_Profile menu_Calendar`.
3. Upload the 7 PNGs. Last time this used Studio MCP's `upload_image` with a local server: `python -m http.server 8765 --bind 127.0.0.1` in `art/ui`. The user gets a permission prompt and accepts it. Put the new `rbxassetid://` ids into `UIAssets.Menu`, and commit that file from the cloud.
4. Run `node tools/sync.js` (it pushes all of `src/` into the open place).
5. Playtest in a nation lobby and check:
   - all 7 buttons show the new frames and icons
   - the labels are in Titillium Web
   - the left column fits on screen (`fitToScreen` UIScale)
   - Play, Items, Store, Areas, Profile and Calendar still work
   - no errors in Output
6. Screenshot it for the user. Remind them to press Ctrl+S in Studio to save.

## User's style decisions
- **Chosen:** style "B · Bold Vanguard" from `/mnt/project-files/lobby-menu/hud-style-options.png`, with font option 4, Titillium Web (`hud-fonts.png`).
- **Keep current shapes for** the skill buttons, the flask, the level badge and the HP bar. The new style goes on the menu buttons and the lettering.
- **Rejected:**
  - the bright bubbly sim look ("too childish")
  - the dark framed version (`hud-style-mockup-v2.png`)
  - the Chinese ink theme ("not fit our roblox game")
- The PC session's interactive page (https://claude.ai/artifact/BD8xG3G8VuhmSABTfZxkvW) uses different letters: its "B" is Neon Rift. Bold Vanguard is what was picked.
- **Possible follow-ups once the buttons are approved (not started):** restyle the Play page cards and the lobby panels to match.

## Hooks other code depends on
- **Player attributes:**
  - `Area` ("Nation" | "Crossroads" | "Rift" | "Story")
  - `Nation`, `InRift`, `NeedsNation`, `MatchMode`, `StoryCleared` (0–15)
  - `Level`, `Gold`, `Xp`, `XpToNext`, `StatPoints`, `Stat_*`
- **`ReplicatedStorage.NationRemotes`:**
  - `OpenMarketLocal` (BindableEvent, `Fire("Shop")`)
  - `TravelTo` (RemoteEvent)
  - `OpenStoryLocal` (BindableEvent)
- **Riftbound Remotes:** `EnterRift` (RemoteEvent, mode string; only "Training" is valid).
- **HUD API used by LobbyMenu/PlayScreen:** `HUD.Style`, `HUD.SetLobby`, `HUD.SetLobbyPanel`, `HUD.OnHudMenuOpened`, `HUD.ToggleBackpack`.
- **Known issue:** the first Story click after joining sometimes doesn't open the story screen. The Nation thread's script hooks `OpenStoryLocal` late.

## Studio etiquette
- Only one session may use Studio at a time. Ask the coordinator for a slot and wait for its go, even if Studio shows Edit mode.
- Never stop or interrupt a playtest the user started.
- Don't sync over another thread's in-progress work. `HUD.lua` on the PC holds Nation thread edits.
