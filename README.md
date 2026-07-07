# Battle Bog

Battle Bog is a top-down competitive creature brawler built from the original
Hitmasters prototype. Two teams fight across a mixed land/water bog map, protect
their home habitat, pressure mud-hut lanes, manage creature stocks, and scale
through food, hunger, and breeding.

## Current Direction

- Pixel-based indie visual style.
- Ranked-first combat readability.
- 1v1 and 3v3 game modes.
- One reusable bog arena with mirrored team territory.
- Amphibians, reptiles, birds, mammals, and crawlies with terrain-specific
  strengths and risks.
- No item shop or traditional leveling.
- Team progression comes from food, habitat deposits, breeding, and stock
  management.

## Design Docs

| File | Purpose |
| --- | --- |
| `docs/BATTLE_BOG_SYSTEMS.md` | System map for habitats, food, hunger, terrain, mud huts, stocks, and controls. |
| `docs/BATTLE_BOG_ROSTER.md` | Full playable creature roster translated from the design notes. |
| `docs/BATTLE_BOG_IMPLEMENTATION_PLAN.md` | Migration path from the current prototype into Battle Bog. |
| `docs/BATTLE_BOG_DECISIONS.md` | Locked design rulings; overrides other docs on conflict. |
| `docs/BATTLE_BOG_BUILD_PLAN.md` | Hardened milestone plan (M0-M8) with file layout and acceptance checks. |
| `docs/CODEX_HANDOFF_PROMPT.md` | Ready-to-paste implementation prompt for the coding agent, one milestone at a time. |
| `docs/RESEARCH_MOVEMENT_FEEL.md` | Movement-feel research source; context unless ratified in decisions/build/systems docs. |
| `docs/RESEARCH_COMBAT_DEPTH.md` | Combat-depth research source; context unless ratified in decisions/build/systems docs. |
| `docs/RESEARCH_VISUAL_OVERHAUL.md` | Visual/readability research source; context unless ratified in decisions/build/systems docs. |
| `docs/RESEARCH_VISION_SUPERVIVE_AND_BATTLE_BOG.md` | Vision/information-ecology research source; context unless ratified in decisions/build/systems docs. |
| `docs/RESEARCH_SUPERVIVE_MECHANICS_FOR_BATTLE_BOG.md` | SUPERVIVE mechanics translation source; context unless ratified in decisions/build/systems docs. |
| `data/battle_bog_roster.json` | Structured roster data for future character select/gameplay wiring. |

## Current Prototype Goals

1. Keep the existing menu, character select, and arena playable.
2. Convert character select to the Battle Bog roster data.
3. Implement the first animal vertical slice with placeholder pixel silhouettes.
4. Add terrain tags and animal movement rules.
5. Add mud huts, habitat stocks, food/hunger, and breeding in that order.
