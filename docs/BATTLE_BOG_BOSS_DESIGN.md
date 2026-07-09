# Battle Bog Boss Design

Date: 2026-07-07

This document captures the confirmed boss-system direction from the Battle Bog boss design thread. The guiding rule is:

```text
Bosses are habitat events first, creatures second, health bars third.
```

Every major attack should use this readable combat shape:

```text
TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint
```

## System Shape

```text
+====================== BOSS SYSTEM SHAPE ======================+
| Side Boss                                                     |
|  bred-animal milestone -> team-side boss zone -> habitat buff |
|  owning claim -> buff + enemy-side terrain disruption         |
|  enemy steal  -> buff only                                    |
|                                                               |
| Center Big Boss                                               |
|  10:00 / 20:00 center spawn -> random boss family             |
|  50% larger model -> map-wide event -> special combat reward  |
|  no extra enemy-side disruption because the whole map is hit  |
+===============================================================+
```

## Core Loop Integration

```text
Start match
  |
  v
Get food / hunt / forage
  |
  v
Fill creature hunger
  |
  v
Deposit full-hunger creature at habitat
  |
  v
Habitat stock improves + breeding speed improves temporarily
  |
  v
Bred animals fill side-boss meter
  |
  v
Side boss spawns in set order
  |
  v
Claim or steal boss
  |
  v
Gain habitat buff, and possibly enemy-side terrain disruption
```

Rules:

- Side bosses spawn from bred-animal milestones.
- If a side boss is already active in that team's zone, newly bred animals do not count toward that team's next boss meter.
- Side bosses should spawn in a fixed order so both teams can anticipate the next ecosystem pressure.
- Center big bosses spawn at 10:00 and 20:00.
- Center big bosses are randomized picks from the same five boss families.
- Center big bosses are 50% larger and affect the whole map by default.
- Center big bosses do not grant enemy-side terrain disruption, because their fight already disrupts both teams.

Recommended side-boss order:

```text
Champsosaurus -> Platyhystrix -> American Mastodon -> Arthropleura -> Teratornis -> repeat
```

## Travel And Reward Rules

```text
+====================== SIDE BOSS CONTROL ======================+
| Alive fight space                                             |
|  home side boss zone + nearby lane + middle contest band      |
|  never chases deep into enemy territory while alive           |
|                                                               |
| Over-leash behavior                                           |
|  readable retreat/migration home                              |
|  brief weakpoint exposure during recovery                     |
|                                                               |
| Owning team claims own side boss                              |
|  receives habitat-stock buff                                  |
|  sends that boss's terrain disruption to enemy side           |
|                                                               |
| Enemy steals side boss                                        |
|  receives habitat-stock buff                                  |
|  does not send terrain disruption                             |
+===============================================================+
```

Use soft leashes rather than invisible hard walls. The boss should feel dramatic inside its allowed space, but it should not punish a team by running too far into enemy control.

## Side Boss Buffs

These apply to habitat-stock animals, especially newly spawned or bred creatures.

| Boss | Habitat-stock buff |
| --- | --- |
| Champsosaurus | +7% swim duration, +1.5% speed while in water |
| Platyhystrix | +5% healing from all sources, +2.5% HP regen |
| American Mastodon | +5% max health, +2% damage reduction from all sources |
| Arthropleura | -6% hunger depletion, +4% creature size and attack size |
| Teratornis | +4% vision range, +1.5% move speed |

## Center Big Boss Rewards

Big boss rewards are special team combat abilities. If the same boss family is rolled again at the second center timing, the reward upgrades once.

| Boss | First stack | Second stack |
| --- | --- | --- |
| Champsosaurus | Every 5s, next landed attack applies DOT equal to 4.5% target max HP over 3s. Cooldown starts only after the empowered hit lands. | DOT becomes 7.5%. |
| Platyhystrix | Every 10s, gain a one-hit shield. The creature that breaks it is slowed by 20% for 2s. | Slow lasts 4s. |
| American Mastodon | After 4s without taking damage, HP regen speed increases by 30% until full HP or damaged. | Regen speed becomes 50%. |
| Arthropleura | Creature/allied kills grant the team +1.5% creature size and +1.5% max health. | Per-kill stack becomes +1.85% size and +2% max health. |
| Teratornis | After 8s without taking damage, next landed damage instance deals +30%. Taking damage wipes the stored hit. | Next hit deals +45%. |

