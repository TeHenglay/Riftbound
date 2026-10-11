# Riftbound – Skill Awakening & Crafting System Specification

This document details the mechanics, progression loops, and complete recipe catalog for the **Skill Awakening System** and the **Skill Crafting System** in *Riftbound*.

---

## 1. Skill Acquisition: Nation Choice (No More Shrines)

**Shrines in the arena have been completely removed.** Players no longer wander around clicking shrines to pick up random skills.

Instead, your starting skill is defined by your **Nation Choice** upon character creation:

| Chosen Nation | Starting Signature Skill | Starting Basic Attack | Element |
| :--- | :--- | :--- | :--- |
| **🔥 Ember Dominion (Fire)** | **Fireball** | **Rift Bolt** | Fire |
| **🌊 Tidewater Court (Water)** | **Tidal Wave** | **Rift Bolt** | Water |
| **🪨 Stonehold Clans (Earth)** | **Stone Spike** | **Rift Bolt** | Earth |
| **🌪️ Skyreach Nomads (Wind)** | **Gust** | **Rift Bolt** | Air / Wind |
| **⚡ Stormcall Order (Lightning)**| **Spark Bolt** | **Rift Bolt** | Lightning |

### Skill Drops from Act 1 Clears (50% Drop Chance):
When clearing **Act 1** of any nation's story, there is a **50% Chance** to drop the signature base skill of that nation:
* **🔥 Fire Act 1 Clear**: 50% chance to drop **Fireball**
* **🌊 Water Act 1 Clear**: 50% chance to drop **Tidal Wave**
* **🪨 Earth Act 1 Clear**: 50% chance to drop **Stone Spike**
* **🌪️ Wind Act 1 Clear**: 50% chance to drop **Gust**
* **⚡ Lightning Act 1 Clear**: 50% chance to drop **Spark Bolt**

#### What Happens When a Skill Drops?
1. **If New (Not Owned Yet)**: Unlocks the skill into your Arsenal so you can equip it or use it for Forge Crafting. *(e.g. A Fire player clears Water Act 1 and unlocks Tidal Wave to craft Steam Cloud).*
2. **If Already Owned**: Grants **+1 Skill Level** (up to Level 5) or provides a **Duplicate Copy** required for **Skill Evolution**! This gives players a reason to farm their home nation's Act 1 to power up their starting skill toward Evolution.

---

## 2. System Overview & Architecture

Progression in *Riftbound* branches into two distinct pathways:

```
                          ┌── [EVOLUTION] ───> Ascended Skill (Vertical Power)
                          │                    Home Skill + Mastery (Lv 5) + Catalysts
                          │                    • +20% Base Damage
                          │                    • +25% to +35% Visual & Hitbox Size
                          │                    • Unique Mechanical Perk
                          │
[EQUIPPED BASE SKILL] ────┤
                          │
                          └── [CRAFTING] ────> Fused Skill (Horizontal Synergy)
                                               2 different unlocked skills + Materials
                                               • New dual-element mechanics
                                               • Elemental reaction triggers
                                               • Forged at the Forge
```

* **Vertical Progression (Awakening)**: Specialize deeply in your starting element (e.g. A Fire player awakening Fireball into Fireball Awakened).
* **Horizontal Progression (Crafting)**: Clear other nation stories to unlock their elements, then combine them at the Forge for reaction synergies.

---

## 2. The Skill Awakening System

### Awakening Mechanics (Strictly Balanced & Earned)
Awakening turns a skill into its **Awakened Form**. Because this is a permanent, high-tier power spike (+20% damage, +30% size, and a brand new mechanic), **it cannot be obtained easily in early runs**.

#### Prerequisites to Awaken:
1. **Mastery (Max Level 5)**: The base skill must already be upgraded to **Level 5**.
2. **Awakening Catalyst**: Requires **1x Nation Essence** (earned by defeating an Act 3 Boss) **OR 2x Nation Cores** (from Act 2 clears). *You cannot awaken in Act 1.*
3. **Material Requirements**:
   * **8x Nation Shards** (e.g. 8x Fire Shards for Fireball). Requires farming across multiple act clears.
   * **15x Rift Shards**.
