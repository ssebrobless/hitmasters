# Battle Bog Systems Map

Battle Bog is a top-down competitive creature brawler with lane pressure, team
stocks, habitat defense, terrain mastery, food pressure, and late-match breeding
scaling. The ranked feel should come from aim, spacing, timing, resource use,
terrain knowledge, and team composition.

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║                                Match Shape                                  ║
╠══════════════════════════════════════╦═══════════════════════════════════════╣
║ Blue Bog                             ║ Red Bog                               ║
║                                      ║                                       ║
║  ┌──────┐      ┌──────┐              ║              ┌──────┐      ┌──────┐  ║
║  │ Hut  │─────▶│ Mid  │◀─────────────╬─────────────▶│ Mid  │◀─────│ Hut  │  ║
║  └──────┘      │ Bog  │              ║              │ Bog  │      └──────┘  ║
║      │         └──────┘              ║              └──────┘         │      ║
║      ▼            ▲                  ║                  ▲            ▼      ║
║  ┌────────┐   ┌──────┐               ║               ┌──────┐   ┌────────┐  ║
║  │Habitat │──▶│Food +│── contested ──╬── contested ──│Food +│◀──│Habitat │  ║
║  │ Stocks │   │Water │               ║               │Water │   │ Stocks │  ║
║  └────────┘   └──────┘               ║               └──────┘   └────────┘  ║
║      ▲            │                  ║                  │            ▲      ║
║      │         ┌──────┐              ║              ┌──────┐         │      ║
║  ┌──────┐─────▶│ Mid  │◀─────────────╬─────────────▶│ Mid  │◀─────┌──────┐  ║
║  │ Hut  │      │ Bog  │              ║              │ Bog  │      │ Hut  │  ║
║  └──────┘      └──────┘              ║              └──────┘      └──────┘  ║
╚══════════════════════════════════════╩═══════════════════════════════════════╝
```

## Primary Match Loop

```text
┌────────────┐   fight/farm   ┌────────────┐   fill hunger   ┌─────────────┐
│ Habitat    │───────────────▶│ Field Play │────────────────▶│ Satiated    │
│ stocks     │                │ terrain    │                 │ animal      │
└─────┬──────┘                └─────┬──────┘                 └──────┬──────┘
      ▲                             │ death                           │ U
      │ take next stock             ▼                                 ▼
┌─────┴──────┐                ┌────────────┐                 ┌─────────────┐
│ Respawn    │◀───────────────│ Stock lost │                 │ Deposit in  │
│ control    │                │ in field   │                 │ habitat     │
└────────────┘                └────────────┘                 └──────┬──────┘
                                                                     │ breed
                                                                     ▼
                                                              ┌─────────────┐
                                                              │ Team stat   │
                                                              │ boost stack │
                                                              └─────────────┘
```

## Win And Loss

| System | Current Rule |
| --- | --- |
| Team structure | 1v1 and 3v3 supported by the same map logic. |
| Protected objective | Each team has a central Habitat. |
| Player lives | At match start, each selected creature has 2 reserve stocks in the habitat and 1 controlled stock in the field. |
| Death | The player takes control of another stock in the habitat. |
| Habitat danger | Outer defenses must be broken before habitat stocks are vulnerable. |
| Defeat | If a team cannot respawn because its required stocks are gone, that team loses. |

## Terrain Rules

```text
╔══════════════╦════════════════════╦════════════════════════════════════════╗
║ Terrain      ║ Favored creatures  ║ Risk rule                              ║
╠══════════════╬════════════════════╬════════════════════════════════════════╣
║ Land         ║ walkers, birds     ║ aquatic specialists may be slower       ║
║ Shallow bog  ║ amphibians, birds  ║ neutral contest space                   ║
║ Water        ║ aquatic/semi-aqua  ║ non-designated animals take DOT risk    ║
║ Trees/cover  ║ owl, spider, beaver║ blocks ground shots and creates ambush  ║
║ Burrows/dams ║ spider, beaver     ║ creature-built map modifiers            ║
╚══════════════╩════════════════════╩════════════════════════════════════════╝
```

- Non-designated environments should damage over time instead of instantly
  killing. Risky terrain plays should be possible.
- Aquatic and semi-aquatic creatures gain 15% move speed in water.
- Semi-aquatic creatures have limited swim time before they must surface.
- Birds move faster in flight, ignore ground collision while airborne, and have
  counter-hit windows when they dip low to attack.
- Mosquitos and fireflies are always airborne, but unlike birds they can still
  be hit by physical attacks.

## Information Ecology

Battle Bog information is a gameplay resource. The map, minimap, AI, terrain
clues, and future objective events should share the same truth ladder instead of
showing every enemy or objective as exact global knowledge.

```text
direct sight -> revealed -> heard/pulsed -> last-known -> suspected -> hidden
```

| Layer | System Meaning |
| --- | --- |
| Direct sight | Current allied vision can show exact enemy position and normal minimap icon. |
| Revealed | Ability/objective/terrain reveal grants temporary exact information. |
| Heard or pulsed | Movement, attacks, harvesting, splashes, or rustles create uncertain rings/arcs. |
| Last-known | Recently seen enemies leave faded, decaying markers instead of live GPS. |
| Suspected | Terrain clues suggest activity without a precise unit marker. |
| Hidden | No targeting, no exact minimap icon, and AI should not engage omnisciently. |

- Day/night is an information phase layered over decision #34's 120 second day:
  day favors direct scouting, dusk transitions toward clue reading, and night
  should emphasize pulses, rustles, ripples, and reveal tools.
- Terrain should communicate information through mechanics and visuals: reeds
  rustle, water ripples, mud drags, rocks/trees block sight, and cover hides
  slow/idle creatures until an action gives them away.
- Neutral animal-zone progress is public ecology pressure. The world and
  minimap may show coarse remaining wildlife/contest/control state, while exact
  enemy positions still follow the visibility rules above.
- Future objective states should be public events: dormant, active, contesting,
  claimable, claimed, and stolen.

## Food, Hunger, And Breeding

```text
Wild flora/fauna ── harvest/kill ──▶ food ──▶ heal slightly
                                      │
                                      ▼
                              hunger/satiation
                                      │
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
                 hunger reaches 0            food cap reached
                 active stock dies           hunger stops draining
                                                    │
                                                    ▼
                                             return to habitat
                                                    │ U
                                                    ▼
                                             deposit + breed