Arthropleura's big reward should probably cap at 8-10 stacks or include decay/death-loss, because teamwide size and max-health growth is the snowballiest reward.

## Champsosaurus

Research hook: aquatic or semiaquatic choristodere with a long fish-grabbing snout, streamlined body, aquatic sensory flavor, and weak land competence. It should feel like the water itself became dangerous, not just like a large crocodile.

Sources:

- https://ucmp.berkeley.edu/taxa/verts/archosaurs/choristodera.php
- https://nature.ca/en/champsosaurus-ct-scanning/
- https://www.nature.com/articles/s41598-020-63956-y
- https://pubmed.ncbi.nlm.nih.gov/34865223/
- https://dinosaurpark.org/champsosaurus/

```text
+==================== SMALL CHAMPSOSAURUS ====================+
| Role       flood ambush / side water-route controller        |
| Leash      ally boss pond + connected stream + middle band   |
| Reward     side buff + enemy-side flood scar                 |
| Steal      side buff only                                    |
| Weakpoint  jaw/neck after missed lunge or failed sweep       |
+==============================================================+
```

Small side-boss attacks:

- Jaw Gate: two bubble lines form a V in front of the snout; jaws snap shut and drag targets toward the point; churned shallow water remains; jaw/neck exposed on miss.
- Lateral Sweep Drag: head turns sideways; ripples arc left or right; snout sweeps shoreline; shoreline becomes slick mud; neck weakpoint opens on the outer sweep side.
- Tail Current: tail wake appears behind body; crescent current pushes/pulls through water; current lane persists; tail becomes damageable and breaking it lowers future pull strength.
- Bank Breach: cracks appear along bank edge; boss lunges through the land-water boundary; land strip becomes mud or shallow water; boss gets stuck briefly with jaw/neck exposed.

Owning-team disruption:

- Flood Scar: one enemy-side shoreline collapses into mud or shallow water for a timed window.
- It should open a risky swimmer shortcut while slowing non-swimmers, not hard-lock a route.

```text
+===================== BIG CHAMPSOSAURUS =====================+
| Role      whole-map flood event                              |
| Scale     50% larger                                         |
| Reward    charged DOT attack passive                         |
| Terrain   connected water bodies become suspicious routes    |
+==============================================================+
```

Big center-boss attacks:

- Flood Pulse: map-wide ripple from center; water expands briefly over banks, then recedes into mud.
- Three-Gate Jaw Ambush: three V-shaped warning zones appear at ponds/streams; one is the real hit and the others become wake trails.
- River Spine Current: long current line connects top/bottom water routes and drags creatures along it.
- Center Bank Rupture: temporarily changes central land bridges and water crossings.

## Platyhystrix

Research hook: Permian sail-backed amphibian with unusual dorsal blades. Toxicity is fantasy extrapolation, supported by living amphibian skin-defense inspiration. Its sail should be the boss's warning language.

Sources:

- https://bryangee.weebly.com/paleo-blog/the-dog-days-of-dissorophids-week-3-platyhystrix
- https://bioone.org/journals/journal-of-vertebrate-paleontology/volume-42/issue-2/02724634.2022.2144338/Histological-Evidence-for-Dermal-Endochondral-Co-Ossification-of-the-Dorsal/10.1080/02724634.2022.2144338.full
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6339944/

```text
+==================== SMALL PLATYHYSTRIX =====================+
| Role       toxic hazard painter                              |
| Leash      home boss zone + nearby lane + middle band         |
| Reward     side buff + enemy-side toxic bloom                 |
| Steal      side buff only                                     |
| Weakpoint  sail/spines during charge and recovery             |
+==============================================================+
```

Small side-boss attacks:

- Spine Flare: sail rises, spine tips glow, toxic rings pulse outward, puddles linger, sail weakpoint opens.
- Bog Leap: crouch and landing circle telegraph; leap slam splashes poison-mud; toxic crater remains; legs/sail vulnerable while unsticking.
- Slick Skin Shed: body shivers and slides forward; toxic mucus lane remains; exposed fresh skin takes increased damage.

