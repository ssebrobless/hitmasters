# Gameplay Spine

```text
Blue Core                                      Red Core
   │                                              │
   ├─ spawns minions ───▶ mid clash ◀─── spawns minions
   │                       │                      │
   │                 player fights                │
   │                       │                      │
   └────────────── destroy enemy Core ────────────┘
```

## Core Principles

- The Core is the win condition.
- Minions create pressure, space, and timing windows.
- Players decide the match through aim, movement, cooldown discipline, and
  coordinated pushes.
- No items or leveling in the first version.
- Every strong action should have readable counterplay.

## Default Match Rules

| Rule | Starting Value |
| --- | --- |
| Teams | Blue vs Red |
| Modes | 1v1, 3v3 |
| Win condition | Enemy Core reaches 0 health |
| Minion wave interval | 20 seconds |
| Respawns | Enabled |
| Player scaling | None |
| Items | None |
| Levels | None |
| Core attacks | Disabled initially |
| Minions damage Core | Yes, slowly |

## Combat Feel Targets

- Movement should feel crisp and intentional.
- Basic attacks should reward aim and spacing.
- Dashes should be powerful but punishable after use.
- Supports should create skill tests, not passive sustain walls.
- Tanks should create space without deleting opponents.
- Assassins should threaten isolated targets but struggle into peel and grouped
  enemies.

