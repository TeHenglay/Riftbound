# Riftbound – Master Game Systems Blueprint

This document serves as the **Master Index and Complete Specification Overview** for all interconnected gameplay systems designed for *Riftbound*.

---

## 📚 Complete System Documentation Map

| Specification Document | Systems Covered |
| :--- | :--- |
| **1. [RUNES_SYSTEM.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RUNES_SYSTEM.md)** | 3-slot rune mechanics, full rarity catalog (Common, Rare, Epic, Legendary), and balance rules. |
| **2. [SKILL_EVOLUTION_AND_CRAFTING.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md)** | Nation starting skills, 50% Act 1 skill drops, evolution ascensions, and Forge crafting recipes. |
| **3. [RIFT_BOLT_AND_DASH.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFT_BOLT_AND_DASH.md)** | Basic attack sockets & Astral Cannon ascension; Nation-specific Dash evolutions (0 sockets). |
| **4. [GAME_BALANCE_GUIDE.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md)** | 10+ enemies per wave, mob roles, player baseline stats, and the rebalanced XP curve. |
| **5. [STORY_DROPS_AND_MATERIALS.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/STORY_DROPS_AND_MATERIALS.md)** | Zero combat clutter (mobs drop only gold/XP) with Act Clear material reward bundles. |
| **6. [GOLD_ECONOMY_SYSTEM.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GOLD_ECONOMY_SYSTEM.md)** | 10x scaled gold economy across combat, Forge fees, mid-run shops, and permanent lobby upgrades. |
| **7. [ANIME_BOSSES_AND_SKILLS.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md)** | Act 3 Final Anime Boss encounters (Naruto, Sasuke, Ace, Jinbe, Toph) and pure hand-cast dropped skills. |
| **8. [GAMEPASS_MONETIZATION.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAMEPASS_MONETIZATION.md)** | Official 6-item gamepass roster (Infinite Magnet, 2x Gold, 2x XP, 2x Match Drops, Lucky Runes, VIP Sovereign). |
| **9. [PLAYER_EQUIPMENT_SYSTEM.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/PLAYER_EQUIPMENT_SYSTEM.md)** | 3-slot gear system (Ring, Armor, Boots), substats, and the Crossroads Lobby Relic Vault (Gold Gacha). |
| **10. [IMPLEMENTATION_ROADMAP.md](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/IMPLEMENTATION_ROADMAP.md)** | Single master phase tracker, priority order, full file paths, and code modification guides. |

---

## 1. ⛩️ Starting Loadout & Skill Acquisition (No Shrines)

* **Shrines Removed**: Players no longer collect skills from shrines in the arena.
* **Nation Starting Skill**: Swearing allegiance to a nation upon character creation grants:
  * **LMB Basic Attack**: `Rift Bolt`
  * **Shift Mobility**: `Dash`
  * **Q Signature Skill**:
    * 🔥 **Fire (Ember Dominion)** ➔ `Fireball`
    * 🌊 **Water (Tidewater Court)** ➔ `Tidal Wave`
    * 🪨 **Earth (Stonehold Clans)** ➔ `Stone Spike`
    * 🌪️ **Wind (Skyreach Nomads)** ➔ `Gust`
    * ⚡ **Lightning (Stormcall Order)** ➔ `Spark Bolt`
* **Unlocking Other Skills**:
  * Clearing **Act 1** of any nation has a **50% Chance** to drop that nation's base skill.
  * If new: Unlocks the skill in your Arsenal for equipping or Forge crafting.
  * If owned: Grants **+1 Skill Level** (up to Level 5) or duplicate copy toward **Skill Evolution**.

---

## 2. 💎 The 3-Slot Rune System (Temporary In-Run Drops)

