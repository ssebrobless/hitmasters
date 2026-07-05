# Full-Roster Implementation Audit & Wave Plan

Compiled 2026-07-04 (subagent audit of `data/battle_bog_roster.json` +
ROSTER/SYSTEMS docs vs code at HEAD 41b5571). Refines BUILD_PLAN M7's 4 waves
into 5. Authority order unchanged: DECISIONS > BUILD_PLAN > this doc.

## 0. Verified existing machinery

- Primitives (`scripts/sim/abilities/`): melee_hit (arc, max_hits, tags, core
  splash), projectile (**hitscan line only** — no traveling projectile in sim;
  legacy `scripts/game/projectile.gd` is portable), dash (breaks latch per #2),
  aura, latch (struggle model, `execute_after`, drag in `creature._tick_latch`),
  cooldown, charges.
- Creature-level: stealth, `open_low_window`, plane-dodge rules, additive
  modifier list (**no per-source stack cap**), `healing_ticks`, diet-gated
  kill-heal (#17 live), swim/flight/wrong-terrain DOT.
- Reusable: `dam.gd` placeable-entity pattern; `pets/duckling.gd` (hard-capped);
  `terrain_map.gd` zone lookup (Death Roll water check possible today);
  `arena.match_rng` seeded (rule 4 OK for the 9% miss); **M5 trio-squad shell**
  (`player_squad` / `_set_active_squad_index` / `_build_squad_ai_frame` +
  `squad_hud.gd`) = the Otter pack reuse target.
- `creature_state.gd` has BURROWED/MOUNTED/STANCE/DEFENDING — **stubs, zero logic**.
- `visual_style.gd` SKINS already covers all 21 creatures — skin work per wave
  is verification + per-kit VFX, not new entries.
- Registration cost per creature: `creature.gd` preload + `_make_kit` arm;
  `bot_brain.gd` const + hooks factory; `game_config.gd` playable list;
  `character_select.gd` un-grey; check script.
- **Not built:** hunger/food/diet economy (no `hunger|blood` in scripts/),
  breeding, second-resource HUD meters, DOT/poison, retaliation hooks,
  knockback impulse, invuln/cleanse, traveling projectiles, AOE fields,
  burrows, mounts, pack control.

## 1. Missing-primitive inventory

| # | Primitive | Shared by | Difficulty | Notes |
|---|---|---|---|---|
| P1 | DOT/stack system (`abilities/dot.gd` + `max_stacks` in add_modifier) | Cane Toad ×3, Newt ×2, Snake bleed, Leech attach, Mosquito AOE, Shrew/Crayfish caps | Medium | Foundation for wave 1; build first. |
| P2 | Melee-retaliation hook in `take_damage_event` (delivery==MELEE only, #1) | Toad Bufotoxin/Toxic Skin, Newt Toxic Secretion/Rib Exudation | Medium | Plus low-HP-threshold trigger variant. |
| P3 | Knockback/forced-move (`abilities/knockback.gd`) | Bullfrog Lunge, Newt Unken, Snake Musking, Otter Tail Whip; fulfills #2 ally-knockback latch break | Medium | Reuse dash velocity fields on victim; must call `break_latch`. |
| P4 | Dash obstacle-hop flag | Bullfrog Leap | Low | |
| P5 | Stance state (STANCE logic: movement constraints, size, DR) + split lock modifiers (move/attack/ability keys) | Crayfish Meral, Shrew root/silence, Toad Thanatosis | Medium | `can_act_mult` currently blocks everything — split it. |
| P6 | Second-resource meter (sim var + generic HUD widget) | Toad ammo, Mosquito blood, Leech bodies | Medium | Build widget in wave 1 (ammo); M5 hunger adopts it later — reverses the plan's reuse direction, unblocking waves 1–3 from M5. |
| P7 | Invuln/untargetable + modifier polarity tags + cleanse + CC-immunity | Newt Unken, Heron Powder Puff, Kingfisher Nest Chamber | Medium | Polarity tagging touches every modifier call site — do once, early wave 2a. |
| P8 | Hold-to-maintain latch + drag movement (attacker-drags vs victim-drags by base HP) | Water Snake, Alligator, Wolf Spider | Med-High | Feel risk (standing risks); tuning time budgeted. |
| P10 | Burrow — single (BURROWED) then network (multi-placeable, enter/exit, ambush charge) | Kingfisher (single), Wolf Spider (network of 4) | Low-Med / High | Single in wave 2a, network in wave 3. |
| P11 | Terrain-profile overrides (water-walk, wading) | Shrew Q, Heron Wading | Low | Modifier flag read in `_update_terrain`. |
| P12 | Traveling projectile (sim-side; straight/lobbed/homing; on-hit payload) | Mosquito, Leech, Firefly, Bog Turtle | Medium | Port legacy game projectile into `scripts/sim/abilities/`; no physics engine. |
| P13 | Placeable generalization (mine/flower/trap) | Firefly Glowworms, Turtle flower, Spider trap-hatch | Low | `dam.gd` proves the pattern; hard caps mandatory. |
| P14 | Ground AOE field entity + trail spawner | Mosquito primary/Q, Firefly field | Medium | Cap live field count (perf risk). |
| P15 | Pass-through movement + contact-damage aura | Mosquito Unswattable | Low-Med | |
| P16 | Pack-of-3 controller (control swap on latch, follower AI, shared life rules) | Otter | High | Extract trio-squad logic from `arena.gd`/`squad_hud.gd` into `pack_controller.gd` usable per squad slot. Blocked on ruling Q2. |
| P17 | Mount/shared damage (MOUNTED, position parent, 95% redirect reduction, drown/flight exemptions) | Bog Turtle | High | Interacts with latch, knockback, carrier death. |
| P18 | Body-count-as-HP/ammo | Leech | High | Overrides HP math; touches every base-HP comparison — blocked on ruling Q1. |
| P19 | Water-body connectivity query (`terrain_map.gd` flood-fill at map build) | Leech Sensory Crypt | Low-Med | |

(P9 folded into P7.)

## 2. Per-creature mapping (condensed; full ability text lives in the roster JSON)

- **Bullfrog** — melee_hit; Leap = dash + stealth-check (+P4); Lunge = dash +
  charges + melee + P3; Swallow = kit execute check (Mink Fearless pattern);
  Camouflage = begin_stealth + idle timer.
- **Cane Toad** — stream via instant_line + P1 + P6 ammo; Toxic Skin/Bufotoxin =
  P2 + P1; Thanatosis = modifiers (move 0, act 1) + range mult.
- **Crayfish** — melee alternation; Q = dash + charges + melee; Meral = P5 +
  body_radius mutation (restore on exit); Molting = modifiers + timer + stack cap.
- **Water Shrew** — melee + victim modifiers (cap 3); Water Walk = P11;
  Proenkephalin = split locks (P5's modifier keys); passive already global.
- **Water Snake** (capsule 0.4×2.5) — P8 hold-latch + P1 bleed; latched DPS = 1%
  max HP/s kit tick; Musking = P3 aura-shaped; Retreat = modifier; Ingestion =
  execute_after + threshold. **Gated on hurtbox capsule layer.** Bite number = Q4.
- **Alligator** (capsule 0.9×3.0) — P8 drag-latch; Death Roll = zone check +
  kit tick; Ambush = stealth + speed modifier; Devour = on_kill override.
  **Gated on hurtbox capsule layer.**
- **Newt** — melee; Unken = P7 invuln + P3; Toxic Secretion = P2 + P1;
  Rib Exudation = P2 variant; Caudal Autotomy = death-interception hook.
- **Heron** — grounded spear (#15) + airborne gate; Powder Puff = P7 cleanse +
  CC-immunity; Flushing = dash → set AIRBORNE; Wading = P11.
- **Kingfisher** — melee + open_low_window + displacement tracker; Hover =
  flight variant; Nest Chamber = P10 single (balance flag Q6).
- **Wolf Spider** — dash+melee+latch (P8); Burrow network = P10-network;
  eggs/spiderlings = pet pattern hard cap 12 + trap-storage variant (stats Q5);
  Simple Eyes = anti-stealth reveal cone or defer (Q7).
- **Firefly** (nectarivore, no kill-heal) — P12 homing + reveal; Flash-Train =
  aura; Glowworms = P13 + P14; Bioluminescence = persistent aura (balance Q6).
- **Mosquito Swarm** — P12 + P14; Breeding Grounds trail (#13) = P14 + spawner;
  Deposit (#13) = P6 blood meter; Unswattable = P15 + match_rng 9% miss +
  HP-scaled hitbox.
- **Otter** — latch; Tail Whip = melee no-max_hits + P3; Gang Up = pack
  coordination (no CD in JSON — Q3); Pack of 3 = P16 (stocks ruling Q2).
- **Bog Turtle** — melee + modifiers; Endozoochory = P12 lobbed + P13 pickup;
  Umbrella = heal API once mounted; Basking = P17 (R context input exists).
- **Leech** — P18 body count (Q1); leech projectile = P12 + P1 attach + ammo
  spend; Copulation = idle-channel; Sensory Crypt = P19 + P12 + reveal (#16).

## 3. Cross-track dependencies

- **(a) Hurtbox/capsule layer** (combat track Phase A/D): only Water Snake +
  Alligator need capsules → wave 2 splits into 2a (circles, unblocked) and 2b
  (gated). Hull extension lands in `hit_shape.gd`; melee/aura/projectile
  inherit it because they all route through those overlap functions.
- **(b) M5 economy**: blood meter is independent of hunger (#13). With the
  generic meter widget built in wave 1, **no roster wave hard-blocks on M5**.
  Two TODO hooks (mosquito hunger-fill clauses) land when M5 does.

## 4. Wave plan

Every creature ships with kit + bot hook + skin verification + check coverage;
every wave ends with the M2/M3-six regression pass + `run_all.ps1` + `Input\.`
grep + roster-hash check.

1. **Wave 1 — Bullfrog, Cane Toad, Crayfish, Water Shrew** (~1.0× baseline;
   unblocked today). New: P1, P2, P3, P4, P5, P6-widget(ammo), P11.
   Check `battle_bog_wave1_check.gd`: Bufotoxin caps at 5 + MELEE-only; Swallow
   execute+heal; camouflage 3.0s idle / breaks on action; Lunge knockback 1u +
   breaks latch; Meral = STANCE +30% radius 30% DR restore-on-exit; shrew 3-stack
   cap; root+silence leaves attack; ammo drains 10/s, blocks at 0; water-walk
   drops on idle.
2. **Wave 2a — Newt, Heron, Kingfisher** (~0.9×). New: P7, P10-single,
   Flushing dash-to-flight, Hover, P11-wading.
   Checks: invuln 3s + push; 60% melee-only reflect; Autotomy once/25s;
   Powder Puff strips debuffs only + blocks Lingual Lure; wading hits water
   targets w/o DOT; Flushing skips takeoff; +30% after 2u; Nest Chamber
   untargetable 7s; spike rule still grounds flying heron.
3. **Wave 2b — Water Snake, Alligator** (~1.1×; **gated on capsule hurtbox**).
   New: P8 + capsule integration.
   Checks: tail-side hit connects / perpendicular circle-miss doesn't;
   hold-release ends latch; drag direction by base HP both ways; Ingestion
   gates (<15%, lower base HP, 20s); Death Roll water-only 30×5; Musking
   blocked while latched; Devour 50%; gator whiff leaves a 1.8s punish gap.
4. **Wave 3 — Wolf Spider, Firefly, Mosquito Swarm** (~1.3×). New: P12, P13,
   P14, P10-network, P15, P6-blood, spiderling pet (cap 12), match_rng miss.
   Checks: burrow cap 4 + hide + 4u charge; spiderling cap incl. trap hatch;
   glowworm 40% slow + 10% vuln cleansable; firefly 20/s inside 4u only;
   projectile→3-radius field; trail node cap; blood fills from all three #13
   sources, Deposit 50×(stored/max) at ≤1u; 9% miss seeded-deterministic;
   mosquito passes through dams but takes melee.
5. **Wave 4 — Otter → Bog Turtle → Leech** (~1.6×; the exotic controllers, one
   at a time; **blocked on rulings Q1–Q3**). New: P16, P17, P18, P19.
   Checks: control swaps to unlatched otter on latch; Gang Up latches all
   three; latched otters −20% dmg taken; per-otter 25% slow stacks; bot pilots
   all 3 bodies (hardest bot hook in the game — budget it); mounted turtle
   takes 5% of carrier damage, survives carrier flight/water, dismounts on
   carrier death, Umbrella order correct; leech −1 body per hit regardless of
   damage, +1/4s regen, primary and Crypt spend bodies, Crypt hits same water
   body only, 6s reveal-latch.

## 5. Open questions needing a user ruling

1. **Q1 Leech base HP** — `stats.health = "20 leeches"` breaks every base-HP
   comparison (Swallow, Snake drag/Ingestion, Fearless, Basking, kill-heal %).
   Need a canonical scalar.
2. **Q2 Otter pack vs stocks (#6)** — one pack = one stock? Do dead otters
   respawn mid-life (ROSTER.md says "pack respawns"; JSON silent)?
3. **Q3 Otter Gang Up cooldown** — absent from JSON; number needed.
4. **Q4 Water Snake unlatched bite damage** — only the latched string exists.
5. **Q5 Spiderling stats** — no HP/damage/lifetime anywhere.
6. **Q6 Balance flags (not blockers)** — Kingfisher 7s immunity vs 6s CD
   (>50% uptime); Firefly 20 HP/s constant aura on a 30 HP body.
7. **Q7 Vision** — no fog-of-war exists. Implement Spider Simple Eyes / Owl
   perch vision as anti-stealth reveal only, or defer to a vision system?
8. **Schema note (code-side; JSON read-only):** movement tag `land_walker`
   (Bullfrog/Chorus Frog/Mink) vs `ground_walker` (the rest) — code must treat
   them as synonyms.
9. **Crayfish** — JSON says ground-only (+5% speed in stance); ROSTER.md says
   "aquatic TBD" and "slower turning". JSON wins per authority order.
