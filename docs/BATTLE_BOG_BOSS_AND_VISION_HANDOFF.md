# Battle Bog Boss And Vision Handoff

Date: 2026-07-07

This document captures the boss concept work from the side design thread and the current vision research direction for the Godot repo.

```text
+==================== BOSS SYSTEM SHAPE ====================+
| Side Boss                                                |
|  bred-animal milestone -> team-side zone -> side buff     |
|  owning claim -> buff + enemy-side disruption             |
|  enemy steal  -> buff only                                |
|                                                          |
| Big Boss                                                 |
|  10:00 / 20:00 center spawn -> 50% larger                 |
|  map-wide event -> special combat reward                  |
|  no enemy-side disruption because the map is already hit  |
+==========================================================+
```

## Core Loop Tie-In

```text
Start match
  v
Get food / hunt / forage
  v
Fill hunger
  v
Deposit full-hunger creature at habitat
  v
Habitat stock improves + breeding speed improves temporarily
  v
Bred animals fill side-boss meter
  v
Side boss spawns in set order
  v
Claim side boss for habitat buff, and if owning team claims it, enemy-side terrain disruption
  v
At 10:00 and 20:00, center big boss spawns as a random 50% larger version
```

Important boss-meter rule: while a side boss is active in that team's zone, newly bred animals should not count toward that team's next boss. This prevents stockpiling and boss-chain abuse.

## Travel And Reward Rules

```text
Side boss alive
|- may fight in home side boss zone
|- may enter nearby lane and middle contest band
|- should not chase into enemy deep territory
`- if over-leashed, retreats or migrates home with a readable recovery window

Owning team claims own side boss
|- receives boss habitat-stock buff
`- sends that boss's terrain disruption to enemy side

Enemy steals side boss
|- receives boss habitat-stock buff
`- does not send terrain disruption

Center big boss
|- affects the whole map during the fight
|- grants special team ability
`- never grants extra enemy-side disruption
```

## Side Boss Buffs

| Boss | Habitat-stock buff |
| --- | --- |
| Champsosaurus | +7% swim duration, +1.5% speed while in water |
| Platyhystrix | +5% healing from all sources, +2.5% HP regen |
| American Mastodon | +5% max health, +2% damage reduction from all sources |
| Arthropleura | -6% hunger depletion, +4% creature size and attack size |
| Teratornis | +4% vision range, +1.5% move speed |

## Big Boss Rewards

| Boss | First stack | Second stack |
| --- | --- | --- |
| Champsosaurus | Every 5s, next landed attack deals DOT equal to 4.5% of target max HP over 3s. Cooldown starts only after landing. | DOT becomes 7.5%. |
| Platyhystrix | Every 10s, one-hit shield negates one damage instance. Breaker is slowed by 20% for 2s. | Slow lasts 4s. |
| American Mastodon | After 4s without taking damage, HP regen speed +30% until full HP or damaged. | Regen speed +50%. |
| Arthropleura | Creature/allied kills grant team +1.5% creature size and +1.5% max health. | Per-kill stack becomes +1.85% size and +2% max health. Recommend 8-10 stack cap or decay. |
| Teratornis | After 8s without taking damage, next landed damage instance deals +30%. Taking damage wipes the stored hit. | Next hit deals +45%. |

## Champsosaurus

Research hooks: aquatic ambush choristodere, long fish-grabbing snout, streamlined body, water/vibration-sense flavor. It should feel like the water itself became dangerous, not just like a large crocodile.

Sources:
- https://ucmp.berkeley.edu/taxa/verts/archosaurs/choristodera.php
- https://nature.ca/en/champsosaurus-ct-scanning/
- https://www.nature.com/articles/s41598-020-63956-y

```text
+================ SMALL CHAMPSOSAURUS ================+
| Role: flood ambush / side water-route controller    |
| Weakpoint: jaw/neck after missed lunge              |
| Part break: tail damage reduces current strength    |
| Disruption: enemy shoreline flood scar              |
+=====================================================+
```

Small side-boss attacks:
- Jaw Gate: two bubble lines form a V, jaws snap shut and drag targets toward the point, churned shallow water remains, jaw/neck exposed on miss.
- Lateral Sweep Drag: head turns sideways, ripples arc left or right, snout sweeps shoreline, shoreline becomes slick mud, neck exposed on outer sweep side.
- Tail Current: tail wake appears, crescent current pushes/pulls through water, current lane persists, tail becomes damageable.
- Bank Breach: cracks appear along bank edge, boss lunges through land-water boundary, land strip becomes mud/shallow water, boss gets stuck briefly.

