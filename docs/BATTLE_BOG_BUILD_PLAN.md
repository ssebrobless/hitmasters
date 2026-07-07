# Battle Bog Build Plan (hardened, to completion)

Authority order when documents disagree:
`BATTLE_BOG_DECISIONS.md` > this plan > `BATTLE_BOG_SYSTEMS.md` / `BATTLE_BOG_ROSTER.md` > source notes.
All numeric kit/stat values come from `data/battle_bog_roster.json` — never hardcode
a creature number in a script.

Conversion constants (from decisions #3 and #32): `UNIT_PX = 16.0`,
`SPEED_PX_PER_SEC = 91.0` (speed 1.0). Define once in
`scripts/sim/sim_constants.gd`; everything imports them.

Target directory layout (created incrementally):

```text
scripts/
  sim/            deterministic gameplay — NO Input.*, NO randomness without seeded RNG
    sim_constants.gd     unit/speed conversion, tick rate
    input_frame.gd       InputFrame resource: move Vector2, aim Vector2 (world), buttons bitmask
    creature.gd          generic creature controller (replaces player.gd logic)
    creature_state.gd    state enum + transition rules (normal/latched/airborne/perched/burrowed/mounted/stance/defending)
    terrain_map.gd       zone lookup: land/shallow/water/cover/habitat/hut per world point
    damage_event.gd      {amount, delivery: MELEE|RANGED|AREA, plane: GROUND|AIR, source_actor, source_ability}
    abilities/           one primitive per file (see M2)
    kits/                per-creature kit scripts wiring primitives to roster data
  ai/
    bot_brain.gd         shared engage/kite/retreat/objective logic
    bot_kit_hooks/       per-creature bot hook (when to use Q/E/R/Space)
  game/                  match orchestration (arena, huts, habitat, economy)
  ui/                    menus, select, HUD
  visual/                visual_style.gd silhouettes
```

Standing rules (every milestone):
1. Every creature ships WITH its bot hook or it does not ship.
2. `grep -r "Input\." scripts/sim scripts/game/kits` must return nothing; only
   `scripts/ui` and one human-input reader may touch Input.
3. Gameplay math runs in `_physics_process` at the default 60 Hz tick; `_process`
   is for rendering/UI only.
4. All RNG in sim code goes through one seeded `RandomNumberGenerator` owned by
   the match (for the 9% Unswattable miss etc.).
5. The game must launch and play 3v3 vs bots at the end of every milestone.
6. `data/battle_bog_roster.json` is design-owned: code reads it; refactors never
   rewrite it. Schema additions require a note in BATTLE_BOG_DECISIONS.md.
7. Information systems obey decisions #35-#36: minimap, AI targeting, terrain
   clues, and future objective UI must distinguish visible/revealed/heard/
   last-known/hidden state instead of adding new omniscient shortcuts.

---

## M0 — Foundation

Tasks:
- `project.godot`: add input actions `move_up/down/left/right`, `primary`,
  `ability_q`, `ability_e`, `hut_defend` (F), `habitat_deposit` (U),
  `context_action` (R), `flight_toggle` (Space).
- `scripts/sim/sim_constants.gd`, `input_frame.gd`, `damage_event.gd`.
- `scripts/data/creature_catalog.gd`: load + validate `battle_bog_roster.json`
  (push_error on missing id/stats/footprint/diet), expose `get_creature(id)`,
  `get_all()`, unit-conversion helpers. Register as autoload `CreatureCatalog`.
- Character select: list all 21 creatures grouped by family from the catalog;
  the 6 slice creatures selectable, the rest greyed with "coming soon".
  `GameConfig.selected_hero_id` becomes `selected_creature_id` (keep old field
  as alias until M2 removes the old heroes path).
- Human input reader (`scripts/ui/local_input.gd`) producing an InputFrame each
  tick; player-side code consumes only InputFrame.

Acceptance:
- Old Hitmasters demo still playable from menu.
- Select screen shows 21 creatures, 6 pickable; picking one is remembered.
- Catalog validation errors surface for a deliberately broken JSON copy (test
  manually, then revert).

## M1 — Animal controller + terrain

Tasks:
- `terrain_map.gd`: arena defined as zone polygons/rects in one data structure;
  zones: LAND, SHALLOW, WATER, COVER, HABITAT_BLUE, HABITAT_RED. Mirrored
  layout: habitat plots in each corner-back area with the team core placed
  inside the plot (decision #5); a central water channel + two shallow bogs.
- `creature.gd`: reads catalog stats; movement modes ground/swim/flight/
  always-fly from `movement` tags; swim timer with HUD pip; +15% water speed
  for (semi)aquatics; ramping wrong-terrain DOT 2%/s→5%/s after 3 s
  (decision #4); flight meter drain, depletion grounding + 3 s no-takeoff.
- `creature_state.gd` state machine with stubs for latch/perch/burrow/mount/
  stance/defending (implemented per-kit later).
- Camera zoom retuned for 16 px scale; arena dimensions re-derived in units
  (target ~80×45 units for 3v3, ~55×30 for 1v1).
- Cores relocated into habitat plots; minions/bots/projectiles keep working
  (they may temporarily keep old pixel constants).

Acceptance:
- A catalog-stat creature (no abilities yet) walks, swims with timer, takes
  ramping drown damage, and a `movement: land_walker` creature takes DOT in
  water while a semi-aquatic gains 15% speed.
- Fly-capable test creature takes off (hold Space + move 2 units), drains
  meter, is grounded 3 s on depletion.

## M2 — Ability primitives + first three creatures (FUN GATE)

Tasks:
- `scripts/sim/abilities/`: `melee_hit.gd` (arc/box, optional windup telegraph),
  `dash.gd`, `projectile.gd` (reuse/port existing), `aura.gd` (ally buff /
  enemy debuff, timed), `latch.gd` (struggle model per decision #2: victim
  moves slowed + acts; ends on release/timeout/victim displacement/ally
  knockback; drag direction by base-HP comparison), `cooldown.gd` +
  `charges.gd` helpers.
- Kits: `snapping_turtle.gd` (0.7 s windup bite 100, Grab reach+pull,
  Lingual Lure stun aura, 15% DR passive), `chorus_frog.gd` (tongue poke,
  Comb Call ally aura, Cree enemy aura), `mink.gd` (bite, Choke dash-latch
  with 10 s kill countdown, Scent Marking dual aura, Fearless passive).
- Delete the old hard-coded `match hero_id` paths from player.gd; player is now
  a Creature driven by InputFrame. Remove hero-swap hotkeys.
- `bot_brain.gd` v1 + hooks for the three kits; 3v3 = you + 2 bots vs 3 bots,
  drafted from available kits.
- HUD: Q/E cooldowns + charges, swim/flight meter, latch indicator.

Acceptance (fun gate — do not proceed until this holds):
- Full 3v3 vs bots match with these three creatures ends by core destruction
  and is fun for a 5-minute session. Latch feels like a struggle, not a stun:
  a latched victim can walk to allies and a dash breaks Choke.
- Kill-heal (5% max HP over 2 s) triggers for carnivores/omnivores on kills.

## M3 — Complete the six-creature slice

Tasks:
- New primitives: `placeable.gd` (Beaver dams: 200 HP walls, max 3, R rotate,
  block ground attacks + bodies), `pet.gd` (follower AI with owner-relative
  leash), `flight` states finished (takeoff/land/perch), `stealth.gd`
  (camouflage/silent-flight pattern: break on act/damage).
- Kits: `beaver.gd` (Tail Slap DR aura + dam repair, Dam placeable, Gnawing on
  tree props), `owl.gd` (peck/swoop with 0.7 s low counter-hit window where
  plane becomes GROUND, Silent Flight, Auditory Mapping reveal, Perch),
  `duck.gd` (3-hit chain, Nesting egg→duckling pets, Mobbing buff, Paddling).
- Damage-plane rules live: airborne creatures immune to GROUND+MELEE only;
  swoop/peck impact windows flip the bird to GROUND plane briefly.
- Tree/cover props on the terrain map (Beaver Gnawing + Owl perch targets).
- Bot hooks + silhouettes for all six.

Acceptance:
- Any 3v3 comp of the six plays without errors; dams block minions and
  projectiles tagged ground; owl in flight is immune to turtle bite but not to
  chorus frog tongue... (ranged) and is hittable during swoop impact.
- Duck bots manage ducklings without runaway node counts (hard cap enforced).

## M4 — Mud huts and lanes

Tasks:
- `scripts/game/mud_hut.gd`: hut entity with HP, team, lane id; data-driven
  hut placement list sized for 4/side but populated with 2/side (3v3) and
  1/side (1v1) per decision #9.
- Lane minions: spawn from each hut on the wave timer, march toward the
  opposing hut on their lane, retarget enemies in range (port minion.gd).
- Hut defender squad: 1 tanky + 2 melee + 2 ranged pebble minions per hut,
  respawn 5 s after death, leashed to the hut.
- Vulnerability gating: habitat plot (and core within) only damageable after
  that side's huts on at least one adjacent lane are destroyed.
- `F` defend assignment stubbed behind `has_reserve_stocks >= 3` (constant
  true-with-warning until M5 gives real stocks).
- Old single-lane core wave removed.

Acceptance:
- Destroying a lane's hut opens the habitat to damage on that side; bots
  respond to hut pressure (defend/push heuristics in bot_brain).
- 40-ish concurrent minions hold 60 fps on the dev machine.

## M5 — Habitat economy (stocks, food, hunger)

Tasks:
- `scripts/game/stock_manager.gd`: per player 1 fielded + 2 reserve stocks of
  their creature (decision #6); reserves rendered idling inside the habitat
  plot; death = control moves to a reserve (respawn delay); team defeat when a
  dead player has no reserves. Core HP removed as win condition; the core
  becomes the habitat centerpiece prop (or is deleted — keep whichever reads
  better in playtest).
- Hunger: bar per fielded creature, 105 s full-to-empty (mid of decision #7
  range), lethal at 0, pulsing warning under 25%; satiation cap stops drain.
- Food: wildlife/flora spawn points on the terrain map (small neutral critters
  + plants honoring diet tags: herbivores can't eat critters, carnivores can't
  eat plants; omnivores both); eating heals slightly + fills hunger.
- `U` at habitat: deposit satiated animal (starts breeding, M6) or swap stock.
- `F` at hut now uses real stock counts (needs ≥3 in habitat; max 2 defenders).
- HUD: hunger bar, stock count, team stock summary.

Acceptance:
- Matches end by stock elimination; a starved creature dies and consumes a
  stock; hunger pauses at satiation cap; diet restrictions enforced.

## M6 — Breeding + per-family buffs

Tasks:
- Deposited satiated animal breeds after a visible 45 s timer at the habitat
  (decision #18); on completion, team gains a family buff stack (decision #8):
  Amphibian +3% regen, Reptile +3% max HP, Bird +3% move speed, Mammal +3%
  damage, Crawly +3% ability haste. Cap 6/team, max 3/family. One satiated
  animal per type per team in habitat.
- Breeding is interruptible: enemies inside an opened habitat can kill the
  breeding animal (this is the raid incentive).
- HUD: team buff stack icons; enemy stacks visible on scoreboard.

Acceptance:
- Deposit → 45 s → stack appears and measurably changes stats; killing the
  breeding animal during the window denies it; caps enforced.

## M7 — Roster waves

Ship 3–5 creatures per wave, each with kit + bot hook + silhouette, in
primitive-risk order:
1. Bullfrog, Cane Toad, Crayfish, Water Shrew — existing primitives only
   (stealth-leap, poison stream/thorns, stance, stacking debuff bite).
2. Water Snake, Alligator, Newt, Heron, Kingfisher — latch variants (drag by
   base-HP, Death Roll water check), reflect/invuln windows, flight variants
   (wading, hover, burrow).
3. Wolf Spider, Firefly, Mosquito Swarm — burrow network, mines,
   always-flying pair, trail AOE, blood-meter Deposit (second resource meter;
   HUD meter widget from M5 must be reusable).
4. Otter (pack-of-3 control swap), Bog Turtle (mounting + shared damage),
   Leech (body-count-as-HP/ammo) — the three exotic controllers, last.

Acceptance per wave: all shipped creatures playable AND bot-pilotable in 3v3;
no regression in the M2/M3 six (quick pass each wave).

## M8 — Competitive polish

- 1v1 final tuning is live on the unified expanded map: one hut per side, two
  minions per hut wave, 18s waves, 90s hunger pace, and mode tuning logged in
  match summaries.
- Draft/ban stub and match summary telemetry are live for ranked-feel review:
  stocks lost, deposits, hut damage, core damage, balance deltas, review
  priority, and compact scoreboard review lines.
- Sprite passes remain the art-side follow-up for creatures whose kits survived
  M7 unchanged; 16 px sheets, states: idle/move/attack/special per creature.
- Balance sweep is driven by family-buff, stock, mode-tuning, and review
  telemetry printed to per-match log files.

Complete = M8 done: full loop 1v1 and 3v3 vs bots, all 21 creatures, stocks/
food/breeding/huts live, local only. Online is Phase 5, enabled by the M0
InputFrame + fixed-tick discipline, and is out of scope for this plan.

## Standing risks

- Latch feel (M2) and flight feel (M3) are make-or-break; budget tuning time.
- Determinism erodes silently: re-run the Input.* grep at every milestone.
- Pet/minion node counts (duck, spider, leech, mosquito visuals): enforce hard
  caps in every summon primitive from day one.
