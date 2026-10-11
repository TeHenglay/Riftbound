# Riftbound – Gold Economy & Shop System Specification

This document details the complete currency scaling, income sources, and spending sinks for **Gold Coins** in *Riftbound*.

---

## 1. Economy Architecture (10x Scaled RPG Standard)

Gold uses a classic action-RPG scale where killing enemies showers the screen with double-digit drops (`+20 to +50 Gold`), making wave clearing visually satisfying and rewarding.

```
                           ┌── 1. The Forge & Rune Workshop (Crafting, Ascension, Rerolling)
                           │
                           ├── 2. The Mid-Run Void Merchant (Emergency Flask, Mystery Runes, Buffs)
GOLD INCOME (💰) ──────────┤
                           ├── 3. The Crossroads Lobby Shop (Permanent Flask Upgrades & Stat Respec)
                           │
                           └── 4. The Material Exchange (Rift Shards & Husk Ichor)
```

---

## 2. Gold Income Sources

### A. Combat Mob Drops (During Waves)
Enemies drop gold coins upon death that fly directly to the player when nearby:

| Enemy Role | Gold Drop Per Kill | Notes |
| :--- | :---: | :--- |
| **Swarmer (Scout)** | **10 – 25 Gold** | Small, fast coin fountains from AoE pack clears. |
| **Grunt (Soldier)** | **30 – 50 Gold** | Consistent standard combat income. |
| **Brute (Heavy)** | **80 – 140 Gold** | Substantial bounty from high-threat mobs. |
| **Elite (Captain)** | **150 – 250 Gold** | Large prize for defeating glowing captains. |

### B. Story Mode Act Clear Bounties
Awarded in the victory summary screen upon clearing an Act:

| Act Milestone | Base Gold Bounty | Hard Difficulty (2.0x) | Nightmare Difficulty (3.0x) |
| :--- | :---: | :---: | :---: |
| **Act 1 Clear** | **500 Gold** | 1,000 Gold | 1,500 Gold |
| **Act 2 Clear** | **1,000 Gold** | 2,000 Gold | 3,000 Gold |
| **Act 3 Boss Victory** | **2,500 Gold** | 5,000 Gold | 7,500 Gold |

---

## 3. The Forge & Rune Workshop (Build Crafting)

Gold serves as the crafting fee for the Master Shaper at the Forge:

| Service | Gold Cost | Required Materials | Description |
| :--- | :---: | :--- | :--- |
| **Craft Fused Skill (Tier 1)** | **1,000 Gold** | 4x Shard A + 4x Shard B + 8x Rift Shard | Forges utility/CC fusions (*Steam Cloud*, *Mudslide*). |
| **Craft Fused Skill (Tier 2)** | **1,750 Gold** | 5x Shard A + 5x Shard B + 1x Core + 12x Rift Shard | Forges heavy fusions (*Magma Meteor*, *Thunderstorm*). |
| **Awaken Base Skill (Awakening)** | **2,500 Gold** | Skill Lv 5 + 1x Essence/2x Cores + 8x Shard + 15x Rift Shard | Transforms base skill into its Awakened Form (*Fireball Awakened*). |
| **Reforge / Reroll a Rune** | **400 Gold** | Any socketed or inventory rune | Rerolls the rune into a different rune of the same rarity. |
| **Upgrade Rune Rarity** | **1,200 Gold** | Common Rune | Elevates a Common Rune to a Rare Rune. |

---

## 4. The Mid-Run Void Merchant (In-Rift Shop)

A wandering void peddler appears at rest shrines between waves or prior to boss battles:

| Item | Gold Cost | Gameplay Impact |
| :--- | :---: | :--- |
| **Emergency Flask Sip (+1 Charge)** | **350 Gold** | Restores 1 drink if you are low on HP before a boss. |
| **Full Flask Refill (All 3 Charges)** | **800 Gold** | Complete reset for life-or-death fights. |
| **Mystery Rune Chest (Rare)** | **750 Gold** | Instant power spike for an empty skill socket. |
| **Mystery Rune Chest (Epic)** | **1,500 Gold** | High-tier gamble for transformative runes (Echo, Vortex, Siphon). |
| **Blessing of Stone Skin** | **500 Gold** | Grants a +30 Max HP temporary barrier for the rest of the Act. |
| **Blessing of Ember Edge** | **500 Gold** | Grants +10% Skill Damage for the rest of the Act. |
| **Blessing of Gale Footing** | **500 Gold** | Grants +10% Movement Speed for the rest of the Act. |

---

## 5. The Crossroads Lobby Shop (Permanent Meta-Progression)

In the central Crossroads lobby, players invest their accumulated gold between runs into permanent upgrades:

### A. Permanent Rift Flask Upgrades
* **Capacity (Extra Charges)**:
  * 3 ➔ **4 Max Charges**: **4,000 Gold**
  * 4 ➔ **5 Max Charges**: **9,000 Gold**
* **Potency (Heal Percentage)**:
  * 30% ➔ **35% Heal per sip**: **3,500 Gold**
  * 35% ➔ **40% Heal per sip**: **7,500 Gold**

### B. Attribute Stat Respec (Reset Stat Points)
* **Cost**: **1,000 Gold**
* **Effect**: Refunds all spent attribute points (Vitality, Might, Swiftness, Focus) to allow experimenting with different stat builds.

### C. The Relic Vault (Equipment Gold Gacha)
* **Single Relic Roll**: **600 Gold** (or 10x Rift Shards) ➔ Rolls 1 piece of equipment (Ring, Armor, or Boots).
* **10x Relic Roll**: **5,400 Gold** (10% bulk discount; or 90x Rift Shards) ➔ Guaranteed 1 Epic (🟣) or higher.
* **Salvage Refunds**: Salvage unwanted gear for **150g / 300g / 600g / 1,500g** + bonus Rift Shards.

---

## 6. The Material Exchange (Bad Luck Protection)

The material merchant at Crossroads sells basic crafting materials if players are missing just a few items to complete a recipe:

| Material | Cost | Purpose |
| :--- | :---: | :--- |
| **1x Rift Shard** | **150 Gold** | Universal base crystal for forging. |
| **1x Husk Ichor** | **450 Gold** | Organic binding agent for fusions. |

*(Note: Elemental Shards, Cores, and Essences **cannot** be purchased with gold; they must be earned through story act clears).*
