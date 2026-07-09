# Supervive Mechanics Research For Battle Bog

Date: 2026-07-07

This document mines SUPERVIVE for mechanics that can elegantly inform Battle
Bog. It is not a request to clone SUPERVIVE. The goal is to extract design
patterns that fit Battle Bog's food, hunger, breeding, habitat, boss, terrain,
and team-vision loops.

Important current-context note: SUPERVIVE is now a historical reference rather
than a stable live-service target. Research should prioritize lessons from its
official patch notes, wiki snapshots, and player-facing guides, then adapt them
to Battle Bog's smaller deterministic Godot scope.

## Source Links

- SUPERVIVE 1.0 feature rundown:
  https://steamcommunity.com/games/1283700/announcements/detail/516342322187730946
- SUPERVIVE Steam announcements and patch notes:
  https://steamcommunity.com/app/1283700/announcements/
- SUPERVIVE Objective Timers wiki:
  https://supervive.wiki.gg/wiki/Objective_Timers
- SUPERVIVE Bosses wiki:
  https://supervive.wiki.gg/wiki/Bosses
- SUPERVIVE Vaults wiki:
  https://supervive.wiki.gg/wiki/Vaults
- SUPERVIVE Getting Started wiki:
  https://supervive.wiki.gg/wiki/Getting_Started
- SUPERVIVE Hunters wiki:
  https://supervive.wiki.gg/wiki/Hunters
- Scan Grenade wiki:
  https://supervive.wiki.gg/wiki/Scan_Grenade
- Raven Spy wiki:
  https://supervive.wiki.gg/wiki/Raven_Spy
- Elixir of Vision wiki:
  https://supervive.wiki.gg/wiki/Elixir_of_Vision
- Abyssal Eye wiki:
  https://supervive.wiki.gg/wiki/Abyssal_Eye
- Nightstalker Soul wiki:
  https://supervive.wiki.gg/wiki/Nightstalker_Soul
- Dignitas beginner guide:
  https://dignitas.gg/articles/how-to-thrive-in-supervive-a-general-introduction
- Dot Esports item overview:
  https://dotesports.com/supervive/news/all-supervive-items-explained

## Core Shape

```text
+================ SUPERVIVE LESSON -> BATTLE BOG USE ================+
| Resource conversion under pressure                                  |
|   farm -> upgrade -> rotate -> contest visible reward                |
|                                                                     |
| Battle Bog translation                                              |
|   forage -> fill hunger -> deposit -> breed -> boss -> claim/steal   |
+=====================================================================+
```

The strongest import is not any one mechanic. It is the way SUPERVIVE links
economy, movement, map information, and objective timing into one continuous
decision loop. Battle Bog should make players repeatedly ask:

```text
Do we forage?
Do we deposit?
Do we breed?
Do we defend habitat?
Do we contest animals?
Do we start side boss?
Do we steal side boss?
Do we recover before the center event?
```

## Confirmed Supervive Facts

These are facts drawn from official patch notes, wiki pages, or player-facing
guides. Some details changed across patches, so use the design pattern rather
than freezing exact numbers unless Battle Bog explicitly adopts them.

### Macro And Objectives

- SUPERVIVE 1.0 simplified its match pitch into: land, get coin, buy gear from
  the Armory, wipe the lobby.
- In-match resources came from monsters, vaults, objectives, bosses, player
  deathboxes, Prisma extractors, and shops.
- The win condition remained battle royale simple: survive until the lobby is
  wiped and the final team remains.
- Supervive used day/night cycles. New days refreshed or advanced map state,
  raised soft level caps, spawned monsters/objectives, and pushed circle
  pressure.
- Objective timing was tied to readable map phases. Wiki notes describe circles
  appearing at the start of each day, storm closing shortly after, and creep
  camps respawning at the start of each day.
- Bosses were marked map objectives with unique rewards. Patch notes later
  changed boss pacing so bosses spawned after new days, with UI showing bosses
  travelling toward their destination.
- Official notes adjusted boss health and stagger so bosses took longer to kill
  and were easier to contest.