* **Temporary In-Run Modifiers (The *Hades* Model)**: Runes are **mid-run powerups** earned strictly by clearing enemy waves. They **do NOT save** to the player's permanent lobby inventory.
* **Match Reset**: Sockets start completely empty at the start of every match. When a match ends (victory or defeat), all socketed runes are wiped/reset for the next run.
* **3 Sockets Per Skill**: Every equipped combat skill (LMB, Q, E, Anime Boss skills) features **3 Rune Sockets**.
* *Exception: Dash has 0 rune sockets (pure mobility).*
* **Wave Clear Reward**: Clearing each enemy wave drops **1 Rune** (or a 3-choice selection).
* **Rarity Breakdown**:
  * **Common (⚪)**: Might (+15% Dmg), Expansion (+15% Area), Haste (-12% CD), Reach (+30% Range), Impact (+50% Knockback), Lingering (+1.5s Duration), Prospector (+20% Gold/XP), Heavy Mass (+10% Dmg, -5% Spd).
  * **Rare (🔵)**: Multishot (+1 Projectile), Piercing (Hits 2 targets), Ricochet (Bounces to 1 target), Precision (+18% Crit), Executioner (+10% Dmg vs <35% HP), Giant Hunter (+25% vs Elites/Bosses), Deep Chill (15% Slow for 3s), Tremor (+0.8s Stun), Momentum (+3% Speed per hit, max 5x).
  * **Epic (🟣)**: Aftershock (45% secondary burst), Graviton Vortex (Pulls enemies within 16 studs), Magma Trail (12 fire dmg/sec trail), Twin Spark (22% double-cast chance), Thermal Shock, Overloaded Voltage, Blood Siphon (4% Lifesteal), Aegis Ward (10% Max HP shield, 10s CD), Windrunner (Dash reset).
  * **Legendary (🌟)**: Phantom Twin (Twin Cast clone), Celestial Orbit (8s orbiting shield projectiles), Chain Reaction (Corpse explosion), Singularity (Black hole), Endless Cascade (Cooldown reset on kill), Triple Charge (3-charge stockpile), Dash Weaver (Dash casts skill), Prismatic Prism (Dual element rotation), Absolute Zero (Freeze & execute <25% HP), Cataclysm (+120% screen-wide area), Spell-Totem (Auto-turret), Blood Pact (-80% CD, costs 5% HP).
* **Socketing Limit**: Maximum of **1 Legendary Rune** per skill.

---

## 3. 🌟 Skill Awakening vs. 🔨 Forge Crafting

Progression splits into two paths:

```
                          ┌── [AWAKENING] ───> Awakened Skill (Vertical Power)
                          │                    Home Skill + Mastery (Lv 5) + Catalysts
                          │                    • +20% Base Damage
                          │                    • +25% to +35% Visual & Hitbox Size
                          │                    • Unique Inherent Perk
[EQUIPPED BASE SKILL] ────┤
                          │
                          └── [CRAFTING] ────> Fused Skill (Horizontal Synergy)
                                               2 different unlocked skills + Materials
                                               • New dual-element mechanics
                                               • Elemental reaction triggers
                                               • Forged at the Forge
```

### A. Skill Awakening (Strictly Balanced & Earned)
* **Requirements**:
  1. Base Skill at **Max Level 5**.
  2. **1x Nation Essence** (Act 3 Boss) **OR 2x Nation Cores** (Act 2 clears). *Impossible to awaken in Act 1.*
  3. **8x Nation Shards** + **15x Rift Shards**.
  4. **2,500 Gold** at the Forge.
* **Awakened Base Skills**:
  * **Fireball** ➔ **Fireball Awakened** (+20% Dmg, +30% Radius, leaves Molten Crater).
  * **Tidal Wave** ➔ **Tidal Wave Awakened** (+20% Dmg, +35% Size, +50% knockback, leaves Soaked puddles).
  * **Stone Spike** ➔ **Stone Spike Awakened** (+20% Dmg, +30% Radius, +0.6s stun, +15% earth vuln).
  * **Gust** ➔ **Gust Awakened** (+20% Dmg, +35% Radius, inward vortex pull before blast).
  * **Spark Bolt** ➔ **Spark Bolt Awakened** (+20% Dmg, 5 chain jumps, leaves electric tethers).

### B. Dual-Element Crafting at the Forge
* **Tier 1 Fusions** *(Steam Cloud, Mudslide, Frost Gale, Quake Leap)*:
  * Base Skill A + Base Skill B + **4x Shard A** + **4x Shard B** + **8x Rift Shard** + **1,000 Gold**.
* **Tier 2 Fusions** *(Magma Meteor, Plasma Lance, Magnet Quake, Thunderstorm)*:
  * Base Skill A + Base Skill B + **5x Shard A** + **5x Shard B** + **1x Core** + **12x Rift Shard** + **1,750 Gold**.
* *Rune Rule: Consumed skills refund their socketed runes directly back into player inventory.*

---

## 4. 🔮 Rift Bolt & 💨 Dash Progression

* **Rift Bolt (LMB)**:
  * Can equip **3 Runes**.
  * Awakens into **Rift Bolt Awakened**: +20% Dmg, +25% Size, innate **Pierce 1**, every 4th consecutive hit triggers a **+15 AoE Rift Explosion**.
  * Forge Fee: Level 5 + 15x Rift Shards + 1,500 Gold.
