# Riftbound – Player Equipment System Specification

This document details the **Player Equipment System (Relics & Gear)**, its 3-slot structure, stat attributes, rarity tiers, and the lobby **Relic Vault (Gold Gacha)** in *Riftbound*.

---

## 1. System Overview & Design Philosophy

The Equipment System provides **permanent meta-progression** that players customize and upgrade in the lobby between runs:

1. **Separation of Power**:
   * **Skills (Bosses & Forge)**: 100% earned by conquering Acts and challenging bosses on Hard Mode. Zero skill gacha.
   * **Runes (In-Run)**: Temporary rogue-lite modifiers earned wave-by-wave inside each match, resetting upon completion.
   * **Equipment (Lobby)**: Permanent baseline stat modifiers (HP, Crit, Speed) equipped in the lobby to define your character's foundation.
2. **Infinite Gold Sink**:
   * Solves the long-term economy challenge by giving players a rewarding, exciting sink for farmed Gold Coins and Rift Shards.
3. **Avatar Fashion Preservation**:
   * Equipment does **NOT overwrite** or distort the player's custom Roblox avatar clothing (shirts/pants).
   * Gear displays as subtle floating radiant accents (e.g. glowing aura rings around wrists, a shimmering crest on the chest, particle glimmers on feet) with an in-game **"Show Gear Visuals" Toggle** in the settings.

---

## 2. The 3 Equipment Slots

Every player has **3 core gear slots**:

```
┌────────────────────────────────────────────────────────┐
│ 💍 SLOT 1: RING / TALISMAN     (Offensive Power & Crit)│
├────────────────────────────────────────────────────────┤
│ 🛡️ SLOT 2: ROBE / ARMOR        (Defense, HP & Shields) │
├────────────────────────────────────────────────────────┤
│ 👢 SLOT 3: BOOTS / GREAVES     (Mobility & Cooldowns)  │
└────────────────────────────────────────────────────────┘
```

---

### 💍 Slot 1: Ring / Talisman (Offensive Focus)
The Ring amplifies spell potency, critical strike opportunities, and damage scaling:

* **Primary Stat**: Flat Damage (`+3` to `+15` Base Spell Damage).
* **Possible Random Substats**:
  * **Critical Strike Chance**: `+4%` to `+18%`
  * **Critical Strike Damage**: `+15%` to `+45%` (Base crit multiplier is 150%)
  * **Elemental Damage Boost**: `+6%` to `+20%` (Fire, Water, Earth, Wind, or Lightning)
  * **Armor Penetration / Shred**: `+5%` to `+15%`

---

### 🛡️ Slot 2: Robe / Armor (Defense & Survivability Focus)
Armor provides the health pool and damage mitigation needed to survive elite mob swarms and Act 3 boss hits:

* **Primary Stat**: Flat Max HP (`+50` to `+300` Max HP).
* **Possible Random Substats**:
  * **Max Health Percentage**: `+5%` to `+22%` Max HP
  * **Damage Reduction**: `+4%` to `+14%` Incoming Damage Reduction
  * **Health Regeneration**: `+1.5` to `+6.0` HP restored per second
  * **Status Resistance**: `+15%` to `+40%` reduced duration of Burn, Shock, Soak, Slow, and Stun

---

### 👢 Slot 3: Boots / Greaves (Mobility & Flow Focus)
Boots enhance dodge maneuverability, walk speed, and skill rhythm:

* **Primary Stat**: Walk Speed (`+1.0` to `+3.5` Base WalkSpeed; default speed is 16).
* **Possible Random Substats**:
  * **Dash Recovery Rate**: `+10%` to `+30%` faster Dash cooldown recovery
  * **Global Cooldown Reduction**: `-4%` to `-14%` Cooldown on all equipped skills
  * **Movement Speed on Cast**: `+10%` to `+20%` temporary speed burst for 1.5s after casting Q or E
  * **Sprint Acceleration**: Faster turn rate and evasion friction

---

## 3. Rarity Tiers & Substat Structure

When equipment is rolled or forged, it receives a rarity tier that determines its substat capacity and stat roll ranges:

| Rarity Tier | Drop Rate | Substats | Roll Quality | Unique Legendary Trait? |
| :--- | :---: | :---: | :---: | :---: |
| ⚪ **Common** | **60.0%** | **1 Substat** | Base range | ❌ No |
| 🔵 **Rare** | **28.0%** | **2 Substats** | Mid range | ❌ No |
| 🟣 **Epic** | **10.0%** | **3 Substats** | High range | ❌ No |
| 🌟 **Legendary** | **2.0%** | **3 Substats** | Maximum rolls | ✅ **YES (1 Unique Trait!)** |

