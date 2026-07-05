# Research: Combat Depth — Authored Hurtboxes, Frame Data, Movement

Compiled 2026-07-04 (subagent research + codebase verification). Governs the
combat-depth track. Decisions #21–#30 in BATTLE_BOG_DECISIONS.md were ratified
from this report; where this doc and the decisions table disagree, the table wins.

## Part 1 — Research findings (each with the Battle Bog implication)

1. **Fighting-game frame data (startup/active/recovery) is the core depth
   engine.** Depth comes from asymmetry: startup and recovery are vulnerability
   you buy for the active window. Frame advantage decides who moves first after
   an exchange; multi-tick active windows enable "meaty" timing.
   *Battle Bog:* today there is windup (turtle only) and **zero recovery
   anywhere** — every whiff is free. Recovery is the single highest-value
   addition; #14/#15 already demand punishable whiffs.
2. **Hitstop serves gameplay, not just juice.** Sakurai: hitstop weight scales
   with move power and gives both players a confirm/react beat.
   *Battle Bog:* 3-frame render-only freeze on ≥50 dmg (decision #26); render-only
   protects determinism.
3. **Counter-hits reward interruption.** Bonus effect for hitting an opponent
   during their startup makes whiff-baiting a skill.
   *Battle Bog:* +20% + distinct flash when victim `attack_phase == STARTUP`
   (decision #25) makes Alligator/Heron slow bites readable duels.
4. **Smash disjoints: hitbox/hurtbox separation is authored feel, not anatomy.**
   Boxes that whiff visually get shrunk; disjointed weapons can't be traded with.
   *Battle Bog:* Frog tongue and Heron beak are our disjoints — a tongue must be
   able to hit a snake's body without the frog's own hull being in range. Chunky
   capsules + a few circles, never per-pixel.
5. **Monster Hunter hitzones: part multipliers create positioning gameplay, not
   sniping.** Parts are huge, values knowable, and they change with state (rage,
   wounds). Skill is positioning around a moving body.
   *Battle Bog:* exactly the model for capped 0.75–1.35 regions with state-gated
   openings (decision #22). State-gating is what makes it a timing game.
6. **Battlerite: everything is a skillshot; move-while-casting with per-ability
   multipliers; i-frames are explicit tools.**
   *Battle Bog:* per-phase `move_mult` (slower in startup, near-zero in recovery)
   delivers the feel without rooting.
7. **Nidhogg/Samurai Gunn: whiff cost + spacing IS the game.**
   *Battle Bog:* with ~6 kits live we can afford real whiff cost now; it gets
   harder to retrofit after all 21 ship.
8. **LoL/Dota body collision.** LoL units always attempt not to overlap;
   "ghosting" is an explicit power. Dota adds finite turn rate, making body
   orientation and flanking real.
   *Battle Bog:* (a) pairwise soft separation (decision #27); (b) capped turn
   rate for capsule bodies (decision #28) so "get behind the gator's jaws" is a
   real maneuver.
9. **Separation implementation.** Pairwise minimum-translation push-apart,
   symmetric halves, capped per-frame. Do it manually in the sim (deterministic,
   ordered iteration), never via physics bodies.

## Part 2 — Codebase reality check (verified 2026-07-04, HEAD 41b5571)

1. Combat is flat circles: `hit_shape.gd` melee arc = distance-to-center vs
   `radius + body_radius` + facing dot ≥ 0.15; `arena.gd:833` projectile hits =
   circle vs `body_radius`.
2. **Capsule footprints silently collapsed** — `creature.gd:_footprint_radius_px()`
   (~line 751) reads only `radius_units`. Alligator = 14.4 px circle despite
   `capsule 0.9×3.0` (48 px) in the roster; Water Snake = 6.4 px. The hull fixes
   creatures that are ~3x smaller than designed.
3. **No creature-vs-creature collision exists.** `arena.resolve_body_position()`
   (~1024) clamps to arena rect + cover rects only; zero `CollisionShape2D` in
   `scripts/`; creatures freely stack.
4. Frame data is ad hoc: turtle kit-local `primary_windup_remaining` lands
   regardless of stuns; frog tongue is 0-startup hitscan; **no recovery state
   exists**; `can_act()` is a modifier check only.
5. Attack anim is cosmetically decoupled from the hit (`creature.gd:268`
   `anim_attack_duration = interval * 0.55` plays after damage resolved). Frame
   data must make the animation the contract (pose = phase).
6. **Damage taxonomy leak** (violates #1's spirit): `creature.take_damage()`
   (~166) fabricates MELEE/GROUND events; `arena.damage_enemies_in_radius()`
   (~876) and wrong-terrain DOT use it — AOE counts as ground melee, so fliers
   dodge AOE and melee-contact passives would mistrigger. Fixed by `AREA`
   delivery (decision #29).
7. Latch has no attach point and leaks kit logic: `_tick_latch` (~612) positions
   by center-offset math and hard-codes `latch_source == "Choke"` for the mink
   execute. Fixed by decision #30.
8. Determinism setup is sound: 60Hz `tick_sim`, no `Input.*` in `scripts/sim`,
   VFX via `emit_vfx_event`. New checks follow the
   `battle_bog_combat_fairness_check.gd` SceneTree pattern.
9. Two projectile paths must both be upgraded: hitscan `projectile.gd
   instant_line` AND traveling projectiles in `arena.resolve_projectile_hits`.

## Part 3 — Phased implementation plan

Ordering: hull first (fixes the capsule bug), frame data before regions
(regions without whiff-punish is cosmetics), collision independent,
readability last.

### Phase A — Hurtbox hull foundation
- New `scripts/sim/combat/hurtbox.gd` (static): hull from footprint — circle or
  capsule (`radius_px`, `half_length_px`, axis = movement heading when velocity
  above threshold, else last aim direction; all sim-state, deterministic).
  Functions: `hull_of(creature)`, `closest_point(hull, from)`,
  `overlaps_circle(hull, center, r)`, `segment_hit(hull, from, to, half_width)
  -> {hit, point, normal}`.
- `creature.gd`: parse `footprint.shape`/`length_units` into
  `body_capsule_half_len_px` (0 for circles); keep `body_radius` as capsule
  radius. Expose `get_hurtbox_hull()`.
- Rewire `hit_shape.gd` overlaps + `arena.resolve_projectile_hits` through the hull.
- Test `battle_bog_hurtbox_check.gd`: circle parity (identical results
  before/after), Alligator hit 2.5u behind center along axis now connects,
  Water Snake perpendicular near-miss, capsule cap closest-point math.

### Phase B — DamageEvent hit metadata
- `damage_event.gd`: add `hit_position`, `hit_normal`, `region := "hull"`,
  `region_mult := 1.0`, `DELIVERY_AREA := 2`; `set_hit(...)` so `setup()` is
  untouched.
- `melee_hit.gd`, `projectile.gd`, `arena.resolve_projectile_hits` populate hit
  point/normal; `hit_landed` VFX payload gains `hit_position`/`region`.
- Route `damage_enemies_in_radius` + wrong-terrain DOT through `DELIVERY_AREA`;
  update `_dodges_event`.
- Tests: extend `battle_bog_target_filter_check.gd` + new
  `battle_bog_damage_meta_check.gd` (metadata populated; AREA neither dodged by
  airborne nor treated as melee contact).

### Phase C — Frame-data discipline (the depth core)
- New `scripts/sim/combat/attack_phase.gd`: per-creature state machine
  IDLE → STARTUP → ACTIVE → RECOVERY, tick-counted. Per-ability fields:
  `startup_sec/active_sec/recovery_sec`, `move_mult_startup/active/recovery`,
  `dash_cancelable`. Data in roster `stats` (e.g. Alligator 0.45/0.15/0.55
  inside the 1.8s interval; Heron 0.30/0.10/0.45; Frog tongue 0.18/0.05/0.30).
- Hit resolution runs each ACTIVE tick (dedupe per swing) — enables meaties.
- `creature.gd`: `attack_phase` + `can_start_ability()` gate (blocked in
  RECOVERY); phase move_mult folded into `_move_from_input`; migrate turtle
  windup + frog tongue; whiff → full recovery; hit → 40% recovery refund (#24).
- Hitstop: `render_hitstop_timer` on attacker+victim from heavy `hit_landed`,
  consumed only in `_process`/`_draw` (~3/60 s freeze of anim phase). Sim untouched.
- Counter-hit (#25): in `take_damage_event`, victim in STARTUP → `amount *= 1.2`
  + `counter_hit` VFX.
- Test `battle_bog_frame_data_check.gd`: exact tick counts, hit only during
  ACTIVE, ability rejected during RECOVERY, whiff recovery > hit recovery,
  seeded runs identical with hitstop on/off.

### Phase D — Authored regions on the hull
- Roster gains per-creature `hurtbox_regions: [{name, offset_units (facing
  space), radius_units, mult, open_when: always|lunge|stunned|low_window|bask}]`.
  Loader rejects mult outside 0.75–1.35 and radius < 0.35u (anti-sniping, #22).
- `hurtbox.region_at(creature, hit_point)` — smallest containing open region
  wins, else hull/1.0; gates via `creature.is_region_open(open_when)`.
- `_modified_incoming_damage` applies `event.region_mult`.
- Prototype pair first: Frog tongue vs Water Snake head region (1.35x leading
  cap); Snapping Turtle shell 0.75x rear 60%, open (1.0x) during its own bite
  STARTUP.
- Latch attach point (#30): `latch.gd` records hit region point; `_tick_latch`
  anchors there; Choke execute moves to `mink.gd` callback (`on_latch_execute`).
- Test `battle_bog_region_check.gd`: turtle rear 0.75x/front 1.0x, snake head
  1.35x only from head side, gate opens during turtle STARTUP, catalog rejects
  mult 2.0.

### Phase E — Movement depth
- Dash momentum bleed: on `dash_timer` expiry move `dash_velocity` into
  `residual_velocity` decaying over 0.2s (12 ticks, fixed per-tick multiplier
  ≈0.68 for determinism), summed into `_move_from_input`. Dash direction stays
  locked during the dash (commitment — keep).
- Turn-rate cap for capsule bodies (#28): clamp per-tick rotation of the body
  axis (Alligator 240°/s, Water Snake 320°/s); aim stays instant; store
  `body_heading`, updated in `tick_sim`.
- Test `battle_bog_movement_check.gd`: dash-end golden positions, gator
  body_heading lags an instant 180° aim flip, airborne unaffected.

### Phase F — Soft body collision
- `arena.resolve_body_separation()` once per physics tick after entity ticks:
  each pair of live grounded non-latch-paired creatures, capsule-aware hull
  overlap (Phase A closest points), push each half the penetration apart,
  capped ~50 px/s, then re-clamp to cover/arena. Array-order iteration —
  deterministic. Airborne exempt; latch pairs exempt; dashing creatures ghost
  through (#27).
- Test `battle_bog_body_collision_check.gd`: overlapped pair separates within
  30 ticks; midpoint invariant; latch pair stays attached; airborne overlaps
  freely; two seeded 600-tick bot runs bit-identical.

### Phase G — Readability grammar for regions
- Regions anchor to the same part offsets `visual_style.gd` draws — extract
  shared part-offset helpers so sim regions and drawing can't drift.
- Open region = subtle pulsing outline on the exposed part (danger-fill
  family, low alpha). Resolved = `hit_landed` spark at `event.hit_position`
  (not target center), intensity scaled by `region_mult`; region hits tint that
  part's flash. Whiff = RECOVERY drives a visible "off-balance" pose.
- Dev overlay: debug draw of hulls + regions (game-side, reads sim state).
- Contract check in `battle_bog_damage_meta_check.gd` that `hit_landed`
  payloads carry `hit_position` + `region`; feel verified by playtest.

Every phase: no `Input.*` in `scripts/sim`, no unseeded RNG (none needed —
all math is state-derived), all timers tick-decremented at 60Hz `tick_sim`.

## Key files

`scripts/sim/combat/hurtbox.gd` (new), `scripts/sim/combat/attack_phase.gd`
(new), `scripts/sim/combat/hit_shape.gd`, `scripts/sim/damage_event.gd`,
`scripts/sim/creature.gd` (~166, ~612–614, ~751), `scripts/game/arena.gd`
(~823, ~876, ~1024), `scripts/sim/abilities/{melee_hit,projectile,dash,latch}.gd`,
`scripts/sim/kits/{snapping_turtle,chorus_frog,mink}.gd`,
`data/battle_bog_roster.json`, `scripts/visual/visual_style.gd`.

Sources: SuperCombo Frame Data wiki; CritPoints frame-data patterns + hitstop;
Sakurai Famitsu col. 490 (hitstop); BlazBlue wiki (counter hit); SmashWiki
(hitbox); Smash Ultimate disjoint analyses; Game8/Kiranico (MH hitzones);
LoL Wiki unit collision; Liquipedia Dota collision size; Battlerite wiki +
Stunlock dev blog 003; Kill Screen (Samurai Gunn); Nidhogg; GDevelop collision
separation docs.
