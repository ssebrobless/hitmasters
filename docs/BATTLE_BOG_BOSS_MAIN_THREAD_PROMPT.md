# Battle Bog Boss Main Thread Prompt

Copy the prompt below into the main Codex thread when you are ready for it to absorb the boss work.

---

You are continuing Battle Bog in `C:\Users\fishe\OneDrive\Documents\hitmasters`.

The boss design work was developed in a side thread and is now captured in:

- `docs/BATTLE_BOG_BOSS_DESIGN.md`
- `docs/BATTLE_BOG_BOSS_AND_VISION_HANDOFF.md`
- `docs/RESEARCH_VISION_SUPERVIVE_AND_BATTLE_BOG.md`
- `docs/RESEARCH_SUPERVIVE_MECHANICS_FOR_BATTLE_BOG.md`

Please read these files before changing code. Treat `docs/BATTLE_BOG_BOSS_DESIGN.md` as the current source of truth for boss design unless it conflicts with locked project decisions. Treat `docs/RESEARCH_VISION_SUPERVIVE_AND_BATTLE_BOG.md` and `docs/RESEARCH_SUPERVIVE_MECHANICS_FOR_BATTLE_BOG.md` as research/inspiration docs unless they conflict with locked project decisions.

Confirmed boss system:

```text
+===================== BOSS SYSTEM =====================+
| Side bosses                                            |
|  bred-animal milestone -> team-side boss zone          |
|  owning team claim -> habitat buff + enemy disruption  |
|  enemy steal -> habitat buff only                      |
|                                                        |
| Center big bosses                                      |
|  spawn at 10:00 and 20:00                              |
|  random family from the five bosses                    |
|  50% larger model                                      |
|  map-wide attacks and environmental effects            |
|  special combat reward, stackable once if repeated     |
|  no enemy-side disruption reward                       |
+=======================================================+
```

Core loop tie-in:

```text
food / hunt / forage
  -> fill creature hunger
  -> deposit full-hunger creature at habitat
  -> habitat stock improves and breeding speed improves temporarily
  -> bred animals fill side-boss meter
  -> side boss spawns in fixed order
  -> boss rewards push team ecosystem and map pressure
  -> 10:00 and 20:00 center bosses create major PvPvE fights
```

Important rules:

- Side boss order should be fixed: Champsosaurus, Platyhystrix, American Mastodon, Arthropleura, Teratornis, then repeat.
- If a side boss is already active in a team's zone, newly bred animals should not count toward that team's next boss meter.
- Side bosses may fight in their home boss zone, nearby lane, and middle contest band, but should not chase deep into enemy territory while alive.
- If the owning team claims its own side boss, it receives the habitat-stock buff and sends that boss's terrain disruption to the enemy side.
- If the enemy steals the side boss, it receives the habitat-stock buff only.
- Center big bosses affect the whole map by default, so they never grant extra enemy-side disruption.
- Every major boss attack should follow: `TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint`.

Boss identities:

- Champsosaurus: flood ambush / water route controller. Small side boss controls streams and banks. Big boss makes water routes map-wide threats. Buff: +7% swim duration and +1.5% speed while in water. Big reward: periodic landed hit applies max-HP DOT.
- Platyhystrix: toxic hazard painter. Small boss paints toxic rings, leaps, and skin trails. Big boss creates map-wide poison rhythm. Buff: +5% healing from all sources and +2.5% HP regen. Big reward: periodic one-hit shield that slows breaker.
- American Mastodon: siege stampede / cover reshaper. Small boss plows, stomps, throws debris, and breaks cover. Big boss creates map-wide stampede corridors. Buff: +5% max HP and +2% all-source damage reduction. Big reward: out-of-combat regen speed boost.
- Arthropleura: moving trench / terrain scar. Small boss crawls predictable routes, sheds plates, and creates trenches. Big boss becomes a living map fault line. Buff: -6% hunger depletion and +4% creature/attack size. Big reward: kill-scaling team size/max-HP stacks, likely capped at 8-10 stacks.
- Teratornis: sky hunt / anti-comfort. Small boss uses shadows, gusts, and talon pins. Big boss creates map-wide reveal/wind pressure. Buff: +4% vision range and +1.5% move speed. Big reward: after no-damage window, next landed hit deals bonus damage.

Recommended implementation order:

1. Prototype Champsosaurus side boss first.
2. Prototype Teratornis center big boss second.
3. Extract shared boss framework: spawn meter, leash zones, telegraphs, body-part weakpoints, claim windows, reward routing, and terrain-event hooks.
4. Then add the remaining side bosses using the same framework.

Also note: vision research was done because the current game felt like it had no meaningful vision limitations. Before implementing Teratornis or night/day boss effects, read the vision research and make sure boss reveal/shadow/water effects connect to a shared team vision system instead of becoming separate one-off UI.

Vision direction:

- Current day/night mostly affects pacing and refreshes; it does not yet create strong information limits.
- Minimap should stop behaving like full global truth. Use team visibility, last-known ghosts, sound/ripple/rustle pulses, and objective/boss broadcasts.
- World view should use nearby clarity, cover/reed/water uncertainty, readable reveal tools, and day/dusk/night modifiers.
- Bots and target acquisition should use the same visibility rules as players where practical.
- Supervive is the feel reference: layered information from direct sight, sound pulses, scouting tools, stealth, reveal windows, and objective timing.

Supervive mechanics research direction:

- Use Supervive as inspiration for how macro economy, objectives, combat, terrain, information, and UI form one readable loop.
- The key translation is: `forage -> fill hunger -> deposit -> breed -> boss meter -> claim/steal`.
- Treat objectives as information events, not only rewards. Side boss wake-ups, center boss rolls, claim phases, and steals should be readable through world cues, minimap states, and simple event text.
- Keep Battle Bog's power mostly in-match. Do not add persistent out-of-match stat progression just because Supervive had Armory.
- Use anti-snowball through interaction: caps, decay, claim interruption, steal windows, visible comeback objectives, and bounties on heavily buffed creatures.
- UI should answer: what is happening, why it matters, where to go, and what can be done before it finishes.
