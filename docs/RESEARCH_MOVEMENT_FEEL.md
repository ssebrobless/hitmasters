# Battle Bog Movement Feel Research

Compiled 2026-07-05. Scope: research and implementation recommendations only.
No gameplay code or roster data changed.

## Thesis

Battle Bog should not make 21 creatures feel unique by giving every kit a bespoke
controller. It should make them feel unique by combining a small number of
deterministic movement primitives with creature-specific timing, turn, terrain,
and procedural animation profiles.

```text
╔══════════════════════════════════════════════════════════════════════╗
║                        MOVEMENT FEEL STACK                         ║
╠════════════════════╦════════════════════╦═══════════════════════════╣
║ Animal truth       ║ Sim levers         ║ Render/read levers       ║
║ body plan + gait   ║ accel, friction,   ║ bob, squash, gait phase, ║
║ terrain comfort    ║ turn rate, dashes, ║ trails, ripples, shadow  ║
╠════════════════════╬════════════════════╬═══════════════════════════╣
║ Player read        ║ "What is it?"      ║ silhouette + contact     ║
║ Player intent      ║ "Can I steer it?"  ║ low latency response     ║
║ Combat fairness    ║ "Can I punish it?" ║ startup/recovery tells   ║
╚════════════════════╩════════════════════╩═══════════════════════════╝
```

The highest-value rule: input should stay readable and responsive, but each
creature's *path into the same input* should differ. A frog can snap into motion
with hop pulses, a turtle should resist turning, a crayfish should scuttle and
reverse explosively, and a water shrew should skim because it is too light and
urgent to feel like a generic mouse.

## Roster Movement Matrix

Wave = current `ROSTER_WAVE_PLAN.md` wave. "W2b" is the capsule-gated snake/gator
wave from that doc.