- High-value rewards were made visible and limited, including boss reward pools
  and exotic reward distribution.
- Vaults provided objective containers with powers, armor, and gold, opened
  through a mini-game.
- Storm Shifts were randomized match modifiers that altered traversal or
  resources, such as unstable portals or berry/resource changes.

### Combat And Movement

- SUPERVIVE played as an aim-based top-down hero shooter with WASD movement,
  hunter kits, projectiles, cooldowns, and role-distinct abilities.
- Hunters had clear mechanical identities, such as melee combo fighters,
  long-range precision threats, control tanks, burst mages, supports, and
  mobility/displacement specialists.
- Gliding, abyss traversal, jetstreams, storm clouds, and later Skyshark travel
  made map traversal part of combat mastery.
- Gliders used Heat in 1.0; overheating and taking PvP damage at or over heat
  limits could spike players.
- Spiking functioned as a stun/slam into ground or abyss pressure.
- SUPERVIVE used knock, Wisp, deathbox, revive, and respawn layers rather than a
  single instant-death state.
- Official tuning notes tried to avoid combat ending in one burst and pushed
  fights toward back-and-forth exchanges.
- Ability input buffering was tuned down in one patch to make ability output
  feel more attached to player input.
- Some fight wins created reset momentum, such as mana refills on knock in a
  past patch.

### Economy And Progression

- SUPERVIVE's 1.0 economy included coin, EXP, armor, powers, consumables, Prisma,
  Armory unlocks, and shops.
- Build categories included Relics, Grips, Perks, and Kicks. Relics were larger
  situational powers, Grips broader stat/mechanic pieces, Perks smaller passive
  power, and Kicks movement-focused options.
- Prisma was earned through play/objectives/kills/placement and used for Armory
  progression; it was not purchased directly with real money.
- Armor reduced damage until broken and could be repaired or upgraded through
  several systems across patches.
- Base camps provided between-fight value: vision, healing/mana restoration,
  armor repair, shop access, recall destination utility, and positioning.
- Anti-snowball XP tuning existed: knocking higher-level targets gave more EXP,
  lower-level targets gave less, and repeated knocks on the same target
  diminished.
- Death and comeback layers included wisps, deathboxes, respawn beacons,
  resurgence/catch-up mechanics, dropped loot, and Most Wanted-style pressure.

### Vision And Information

- Official patch notes described an "Information Sandbox."
- Off-screen enemy sounds were represented on the minimap as radar pulses; a
  later patch added edge-of-screen visual pulses showing sound direction.
- Scan Grenade provided temporary vision and revealed stealthed enemies.
- Raven Spy granted vision influenced by height, with trees giving more vision.
- Elixir of Vision let the user see invisible units for a duration.
- Abyssal Eye passively let users see invisible units in a vision cone.
- Nightstalker Soul granted team stealth after an out-of-combat delay.
- Community/player guides described bushes as stealth/hiding tools, but treat
  that specific point as lower-confidence than official notes/wiki.

### UX And Readability

- SUPERVIVE heavily iterated on pings and non-verbal communication: enemy pings,
  destination pings, HP/mana pings, food requests, vault/loot pings, teleport
  VO, and dead-player communication.
- 1.0 aimed to make matches more focused, strategic, and knowable.
- The UI overhaul included new HUD, mission hub, in-map trackers, activity
  pickers, death recap, objective/storm/item icons, and tooltips.
- Tutorials and warm-up modes were added/improved to teach combat and builds.
- Recommended items reduced shop friction, while later updates preserved full
  shop access preferences.
- Capture/objective speeds were tuned because too-fast captures made rotations
  feel chaotic instead of strategic.
- Community response disliked locking core mechanics behind onboarding
  progression. The useful lesson: teach and recommend, but do not handicap new
  players by hiding core mechanics.

## Design Inferences For Battle Bog

### 1. Objectives Should Be Information Events

SUPERVIVE objectives did not merely provide rewards. They created public or
semi-public reasons for teams to rotate, contest, trade, or ambush.