---

## 4. 🌟 Legendary Equipment Catalog (Unique Traits)

Legendary equipment pieces possess unique, build-defining perks:

### 💍 Legendary Rings
1. **Eye of the Rift Sovereign**:
   * *Trait*: Landing a Critical Strike triggers a **seismic shockwave** dealing 30% of the damage to all surrounding enemies.
2. **Bloodthirst Signet**:
   * *Trait*: Critical strikes restore **5% of damage dealt as Health** (sustain engine).
3. **Prismatic Band of Harmony**:
   * *Trait*: Dealing damage with an elemental reaction (e.g. Steam, Mud, Shock) grants **+20% bonus skill damage** for 4 seconds.
4. **Executioner's Coil**:
   * *Trait*: Attacks against enemies below 30% HP have **100% Critical Strike Chance**.

### 🛡️ Legendary Robes & Armors
1. **Aegis of the Immortal**:
   * *Trait*: When dropping below 30% HP, instantly gain a **barrier equal to 35% Max HP** for 6 seconds (90s internal cooldown).
2. **Mantle of Volcanic Wrath**:
   * *Trait*: Taking damage erupts **retaliatory magma sparks**, dealing 25 fire damage to nearby attackers and inflicting Burn.
3. **Unstoppable Carapace**:
   * *Trait*: Gain **immunity to staggers and knockbacks** for 3 seconds after casting your Q skill.
4. **Elder Treant's Bark**:
   * *Trait*: Standing still for 1 second doubles HP regeneration and grants +15% damage reduction.

### 👢 Legendary Boots & Greaves
1. **Zephyr Wing Striders**:
   * *Trait*: Slain enemies grant **+25% Movement Speed** for 3 seconds (stacks up to 2 times).
2. **Chrono Treads**:
   * *Trait*: Every 4th consecutive Dash **resets the cooldown of your Q skill** immediately.
3. **Phantom Flicker Greaves**:
   * *Trait*: Dashing creates a decoy after-image that taunts nearby enemies for 1.2 seconds.
4. **Tectonic Stompers**:
   * *Trait*: Dashing into an enemy applies a **0.6s Stun** and micro shockwave.

---

## 5. 🏛️ The Lobby "Relic Vault" (Gold Gacha)

Located in the **Crossroads Lobby** at the Relic Vault pedestal:

### 🪙 Roll Pricing
* **Single Roll (1x Relic)**: `600 Gold` *(or 10x Rift Shards)*
* **Bulk Roll (10x Relics)**: `5,400 Gold` *(10% discount; or 90x Rift Shards)*

### 🛡️ Pity & Bad-Luck Protection
1. **Epic Pity (10 Pulls)**: Every 10 pulls guarantees at least **1 Epic (🟣) or higher** gear piece.
2. **Legendary Pity (50 Pulls)**: If a player does not pull a Legendary within 49 pulls, the **50th pull is 100% guaranteed to be Legendary (🌟)**!
3. **Pity Persistence**: Pull counters persist across game sessions and are saved to player DataStore.

### ♻️ Gear Salvage (Scrap System)
Players can dismantle unwanted equipment at the Relic Vault to refund resources:
* **Common Gear**: Yields `150 Gold` (25% refund).
* **Rare Gear**: Yields `300 Gold` + `1x Rift Shard`.
* **Epic Gear**: Yields `600 Gold` + `3x Rift Shards`.
* **Legendary Gear**: Yields `1,500 Gold` + `8x Rift Shards` + `1x Nation Shard`.

---

## 6. ⚔️ Synergy with the Full Gameplay Loop

```
┌────────────────────────────────────────────────────────┐
│ 1. COMBAT RUN (In-Match)                               │
│    • Slay 10+ mobs/wave ➔ Earn Gold & XP              │
│    • Clear waves ➔ Socket temporary in-run Runes       │
│    • Beat Hard Naruto/Ace ➔ Earn mythic Boss Skills    │
│    • Clear Act ➔ Receive massive Gold & Shard bundles  │
└────────────────────────────────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│ 2. RETURN TO LOBBY (Crossroads)                        │
│    • Forge & Awaken skills with Shards & Cores         │
│    • Spend Gold at the RELIC VAULT for Gear rolls      │
│    • Hunt for "God Roll" Legendary Rings, Armor, Boots │
│    • Equip highest synergy gear to boost base stats    │
└────────────────────────────────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│ 3. ENTER NEXT RUN STRONGER                             │
│    • Enter Act 3 Hard Mode with higher base Crit & HP  │
│    • Overcome tougher challenges and conquer Riftbound!│
└────────────────────────────────────────────────────────┘
```
