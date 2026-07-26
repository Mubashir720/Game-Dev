# FOREST THRONES

## Game Design & Software Requirements Document

**Version 2.0 · Complete Blueprint — All Loopholes Addressed**

Genre: Multiplayer Squad Survival · Platform: Mobile (iOS & Android) · Visual Style: 2.5D Isometric RPG Cartoon

> *"PUBG meets Among Us in a haunted forest — where your squadmate might kidnap you, steal your coins, and sell you to your enemies."*

---

## Table of Contents

1. Game Overview
2. Core Game Loop
3. The Map
4. Roles & Archetypes
5. Resources
6. Buildings
7. Coins & Economy
8. Survival Stats
9. Combat
10. Capture, Prison & Ransom
11. The 7 Addiction Systems
12. Match Timeline (25 min)
13. System Linkage — How Everything Connects
14. Game Modes
15. Progression & Rewards
16. Monetisation
17. Technical Architecture
18. Development Phases
19. MVP Scope
20. Risks & Mitigations

---

## 1 — GAME OVERVIEW

Forest Thrones is a 2.5D isometric multiplayer survival game built for mobile. Thirty-two players drop into a living, cursed forest — deep layered environments, dynamic lighting, and expressive RPG cartoon characters that bring every moment to life. Players form squads of four, gather resources, build bases, generate coins, fight and capture enemies, and work to be the last squad standing. What makes it unique is a combination of three mechanics that no other game combines: a secret Traitor inside every squad with a full suspicion-to-betrayal lifecycle, a public Ransom Board that broadcasts every capture to all players, and an auto-clip system that records and shares every dramatic moment automatically.

| Property | Value |
|----------|-------|
| Genre | Squad Survival + Social Deduction + Base Building |
| Players per match | 32 players = 8 squads of 4 |
| Match length | 25 minutes |
| Engine | 2.5D Isometric — fixed-angle perspective with full depth layering, parallax environments, and dynamic lighting across foreground, midground, and background planes |
| Performance target | Stable 60 fps on mid-range devices (2021 and newer). Dynamic quality scaling preserves experience on lower-end hardware. |
| Platform (launch) | iOS and Android — mobile-first, built and optimised for touchscreen |
| Win condition | Last squad with alive members. If timer ends: highest coin total wins. Lone Wolf Traitors can win individually via highest personal coin count. |
| Session feel | Short enough for a break. Long enough to feel epic. |

### Why This Game Goes Viral

| Driver | How It Works |
|--------|-------------|
| Secret Traitor Token | Exactly 6 Traitor Tokens are randomly distributed across the 8 squads per match (6 squads get 1 traitor; 2 squads are 100% traitor-free). Nobody knows which squads are safe! Suspicion builds for 8 minutes before activation. Counter-play tools let honest players fight back. The reveal moment is auto-clipped every time. |
| Public Ransom Board | Every capture is broadcast live to all 32 players for 90 seconds. Everyone watches. Anyone can outbid. It creates a live story. |
| Auto-Clip Engine | The game detects dramatic moments, saves a 15-second clip automatically, and lets players share it in one tap — with a download QR code embedded. |
| Forest Curse | When one squad dominates, the forest punishes them visibly. All beasts hunt them. This creates natural comebacks and villain moments. |
| Beast Companions | Players tame and name animals. When a wolf dies protecting its owner, the game clips it. Emotional content spreads. |
| Traitor Team-Up | Up to 3 activated Traitors from different squads can form a Rogue Squad — no respawns, but buffed. Insane content when it happens. |

---

## 2 — CORE GAME LOOP

This is what every player does every match. Every other section of this document describes one part of this loop in detail.

**1 · LAND**
Drop into your squad zone with a Basic weapon based on character type. No gear, no base, no coins. Server secretly assigns 6 Traitor Tokens across 6 random squads (2 squads are completely traitor-free). Suspicion phase begins — nobody knows if their squad has a traitor or is clean!

▼

**2 · GATHER**
Chop trees (Wood) · Mine rocks (Stone) · Hunt/forage (Food) · Collect at river (Water). These 4 materials are used to build everything.

▼

**3 · BUILD YOUR BASE**
Place structures on a grid. Hut (respawn point + proximity aura) → Walls (defense) → Cage (prison for enemies) → Workshop (craft weapons + traps) → Well (water source) → Mint (double coins).

▼

**4 · QUEEN GENERATES COINS**
While the Queen is alive at base: 1 coin every 20 seconds into the squad treasury. Automatic. No button. Protect her — if she is captured, income drops to emergency rate.

▼

**5 · FIGHT, CAPTURE & RANSOM**
Attack enemies. Knock them to 0 HP. Handcuff (2s). Carry to Cage. Imprison. Set ransom — it broadcasts publicly to all 32 players for 90 seconds. Or chain them for Forced Labor near your cage.

▼

**6 · SUSPICION & BETRAYAL**
During minutes 0–8, watch for suspicious teammates (Trust Color System, Buddy Links). After minute 8, the Traitor Token holder can activate Rogue State: attack squadmates, steal the treasury, sell the Queen to enemies, or defect. Honest players can Vote to Exile, lock the treasury, or kill the traitor via friendly fire once confirmed.

▼

**7 · ZONE SHRINKS (MINUTE 17)**
Dark border closes in from map edges. Players take 2 HP/s inside it. Squads pick up their Hut (moveable, carrier visible on all minimaps) and migrate toward center.

▼

**8 · FINAL FIGHT & WIN**
All squads converge at center. Last squad alive wins. Or highest coins if timer runs out. Lone Wolf Traitors can win individually. Post-match reveals who the Traitor was.

---

## 3 — THE MAP

### Map Specifications

| Property | Detail |
|----------|--------|
| Size | 200 × 200 isometric grid cells. Each cell is a diamond-shaped isometric tile rendered with full depth — elevated terrain, ground-level objects, and overhead canopy layers stack independently. |
| Drop zones | 8 drop zones at map edges — one per squad, equidistant |
| Center landmark | The Cursed Throne — hold uncontested for 60 seconds = 50 coin bonus. Squad holding it becomes visible on ALL minimaps. |
| Center danger (first 10 min) | 3–4 wild beasts patrol the center area for the first 10 minutes. Building there early = constant beast attacks. After minute 10, beasts disperse. |
| Center resources | The center has NO trees and NO stone outcrops. Only grass and the Throne. Building at center requires hauling all resources from outer zones. |
| NPC Vendor | 2 fixed locations, mid-map. Neutral zone within 3 tiles. |
| Black Market | Spawns at random location every 8 min. 60-second warning indicator on minimap before spawn. Lasts 3 min. 5-tile neutral zone. |
| Shipment Crate | Drops every 10 min at random visible location. Contested. |
| Zone shrink start | Minute 17. Rate: 1 tile inward per 30 seconds. 2 HP/s damage inside. |

### Map Zones

| Zone | Location | Purpose & What It Creates |
|------|----------|--------------------------|
| Drop Zones ×8 | Map edges | Equal starting positions. Each squad isolated at landing. |
| Dense Forest | Center-north, center-south | Rich wood. Low visibility. Ambush territory. Beasts patrol at night. |
| Open Clearing | 4 mid-map clearings | Resource hotspots that pull squads together. First fights happen here. |
| Riverbed | East and west edges | Primary Water source. During Heatwave: most contested area on map. |
| Rocky Highlands | North-west, south-east | Rich stone + rare metal ore veins. Elevated — Watchtowers see further. |
| Swamp | North-east | Richest herb zone. Movement −20%. High risk, high reward. |
| Cursed Throne | Dead center | Late-game objective. Forces convergence. Worth 50 coins. Beast-patrolled early game. No natural resources. |

### Zone Shrink Design Note — Why Buildings Still Make Sense

The zone does NOT shrink constantly like PUBG. The full map is open for the first 17 minutes.

Buildings are useful for 68% of the match — they generate coins, hold prisoners, provide proximity aura healing, and protect the squad.

Huts are moveable: pick one up at any time, lose 30% stored resources, place it elsewhere. Carrier is visible on all minimaps (creates escort missions). Early building is never wasted.

When the zone shrinks at minute 17 it moves slowly (1 tile per 30s), giving squads time to migrate deliberately.

**Late Arrival Bonus**: Squads that migrate INTO the center zone after minute 17 get a 30-second "Adrenaline" buff: +10% speed, +10% damage. Squads already in center when shrink starts get nothing. Rewards the dramatic migration.

---

## 4 — ROLES & ARCHETYPES

Every squad has exactly 4 players. Each player fills one role. Roles are not interchangeable — each one provides something the others cannot. Losing a role creates a specific weakness enemies can exploit.

| Role | What They Do | Effect if Captured | Archetypes (pick 1) |
|------|-------------|-------------------|---------------------|
| King | Strongest fighter. Highest HP. Squad anchor. | Main combat power gone. 30s respawn (vs 15s others). | Warlord / Regent / Beastlord |
| Queen | Passive coin income. Crafting speed +30%. | Coin income drops to emergency rate (75% reduction, not total stop). | Engineer / Witch / Herbalist |
| Soldier A | Frontline tank. Shields while others gather. | Squad exposed during all resource runs. | Guardian / Berserker / Sapper |
| Soldier B | Scout, speed, ranged support, fast building. | No early warning of incoming raids. | Scout / Archer / Builder |

### Archetypes — Active and Passive Abilities