* **Dash (Shift)**:
  * **0 Rune Sockets** (clean mobility).
  * Awakens based on **Chosen Nation**:
    * 🔥 **Fire (Dash Awakened: Blaze Surge)**: Leaves trail of fire for 3s dealing 12 fire dmg/sec and applying Burn.
    * 🌊 **Water (Dash Awakened: Tidal Wake)**: Leaves flooded wake pushing enemies aside and applying Soaked for 4s.
    * 🪨 **Earth (Dash Awakened: Tectonic Ram)**: Dashes *through* enemies dealing 25 damage, knocking back, stunning for 0.8s, and granting a 15 HP stone shield.
    * 🌪️ **Wind (Dash Awakened: Zephyr Twin-Drift)**: Gains **2nd Dash Charge (Double Dash!)**, 20% faster recharge, and +25% speed for 2s.
    * ⚡ **Lightning (Dash Awakened: Thunder Step)**: Instant blink/teleport; an electric arc zaps enemies between start and end for 20 damage and applies Shock.
  * Forge Fee: 6x Nation Shards + 10x Rift Shards + 1,500 Gold.

---

## 5. ⚔️ Game Balance: 10+ Enemies Per Wave & Controlled XP

* **Horde Density**: Minimum **10 enemies per wave** (mixed with fragile Swarmers, Grunts, and 1 heavy anchor).
* **Enemy Stats**:
  * **Swarmer**: 45 HP, 13 Spd, 3 Dmg, **2 XP**, **10–25 Gold**.
  * **Grunt**: 95 HP, 10 Spd, 5 Dmg, **4 XP**, **30–50 Gold**.
  * **Brute**: 220 HP, 7.5 Spd, 10 Dmg, **12 XP**, **80–140 Gold**.
  * **Elite**: 420 HP, 8.5 Spd, 14 Dmg, **30 XP**, **150–250 Gold**.
  * **Act Boss**: 2,800 HP, 8.0 Spd, 18 Dmg, **250 XP**, **2,500 Gold**.
* **Rebalanced XP Formula (Prevents Fast Leveling)**:
  $$\text{XP to Next Level} = 100 \times \text{Level}^{1.65}$$
  * Act 1 ends around **Level 2** (~25–30 mixed kills needed).
  * Act 2 ends around **Level 4**.
  * Act 3 ends around **Level 6–7**.

---

## 6. 📦 Clean Drops & Act Clear Reward Bundles

* **During Combat**: Mobs drop **ONLY XP Orbs and Gold Coins** (zero material clutter).
* **Act Clear Material Bundles**:
  * **Act 1 Clear**: 1x Nation Shard (100%), 3x Rift Shards (100%), 50% chance for Signature Skill, 40% chance for +1 extra Shard, 500 Gold.
  * **Act 2 Clear**: 1x Nation Core (100%), 1x Nation Shard (100%), 5x Rift Shards (100%), 50% chance for +1 extra Shard, 1,000 Gold.
  * **Act 3 Boss Defeat**: 1x Nation Essence (100%), 1x Nation Core (100%), 2x Nation Shards (100%), 8x Rift Shards (100%), 2,500 Gold + **1 Legendary Rune Choice** + **100% Signature Anime Skill Drop**.

---

## 7. 🪙 10x Scaled Gold Economy

* **Mid-Run Void Merchant**:
  * Emergency Flask Sip (+1): 350 Gold | Full Flask Refill: 800 Gold
  * Mystery Rune Chest (Rare / Epic): 750 / 1,500 Gold
  * Temporary Run Blessings: 500 Gold
* **Crossroads Lobby Shop (Permanent Meta-Progression)**:
  * 4th / 5th Flask Charge: 4,000 / 9,000 Gold
  * Flask Potency (+5% Heal): 3,500 / 7,500 Gold
  * Stat Respec (Reset Points): 1,000 Gold
  * Material Exchange: 1x Rift Shard (150 Gold), 1x Husk Ichor (450 Gold)

---

## 8. 👑 Act 3 Anime Final Bosses (100% Hand-Casting, 2-Tier Dropped Skills)

Every nation's Act 3 features an iconic anime master who uses **strictly bare-handed casting** and drops two distinct skills based on difficulty:

```
🌪️ WIND NATION      ➔ Naruto Uzumaki  (Naruto)
   • Normal Clear Drop : Wind Style: Rasenshuriken
   • Hard Clear Drop   : Multi-Shadow Clone Jutsu (Kage Bunshin)

⚡ LIGHTNING NATION ➔ Sasuke Uchiha   (Naruto)
   • Normal Clear Drop : Chidori: Lightning Surge
   • Hard Clear Drop   : Kirin: Thunder Dragon

🔥 FIRE NATION      ➔ Portgas D. Ace  (One Piece)
   • Normal Clear Drop : Fire Fist: Rushing Inferno (Hiken)
   • Hard Clear Drop   : Great Flame Emperor: Sun Cataclysm (Entei)

🌊 WATER NATION     ➔ Jinbe           (One Piece)
   • Normal Clear Drop : Fish-Man Karate: Vagabond Drill (Buraikan)
   • Hard Clear Drop   : Ocean Current Geyser (Kairyū Ipponzeoi)

🪨 EARTH NATION     ➔ Toph Beifong    (Avatar: TLA)
   • Normal Clear Drop : Bedrock Seismic Rupture
   • Hard Clear Drop   : Granite Armor & Earth Gauntlets
```