Owning-team disruption:

- Toxic Bloom: an enemy food/plant route gets temporary poisonous puddles around harvest points, forcing slower harvesting or defensive clearing.

```text
+===================== BIG PLATYHYSTRIX ======================+
| Role      map-wide hazard rhythm boss                        |
| Scale     50% larger                                         |
| Reward    one-hit shield with slow retaliation                |
| Terrain   poison waves and puddles pressure routes/food/water|
+==============================================================+
```

Big center-boss attacks:

- Grand Spine Bloom: map-wide warning veins radiate from center; three large toxic ring waves expand through lanes.
- Cross-Map Bog Leap: huge splash target appears in one lane; boss lands and splits route choice with a toxic crater.
- Skinstorm Shed: toxic mist rolls across water and mud paths; water edges become risky; exposed skin becomes vulnerable afterward.

## American Mastodon

Research hook: huge wetland/forest browser with tusks, trunk, heavy body, broad feet, and strong cover-reshaping fantasy. It should be a slow raid-sized siege animal, not a fast charger.

Sources:

- https://www.nps.gov/articles/000/mammut_americanum.htm
- https://www.nhm.ac.uk/discover/the-making-of-an-american-mastodon.html
- https://www.sdnhm.org/exhibitions/fossil-mysteries/fossil-field-guide-a-z/mastodon/
- https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2022.1064299/full

```text
+==================== SMALL AMERICAN MASTODON ====================+
| Role       siege stampede / cover reshaper                       |
| Leash      ally side + nearby lane + middle band                 |
| Reward     side buff + enemy-side siege scar                     |
| Steal      side buff only                                        |
| Weakpoint  legs after charge/stomp; tusks are breakable parts    |
+==================================================================+
```

Small side-boss attacks:

- Tusk Plow: long cracked lane warning; charge pushes creatures and smashes cover; plowed mud trench remains; legs vulnerable after stopping.
- Stomp Quake: circular rings under front feet; expanding quake rings knock back and slow; cracked mud remains; front legs weak after final stomp.
- Trunk Throw: trunk wraps log/rock/tree; throws an arcing impact object; object becomes temporary cover or obstacle; tusk/trunk side exposed.
- Tree Crush: selected tree/reed cluster shakes; boss shoulders through it; fallen-log cover opens a new path.

Owning-team disruption:

- Siege Scar: one enemy route is trampled into cracked mud, with 2-4 trees/rocks converted into fallen cover.

```text
+===================== BIG AMERICAN MASTODON =====================+
| Role      map-wide siege event                                  |
| Scale     50% larger                                             |
| Reward    out-of-combat regen speed boost                        |
| Terrain   stampede corridors reshape cover and sightlines        |
+==================================================================+
```

Big center-boss attacks:

- Grand Tusk Plow: map broadcast plus massive lane warning; huge charge across center route; mud scar and debris walls remain; front legs and tusks exposed.
- Bogquake March: sequential footfall circles across connected lanes; cracked patches slow turning and acceleration.
- Canopy Breaker: multiple trees/rocks marked; trunk tosses debris into lanes; temporary cover and sightlines change.

## Arthropleura

Research hook: giant segmented arthropod with trackways, wet floodplain movement, molting/exuviae inspiration, and slow inevitability. It should feel like a living terrain scar.

Sources:

- https://www.nhm.ac.uk/discover/news/2021/december/worlds-largest-terrestrial-arthropod-was-car-sized-millipede.html
- https://www.nhm.ac.uk/discover/news/2024/october/largest-ever-millipede-head-revealed.html
- https://www.science.org/doi/10.1126/sciadv.adp6362
- https://www.lyellcollection.org/doi/abs/10.1144/jgs2021-115
- https://museum.wales/blog/2384/Arthur-the-Arthropleura/

```text
+==================== SMALL ARTHROPLEURA =====================+
| Role       moving trench / side-lane terrain scar            |
| Leash      home route + nearby lane + middle band             |
| Reward     side buff + enemy-side bog scar                    |
| Steal      side buff only                                     |
| Weakpoint  head/tail during turns; segment bands break down   |
+==============================================================+
```