Owning-team side disruption: send one timed flood scar to an enemy-side shoreline. It should open a risky swimmer shortcut while slowing land creatures, not hard-lock a route.

```text
+================ BIG CHAMPSOSAURUS =================+
| Role: whole-map flood event                        |
| Scale: 50% larger                                  |
| Reward: charged DOT attack passive                 |
+====================================================+
```

Big center-boss attacks:
- Flood Pulse: map-wide ripple; water expands over banks, then recedes into mud.
- Three-Gate Jaw Ambush: three V warnings appear at ponds/streams; one is the real hit, decoys leave wake trails.
- River Spine Current: long current connects top/bottom water routes and drags creatures along it.
- Center Bank Rupture: temporarily changes central bridge/water crossings.

## Platyhystrix

Research hooks: sail-backed amphibian; exact sail function uncertain. Toxicity is fantasy extrapolation, supported by general amphibian skin defense logic. Its sail should be a readable warning system.

Sources:
- https://bryangee.weebly.com/paleo-blog/the-dog-days-of-dissorophids-week-3-platyhystrix
- https://bioone.org/journals/journal-of-vertebrate-paleontology/volume-42/issue-2/02724634.2022.2144338/Histological-Evidence-for-Dermal-Endochondral-Co-Ossification-of-the-Dorsal/10.1080/02724634.2022.2144338.full
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6339944/

```text
+================ SMALL PLATYHYSTRIX ================+
| Role: toxic hazard painter                         |
| Weakpoint: sail during charge/recovery             |
| Risk: hitting sail too late causes overflare        |
| Disruption: Toxic Bloom around enemy food route     |
+====================================================+
```

Small side-boss attacks:
- Spine Flare: sail rises, spine tips glow, toxic rings pulse outward, puddles linger, sail exposed afterward.
- Bog Leap: crouch and landing circle telegraph, leap slam splashes poison-mud, toxic crater remains, legs/sail exposed.
- Slick Skin Shed: body shivers, slick trail preview appears, boss slides and sheds toxic mucus, exposed skin takes bonus damage.

Owning-team side disruption: Toxic Bloom around an enemy harvest/food route, forcing slower harvesting or defensive clearing.

```text
+================ BIG PLATYHYSTRIX =================+
| Role: map-wide poison rhythm boss                 |
| Scale: 50% larger                                 |
| Reward: one-hit shield with slow retaliation       |
+===================================================+
```

Big center-boss attacks:
- Grand Spine Bloom: map-wide warning veins radiate from center; three large toxic ring waves expand through lanes.
- Cross-Map Bog Leap: huge splash target appears in one lane; boss lands and splits the route with a toxic crater.
- Skinstorm Shed: toxic mist rolls across water and mud paths; water edges become risky.

## American Mastodon

Research hooks: huge wetland/forest browser, tusks/trunk, heavy body, broad feet, cover destruction. It should be a slow siege animal, not a fast charger.

Sources:
- https://www.nps.gov/articles/000/mammut_americanum.htm
- https://www.nhm.ac.uk/discover/the-making-of-an-american-mastodon.html
- https://www.sdnhm.org/exhibitions/fossil-mysteries/fossil-field-guide-a-z/mastodon/

```text
+================ SMALL AMERICAN MASTODON ================+
| Role: siege stampede / cover reshaper                   |
| Weakpoint: legs after charges/stomps                    |
| Breakables: tusks reduce plow/throw threat              |
| Disruption: enemy Siege Scar                            |
+=========================================================+
```

Small side-boss attacks:
- Tusk Plow: cracked lane warning, charge pushes creatures and smashes cover, plowed mud trench remains, legs exposed.
- Stomp Quake: circular rings under front feet, expanding quake rings knock back/slow, cracked mud remains, front legs weak.
- Trunk Throw: trunk wraps log/rock/tree, throws arcing impact, object becomes temporary cover/obstacle, tusk/trunk side exposed.
- Tree Crush: marked tree/reed cluster shakes, boss slams through it, creates fallen-log cover and opens a path.

