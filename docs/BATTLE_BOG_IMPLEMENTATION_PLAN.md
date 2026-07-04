# Battle Bog Implementation Plan

The current Godot prototype already has menu flow, character select, a reusable
arena, cores, minions, bots, projectiles, cover, and six placeholder archetypes.
This plan migrates that foundation into Battle Bog without throwing away the
playable work.

```text
╔════════════════════════════════════════════════════════════════════════════╗
║                         Prototype Migration Shape                         ║
╠══════════════╦══════════════════════╦══════════════════════╦══════════════╣
║ Phase 1      ║ Phase 2              ║ Phase 3              ║ Phase 4      ║
║ Data + docs  ║ First animal slice   ║ Habitat systems      ║ Ranked loop  ║
╠══════════════╬══════════════════════╬══════════════════════╬══════════════╣
║ roster JSON  ║ movement tags        ║ stocks/respawns      ║ draft rules   ║
║ systems docs ║ terrain modifiers    ║ food/hunger          ║ team comps    ║
║ open gaps    ║ 4-6 playable animals ║ breeding buffs       ║ map tuning    ║
║ old demo safe║ mud hut prototype    ║ defender assignment  ║ netcode prep  ║
╚══════════════╩══════════════════════╩══════════════════════╩══════════════╝
```

## Phase 1: Make The Notes Buildable

- Preserve the full creature roster in structured data.
- Add design docs for systems, roster, and open gaps.
- Keep the current six-hero demo playable while the new data settles.
- Decide which animal set becomes the first playable vertical slice.

Recommended first slice:

```text
┌────────────────┬────────────────────┬───────────────────────────────┐
│ Role           │ Creature            │ Why first                     │
├────────────────┼────────────────────┼───────────────────────────────┤
│ Tank anchor    │ Snapping Turtle     │ readable melee windup/pull    │
│ Flank assassin │ Mink                │ dash/latch skill test         │
│ Ranged support │ Chorus Frog         │ clean buffs/debuffs           │
│ Builder        │ Beaver              │ map interaction via dams       │
│ Aerial scout   │ Owl                 │ proves flight/perch rules      │
│ Swarm pet      │ Duck                │ proves follower/pet logic      │
└────────────────┴────────────────────┴───────────────────────────────┘
```

## Phase 2: Terrain And Animal Movement

```text
Animal controller
      │
      ├── ground movement
      ├── swim movement + swim timer
      ├── flight movement + takeoff/landing
      ├── latch/mount state
      └── burrow/perch special states
```

- Add terrain zones: land, shallow bog, water, cover/tree, habitat, mud hut.
- Apply speed boosts and damage-over-time risk by movement tag.
- Add generic state support for latch, mounted, airborne, perched, burrowed, and
  defending.
- Implement ability shapes as reusable pieces: dash, cone/arc hit, latch, aura,
  projectile, placeable, summon, stealth, reveal, cleanse.

## Phase 3: Habitat Economy

- Replace simple core-only win condition with habitat stocks.
- Spawn 2 reserve stocks per selected creature plus 1 controlled stock.
- Add `U` deposit/swap behavior in home habitat.
- Add food pickups from wild flora/fauna and a hunger/satiation bar.
- Add breeding timers, habitat capacity, and baby stat buffs.
- Add loss condition when a team cannot respawn.

## Phase 4: Mud Huts And Competitive Loop

- Replace simple core minion waves with 4 hut lanes per side.
- Add lane mud minions and hut defender minions.
- Add `F` stock-defender assignment.
- Add readable hut vulnerability before habitat vulnerability.
- Tune 1v1 and 3v3 map sizes separately while reusing the same terrain rules.

## Build Order Recommendation

1. Convert character select to read `data/battle_bog_roster.json`.
2. Implement a generic animal controller with terrain tags.
3. Make the first six-animal slice playable with placeholder pixel silhouettes.
4. Add one lane/mud hut pair and validate minion pressure.
5. Add habitat stocks and respawn selection.
6. Add food/hunger/deposit loop.
7. Add breeding buffs after the core loop feels fun without them.