| Creature | Wave | Real-world locomotion cues | Game feel target | Implementation levers | Risk / effort |
| --- | --- | --- | --- | --- | --- |
| Bullfrog | W1 | Long hind legs, webbed feet, powerful swimming/jumping; ambush stillness before burst. | Heavy ambush hopper: still, coiled, then a thick landing thump. | Hop-pulse ground movement profile; render-only vertical arc and landing squash; Leap uses dash with `hop_over_obstacles`; Camouflage gets "statue" idle timer cue. | Low. Mostly `creature.gd` movement profile + `visual_style.gd` frog gait. |
| Chorus Frog | Post-W1 / existing M2 slice | Tiny frog that migrates between pools; identity is calling and group tempo. | Light, fast, rhythmic skitter-hop support. | Same hop primitive as Bullfrog but shorter period, lower landing weight; call-sac pulse tied to Comb Call/Cree and movement cadence. | Low. Visual + profile tuning. |
| Newt | W2a | Salamander/newt movement shifts between limb walking and tail/body undulation in water. | Slick little punish tank: slow deliberate crawl on land, eel-tail glide in water. | Amphibian crawl profile; swim gait switches to tail undulation overlay; Unken Reflex hard-freezes movement then flips orientation. | Medium. Needs W2a invuln/stance logic and water render state. |
| Cane Toad | W1 | Toads are more squat and terrestrial; studies emphasize hopping endurance affected by hydration/temperature. | Plodding poison battery: short ugly hops, not graceful frog leaps. | Low hop height, long ground contact, high friction; Thanatosis pins velocity but keeps torso/aim active; poison stream recoil slows facing slightly. | Low-Med. Needs ammo/stance locks from W1. |
| Snapping Turtle | Existing M2 slice | Mostly aquatic, ambushes with long neck; slow on land, stronger in water. | Armored anchor: slow body, sudden neck threat. | Heavy pivot inertia; shell bob minimal; bite windup retracts head while body keeps creep; water movement gets smoother acceleration than land. | Low-Med. Existing kit; add profile polish. |
| Water Snake | W2b | Snakes use lateral undulation; aquatic snakes use a modified lateral wave in water; strikes are fast lunges. | Serpentine duelist: head steers first, body follows. | Capsule turn-rate cap; slither sine wave render path; speed bonus while moving with curves, penalty on hard reversals; latch anchor at head/hull point. | Medium-High. Gated by capsule + latch feel. |
| Bog Turtle | W4 | Very small semi-aquatic turtle in muddy wetlands; movement is low, tucked, and cautious. | Backpack healer: tiny, stubborn, carried more than self-driven. | Mini turtle profile; mount anchor smoothing; tiny idle foot paddles while mounted; dismount pop with short recovery. | High. Mount/shared damage controller. |
| Alligator | W2b | Alligators swim, walk, run, crawl; high-walk lifts body/tail, low crawl is stealthier. | Massive ambush grappler: low stealth crawl, high-walk commitment, tail-driven water power. | Two posture profile: Ambush = low crawl, normal = heavy high-walk; capsule turn inertia; water swim overlay from tail sway; Death Roll circular drag lock. | High feel risk. Capsule + latch + roll. |
| Owl | Existing M3 slice | Silent flight: large wings allow slow gliding; feather structure dampens noise. | Quiet aerial assassin: floaty but precise, minimal flapping noise/read. | Flight profile with low accel noise, soft hover drift, slow wingbeats; Silent Flight suppresses usual trail/ripple cues; perch snap-to-anchor. | Medium. Flight readability vs stealth. |
| Great Blue Heron | W2a | Stands motionless, wades with long deliberate steps, strikes rapidly; slow deep wingbeats in flight. | Patient spear-wader: slow legs, instant bill. | Wading profile ignores water drag; stride lock while attacking; long neck windup/strike overlay; Flushing dash-to-flight with one large wingbeat. | Medium. Needs W2a wading flag. |
| Kingfisher | W2a | Energetic patrol flight; perches/hovers, then plunges headfirst; nests in bank burrows. | Twitchy precision diver: dart, hold, spike down. | Hover bob state, sharp dive line, plunge splash; burrow entry/exit dirt ring; post-move damage buff shown by beak/wing streak. | Medium. Hover + single burrow. |
| Duck | Existing M3 slice | Surface duck: walking, swimming, direct flight; dabbling ducks are smoother walkers than divers. | Comfortable generalist: waddles, paddles, bursts into flight. | Waddle sway on ground; paddling ripple cadence in water; duckling follower wake trails; takeoff has flapping acceleration. | Low-Med. Existing kit plus render/profile. |
| Water Shrew | W1 | Runs/skates on water via trapped air in hairs; underwater attacks react in milliseconds; bubble-sniffs prey. | Tiny electric skimmer: frantic, high-frequency, almost too fast. | High accel/decel, low inertia; Water Walk surface-only skim with micro-zigzag and bubble trail; idle drops into swim; bite lunge is a 1-tick visual snap. | Medium. Needs terrain override + strong readability. |
| Beaver | Existing M3 slice | Awkward on land, strong in water; webbed hind feet swim, tail rudders/balances/signals. | Builder bulldozer: land trundle, water competence. | Land heavy profile; water glide profile; tail-slap recoil wave; carrying/placing dams briefly slows/pivots body. | Low-Med. Existing kit. |
| Otter | W4 | Long agile bodies twist, roll, dive, slide; land travel includes bounding and slides; social play matters. | Three-body chaos that still reads as one pack. | Pack cohesion controller; leader/follower slots with elastic offsets; bound-slide gait; water roll turns; latch follower magnetism. | High. Pack controller and bots. |
| Mink | Existing M2 slice | Semi-aquatic mustelid; streamlined body reduces drag, but surface swimming is energetically costly; bounding is efficient on land. | Needle assassin: elastic bound, expensive water chase. | Bounding profile with spinal stretch; water speed ok but stamina/read cost via heavier wake; Choke dash stretches body then snaps to neck. | Low-Med. Existing kit polish. |
| Leech | W4 | Leeches either swim by eel-like undulation or crawl inchworm-style using front/rear suckers. | Living resource blob: horrible little inching mass, smooth in water. | Cluster state uses body-count visual density; ground inchworm pulses; water undulation wave; attach projectiles become mini leech gait overlays. | High. Body-count HP/ammo. |
| Crayfish | W1 | Decapod scuttle plus caridoid escape: rapid abdominal flexion/tail flip creates backward burst. | Defensive duelist: sideways confidence, explosive reverse panic. | Scuttle acceleration with lateral foot cadence; Q uses backward dash with tail-curl anticipation; Meral Display narrows strafe/turn and enlarges claws/body. | Medium. Needs stance + forced move/knockback. |
| Mosquito Swarm | W3 | Mosquito swarms are aerial aggregations; recent work models attraction to visual + CO2 cues rather than pure follow-the-leader flocking. | Dirty cloud: jittery local noise, coherent global intent. | Swarm primitive: many render dots orbit center; pass-through movement; idle/attack modes alter dot radius; trail AOE stamps from center path. | Medium. VFX perf caps. |
| Wolf Spider | W3 | Cursorial hunter; fast legged scuttle, pounce, burrow use in kit fantasy. | Low, sudden ambusher: foot noise then trap-door burst. | Spider scuttle gait; burrow entry hides body with dirt/silk ring; emerge charge has low-to-high body scale and leg flare. | Medium-High. Burrow network + pets. |
| Firefly | W3 | Fireflies are beetles; bioluminescent flashes are communication/defense cues, with airborne flashing. | Fragile lantern: soft hover, signal pulses, slow drift. | Hover bob + small drift inertia; glow radius breathing tied to speed/Flash-Train; projectile/mine inherit glow cadence. | Low-Med. Mostly render + aura. |