4. **Gold Cost**: **2,500 Gold** paid at the Forge / Master Shaper.
5. **Rune Sockets**: Awakened skills maintain all **3 Rune Slots**, and any runes already equipped remain socketed.

---

### Awakened Skill Catalog

#### 🔥 1. Fireball ➔ **Fireball Awakened**
* **Element**: Fire
* **Visual**: A massive, raging sun-sphere with solar corona flares and ember trails.
* **Core Upgrades**:
  * **+20% Damage** (22 ➔ 26.4 base damage).
  * **+30% Explosion Radius** (8 ➔ 10.4 studs).
* **Awakened Perk (Molten Crater)**: Detonation leaves a fiery scorch patch on the ground that ticks **8 fire damage/sec for 2.5 seconds** and applies Burn to enemies walking through.

#### 🌊 2. Tidal Wave ➔ **Tidal Wave Awakened**
* **Element**: Water
* **Visual**: A towering wall of turbulent blue water crowned with foaming white rapids.
* **Core Upgrades**:
  * **+20% Damage** (16 ➔ 19.2 base damage).
  * **+35% Wave Width & Length** (Length 34 ➔ 46 studs, Width 12 ➔ 16 studs).
* **Awakened Perk (Surging Rapids)**: **+50% Knockback Force** (40 ➔ 60 force). Leaves flooded ground for 4 seconds that applies **Soaked** to any enemy crossing it.

#### 🪨 3. Stone Spike ➔ **Stone Spike Awakened**
* **Element**: Earth
* **Visual**: Three jagged crystalline stone monoliths violently burst from the earth with deep ground fissures.
* **Core Upgrades**:
  * **+20% Damage** (30 ➔ 36 base damage).
  * **+30% Strike Radius** (7 ➔ 9.1 studs).
* **Awakened Perk (Crush & Concuss)**: **Stun duration increased by +0.6s** (1.0s ➔ 1.6s). Targets crushed by the spikes take **+15% bonus physical/earth damage** for 3 seconds.

#### 🌪️ 4. Gust ➔ **Gust Awakened**
* **Element**: Air
* **Visual**: A ferocious swirling hurricane vortex with air distortion rings and dust clouds.
* **Core Upgrades**:
  * **+20% Damage** (10 ➔ 12 base damage).
  * **+35% Blast Radius** (16 ➔ 21.6 studs).
* **Awakened Perk (Inward Vortex)**: Before detonating outward, it pulls all nearby enemies inward toward the caster for 0.3s, grouping them before blasting them away with massive knockback.

#### ⚡ 5. Spark Bolt ➔ **Spark Bolt Awakened**
* **Element**: Lightning
* **Visual**: Blinding violet-yellow lightning beam that leaves sizzling plasma arcs in the air.
* **Core Upgrades**:
  * **+20% Damage** (14 ➔ 16.8 base damage).
  * **+2 Additional Chain Jumps** (3 ➔ 5 jumps).
* **Awakened Perk (Static Tether)**: Jumping lightning creates a lingering electric arc between targets for 2 seconds that damages any enemy walking between them.

#### 🔮 6. Rift Bolt (M1 Attack) ➔ **Rift Bolt Awakened**
* **Element**: Void / Rift
* **Visual**: A dense, pulsing void crystal fired forward with trailing rift shards.
* **Core Upgrades**:
  * **+20% Damage** (8 ➔ 9.6 base damage).
  * **+25% Projectile Scale**.
* **Awakened Perk (Phasing Core)**: Projectile **pierces through 1 enemy**, hitting a secondary target behind them. Every 4th hit releases a +15 AoE burst.

---

## 3. The Skill Crafting System (The Forge)

### Crafting Mechanics
* **Location**: Performed at the **Forge** in the Rift.
* **Inputs**:
  1. **Base Skill A** (consumed)
  2. **Base Skill B** (consumed)
  3. **Crafting Materials** (collected from enemy drops and waves)