```

| Rule | Design Intent |
| --- | --- |
| Food heals slightly | Rewards map movement without replacing support play. |
| Hunger drains over time | Forces field activity and denies permanent turtling. |
| Satiated food cap | Creates a clear return-to-base decision. |
| No hunger drain after cap | Prevents losing a successful farm run before deposit. |
| One satiated animal per type/team in habitat | Prevents stacking one creature type too efficiently. |
| Baby animal buff | Gives teams progression without items or levels. |
| Stackable habitat buffs | Creates late-game pressure and comeback targets. |

## Mud Huts And Lane Pressure

```text
┌──────────────┐     spawns      ┌─────────────┐       targets      ┌──────────────┐
│ Blue mud hut │───────────────▶ │ mud minions │──────────────────▶ │ Red mud hut  │
└──────┬───────┘                 └─────────────┘                    └──────┬───────┘
       │ defender stock                                               defender stock
       │ F interaction                                                F interaction
       ▼                                                                    ▼
┌──────────────┐                                                   ┌──────────────┐
│ 5 minion     │                                                   │ 5 minion     │
│ defenders    │                                                   │ defenders    │
└──────────────┘                                                   └──────────────┘
```

- Each side has 4 mud huts surrounding its territory.
- Huts spawn marching mud minions that default to attacking opposite huts.
- Minions target enemies in range while marching.
- Huts do not directly attack.
- Each hut maintains 5 defensive mud minions: 1 tanky, 2 standard physical, and
  2 ranged pebble throwers.
- Defensive mud minions respawn 5 seconds after death.
- Players can press `F` at a hut to leave their current stock defending it.
- A player may only leave a stock defending if they have 3 or more stocks in the
  habitat.
- A hut can hold up to 2 player-stock defenders plus 5 mud minion defenders.

## Controls

| Input | Use |
| --- | --- |
| `WASD` | Move. |
| `Mouse` | Aim. |
| `LMB` | Default attack. |
| `Q` | Ability 1. |
| `E` | Ability 2. |
| `F` | Leave current stock defending a mud hut. |
| `U` | Deposit/swap a satiated animal in home habitat. |
| `R` | Context action such as bog turtle basking or beaver dam rotation. |
| `Space` | Bird takeoff/landing or character-specific cancel/release actions. |

## Global Trait Rules

| Trait | Rule |
| --- | --- |
| Carnivore/omnivore | Heal 5% max HP over 2 seconds after killing an enemy. |
| Aquatic/semi-aquatic | Gain 15% move speed in water. |
| Semi-aquatic | Limited swim timer before needing air. |
| Bird takeoff | Hold `Space` and move 2 units to take off. |
| Bird depletion | Fully depleted flight grounds the bird and prevents takeoff for 3 seconds. |
| Airborne bird | Passes over obstacles/enemies and dodges ground physical attacks. |
| Low attack window | Bird dive/peck impact windows can be hit by ground attacks. |
| Always-flying bugs | Mosquitos/fireflies fly over water/objects but can still be hit physically. |