## Shared Movement Primitives

```text
╔══════════════════════╦══════════════════════════════════════════════╗
║ Primitive layer      ║ Owns                                         ║
╠══════════════════════╬══════════════════════════════════════════════╣
║ Sim profile          ║ accel, decel, friction, turn rate, terrain   ║
║ State decorator      ║ hop, stance, hover, burrow, mount, latch     ║
║ Render overlay       ║ bob, squash, gait phase, ripples, trails     ║
║ Bot hint             ║ distance comfort, turn budget, terrain pref  ║
╚══════════════════════╩══════════════════════════════════════════════╝
```

Recommended file/API shape for later implementation:

| Primitive | Use for | Suggested API/files | Determinism notes |
| --- | --- | --- | --- |
| Movement profiles | All creatures | `scripts/sim/movement_feel.gd`: `profile_for(creature_id) -> {accel, decel, turn_rate, idle_friction, water_profile, gait}`; consumed by `creature.gd` before `move_and_slide()`. | Pure math from input + state. No RNG. |
| Hop arcs | Bullfrog, Chorus Frog, Cane Toad | `movement_feel.gd` gait phase + render-only `vertical_bob_px`; Leap remains dash sim. | Keep collision 2D; arc is visual plus obstacle-hop flag on dash. |
| Scuttle acceleration | Crayfish, Wolf Spider | Lateral foot phase in `visual_style.gd`; optional `preferred_strafe_mult` in profile. | Input vector still authoritative; profile changes accel/turn only. |
| Serpentine slither | Water Snake, Leech swim | `visual_style.gd` already has serpent/cluster bases; add sim-facing `body_axis` smoothing for capsule creatures. | Store deterministic `body_axis` rather than deriving solely from instantaneous velocity. |
| Heavy pivot inertia | Snapping Turtle, Alligator, Beaver | `turn_rate_deg_per_sec`, `reverse_accel_mult`, `water_accel_mult`. | Must not delay aim/projectile intent unless a kit explicitly asks for body-facing gates. |
| Hover bob / air drift | Owl, Kingfisher, Firefly, Mosquito | Air profile separate from ground profile; render bob uses `anim.walk_phase` or sim tick time. | Avoid `Time.get_ticks_msec()` for gameplay. Render-only use is fine. |
| Water-surface skimming | Water Shrew Q, Duck paddling, leech water | Terrain override flag in `EnvironmentProfile` / `creature.gd`: `surface_walk`, `paddle`, `deep_swim`. | Water Walk must end on zero input exactly, per roster. |
| Burrow emergence | Kingfisher, Wolf Spider | `CreatureState.BURROWED` logic plus `burrow_anchor`/placeable network later. | Untargetability and collision must be state-owned, not visual-only. |
| Pack cohesion | Otter, ducklings as reference | Extract current squad/duckling follower ideas into `scripts/sim/pack_controller.gd`. | Followers consume deterministic steering, not independent RNG. |
| Mount anchor | Bog Turtle | `MOUNTED` state: parent offset, damage redirect, carrier terrain exemptions. | Explicit death/dismount order needed for stock system. |
| Swarm field | Mosquito, Firefly glow, Leech cluster | Visual dot cache; hard cap live trail/field nodes in `arena.gd`. | Swarm dots can be render RNG seeded by creature id; hitbox remains one hull. |
| Terrain transition easing | Semi-aquatics | Existing `terrain_speed_px` lerp is a good base; expose per-profile rates. | Current `TERRAIN_SPEED_LERP_RATE` is global; profile it carefully. |

## Wave 1 Recommendations

Wave 1 should be the "movement feel proving ground" because its four creatures
cover the core axes without exotic controllers:

```text
╔═══════════════╦══════════════════╦════════════════════════════════╗
║ Creature      ║ Feel verb        ║ First shippable movement delta ║
╠═══════════════╬══════════════════╬════════════════════════════════╣
║ Bullfrog      ║ coil ▶ thump     ║ Hop gait + leap landing tell   ║
║ Cane Toad     ║ squat ▶ ooze     ║ Toad hop + rooted aim stance   ║
║ Crayfish      ║ scuttle ◀ snap   ║ Lateral gait + tail-flip dash  ║
║ Water Shrew   ║ zip ▶ skim       ║ high accel + water-walk wake   ║
╚═══════════════╩══════════════════╩════════════════════════════════╝
```

### Bullfrog

Land first in Wave 1, before damage tuning. A generic `speed * input` frog will
feel wrong even if Leap works mechanically.

- Movement profile: medium top speed, high initial impulse, modest decel, hop
  cadence around 0.45-0.60 s at full speed.
- Render: keep body planted during the first half of each hop, then a short
  forward body bob and landing squash. The hop height is render-only.
- Leap: add clear takeoff/air/landing VFX. The landing should thump even when it
  deals no damage because obstacle-hop is part of its identity.
- Camouflage: when the idle timer crosses 3 s, remove gait motion entirely,
  reduce breathing, and let eyes/outline be the readable cue.
- Acceptance read: a player should be able to tell "this frog is coiled and
  dangerous" before it presses Q.

### Cane Toad

Make the toad feel toxic and grounded, not like a smaller bullfrog.

- Movement profile: lower hop height, longer body contact, higher friction, less
  visual forward bob than Bullfrog.
- Poison stream: while firing, preserve aim responsiveness but add tiny backward
  recoil and foot-plant visuals. Sim movement can stay normal until tuning says
  otherwise.
- Thanatosis: hard zero movement, but keep aim/primary/Q readable. Use a belly
  flatten, still legs, and wider poison gland silhouette.
- Toxic Skin / Bufotoxin: contact retaliation should read as "touching this body
  was the mistake"; add a brief skin flash from contact side.
- Risk: the toad's listed speed is 1.5, faster than Bullfrog's 1.2. The feel
  profile should still make it visually squat by using shorter steps, not by
  secretly nerfing speed.

### Crayfish

Crayfish should be the first proof that "movement profile" affects combat, not
just cosmetics.

- Movement profile: brisk lateral/diagonal scuttle, sharper backward response
  than forward response, quick decel after short inputs.
- Caridoid Escape: backward dash should begin with a one- or two-frame tail curl
  visual and then a hard reverse burst. It should call the same latch-break /
  forced-move hooks as other displacement.
- Meral Display: keep forward/back only as planned, but make turn rate visibly
  slower; claws-up stance should widen the silhouette and reduce side-slip.
- Primary: alternate claw strike should bias the body slightly toward the active
  claw so footwork and attacks feel linked.
- Acceptance read: when a player overcommits into a crayfish face, the backward
  snap should feel earned, not like a generic dodge roll.

### Water Shrew

This is the high-skill micro-movement test. Its authenticity comes from surface
skimming and extreme reaction, not raw invisibility or bigger numbers.

- Movement profile: very high accel/decel, tiny turn radius, high gait frequency.
  Avoid slow easing; the creature is small enough to be twitchy.
- Water Walk: while Q is active and input is nonzero, set a `surface_walk`
  terrain override: no drowning tick, water speed bonus, shallow wake/bubble
  trail. On zero input, drop into normal water immediately.
- Visual read: render tiny alternating foot taps on the water surface and a
  dotted bubble trail. In deep water without Q, switch to low dark body with
  bubble-sniff pulses.
- Bite: micro-lunge at contact, no long recovery flourish. The debuff stacks
  should be shown by tiny "nicks" or chill marks on the victim rather than a huge
  aura.
- Risk: tiny radius plus speed can become unreadable. Use contrast in wake,
  shadow, and hit flash rather than increasing footprint.

## Landing Order

```text
Wave 1 movement work
├─ 1. Shared `movement_feel.gd` profile table, no JSON schema change
├─ 2. `creature.gd` acceleration/deceleration/turn application
├─ 3. Render-only gait params passed into `VisualStyle.draw_battle_creature`
├─ 4. Bullfrog + Cane Toad hop variants
├─ 5. Crayfish scuttle + Caridoid Escape tell
└─ 6. Water Shrew water-walk terrain override + wake
```