```text
Battle Bog objective event
├─ tells both teams something is happening
├─ previews why it matters
├─ creates a decision window
├─ changes map pressure
└─ grants reward only after claim/steal interaction
```

Recommendations:

- Side boss wake-up should broadcast to both teams through world audio, minimap
  icon, and a short warning timer.
- Owning team gets first positional advantage; enemy team gets enough
  information to choose steal, pressure habitat, or trade elsewhere.
- Center big boss spawn should preview family and reward before the fight starts.
- Boss zones should show active/claimable/claimed/stolen states clearly.

### 2. Bred Animals Are Battle Bog's Coin

SUPERVIVE converts farming into gear and objective pressure. Battle Bog should
convert ecosystem progress into boss pressure.

```text
Food -> Hunger -> Deposit -> Breeding Boost -> Bred Animals -> Boss Meter
```

Recommendations:

- Full hunger deposit grants immediate breeding-speed boost, habitat-stock stat
  progress, and boss meter progress.
- If a side boss is active, newly bred animals do not count toward the next side
  boss meter until the boss is claimed, stolen, or reset.
- Show the next side boss family before the meter fills so teams can plan.
- Keep Battle Bog's power in-match. Avoid persistent out-of-match stat unlocks.

### 3. Side Bosses Are Local Macro Pressure

SUPERVIVE bosses were global contest magnets. Battle Bog side bosses should be
local events with fair leash rules.

Recommendations:

- Side boss fight area: home boss zone, nearby lane, and middle contest band.
- Side boss should not chase deep into enemy territory while alive.
- Owning-team claim grants habitat-stock buff and enemy-side terrain disruption.
- Enemy steal grants habitat-stock buff only.
- Do not use pure last-hit for side bosses. Use downed boss -> claim/harvest
  channel -> interrupt/steal window.

### 4. Center Bosses Are Scheduled Gravity

SUPERVIVE's high-value objectives pulled the lobby together. Battle Bog's 10:00
and 20:00 center bosses should do that job.

Recommendations:

- Announce center boss family and reward early.
- Make the model 50% larger than side boss version.
- Make attacks and environmental effects map-wide.
- Do not grant extra enemy-side disruption; the center boss already affects both
  teams.
- If the same family repeats, upgrade the special reward once; cap family stacks
  at two.

### 5. Combat, Terrain, And Information Should Be One System

SUPERVIVE's best combat texture comes from movement and terrain interacting with
damage, danger, and information.

```text
Water  -> speed/risk/ripple clues/current pulls
Mud    -> slower acceleration/turning/drag marks
Reeds  -> partial concealment/rustle pulses/ambushes
Trees  -> cover/food/destructible boss material/perches
Rocks  -> collision/line-of-sight breaks/knockback traps
```

Recommendations:

- Boss attacks should damage, move creatures, change terrain, and change
  information when possible.
- Knockbacks should have terrain consequences, such as water danger, mud slow,
  reed reveal, or collision stun.
- Creature kits should have one primary attack identity plus one terrain/movement
  rule, not just stat differences.
- Fight pacing should be back-and-forth: telegraph, hit, afterstate, recovery,
  punish, reset.

### 6. Vision Is Information Texture, Not Darkness

The goal is not simply to make the screen darker at night. Players should have
partial, readable clues.

```text
+------------------- BATTLE BOG VISION STATES -------------------+
| Seen        exact unit, targetable, current health/direction     |
| Revealed    exact-ish position for limited time                  |
| Heard       directional pulse, no exact identity                 |
| Last Known  fading ghost at old position                         |
| Suspected   rustle/ripple/footprint clue, no unit icon           |
| Hidden      no direct info unless scouted                        |
+-----------------------------------------------------------------+
```

Recommendations:

- Minimap should not show all enemies by default.
- Visible enemies require allied vision radius, reveal, or special broadcast.
- Attacking, harvesting, splashing, sprinting through reeds, or fighting a boss
  should create pulses.
