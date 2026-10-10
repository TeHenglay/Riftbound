# Riftbound – Skill Rune System Specification

This document details the complete design, mechanics, and catalog for the **Rune System** in *Riftbound*.

---

## 1. System Overview

### Core Concept
* **3 Rune Slots per Skill**: Every equipped skill (Rift Bolt / LMB, Skill Q, Skill E) features 3 socket slots for modifiers.
* **Wave Clear Reward**: Clearing each enemy wave in the Rift drops **1 Rune** (or offers a choice of runes).
* **Skill Customization**: Runes socket directly into a skill, modifying its damage, behavior, shape, elemental interactions, or cooldown flow.
* **Stacking**: Players can stack duplicate runes across multiple slots unless marked unique (e.g. stacking two `+1 Projectile` runes yields `+2 Projectiles`).

---

## 2. Drop Rarity & Wave Progression

| Rarity | Visual Border / Aura | Wave Window | Drop Weight |
| :--- | :--- | :--- | :--- |
| **Common (⚪)** | Slate White / Gray | Waves 1+ | High (~60% in early waves) |
| **Rare (🔵)** | Rift Blue | Waves 3+ | Moderate (~30%) |
| **Epic (🟣)** | Deep Violet | Waves 7+ | Low (~10% from normal waves, guaranteed on mini-bosses) |
| **Legendary (🌟)** | Prismatic Gold / Radiant | Wave 10+ / Bosses | Very Rare (~3% or guaranteed Boss clear choice) |

---

## 3. Rune Catalog

### ⚪ Common Runes (Foundational Stat Boosters)
*Reliable stat amplifiers that drop frequently to start establishing a build early.*

| Rune Name | Effect | Description |
| :--- | :--- | :--- |
| **Rune of Might** | **+15% Skill Damage** | Consistent damage boost for any skill. |
| **Rune of Expansion** | **+15% Skill Area / Radius / Width** | Increases AoE coverage for strikes, zones, and novas. |
| **Rune of Haste** | **-12% Skill Cooldown** | Lowers waiting time between skill uses. |
| **Rune of Reach** | **+30% Max Range / Travel Distance** | Allows projectiles and strikes to reach further across the arena. |
| **Rune of Impact** | **+50% Knockback Force** | Increases the pushback applied to enemies on hit. |
| **Rune of Lingering** | **+1.5s Zone & Status Duration** | Prolongs ground hazards (Steam Cloud, Lava pools) and status effects. |
| **Rune of the Prospector** | **+20% Gold & XP drops** from hit enemies | Farming rune to accelerate level and stat gains. |
| **Rune of Heavy Mass** | **+10% Damage**, -5% flight speed | Sacrifices projectile speed for raw impact power. |

---

### 🔵 Rare Runes (Mechanical & Tactical Modifiers)
*Introduces shape shifts, conditional spikes, and target adjustments.*

| Rune Name | Effect | Description |
| :--- | :--- | :--- |
| **Rune of Multishot** | **+1 Projectile** | Fires an additional projectile in a tight angled fan. |
| **Rune of Piercing** | **Pierces through 2 enemies** | Projectiles continue flying through targets instead of terminating on first contact. |
| **Rune of Ricochet** | **Bounces to 1 nearby enemy** | Hits bounce off targets or walls toward the nearest enemy. |
| **Rune of Precision** | **+18% Critical Strike Chance** | Crits inflict 175% base damage. |
| **Rune of the Executioner** | **+10% Damage to targets below 35% HP** | Helps finish off weakened enemies and champions. |
| **Rune of the Giant Hunter** | **+25% Damage vs Elites & Bosses** | Dedicated single-target boss slayer modifier. |
| **Rune of Deep Chill** | **Applies 15% Slow for 3s** | Adds crowd control to skills that lack innate slowing effects. |
| **Rune of Tremor** | **+0.8s Stun Duration** | Extends stun lock-down windows on skills with stun. |
| **Rune of Momentum** | **+3% Move Speed per enemy hit for 4s** | Stacks up to 5 times (max +15% Movement Speed). |

---