| Archetype | Active Ability | Passive Ability |
|-----------|---------------|-----------------|
| Warlord (King) | Rally Cry: squad within 10 tiles get +20% speed + damage for 8s. (45s CD) | War Banner: place a flag — +15% squad damage within 8 tiles. |
| Regent (King) | Tax Edict: all coin sources +50% for 20 seconds. (90s CD). Works at 50% effectiveness even without Queen — insurance pick. | Stockpile: carry 50% more of every resource type. |
| Beastlord (King) | Tame wild animals. Tamed beast stats +30%. | Pack Leader: while companion lives, King gets +15% move speed. |
| Engineer (Queen) | Overclock: all squad builds take 50% of normal time for 15s. (60s CD) | Trap Master: traps deal +40% damage. Build 2× faster. |
| Witch (Queen) | Hex: target gets −30% speed and −20% damage for 10s. (30s CD) | Curse Ward: once per match auto-removes a Forest Curse from squad. |
| Herbalist (Queen) | Brew: craft healing potion from 2 herbs instead of 3. Restores 35 HP. | Mend: squadmates within 5 tiles of base regen +2 HP/s. |
| Guardian (Soldier A) | Shield Wall: hold to block 60% incoming melee. Cannot attack while blocking. | Taunt: every 40s force nearest enemy to attack Guardian for 5s. |
| Berserker (Soldier A) | Frenzy: 6s of double attack speed, knockback-immune. (2 min CD) | Bloodlust: +5% damage per kill this match, stacks to +40%. |
| Sapper (Soldier A) | Demolish: destroy any structure in 3 seconds. (20s CD) | Trap Disarm: safely remove enemy bear traps without triggering. |
| Scout (Soldier B) | Flare: reveal all enemies within 20 tiles on minimap for 30s. | Stealth: invisible on enemy minimap when not attacking. |
| Archer (Soldier B) | Volley: fire 3 arrows simultaneously in a spread. (4s CD) | Eagle Eye: +50% ranged damage at 6+ tile range. (Activates with base Bow at 8 tiles and Advanced Bow at 12 tiles.) |
| Builder (Soldier B) | Rapid Build: all structures built 3× faster. Can build while moving. | Blueprint: copy any seen enemy structure, build for 50% resource cost. |

---

## 5 — RESOURCES

| Resource | How to Get It | Used For | Respawn |
|----------|--------------|----------|---------|
| Wood | Chop trees (everywhere) | Walls, Hut, Cage, Watchtower, Workshop, Fire Pit, Bear Trap, Well | 60 seconds |
| Stone | Mine outcrops (mid-map, highlands) | Stone Walls, Hut upgrade, Mint, Workshop, Well | 90 seconds |
| Food | Hunt beasts, forage bushes, fish | Eat raw: Hunger +20. Cook at Fire Pit: Hunger +40 + speed buff. Includes Mushrooms (Swamp only) — can also be used to tame Boar. | 45 seconds |
| Water | Collect at rivers, wells, and Well structures | Drink: Thirst +40. Can be stored in craftable Water Skins. | Constant (rivers). Well: 1 per 30s. |
| Metal (rare) | Ore veins, Mutation Wave kills, Shipment Crate | Cage, Mint, Bear Trap, advanced weapons, keys, Alarm Trap, Spike Trap | 120 seconds |
| Herbs (rare) | Swamp zone, shaded tiles, Black Market | Brew healing potions, tame Ravens, craft beast-calm item | 80 seconds |

---

## 6 — BUILDINGS

Buildings are placed on a grid. Each has a clear purpose. Nothing is decorative. The zone does not shrink until minute 17, so every structure built in the first 17 minutes provides full value.

| Building | Cost | Purpose | Linked To |
|----------|------|---------|-----------|
| Hut (basic) | 8 Wood | Respawn point — die here after 15s (King: 30s). Without this, death is permanent. Squad members within 8 tiles get +1 HP/s passive regen (Proximity Aura). 50 HP — can be destroyed by enemies. | Combat, Zone migration (moveable), Traitor sabotage |
| Hut (upgraded) | +6 Wood +3 Stone | Respawn in 8s. 100 HP. Adds a shared 20-slot storage chest (any mix of resource types, accessible by all squad members). Proximity Aura increases to +1.5 HP/s. When picked up and migrated, stored resources count toward the 30% resource loss. Required to build a Mint. | Economy, Speed, Defense |
| Wood Wall | 4 Wood | Physical barrier. 50 HP. Can be set on fire. Slows raiders. | Defense, Fire system |
| Stone Wall | 6 Stone | Physical barrier. 150 HP. Fireproof. Sapper destroys in 3s; others take 10 hits. | Defense — protects Mint and Cage |
| Basic Cage | 10 Wood | Holds 1 prisoner. Forced Labor (Chain Gang) only. Upgrade to full Cage by adding 4 Metal. | Early capture (minutes 3–8 before Metal is available) |
| Cage (full) | 8 Wood + 4 Metal | Holds up to 2 prisoners. Enables ransom, Chain Gang labor, interrogate, execute, sell to Black Market. Upgrades from Basic Cage (pay 4 Metal at existing structure). | Capture system, Coins, Ransom Board |
| Mint | 12 Wood + 8 Stone + 4 Metal | Doubles Queen coin rate: 1 coin per 10s instead of 20s. Requires upgraded Hut. | Economy — major raid target |
| Watchtower | 10 Wood + 4 Stone | Reveals enemy King positions within 15 tiles on minimap. Detects nearby Mints. Auto-pings "Base Under Threat" warning to all squad members when enemies enter within 8 tiles of any friendly structure. | Scouting, Raid planning, Base defense |
| Workshop | 10 Wood + 6 Stone | Craft: upgraded sword, bow, arrows, bear trap, spike trap, alarm trap, healing potion, keys, water skin. | Combat, Capture, Defense |
| Bear Trap | 4 Metal + 2 Wood (Workshop) | Hidden on ground. Triggered: 20 damage + 5s frozen. Invisible to enemies. | Base defense, Combat |
| Alarm Trap | 2 Wood + 1 Metal (Workshop) | Hidden on ground. When enemy steps on it: no damage, but ALL squad members get a notification + enemy position pings on minimap for 10 seconds. Early warning system. | Base defense, Raid counter |
| Spike Trap | 3 Wood + 2 Metal (Workshop) | Visible but impassable terrain. Forces raiders to go around walls, not through. Creates chokepoints. | Base defense, Choke points |
| Fire Pit | 4 Wood | Cook food (Hunger +40 + speed buff). Light source at night (vision +6 tiles). | Survival, Night phase |
| Well | 8 Stone + 4 Wood | Generates 1 Water every 30 seconds. Maximum 5 stored. Alternative to river trips. | Survival, Thirst management |

### Hut — Detailed Mechanics

The Hut is the emotional heart of your base. Losing it is devastating. Carrying it is heroic.

| Feature | Detail |
|---------|--------|
| Proximity Aura | Squad members within 8 tiles of their Hut get +1 HP/s passive regen (basic) or +1.5 HP/s (upgraded). |
| Respawn Anchor | No Hut = permanent death. This is the strongest mechanic in the game. |
| Moveable | Any squad member can pick up the Hut. Lose 30% stored resources on pickup. |
| Carry Penalty | Carrier moves at 50% speed, cannot attack, and is visible on ALL player minimaps as a beacon icon. Creates escort missions. |
| Destructible | Enemies CAN destroy the Hut (50 HP basic, 100 HP upgraded). If destroyed, squad has 90 seconds to rebuild or all future deaths are permanent. |
| Traitor Sabotage | The Traitor can damage the Hut by interacting with it (3-second interaction per sabotage). Each sabotage reduces Hut HP by 10–15 points. Can be done multiple times. Hut HP can be reduced to any amount — 40, 30, 12, 3, whatever the Traitor manages before being caught. Teammates who check the Hut can see its current HP bar. A Hut Guardian (any player staying within 3 tiles for 30 continuous seconds) gets notified of ANY interaction with the Hut, including sabotage. |
| Repair | Any squad member can repair the Hut: 2 Wood per 10 HP restored. 3-second repair interaction per 10 HP. |

### Recommended Build Order

**Minutes 0–3 · Emergency Base**
Hut → Wood Walls (×4–6 around Hut) → Fire Pit. Have a respawn point before first contact. Assign a Hut Guardian if paranoid about Traitor.

▼

**Minutes 3–7 · Economic Base**
Basic Cage (10 Wood — ready before Metal is available) → Watchtower (spot raids and base threats) → Well (water security). Upgrade to full Cage when Metal is found.

▼

**Minutes 7–12 · Power Base**
Workshop (craft weapons + traps + water skins) → Alarm Traps at perimeter → Mint (if metal available) → Bear Traps at entrances.

▼

**Minutes 12–17 · Hardened Base**
Stone Walls around Mint and Cage → Upgrade Hut → Spike Traps at chokepoints → Extra Bear Traps.

▼

**Minute 17+ · Migrate**
Pick up Hut (lose 30% stored resources, carrier visible on all minimaps). Move toward center. Stone walls remain to slow pursuers. Squad escorts Hut carrier.

---

## 7 — COINS & ECONOMY

### Where Coins Come From

| Source | How | Approximate Yield |
|--------|-----|-------------------|
| Queen passive mint | 1 coin every 20s while Queen is alive at base. Automatic. | ~45 coins over 15 active minutes |
| Emergency income (Queen captured) | Each remaining squad member generates 0.25 coins per 20s. | ~25% of normal rate — crippled but not dead |
| Mint structure | Doubles passive to 1 coin every 10s. | ~90 coins if Mint up by minute 8 |
| Ransom payments | Enemy squad pays to free their captured player. | 20–80 coins per ransom |
| Forced labor (Chain Gang) | Prisoner chained to cage gathers nearby resources. Sell at NPC vendor. | ~15–20 coins per 3-minute session |
| Shipment Crate | Drops every 10 min. Contains coins + rare item. | 20–40 coins per crate won |
| Cursed Throne | Hold center structure uncontested for 60 seconds. | 50 coins flat reward |

### What Coins Are Spent On

