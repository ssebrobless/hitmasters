# Research: Visual & Environment Overhaul — Semi-Realistic Bog

Compiled 2026-07-04 (subagent research + drawing-code inventory at HEAD
41b5571). Goal: semi-realistic animal brawler look; huts/minions/terrain/props
upgraded; hitboxes visibly backed by the models. The style constitution in
Part 4 is law for all future drawing code once ratified.

## Part 1 — Research findings

- **R1 Water = three cheap layers**: depth tint (darker toward center),
  shoreline foam band (smoothstep of distance-to-shore), sparse animated
  highlights. Zones are axis-aligned rects → distance-from-shore is trivial per
  edge; a 3-band shore treatment (wet mud strip → pale foam line → shallow →
  darkening deep) draws ONCE into the cached terrain layer. The foam line IS
  the swim/drown boundary — art doubles as legibility.
- **R2 Semi-realistic without textures = value layering, not detail count.**
  4–5 value steps per material; detail concentrated at boundaries; interiors
  ≤2-tone mottling. Current uniform random specks add grain, not realism —
  move the detail budget to edges (shoreline tufts, cover rims, mud cracks).
- **R3 Bog palettes**: dark desaturated olive/brown ramps; saturation reserved
  for focal points. Current zone fills are too dark AND too same-value (hue-only
  discrimination at low value = hardest band). Lift LAND/SHALLOW one value step;
  keep WATER darkest; saturation ceiling on environment so team/telegraph
  colors pop by contract.
- **R4 Top-down volume** = lit roof + dark wall sliver on the shadow side +
  offset drop shadow. Dome hut: SE ground-shadow ellipse, SE rim crescent,
  NW highlight crescent, curved thatch arcs (not radial spokes), entrance as a
  dark arch + lintel on the wall.
- **R5 LoL/Dota anchor gameplay truth in a ground ring** scaled to the
  gameplay radius; body mass stays over the circle, extremities may overhang.
  Rule to adopt: torso inside the collision circle; only thin extremities
  (<0.25R wide) overhang; ring drawn at exactly `body_radius`.
- **R6 Unit overlap = soft pairwise separation forces**, not hard physics —
  matches the combat track's Phase F (shared spine).
- **R7 Contact/blob shadows** are the cheapest grounding tool and double as
  the hitbox-truth indicator (airborne creatures already get one; grounded
  creatures get nothing today).

## Part 2 — Current-state inventory (file:line at HEAD 41b5571)

- **terrain_layer.gd** — drawn once, z=-10 (good discipline). Flat very-dark
  zone fills from `visual_grammar.gd:49-63`; all zones axis-aligned rects
  (`terrain_map.gd:89-127`, hard 90° shorelines). Uniform mottling + hardcoded
  tufts (:36-43); SHALLOW specks/static ripples/reeds (:44-56); COVER dark rect
  + bushes (:57-63); HABITAT tint + fence posts (:64-80). WATER 3px border
  (:85); plain 6px arena border (:29). Perch anchors = crosshair dots
  (:108-114) — placeholder.
- **water_layer.gd** — 20 Hz, precomputed origins, drifting 14px dashes
  (:35-43). Reads as static dashes; no foam/flow/interaction.
- **mud_hut.gd:100-121** — flat concentric circles + 7 radial sticks +
  hardcoded team colors (:103) + banner + bar. No volume, no damage states.
  **Perf violation: `_process → queue_redraw` every frame (:97-98)** for a
  static drawing. `dam.gd:57-58` same violation.
- **Minions** — `minion.gd:176-184` + `visual_style.gd:664-681`
  `draw_pixel_minion`: one shared 6×6 pixel blob for all kinds; retro-pixel
  clashes with the semi-realistic creatures. Tank drawn SMALLER than its
  17px hitbox. Cores/projectiles (:683-702) same retro clash.
