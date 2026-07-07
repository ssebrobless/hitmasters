# Battle Bog Locked Design Decisions

Resolved 2026-07-03. These override ambiguity in the systems/roster docs.

## Research Integration Decisions

| # | Decision | Ruling |
| --- | --- | --- |
| 35 | Information ecology | Research handoff integration: Battle Bog information is layered, not global truth. Systems should distinguish directly visible, revealed, heard/pulsed, last-known, suspected, and hidden states. Exact radii/timings are tuning variables, but new visibility, minimap, AI, terrain clue, and objective work must plug into shared information states instead of ad hoc omniscience. |
| 36 | Minimap truth | The minimap is a readability tool, not enemy GPS. Exact enemy icons require current team visibility or reveal; otherwise future work should use faded last-known markers or uncertain sound/ripple/rustle pulses. Neutral animal-zone progress may be shown as coarse public ecology information because it already exists as world-state objective pressure. |
| 37 | Public objective events | Future non-core objectives should announce readable state transitions such as dormant, active, contesting, claimable, claimed, and stolen. Ownership should be earned through contest/claim/interrupt windows rather than pure last-hit. Boss-family-specific rewards and timings remain out of main-thread scope until the boss work is handed off. |
| 38 | Match-contained power | Do not import persistent out-of-match stat progression from reference games. Food, hunger, breeding, stocks, and future objectives stay match-contained unless a later decision explicitly changes the ranked progression model. |

## Original Locked Decisions

