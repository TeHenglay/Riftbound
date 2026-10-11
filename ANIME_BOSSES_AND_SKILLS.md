# Riftbound – Anime Final Bosses & Dropped Skills Specification

This document details the Act 3 Final Boss encounters, hand-cast animations, and signature dropped skills for all 5 nations in *Riftbound*.

---

## 1. Design Rules & Guidelines

1. **Zero Weapons**: Every boss and dropped skill uses **100% pure bare-handed casting** (palm blasts, throws, finger guns, sky calls, martial arts punches, ground stomps). Strictly no swords, bows, or weapons.
2. **Strict Difficulty Separation (Hard Mode Exclusivity)**:
   * **Skill 2 is Hard Mode ONLY**: The second dropped skill (e.g., Naruto's `Multi-Shadow Clone Jutsu`, Sasuke's `Kirin`, Ace's `Entei`, Jinbe's `Ocean Current Geyser`, Toph's `Granite Armor`) **ONLY drops in Hard Mode**. It is 100% impossible to obtain in Normal mode.
   * **Normal Difficulty Drop Pool**: Normal clears drop **ONLY Skill 1** (Iconic Offensive Nuke).
   * **Hard Difficulty Drop Pool**: Hard clears drop **Skill 2** (Advanced Form / Summons / Utility).
   * **First Clear Guarantee**: 100% Guaranteed drop on your first clear of each respective difficulty tier.
   * **Repeat Clears**: Subsequent Normal clears have a **30% chance** to drop duplicate copies of Skill 1 (up to Level 5). Subsequent Hard clears have a **30% chance** to drop duplicate copies of Skill 2 (up to Level 5).
3. **3 Rune Sockets**: All dropped anime skills come equipped with **3 Rune Sockets**, fully compatible with Common, Rare, Epic, and Legendary runes.

---

## 2. Complete 5-Nation Anime Boss & 2-Tier Drop Lineup

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

---

## 3. Boss Full Combat Kits & 2-Tier Dropped Skills

To make each Act 3 final boss feel like a true epic encounter, **bosses do NOT have only 1 skill**. Each boss features a full **5-skill combat kit** (Long-Range Poke, Close-Range Melee, Crowd/Minions, Mobility, and Ultimate Phase 2) and drops distinct skills on Normal vs. Hard:

---

### 🌪️ 1. Wind Nation: Naruto Uzumaki
* **Boss Title**: Sage of the Hidden Leaf
* **Arena**: The Broken Cloud Summit, surrounded by howling vortex winds.
* **Boss HP (Normal)**: 2,800 HP | **Boss HP (Hard)**: 4,500 HP | **Speed**: 13 (Fast and agile)

#### 🥋 Naruto's Combat Kit (Normal vs. Hard Moveset):
1. **Long-Range Poke – Wind Shuriken Volley**: Throws 3 fast spinning chakra shurikens in a spread fan toward the player (deals 8 dmg each). Forces the player to keep moving.
2. **Close-Range Burst – Rasengan Slam**: When the player gets close (or after dashing in), charges a spinning blue chakra sphere in his palm (0.35s windup) and lunges forward, dealing **28 Burst Damage** and knocking the player back.
3. **Mobility – Body Flicker (Wind Dash)**: Dashes in a blur of wind to reposition or close the distance for a Rasengan.
4. **Phase 2 Finisher (Cast on Normal & Hard) – Wind Style: Rasenshuriken**:
   * Jumps into the air with 2 clones stabilizing a screaming, expanding wind disc in his hand.
   * Hurls the Rasenshuriken down, creating an **18-stud hurricane suction sphere** that drags the player in, dealing **18 multi-tick damage every 0.35s** for 3.5s and shredding defense by -20%!
5. ⚠️ **HARD MODE EXCLUSIVE ABILITY – Multi-Shadow Clone Jutsu (Kage Bunshin)** *(Cast ONLY in Hard Mode!)*:
   * **In Normal Mode, Naruto NEVER summons shadow clones.**
   * **In Hard Mode**, Naruto crosses his fingers (`Clones` hand sign) and summons **3 to 4 Shadow Clones** around the arena with a loud *POOF!* smoke cloud!
   * **Clone Stats**: Fragile health (**45 HP each**; die in 1–2 hits or 1 Fireball).
   * **Clone Behavior**: Clones run at the player, throw shurikens, and charge with mini Rasengans. Upon dying, they vanish in a puff of white smoke!

#### 🎁 Dropped Skills:
* 🟢 **Normal Mode Drop: `Wind Style: Rasenshuriken`** *(Drops on Normal & Hard)*
  * **Element**: Wind | **Kind**: `Projectile` ➔ `Zone` | **Cooldown**: 5.5s | **Sockets**: 3 Runes
  * **Mechanics**: Hurls a screaming chakra shuriken that expands on hit into an 18-stud hurricane suction sphere. Drags all nearby enemies into the center, dealing multi-tick damage (18 dmg/tick for 3.5s) and shredding enemy defense by -20%.
* 🔴 **Hard Mode Drop: `Multi-Shadow Clone Jutsu (Kage Bunshin)`** *(Boss casts ONLY in Hard Mode & drops ONLY in Hard Mode!)*
  * **Element**: Wind / Neutral Chakra | **Kind**: `Summon` / `Decoy Minions` | **Cooldown**: 12.0s | **Sockets**: 3 Runes
  * **Duration**: 15 seconds (or until destroyed).
  * **Mechanics**: Player forms the cross-finger hand sign with an authentic `*POOF!*` smoke cloud, spawning **2 Shadow Clones**.
    * **Fragile Health**: Clones have **45 HP** (die quickly to direct enemy attacks).
    * **Combat Behavior**: Clones inherit the player's basic attack: they aggressively throw chakra shurikens and charge enemies with mini Rasengans (dealing 40% of player's attack damage).
    * **Aggro Magnet**: Enemies and bosses will divide their attention and target the clones, giving the player critical breathing room!
    * **Rune Sockets**: Equipping runes modifies the clones (e.g. *Lingering* extends duration to 20s, *Chain Reaction* causes clones to explode into a 25-dmg smoke blast upon death, *Might* increases clone attack damage).