| Where | What You Buy | Why You Need It |
|-------|-------------|-----------------|
| NPC Vendor (always open) | Food 5c, Water 3c, Bandage 8c, Basic Sword 20c, Arrows×10 10c | Emergency resupply. Available when your base runs out. |
| NPC Vendor — Sell prices | Wood 1c, Stone 1c, Food 2c, Herbs 3c, Metal 5c (per unit) | Used by Forced Labor: prisoner collects and squad sells ≈ 15–20 coins |
| Black Market (8 min, 3 min window) | Metal 15c, Beast Bait 25c, Advanced Sword 45c, Rare Bow 40c. Prices scale: +20% for rich squads, −15% for poor squads. | Only source of advanced weapons during a match. |
| Ransom payment | Pay to free your own captured squad member. | Paying is cheaper than losing your Queen's income permanently. |
| Outbid ransom | Pay 50% of active ransom to steal a prisoner from captors. | Steal an enemy Queen and you gain a prisoner AND deny the captor coins. |
| Structure upgrades | Hut upgrade, Mint activation. | Investing coins builds infrastructure to earn more. |
| Win condition | If timer runs out, highest coin total in treasury wins. | Hoarding coins late-game is a valid strategy. |

### Treasury

The squad treasury is a physical chest placed at your base. 30 HP. Can be attacked and destroyed.

- Any squad member can deposit or withdraw coins at any time.
- If the chest is destroyed: 50% of coins scatter as individual coin pickups within a 3-tile radius. Any player auto-collects them on contact (no button press). Pickups despawn after 60 seconds if uncollected.
- Treasury total is hidden from enemies unless Interrogation mini-game succeeds.

**Treasury Defense Mechanics:**

| Defense | Detail |
|---------|--------|
| Treasury Lock | Squad vote (2 of 4 players agree) locks treasury for 3 minutes. Nobody — including the Traitor — can withdraw or steal during lock. Costs: squad also can't spend during lock. Can't pay ransoms while locked. |
| Treasury Alarm | When anyone withdraws more than 20 coins at once, ALL squad members get a loud sound alert + notification: "[Player Name] withdrew [X] coins." Traitor stealing triggers this immediately. |
| Split Treasury | Squad can vote (3 of 4 agree) to split the treasury into 4 personal shares. Each player controls their own coins. Traitor can only steal their own share. Downside: Ransom payments require 3 players to agree to pool funds. Slower, more bureaucratic, but traitor-proof. |
| Queen's Secret Stash | The Queen always has a hidden 10-coin personal reserve that cannot be stolen by the Traitor or lost in capture. Only usable for paying ransoms. Emergency money. |

### Queen Capture Recovery

| Mechanic | Detail |
|---------|--------|
| Emergency Income | When Queen is captured, each remaining squad member generates 0.25 coins per 20 seconds (75% reduction, not 100% elimination). Squad is crippled, not dead. |
| Rescue Bonus | If squad rescues their own Queen (break her out or pay ransom), the squad gets a "Reunited" buff: Queen generates coins at 1.5x rate for 60 seconds. Comeback mechanic. |
| Queen's Secret Stash | 10-coin hidden reserve. Cannot be stolen. Only for ransoms. |
| Regent Insurance | If King is Regent archetype, Tax Edict works at 50% effectiveness even without Queen. Strategic archetype pick for Queen-loss scenarios. |

---

## 8 — SURVIVAL STATS

| Stat | Decay Rate | Consequence at Zero |
|------|-----------|-------------------|
| HP (0–100) | No natural decay. Lost in combat, starvation, dehydration. | At 0: player enters Downed state. Bleeds 1 HP/3s. Capturable. |
| Hunger (0–100) | −1 per 8 seconds | HP drains at −1 per 3 seconds until food is eaten. |
| Thirst (0–100) | −1 per 8 seconds | HP drains at −1 per 2 seconds — worse than Hunger. Reaches 0 at ~13 minutes without water. |

**Design Note — Thirst Rebalance:** Thirst decay changed from −1/6s to −1/8s (matches Hunger rate). At zero, HP drain remains severe (−1/2s). This gives players ~13 minutes before thirst crisis — enough to require management without forcing constant river trips that dominate gameplay. The Well structure and craftable Water Skins provide alternatives to river dependency.

### Restoration Items

| Item | Restores | How to Get |
|------|----------|-----------|
| Raw Food | Hunger +20 | Forage bushes, hunt beasts |
| Cooked Meal (Fire Pit) | Hunger +40 + 30s speed buff | Cook Raw Food at Fire Pit — takes 8 seconds |
| Fresh Water (river/well) | Thirst +40 | Collect at river, well tiles, or Well structure |
| Water Skin (craftable) | Thirst +40 (stored, portable) | Workshop: 3 Wood + 1 Metal. Holds 2 charges. Fill at any water source. |
| Water Skin (vendor) | Thirst +60 (stored) | Buy at NPC vendor for 3 coins — single use |
| Bandage (vendor) | HP +25 | Buy at NPC vendor for 8 coins — 3 second apply time |
| Healing Potion (Workshop) | HP +50 | Craft at Workshop: 3 herbs — instant use |

---

## 9 — COMBAT

### Friendly Fire

Friendly fire is **ALWAYS ON** but deals **50% reduced damage** to teammates.

**Why Friendly Fire Exists:**
- Teammates can kill a confirmed Traitor once they're sure
- Accidental friendly fire creates paranoia moments ("Did they hit me on PURPOSE?!")
- Boar companion already has "can hit allies" — friendly fire is consistent with this
- Adds tension to every squad interaction — especially during the Suspicion Phase
- Prevents exploit where squads stack on top of each other with zero risk

**Friendly Fire Rules:**
- Damage to squadmates is 50% of normal weapon damage
- Friendly fire kills DO count toward Forest Curse triggers (3 kills in 60s)
- Killing an innocent squadmate via friendly fire gives the killer a visible "Teamkiller" icon for 60 seconds (visible to all players)
- Killing the actual Traitor via friendly fire gives no penalty — the squad gets a "Justice Served" notification and +10 coins
- If the squad kills the wrong person (an innocent), the actual Traitor sees a private notification: "They suspected someone else. You are safe."

### Weapons

| Weapon | Damage | Range / Notes | How to Get |
|--------|--------|--------------|-----------|
| Basic Sword | 15/hit | Melee. Block reduces incoming damage 60% while held. | Starting item or NPC vendor 20c |
| Upgraded Sword | 22/hit | Melee + knockback. | Workshop: 4 Metal |
| Bow | 8/arrow | 8 tile range. Requires arrows. | Workshop: 6 Wood + 2 Metal |
| Advanced Bow | 13/arrow | 12 tile range. Pierces 1 extra enemy. | Black Market: 40c |
| Charge Attack | 25 + knockback | Any weapon. Hold then release. 6s cooldown. | Built into every weapon |
| Bear Trap | 20 + 5s freeze | Ground placement. Hidden until triggered. | Workshop: 4 Metal + 2 Wood |

### HP States

| State | HP Range | Effect |
|-------|---------|--------|
| Healthy | 100–41 HP | Full speed. Full damage. No visible change to enemies. |
| Wounded | 40–11 HP | Speed −20%. Visible limp animation. Enemies see weakness. |
| Critical | 10–1 HP | Speed −40%. Screen pulses red. Enemies see clear distress. |
| Downed | 0 HP | Crawl only (20 px/s). Bleeds 1 HP/3s. Capturable by any player. Dies in 30s. |
| Dead | — | Respawn at squad Hut after 15s (King: 30s). No Hut: eliminated. Ghost Scout mode during respawn timer. |

### Ghost Scout (During Respawn Timer)

Dead players do not stare at a blank timer. During the respawn countdown:

| Feature | Detail |
|---------|--------|
| Ghost Mode | Dead player becomes a transparent ghost. They can fly around freely (fast, no collision, invisible to enemies). They CAN see enemy positions. |
| Team Pings | Ghost players can ping locations for their living teammates. Up to 3 pings per respawn cycle. |
| No Interaction | Ghosts cannot interact with anything — no attacking, no picking up items, no opening doors. Pure scouting. |
| Quick Respawn Task | During the timer, the dead player sees a mini-game (tap targets rapidly). Performance reduces respawn time by up to 3 seconds. Small but engaging. |

### Spectator System (Permanently Eliminated Players)

Players who are permanently eliminated (no Hut, no respawn) stay engaged:

| Feature | Detail |
|---------|--------|
| Free Spectate | Watch any living player from their perspective. Switch freely. |
| Community Bounty | All eliminated players vote together every 3 minutes to place a +10 coin bounty on one surviving player's head. Killing that player awards +10 bonus coins. Keeps eliminated players invested. |
| Post-Match Stats | Eliminated players still earn XP for actions performed while alive. |

---

## 10 — CAPTURE, PRISON & RANSOM

### Capture Flow

**Step 1 · Down the Enemy**
Reduce enemy HP to 0. They enter Downed state — crawling, bleeding, 30 seconds to die.

▼

**Step 2 · Handcuff (hold interact, 2 seconds)**
Walk up to downed player. Hold interact. You are now carrying them. Your speed drops to 60%. You cannot attack.

▼

**Step 3 · Carry to Your Cage**
Walk them to your base. You are slow and exposed. Your squad must protect you during this walk.

▼

**Step 4 · Imprison (press interact at Cage, 1 second)**
Prisoner is locked inside. Cannot attack or leave. Lock-pick mini-game available every 45 seconds.

▼

**Step 5 · Choose Your Option**
See the 5 options below. Each has different strategic value.

### The 5 Prison Options

