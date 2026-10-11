# Riftbound – Master Implementation Roadmap & Priority Guide

This document is the **Single Master Tracker** for all implementation phases, priorities, design specifications, and code files for *Riftbound*.

---

## 📊 High-Level Progress Tracker

| Priority | Feature / System | Phase | Status | Target Files |
| :---: | :--- | :---: | :---: | :--- |
| **P2** | **Nation Starting Skill Auto-Grant & Equip** | Phase 1 | ✅ **COMPLETED** | `Nations.lua`, `BuildService.lua`, `NationService.lua` |
| **P1** | **Rebalanced XP Curve & 10x Gold Economy** | Phase 1 | ⏳ **PENDING** | `Progression.lua`, `Story.lua` |
| **P3** | **Horde Wave Density (10+ Mobs) & Clean Drops** | Phase 1 | ⏳ **PENDING** | `Story.lua`, `Enemies.lua`, `Drops.lua` |
| **P4** | **Register Awakened & 10 Anime Boss Skills** | Phase 2 | ⏳ **PENDING** | `Skills.lua` |
| **P5** | **Act 3 Anime Boss AI & 2-Tier Drop System** | Phase 2 | ⏳ **PENDING** | `Story.lua`, `StoryService.lua` |
| **P6** | **Temporary In-Run 3-Socket Rune System** | Phase 3 | ⏳ **PENDING** | `BuildService.lua`, `StoryService.lua`, `HUD.lua` |
| **P7** | **Player Equipment System & Lobby Relic Vault** | Phase 3 | ⏳ **PENDING** | `EquipmentService.lua`, `StatService.lua`, `LobbyMenu.lua` |
| **P8** | **Gamepass Monetization Integration** | Phase 3 | ⏳ **PENDING** | `MarketService.lua` |

---

## 🚦 Phase 1: Core Combat Foundation & Balance

### ✅ Priority 2: Nation Starting Skill Auto-Grant & Equip
* **Status**: ✅ **COMPLETED**
* **Specification Document**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md)
* **Code Files Modified**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Nations.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Nations.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/BuildService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/BuildService.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/NationService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/NationService.lua)
* **Summary**:
  * Added `HomeSkill` mappings to `Nations.Defs` (`Fire` ➔ `Fireball`, `Water` ➔ `TidalWave`, `Earth` ➔ `StoneSpike`, `Wind` ➔ `Gust`, `Lightning` ➔ `SparkBolt`).
  * Implemented `BuildService.GrantHomeSkill(player, nationId)` which grants the skill at Level 1, places it into **Slot `Q`**, and sends a toast banner notification.
  * Connected auto-granting to both first-time selection (`NationService.Choose`) and returning player joins (`NationService.load` / `BuildService.Init`). Shrines in arena are no longer required.

---

### ⏳ Priority 1: Rebalanced XP Curve & 10x Gold Economy Scaling
* **Status**: ⏳ **PENDING (Next Up)**
* **Specification Documents**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GOLD_ECONOMY_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GOLD_ECONOMY_SYSTEM.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Progression.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Progression.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua)
* **Summary**:
  * Update `Progression.XpToNext(level)` formula to:
    $$\text{XP} = 100 \times \text{Level}^{1.65}$$
    (Prevents fast leveling; Act 1 ends around Level 2, Act 2 around Level 4, Act 3 around Level 6–7).
  * Scale mob gold drops to the 10x RPG economy:
    * Swarmers: 10–25 Gold
    * Grunts: 30–50 Gold
    * Elites: 150–250 Gold
    * Act Bosses: 2,000–2,500 Gold
  * Update `Story.ClearGold` act completion bounties to **500g (Act 1)**, **1,000g (Act 2)**, and **2,500g (Act 3)**.

---