---

### ⚡ 2. Lightning Nation: Sasuke Uchiha
* **Boss Title**: The Avenger
* **Arena**: The Sky Throne, surrounded by dark thunderclouds and crackling coils.
* **Boss HP (Normal)**: 2,800 HP | **Boss HP (Hard)**: 4,500 HP | **Speed**: 13 (Teleports and flicker-steps)

#### 🥋 Sasuke's Combat Kit (Normal vs. Hard Moveset):
1. **Long-Range Poke – Lightning Senbon**: Snaps his fingers to fire 5 piercing electrical needles in rapid succession (10 dmg each, applies mini slow).
2. **Area Defense – Chidori Nagashi (Current)**: Discharges a 360° radial sheet of yellow-and-blue electricity across the arena floor (16 studs). Deals 20 damage and applies **Shock (+20% damage taken)**.
3. **Mobility – Lightning Flicker Step**: Instantly blinks across the arena with a crackle of yellow-and-blue sparks.
4. **Phase 2 Finisher (Cast on Normal & Hard) – Chidori Palm Thrust / Surge**:
   * Charges screaming yellow-and-blue electricity in his palm (screaming 1,000 birds audio) and lunges **28 studs forward**, dealing **32 Heavy Damage**.
5. ⚠️ **HARD MODE EXCLUSIVE ABILITY – Kirin: Thunder Dragon** *(Cast ONLY in Hard Mode!)*:
   * **In Normal Mode, Sasuke NEVER casts Kirin.**
   * **In Hard Mode**, when dropping below 50% HP, Sasuke thrusts his hand to the dark storm clouds. A colossal electrical dragon roars down from above after a 0.7s telegraph, blasting the arena for **50 Massive Damage** and screen-shaking knockback!

#### 🎁 Dropped Skills:
* 🟢 **Normal Mode Drop: `Chidori: Lightning Surge`** *(Drops on Normal & Hard)*
  * **Element**: Lightning | **Kind**: `Line` / `Dash-Strike` | **Cooldown**: 4.5s | **Sockets**: 3 Runes
  * **Mechanics**: Lunges 32 studs forward with yellow-and-blue Chidori, piercing enemies for 90 damage and emitting a 14-stud radial Chidori Current with **Shock (+20% damage taken)**.