| Option | How It Works | Best Used When |
|--------|-------------|---------------|
| Set Ransom | Choose a coin amount. Posted to ALL 32 players on the Ransom Board for 90 seconds. Any squad can outbid at 50% cost to steal the prisoner. Prisoner's squad can counter-offer (captor has 10s to accept/reject). | Captured the enemy Queen — ransom stops most of their income AND earns 30–80 coins. |
| Forced Labor (Chain Gang) | Prisoner is chained to the cage with a 5-tile leash radius. They physically move within this radius and auto-gather any resources in range at 25% of normal rate. Captor selects the resource type: wood, stone, food, or metal. Lasts max 3 minutes per session. If no resources of the selected type are within 5 tiles, prisoner generates 1 unit of the selected resource per 30 seconds (working the immediate area). Extended to 5 minutes total if prisoner's squad doesn't attempt rescue within 3 minutes. After 2 successful interrogations on same prisoner, gather rate increases to 40% (prisoner is "broken" and cooperative). | You are resource-poor and need specific materials. Low-value prisoner not worth a ransom. Cage is placed near resource nodes for maximum value. |
| Interrogate | 3-tier interrogation system. Each tier is a separate mini-game, progressively harder. **Tier 1 (Easy):** Three gauges, press interact in green zone, 8 seconds. Success: reveals prisoner's squad coin total. **Tier 2 (Medium):** Faster gauges, narrower green zones, 6 seconds. Success: reveals prisoner's squad Hut location. **Tier 3 (Hard):** Three gauges moving at different speeds simultaneously, 5 seconds. Success: reveals whether prisoner's squad has a Traitor and whether the Traitor has activated. Fail on any tier: 30-second cooldown before retry. **Prisoner can LIE once per interrogation** (player chooses). Captor can "press harder" if they suspect a lie — second attempt, but if THAT fails, cage door opens and prisoner escapes immediately. | Before planning a treasury raid — know the target's value, location, and internal trust situation. |
| Execute | Kills prisoner instantly. They lose their Hut respawn anchor and gear drops at the cage (captor gets the loot). **Triggers Forest Curse on executing squad. Curse duration stacks: 1st execution = 90s, 2nd = 120s, 3rd = 150s.** Executor gets a permanent "Blood Debt" icon visible to all players for rest of match. Killing a Blood Debt player awards +10 bonus coins. Executed player's squad gets "Vengeance" buff: +15% damage vs executing squad for 120 seconds. | Absolute last resort. You get their loot but become the most hated player in the match. |
| Sell to Black Market | Available on ransom expiry OR as a direct option with full Cage. Prisoner is sold for a flat 15 coins. Prisoner respawns at a random location on the map (not their base). No Forest Curse triggered. | On ransom expiry when you don't want to execute (avoid Curse) and don't want to release (avoid getting nothing). |

### Ransom Board — Complete Mechanics