Do not start with a universal "animal locomotion system." Start with Wave 1
profiles hardcoded in one helper, then generalize only once Wave 1 passes 3v3 bot
play. The current code already has useful anchors: `creature.gd` owns movement,
terrain, dash, and render anim params; `visual_style.gd` already has per-body
bases; `EnvironmentProfile` already centralizes water/terrain behavior.

## Source Notes

Natural-history and locomotion sources:

- American Bullfrog, Chesapeake Bay Program field guide: https://www.chesapeakebay.net/discover/field-guide/entry/american-bullfrog
- Cane toad hopping locomotion study, Functional Ecology: https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2435.12414
- Cane toad performance and hydration/temperature, PLOS/PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC5541569/
- Water shrew sensory/attack speed and underwater bubble sniffing, Vanderbilt Catania Lab: https://as.vanderbilt.edu/catanialab/research/water-shrews/
- Water shrew water-walking overview, Northern Woodlands: https://northernwoodlands.org/outside_story/article/shrew
- Crayfish/caridoid escape hydrodynamics, Scientific Reports: https://www.nature.com/articles/s41598-023-31676-8
- Snake locomotion, Smithsonian National Zoo: https://nationalzoo.si.edu/news/news/how-do-snakes-move-without-legs
- Alligator locomotion, National Wildlife Federation: https://www.nwf.org/Educational-Resources/Wildlife-Guide/Reptiles/American-Alligator
- Crocodilian locomotion overview, IUCN Crocodile Specialist Group: https://www.iucncsg.org/pages/Locomotion.html
- Salamander/newt walking and swimming gait analog, ScienceDirect/JEB: https://www.sciencedirect.com/science/article/abs/pii/S0944200604000236
- Great Blue Heron, Cornell All About Birds: https://www.allaboutbirds.org/guide/Great_Blue_Heron/overview
- Belted Kingfisher, Cornell All About Birds: https://www.allaboutbirds.org/guide/Belted_Kingfisher/overview
- Belted Kingfisher hover/plunge note, Audubon Field Guide: https://www.audubon.org/field-guide/bird/belted-kingfisher
- Owl silent flight, Audubon: https://www.audubon.org/magazine/silent-flight-of-owls-explained
- Mallard movement categories, Audubon Field Guide: https://www.audubon.org/field-guide/bird/mallard
- Beaver movement and tail/feet functions, Smithsonian National Zoo: https://nationalzoo.si.edu/animals/beaver
- River otter agility/sliding/social play, Smithsonian National Zoo: https://nationalzoo.si.edu/animals/north-american-river-otter
- River otter bounding gait, Washington Department of Fish & Wildlife: https://wdfw.wa.gov/species-habitats/species/lontra-canadensis
- North American mink swimming energetics/body drag, Journal of Experimental Biology: https://journals.biologists.com/jeb/article/103/1/155/4035/Locomotion-in-the-North-American-Mink-A-Semi
- Leech inchworm crawling and undulatory swimming, Australian Museum: https://australian.museum/learn/animals/worms/leeches/
- Mosquito swarming/flight-cue research, Georgia Tech 2026: https://coe.gatech.edu/news/2026/03/why-mosquitoes-swarm-your-head-theyre-following-signals-not-each-other
- Mosquito swarming behavior study, NIH/PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC8755986/
- Firefly behavior/bioluminescence, AMNH: https://www.amnh.org/explore/videos/biodiversity/insectarium-fireflies
- Firefly behavior and artificial light, Frontiers: https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2022.946640/full
- Mountain Chorus Frog seasonal movement, Virginia Herpetological Society: https://www.virginiaherpetologicalsociety.com/amphibians/frogsandtoads/mountain-chorus-frog/index.php

Game-feel and top-down movement sources:

- Steve Swink, *Game Feel*: https://gamifique.files.wordpress.com/2011/11/2-game-feel.pdf
- GDevelop top-down movement behavior docs: https://wiki.gdevelop.io/gdevelop5/behaviors/topdown/
- GDQuest Godot top-down movement tutorial: https://www.gdquest.com/tutorial/godot/2d/top-down-movement/
- Game Developer, "Game Feel Tips II: Speed, Gravity, Friction": https://www.gamedeveloper.com/design/game-feel-tips-ii-speed-gravity-friction
- Game Developer, "Game Feel Tips III: More On Smooth Movement": https://www.gamedeveloper.com/design/game-feel-tips-iii-more-on-smooth-movement