* 🔴 **Hard Mode Drop: `Kirin: Thunder Dragon`** *(Boss casts ONLY in Hard Mode & drops ONLY in Hard Mode!)*
  * **Element**: Lightning | **Kind**: `Cataclysm` / `Sky Strike` | **Cooldown**: 11.0s | **Sockets**: 3 Runes
  * **Mechanics**: Player thrusts their arm toward the sky; thunderclouds gather instantly above the target reticle (0.6s telegraph). A colossal mythical electrical dragon descends at lightning speed, detonating an 18-stud area for **160 Massive Lightning Damage**, launching targets into the air and applying **Shock** for 6s.

---

### 🔥 3. Fire Nation: Portgas D. Ace
* **Boss Title**: Fire Fist Ace
* **Arena**: Caldera Throne, floating stone platform inside an active volcano.
* **Boss HP (Normal)**: 2,800 HP | **Boss HP (Hard)**: 4,500 HP | **Speed**: 11.5

#### 🥋 Ace's Combat Kit (Normal vs. Hard Moveset):
1. **Long-Range Poke – Fire Gun (Higan)**: Points his fingers like pistols, firing rapid-fire burning bullets across the arena (deals 7 dmg each with Burn).
2. **Area Hazard – Fireflies (Hidaruma)**: Spawns 5 glowing green-yellow fireflies that hover in the air, then lock onto the player and detonate on touch.
3. **Mobility – Blaze Step**: Dashes through the air in a spiral of fire, leaving burning embers behind.
4. **Phase 2 Finisher (Cast on Normal & Hard) – Fire Fist (Hiken)**:
   * Transforms his entire arm into an enormous rushing column of fire, blasting forward 30 studs for **30 Fire Damage**.
5. ⚠️ **HARD MODE EXCLUSIVE ABILITY – Great Flame Emperor (Dai Enkai: Entei)** *(Cast ONLY in Hard Mode!)*:
   * **In Normal Mode, Ace NEVER casts Entei.**
   * **In Hard Mode**, gathers flames from across the caldera into a **giant miniature sun** above his head, crashing it into the arena center for a **25-stud cataclysmic explosion** dealing 45 damage and leaving molten lava for 4s.

#### 🎁 Dropped Skills:
* 🟢 **Normal Mode Drop: `Fire Fist: Rushing Inferno (Hiken)`** *(Drops on Normal & Hard)*
  * **Element**: Fire | **Kind**: `Line` / `Flamethrower Column` | **Cooldown**: 4.5s | **Sockets**: 3 Runes
  * **Mechanics**: Transforms the player's arm into an immense roaring torrent of flame blasting 32 studs forward, dealing 95 heavy fire damage, knocking enemies backwards, and inflicting **Burn** (8 dmg/sec for 4s).
* 🔴 **Hard Mode Drop: `Great Flame Emperor: Sun Cataclysm (Entei)`** *(Boss casts ONLY in Hard Mode & drops ONLY in Hard Mode!)*
  * **Element**: Fire | **Kind**: `Meteor` / `Cataclysm` | **Cooldown**: 12.0s | **Sockets**: 3 Runes
  * **Mechanics**: Player raises both hands, manifesting a colossal miniature sun orb overhead, and hurls it down. Detonates in a **24-stud cataclysmic firestorm** dealing 150 burst damage and turning the impact zone into a molten sea of fire for 5s (deals 15 fire dmg/sec to anyone standing inside).

---

### 🌊 4. Water Nation: Jinbe
* **Boss Title**: Knight of the Sea
* **Arena**: The Abyssal Throne, submerged sunken temple with rising water currents.
* **Boss HP (Normal)**: 3,100 HP | **Boss HP (Hard)**: 4,800 HP | **Speed**: 10 (Tanky martial-arts master)