| Feature | Detail |
|---------|--------|
| Broadcast | All ransoms shown on every player's HUD ticker simultaneously for 90 seconds. |
| Outbid | Any squad can steal a prisoner mid-ransom by paying 50% of the listed price. |
| Counter-Offer | Prisoner's squad can offer a counter-amount. Captors have 10 seconds to accept or reject. |
| Ransom Extension | Captor can pay 5 coins to extend the window by 60 more seconds (max 1 extension). |
| Partial Ransom | Prisoner's squad can offer 50% of ransom to convert to Forced Labor instead of full release. Captor gets some money, prisoner does Chain Gang labor for 2 minutes, then is released. |
| On Expiry (no payment) | Captor must choose: Execute (triggers Curse), Release (free), Sell to Black Market (15 coins, no Curse), or Community Service (release with Debtor's Mark — prisoner is visible on all minimaps and moves at −15% speed for 2 minutes). |

### Prisoner Escape Options

| Escape Method | How |
|--------------|-----|
| Lock-pick mini-game | Every 45s prisoner sees a 3-button prompt. Press correctly in 2 seconds = cage door opens. |
| Squad Key | Squadmate crafts a Key at Workshop (4 Metal). Bring to cage. Press interact. Instant release. |
| Thunderstorm | During active storm: 20% chance per minute of automatic cage latch failure. *(Post-MVP — Weather system not in MVP build.)* |
| Raven Scout | If squad has a tamed Raven, it can distract the guard — reduces guard vision radius for 10 seconds, giving time for key rescue. |
| Traitor Release | A Traitor in Rogue State can open their own squad's cage to release enemy prisoners. |
| Interrogation Failure | If captor "presses harder" on a suspected lie during interrogation and FAILS, the cage door opens automatically. |

### Chain Gang (Forced Labor) — Detailed Mechanics

The prisoner is physically chained to the cage with a visible chain/leash that restricts movement to a 5-tile radius around the cage.

| Feature | Detail |
|---------|--------|
| Movement | Prisoner can walk freely within 5 tiles of the cage. Cannot go further — chain pulls them back. |
| Resource Gathering | Prisoner auto-gathers any resource nodes within their 5-tile leash radius at 25% of normal gathering speed. |
| Resource Selection | Captor selects which resource type the prisoner focuses on. If multiple resource types exist in range, prisoner only gathers the selected type. |
| No Resources in Range | If no nodes of the selected type are within 5 tiles, prisoner generates 1 unit of the selected resource per 30 seconds (scavenging, working the ground, etc). |
| Duration | Default: 3 minutes. Extended to 5 minutes if prisoner's squad doesn't attempt rescue within the first 3 minutes. |
| Cage Placement Strategy | Smart captors place cages near resource-rich areas to maximize Forced Labor value. This makes cage placement a strategic decision — near trees for wood, near stone outcrops for stone, or near the swamp edge for herbs. |
| Escape During Labor | Prisoner can still attempt lock-pick every 45 seconds during labor. They remain chained, not caged — lock-pick is harder (narrower green zone) but still possible. |
| Squad Rescue During Labor | Prisoner's squadmates can attack the chain (15 HP) to free the prisoner without needing a key. But this alerts the captor's full squad via Alarm Trap integration. |
| Post-Interrogation Bonus | After 2 successful interrogations, gather rate increases to 40%. Prisoner is "broken" and works faster. |

---

## 11 — THE 7 ADDICTION SYSTEMS

These systems are what separate Forest Thrones from every other survival game. Each one generates a different type of memorable moment. Together they make every match feel like a story worth retelling.

---

### System 1 — The Traitor Token (Complete System)

The Traitor system has a full lifecycle: Suspicion → Activation → Action → Resolution. It is designed to be equally thrilling for the Traitor AND the honest players.

#### Phase 1: Assignment (Minute 0)

| Property | Detail |
|----------|--------|
| Assignment | Server secretly distributes 6 Traitor Tokens across 6 random squads at match start (2 squads receive ZERO traitors). Nobody knows which 2 squads are clean! This creates deep psychological paranoia: is a teammate acting suspicious because they are a traitor, or is the team turning on an innocent player in a safe squad? Token holder sees a private icon. Others see nothing. |
| Activation Lock | Traitor CANNOT activate Rogue State before Minute 8. Before minute 8, there's nothing worth stealing (low treasury, no Mint), and early betrayal kills the squad before the game starts — feels cheap, not dramatic. |

#### Phase 2: Suspicion Phase (Minutes 0–8)

During this phase, the Traitor cannot activate but CAN perform subtle sabotage actions. Honest players have counter-play tools to detect suspicious behavior.

**What the Traitor CAN Do Before Minute 8:**

| Subtle Action | What It Does | Risk of Detection |
|--------------|-------------|-------------------|
| Waste Resources | Intentionally build structures in bad positions, use extra materials | Low — teammates might not notice |
| Leak Position | Traitor's position is visible to ONE enemy squad (chosen at token reveal) — the squad they intend to defect to | None — invisible to teammates |
| Hoard Privately | Traitor can stash up to 15 resources in a personal hidden cache (not the team chest). These carry over after betrayal. | Low — teammates only notice if they track resource counts |
| Sabotage Hut | Interact with Hut for 3 seconds. Each sabotage reduces Hut HP by 10–15. Can be done multiple times to bring HP to any level. | Medium — Hut Guardian gets notified. Teammates might see the interaction. |
| Plant False Info | Traitor can ping "enemy spotted" at wrong locations to waste team time | Low — hard to verify |

**What Honest Players CAN Do During Suspicion Phase:**

| Counter-Play Action | Detail |
|-------------------|--------|
| Trust Color System | Each player has a hidden "Trust Score." It goes DOWN when: they wander alone for >60s, take resources but don't build/deposit, visit enemy territory, interact with the Hut suspiciously. Teammates see a subtle color dot next to each player's name: **green** (trustworthy) → **yellow** (some suspicious activity) → **orange** (very suspicious). **Never red** — the system never confirms the traitor. It only hints. |
| Buddy Link | Two players hold interact near each other for 3 seconds to link. Linked players see each other's exact resource inventory at all times. If one is the Traitor, they can't hoard privately without the buddy seeing it. Cost: both players share hunger/thirst drain (both bars deplete 20% faster). |
| Hut Guardian | Any player stays within 3 tiles of the Hut for 30 continuous seconds → becomes Hut Guardian. Gets a notification if ANYONE (including teammates) interacts with the Hut. Protects against sabotage. |
| Watch Resource Counts | The HUD shows each squad member's "gathered vs deposited" ratio as a subtle bar. A player who gathers a lot but deposits little is suspicious. |
| Treasury Lock | Squad vote (2 of 4) locks treasury for 3 minutes. Nobody can withdraw. Prevents theft, but also prevents spending. |

#### Phase 3: Activation (Minute 8+)

When the Traitor activates Rogue State:

1. **30-second disguise window** — teammates don't see the red Traitor icon yet
2. During these 30 seconds, the Traitor can:
   - Steal the full treasury (3-second interaction — triggers Treasury Alarm if >20 coins)
   - Sabotage the Hut further
   - Release prisoners from the squad's cage
   - Attack squadmates (they take damage but don't see who dealt it — "WHO HIT ME?!" moment)
   - Plant a **Spoiled Supply** — poisons the team's shared chest. Next teammate to take food from it gets −30 HP
3. After 30 seconds: Red icon appears above Traitor. Everyone knows. **Auto-clip triggers ("The Betrayal").**
4. **Post-Betrayal Rally:** When the red icon reveals, surviving honest squad members get a 60-second buff: +20% damage, +10% speed, −50% respawn time. "You messed with the wrong squad."

**Stolen Treasure Mechanics:**
- The Traitor physically carries stolen coins as a visible gold sack on their back
- Movement at 70% speed while carrying the sack
- If they die, the sack drops and anyone can pick it up
- The Traitor must DELIVER the stolen treasure to their new team's base to cash it in (Option B/C) or keep it as personal score (Option A)

#### Phase 4: The Traitor's Three Paths

After activating Rogue State, the Traitor chooses one of three paths:

**Option A — Lone Wolf**

| Feature | Detail |
|---------|--------|
| Status | Solo player. No squad. No allies. |
| Coins | Keep everything stolen as personal score. |
| Win Condition | Survive to end AND have the highest individual coin count among all surviving players. Lone Wolf can win even if a squad also "wins" — separate victory category. |
| Risk | Completely alone. Everyone wants to kill you. Very hard. Very cinematic. |

**Option B — Defect to an Enemy Squad**

| Feature | Detail |
|---------|--------|
| How | Approach any enemy squad's Hut. Hold interact for 5 seconds. Target squad gets popup: "A Traitor from [Squad Name] offers to join you. They bring [X coins]. Accept?" |
| If Accepted | Traitor joins as a 5th member. Deposits stolen coins into new squad's treasury. |
| The Catch | 15% hidden chance the defector receives a SECOND Traitor Token for their new squad. Nobody knows. Paranoia continues. The accepting squad gains power but also gains paranoia. |
| If Rejected | Traitor remains a Lone Wolf. The rejecting squad's position is briefly revealed on the Traitor's minimap for 15 seconds (they saw the Traitor and know where they are). |

**Option C — Traitor Team-Up (Max 3 Traitors)**

| Feature | Detail |
|---------|--------|
| Visibility | After activation, the Traitor's position is visible to OTHER activated Traitors on the minimap (and only to them). |
| Formation | If 2–3 activated Traitors find each other within 90 seconds of any of them activating, they can form a Rogue Squad. All traitors within 5 tiles hold interact simultaneously for 3 seconds → Rogue Squad formed. |
| Max Size & Multiple Squads | Max 3 traitors per Rogue Squad. With 6 total traitors in the match, up to TWO separate Rogue Squads of 3 traitors each can form simultaneously (e.g. Rogue Squad Alpha: 3 traitors, Rogue Squad Beta: 3 traitors). |
| Shared Resources | Rogue Squad pools all stolen treasuries. Shared minimap. See each other's positions. |
| No Respawn | Rogue Squad does NOT get a Hut. They cannot respawn. One life each. This is their balance penalty. |
| Rogue Buff | "Nothing Left to Lose" — +15% damage, +10% speed. They're desperate and dangerous. |
| Rogue Camp | Can build a Rogue Camp (12 Wood, 6 Stone): small fortification with NO respawn, but includes a basic cage. They can capture and ransom players. |
| Win Condition | Rogue Squad can win the match if they survive as the last "team" standing, same as any squad. |

#### Phase 5: Counter-Play on Confirmation

Once the Traitor's red icon is revealed (after 30-second disguise), honest players have immediate options:

| Action | Detail |
|--------|--------|
| Kill via Friendly Fire | Teammates can attack and kill the revealed Traitor. Friendly fire does 50% damage. Killing the confirmed Traitor awards +10 coins and no penalty. |
| Vote to Exile (also available pre-reveal) | After minute 8, squad can hold a 10-second vote (3 of 4 must agree) to exile one member. Correct exile: Traitor is expelled, loses all items, marked on map for 30 seconds (easy kill). Wrong exile: innocent player thrown out with no items, squad down to 3, real Traitor knows they're safe. |
| Chase and Recover | If Traitor stole treasury, they're visible (gold sack, 70% speed). Chase them down, kill them, recover the coins. Post-Betrayal Rally buff helps. |

#### Traitor Rewards

| Outcome | XP Reward | Title |
|---------|----------|-------|
| Activate Traitor Token | 200 XP | — |
| Steal treasury and survive 60s | 300 XP | Crown Thief |
| Defect and new squad wins | 400 XP | Turncoat |
| Form Rogue Squad | 250 XP | Rogue King |
| Rogue Squad wins the match | 500 XP | Lone Wolves |
| Betray TWICE (second token in new squad) | 500 XP | Double Agent |
| Never activate (play honest all match, squad wins) | 150 XP | Loyal Shadow |

---

### System 2 — Public Ransom Board

| Feature | Detail |
|---------|--------|
| Broadcast | All ransoms shown on every player's HUD ticker simultaneously for 90 seconds. |
| Outbid mechanic | Any squad can steal a prisoner mid-ransom by paying 50% of the listed price. |
| Negotiation window | Prisoner's squad can counter-offer. Captors have 10 seconds to accept or reject. |
| Ransom Extension | Captor pays 5 coins to extend window by 60 seconds (max 1 extension). |
| Partial Ransom | Prisoner's squad pays 50% to convert to Chain Gang labor (2 min) then release. |
| On expiry (4 options) | Execute (Curse + Blood Debt), Release (free), Sell to Black Market (15 coins, no Curse), or Community Service (release with Debtor's Mark: visible on minimaps, −15% speed for 2 minutes). |
| Why it works | 3-party tension — captor, prisoner's squad, outbidders — where all 32 players have a stake. |

---

### System 3 — Forest Curse

| Trigger | Curse Effect (duration varies) | Design Purpose |
|---------|-------------------------------|----------------|
| Kill 3 enemies in under 60 seconds | All beasts within 200 tiles aggro toward that squad. 90s duration. | Stops early snowballing. Creates natural comeback windows. |
| Execute an imprisoned player | Squad icons glow red — all 32 players see their exact minimap position. Duration stacks: 1st execution = 90s, 2nd = 120s, 3rd = 150s. Executor gets permanent Blood Debt icon. | Punishes cruelty. Makes executors into hunted villains. Serial killers get increasing punishment. |
| Burn another squad's entire base | Squad takes +20% damage from all sources. 90s duration. | Preserves base-building value. Deters pure destruction. |
| Hold Cursed Throne while also holding 2+ active ransoms | Extra Mutation Wave spawns and targets only this squad. 90s duration. | Punishes combined economic and territorial dominance. |
| Kill innocent teammate via friendly fire | Killer gets visible "Teamkiller" icon for 60 seconds. Not a squad-wide curse — individual punishment. | Prevents careless friendly fire. Makes Vote to Exile the safer option vs shooting first. |

---

### System 4 — Legendary Moments Engine

| Moment | Trigger |
|--------|---------|
| The Betrayal | Traitor Token activated (red icon revealed). |
| The Great Escape | Prisoner breaks out during active ransom countdown. |
| Last Stand | 1 player vs 3+ enemies — and survives. |
| Squad Wipe | One squad eliminates all 4 members of another in 45 seconds. |
| Beast Sacrifice | Companion intercepts a killing blow on behalf of its owner. |
| Crown Thief | Traitor steals treasury and survives 60 more seconds with it. |
| Beast Duel | Two companion Wolves from different squads fight 1v1. |
| Rogue Alliance | 2–3 Traitors form a Rogue Squad. |
| Justice Served | Squad correctly identifies and kills their Traitor. |
| Stockholm Flip | A forced labor prisoner defects to the captor's squad. |

On each trigger: 15-second clip auto-saved from rolling buffer. 3-second cinematic slow-motion cut. Clip named after the player. One-tap share with embedded download QR code.

---

### System 5 — Seasonal Lore

| Season | New Content |
|--------|-------------|
| Season 0 (Launch) | The Cursed Crowning — Wraith King lore. Ghost trail cosmetic for King. |
| Season 1 | Plague Winter — Plague Doctor archetype. Frozen Swamp zone. Ice Wolf beast. |
| Season 2 | Rise of the Stone Court — Stone Mason archetype. Fortress Tower structure. |
| Season 3 | The Merchant Guild — Player stalls. Smuggler archetype. Expanded Black Market. |

---

### System 6 — Treasury Heist Mode

| Feature | Detail |
|---------|--------|
| Format | 1 Vault Squad defends a 500-coin treasury at map center. 3 Raider squads attack. 12 minutes. No respawns. |
| Defenders earn | 50 coins per alive member per 60 seconds survived. |
| Raiders earn | 2 coins per second of direct contact with the vault chest. |
| Why it works | Unique mode no other game has. Perfect length for short-form content. Last-minute breach is always cinematic. |

---

### System 7 — Beast Companions

| Beast | How to Tame | Companion Ability |
|-------|-----------|-------------------|
| Wolf | Feed Raw Meat 3 times within 30 seconds. | Guards owner. Attacks anyone who hits them. Intercepts 1 killing blow per match. Can be set to Guard Mode (patrols 5-tile radius at base, attacks intruders). |
| Raven | Leave Metal near nest, wait 10 seconds. | Scout — player holds the Raven ability key; an aim direction line appears. Release to launch. Raven flies 30 tiles in the aimed direction, revealing all enemies within 5 tiles of its path on the minimap. Returns automatically after 10 seconds. 45-second cooldown. |
| Boar | Feed Mushrooms (found in swamp). | Chaotic charger — high damage, random targeting. Can hit allies (friendly fire consistency). |
| Stag | Stand within 5 tiles without attacking for 30 seconds. | Pack animal — carries 20 extra resources for the squad. |

#### Beast Lifecycle Mechanics

| Feature | Detail |
|---------|--------|
| Beast Hunger | Companions have a hunger bar (decays at −1 per 20 seconds). If hunger hits 0, beast goes wild — attacks randomly including the owner. Feed them regularly. Creates ongoing resource tension: feed yourself or your beast? |
| Beast Leveling | Companions gain XP from combat: 1 XP per hit landed, 10 XP per kill assisted. At 30 XP, beast evolves. Wolf → Dire Wolf (+20 HP, +5 damage). Raven → Storm Raven (8-tile reveal radius instead of 5). Boar → War Boar (double charge damage, slightly less random targeting). Stag → Great Stag (carries 35 extra resources). |
| Beast Mood | 3 moods based on treatment. **Happy** (well-fed, owner nearby): +10% stats. **Neutral** (default): normal stats. **Angry** (starving or owner left them alone >60s): 30% chance to disobey commands, may attack allies. |
| Naming | Players can name their companion (8 characters). Name shown above beast on-screen. |
| Death | Companion death triggers mourning animation. Corpse remains 60 seconds. Post-match badge shown. |
| Beast Sacrifice Clip | Auto-clips whenever a companion dies intercepting a killing blow. Most emotional content in the game. |
| Beast Duel | Two companion Wolves from different squads that meet in combat trigger a "Beast Duel" — 1v1 fight between the beasts while owners watch. Auto-clipped. Winning beast gets +10% stats for rest of match. |
| Guard Mode (Wolf) | Wolf can be set to Guard Mode: stays at base instead of following owner. Patrols 5-tile radius around the Hut. Attacks any enemy that enters the patrol zone. Owner gets a ping when the Wolf engages an intruder. |
| Traitor + Beast | If the Traitor has a tamed beast, the beast goes with the Traitor when Rogue State activates (beast does NOT attack the Traitor). If a squadmate has a Buddy Link with the Traitor and the beast is between them, the beast becomes confused and stops moving for 10 seconds (choosing loyalty). Dramatic moment. |

---

## 12 — MATCH TIMELINE — 25 MINUTES

| Time | Event | What Players Experience | Systems Active |
|------|-------|------------------------|----------------|
| Min 0:00 | Match starts | Everyone lands equally. Traitor Token assigned secretly. Suspicion Phase begins. | Traitor System (suspicion only) |
| Min 0–5 | Early gather phase | Gather resources, build starter base. NPC Vendor open. Trust Color dots begin updating. Buddy Links can be formed. | Resources, Buildings, Coins start, Trust System |
| Min 5–6 | First contact | Mid-map hotspots pull squads together. First fights. First captures. Friendly fire paranoia starts. | Combat, Capture, Ransom Board |
| Min 8:00 | Traitor Unlock + First Mutation Wave | Traitor activation unlocked. Mutated beasts attack all bases simultaneously. Vote to Exile becomes available. Center beasts begin dispersing. | Traitor (full), Beasts, Metal drops, Curse (if active) |
| Min 8–10 | Black Market spawns | 60-second warning on minimap. Pop-up shop at random location. 3 minutes only. 5-tile neutral zone. | Coins, Advanced weapons |
| Min 10:00 | Shipment Crate drops + Center opens | Crate falls — visible to all. Contested. Center beasts fully dispersed — Cursed Throne now contestable. | Coins, Rare item, Throne |
| Min 8–15 | Economy wars | Mints running. Queens captured. Ransom Board active. Traitor peak window. Chain Gang labor in progress. | All economy + Traitor + Ransom Board |
| Min 16:00 | Second Mutation Wave | Larger wave. Cursed squads get extra beasts. Beast companions may face wild rivals. | Beasts, Curse System |
| Min 17:00 | Zone shrinks | Dark border closes in. 1 tile per 30s. Hut migration begins. Carriers visible on all minimaps. Late Arrival Bonus for migrating squads. | Zone, Building migration, Escort missions |
| Min 18:00 | Second Black Market | Last rare item purchase opportunity. Price scaling active. | Coins, Weapons |
| Min 20:00 | Second Shipment Crate | Last Crate of match. High stakes. | Coins, Rare item |
| Min 20–25 | Final convergence | All squads near Cursed Throne. Zone tiny. Rogue Squads make final plays. | All systems — Moments Engine firing constantly |
| End | Win / post-match | Traitor revealed. Clips shown. XP awarded. Beast Duels resolved. Community Bounty results shown. | Resolution of all systems |

---

## 13 — SYSTEM LINKAGE — HOW EVERYTHING CONNECTS

No system in Forest Thrones works in isolation. Every action creates ripple effects in other systems. This is what makes the game feel alive and generates the stories players share.

### Chain 1 — Economic Warfare
Queen alive → Coins generate → Build Mint → Double income → Watchtower detects it → Raid incoming → Alarm Traps trigger → Squad defends or loses treasury

### Chain 2 — Betrayal Cascade
Suspicion builds (Trust Colors shift) → Traitor activates at minute 8+ → 30s disguised chaos → Steals treasury (alarm triggers) → Honest squad gets Rally buff → Chase begins → Traitor must deliver coins or go Lone Wolf

### Chain 3 — Traitor Team-Up Chain
6 Traitors across 8 squads (2 squads clean) → Traitors activate after Min 8 → Traitors see other activated Traitors on minimap → Up to 3 team up per Rogue Squad (allowing up to 2 Rogue Squads of 3 traitors each) → No respawns but buffed → Build Rogue Camp → Capture players → Win as outcasts

### Chain 4 — Counter-Betrayal Chain
Trust Colors turn orange on one player → Squad discusses → Buddy Link formed to confirm → Link reveals hoarding → Vote to Exile → Traitor expelled → Justice Served auto-clip → Squad continues as 3 with full treasury

### Chain 5 — Viral Content Chain
Big moment happens → Auto-clip saves 15s → Cinematic cut plays → Player shares + QR code → New player downloads

### Chain 6 — Survival Pressure
Thirst gets low (~13 min without water) → Well structure buys time → OR must go to river → Base left exposed (unless Guard Beast is set) → Alarm Traps give warning → Squad makes tactical choice

### Chain 7 — Beast Companion Emotion
Tame + name wolf → Feed to keep happy → Wolf guards owner → Wolf intercepts killing blow → Wolf dies saving owner → Emotional auto-clip → Mourning animation → Post-match badge

### Chain 8 — Capture Economy
Capture enemy → Imprison → Choose: Ransom (broadcast to 32), Chain Gang (resources near cage), Interrogate (intel tiers), Execute (loot + curse). Each choice cascades differently. Ransom expiry leads to: Sell to Market, Release, Execute, or Community Service.

### Chain 9 — Queen Capture Recovery
Queen captured → Emergency income activates (75% reduction) → Queen's Secret Stash available for ransom → Squad pays ransom or rescues → Reunited Buff fires → 1.5x coin generation for 60s → Comeback initiated

### Chain 10 — Hut Crisis
Traitor sabotages Hut to low HP → Enemy raid hits base → One stray arrow destroys Hut → Squad has 90 seconds to rebuild → No Hut = permanent death → Panic → Most tense moment in match → Auto-clip worthy

### Master Dependency Table

| System | Depends On | Enables |
|--------|-----------|---------|
| Traitor Token | Squad formation, treasury existence, minute 8 unlock | Betrayal clips, economic chaos, defection drama, paranoia, Rogue Squads, Trust Color tension |
| Trust System | Traitor Token existence, player behavior tracking | Counter-play, Buddy Links, Vote to Exile, detection drama |
| Ransom Board | Cage structure, captured prisoner, coins | 3-party drama, outbid mechanics, public narrative, partial ransoms |
| Forest Curse | Combat events, execution choices, friendly fire kills | Beast aggro, comeback windows, villain moments, stacking punishment |
| Moments Engine | All other game events | Clip sharing, viral spread, post-match highlights reel |
| Coins | Queen alive (or emergency income), Mint built, captures/crates | Weapons, ransoms, shop, win condition, treasury lock tension |
| Buildings | Resources gathered, metal found | Income (Mint), defense (Walls/Traps/Alarms), economy (Cage), water (Well), healing (Hut aura) |
| Beast Companions | Taming materials, beast hunger management | Scouting (Raven), combat (Wolf), Guard Mode, emotional content, Beast Duels |
| Friendly Fire | Always active, 50% damage | Traitor killing, paranoia, accidental drama, Teamkiller icon |
| Ghost Scout | Player death, respawn timer | Dead player engagement, team scouting, Quick Respawn task |

---

## 14 — GAME MODES

| Mode | Format | Rules |
|------|--------|-------|
| Battle Siege (Main) | 32 players / 8 squads of 4 | Full ruleset. All 7 systems active. Last squad or highest coins wins. Lone Wolf Traitor can win individually. 25 minutes. |
| Quick Skirmish | 16 players / 4 squads of 4 | Smaller map. 15 minutes. All systems active. Good for quick sessions. |
| Treasury Heist | 16 players / 1 vault + 3 raider squads | 12 minutes. No respawns. Vault squad defends. Raiders steal coins from chest. |
| Ranked Siege | 32 players / MMR-matched | Same as Battle Siege. Seasonal ladder. Top 100 global leaderboard. |
| Custom Match | 4–32 players / host-controlled | Toggle friendly fire damage %, mode, map size, starting resources, time of day, traitor activation timer. |
| Practice Island | Solo only | No enemies. Learn every mechanic. Tutorial integrated here. Traitor Token explained on first receipt. |

---

## 15 — PROGRESSION & REWARDS

### XP Sources

| Action | XP |
|--------|-----|
| Participate in any match | 100 XP |
| Squad wins the match | 300 XP |
| Last survivor of your squad | 150 XP |
| Successfully ransom an enemy | 80 XP |
| Escape from prison | 120 XP |
| Traitor Token activated | 200 XP |
| Crown Thief (steal treasury, survive 60s) | 300 XP |
| Rogue Squad formed | 250 XP |
| Double Agent (betray twice) | 500 XP |
| Loyal Shadow (have token, never activate, squad wins) | 150 XP |
| Justice Served (squad kills real traitor) | 100 XP |
| Each Legendary Moment triggered | 100 XP per moment |
| Daily quest completed (×3 per day) | 200 XP per quest |
| Community Bounty kill | 50 XP |

### Seasonal Battle Pass

- Price: $4.99 per season (8 weeks)
- Free track: XP boost ×1.1, 2 cosmetics per season, seasonal profile border
- Premium track: 30+ cosmetics: outfits, structure skins, weapon skins, animated effects, beast skins, unique titles
- Rule: All cosmetics are visual only. Zero gameplay advantage. Zero pay-to-win.

---

## 16 — MONETISATION

| Core Principle | Detail |
|---------------|--------|
| Zero pay-to-win | Players who pay look different — they do not play better. Free players access ALL gameplay content, ALL modes, ALL mechanics. This is non-negotiable. Pay-to-win kills viral games. |

| Revenue Stream | Details |
|---------------|---------|
| Mobile | Free to download on iOS and Android. Full core gameplay accessible at no cost. Revenue comes entirely from cosmetics and Battle Pass. |
| Battle Pass | $4.99/season. Free tier always available. Seasonal FOMO drives renewals. |
| Cosmetic Shop | Individual skins $0.99–$4.99. Character outfits, structures, weapons, beast skins. |
| Squad Bundle | $9.99 — themed set of 4 cosmetics for all squad roles. Giftable. |
| Creator Marketplace (post-MVP) | Community skin submissions. 70/30 revenue split. Verified creator program. |

---

## 17 — TECHNICAL ARCHITECTURE

| System | Detail |
|--------|--------|
| Rendering | 2.5D isometric renderer with support for layered depth sorting, per-tile height maps, dynamic point lighting, soft shadow casting, and full particle system support at 60fps on target mobile hardware. RPG cartoon visual style. |
| Map system | Isometric grid world with collision, multi-layer terrain (ground / object / canopy), dynamic navigation mesh for beast AI pathfinding, and procedural resource node placement within defined zone bounds. |
| Networking | Server-authoritative architecture. Dedicated match server per session, cloud-hosted with auto-scaling. Minimum 20 server ticks/second. Client-side prediction for movement with server reconciliation. Optimised for mobile network conditions — tolerant of packet loss and variable latency. |
| Server model | One dedicated match server per match. Cloud-hosted. Auto-scales with concurrent player count. Regional server routing to minimise latency for mobile users globally. |
| Trust System | Server-side behavior tracking. Trust Score calculated from: time alone, resource gather/deposit ratio, proximity to enemy territory, Hut interactions. Color dot (green/yellow/orange) sent to clients. Never reveals traitor directly. |
| Friendly Fire | Server validates all damage events including friendly fire (50% modifier). Traitor kill detection (correct vs innocent) handled server-side. |
| Chain Gang | Server tracks prisoner leash radius (5 tiles from cage). Resource gathering at reduced rate validated server-side. Chain HP tracked for squad rescue attempts. |
| Ghost Scout | Dead player entity transitions to spectator mode with movement freedom but no interaction capability. Ping limit (3 per cycle) enforced server-side. |
| Clip recording | Rolling 30-second frame buffer running on a background thread. On Legendary Moment trigger: last 15 seconds saved as a shareable video clip. One-tap share via native iOS/Android share sheet. Embedded QR code for cross-platform clip viewing. |
| Build targets | iOS (App Store) and Android (Google Play) — simultaneous launch. Optimised for touch input, mobile aspect ratios, and background/foreground lifecycle management. |
| Performance targets | 60 fps on mid-range 2021+ mobile devices. Dynamic quality levels (High / Medium / Low) auto-selected on first launch based on device benchmark. Battery usage mode available for extended sessions. |

### Core Scene Structure

| Module | Detail |
|--------|--------|
| World Module | Isometric map, navigation mesh, zone layers, resource node management, zone shrink overlay, event spawn points, day/night lighting cycle, center beast patrol system. |
| Player Module | Character entity with movement controller, stats (HP/Hunger/Thirst), inventory, role and archetype data, sprite animation state machine, touch input handler, Trust Score tracker. |
| Squad Module | Squad of 4 player entities (expandable to 5 on defection). Shared treasury chest object with lock/alarm/split mechanics. Traitor Token assignment. Buddy Link system. Vote to Exile system. Win condition evaluation. |
| Structure Module | Base class for all buildings. HP, construction progress, fire state, repair logic, upgrade paths, sabotage detection. Isometric depth sorting integrated. Includes new structures: Well, Alarm Trap, Spike Trap. |
| Beast Module | AI navigation agent. Behaviour states (idle patrol / aggro / tame / companion / guard mode). Taming mechanics. Companion bond data. Hunger system. Leveling/evolution. Mood system. Beast Duel logic. Death and mourning sequences. |
| Economy Module | Queen passive mint timer with emergency income fallback. Treasury sync across squad with lock/alarm/split states. Shop inventory management with price scaling. Ransom records with extension and partial payment support. Sell price calculations. |
| Prison Module | Cage state machine. Prisoner UI (5 options menu). Chain Gang leash radius system. Escape mini-game logic (including chain-break rescue). Ransom Board event emission with expiry options (execute/release/sell/community service). Interrogation tiers with lie/press-harder mechanic. |
| Traitor Module | 6 Traitors / 2 clean squads distribution logic. Suspicion phase behavior tracking. Activation lock (minute 8). Rogue State 30-second disguise timer. Defection system (Lone Wolf / Squad Defect / Rogue Team-Up max 3 per squad, up to 2 Rogue Squads). Stolen treasure sack physics. Second Token 15% chance on defection. |
| Curse Module | Game event monitor. Curse trigger evaluator with stacking duration. Blood Debt individual marker. Vengeance buff for victim squads. 90-second base timer with per-execution scaling. |
| Moments Module | Game event monitor. 30-second rolling video frame buffer. Moment detection (10 trigger types). Cinematic cut controller. Clip export and native mobile share integration. |
| Combat Module | Friendly fire system (50% damage modifier). Teamkiller/Justice Served detection. Charge attack cooldowns. HP state transitions with visual indicators. |
| Ghost Module | Dead player spectator entity. Free movement, ping system (3 per cycle), quick respawn mini-game, transition to full spectator on permanent elimination. Community Bounty voting for eliminated players. |
| HUD Module | All on-screen UI elements. Trust Color dots. Treasury alarm notifications. Chain Gang status. Ransom Board ticker. Beast hunger/mood indicators. Ghost Scout ping UI. Community Bounty vote UI. Event-driven — subscribes to signals from all game modules. Scales for mobile aspect ratios and safe areas. |

---

## 18 — DEVELOPMENT PHASES

Each phase is a self-contained deliverable with a clear test condition. Complete and validate each phase before proceeding to the next.

| Phase | Deliverable | Key Prompts |
|-------|------------|-------------|
| Phase 1 — Map & World | Playable isometric world with zone tiles, resource nodes, day/night lighting cycle, center beast patrol, and minimap. | 1.1 Isometric grid world (3 base terrain types, 200×200 grid) with correct depth sorting. 1.2 Resource nodes (tree/stone/bush — interactive, respawning, with harvest animations). Center has no trees/stone. 1.3 Dynamic day/night ambient lighting cycle (8-min day / 4-min night). 1.4 Drop zones + vendor NPC locations + Black Market spawn system with 60s warning. 1.5 Minimap with fog of war and zone boundary indicator. 1.6 Center beast patrol (3-4 beasts, despawn at minute 10). |
| Phase 2 — Characters & Trust | All 4 roles with stats, archetype selection, Traitor Token assignment, Trust Color system. | 2.1 Player character entity with 4-directional isometric movement and animation. 2.2 HP/Hunger/Thirst decay systems + HUD stat bars (thirst at −1/8s). 2.3 Role stat modifiers and archetype ability binding. 2.4 Archetype selection screen with ability preview. 2.5 Traitor Token server assignment + activation lock (minute 8). 2.6 Trust Color system (behavior tracking → green/yellow/orange dot). 2.7 Buddy Link system. 2.8 Ghost Scout mode for dead players. |
| Phase 3 — Buildings | Grid-based building, all structures including new ones, fire, hut migration with minimap visibility. | 3.1 Build mode + ghost preview + resource check. 3.2 All structure scenes (Hut, Walls, Cage, Watchtower, Workshop, Fire Pit, Well, Alarm Trap, Spike Trap, Bear Trap). 3.3 Build progress bar + Builder archetype speed. 3.4 Fire spread on wood structures. 3.5 Moveable Hut (pick up + relocate + carrier visible on all minimaps). 3.6 Hut Proximity Aura (+1 HP/s). 3.7 Hut destruction + 90-second rebuild timer. 3.8 Hut sabotage interaction (Traitor). 3.9 Hut Guardian notification system. 3.10 Hut repair system (2 Wood per 10 HP). 3.11 Watchtower auto-ping for nearby enemies. |
| Phase 4 — Combat & Capture | Melee/ranged combat, friendly fire, downed state, full capture-to-prison flow with Chain Gang. | 4.1 Sword combat + block + hitbox. 4.2 Bow + arrows + range limit. 4.3 HP state system + animations. 4.4 Friendly fire system (50% damage, Teamkiller/Justice Served detection). 4.5 Handcuff + carry + imprison flow. 4.6 5 prison options menu (Ransom, Chain Gang, Interrogate, Execute, Sell). 4.7 Chain Gang leash system (5-tile radius, resource gathering, chain HP). 4.8 Lock-pick escape mini-game. 4.9 Interrogation 3-tier system with lie mechanic. 4.10 Execution with stacking Curse + Blood Debt + Vengeance buff. 4.11 Quick Respawn mini-game for dead players. |
| Phase 5 — Economy | Coin system, ransom board with all expiry options, treasury defenses, NPC vendor, Black Market with price scaling. | 5.1 Queen mint timer + emergency income on capture. 5.2 Treasury chest (30 HP) + lock/alarm/split mechanics + scatter on destroy. 5.3 Queen's Secret Stash (10 coins). 5.4 Rescue Bonus (Reunited buff). 5.5 Ransom Board HUD + outbid + counter-offer + extension + partial ransom. 5.6 Ransom expiry options (execute/release/sell/community service). 5.7 NPC vendor shop UI. 5.8 Black Market spawn/despawn with 60s warning + neutral zone + price scaling. |
| Phase 6 — Living World | Beasts with full lifecycle, Mutation Waves, Forest Curse with stacking, zone shrink with Late Arrival Bonus. | 6.1 Wolf AI with patrol, aggro, attack, and Guard Mode. 6.2 Beast taming + naming + hunger system + mood system. 6.3 Beast leveling/evolution system. 6.4 Companion guard logic + killing-blow interception + death clip trigger. 6.5 Beast Duel system. 6.6 Mutation Wave server event + ground-crack arrival VFX. 6.7 Forest Curse trigger system with stacking duration + Blood Debt markers. 6.8 Zone shrink animated fog-wall with damage + Late Arrival Bonus. |
| Phase 7 — Traitor & Moments | Complete Traitor lifecycle, Rogue Squad formation, defection, all Legendary Moment types. | 7.1 Traitor suspicion phase actions (waste resources, leak position, hoard, sabotage, false pings). 7.2 Rogue State activation with 30s disguise + Spoiled Supply. 7.3 Post-Betrayal Rally buff for honest squad. 7.4 Lone Wolf path + individual win condition. 7.5 Defection to enemy squad + 15% second token chance. 7.6 Traitor Team-Up (max 3) + Rogue Squad formation + Rogue Camp. 7.7 Vote to Exile system (pre and post reveal). 7.8 Rolling 30s video frame buffer. 7.9 10 Legendary Moment detection signals. 7.10 Slow-motion cinematic cut + audio sting. 7.11 Post-match Highlights Reel + share/QR. |
| Phase 8 — Polish & Launch Prep | XP system, Battle Pass UI, matchmaking, leaderboard, tutorial, Community Bounty. | 8.1 XP award system + level-up animation (including all Traitor XP paths). 8.2 Battle Pass UI screen. 8.3 Matchmaking lobby + private room codes. 8.4 Leaderboard screen (global/friends/personal). 8.5 Practice Island tutorial (guided tour of all mechanics including Traitor, Chain Gang, Trust System). 8.6 Community Bounty system for eliminated players. 8.7 Spectator system for permanently eliminated players. |

---

## 19 — MVP SCOPE

The MVP must prove one thing: that the core loop is fun with real players, the Traitor Token creates genuine drama, and the counter-play tools make betrayal feel fair for everyone.

### MVP Must-Have (Phase 1–7 complete)

- 8–16 player online mobile match (2–4 squads). Server-authoritative. Playable on iOS and Android.
- All 4 roles + 1 archetype per role.
- Basic map: forest tiles, 4 drop zones, resource nodes, 1 NPC vendor. Center beast patrol for first 10 minutes. Center has no natural resources.
- Movement, melee combat, basic bow. Friendly fire (50% damage).
- Gather: wood, stone, food, water.
- Build: Hut (with Proximity Aura, destructible, sabotage-able, repairable, moveable with minimap visibility), Wood Wall, Basic Cage, Full Cage, Watchtower (with auto-ping), Fire Pit, Well, Workshop, Alarm Trap.
- Full capture / carry / imprison flow with 5 prison options.
- Chain Gang forced labor (5-tile leash, resource gathering, chain-break rescue).
- Interrogation 3-tier system with lie mechanic.
- Execution with stacking Curse + Blood Debt + Vengeance buff.
- Ransom Board with outbid, counter-offer, extension, partial ransom, and 4 expiry options.
- Complete Traitor Token system: 6 Traitors assigned across 8 squads (2 squads clean) + suspicion phase (minute 0–8) + activation + 3 paths (Lone Wolf, Defect, Team-Up max 3 per squad, up to 2 Rogue Squads).
- Trust Color system (green/yellow/orange).
- Buddy Link system.
- Vote to Exile.
- Treasury Lock + Alarm + Split options.
- Queen emergency income + Secret Stash + Rescue Bonus.
- Post-Betrayal Rally buff.
- Forest Curse System (all triggers, stacking duration, Blood Debt).
- Legendary Moments Engine (10 moment types + clip export).
- Day/night cycle.
- 1 beast type (Wolf — tameable, nameable, hunger, mood, Guard Mode, Beast Sacrifice clip).
- Ghost Scout mode for dead players + Quick Respawn mini-game.
- Post-match summary + XP + Traitor reveal.

### Post-MVP (Phase 8 and beyond)

- Battle Pass and full seasonal cosmetics.
- Treasury Heist mode.
- Full beast roster (Raven, Boar, Stag) with leveling/evolution.
- Beast Duel system.
- Weather system (Heatwave, Thunderstorm, Fog).
- Player stalls and Creator Marketplace.
- Ranked Siege with MMR matchmaking.
- Community Bounty system for eliminated players.
- Spike Trap.
- Stockholm Syndrome mechanic for extended forced labor.
- Second Traitor Token (15% on defection) — may ship with MVP if balanced in testing.

---

## 20 — RISKS & MITIGATIONS

| Risk | Severity | Mitigation |
|------|----------|-----------|
| New players confused by many systems | High | Practice Island tutorial mandatory before first public match. Context tooltips in first 3 matches. Traitor Token explained only on first receipt. Trust Color system is intuitive (green = good, orange = suspicious). |
| Traitor causes toxic squad behaviour | Medium | Traitor cannot activate before minute 8 — squads have time to bond. Counter-play tools (Trust Colors, Buddy Links, Vote to Exile, Treasury Lock, friendly fire) mean honest players can fight back. Traitor should succeed ~30–40% of activations. Post-Betrayal Rally buff empowers the betrayed squad. |
| Traitor Team-Up is too powerful | Medium | Max 3 Traitors (weaker than a full 4-player squad). No respawns — one life each. Must find each other within 90 seconds. Rogue Camp has no respawn point. The "Nothing Left to Lose" buff is strong but the no-respawn penalty is severe. |
| Friendly fire griefing | Medium | 50% damage reduction makes it slow to kill teammates. Teamkiller icon (visible to all for 60s) marks griefers. Killing an innocent triggers visible punishment. Correct Traitor kills are rewarded. Mute/report system. |
| Prisoner abuse exploits | High | Forced labor (Chain Gang) capped at 3–5 minutes. Escape mini-game every 45 seconds. Chain can be broken by rescue squad. Execution triggers stacking Forest Curse — heavy and increasing disincentive. Sell to Black Market provides a clean exit for captors. |
| Economy inflation / coin exploits | Medium | Server-side only economy. Per-match reset — no coin carry-over. Server validates every transaction. Black Market prices scale with squad wealth. Treasury Lock prevents exploit withdrawals. |
| Queen capture creates unrecoverable death spiral | High | Emergency income (25% rate) prevents total shutdown. Queen's Secret Stash provides ransom emergency funds. Rescue Bonus (1.5x coins for 60s) enables comeback. Regent archetype provides insurance. |
| River camping dominates strategy | High | Well structure provides base water source. Thirst decay slowed to −1/8s (13+ minutes to crisis). Craftable Water Skins provide portable water. Morning Dew event (post-MVP weather) adds passive thirst recovery. |
| Center camping dominates strategy | High | Center beast patrol for first 10 minutes prevents early occupation. No trees or stone at center forces resource hauling. Late Arrival Bonus rewards migration over camping. Cursed Throne makes holders visible targets. |
| No counter-play to base raids | Medium | Alarm Traps provide early warning. Watchtower auto-pings nearby enemies. Wolf Guard Mode provides autonomous defense. Spike Traps create chokepoints. |
| Black Market spawn unfairly favors nearby squads | Medium | 60-second warning on minimap before spawn. 5-tile neutral zone prevents camping. Price scaling penalizes rich squads and helps poor squads. |
| Dead players disengage | High | Ghost Scout mode during respawn timer. Quick Respawn mini-game. Community Bounty voting for permanently eliminated players. Full spectator mode with squad switching. |
| Matchmaking too slow at launch | High | Launch with 16-player lobbies. Start match with minimum 8 players if needed. Fast starts beat waiting. |
| Clip recording performance on low-end devices | Medium | Buffer runs on background thread. Async capture. Disable option in settings. Test on mid-range 2021 devices. |
| App store rejection on mobile | Low | No gore. Stylised combat only. Age rating 12+. Submit for review 2 weeks before planned mobile launch. |
| Solo developer content pace | High | MVP uses a consistent defined style guide. Seasonal content targets 1 new thematic element per 8-week season — scoped to maintain quality without feature creep. |

---

## COMPLETE SYSTEM CHECKLIST

Every mechanic in this document has:
- ✅ A clear trigger condition
- ✅ A defined outcome
- ✅ Counter-play options for affected players
- ✅ Connection to at least 2 other systems
- ✅ A reason for players to care
- ✅ Balance considerations for all parties

No dead ends. No mechanics that start but lead nowhere. No situations where a player has zero options.

---

**FOREST THRONES**
Game Design & Requirements Document · Version 2.0
Every system documented. Every loophole closed. Every chain connected. Ready to build.
Start with Section 18 → Phase 1 → Prompt 1.1
