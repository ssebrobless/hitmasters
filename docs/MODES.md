# Game Modes

```text
╔═════════════╦═══════════════╦════════════════════════════════════╗
║ Mode        ║ Map Shape     ║ Match Pressure                     ║
╠═════════════╬═══════════════╬════════════════════════════════════╣
║ 1v1 Trio    ║ shared map    ║ 3 species, 1 active, squad calls   ║
║ 3v3 Clash   ║ shared map    ║ full waves + team bot pressure     ║
║ Hero Lab    ║ shared map    ║ single-creature practice           ║
╚═════════════╩═══════════════╩════════════════════════════════════╝
```

## 1v1 Trio

```text
Character Select
        │
        ▼
Pick 3 unique playable species
        │
        ├── Slot 1 starts active
        ├── Slots 2/3 are field squadmates
        └── 1 / 2 / 3 swap active species during match

ACTIVE CREATURE receives WASD / aim / LMB / Q / E / U
        │
        ├── T: inactive squadmates follow within 5 units for 10s
        │       └── active hit on enemy creature -> assist aggro
        │
        └── G: inactive squadmates farm safely, clear minions, survive
```

- The player owns three unique species slots chosen in the 1v1 Trio select flow.
- The playable slice is Snapping Turtle, Chorus Frog, Mink, Beaver, Owl, and Duck.
- Each species has three stocks managed by the stock manager; the 1v1 Trio HUD shows per-slot stock, KO, and out states.
- 1v1 uses the unified expanded map with mode pressure tuned by one hut per side, two minions per hut wave, an 18s wave interval, and a 90s hunger pace.
- Only the active species receives manual deposit input. Inactive species must never auto-deposit for habitat stat boosts.
- Inactive species default to safe farming/minion clearing until food and hunger systems come online.
- The 1v1 format should feel like an action hero game with squad pressure, not RTS-style unit micro.
- InputMap actions exist for `squad_slot_1`, `squad_slot_2`, `squad_slot_3`, `squad_regroup`, and `squad_farm`; Arena owns the live command handling.

## 3v3 Core Clash

- Unified expanded arena bounds.
- Three minions per wave.
- Standard wave interval.
- Two allied bots and three enemy bots.
- Wider camera for teamfight readability.
- Character select remains a single-creature pick.

## Hero Lab

- Unified expanded arena bounds with the learning camera profile.
- One selected creature against one rival bot.
- Closer camera for learning movement, terrain, and kit timing.
- Character select remains a single-creature pick.