Owning-team side disruption: Siege Scar on one enemy-side route, with cracked mud and fallen cover. It should change cover/sightlines without sealing the enemy in.

```text
+================ BIG AMERICAN MASTODON ================+
| Role: map-wide siege event                            |
| Scale: 50% larger                                     |
| Reward: out-of-combat regen speed                     |
+=======================================================+
```

Big center-boss attacks:
- Grand Tusk Plow: map broadcast plus huge lane warning; charge across center route leaves mud scar and debris walls.
- Bogquake March: sequential footfall circles across connected lanes; cracked patches slow turning/acceleration.
- Canopy Breaker: multiple trees/rocks marked, trunk tosses debris into lanes, cover and sightlines change.

## Arthropleura

Research hooks: huge segmented arthropod, broad trackways, wet/open floodplain movement, molting. It should feel slow, huge, readable, and inevitable.

Sources:
- https://www.nhm.ac.uk/discover/news/2021/december/worlds-largest-terrestrial-arthropod-was-car-sized-millipede.html
- https://www.nhm.ac.uk/discover/news/2024/october/largest-ever-millipede-head-revealed.html
- https://www.science.org/doi/10.1126/sciadv.adp6362

```text
+================ SMALL ARTHROPLEURA ================+
| Role: moving trench / side-lane terrain scar        |
| Weakpoint: head/tail during turns                   |
| Armor: segment bands break over time                |
| Disruption: enemy bog scar with molt plates         |
+=====================================================+
```

Small side-boss attacks:
- Segment Wave: segments glow one by one, sequential hitboxes ripple down body, cracked mud ridges remain, head/tail exposed during turn.
- Trench Crawl: trackway lines appear, boss pushes forward, leaves slow trench/slime path, middle armor softens after crawl.
- Coil Arena: boss curves into visible ring, ring closes into temporary fight pocket, head/tail weak at opening seam.
- Acid Molt: plates lift, armor plates drop as damaging patches, plates become clearable/harvestable objects.

Owning-team side disruption: one enemy route becomes a temporary slow trench with scattered molt plates.

Implementation note: keep PSD/model source simplified with one body segment template plus manifest instances. Do not require players to track 20 separate health bars; use front, mid-front, mid-back, rear segment bands.

```text
+================ BIG ARTHROPLEURA =================+
| Role: living fault line / map scar                |
| Scale: 50% larger and longer influence            |
| Reward: teamwide kill-scaling size + max HP       |
+===================================================+
```

Big center-boss attacks:
- Lane-Spanning Segment Wave: sequential hitboxes travel across multiple lanes.
- Trench Crawl: creates center-to-side scar path.
- Huge Coil Arena: encloses a major objective-sized area.
- Map Acid Molt: sheds clearable armor hazards across routes.

Balance note: cap the big reward at 8-10 stacks or add decay, because teamwide size/HP on kill is likely the snowballiest reward.

## Teratornis

Research hooks: huge soaring bird, broad wings, hooked beak, stout legs/talons, likely scavenger/hunter mix rather than a pure eagle analogue. It should stalk, reveal, displace, isolate, then expose wings.

Sources:
- https://www.nps.gov/articles/000/the-giant-bird.htm
- https://tarpits.org/stories/meet-teratorn-largest-bird-found-la-brea-tar-pits
- https://digitalcommons.usf.edu/auk/vol100/iss2/14/

```text
+================ SMALL TERATORNIS ================+
| Role: sky hunt / anti-comfort side boss          |
| Weakpoint: wings after dive, legs after grab     |
| Pressure: wounded/isolated targets               |
| Disruption: enemy Sky Scare lane reveal          |
+==================================================+
```

Small side-boss attacks:
- Hunt Shadow Dive: large moving shadow tracks lane, delayed dive slash lands, reeds/grass flattened, wings exposed after skid.
- Wing Shear: feather gust lines fan outward, push cone shoves creatures toward water/mud, one wing droops in recovery.
- Talon Pin: lock-on circle under isolated/wounded target, grab pins or drags, scrape trail slows path, legs exposed on miss/interrupt.

Owning-team side disruption: Sky Scare for 60-90s on one enemy lane. Periodic shadows reveal enemy creatures, small wildlife scatter, reeds/bush cover becomes less reliable.

```text
+================ BIG TERATORNIS =================+
| Role: map-wide sky hunt                         |
| Scale: 50% larger                               |
| Reward: ambush burst after no-damage window     |
+=================================================+
```

