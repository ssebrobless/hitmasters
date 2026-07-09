# Vision Research: Supervive Reference And Battle Bog Direction

This document summarizes quick current research into Supervive-style vision/information pressure and translates it into Battle Bog recommendations.

## Current Battle Bog State

```text
╔════════════════ CURRENT IMPLEMENTATION ════════════════╗
║ Day cycle                                               ║
║  arena.gd has a deterministic 120s day timer            ║
║  dawn refreshes wild food                               ║
║                                                        ║
║ Line of sight                                           ║
║  cover rects block targeting LOS                        ║
║  closest-enemy targeting respects cover LOS             ║
║                                                        ║
║ Stealth                                                 ║
║  creatures can be stealthed                             ║
║  some target selection skips stealthed enemies           ║
║                                                        ║
║ Minimap                                                 ║
║  currently draws live entities/food/zones broadly        ║
║  no team vision/fog gate in minimap visibility yet       ║
║                                                        ║
║ Gap                                                     ║
║  day/night changes pacing but not actual information     ║
║  so play can feel like there are no vision limits        ║
╚════════════════════════════════════════════════════════╝
```

Relevant local notes:

- `docs/BATTLE_BOG_DECISIONS.md`: one in-match day is 120 seconds; wild fauna/flora refresh at dawn.
- `docs/ROSTER_WAVE_PLAN.md`: explicitly notes no fog-of-war exists yet.
- `scripts/game/arena.gd`: `get_day_state()`, `_tick_day_cycle()`, `has_line_of_sight()`, and cover-block checks exist.
- `scripts/ui/minimap.gd`: `_is_visible_entity()` currently mostly checks alive/valid state.

## Confirmed Supervive Facts

Sources:

- Supervive Season 2 patch notes: https://store.steampowered.com/news/posts/?appgroupname=GameGuru+-+Easter+Game&enddate=1761094852&feed=steam_community_announcements
- Supervive 1.05 patch search summary: https://store.steampowered.com/news/app/1283700/view/543369627969782426
- Supervive wiki, Raven Spy: https://supervive.wiki.gg/wiki/Raven_Spy
- Supervive wiki, Scan Grenade: https://supervive.wiki.gg/wiki/Scan_Grenade
- Supervive wiki, Stealth Cloak: https://supervive.wiki.gg/wiki/Stealth_Cloak
- Supervive wiki, Delicate X-Ray Goggles: https://supervive.wiki.gg/wiki/Delicate_X-Ray_Goggles
- Supervive wiki, Nightstalker Soul: https://supervive.wiki.gg/wiki/Nightstalker_Soul
- Supervive wiki, Objective Timers: https://supervive.wiki.gg/wiki/Objective_Timers

Confirmed from accessible sources/snippets:

- Supervive uses off-screen sound information. Season 2 notes say enemy sounds were represented through minimap radar pulses, and that edge-of-screen visual pulses were added too.
- Supervive used day/night as objective pacing. Patch notes changed bosses from spawning at night to spawning 60 seconds after each new day.
- Supervive has scout/reveal tools, including Raven Spy, which grants vision based on height, and Scan Grenades, which can grant vision over walls.
- Supervive has stealth/information-denial tools, including Stealth Cloak.
- Supervive has conditional vision advantages such as Delicate X-Ray Goggles seeing moving enemies through walls while sneaking at full health.
- Supervive has team-wide information/stealth rewards such as Nightstalker Soul making a team stealthed after being out of combat.

## Design Inferences From Supervive

```text
╔════════════════ SUPERVIVE-LIKE FEEL ════════════════╗
║ Vision is not only a radius                         ║
║  it is sound + movement + scouting + objectives      ║
║                                                     ║
║ Minimap is partial truth                             ║
║  pulses and last-known info matter more than full GPS║
║                                                     ║
║ Day/night is pacing                                  ║
║  it tells teams what kind of risk window they are in ║
║                                                     ║
║ Stealth has readable counters                        ║
║  scanning, sound, movement, and reveal tools matter  ║
╚═════════════════════════════════════════════════════╝
```

Supervive's useful lesson for Battle Bog is not "copy its exact systems." The useful lesson is that players should feel a layered information game:

- What I can directly see.
- What my team has revealed.
- What I heard or saw pulse.
- What the minimap remembers as last-known.
- What terrain is hiding or distorting.
- What a boss event is broadcasting.

## Battle Bog Vision Goals

```text
╔════════════════ BATTLE BOG VISION GOALS ════════════════╗
║ Day                                                    ║
║  scouting is broad, minimap is more reliable            ║
║                                                       ║
║ Dusk/Night                                             ║
║  direct vision shrinks, sound/pulse info matters more   ║
║                                                       ║
║ Bushes/Reeds                                           ║
║  hide idle/slow creatures, reveal movement/attacks      ║
║                                                       ║
║ Water                                                  ║
║  gives ripple clues, not perfect visibility             ║
║                                                       ║
║ Boss Events                                            ║
║  temporarily rewrite visibility rules                   ║
╚════════════════════════════════════════════════════════╝
```