| # | Decision | Ruling |
| --- | --- | --- |
| 1 | Damage taxonomy | Two orthogonal tags: delivery (`melee` vs `ranged`) and plane (`ground` vs `air`). Airborne birds dodge ground-melee only; ranged hits fliers normally. Mosquito's 9% miss is its unique passive, not a global rule. "Physical attacker" passives (Bufotoxin, Toxic Skin, Toxic Secretion, Rib Exudation) trigger on melee contact only. |
| 2 | Latch model | Struggle model. Latched victim keeps moving (slowed; drag direction per base-HP rule) and can attack and use abilities. Latch ends on attacker release, duration timeout, victim dash/displacement ability, or ally knockback. Latcher takes full damage while attached. |
| 3 | Units & scale | 1 design unit = 16 px. Original speed 1.0 = 130 px/s, amended by decision #32 to 91 px/s. Camera zooms in and arena shrinks relative to the Hitmasters prototype; slower, denser game feel. |
| 4 | Wrong-terrain risk | Ramping percent DOT: 2% max HP/s for the first 3 s in wrong terrain (or after swim timer expires), then 5%/s. Applies identically to non-swimmers in water and expired semi-aquatics. |
| 5 | Migration win condition | Slice 1 keeps cores, but each core is placed inside its team's habitat plot so the habitat exists spatially from day one. Stocks/habitat defeat replaces cores in Phase 3. |
| 6 | Stock identity | Same creature, fixed 3 stocks (1 fielded + 2 reserve). Death = respawn as your creature at the habitat. |
| 7 | Starvation | Lethal at 0 hunger, as designed, but slow drain (~90–120 s full-to-empty) with loud warnings below 25%. |
| 8 | Breeding buffs | Per-family team buff stacks (capped), from the deposited animal's family: Amphibian +regen, Reptile +max HP, Bird +move speed, Mammal +damage, Crawly +ability haste. Starting value ~+3%/stack. |
| 9 | Hut count | Data-driven hut system designed for 4/side; ship 2/side (top + bottom lane) in 3v3 and 1/side in 1v1 until the mechanic is proven. |
| 10 | Dev mode | 3v3 with bots is the daily target throughout. Shared bot brain with per-kit hooks; all slice creatures stay bot-pilotable through refactors. |
| 11 | Slice art | Procedural per-creature silhouettes in `visual_style.gd` first; real 16 px sprite sheets only after kits stabilize. |
| 12 | Netcode scope | Local-first, net-aware. Complete = full loop vs bots through Phase 4. Deterministic fixed-tick sim, controllers consume an input struct (no `Input.*` inside creature logic) so online is a Phase 5 decision, not a rewrite. |
| 13 | Mosquito Q/E | Q Breeding Grounds: 6 s moving AOE trail, lingers 3 s, 10 s CD after trail fades. E Deposit: within 1 unit of ally, transfer blood meter as burst heal (50 at full, scales with stored blood), 3 s CD. Blood meter is separate from hunger; fills from primary AOE, trail, and Unswattable contact. |
| 14 | Alligator attack speed | 1 bite / 1.8 s (bite is 70 dmg + drag-latch entry; whiffs must be punishable). |
| 15 | Heron attack speed | 1 strike / 1.4 s (longest melee reach in roster; each poke matters, each whiff is an opening). |
| 16 | Sensory Crypt | 14 s cooldown; costs 1 body-leech per target hit (self-balancing with the Cluster passive). |
| 17 | Diet tags | Realistic split, `diet` field per creature. Kill-heal (5% max HP over 2 s) for all carnivores/omnivores — 19 of 21. Excluded: Beaver (herbivore, has Gnawing) and Firefly (nectarivore, has Bioluminescence). Mosquito/Leech blood-feeding counts as carnivore. |
| 18 | Reproduction | Uniform 45 s breeding timer per deposit (visible, attackable window at the habitat). Team cap 6 buff stacks, max 3 from one family, +3% each. Per-creature rates only if playtests demand. |
| 19 | Footprints | Per-creature bespoke sizes in `footprint` field (radius in design units; 1 u = 16 px). Circles for all except Water Snake (capsule 0.4×2.5) and Alligator (capsule 0.9×3.0). Range: 0.3 (Firefly) to 1.6 (Snapping Turtle). Duckling 0.3; Mosquito hitbox scales slightly with health. |
| 20 | Spike rule | A ranged hit dealing ≥30 damage to a flying bird (AIRBORNE state, not always-flying bugs) forces it to the ground and triggers the 3 s no-takeoff lockout. Imported from Supervive's glider-spike counterplay (see RESEARCH_TOPDOWN_BRAWLERS.md); gives every creature an answer to flight. Perched birds are not spikeable. Adopted 2026-07-04. |
| 21 | Hurtbox hull | Hits resolve against a broad hull built from `footprint` (circle, or capsule for Water Snake/Alligator; capsule axis = movement heading, aim fallback), replacing center+radius. Fixes the capsule creatures being ~3x smaller than designed. Adopted 2026-07-04 (see RESEARCH_COMBAT_DEPTH.md). |
| 22 | Region band | Authored hurtbox regions are chunky (min radius 0.35 u) with multipliers capped 0.75x–1.35x, enforced by the catalog loader. No universal headshot, no limb sniping — Monster-Hunter-style zones only, high-value regions state-gated. |
| 23 | Frame data | Every damaging ability declares startup/active/recovery (roster `stats`); damage lands only during active ticks; no new ability may start during recovery (dash-cancel only if flagged per-ability). |
| 24 | Whiff cost | Whiffed attacks serve full recovery; landing a hit refunds 40% of recovery (hit-confirm reward). |
| 25 | Counter-hit | Hitting an enemy during their startup deals +20% damage with a distinct flash. |
| 26 | Hitstop | 3-frame render-only freeze of attacker+victim on hits ≥50 dmg; sim state never pauses (formalizes RESEARCH_TOPDOWN_BRAWLERS item 13). |
| 27 | Body collision | Grounded live creatures soft-collide via a deterministic capped push-apart pass (both teams); airborne creatures pass over; latch pairs exempt; dashing creatures ghost through bodies. |
| 28 | Turn rate | Capsule-bodied creatures (Alligator, Water Snake) rotate their body axis at a capped rate (gator 240°/s, snake 320°/s starting values); aim stays instant. Makes flanking a long body a real maneuver. |
| 29 | AREA delivery | Third delivery tag `area` for AOE/terrain/environment damage: not dodged by fliers, never triggers melee-contact passives (closes a Decision #1 loophole in `arena.damage_enemies_in_radius`). |
| 30 | Latch anchor | Latches attach at the hit point on the victim's hull (visual anchor + drag pivot); kit-specific latch effects (Choke execute) live in kit callbacks, not `creature.gd`. |
| 31 | Visual style constitution | The palette constants and 8 rules in RESEARCH_VISUAL_OVERHAUL.md Part 4 are law for all drawing code: global NW light/SE `SHADOW`, saturation bands (team + telegraph colors exclusive above 0.7), no environment outlines, the truth ring (contact shadow + team ring at exactly `body_radius`, extremities overhang only if thinner than 0.25R), value hierarchy, detail-at-edges, perf constitution (drawn-once static layers, throttled animated layers), one source for team colors. Adopted 2026-07-04. |
| 32 | Global tempo | Amends #3: speed 1.0 = 91 px/s (−30%); all minion speeds −40% from their pre-2026-07-05 values. Minions commit to attacks: movement pauses 0.25 s when they swing/throw (no hard-chase while hitting). Adopted 2026-07-05 after playtest ("game felt a little too fast"). |
| 33 | Latch grip & struggle | Amends #2's escape rules. The latch timer is a GRIP METER: victim movement opposing the drag drains it 1.5x; victim melee hits on the latcher auto-connect regardless of facing/arc (thrashing) and chunk the grip (−0.75 s each). Latcher movement while attached is capped at 45% of the victim's base speed. Latcher takes 100% damage from its victim but 75% from third parties while attached (fragile latchers aren't free kills for the victim's team; the victim fighting back stays the premier answer). |
| 34 | Match days | One in-match day = 120 s (≈ one hunger cycle per #7). Wild fauna/flora spawns refresh at each dawn. Day clock is sim-owned and deterministic. |
