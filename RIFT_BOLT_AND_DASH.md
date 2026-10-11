# Riftbound – Rift Bolt & Dash Progression Specification

This document details the socketing rules, progression loops, and evolution mechanics for **Rift Bolt** (Basic Attack / LMB) and **Dash** (Mobility / Shift) in *Riftbound*.

---

## 1. System Overview at a Glance

| Feature | **Rift Bolt (LMB)** | **Dash (Shift)** |
| :--- | :--- | :--- |
| **Primary Function** | Continuous basic ranged damage | Fast escape, repositioning, and evasion |
| **Equip Runes?** | **YES (3 Rune Sockets)** | **NO (0 Rune Sockets)** |
| **Can Awaken?** | **YES** | **YES** |
| **Awakened Form** | **Rift Bolt Awakened** (Heavy Piercing Void Bolt) | **Dash Awakened** (Nation Elemental Trait) |
| **Forge Awakening Fee** | 15x Rift Shard + 1,500 Gold | 6x Nation Shard + 10x Rift Shard + 1,500 Gold |

---

## 2. 🔮 Rift Bolt (Basic Attack / LMB)

### Base Mechanics
* **Damage**: 8 Base Damage.
* **Cooldown**: 0.35s (Rapid fire, ~23 DPS).
* **Speed / Range**: 120 Speed, 70 Studs Range.
* **Rune Sockets**: Features **3 Rune Sockets**. 
  * Compatible with Common, Rare, and Epic runes (such as *Rune of Multishot* for fanning bolts, *Rune of Piercing*, or *Rune of Precision* for crits).

---

### Awakened Form: **Rift Bolt Awakened**

When awakened at the Forge, Rift Bolt ascends into a heavier void projectile with trailing cosmic dust and high penetration power.

* **Visual & Audio**: Fired projectile is noticeably larger, with glowing crystalline edges and deep cosmic explosion audio on impact.
* **Core Stat Upgrades**:
  * **+20% Base Damage** (8 ➔ 9.6 Base Damage).
  * **+25% Projectile Size & Hitbox**.
* **Inherent Perk (Rift Resonance)**:
  * **Innate Pierce**: The bolt passes through **1 enemy**, hitting a secondary target directly behind it.
  * **Resonance Implosion**: Every **4th consecutive hit** triggers a mini void implosion, dealing **+15 bonus AoE Rift Damage** to all enemies within 8 studs of the target.
* **Awakening Requirements**:
  * Rift Bolt upgraded to **Level 5**.
  * **15x Rift Shards**.
  * **1,500 Gold** at the Forge.
  * *Note: All 3 socketed runes remain equipped upon awakening.*

---

## 3. 💨 Dash (Mobility / Shift)

### Base Mechanics
* **Duration**: 0.25 seconds.
* **Cooldown**: 2.5 seconds.
* **Invulnerability**: 0.2 seconds of i-frames (invulnerability frames).
* **Rune Rule**: **Dash CANNOT equip runes**. It is kept strictly as a reliable, clean mobility tool without rune management.

---

### Nation-Based Evolution Mechanics
Dash evolves into a unique elemental movement power based entirely on the **Nation the player chose at character creation**:

#### 🔥 1. Fire Nation (Ember Dominion) ➔ **Blaze Surge**
* **Visual**: Burst of fire beneath the caster's feet, leaving a scorched red fiery path.
* **Effect**: Leaves a **Trail of Fire** along your dash trajectory for **3.0 seconds**.
* **Combat Function**:
  * Enemies walking over the trail take **12 Fire Damage/sec** and suffer **Burn for 3 seconds**.
  * Ideal for kiting aggressive melee husks by dashing backwards through a choke point.

#### 🌊 2. Water Nation (Tidewater Court) ➔ **Tidal Wake**
* **Visual**: Surfs forward on a towering wave of frothing ocean water.
* **Effect**: Leaves a **Flooded Slipstream** behind you that pushes enemies sideways and drenches them in water.
* **Combat Function**:
  * Applies **Soaked for 4.0 seconds** to all enemies touched.
  * Directly sets up instant elemental reactions: follow up with Lightning for **Conduct (+50% dmg)** or Fire for **Evaporate (+25% dmg)**.

#### 🪨 3. Earth Nation (Stonehold Clans) ➔ **Tectonic Ram**
* **Visual**: The player encases in solid granite boulders and lunges forward like a living projectile.
* **Effect**: Allows dashing **directly through enemies** instead of colliding.
* **Combat Function**:
  * Dashing through foes deals **25 Earth Damage**, knocks them away, and **Stuns the first enemy hit for 0.8 seconds**.
  * Grants a temporary **15 HP Stone Barrier** for 2.0 seconds after landing.

#### 🌪️ 4. Wind Nation (Skyreach Nomads) ➔ **Zephyr Twin-Drift**
* **Visual**: The player dissolves into a rushing gale and blinks with razor-sharp wind trails.
* **Effect**: Dash gains **+1 Additional Charge (Double Dash!)** with 20% faster charge recovery.
* **Combat Function**:
  * Allows performing two rapid dashes back-to-back.
  * Grants **+25% Movement Speed for 2.0 seconds** after dashing, allowing unmatched arena kiting.

#### ⚡ 5. Lightning Nation (Stormcall Order) ➔ **Thunder Step**
* **Visual**: An instantaneous lightning flash-step accompanied by a sharp thunderclap.
* **Effect**: Instant teleportation to the target location. A persistent bolt of electricity arcs between your start position and landing spot for 0.5s.
* **Combat Function**:
  * All enemies caught between your start and end point take **20 Lightning Damage**.
  * Applies **Shock for 3.0 seconds** (enemies take +20% damage from all your incoming attacks).

---

### Dash Awakening Requirements at the Forge
Since Dash does not possess normal leveling ranks, awakening your Dash is unlocked by proving your allegiance:
* **6x Nation Shards** (matching your chosen nation, e.g. 6x Fire Shards for Fire Nation).
* **10x Rift Shards**.
* **1,500 Gold** paid to the Master Shaper at the Forge.

---

## 4. Synergy with Combat & Reactions

The combination of an Awakened Dash and an Awakened Rift Bolt creates dynamic combat loops:

* **Water Dash + Lightning Rift Bolt**: Dash through a pack to apply **Soaked**, then turn and fire **Rift Bolt Awakened** to trigger massive chain reactions!
* **Fire Dash + Wind Skill**: Dash through enemies to lay a **Blaze Surge**, then cast **Gust** to blow the enemies back into your fire trail for double burn ticks!
* **Earth Dash + Meteor**: Ram through an elite to **Stun** them for 0.8s, then immediately drop **Magma Meteor** while they are immobilized!
