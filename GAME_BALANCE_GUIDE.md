# Riftbound – Game Balance & Progression Guide (10+ Enemies Per Wave)

This guide provides the complete balance numbers, formulas, and wave breakdowns for *Riftbound*, configured specifically for **10+ enemies per wave** while keeping player leveling steady and controlled.

---

## 1. Combat Design with 10+ Enemies Per Wave

With at least 10 enemies on screen at once, *Riftbound* shifts into a high-intensity action roguelike where **AoE, crowd control (knockback/slow/stun), and rune synergies shine**.

### Key Rules for Horde Balance:
1. **Never spawn 10 damage-sponges at once**: A wave of 10 should consist of **fast, fragile fodder (Swarmers)** to slaughter quickly with AoE, mixed with **medium Grunts** and **1–2 heavy anchors (Brutes/Elites)**.
2. **Lower Individual Enemy Damage**: With 10 enemies, melee damage per hit must be modest (3–7 damage) so the player doesn't instantly evaporate if surrounded for 1 second.
3. **Scaled XP Drops**: Because players kill 40–60+ enemies per act, individual XP per kill is tuned down so the player does **not** level up too quickly.

---

## 2. Enemy Roster & Stats (Tuned for 10+ Packs)

| Enemy Type | HP | Speed | Hit Dmg | XP Drop | Gold Drop | Design Purpose |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Swarmer (Scout)** | **45 HP** | 13 | **3** | **2 XP** | **10–25 Gold** | Dies in 1 Fireball or 2 basic hits. Surrounds player. |
| **Grunt (Soldier)** | **95 HP** | 10 | **5** | **4 XP** | **30–50 Gold** | Main frontline body. Takes ~3-4 hits. |
| **Brute (Heavy)** | **220 HP** | 7.5 | **10** | **12 XP** | **80–140 Gold** | Slow, telegraphs telegraphed slam attacks. |
| **Elite (Captain)** | **420 HP** | 8.5 | **14** | **30 XP** | **150–250 Gold** | Glowing mini-boss; requires reaction combos. |
| **Act Boss** | **2,800 HP** | 8.0 | **18** | **250 XP** | **2,500 Gold** | Multi-phase boss fight with add waves. |

---

## 3. Wave Structure (Minimum 10 Enemies Per Wave)

### Act 1: The Outskirts (Total Enemies: 46)
*Target Player Level: Level 1 ➔ Level 2 by Wave 3/4*

* **Wave 1 (10 Enemies)**: 6 Swarmers + 4 Grunts
  * *Pacing: Introductory wave. Clearable with 1-2 well-aimed AoE casts.*
* **Wave 2 (11 Enemies)**: 6 Swarmers + 4 Grunts + 1 Brute
  * *Pacing: Introduces the heavy slam telegraph.*
* **Wave 3 (12 Enemies)**: 5 Swarmers + 6 Grunts + 1 Brute
  * *Pacing: Higher density frontline.*
* **Wave 4 (13 Enemies - Climax)**: 6 Swarmers + 5 Grunts + 1 Brute + **1 Elite**
  * *Pacing: Big horde with a glowing captain.*

---

### Act 2: The Core / Forges (Total Enemies: 52)
*Stats Scaled: 1.4x HP, 1.3x Damage*  
*Target Player Level: Level 2 ➔ Level 4*

* **Wave 1 (12 Enemies)**: 7 Swarmers + 5 Grunts
* **Wave 2 (13 Enemies)**: 6 Swarmers + 5 Grunts + 2 Brutes
* **Wave 3 (13 Enemies)**: 5 Swarmers + 6 Grunts + 1 Brute + 1 Elite
* **Wave 4 (14 Enemies - Climax)**: 6 Swarmers + 5 Grunts + 2 Brutes + **1 Elite**

---

### Act 3: Throne / Mountain Heart (Total Enemies: 27 + Boss)
*Stats Scaled: 2.0x HP, 1.6x Damage*  
*Target Player Level: Level 4 ➔ Level 6/7*

* **Wave 1 (13 Enemies)**: 6 Swarmers + 5 Grunts + 2 Brutes
* **Wave 2 (14 Enemies)**: 6 Swarmers + 5 Grunts + 2 Brutes + 1 Elite
* **Wave 3 (Boss Battle)**:
  * **Act Boss (e.g. Pyrelord Vashra / Gravemaw)**
  * *Boss Phase 1 (75% HP)*: Summons **10 Swarmers** across the arena.
  * *Boss Phase 2 (40% HP)*: Summons **6 Swarmers + 4 Grunts**.

---

## 4. Rebalanced XP Curve (Prevents Fast Leveling)

With 40–50+ enemies per act, the XP formula must be steep enough that gaining a level feels like a genuine achievement.

### Formula:
```lua
function Progression.XpToNext(level)
    return math.floor(100 * level ^ 1.65 + 0.5)
end
```

### Progression Pace Table:

| Level | XP Required to Next | Cumulative XP | Total Kills Needed | Expected Milestone in Run |
| :---: | :---: | :---: | :---: | :--- |
| **1 ➔ 2** | **100 XP** | 100 XP | ~25–30 mixed kills | **Act 1 Wave 3 or 4** |
| **2 ➔ 3** | **313 XP** | 413 XP | ~60 mixed kills | **Act 1 Boss / Early Act 2** |
| **3 ➔ 4** | **610 XP** | 1,023 XP | ~90 mixed kills | **Mid Act 2** |
| **4 ➔ 5** | **986 XP** | 2,009 XP | ~120 mixed kills | **Late Act 2 / Start Act 3** |
| **5 ➔ 6** | **1,436 XP** | 3,445 XP | ~160 mixed kills | **Mid Act 3** |
| **6 ➔ 7** | **1,957 XP** | 5,402 XP | ~200+ mixed kills | **Act 3 Boss Victory** |
| **7 ➔ 10** | **2,500 – 4,000 XP** | 12,000+ XP | Post-Game / Raids | Meta progression |

---

## 5. Player Starting Survival Tuning

With 10+ enemies chasing the player, survivability needs to match:

* **Player Base HP**: **100 HP**
* **Flask Healing**: **30% Max HP** (30 HP healed). 3 Charges. Refilled at Wells or Act completions.
* **Dash (Shift)**: **2.5s cooldown**, 0.25s duration. Gives 0.2s of invulnerability (i-frames) to escape tight mobs.
* **Rift Bolt (LMB)**: 8 Damage, 0.35s cooldown (effective for picking off lone swarmers).
* **Area Skills (Q / E)**: Cooldowns between 1.8s and 3.0s with damage between 16 and 30, allowing 1–2 casts to clear groups of 45 HP Swarmers.