### 🟣 Epic Runes (High-Impact & Playstyle Anchors)
*Powerful modifiers that fundamentally boost skill loops, survival, or combo chains.*

| Rune Name | Category | Effect & Mechanics |
| :--- | :--- | :--- |
| **Rune of the Aftershock** | Offensive | **0.5s after impact, triggers a secondary burst** dealing 45% damage at the impact spot. |
| **Rune of the Graviton Vortex** | Crowd Control | **Pulls enemies within 16 studs inward** toward the center of the spell impact. |
| **Rune of the Magma Trail** | Hazard Area | Projectiles and rollers leave a **scorch trail** dealing 12 fire damage/sec for 3 seconds. |
| **Rune of Twin Spark** | Burst Chance | Gives the skill a **22% chance to cast instantly a second time** at no cooldown cost. |
| **Rune of Thermal Shock** | Reaction | Hitting a Soaked enemy with this Fire skill triggers a steam blast that **stuns nearby targets for 1.2s**. |
| **Rune of Overloaded Voltage** | Reaction | Shocked enemies hit by this skill emit an **arc of electricity zapping 3 nearby targets**. |
| **Rune of the Blood Siphon** | Sustain | Restores **4% of damage dealt as Health** (or +3 HP per hit). |
| **Rune of the Aegis Ward** | Defense | Hitting 3+ enemies grants a **barrier shield equal to 10% Max HP** for 5s (Has a **10s cooldown**). |
| **Rune of the Windrunner** | Mobility | Casting this skill **instantly refreshes Dash (Shift) cooldown**. |

---

### 🌟 Legendary Runes (Rule-Breaking Game Changers)
*Build-defining drops with unique mechanics and visual auras.*

| Rune Name | Archetype | Core Mechanics |
| :--- | :--- | :--- |
| **Rune of the Phantom Twin** | Clone Cast | Spawns a spectral clone beside the player that **casts the exact same skill simultaneously**. |
| **Rune of the Celestial Orbit** | Orbit Defense | Projectiles **orbit the player for 8 seconds** as a protective barrier instead of firing straight. |
| **Rune of the Chain Reaction** | Corpse Explosion | Enemies slain by this skill **detonate**, releasing a mini-burst that hits neighboring targets. |
| **Rune of the Singularity** | Arena Control | Impact point collapses into a **super-dense black hole**, pulling enemies across the arena into one clump. |
| **Rune of the Endless Cascade**| Cooldown Reset | Killing an enemy with this skill **instantly resets its cooldown to 0**. |
| **Rune of the Triple Charge** | Stockpile Burst | Replaces the single cooldown with **3 rechargeable skill charges** for instant triple-casting. |
| **Rune of the Dash Weaver** | Spell Mobility | Pressing **Dash (Shift)** automatically **casts this skill for free** toward the dash direction. |
| **Rune of the Prismatic Prism**| Dual Element | Infuses the skill with a **random second element** that rotates on cast, enabling solo elemental reactions. |
| **Rune of Absolute Zero** | Execute | Hits freeze enemies solid; frozen targets **below 25% HP shatter and are instantly executed**. |
| **Rune of the Cataclysm** | Screen Wiping | Increases Area / Radius by **+120%** and triggers arena-wide screen shake on impact. |
| **Rune of the Spell-Totem** | Automated Turret | Plants a Rift Totem that **automatically casts this skill every 1.2 seconds** for 6 seconds. |
| **Rune of the Blood Pact** | Rapid Spam | **-80% Cooldown reduction**, but casting consumes 5% current HP (refunded if hitting 3+ enemies). |

---

## 4. Socketing Rules & Limitations

1. **Slots per Skill**: Each skill has exactly **3 sockets**.
2. **Legendary Limit**: A maximum of **1 Legendary Rune** may be equipped per skill (1 Legendary + 2 Normal/Rare/Epic Runes) to preserve balance.
3. **Additive Stacking**: Common and Rare stat runes stack additively (e.g. two *Rune of Expansion* socketed = `+30% Area`).
4. **Hot-Swapping**: Runes can be unsocketed or swapped between skills in the Backpack (`B`) or during post-wave reward menus.
