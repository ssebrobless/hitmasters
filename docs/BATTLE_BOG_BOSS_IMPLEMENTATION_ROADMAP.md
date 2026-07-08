# Battle Bog — Boss & Vision Implementation Roadmap

Status date: 2026-07-07. Derived from `BATTLE_BOG_BOSS_DESIGN.md` (confirmed boss source-of-truth),
`BATTLE_BOG_BOSS_AND_VISION_HANDOFF.md` (vision sequencing), and the two Supervive research docs.

**Authority order:** `BATTLE_BOG_DECISIONS.md` > `BATTLE_BOG_BOSS_DESIGN.md` > `BATTLE_BOG_BOSS_AND_VISION_HANDOFF.md`.
All numeric creature values come from `data/battle_bog_roster.json` (design-owned; code reads, never writes).
Boss tuning data is NOT in the roster — see Open Questions.

Guiding rule (from BOSS_DESIGN): **"Bosses are habitat events first, creatures second, health bars third."**
Every major boss attack: `TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint`.

---

## Dependency order

```
BB-BOSS-1  per-team meter + objective-state contract            [DONE 2026-07-07]
   -> BB-BOSS-2  objective lifecycle state machine + public broadcasts   [DONE 2026-07-07]
   -> BB-BOSS-3  Champsosaurus side-boss actor (scripts/game/bosses/)    [DONE 2026-07-07]
   -> BB-BOSS-4  claim/steal + reward routing + timed terrain-event      [DONE 2026-07-07]
   -> BB-VIS-1   team vision API                 [DONE 2026-07-07] [HARD predecessor of BB-BOSS-5]
   -> BB-VIS-2/3  minimap fog + bot see-only-what-they-see   [DONE 2026-07-08]
   -> BB-VIS-4    world-space enemy masking (deferred)
   -> BB-BOSS-5  Teratornis center boss                    [DONE 2026-07-08]
   -> BB-BOSS-6  shared boss framework + remaining 4 families
   (BB-VIS-4 may follow)
   -> BB-BOSS-5  Teratornis center boss
   -> BB-BOSS-6  shared boss framework + remaining 4 families
```

Standing gates every milestone: full suite `scripts/test/run_all.ps1 -Godot <exe> -KeepGoing -StrictOutput`
green; `grep -rn "Input\." scripts/sim scripts/game/kits` empty (NOTE: gate scope is `scripts/sim`
and `scripts/game/kits` only — arena.gd legitimately uses `Input` for the mouse cursor);
`sha256sum data/battle_bog_roster.json` unchanged; headless boot
`<exe> --headless --path . --quit-after 300` clean. Godot: `C:\Godot\Godot_v4.6-stable_win64_console.exe`.

Run one check: `<exe> --headless --path . --script scripts/test/<name>.gd` (exit 0 = pass; the
"ObjectDB instances leaked" / "N resources still in use" warnings are whitelisted).

---

## Locked source-of-truth decisions