* **Result**: **Fused Skill** created at the higher level of the two component skills.
* **Rune Handling**: Any runes socketed into the consumed base skills are **automatically unequipped and refunded to the player's rune inventory**, ready to be socketed into the newly crafted skill.

---

### Required Materials Breakdown

| Material | Rarity | Drop Source | Description |
| :--- | :--- | :--- | :--- |
| **Rift Shard** | Common (60%) | All Rift Husks | The fundamental stabilizing crystal for forging. |
| **Husk Ichor** | Uncommon (25%) | Elite Husks & Brutes | Biological binding agent for elemental blending. |
| **Ember Core** | Rare (6%) | Champions & Boss Waves | High-energy catalyst required for pinnacle fusions. |

---

### Crafting Recipe Table (Balanced Forging at the Forge)
Crafting requires collecting materials from Act Clears across the required nations:

| Fused Skill | Components | Required Materials & Gold | Description |
| :--- | :--- | :--- | :--- |
| **Steam Cloud** | Fireball + Tidal Wave | 4x Fire Shard + 4x Water Shard<br>8x Rift Shard + 1,000 Gold | Scalding cloud that burns and slows targets inside. |
| **Magma Meteor** | Fireball + Stone Spike | 5x Fire Shard + 5x Earth Shard<br>1x Ember Core + 12x Rift Shard + 1,750 Gold | Molten meteor that crashes and leaves a pool of burning lava. |
| **Firestorm** | Fireball + Gust | 4x Fire Shard + 4x Wind Shard<br>8x Rift Shard + 1,200 Gold | Fire tornado pulling enemies inward while dealing burn ticks. |
| **Plasma Lance** | Fireball + Spark Bolt | 5x Fire Shard + 5x Lightning Shard<br>1x Ember Core + 12x Rift Shard + 1,750 Gold | Piercing spear of plasma exploding on impact with Burn + Shock. |
| **Mudslide** | Tidal Wave + Stone Spike | 4x Water Shard + 4x Earth Shard<br>8x Rift Shard + 1,000 Gold | Massive rolling mud boulder that flattens, soaks, and slows. |
| **Frost Gale** | Tidal Wave + Gust | 4x Water Shard + 4x Wind Shard<br>8x Rift Shard + 1,200 Gold | Freezing blizzard cone that slows and freezes enemies in ice. |
| **Chain Shock** | Tidal Wave + Spark Bolt | 5x Water Shard + 5x Lightning Shard<br>1x Volt Core + 12x Rift Shard + 1,500 Gold | Leaping lightning chain that shocks and soaks large groups. |
| **Quake Leap** | Stone Spike + Gust | 4x Earth Shard + 4x Wind Shard<br>8x Rift Shard + 1,200 Gold | High leap slamming down with two rings of stone spikes. |
| **Magnet Quake** | Stone Spike + Spark Bolt | 5x Earth Shard + 5x Lightning Shard<br>1x Volt Core + 12x Rift Shard + 1,750 Gold | Magnetic core that gathers enemies, then detonates in shock. |
| **Thunderstorm** | Gust + Spark Bolt | 6x Wind Shard + 6x Lightning Shard<br>1x Volt Core + 14x Rift Shard + 2,000 Gold | Persistent storm cloud raining down continuous lightning strikes. |

---

## 4. Synergy with the 3-Slot Rune System

Both Evolved skills and Crafted skills feature **3 Rune Sockets**, creating deep customization options:

1. **Evolved Skill + Runes**:
   * Example: **Pyroclasm** (Great Fireball) + *Rune of Multishot* (+1 Projectile) + *Rune of Expansion* (+15% Size).
   * Result: Two giant, screen-shaking suns fired simultaneously, covering half the arena in molten lava!
2. **Crafted Skill + Runes**:
   * Example: **Magma Meteor** + *Rune of the Singularity* (Legendary Black Hole) + *Rune of the Aftershock* (Epic Echo).
   * Result: A meteor crashes down, vacuums the entire wave into the lava pit, and triggers a secondary shockwave!