Small side-boss attacks:

- Segment Wave: segments glow one by one from tail to head; sequential hitboxes ripple down the body; cracked mud ridges remain; head/tail exposed during turns.
- Trench Crawl: trackway lines appear under legs; boss pushes forward; slow trench/slime path remains; middle body armor softens afterward.
- Coil Arena: boss curves into a ring; ring closes into a temporary fight pocket; head/tail weakpoints expose at the opening seam.
- Acid Molt: armor plates lift and drop as damaging floor patches; plates later become clearable or harvestable objects.

Owning-team disruption:

- Bog Scar: one enemy route becomes a temporary slow trench with scattered molt plates.

Implementation rule:

- Keep art/source simplified with one body-segment template plus manifest instances.
- Do not ask players to track 20 separate health bars.
- Use segment bands: front, mid-front, mid-back, rear.

```text
+===================== BIG ARTHROPLEURA ======================+
| Role      map-wide moving wall / living fault line            |
| Scale     50% larger and longer influence                     |
| Reward    teamwide kill-scaling size + max-health stacks      |
| Terrain   center-to-side trench scars and clearable hazards   |
+==============================================================+
```

Big center-boss attacks:

- Lane-Spanning Segment Wave: sequential hitboxes travel across multiple lanes.
- Trench Crawl: creates a center-to-side scar path.
- Huge Coil Arena: encloses a major objective-sized area.
- Map Acid Molt: sheds clearable armor hazards across major routes.

## Teratornis

Research hook: huge soaring Pleistocene bird, carnivorous scavenger/hunter mix, broad wings, hooked beak, stout legs. It should stalk, reveal, displace, isolate, then expose wings.

Sources:

- https://www.nps.gov/articles/000/the-giant-bird.htm
- https://tarpits.org/stories/meet-teratorn-largest-bird-found-la-brea-tar-pits
- https://digitalcommons.usf.edu/auk/vol100/iss2/14/

```text
+==================== SMALL TERATORNIS ====================+
| Role       sky hunt / anti-comfort side boss              |
| Leash      side zone + nearby lane + middle band          |
| Reward     side buff + enemy-side sky scare               |
| Steal      side buff only                                 |
| Weakpoint  wings after dive; legs after failed grab       |
+===========================================================+
```

Small side-boss attacks:

- Hunt Shadow Dive: large moving bird shadow tracks a target lane; delayed dive slash lands; reeds/grass flatten and dust briefly reduces vision; wings exposed after landing skid.
- Wing Shear: feather gust lines fan outward; push cone shoves creatures toward water/mud; wind lane lingers; one wing droops as weakpoint.
- Talon Pin: small lock-on circle under isolated/wounded target; talon grab pins or drags a short distance; scrape trail slows; legs exposed if grab misses or is interrupted.

Owning-team disruption:

- Sky Scare: one enemy lane gets 60-90s of periodic shadow/reveal pulses, wildlife scattering, and less reliable reeds/bush cover.

```text
+===================== BIG TERATORNIS ======================+
| Role      map-wide sky hunt                                |
| Scale     50% larger                                       |
| Reward    ambush burst after no-damage window              |
| Terrain   rotating reveal zones, wind lanes, flattened cover|
+============================================================+
```

Big center-boss attacks:

- Grand Hunt Shadow: huge shadow crosses the map, revealing targets before the dive lands.
- Map Shear Gust: wind waves push creatures away from safe formations and toward hazards.
- Carrion Claim: marks low-health creatures; isolated targets draw harder dives.
- Talon Relocation: carries one target a short distance toward a center drop zone unless allies interrupt.

## Prototype Recommendation

```text
+====================== IMPLEMENTATION ORDER ======================+
| 1. Champsosaurus side boss                                       |
|    proves terrain interaction, leashing, weakpoint recovery       |
|                                                                 |
| 2. Teratornis big boss                                           |
|    proves map-wide readability, reveal zones, anti-comfort play   |
|                                                                 |
| 3. Shared boss framework                                         |
|    spawn meter, claim window, reward routing, terrain events      |
+=================================================================+
```