#### 🥋 Jinbe's Combat Kit (Normal vs. Hard Moveset):
1. **Long-Range Poke – Water Shot (Uchimizu)**: Flicks water droplets from his bare fingers with supersonic speed, firing 3 heavy water bullets across the room (12 dmg each, applies **Soaked**).
2. **Close-Range Burst – Arabesque Tile Claymore Punch**: Low-stance palm punch that shoots a concussive shockwave through the air, dealing **30 Water Damage** and heavy knockback.
3. **Defense – Fish-Man Guard**: Enters an iron-guard stance for 1.5s, reducing all incoming front damage by 80% and reflecting basic projectiles.
4. **Phase 2 Finisher (Cast on Normal & Hard) – Vagabond Drill (Buraikan)**:
   * Charges water moisture into his bare fist, unleashing a screen-wide pressurized water drill that punches across the entire room for **40 Damage** and drenching the arena in **Soaked**.
5. ⚠️ **HARD MODE EXCLUSIVE ABILITY – Ocean Current Geyser (Kairyū Ipponzeoi)** *(Cast ONLY in Hard Mode!)*:
   * **In Normal Mode, Jinbe NEVER casts Ocean Current Geysers.**
   * **In Hard Mode**, Jinbe slams the floor with both fists, causing 3 spiraling water geysers to erupt violently beneath the player, dealing 35 damage and launching them high into the air.

#### 🎁 Dropped Skills:
* 🟢 **Normal Mode Drop: `Fish-Man Karate: Vagabond Drill (Buraikan)`** *(Drops on Normal & Hard)*
  * **Element**: Water | **Kind**: `Line` / `Piercing Blast` | **Cooldown**: 4.0s | **Sockets**: 3 Runes
  * **Mechanics**: Low-stance bare-fist punch unleashing a 42-stud pressurized water drill shockwave. Pierces all enemies for 85 damage, heavy knockback, and applies **Soaked** (+25% lightning vulnerability, -15% move speed) for 5s.
* 🔴 **Hard Mode Drop: `Ocean Current Geyser (Kairyū Ipponzeoi)`** *(Boss casts ONLY in Hard Mode & drops ONLY in Hard Mode!)*
  * **Element**: Water | **Kind**: `Zone` / `Airborne Lockdown` | **Cooldown**: 9.5s | **Sockets**: 3 Runes
  * **Mechanics**: Player stomps both feet into the ground and heaves both arms upward, summoning 3 titanic spiraling water spouts that erupt in a 16-stud radius around the target area. Deals 110 damage, suspends enemies in mid-air for **1.5s (Airborne Stun)**, and drenches the area in water.

---

### 🪨 5. Earth Nation: Toph Beifong
* **Boss Title**: The Blind Bandit
* **Arena**: Heart of the Mountain, deep stone cavern with crystal stalactites.
* **Boss HP (Normal)**: 3,200 HP | **Boss HP (Hard)**: 5,000 HP | **Speed**: 9.5 (Heavy control & arena manipulation)

#### 🥋 Toph's Combat Kit (Normal vs. Hard Moveset):
1. **Long-Range Poke – Rock Boulder Kick**: Kicks heavy jagged stone boulders across the floor that roll and bounce off walls (14 dmg each).
2. **Area Control – Quicksand Pit**: Stomps the ground, turning a 14-stud patch of the arena floor into churning quicksand that slows the player by 50% and pulls them toward the center.
3. **Defense – Earth Wall Eruption**: Kicks the ground to erupt an impenetrable stone slab in front of her to block incoming spells.
4. **Phase 2 Finisher (Cast on Normal & Hard) – Bedrock Seismic Rupture**:
   * Jumps and stomps both feet down. Deep seismic cracks race across the room, erupting monolithic jagged rock spires beneath the player for 40 damage and a **1.5s Stun**.
5. ⚠️ **HARD MODE EXCLUSIVE ABILITY – Granite Armor & Earth Gauntlets** *(Cast ONLY in Hard Mode!)*:
   * **In Normal Mode, Toph NEVER uses Granite Armor.**
   * **In Hard Mode**, Toph encases her body and fists in dense rock armor: gains a **+1,200 HP Granite Shield**, becomes immune to knockback/staggers, and punches with seismic shockwaves for 8 seconds!

#### 🎁 Dropped Skills:
* 🟢 **Normal Mode Drop: `Bedrock Seismic Rupture`** *(Drops on Normal & Hard)*
  * **Element**: Earth | **Kind**: `Strike` / `Radial Nova` | **Cooldown**: 5.0s | **Sockets**: 3 Runes
  * **Mechanics**: Ground stomp and seismic shockwave raising monolithic stone spires in an 18-stud radius. Deals 80 damage and inflicts a **1.2s Stun** to all enemies caught within.
