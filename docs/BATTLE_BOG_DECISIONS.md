# Battle Bog Locked Design Decisions

Resolved 2026-07-03. These override ambiguity in the systems/roster docs.

| # | Decision | Ruling |
| --- | --- | --- |
| 1 | Damage taxonomy | Two orthogonal tags: delivery (`melee` vs `ranged`) and plane (`ground` vs `air`). Airborne birds dodge ground-melee only; ranged hits fliers normally. Mosquito's 9% miss is its unique passive, not a global rule. "Physical attacker" passives (Bufotoxin, Toxic Skin, Toxic Secretion, Rib Exudation) trigger on melee contact only. |
| 2 | Latch model | Struggle model. Latched victim keeps moving (slowed; drag direction per base-HP rule) and can attack and use abilities. Latch ends on attacker release, duration timeout, victim dash/displacement ability, or ally knockback. Latcher takes full damage while attached. |
| 3 | Units & scale | 1 design unit = 16 px. Speed 1.0 = 130 px/s. Camera zooms in and arena shrinks relative to the Hitmasters prototype; slower, denser game feel. |
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
