# Performance Research — Godot 4.6 Procedural-2D (compiled 2026-07-04)

Findings from a dedicated research pass (Godot docs + community sources),
grounded in this repo's actual code. Full details in the repo history; this
is the action list.

## Structural findings

- Godot caches _draw() command lists: a CanvasItem that never calls
  queue_redraw() costs ~zero script time. We currently queue_redraw
  EVERYTHING every frame (arena terrain, all creatures, minimap) — the
  single biggest cost in our architecture.
- CharacterBody2D.move_and_slide() collapses framerates around ~50 bodies
  (godotengine/godot#93184). Our minions peak 40+. Minions don't need
  physics bodies.
- Forward+ renderer buys nothing for pure 2D; Mobile/Compatibility have
  lower overhead.
- O(n) entity loops are fine at ~50 entities; the real hot spots are the
  20px-step LOS walks and per-frame AI target queries.
- RegEx.new() per ability cast (kit_helpers) and RandomNumberGenerator.new()
  per terrain rect per frame are avoidable allocations.
- Exit leak ("1 resource in use"): typically an autoload/static holding a
  Resource; hunt with --verbose; cosmetic.

## Ranked actions

| # | Action | Impact | Effort |
| --- | --- | --- | --- |
| 1 | Static terrain drawn ONCE on a child node (animated ripples on their own small node) | HIGH | M |
| 2 | Minions: Node2D + manual movement instead of CharacterBody2D/move_and_slide | HIGH | M-L |
| 3 | queue_redraw only on state change; skip off-screen entity redraws | HIGH | M |
| 4 | LOS: segment-vs-rect intersection instead of 20px point stepping | MED-HIGH | S |
| 5 | Cache compiled RegEx / pre-parse ability numbers at kit load | MED | S |
| 6 | Minimap at 5-10 Hz with baked background | MED | S |
| 7 | Bot/minion target queries on 0.1-0.2s timers | MED | S |
| 8 | Collision layer/mask hygiene | MED | S |
| 9 | HUD Label.text assigned only on change | LOW-MED | S |
| 10 | Renderer to mobile/compatibility; static typing in hot loops | LOW-MED | S |

Workflow rule: profile with max minions (Debugger > Profiler + Monitors;
--debug-canvas-item-redraw flag) before and after each change; do 1-3 first.

Key sources: docs.godotengine.org (custom_drawing_in_2d, cpu_optimization,
gpu_optimization, renderers, the_profiler, class_performance),
godotengine/godot#93184, #62995, #45512, GDQuest GDScript optimization.
