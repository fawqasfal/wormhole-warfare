# Wormhole Warfare

A PvP total-conversion mod for Factorio: Space Age (2.0+). Every player gets their own
world (surface + force). A wormhole space location past Aquilo lets endgame players send
raiders into rivals' worlds. Diplomacy contracts let the parties sign tribute-for-peace
treaties that enforce timed ceasefires.

## How to play

1. Each player claims a personal world — automatic on first join (mod setting), or via
   `/ww-claim`. The claim creates a private force (with the shared force's research
   copied over) and a freshly generated Nauvis-like surface, and teleports you there.
2. Research **Wormhole stabilization** (requires cryogenic science) to reveal the
   **Wormhole** space location past Aquilo.
3. Fly a space platform to the wormhole. While aboard a platform parked there, use the
   **Wormhole invasion** shortcut to pick a target from players with claimed worlds.
4. Invading teleports you to a beachhead ~250 tiles from the defender's spawn (setting).
   The raid ends when you die, retreat (`/ww-retreat`), disconnect, run out the invasion
   timer, or sign a treaty. Destroying defender structures and killing the defender
   accrues war score, announced when the raid ends.
5. Every raid ends with an automatic short truce (setting). For longer peace, open the
   **Diplomacy** shortcut and propose a contract: a tribute (N × item, paid by either
   party) in exchange for a ceasefire of M minutes. Accepting physically transfers the
   items and sets a mutual cease-fire that expires on schedule — with a warning to both
   sides when hostilities may resume.

## Architecture

| File | Responsibility |
| --- | --- |
| `data.lua` | Wormhole `space-location` + `space-connection` (deepcopied from Space Age's solar-system-edge prototypes so sprites/asteroids stay valid), unlock technology, two shortcuts |
| `scripts/state.lua` | `storage` schema, id allocation, force-pair keys, ceasefire lookup |
| `scripts/worlds.lua` | World claiming (force + surface lifecycle), research copy, force-cap guard, cleanup on player removal |
| `scripts/invasion.lua` | Eligibility checks, beachhead placement/charting, war-score tracking, every end-of-raid path (timeout/death/retreat/disconnect/treaty), post-raid truce |
| `scripts/diplomacy.lua` | Contract propose/accept/reject/cancel, tribute transfer, ceasefire enforcement and expiry |
| `scripts/gui.lua` | Invasion target picker; diplomacy window (contract form, incoming/outgoing proposals, active ceasefires) |
| `control.lua` | Event wiring, platform-arrival announcements, commands |

## Design constraints this mod works within

- **Deterministic lockstep.** All logic must be deterministic across clients: no
  `os.*`, no local randomness (Factorio's `math.random` is synced game state), all
  persistent state in `storage`. GUI interactions arrive as replayable events.
- **64-force hard cap.** One force per player world; the mod refuses claims past 60 and
  recycles forces (`merge_forces` into neutral) when players are removed.
- **New forces know nothing.** Research is per-force, so claims copy the researched set
  from the player's previous force.
- **Items must physically move.** Tribute is removed from the payer's inventory and
  inserted into the payee's (spilling overflow) — no conjuring resources.
- **UPS scales with active surfaces.** Each claimed world simulates independently.
  Surfaces of removed players are deleted; freezing offline players' worlds is future
  work.

## Roadmap / ideas

- Contraband rules: whitelist what invaders may carry through the wormhole.
- Explicit war goals (destroy the silo, hold the beachhead, steal science) with
  automatic treaty terms proposed to the loser.
- War exhaustion / raid cooldowns per attacker, and alliance (friend) pacts.
- Espionage: a cheaper wormhole trip that only grants a snapshot of the target's map.
- Platform blockades: intercepting a rival's platform parked at the wormhole.
- Contract escrow via a physical "treaty chest" instead of character inventories.
- Locale-proof GUI strings (contract rows are plain English currently).

## Development

Load-test without launching the full game:

```sh
factorio --mod-directory <dir-with-symlink-and-mod-list> --create /tmp/test.zip   # data + on_init
factorio --mod-directory <dir> --benchmark /tmp/test.zip --benchmark-ticks 600    # tick handlers
```

Real invasion/diplomacy flows need two players: start a local multiplayer game and
connect a second instance with `--mp-connect localhost`.