Recommended model:

```text
Entity visible if any of these is true:
  direct line-of-sight within vision radius
  revealed by ability/status
  visible because it attacked / took damage / harvested
  visible because it produced sound pulse
  visible as last-known minimap ghost within memory duration
```

## Day/Night Recommendation

Use the existing 120-second day as a full day/night loop, not just a dawn timer.

```text
0-70s    Day
  normal vision
  minimap shows currently visible enemies and fresh last-known ghosts

70-95s   Dusk
  vision starts shrinking
  reeds/bushes become stronger
  sound pulses become more important

95-120s  Night
  direct enemy vision reduced
  minimap does not show exact enemy positions unless revealed
  loud actions create pulse indicators
  bioluminescent/firefly effects become especially valuable

120s     Dawn
  food refresh
  vision clears
```

Suggested first tuning values:

```text
Day enemy vision radius:      22u
Dusk enemy vision radius:     17u
Night enemy vision radius:    12u
Ally vision sharing radius:   normal direct reveal to team
Minimap exact enemy icon:     only while currently revealed
Minimap last-known ghost:     3s day, 5s dusk, 6s night
Sound pulse radius:           depends on action loudness
```

## Minimap Recommendation

Current minimap should stop being global truth.

```text
╔════════════════ MINIMAP INFORMATION LAYERS ════════════════╗
║ Always visible                                             ║
║  allied creatures, allied huts/core/habitat, known terrain  ║
║                                                           ║
║ Conditionally visible                                      ║
║  enemies only if currently seen/revealed                   ║
║  wildlife only if seen/revealed or in owned zones           ║
║  food only if seen recently or inside owned habitat vision  ║
║                                                           ║
║ Uncertain info                                             ║
║  sound pulses, last-known ghosts, boss warning zones        ║
╚═══════════════════════════════════════════════════════════╝
```

Implementation direction:

- Add a team vision service/cache in `arena.gd`.
- Add `is_visible_to_team(entity, viewer_team)` and `get_minimap_visibility(entity, viewer_team)`.
- Change `scripts/ui/minimap.gd` to draw exact icons only if visibility is current.
- Draw last-known enemy positions as faded hollow icons.
- Draw sound pulses as rings/arcs, not exact dots.

## Bushes, Reeds, Trees, Rocks, Water

Terrain should shape information.

```text
Reeds/Bushes
  idle or slow movement: hidden unless enemy is close
  fast movement: creates rustle pulse
  attack/harvest: reveals briefly
  taking damage: reveals briefly

Trees/Rocks
  block line-of-sight
  tall perches extend vision but reveal perch silhouette

Water
  swimming creates ripple pulse
  diving/ambush creatures can be hidden under water
  attacks in water reveal exact position briefly
  Champsosaurus events make water pulses less trustworthy
```

## Creature-Specific Hooks

Existing roster hooks already point toward a good vision ecosystem:

- Owl perch: increase vision and create elevated scout role.
- Owl Silent Flight: stealth scouting, but reveal on attack/use/grounding.
- Wolf Spider Simple Eyes: strong facing cone day/night; anti-stealth/reveal cone.
- Firefly Bioluminescence: constant small light radius and reveal/heal identity.
- Leech Sensory Crypt: water-body reveal.
- Teratornis boss buff: vision range and movement speed.

Recommendation:

```text
Firefly = night support / light anchor
Owl = high-risk scout / perch vision
Wolf Spider = directional anti-stealth
Leech = water information specialist
Teratornis boss = team vision macro reward
```

## Boss Event Vision Effects

Boss events should temporarily bend the vision rules:

```text
Champsosaurus
  water ripples everywhere; true enemy water movement is harder to distinguish
  big attacks reveal water lanes before impact

Platyhystrix
  toxic clouds obscure minimap exactness in affected zones
  glowing sail provides very clear danger telegraphs

American Mastodon
  dust/mud clouds create temporary local vision loss
  broken trees remove cover afterward

Arthropleura
  trench/slime trails remain visible on minimap
  coil arena blocks or heavily distorts outside vision

Teratornis
  sky shadows reveal and threaten lanes
  wing gust flattens reeds and removes temporary cover
```

## First Implementation Slice

```text
1. Add team vision radii by day phase
2. Gate minimap enemy icons through team visibility
3. Add last-known minimap ghosts
4. Add sound/rustle/ripple pulses
5. Make bushes/reeds hide idle enemies
6. Wire creature reveal abilities into the same visibility service
```

This should immediately fix the current playtest issue where night/day exists but does not meaningfully limit information.