- **Creatures** — `body_radius = radius_units × 16px` (`creature.gd:751-753`);
  capsule footprints (snake 0.4×2.5u, gator 0.9×3.0u, decision #19) collapsed
  to circles by the sim. Team ring at `radius + 3.0` (`visual_style.gd:83`) —
  oversells the hitbox. Silhouette-vs-circle audit: frog ±0.95R OK; turtle nose
  1.37R tail 1.45R; mustelid head 1.55R, beaver tail −3.0R; serpent +1.35R/−2.2R;
  croc snout +1.62R tail −2.5R (~4R total); heron beak tip ~2.1R. Round bodies
  honest; **every elongated creature overdraws 1.4–3× along its axis** — exactly
  the class perceived as interpenetrating.
- **No creature-to-creature collision** — `arena.gd:1024-1046` clamps to
  arena + cover/dam rects only; zero CollisionShape2D in the repo.
- **Telegraph grammar locked, keep** (`visual_grammar.gd:28-47`; arena
  telegraphs `arena.gd:1133-1380`). Environment must stay below it in saturation.
- **Team colors defined in 3 places** (`visual_style.gd:7-8`,
  `visual_grammar.gd:12-14`, `mud_hut.gd:103`) — consolidate to one source.

## Part 3 — Phased plan (impact-ordered)

Verification per phase: headless checks (esp. scene_boot + m1_terrain) then
user playtest for visual sign-off.

### Phase A — Terrain & water fidelity (biggest visible win)
Files: `visual_grammar.gd` (palette constants), `terrain_layer.gd`, `water_layer.gd`.
1. Constitution ramps for zone fills; lift LAND/SHALLOW one value step; WATER
   stays the dark element.
2. Shore treatment drawn once: per WATER edge adjacent to SHALLOW/LAND —
   wet-mud dark strip (4px) → pale foam line (1.5px, per-edge sine wobble
   computed at setup) → 2–3 inner darkening insets toward water center.
   SHALLOW gets mud-speckle bands on LAND edges. **Legibility law: the foam
   line is the ONE high-value environment line; deep water is always the dark
   side of the foam line.**
3. Kill uniform interior noise; re-budget to edges: reed clusters (shared
   `_draw_reed_clump()`), cover-rim tufts, sparse lily pads in SHALLOW.
4. `water_layer.gd`: keep 20 Hz + precomputed origins; dashes → slow expanding
   ripple arcs (2/origin, alpha fade) + a few drifting glints. Same primitive
   count.
5. Arena border: layered double line (dark outer, mossy inner).
Perf: all static stays draw-once; water keeps origin count + 20 Hz.

### Phase B — Mud hut as a volume, with damage states
Files: `mud_hut.gd`, `visual_grammar.gd` (shared shadow/team helpers).
1. **Fix the perf bug first**: delete `_process → queue_redraw` (also in
   `dam.gd`); redraw only on damage/team events.
2. Dome per R4: SE shadow ellipse → SE rim crescent → mud dome → NW highlight
   crescent → curved thatch arcs → daub patches → entrance arch + lintel →
   banner (shared team-color source).
3. Damage states by health thirds in `_draw`: ≥⅔ intact; ⅓–⅔ cracks + fallen
   sticks; <⅓ notched silhouette (polygon with bites), exposed framing, clods.
   RNG seeded from position — stable.
4. Optional: static drawn-once rubble node on destruction.

### Phase C — Minion redesign (silhouette per role)
Files: `visual_style.gd` (replace `draw_pixel_minion` with
`draw_minion(canvas, kind, team, body_radius, facing, anim)`), `minion.gd`
(pass kind/facing/walk phase).
1. Drop pixel-cell style. Theme: **mud-golem critters** — of-the-bog, team
   colored via moss/algae tint not fully saturated bodies.
2. Three silhouettes at a glance: tank = wide dome-backed mudball (shell arcs,
   slow bob); melee = round body + oversized snapping mandibles; pebble/ranged
   = slimmer + visible sling arm + held pebble. Lane minions = melee + march bob.
3. Team readability: colored back-stripe + eye glow; contact shadow + team
   ring at true `body_radius` (shared helper — can land in Phase A commit).
4. Keep the `is_near_view` redraw gate; ≤ ~25 primitives per minion.

### Phase D — Environmental props
Files: `terrain_layer.gd` or new drawn-once `props_layer.gd` (z above terrain,
below units); `terrain_map.gd` only if props get authored positions.
1. COVER → reed brakes/thickets: keep the dark base rect (it IS the blocker
   footprint), ring it with reed/bush clusters slightly overhanging the edge;
   interior stays dark (hide-inside read preserved).
2. Perch anchors → snags/stumps (dead branch + ringed stump ellipse); faint
   ring only as the interactive-radius hint.
3. Non-blocking decor, deterministically seeded: rocks (2-tone + SE shadow),
   driftwood, cattails at water corners, mud cracks near habitats. **Decor
   never exceeds the environment saturation band and never overlaps lane
   centerlines.**
4. Habitats: trampled-earth patch, stick nest ring, team-tinted moss border
   (border stays the gameplay boundary).

### Phase E — Hitbox-visual alignment ("real visual backed hitboxes")
Files: `visual_style.gd`, `creature.gd`, `arena.gd`, `minion.gd`.
1. **Ground-truth base** (can ship inside Phase A's commit): contact-shadow
   ellipse (w=2R, h≈1.2R, SHADOW color) + team ring at exactly `body_radius`
   (fix `visual_style.gd:83`); same helper for minions. The ring is the contract.
2. **Silhouette audit per archetype**: torso mass inside R (mustelid spine
   ±1.0R, serpent coil mass within R, croc body within R with thin
   snout/tail overhangs, bird body within R with thin beak/neck). After: no
   filled shape wider than 0.3R extends past 1.15R.
3. **Soft-collision separation** — shared spine with the combat track's Phase F
   (one implementation, specced in RESEARCH_COMBAT_DEPTH.md).
4. Capsule footprints for snake/gator — handled by the combat track's Phase A
   hull; the serpent/croc archetypes must stretch to footprint length.
Verify: headless check that no two live grounded bodies end a tick overlapping
>1px; playtest for crowd feel (cap correction ~2px/tick — no jitter).

## Part 4 — Style constitution (ratify into DECISIONS; constants live in visual_grammar.gd)

```gdscript
# --- Bog environment ramps (semi-realistic, muted; sat ≤ 0.35, value ≤ 0.55) ---
const BOG_LAND_DARK   := Color(0.16, 0.19, 0.11)   # base earth
const BOG_LAND        := Color(0.22, 0.26, 0.15)   # lit ground
const BOG_MOSS        := Color(0.33, 0.38, 0.21)   # grass/moss accents
const BOG_MUD_DARK    := Color(0.19, 0.14, 0.09)   # wet mud / wood dark
const BOG_MUD         := Color(0.33, 0.24, 0.14)   # hut walls, stumps, dams
const BOG_REED        := Color(0.42, 0.44, 0.24)   # reeds, dry grass tips
const WATER_DEEP      := Color(0.07, 0.17, 0.22)
const WATER_SHALLOW   := Color(0.16, 0.30, 0.28)
const WATER_FOAM      := Color(0.62, 0.70, 0.62, 0.7)  # the ONE bright env line
const SHADOW          := Color(0.04, 0.05, 0.03, 0.35) # all shadows, everywhere
```

Rules (law, like the telegraph grammar):
1. **Global light NW, shadows SE** `(+0.35, +0.5) × height factor`; every
   shadow uses `SHADOW`; never per-object shadow colors.
2. **Saturation bands**: environment/decor ≤0.35; structures ≤0.45; creatures
   ≤0.6; **team colors + telegraph colors have exclusive rights above 0.7.**
   Nothing environmental may use telegraph gold/danger red/heal green/team hues.
3. **Outlines**: creatures/minions get a 1-value-darker rim of their own
   material (existing archetype pattern), never black; environment gets NO
   outlines — edges are value steps. Units stay the crispest things on screen.
4. **The truth ring**: every combat body draws contact shadow + team ring at
   exactly `body_radius`; extremities overhang only if thinner than 0.25R; the
   ring is the only team-colored element touching the ground plane.
5. **Value hierarchy** bottom→top: deep water darkest → land mid → foam/shore
   light → units lighter than their ground → telegraphs/team flashes brightest.
6. **Detail lives at edges**: rect interiors ≤2 tones of mottling; clusters,
   tufts, foam, cracks only at boundaries and prop bases.
7. **Perf constitution** (existing discipline, now written): static = drawn-once
   cached layers (terrain_layer pattern); animated = throttled isolated layers
   (water_layer 20 Hz) or event-driven redraws (hut on damage).
   `_process → queue_redraw` on static visuals is a defect.
8. **Team colors have ONE source** (visual_grammar) — delete the copies in
   visual_style.gd and mud_hut.gd.

Sources: Cyanilux 2D water breakdown; Roystan toon water; MakeGamesSA top-down
water; LoL Wiki unit size; Liquipedia Dota collision; Dignitas hitboxes;
Reynolds steering behaviors; Lospec swamp palettes; GameDev.net top-down depth;
Cainos top-down conventions; Simonschreibt/CMU/VectorStorm on blob shadows;
SeekVectors vector best practices; Level Design Book env art; RocketBrush 2D
styles; Snargl swamp palette notes.