* **Boss Combat AI (Normal vs. Hard Movesets)**:
  * **Normal Mode Bosses**: Cast their core kit (Poke, Dash, Defense) and finish with **Skill 1**. Bosses **NEVER cast Skill 2** in Normal Mode.
  * **Hard Mode Bosses (Enraged)**: Bosses unlock and **CAN CAST Skill 2** (e.g. Naruto casts `Multi-Shadow Clone Jutsu`, Sasuke casts `Kirin`, Ace casts `Entei`, Jinbe casts `Ocean Current Geyser`, Toph casts `Granite Armor`).
* **Normal vs. Hard Drop Distinction (Hard Mode Exclusivity)**:
  * **Normal Clear (100% first drop)**: Unlocks **ONLY Skill 1** (iconic offensive projectile or burst nuke). Skill 2 NEVER drops here.
  * **Hard Clear (100% first drop)**: The **ONLY mode where Skill 2 drops** (earned by defeating the boss while they cast that skill against you!). Skill 2 is 100% exclusive to Hard Mode.
* **3 Rune Sockets**: All dropped anime skills have 3 Rune Sockets.
* **Forge Pinnacle Synthesis**: High-tier cross-element fusions at the Forge (e.g., `Rasenshuriken` + `Chidori` = `Rikudō: Storm Vortex`; `Multi-Shadow Clone` + `Fire Fist` = `Blazing Clone Swarm`).

---

## 9. 💎 Official 6 Gamepasses (QoL, Boosters & Prestige)

Monetization strictly avoids pay-to-win barriers, focusing on convenience, drop luck, and status:

1. **🧲 Infinite Magnet (Super Vacuum) [199 R$]**: Auto-collects Gold Coins and XP Orbs arena-wide with infinite range.
2. **💰 2x Gold Booster [249 R$]**: Permanently doubles all Gold from mob drops and Act clear bounties.
3. **📈 2x XP Booster [249 R$]**: Permanently doubles all XP gained from enemy kills.
4. **📦 2x Match Drops (Double Clear Rewards) [399 R$]**: Permanently doubles all Act Clear materials (2x Shards, 2x Cores, 2x Essences, 2x Rift Shards) and drops 2 Runes per wave!
5. **🍀 Lucky Runes (+25% Luck) [399 R$]**: Permanently boosts drop rates of Epic and Legendary Runes from waves.
6. **👑 VIP: Rift Sovereign [799 R$]**: Golden `[VIP]` chat tag, sovereign particle aura, +20% Gold/XP stacking buff, and daily free 10x Rift Shards + 2x Husk Ichor.

---

## 10. 🛡️ Player Equipment System & Lobby Relic Vault (Gold Gacha)

Meta-progression gear equipped in the lobby to define permanent character foundation stats (Crit, HP, WalkSpeed):

* **3 Equipment Slots**:
  * 💍 **Slot 1: Ring / Talisman (Offense)**: Flat Spell Damage, Crit Chance (+4% to +18%), Crit Damage (+15% to +45%), Elemental Damage (+6% to +20%).
  * 🛡️ **Slot 2: Robe / Armor (Defense)**: Flat Max HP (+50 to +300), Max HP % (+5% to +22%), Damage Reduction (+4% to +14%), HP Regen.
  * 👢 **Slot 3: Boots / Greaves (Mobility)**: Walk Speed (+1 to +3.5), Dash Cooldown Recovery (+10% to +30%), Global CDR (-4% to -14%).
* **Rarity & Substats**:
  * ⚪ **Common (60%)**: 1 Substat.
  * 🔵 **Rare (28%)**: 2 Substats.
  * 🟣 **Epic (10%)**: 3 Substats (Guaranteed pity at 10 pulls).
  * 🌟 **Legendary (2%)**: 3 Max Substats + **1 Unique Trait** (Guaranteed pity at 50 pulls).
* **The Crossroads Relic Vault (Gold Gacha)**:
  * Single Roll: `600 Gold` (or 10x Rift Shards).
  * 10x Roll: `5,400 Gold` (10% bulk discount; or 90x Rift Shards).
  * Unwanted gear can be salvaged for Gold and Rift Shards to fuel future rolls.
  * Avatar fashion is preserved: gear displays as subtle glowing accents with a "Show Gear Visuals" toggle.