Big center-boss attacks:
- Grand Hunt Shadow: huge shadow crosses map, revealing targets before dive lands.
- Map Shear Gust: wind waves push creatures away from safe formations and toward hazards.
- Carrion Claim: marks low-health creatures; isolated targets draw harder dives.
- Talon Relocation: carries one target a short distance toward center drop zone unless allies interrupt.

## Vision Audit A: Minimap

Current behavior:
- `scripts/ui/minimap.gd` redraws at 8 Hz.
- The static backdrop draws all terrain layers from `arena.terrain_map.zone_layers`.
- Huts, cores, entities, squad members, animal zones, and food sources are drawn without a team vision mask.
- `_is_visible_entity(entity)` only checks that the entity is non-null, valid, and alive.
- Food overlays draw all food sources globally.
- The minimap camera rectangle shows current viewport, but does not imply tactical reveal.

Why it feels unlimited:
- Enemy icons are not gated by distance, line of sight, cover, stealth, day/night, or last-known position.
- Food and objective information is globally available.
- There is no fog texture, explored/unexplored state, or minimap reveal layer.

Recommended minimap design:
```text
Minimap entity state
|- visible_now: full icon, live position
|- recently_seen: faded ghost icon at last known position
|- heard/noise ping: expanding ring, no exact identity
`- unknown: hidden
```

Concrete implementation direction:
- Add a `VisionSystem` service or arena-owned dictionaries:
  - `team_visible_now[team][entity_id]`
  - `team_last_seen[team][entity_id] = {position, age, kind_hint}`
  - `team_explored_cells[team]`
- Replace `Minimap._is_visible_entity()` with `arena.is_entity_visible_to_team(entity, viewer_team)` plus last-seen rendering.
- Gate food overlays by explored/visible state or show only friendly-known harvest points.
- Add tests for minimap hiding enemies outside vision, fading last-known icons, reveal effects showing hidden enemies, and night reducing minimap certainty.

Likely files:
- `scripts/ui/minimap.gd`
- `scripts/ui/minimap_backdrop.gd`
- `scripts/game/arena.gd`
- new `scripts/sim/vision_system.gd` or `scripts/game/vision_layer.gd`

## Vision Audit B: World-Space Movement Vision

Current behavior:
- `scripts/game/arena.gd` has a camera with cursor lead, but no view/fog/lighting mask.
- `Arena._draw()` draws animal zones, telegraphs, habitat labels, stock visuals, breeding cues, and squad badges globally.
- Creature nodes remain visible if alive; stealth only reduces creature draw alpha to 0.4 in `scripts/sim/creature.gd`.
- `Creature.begin_stealth()` and `is_stealthed()` exist, and `TargetFilter` can reject stealthed targets unless `allow_stealthed` is true.
- AI in `scripts/ai/bot_brain.gd` scans `arena.entities` within `FIGHT_SCAN_RANGE` and does not use team vision, day/night, or line of sight for ordinary target selection.
- `Arena.has_line_of_sight()` exists and checks segment-vs-cover against `cover_rects`, but it is currently used for some attack queries/projectile checks, not for player world visibility or general AI awareness.
- `day_index` / `day_timer` exist, but `_tick_day_cycle()` only advances a 120s cycle, refreshes food, and announces dawn. There is no actual day/night phase, darkness, vision multiplier, or mechanical visibility change.

Why it feels unlimited:
- The player camera can see any entity inside the viewport because nothing masks or hides nodes based on team vision.
- AI can acquire targets from entity lists without a vision contract.
- Day/night is not a visibility system yet.
- Stealth is a partial alpha/targeting modifier, not a full information layer.

Recommended world-space design:
```text
World vision
|- nearby clarity: full detail inside creature/team sight radius
|- edge uncertainty: silhouettes/low-alpha hints near sight edge
|- hidden zones: enemies in cover/night hidden unless revealed
|- last known: short-lived ghost markers, not live tracking
`- noise/reveal events: attacks, boss warnings, scan abilities, owl/firefly tools
```

Day/night should become a phase inside `get_day_state()`:
- Day: normal vision, shorter last-seen persistence, less hiding power.
- Dusk: mild tint, reduced vision by roughly 10-15%.
- Night: reduced vision by roughly 25-35%, stronger cover/brush hiding, more value from scouts, fireflies, owl perch, Teratornis reward, and reveal consumables/abilities.
- Dawn: food refresh plus gradual return to normal vision.

