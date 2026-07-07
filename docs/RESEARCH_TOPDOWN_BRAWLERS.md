# Research: What LoL / Battlerite / Supervive Teach Battle Bog

Compiled 2026-07-04 from published design analyses, wikis, and developer
deep-dives. Each finding ends with the Battle Bog implication and where it
lands in the build plan.

## Supervive (closest relative: top-down + real verticality)

1. **Verticality is a risk system, not just movement.** Gliding generates
   Heat; overheating damages you and leaves you vulnerable. Taking ANY damage
   while gliding stuns you and smashes you down (their Smash-Bros-style
   "spike"). Vertical mobility is powerful BECAUSE it is interruptible.
   - *Battle Bog:* our flight meter is the Heat analog. IMPLEMENTED
     (decision #20): heavy ranged hits (>=30 dmg) on a flying bird force a
     grounding ("spiked"), triggering the 3s no-takeoff lockout. Gives every
     roster a bird answer while always-flying bugs keep their unique rules.
2. **Every hunter has a movement ability; momentum is preserved and
   chainable** (glide + dash + jump pads). Movement mastery is the skill
   ceiling.
   - *Battle Bog:* our kits mostly have one mobility tool. IMPLEMENTED:
     dash end velocity bleeds into a short render/sim drift instead of
     stopping dead.
3. **Feathering (glider e-brake tricks) emerged from physics, not scripts.**
   Depth-based mechanics breed technique.
   - *Battle Bog:* keep flight/swim as continuous meters (already true), never
     binary states, so edge techniques can emerge (e.g., surfacing for one
     frame to reset a swim tick).
4. **Camera: "Fully Dynamic" cursor-led camera with a deadzone** is the
   competitive standard — screen centers between you and your cursor so you
   see where you aim.
   - *Battle Bog:* IMPLEMENTED — camera leads toward the cursor with a
     deadzone and clamp (arena camera).
5. **Elevation reads through shadows and two-stage motion** (impulse up, then
   decelerate).
   - *Battle Bog:* IMPLEMENTED: airborne shadows scale by height/low-window,
     and bird transitions expose charge, lift flap, landing flare, and
     grounded-lockout cues.

## Battlerite (closest relative: the combat feel target)

6. **Everything is a skillshot; nothing auto-aims.** Responsibility for every
   hit is the source of the ranked feel.
   - *Battle Bog:* already our rule. Never add homing for "accessibility."
7. **Move-while-casting with per-ability movement multipliers** made
   Battlerite feel fluent vs. its stop-cast predecessor.
   - *Battle Bog:* attacks don't root us — good. Give each ability an explicit
     `move_mult_while_casting` when kits mature (M7) instead of ad-hoc roots.
8. **Energy instead of mana: landing hits charges a spendable bar** — resource
   comes from skill expression, not regeneration.
   - *Battle Bog:* our no-mana cooldown design matches. Food/hunger already
     fills the "earned resource" slot; do not add a second combat resource.
9. **No downtime: rounds are pure teamfight.** Battlerite cut everything
   between fights.
   - *Battle Bog:* we intentionally keep macro (lanes/food), but 1v1 mode
     leans Battlerite through faster hunger, quicker waves, one hut per side,
     and compact pressure on the shared expanded map.

## League of Legends (macro + readability standards)

10. **Map ratios** (16,000 units, ~45-60s traversal, attack ranges <1% of map
    width, camera sees ~10%) — applied in the V1 map rescale.
11. **Telegraph grammar is a contract:** windup poses, colored decals, and
    consistent shapes mean every death is legible. Riot's rule: clarity beats
    spectacle.
    - *Battle Bog:* our windup cones + body poses follow this. Rule: every
      new kit ability MUST ship a telegraph in the same visual grammar
      (growing danger fill = incoming, team-color flash = resolved).

## Game-feel literature (juice, applied carefully)

12. **Animation beats particles for conveying weight**; juice cannot fix
    shallow mechanics, and over-juicing destroys readability.
    - *Battle Bog:* invest in body-part animation (done: necks, tongues,
      spines) before particles. Screen shake stays reserved for ≥50 dmg hits.
13. **Hit-stop (2-4 frame freeze on heavy hits)** is the cheapest weight tool
    after animation.
    - *Battle Bog:* IMPLEMENTED (decision #26): freeze attacker+victim render
      3 frames on hits >=50 (render-only, sim unaffected).

## Priority actions

| # | Action | When |
| --- | --- | --- |
| 1 | Cursor-led camera with deadzone | DONE |
| 2 | "Spiked" rule for flying birds hit by heavy ranged | DONE (decision #20) |
| 3 | 1v1 tuned as the Battlerite-pace mode | DONE (M8 tuning) |
| 4 | Per-ability move_mult_while_casting field | M7 kit waves |
| 5 | Two-stage takeoff/landing ease + shadow scale | DONE (M8) |
| 6 | Hit-stop on >=50 dmg | DONE (decision #26) |
| 7 | Dash momentum bleed-out | DONE (M8) |

Sources: SUPERVIVE Wiki (Gliding, Getting Started), Deltia's camera/controls
guides, Rolling Stone and GameRant Supervive previews, Dignitas intro guide,
Game Developer "Turning Bloodline Champions into Battlerite" deep dive,
Wayline "The Juice Problem", LoL Wiki Summoner's Rift.