- Last-known markers should fade after a short window, such as 3-8 seconds.
- Day: longer direct vision, more reliable scouting.
- Dusk: shrinking sight, stronger pulse importance.
- Night: shorter direct sight, stronger sound/ripple/reed clues, more stealth
  and ambush tension.
- AI target acquisition should share these states:
  `visible/revealed = attack`, `heard/last-known = investigate`, `hidden =
  ignore`.

### 7. UI Should Shape Complexity

SUPERVIVE's lesson is not to hide complexity. It is to make timing, location,
ownership, and payoff obvious enough that players can make decisions.

```text
+--------------------- BATTLE BOG UI PRIORITY --------------------+
| Boss Warning   what is waking, where, when danger starts         |
| Macro Chain    food -> hunger -> deposit -> breed -> boss meter  |
| Team Pings     food, boss, defend, steal, retreat, claim         |
| Vision State   seen, revealed, heard, last-known, hidden         |
| Claim Clarity  claimant, interrupter, steal window, reward       |
+-----------------------------------------------------------------+
```

Recommendations:

- Boss warning grammar:
  `yellow/white TEL -> red HIT -> terrain residue -> blue/green weakpoint`.
- Minimap icon states: dormant, waking, active, claimable, claimed, stolen.
- Claim bar should show team color, channel progress, contest/interruption,
  steal window, and reward preview.
- Broadcast simple event text:
  `Blue claiming Champsosaurus`, `Red contesting`, `Claim interrupted`,
  `Boss stolen`.
- HUD chain should show:
  `Food Held -> Hunger Full -> Deposit Ready -> Breeding Boost -> Boss Meter`.
- Debug overlays should toggle boss leash zones, attack layers, team vision,
  reveal pulses, last-known markers, food/breed/boss events, and claim logs.

### 8. Anti-Snowball Through Interaction, Not Charity

SUPERVIVE used catch-up and reward tuning, but the best Battle Bog version is
contestable interaction.

Recommendations:

- Strong rewards need caps, decay, steal windows, or counter-objectives.
- Arthropleura big reward should cap at 8-10 stacks and should have decay or
  partial loss on death.
- Behind teams can get comeback pressure through:
  - stealing side boss buff only
  - interrupting claim phase
  - bonus boss-meter progress when far behind in bred animals
  - safer food refresh near losing habitat after enemy disruption expires
  - bounty reward for killing heavily buffed enemy creatures
- Avoid invisible rubber-banding. Make comeback routes visible and contestable.

## Implementation Suggestions

### Near-Term Shared Systems

```text
Boss/Objective Event Bus
├─ wake-up broadcast
├─ active state
├─ claimable state
├─ contested state
├─ claimed/stolen result
└─ reward payload

Team Vision Service
├─ visible entities
├─ reveal effects
├─ sound/ripple/rustle pulses
├─ last-known memory
├─ day/night modifiers
└─ AI query API

Terrain Event API
├─ water/mud/reed/tree/rock changes
├─ temporary vs lasting scars
├─ minimap/world visualization hooks
└─ cleanup/decay timers
```

### Recommended Order

1. Add objective/boss event state contracts without full boss AI.
2. Add team vision states and minimap gating.
3. Add food/deposit/breed/boss-meter UI chain.
4. Prototype Champsosaurus side boss as the first terrain objective.
5. Prototype Teratornis center boss as the first map-wide information boss.
6. Add claim/steal UI and event logs.
7. Add additional boss families on the shared framework.

## Guardrails

- Do not add persistent out-of-match stat progression just because SUPERVIVE had
  Armory. Battle Bog should stay match-contained unless a later design decision
  explicitly changes that.
- Do not make minimap pulses exact GPS. They should communicate direction and
  activity without deleting ambush tension.
- Do not let bosses become isolated PvE chores. Every boss should create
  rotation, steal, trade, or map-pressure decisions.
- Do not make side boss terrain disruption oppressive. It should inconvenience,
  reroute, reveal, or create risky shortcuts, not hard-lock an enemy team.
- Do not hide core mechanics behind tutorial progression. Teach, recommend, and
  scaffold, but leave the real game available.