Concrete implementation direction:
- Add `get_light_phase()` and `get_vision_multiplier(team_or_actor)` in `arena.gd` or a vision script.
- Add per-creature stats: `base_vision_radius`, `night_vision_mult`, `cover_stealth_bonus`, `reveal_radius_bonus`.
- Build team vision from living allied actors, huts, habitats, minions, temporary wards/scans, and boss effects.
- Hide or dim enemy `CanvasItem.visible` / draw alpha using `arena.is_entity_visible_to_team(entity, BLUE)` for the local player.
- Update bot brain to choose targets from `arena.get_visible_enemy_targets(actor)` rather than all `arena.entities`.
- Preserve "blind damage" behavior: projectiles/AOE can still hit unseen targets, but AI/lock-on/minimap should not track unseen targets.

Likely tests:
- `scripts/test/battle_bog_vision_world_check.gd`: enemies outside radius are not visible or targetable by bots.
- `scripts/test/battle_bog_vision_minimap_check.gd`: minimap hides live enemy positions, shows last-known fading pings.
- `scripts/test/battle_bog_day_night_vision_check.gd`: night reduces vision radius and dawn restores it.
- `scripts/test/battle_bog_vision_reveal_check.gd`: owl/firefly/leech/reveal effects expose stealth/cover targets for a timed window.

Likely files:
- `scripts/game/arena.gd`
- `scripts/ai/bot_brain.gd`
- `scripts/sim/creature.gd`
- `scripts/sim/combat/target_filter.gd`
- `scripts/sim/environment_profile.gd`
- `scripts/ui/minimap.gd`
- `scripts/ui/minimap_backdrop.gd`

## Supervive-Inspired Vision Research

Important note: public Supervive implementation details are limited, but available sources support a tactical-information model with day/night pacing, vision items, reveal tools, and stealth/invisibility counters.

Useful source notes:
- Supervive has a Day/Night cycle that gates match pacing, monster spawns, level cap, and circle timing. Sources: https://supervive.wiki.gg/wiki/Objective_Timers and https://dignitas.gg/articles/how-to-thrive-in-supervive-a-general-introduction
- Scan Grenade provides temporary vision and reveals stealthed enemies; enemies remain visible briefly after leaving its vision. Source: https://supervive.wiki.gg/wiki/Scan_Grenade
- Abyssal Eye can see invisible units only through the holder's vision cone. Source: https://supervive.wiki.gg/wiki/Abyssal_Eye and SteamDB patch mirror https://steamdb.info/patchnotes/17253819/
- Elixir of Vision grants vision of invisible units for 90s. Source: https://supervive.wiki.gg/wiki/Elixir_of_Vision

Design translation for Battle Bog:
```text
Supervive feel to borrow
|- moving through the map should feel information-limited
|- reveal tools should create confident short windows
|- stealth/cover should be beatable, not absolute
|- vision cone/radius should matter for ambush and scouting
|- minimap should show certainty levels, not omniscience
`- day/night should change priorities, not just screen tint
```

Battle Bog-specific proposal:
- Base creature vision is circular for simplicity, with optional facing cone bonus for scouts/predators.
- Cover/brush does not block the whole world; it hides enemies unless an allied vision source is close, a reveal effect is active, or the enemy attacks.
- Night shrinks normal vision and makes sound/noise pings more important.
- Water, reeds, and boss events produce ripples/shadows/noise pings even when exact enemy identity is hidden.
- Minimap should render:
  - exact live enemy icons only while visible_now
  - faded last-known pings for a short time
  - objective/boss warnings globally
  - noisy or suspicious zones as rings, not full information

## Recommended Vision Milestone

```text
Milestone V1: Tactical Vision
|- create vision system / team visibility API
|- gate minimap enemies and food overlays
|- gate bot target acquisition through visible targets
|- add day/dusk/night/dawn phase with vision multipliers
|- add world-space darkness/fog overlay for local player
|- convert existing reveal hooks into timed visibility sources
`- add focused tests for minimap, world, AI, and day/night
```

Start small: implement the vision API first, then wire minimap, then bots, then world-space masking. That avoids making a pretty fog layer while the game logic still sees everything.

