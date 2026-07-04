# Game Modes

```text
╔══════════════╦══════════════════╦══════════════════════════════════╗
║ Mode         ║ Map Shape        ║ Match Pressure                   ║
╠══════════════╬══════════════════╬══════════════════════════════════╣
║ 1v1 Trio     ║ compact arena    ║ 3 species, 1 active, squad calls ║
║ 3v3 Clash    ║ full arena       ║ full waves + team bot pressure   ║
║ Hero Lab     ║ compact arena    ║ single-creature practice         ║
╚══════════════╩══════════════════╩══════════════════════════════════╝
```

## 1v1 Trio

```text
1 / 2 / 3 swap active species
        │
        ▼
ACTIVE CREATURE receives WASD / aim / LMB / Q / E / U
        │
        ├── T: inactive squadmates follow within 5 units for 10s
        │       └── active hit on enemy creature -> assist aggro
        │
        └── G: inactive squadmates farm safely, clear minions, survive
```

- The player owns three unique species slots.
- Each species is designed to have three stocks; current code shows the stock rail while the dedicated stock manager is still pending.
- Only the active species receives manual deposit input. Inactive species must never auto-deposit for habitat stat boosts.
- Inactive species default to safe farming/minion clearing until food and hunger systems come online.
- The 1v1 format should feel like an action hero game with squad pressure, not RTS-style unit micro.

## 3v3 Core Clash

- Full arena bounds.
- Three minions per wave.
- Standard wave interval.
- Two allied bots and three enemy bots.
- Wider camera for teamfight readability.

## Hero Lab

- Compact arena bounds.
- One selected creature against one rival bot.
- Closer camera for learning movement, terrain, and kit timing.