### ⏳ Priority 3: Horde Wave Density (10+ Mobs) & Clean Combat Drops
* **Status**: ⏳ **PENDING**
* **Specification Documents**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/STORY_DROPS_AND_MATERIALS.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/STORY_DROPS_AND_MATERIALS.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/Enemies.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/Enemies.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/Drops.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/Drops.lua)
* **Summary**:
  * Scale all story wave configurations in `Story.lua` to enforce **minimum 10 enemies per wave** (mixed fragile Swarmers, sturdy Grunts, and anchor Elites).
  * Ensure in-combat mobs drop **Gold Coins & XP Orbs ONLY** (zero material clutter on the arena floor).
  * All materials (Shards, Cores, Essences, Rift Shards) are awarded cleanly as **Act Clear bundles**.

---

## 👑 Phase 2: Skills & Anime Final Bosses

### ⏳ Priority 4: Register Awakened Skills & 10 Anime Boss Skills
* **Status**: ⏳ **PENDING**
* **Specification Documents**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFT_BOLT_AND_DASH.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFT_BOLT_AND_DASH.md)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Skills.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Skills.lua)
* **Summary**:
  * Register the 5 Awakened Base Skills: `Fireball Awakened`, `Tidal Wave Awakened`, `Stone Spike Awakened`, `Gust Awakened`, `Spark Bolt Awakened`.
  * Register `Rift Bolt Awakened` (LMB) and `Dash Awakened` (5 nation elemental mobility variants).
  * Register the 10 pure hand-cast Anime Boss Skills:
    * 🌪️ **Wind**: `Wind Style: Rasenshuriken` (Normal) & `Multi-Shadow Clone Jutsu` (Hard)
    * ⚡ **Lightning**: `Chidori: Lightning Surge` (Normal) & `Kirin: Thunder Dragon` (Hard)
    * 🔥 **Fire**: `Fire Fist: Rushing Inferno` (Normal) & `Great Flame Emperor: Entei` (Hard)
    * 🌊 **Water**: `Fish-Man Karate: Vagabond Drill` (Normal) & `Ocean Current Geyser` (Hard)
    * 🪨 **Earth**: `Bedrock Seismic Rupture` (Normal) & `Granite Armor & Earth Gauntlets` (Hard)

---

### ⏳ Priority 5: Act 3 Anime Final Boss AI & 2-Tier Drop System
* **Status**: ⏳ **PENDING**
* **Specification Document**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ReplicatedStorage/Riftbound/Story.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StoryService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StoryService.lua)
* **Summary**:
  * Replace placeholder Act 3 bosses with the 5 Anime Masters: Naruto Uzumaki, Sasuke Uchiha, Portgas D. Ace, Jinbe, and Toph Beifong.
  * **Boss Combat AI Movesets**:
    * **Normal Mode**: Bosses use standard poke/melee and cast **Skill 1**. Bosses **NEVER cast Skill 2**.
    * **Hard Mode**: Bosses unlock and **CAN CAST Skill 2** (e.g. Naruto casts `Multi-Shadow Clone Jutsu` summoning 3–4 fragile 45 HP clones that throw shurikens and charge Rasengans).
  * **2-Tier Drops**:
    * Normal Clear: 100% Guaranteed 1st drop of **Skill 1**.
    * Hard Clear: 100% Guaranteed 1st drop of **Skill 2** (Hard Mode Exclusive).

---

## 💎 Phase 3: Rogue-lite & Meta Progression

### ⏳ Priority 6: Temporary In-Run 3-Socket Rune System
* **Status**: ⏳ **PENDING**
* **Specification Document**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RUNES_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RUNES_SYSTEM.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/BuildService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/BuildService.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StoryService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StoryService.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/StarterPlayer/StarterPlayerScripts/Riftbound/HUD.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/StarterPlayer/StarterPlayerScripts/Riftbound/HUD.lua)
* **Summary**:
  * Runes follow the *Hades* temporary boons model:
    * 3 sockets per skill (LMB, Q, E, Anime skills; Dash has 0 sockets).
    * Sockets start completely **EMPTY** at the beginning of each run.
    * Clearing each wave drops 1 rune to dynamically socket mid-run.
    * When the run ends (victory or defeat), **all socketed runes are wiped/reset**. Runes never save to the lobby backpack.

