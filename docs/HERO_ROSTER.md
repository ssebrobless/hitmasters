# Initial Hero Roster

```text
╔════════════════════════════════════════════════════════════╗
║ Six-Archetype Starter Roster                              ║
╠══════════════╦══════════════╦══════════════╦══════════════╣
║ Frontline    ║ Flank        ║ Midline      ║ Backline     ║
╠══════════════╬══════════════╬══════════════╬══════════════╣
║ Iron Vanguard║ Blinkblade   ║ Burst Rifle  ║ Longshot     ║
║ tank         ║ assassin     ║ rifler       ║ sniper       ║
╠══════════════╩══════════════╬══════════════╩══════════════╣
║ Support                    ║ Control Support              ║
╠═════════════════════════════╬══════════════════════════════╣
║ Lifewarden                  ║ Chorus                       ║
║ healer mage                 ║ bard-style buff/debuff       ║
╚═════════════════════════════╩══════════════════════════════╝
```

## Shared Stat Scale

| Stat | Meaning |
| --- | --- |
| health | Durability before death |
| speed | Base movement speed |
| attack_range | Effective primary attack distance |
| primary_damage | Expected primary attack damage |
| difficulty | Relative mechanical/decision difficulty |

## Iron Vanguard

Slow, tanky physical frontline. Creates space, blocks routes, and protects
teammates during wave pushes.

| Lever | Value |
| --- | --- |
| health | 140 |
| speed | 250 |
| attack_range | short |
| primary_damage | 18 |
| difficulty | 2 |

Abilities:

- `Primary`: heavy melee swing with a short windup.
- `Dash`: short armored shoulder charge.
- `Control`: shield bash that interrupts channeled or aimed abilities.
- `Utility`: guard stance that reduces incoming frontal damage.

Counterplay:

- Kite him.
- Bait the charge.
- Attack from angles that bypass guard stance.

## Blinkblade

Fast physical assassin. Wins by flanking, forcing cooldowns, and finishing
isolated targets.

| Lever | Value |
| --- | --- |
| health | 80 |
| speed | 340 |
| attack_range | short |
| primary_damage | 16 |
| difficulty | 4 |

Abilities:

- `Primary`: fast blade combo.
- `Dash`: blink slash through a target line.
- `Control`: mark target; next hit consumes mark for bonus damage.
- `Utility`: brief vanish or untargetable sidestep.

Counterplay:

- Group up.
- Hold peel until after blink.
- Punish the exit path.

## Burst Rifle

Mid-range rifler. The baseline shooter character: consistent damage, clear aim
test, strong wave clear.

| Lever | Value |
| --- | --- |
| health | 100 |
| speed | 300 |
| attack_range | medium |
| primary_damage | 10 per shot |
| difficulty | 3 |

Abilities:

- `Primary`: three-round burst projectile.
- `Dash`: combat slide that reloads one burst.
- `Control`: suppressive cone that slows enemies hit.
- `Utility`: piercing shot for minion wave clear.

Counterplay:

- Dodge sideways during burst rhythm.
- Close distance after slide is used.
- Use cover to break firing lanes.

## Longshot

Sniper rifler. Controls long sightlines and punishes predictable movement, but
struggles when rushed.

| Lever | Value |
| --- | --- |
| health | 75 |
| speed | 280 |
| attack_range | long |
| primary_damage | 35 charged |
| difficulty | 5 |

Abilities:

- `Primary`: charged precision shot.
- `Dash`: short backward roll.
- `Control`: trap flare that reveals and slows.
- `Utility`: focus mode for one empowered line shot.

Counterplay:

- Deny sightlines.
- Force movement before the shot is charged.
- Dive after backward roll is spent.

## Lifewarden

Ranged magic healer support. Keeps teammates alive through aimed healing and
protective timing rather than passive aura sustain.

| Lever | Value |
| --- | --- |
| health | 90 |
| speed | 295 |
| attack_range | medium |
| primary_damage | 8 |
| difficulty | 4 |

Abilities:

- `Primary`: magic bolt that damages enemies.
- `Dash`: short blink that leaves a small healing pulse.
- `Control`: aimed healing beam or projectile.
- `Utility`: timed barrier that absorbs one burst window.

Counterplay:

- Pressure healer positioning.
- Dodge or body-block healing lines.
- Bait the barrier, then re-engage.

## Chorus

Bard-style team buff and enemy debuff support. Alters fight tempo through
skillshot buffs, slows, and timing windows.

| Lever | Value |
| --- | --- |
| health | 95 |
| speed | 305 |
| attack_range | medium |
| primary_damage | 7 |
| difficulty | 5 |

Abilities:

- `Primary`: rhythmic note projectile.
- `Dash`: tempo step that briefly speeds nearby allies.
- `Control`: dissonant chord that weakens enemy damage.
- `Utility`: rally beat that grants a short movement and attack-speed window.

Counterplay:

- Disengage during rally beat.
- Spread to reduce multi-target value.
- Punish missed dissonant chord cooldown.

