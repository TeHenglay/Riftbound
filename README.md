# Elemental Roguelike

A Hades-style roguelike for Roblox: build a skill loadout during a run and merge elements into fusion skills.

## Run it in Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs Rojo, Selene, StyLua).
2. Install the Rojo plugin in Roblox Studio (`rojo plugin install`).
3. Open a new **Baseplate** place in Studio.
4. Run `rojo serve` here, then click **Connect** in the Rojo plugin. The code syncs into Studio live.
5. Press **Play**.

## Controls

| Key | Action |
|---|---|
| Left click | Attack |
| Right click | Special |
| Q | Cast (long range) |
| Space | Dash |
| 1-6 | Debug: infuse Fire / Ice / Lightning / Wind / Earth / Shadow into the selected slot |
| Tab | Debug: change the selected slot |
| F | Debug: fuse two elements at level 2 or higher on the selected slot |

Try it: press 1 twice and 2 twice (Fire 2 + Ice 2 on Attack), press F to make **Steam Burst**, then hit the training dummies.

## Layout

- `src/shared` — data everyone reads: `Elements`, `Skills`, `Fusions` (recipe table), `Types`, `Remotes`.
- `src/server/Services` — `LoadoutService` (run loadout, infuse, fuse), `CombatService` (cooldowns, hit detection, damage), `StatusEffects` (Burn, Chill, Shock, Knockback, Armor, Drain), `DummyService` (training dummies).
- `src/client` — top-down camera, input, and a placeholder HUD.

Adding a fusion is one entry in `src/shared/Fusions.luau`.