---

### ⏳ Priority 7: Player Equipment System & Lobby Relic Vault (Gold Gacha)
* **Status**: ⏳ **PENDING**
* **Specification Document**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/PLAYER_EQUIPMENT_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/PLAYER_EQUIPMENT_SYSTEM.md)
* **Code Files to Modify / Create**:
  * `src/ServerScriptService/Riftbound/EquipmentService.lua` *(New)*
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StatService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/StatService.lua)
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/StarterPlayer/StarterPlayerScripts/Riftbound/LobbyMenu.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/StarterPlayer/StarterPlayerScripts/Riftbound/LobbyMenu.lua)
* **Summary**:
  * 3 permanent lobby gear slots: 💍 **Ring** (Crit Chance, Crit DMG, Flat Dmg), 🛡️ **Armor** (Max HP, HP %, Dmg Reduction), 👢 **Boots** (Speed, Dash Recovery, CDR).
  * Rarities: Common (1 Substat) ➔ Legendary (3 Substats + 1 Unique Trait).
  * Crossroads Lobby Relic Vault (Gold Gacha): 600 Gold per single roll; 5,400 Gold per 10x roll. Pity at 10 (Epic) and 50 (Legendary).
  * Gear salvage refund system.

---

### ⏳ Priority 8: Gamepass Monetization Integration
* **Status**: ⏳ **PENDING**
* **Specification Document**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAMEPASS_MONETIZATION.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAMEPASS_MONETIZATION.md)
* **Code Files to Modify**:
  * [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/MarketService.lua`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/src/ServerScriptService/Riftbound/MarketService.lua)
* **Summary**:
  * Wire `MarketplaceService` prompt purchase and gamepass entitlement checks for the official 6 passes:
    1. 🧲 **Infinite Magnet** (199 R$) – Infinite range auto-collection of Gold & XP.
    2. 💰 **2x Gold Booster** (249 R$) – 2x Gold from mobs and Act clear bounties.
    3. 📈 **2x XP Booster** (249 R$) – 2x XP from kills.
    4. 📦 **2x Match Drops** (399 R$) – 2x Shards/Cores/Essences and 2 Runes per wave.
    5. 🍀 **Lucky Runes** (399 R$) – +25% Luck on wave Rune drops.
    6. 👑 **VIP: Rift Sovereign** (799 R$) – Golden chat tag, aura, +20% Gold/XP, daily free tribute.

---

## 🔗 Master Document Links
* **Master Index**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFTBOUND_SYSTEMS_MASTER.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFTBOUND_SYSTEMS_MASTER.md)
* **Combat Balance**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAME_BALANCE_GUIDE.md)
* **Gold Economy**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GOLD_ECONOMY_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GOLD_ECONOMY_SYSTEM.md)
* **Story Drops**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/STORY_DROPS_AND_MATERIALS.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/STORY_DROPS_AND_MATERIALS.md)
* **Skill Awakening**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/SKILL_EVOLUTION_AND_CRAFTING.md)
* **Rift Bolt & Dash**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFT_BOLT_AND_DASH.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RIFT_BOLT_AND_DASH.md)
* **Anime Bosses**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/ANIME_BOSSES_AND_SKILLS.md)
* **Runes System**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RUNES_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/RUNES_SYSTEM.md)
* **Player Equipment**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/PLAYER_EQUIPMENT_SYSTEM.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/PLAYER_EQUIPMENT_SYSTEM.md)
* **Monetization**: [`c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAMEPASS_MONETIZATION.md`](file:///c:/Users/LayPl/OneDrive/Documents/GitHub/riftbound/GAMEPASS_MONETIZATION.md)