* 🔴 **Hard Mode Drop: `Granite Armor & Earth Gauntlets`** *(Boss casts ONLY in Hard Mode & drops ONLY in Hard Mode!)*
  * **Element**: Earth | **Kind**: `Self-Buff` / `Brawler Form` | **Cooldown**: 14.0s | **Sockets**: 3 Runes
  * **Duration**: 8 seconds.
  * **Mechanics**: Player stomps both feet and encases their torso and forearms in dense granite plates:
    * **Granite Shield**: Grants an immediate barrier equal to **25% of Player's Max HP**.
    * **Unstoppable**: Complete immunity to enemy knockback, staggers, and slows for the duration.
    * **Seismic Punches**: Player's LMB basic attacks transform into heavy shockwave punches that deal **+60% bonus damage** and create 8-stud mini ground ruptures on every hit!

---

## 4. Complete 2-Tier Drops Summary Table

| Nation | Anime Boss | Series | 🟢 Normal Mode Drop (Offense Nuke) | 🔴 Hard Mode Drop (Advanced / Form) | Sockets |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **🌪️ Wind** | **Naruto Uzumaki** | *Naruto* | **Wind Style: Rasenshuriken** *(Vortex & Shred)* | **Multi-Shadow Clone Jutsu** *(2 Clones, 45 HP)* | 3 |
| **⚡ Lightning** | **Sasuke Uchiha** | *Naruto* | **Chidori: Lightning Surge** *(Piercing Thrust)* | **Kirin: Thunder Dragon** *(160 Cataclysm Dragon)* | 3 |
| **🔥 Fire** | **Portgas D. Ace** | *One Piece* | **Fire Fist: Rushing Inferno** *(32-stud Fire Wave)* | **Great Flame Emperor: Entei** *(Mini Sun Bomb)* | 3 |
| **🌊 Water** | **Jinbe** | *One Piece* | **Fish-Man Karate: Vagabond Drill** *(Punch)* | **Ocean Current Geyser** *(1.5s Airborne Spouts)* | 3 |
| **🪨 Earth** | **Toph Beifong** | *Avatar: TLA* | **Bedrock Seismic Rupture** *(Stun Spires)* | **Granite Armor & Earth Gauntlets** *(Shield/Brawler)* | 3 |

---

## 5. Cross-Elemental Forge Syntheses

When players defeat bosses on Normal and Hard, they can combine signature drops at the Forge with materials to create pinnacle mythic fusions:

1. **🌪️⚡ Naruto + Sasuke Fusion (Wind + Lightning)**:
   * **Recipe**: `Rasenshuriken` + `Chidori` + 10x Wind Shards + 10x Lightning Shards + 1x Wind Essence + 1x Lightning Essence + 3,500 Gold.
   * **Result**: **Rikudō: Storm Vortex (Supercharged Tempest)**
     * Throws an electrified hurricane vortex that pulls enemies in, continuously electrocuting them with yellow-and-blue chain lightning while shredding defense by -25%!
2. **🌪️🔥 Naruto + Ace Fusion (Wind + Fire)**:
   * **Recipe**: `Multi-Shadow Clone Jutsu` + `Fire Fist` + 10x Wind Shards + 10x Fire Shards + 1x Wind Essence + 1x Fire Essence + 3,500 Gold.
   * **Result**: **Blazing Clone Swarm (Flame Bunshin)**
     * Summons 2 flaming shadow clones with 60 HP that shoot fire bullets, and upon death or expiry, detonate in a **35-damage Fire Fist explosion**!
3. **🌊⚡ Jinbe + Sasuke Fusion (Water + Lightning)**:
   * **Recipe**: `Ocean Current Geyser` + `Kirin: Thunder Dragon` + 10x Water Shards + 10x Lightning Shards + 1x Water Essence + 1x Lightning Essence + 3,500 Gold.
   * **Result**: **Electrified Abyssal Maelstrom**
     * Summons a colossal vortex of water charged with roaring Kirin lightning bolts, keeping all enemies airborne while applying continuous high-voltage Shock!

