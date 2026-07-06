# Codex Handoff Prompt — Battle Bog

Copy everything below the line into Codex as the task prompt. Give it one
milestone at a time (replace the CURRENT MILESTONE line); do not hand it the
whole plan as a single task.

---

You are implementing Battle Bog, a top-down pixel-art competitive creature
brawler in Godot 4.6 (GDScript), migrating an existing playable prototype
called Hitmasters. The repo is at the project root; the main scene flow
(MainMenu → CharacterSelect → Arena) already works.

## Read these first, in order
1. `docs/BATTLE_BOG_DECISIONS.md` — locked design rulings. These are law.
2. `docs/BATTLE_BOG_BUILD_PLAN.md` — the milestone plan you are executing,
   including the target directory layout and per-milestone acceptance checks.
3. `data/battle_bog_roster.json` — the single source of truth for every
   creature stat, ability number, diet, and footprint.
4. `docs/BATTLE_BOG_SYSTEMS.md` and `docs/BATTLE_BOG_ROSTER.md` — context.

Authority order on any conflict: DECISIONS > BUILD_PLAN > SYSTEMS/ROSTER docs.
If something is still ambiguous after those, STOP and ask; do not invent a
design ruling.

## CURRENT MILESTONE
Implement **M0 — Foundation** exactly as specified in the build plan.
Do not start work from any later milestone, even where files for it are
mentioned in the layout.

## Hard rules
- `data/battle_bog_roster.json` is design-owned. Code reads it. Never edit,
  regenerate, reformat, or "fix" it. If you believe it contains an error,
  report it and continue.
- Never hardcode a creature stat or ability number in a script — read it from
  the catalog. Conversion constants (1 unit = 16 px; speed 1.0 = 91 px/s per
  decision #32) live only in `scripts/sim/sim_constants.gd`.
- No `Input.*` calls anywhere under `scripts/sim/` or in creature/kit logic.
  Exactly one human-input reader (in `scripts/ui/`) builds an InputFrame;
  everything downstream consumes InputFrame. Bots build InputFrames too.
- Gameplay logic runs in `_physics_process` (fixed 60 Hz). `_process` is for
  rendering/UI only. All sim randomness goes through one seeded
  RandomNumberGenerator owned by the match.
- Keep the existing Hitmasters demo playable until the plan explicitly removes
  a piece of it (player.gd hero paths are removed in M2, core waves in M4).
- Every creature you implement ships with a bot hook in the same milestone.
  A creature without a bot hook is an incomplete task.
- Visuals are procedural silhouettes in `scripts/visual/visual_style.gd` —
  do not add image assets or an asset pipeline.
- Match the existing code style: GDScript with tabs, typed variables where the
  existing code types them, snake_case files, no external addons.

## Verification (required before you call the milestone done)
1. Launch check: run the game headless to catch script errors:
   `godot --headless --path . --quit-after 300` must exit without script
   errors, and a normal editor/run launch must reach the Arena in 3v3.
2. Run the milestone's Acceptance list from the build plan item by item and
   report each as pass/fail with one line of evidence.
3. Run `grep -rn "Input\." scripts/sim` (and `scripts/game` kit files if they
   exist) — must be empty; include the empty result in your report.
4. Validate the roster JSON still parses and is byte-identical (you never
   touched it): report its file hash before and after.

## Working style
- Work in small commits, one plan task per commit, message prefixed with the
  milestone id (e.g. `M0: add input actions and InputFrame`).
- If an acceptance check fails, fix it before moving to the next task; do not
  defer failures silently.
- Finish with a summary: tasks completed, acceptance results, any ambiguities
  you hit and how you resolved them (with doc citations), and anything you
  recommend the designer re-check in play.