- **Objective-state vocabulary (Decision #37):** `dormant, active, contesting, claimable, claimed, stolen`.
  Ownership earned via contest/claim/interrupt windows, NOT last-hit.
- **Information states (Decision #35) — SIX:** directly-visible, revealed, heard, last-known, **suspected**, hidden.
  (The handoff prompt's 5-state list dropped `suspected`; #35 is the lock.)
- **Match-contained power (Decision #38):** no persistent out-of-match progression / Armory / meta unlocks.
- **Reward channels are SEPARATE (never merged/double-counted):**
  1. capped per-family breeding buffs (#8/#18, `arena._add_breeding_buff_stack`),
  2. temporary deposit breeding-speed boost,
  3. `habitat_stock_boss_buffs[team]` (side/center boss habitat-stock buffs — NEW),
  4. `team_combat_rewards[team]` (center-boss abilities — NEW).
- **Side vs center:** side boss = local, leashed (home zone + nearby lane + middle contest band), soft leash,
  claim = habitat-stock buff + enemy-side terrain disruption, steal = buff only. Center boss = scheduled at
  `elapsed` 600s/1200s, random family, +50% size, map-wide, special COMBAT reward, no directed enemy disruption;
  same family twice upgrades the reward once. Center bosses DO reshape terrain map-wide (both teams) — that is
  distinct from the prohibited directed owner->enemy disruption.
- **Do NOT copy from Supervive:** persistent Armory/Prisma/Relics meta; battle-royale storm/lobby-wipe; exact-GPS
  minimap pulses (use rings/arcs); route-locking terrain disruption; hiding core mechanics behind onboarding;
  traversal tech; death-state layering. **Fog/night must NEVER suppress a boss combat telegraph.**

---

## Target architecture

```
scripts/game/arena.gd            per-team meter [done], lifecycle state machine, event broadcasts,
                                 claim/steal routing, boss-stock buff channel, center schedule, vision service
scripts/game/bosses/             NEW
  boss_actor.gd                    base boss (leash, TEL/HIT/FX/RECOVERY, weakpoints, downed)
  champsosaurus_side_boss.gd       first side boss
  teratornis_center_boss.gd        first center boss
  boss_catalog.gd                  const tables: families, habitat-stock buffs, center rewards, attack specs
scripts/sim/terrain_map.gd       (later) boss-zone/lane/mid-band accessors; timed terrain-event overlay
scripts/sim/vision/vision_state.gd (later) per-team info-state store (or inline on arena)
scripts/ui/minimap.gd            (later) view_team, vision gating, ghosts/pulses, boss broadcasts
scripts/ai/bot_brain.gd          (later) vision-gated targeting + investigate intent
```

Boss "body" today = a `WildlifeEncounter` occupant (passive prop, 209 lines, team=-1,
`is_scored_actor()==false`, `is_wildlife_encounter()==true`). Do NOT bloat it into a boss framework —
spawn a dedicated `boss_actor` from `_spawn_wildlife_for_zone` when the zone's family is implemented.
`target_filter.gd` rejects `is_wildlife_encounter()` — a real boss must NOT report that flag (use `is_boss_actor()`).

Reusable arena seams (verified line numbers as of af8c9d7-based tree):
`add_line_telegraph` (1571), `add_circle_telegraph` (1582), `_draw_telegraphs` (2009),
`record_vfx_event` (1594) / `_spawn_vfx_for_event` (2075), `damage_enemies_in_radius(source_team,center,radius,damage,source_actor,source_ability)` (1672, builds a `DELIVERY_AREA` DamageEvent),
`elapsed` (94, `elapsed += delta` at 228), `has_line_of_sight(from,to,radius)` (1950) / `cover_blocks_point` (1953),
`get_day_state()` (1456, food-counter only — needs a light phase added in BB-VIS-1),
`add_kill_feed(text)`, `register_entity`/`unregister_entity` (1520/1528), `_tick_animal_zones` (950, computes live `contested`/`control_team`).

Zone lifecycle (per boss zone dict in `animal_zone_states`): activated -> `active=true`, occupant spawned;
`on_wildlife_defeated` (883) empties `alive_occupants` and sets `active=false` + `cleared_team` on clear (907-909).
Terrain boss zones are ellipses: blue center (-48,18)u / red (+48,18)u, radius (35,28)u, inner water (8,5)u;
"middle contest band" = central band around `objective_position=ZERO`, `objective_radius=9u`, land bridges at y=±48.

---

## BB-BOSS-1 — Per-team meter + objective-state contract  [DONE 2026-07-07]

As-built in `scripts/game/arena.gd`:
- `const SIDE_BOSS_ORDER := ["champsosaurus","platyhystrix","american_mastodon","arthropleura","teratornis"]`.
- `var side_boss_meter/side_boss_activations/side_boss_index := {BLUE:0, RED:0}` (reset in `_setup_animal_zones`).
- `bred_animal_count`/`boss_activation_count` kept as informational lifetime totals.
- `_record_bred_animal(team, _actor=null)`: increments team meter unless `_team_has_active_side_boss(team)` (freeze);
  at `>= BOSS_BREED_INTERVAL` calls `_activate_side_boss_for_team(team)`. Caller `_complete_breeding_cue` passes `team`.
- `_team_side_string(team)` -> "blue"/"red"; `_team_has_active_side_boss(team)`.
- `_activate_side_boss_for_team(team)` (replaced `_activate_boss_zones`): activates only that side's boss zone,
  advances that team's family index, stamps `zone["boss_family"]`.
- `get_side_boss_state(team)` -> `{team, meter, interval, activations, next_family, active}`;
  `get_boss_progress_state()` gained a `"teams"` key `{0:..., 1:...}` (legacy keys retained).

Tests: `battle_bog_boss_side_meter_check.gd`, `battle_bog_boss_meter_freeze_check.gd`,
`battle_bog_boss_order_check.gd` (all NEW); retargeted `battle_bog_m6_animal_zone_check.gd`,
`battle_bog_m6_breeding_buff_check.gd`, `battle_bog_m6_breeding_interrupt_check.gd`.
Verified: full suite 48 PASS/0 FAIL, roster unchanged, boot clean.

**DoD met:** per-team meter drives activation; only the breeding team's zone activates; freeze holds & auto-resumes;
family order wraps; per-team accessor readable.

---

## BB-BOSS-2 — Objective lifecycle state machine + public broadcasts

**Goal:** give each side-boss zone the Decision-#37 lifecycle and readable public transitions, still using the
existing `WildlifeEncounter` occupant as the placeholder body. No new actor.

**Files:** `scripts/game/arena.gd`; `scripts/ui/minimap.gd` (objective layer only); optionally a small HUD accessor.

**Steps:**
1. Add `zone["objective_state"]` with values `dormant|waking|active|claimable|contesting|claimed|stolen`.
   Initialize `dormant` in `_setup_animal_zones` for boss zones.
2. Add `_set_objective_state(zone_index, state)` that sets the field AND emits `add_kill_feed(...)` with public
   text (e.g. "Blue boss awakens: Champsosaurus", "Champsosaurus downed — claimable", "Red steals Champsosaurus").
3. Transitions: `_activate_side_boss_for_team` sets `waking`->`active`; `on_wildlife_defeated` boss-clear path sets
   `active`->`claimable`. (Full claim/steal resolution lands in BB-BOSS-4; for now `claimable` may immediately fall
   to `dormant` after a short window, or stay `claimable` until BB-BOSS-4 — keep it simple and tested.)
4. Extend `get_side_boss_state(team)` to include `objective_state`.
5. Minimap: extend `animal_zone_minimap_state` (minimap.gd ~L158-178, currently returns blank for boss zones) to
   surface `objective_state` as a COARSE PUBLIC broadcast (allowed by Decision #36 — objective info is public).
   Keep it a coarse marker, not exact enemy positions.

**Tests:** `battle_bog_boss_objective_state_check.gd` (drive dormant->waking->active->claimable, assert accessor +
that the minimap boss state reflects it).

**Validation:** new check + `run_all.ps1`. **Risks:** keep objective broadcasts public/global (do NOT gate through
vision); ride the throttled `_draw()` chain, no per-frame `queue_redraw`.

**DoD:** each side boss exposes a readable lifecycle; transitions announce via kill-feed + coarse minimap;
`get_side_boss_state(team).objective_state` is correct across a full cycle.

---

## BB-BOSS-3 — Champsosaurus side-boss actor prototype

**Goal:** replace the passive occupant with a real leashed attacking boss. Proves terrain interaction, leashing,
weakpoint recovery.

**Files:** NEW `scripts/game/bosses/boss_actor.gd`, `champsosaurus_side_boss.gd`, `boss_catalog.gd`;
`scripts/game/arena.gd` (spawn seam in `_spawn_wildlife_for_zone`); `scripts/sim/terrain_map.gd` (leash accessors).

**Steps:**
1. `boss_actor.gd extends Node2D`: fields `team_owner`, `home_zone_id`, `leash_regions`, `hp`, `weakpoints`,
   `attack_queue`, `phase` (`IDLE/TEL/HIT/FX/RECOVERY`); `_physics_process` runs AI at 60 Hz, **no `Input.*`**;
   `is_scored_actor()->false`, `is_boss_actor()->true` (NOT `is_wildlife_encounter`). Helpers `_start_attack(spec)`,
   `_advance_phase(delta)`, `_open_weakpoints(part_ids)`.
2. TEL uses `arena.add_line_telegraph` / `add_circle_telegraph`; HIT uses `arena.damage_enemies_in_radius(team,...)`;
   FX afterstate uses `arena.record_vfx_event({...})` + a timed hazard entry.
3. `boss_catalog.gd`: const tables transcribing BOSS_DESIGN (habitat-stock buffs, center rewards, Champsosaurus
   attack specs). Champsosaurus attacks: `Jaw Gate` (V bubble-line TEL -> bite HIT + pull -> churned-shallow FX ->
   jaw/neck weakpoint), `Tail Current` (arc TEL -> push/pull HIT -> current-lane FX -> tail weakpoint), `Flood Scar`
   as a TIMED terrain-event overlay (not mutation).
4. `terrain_map.gd`: `get_team_boss_zone(team)`, `get_boss_leash_regions(team)` (zone ellipse + inner water + middle band).
5. `arena._spawn_wildlife_for_zone`: when `zone.boss` and family implemented, spawn `boss_actor` instead of
   `WildlifeEncounter`; route defeat to a boss-aware path mirroring the zone bookkeeping in `on_wildlife_defeated`.

**Tests:** `battle_bog_boss_champsosaurus_spawn_check.gd`, `_leash_check.gd`, `_attack_check.gd`
(assert TEL->HIT->FX->RECOVERY sequence + weakpoint open in RECOVERY).

**Risks:** soft leash (pull-back, not wall); consistent `z_index`; boss must be a valid damage target.

**DoD:** Champsosaurus spawns in the owning zone, fights within leash, retreats on over-leash with weakpoint
exposure, runs the attack grammar, reaches a downed state.

---

## BB-BOSS-4 — Claim / steal + reward routing + terrain-event hook

**Goal:** replace last-hit reward with a contested claim window; route owner vs enemy rewards; add the separate
boss-stock buff channel and a timed terrain-event.

**Files:** `scripts/game/arena.gd`, `boss_catalog.gd`, optionally `scripts/game/stock_manager.gd`,
`scripts/sim/creature.gd` (consume boss-stock buff).

**Steps:**
1. Boss downed -> `objective_state=claimable`; `_tick_boss_claim(delta)` advances `claim_progress` for the team in
   control (reuse `_tick_animal_zones` `control_team`/`contested`); contested -> `contesting`; completion ->
   `claimed` (owner) or `stolen` (enemy).
2. REPLACE the last-hit `zone["cleared_team"]=defeat_team` (arena L907) and the boss branch of
   `_grant_wildlife_reward` (L924) with claim-resolved routing.
3. `_grant_boss_reward(team, family, is_owner)`: always add `team_boss_stock_buffs[team]` (from
   `boss_catalog.FAMILY_BUFFS`); if `is_owner`, push an `active_terrain_events` entry on the enemy side.
4. New getter `get_team_boss_stock_effect(team, effect)`, consumed in `creature.gd` stat scaling ALONGSIDE
   `_team_breeding_effects` (never merged; do NOT touch the capped `_add_breeding_buff_stack` path).

**Tests:** `battle_bog_boss_claim_steal_check.gd`, `battle_bog_boss_reward_routing_check.gd`
(own-claim = buff + disruption; enemy-steal = buff only), `battle_bog_boss_terrain_event_check.gd`.

**Risks:** anti-snowball (cap boss-stock stacks; decay/death-loss for Arthropleura later); terrain event must
inconvenience/reroute/reveal, not route-lock; timed overlay, not mutation.

**DoD:** downed boss claimed via contestable window (not last-hit); rewards route correctly and stay separate from
family buffs; enemy-side terrain event fires on owner claim only.

**[DONE 2026-07-07]** New `scripts/game/bosses/boss_catalog.gd` (FAMILY_BUFFS + FAMILY_TERRAIN_EVENTS transcribed
from BOSS_DESIGN). arena.gd: `_advance_boss_claim`/`_resolve_boss_claim` run a presence-based contest window
(claimable->contesting->claimed|stolen; reuses `_tick_animal_zones` control/contested, now counted for downed
boss zones too; seizing restarts progress, no last-hit); `_grant_boss_reward(team, family, is_owner)` adds a
capped boss-stock stack (`BOSS_STOCK_TEAM_CAP=8`) and, owner-only, spawns an enemy-side timed terrain event
(`active_terrain_events`, ticked/expired each frame). Getters: `get_team_boss_stock_effect/summary`,
`get_active_terrain_events`; `get_side_boss_state` now carries claim_progress/ratio/team/claimed_team. creature.gd
consumes the boss channel via `_team_buff_bonus/_multiplier` (breeding + boss-stock summed at the stat site only;
the capped breeding stack path is untouched). Review finding #2 fixed: new `damage_creatures_in_radius` (scored
creatures only, never cores/huts/dams/breeding actors); Champsosaurus bite switched to it. Tests: the 3 named
checks (all `failures=0`); full suite 55 PASS; live smoke PASS.

---

## BB-VIS-1 — Team vision API  (HARD predecessor of BB-BOSS-5)

**Goal:** shared per-team information layer so boss reveal/shadow effects and later minimap/bot work plug into one service.

**Files:** `scripts/game/arena.gd` (+ optional `scripts/sim/vision/vision_state.gd`), `get_day_state`.

**Steps:**
1. `is_entity_visible_to_team(entity, team) -> bool` and `get_entity_info_state(entity, team) -> String`
   (six states, Decision #35). Consult `has_line_of_sight`, `entity.is_stealthed()`, terrain cover, own-territory
   anchors, day phase.
2. Add a light phase to `get_day_state` (currently food-counter only): day/dusk/night/dawn + vision multipliers
   (~22u/17u/12u). Preserve existing `ecology_check` assertions (`day==1`, `length==120.0`).
3. Per-tick updater: `team_vision[team][entity_id] = {state, last_point, last_seen_frame}`; expose
   `get_visible_enemy_targets(actor)` and `reveal_entity_to_team(entity, team, duration)` (for Teratornis + Sky Scare).
   Last-known ghost fade: 3s day / 5s dusk / 6s night (tuning var).

**Tests:** `battle_bog_vision_world_check.gd`, `battle_bog_day_night_vision_check.gd`.

**Risks:** fog must never hide combat telegraphs (gate positions/identity only); minions LOS-gate via
`get_closest_enemy` while bots don't — decide whether to unify.

**DoD:** API returns correct six-state info per team; reveal hook works; day phases modulate vision; telegraphs stay visible.

**[DONE 2026-07-07]** All in arena.gd (the optional vision_state.gd module was not needed). `get_day_state` gained
`phase` (dawn/day/dusk/night), `vision_range` (220/170/120/200 px), `vision_multiplier`; `get_day_phase`,
`get_vision_range_for_phase`, `_vision_ghost_fade` (3/5/6s) added; the ecology `day==1`/`length==120.0` contract is
preserved. Six-state model (Decision #35): `get_entity_info_state(entity, team)` returns
visible/revealed/heard/last_known/suspected/hidden with precedence own-team->live-sight->reveal->hearing->ghost
memory->own-territory suspicion->hidden; `is_entity_visible_to_team` = visible|revealed. `_sensory_state_for` uses
per-phase sight range + LOS (stealthed entities are never seen, only heard) and a cover-agnostic hearing band
(sight+120). `reveal_entity_to_team(entity, team, duration)` (timed, for Teratornis/Sky Scare);
`get_visible_enemy_targets(actor)` for unified target queries. `_tick_team_vision` (wired in `_physics_process`)
decays reveals each frame and refreshes last-known records on a 0.1s throttle; `team_vision`/`team_reveals` reset in
`_reset_match_telemetry`. SCOPE: API only -- minions/bots are NOT yet rewired to consume it (that unification is
BB-VIS-3); telegraphs are drawn unconditionally so fog never hides combat cues. Tests: `battle_bog_vision_world_check.gd`,
`battle_bog_day_night_vision_check.gd` (both `failures=0`); full suite 57 PASS.

---

## BB-VIS-2/3/4 — Minimap / bots / world masking (may follow BB-BOSS-5; land API first)

- **Minimap:** add `view_team`; gate the entity loop (minimap.gd L57-63) via `is_entity_visible_to_team`; EXEMPT own
  team/squad (same `_is_visible_entity` L239 is reused for own units at L73); keep huts/cores/food/zone/objective
  overlays global (#36); add last-known ghosts (`with_alpha` + faded symbol) and sound/ripple pulses (`draw_arc`
  rings, not dots). Test: `battle_bog_vision_minimap_check.gd`.
- **Bots:** gate all three `arena.entities` scans (bot_brain.gd L174/254/269) plus `_cached_intent_valid` (L86-94);
  add an INVESTIGATE intent for heard/last_known/suspected navigating to the stored last-known point (not live pos).
- **World masking:** dim/hide off-vision enemy `CanvasItem`s for the local player.

**[BB-VIS-2 + BB-VIS-3 DONE 2026-07-08]** Minimap: `view_team` (auto = player's team); enemy mobile units
(creatures + minions) route through `_is_fog_gated_enemy` -> `_draw_fogged_enemy` (visible/revealed = live pip;
last_known = faded ghost at `arena.get_last_known_point`; heard = ripple ring; suspected/hidden = nothing);
huts/cores/food/zones/objectives + own units stay global. Bots: new `_can_perceive`/`_is_fog_gated_unit` gate all
three `arena.entities` scans (`_target_candidates`, `_closest_enemy_near_point`, `_closest_live_enemy`) plus the
cached-intent revalidation, so a target that slips into fog is dropped; new `_investigate_intent` (mode
"investigate") walks to the stored last-known point for a lost (last_known) or heard enemy. This also unifies the
old split where minions LOS-gated via `get_closest_enemy` but bots did not -- both now use the shared vision API.
New arena getter `get_last_known_point(team, entity)`. DELIBERATE: investigate is checked AFTER objective targeting
(huts/core aren't fog-gated, so bots still push lanes and only investigate when no objective/visible target remains).
Tests: `battle_bog_vision_minimap_check.gd`, `battle_bog_vision_bot_check.gd` (both `failures=0`); full suite 59 PASS.
BB-VIS-4 (world-space `CanvasItem` dimming of off-vision enemies for the local player) still deferred.

---

## BB-BOSS-5 — Teratornis center boss  (requires BB-VIS-1)  [DONE 2026-07-08]

**[DONE 2026-07-08]** New `scripts/game/bosses/teratornis_center_boss.gd` (neutral team -1, +50% size via
SIZE_MULT 1.5, map-wide/no-leash; Grand Hunt Shadow: TEL reveals creatures of BOTH teams in a radius via
`arena.reveal_entity_to_team` -> HIT `damage_creatures_in_radius` dive -> FX -> RECOVERY wings weakpoint x1.6).
arena.gd: `_tick_center_boss_schedule()` (after `elapsed += delta`) fires at `CENTER_BOSS_TIMES = [600, 1200]` with
`center_boss_fired` guards, one-at-a-time via `_center_boss_zone_index()`; `_roll_center_boss_family()` uses the
match-seeded `match_rng`; `_spawn_center_boss(family)` synthesizes a neutral `center` boss zone (unique id
`center:Boss:N`) appended to `animal_zone_states` and spawns the actor through the existing
`_spawn_wildlife_for_zone` (new `center_boss` branch) so defeat reuses `on_wildlife_defeated` -> the BB-BOSS-4 claim
window. `_resolve_boss_claim` branches: a `center_boss` zone has no owner -> always `claimed`, routes to
`_grant_center_reward` (stack 1->2, same family upgrades once, cap `CENTER_BOSS_REWARD_MAX_STACK=2`) and fires NO
directed disruption. boss_catalog.gd `CENTER_REWARDS` + `center_reward`/`center_reward_value`. Getters
`get_center_boss_state`, `get_team_combat_reward_state`. Dev: `debug_spawn_center_boss()` + F10 key + `--bb-center-boss`
flag. Tests: `battle_bog_boss_center_schedule_check.gd` (`failures=0`) + `bb_center_boss_live_smoke.gd`
(RESULT=PASS: grammar runs, reveal fires, defeat->claim). Full suite 60 PASS. NOTE: the combat-reward ABILITIES
themselves (DOT/shield/ambush burst/etc.) are recorded+stacked but not yet wired into combat (deferred, like the
exotic boss-stock keys); the center actor is Teratornis-shaped for all rolled families until BB-BOSS-6 adds per-family
center actors.

**Goal:** scheduled neutral map-wide objective proving reveal / anti-comfort play.

**Files:** NEW `scripts/game/bosses/teratornis_center_boss.gd`; `arena.gd` (schedule), `boss_catalog.gd`.

**Steps:**
1. After `elapsed += delta` (L228): `_tick_center_boss_schedule()` firing at `[600.0, 1200.0]` with `center_boss_fired`
   guards. Random family via the match-owned seeded RNG (BUILD_PLAN rule 4 — verify accessor; if none, add a
   deterministically-seeded `RandomNumberGenerator`).
2. Spawn at `objective_position=ZERO`, +50% size, neutral team, map-wide attacks using the vision reveal hook.
   Resolution -> `team_combat_rewards[team]` (stack 0/1/2; same family twice upgrades once). NO directed disruption.

**Tests:** `battle_bog_boss_center_schedule_check.gd` (fires at 600/1200, random family, +50%, no directed disruption).

**Risks:** use `elapsed` not day timer; deterministic roll; reveal flows through BB-VIS-1.

**DoD:** center bosses spawn on schedule as neutral objectives, +50%, map-wide, grant a combat reward (upgrading on
repeat family), reveal through the vision service.

---

## Reward-ability wiring (BB-BOSS-4/5 follow-up)  [PARTIAL — DONE 2026-07-08]

**[DONE 2026-07-08]** The recorded-but-inert boss rewards now bite in combat. Wired the habitat-stock stat
buffs into creature.gd: `damage_reduction` (`_modified_incoming_damage`), `healing_received` (`heal`),
`hunger_depletion` (`_tick_hunger`), `size` (`_effective_body_radius` at spawn + `refresh_team_breeding_buffs`),
and `vision_range` (arena `get_team_vision_range`, consumed by `_sensory_state_for`). Wired the Teratornis center
reward **Sky Ambush**: a per-creature `undamaged_timer` (ticked in `tick_sim`, reset on real incoming damage);
`modify_outgoing_damage` empowers the next hit by the reward value once the timer passes `AMBUSH_UNDAMAGED_SEC`
(8s), then resets the window. New arena getters `get_team_combat_reward_value`, `get_team_vision_range`; creature
`_team_combat_reward`. Test `battle_bog_boss_reward_wiring_check.gd` (`failures=0`); full suite 61 PASS; both boss
live smokes PASS. STILL DEFERRED (need net-new subsystems, land in/after BB-BOSS-6): Champsosaurus `empowered_dot`
(needs an on-hit-landed hook), Platyhystrix `periodic_shield_slow` (shield-absorb + slow-on-break), American Mastodon
`regen_ramp` (no base out-of-combat regen exists), Arthropleura `kill_growth` (teamwide stacking kill counter + cap);
Champsosaurus `swim_duration` (no swim-stamina system).

---

## BB-BOSS-6 — Shared framework + remaining families

Extract common `boss_actor.gd` framework learned from the two concrete bosses; add Platyhystrix, American Mastodon,
Arthropleura (4 segment bands, not 20 health bars) incrementally with side + center variants and per-family
buffs/rewards/terrain events from `boss_catalog.gd`. Apply anti-snowball caps/decay to teamwide rewards.

**DoD:** all five families spawn as side + center bosses on the shared framework.

---

## Old behavior intentionally replaced

| Current | Replaced by | Milestone |
|---|---|---|
| Global `bred_animal_count` drives boss | Per-team `side_boss_meter` | BB-BOSS-1 [done] |
| `_activate_boss_zones()` activates both mirrored zones | `_activate_side_boss_for_team(team)` | BB-BOSS-1 [done] |
| m6 tests assert both zones from one team's 5 breeds | Per-team assertions | BB-BOSS-1 [done] |
| Last-hit `cleared_team` ownership (L907) | Contested claim window (#37) | BB-BOSS-4 |
| `_grant_wildlife_reward` gives boss killer food (L924) | Claim-resolved team reward routing | BB-BOSS-4 |
| Boss = beefed passive `WildlifeEncounter` | Dedicated `boss_actor.gd` | BB-BOSS-3 |
| Minimap `_is_visible_entity` alive-only (L239) | Per-team vision-gated (own team exempt) | BB-VIS-2 |
| `get_day_state` food-counter only (L1456) | + day/dusk/night light phase | BB-VIS-1 |
| Bots scan raw `arena.entities`, no LOS gate | Vision-gated + investigate intent | BB-VIS-3 |

## Things not to do yet

No full visual/animation boss polish; no true terrain mutation (timed overlay only); no persistent progression;
no center boss before the side-boss contract (BB-BOSS-1..4) AND vision API (BB-VIS-1); no omniscient minimap once
BB-VIS begins (but keep objective/boss broadcasts and own-team units public); do not bloat `wildlife_encounter.gd`;
do not edit `data/battle_bog_roster.json`; do not add `Input.*` under `scripts/sim`/`scripts/game/kits`; do not
revive the dead `_configure_3v3`/`_configure_1v1` paths (they build no zones — boss zones exist only on the unified map).

## Open questions / assumptions

1. **3v3 meter source:** the breed->boss loop is 1v1-only (`_try_manual_habitat_deposit` gated by
   `_is_1v1_trio_mode`). Headless checks drive it directly; a real 3v3 match needs a 3v3 deposit/breed trigger (or
   bot breeding) before side bosses matter in the daily target. Not a first-slice blocker.
2. **Boss tuning data home:** assumption = code-owned const table `boss_catalog.gd`. If JSON design-ownership is
   preferred (like the roster), mirror to `data/battle_bog_bosses.json`.
3. **Center-boss RNG accessor:** verify the match-owned seeded RNG name at BB-BOSS-5; add a seeded RNG if absent.
