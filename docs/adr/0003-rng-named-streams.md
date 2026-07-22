# ADR-0003: RNG — 8 named streams, seeded, deterministic; `cosmetic_only` never affects gameplay

- Status: Accepted
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.2 item 4 / §11.12 / §11.22.1 / §12.4 P0 spike `rng_named_streams`

## Context

§11.2 item 4 states: "随机可复现：所有影响玩法的随机数来自命名随机流并存档".
§11.12 specifies the streams explicitly:

- `world_generation`
- `city_state`
- `poi_scene_<poi_id>`
- `daily_director_<day>`
- `event_<event_instance_id>`
- `combat_<tactical_session_id>`
- `character_generation`
- `cosmetic_only`

The hard requirement (§14.七 item 5) is: identical snapshot + content
version + seed + command sequence must yield identical end state. Without
stream isolation, a single ambient rain particle draw could perturb the
next combat roll, violating §11.22.1 determinism tests.

## Decision

1. **`RngService` is the only random source** in the project. Global
   helpers `randf` / `randi` from GDScript are forbidden in domain
   modules. They may appear only inside the `cosmetic_only` stream,
   never in `world_generation`, `city_state`, `poi_scene_*`,
   `daily_director_*`, `event_*`, `combat_*`, `character_generation`.
2. **Stream naming** matches §11.12 verbatim. The `cosmetic_only`
   suffix indicates a non-gameplay stream — ambient rain, dust, a
   purely cosmetic idle animation variant, etc. It must be physically
   separated in memory; it cannot share entropy with any other
   stream.
3. **`world_generation` is seeded once at session creation**. Other
   streams derive from the same seed via
   `SeedMix(parent_seed, "<stream_name>")` so that two sessions with
   the same seed deterministically re-create the same streams.
4. **Stream state is part of the save header**. We persist either the
   current counter (preferred) or a hash that allows the same counter
   to be re-derived (§11.12). Save migration must keep the stream
   scheme compatible across versions.
5. **Deterministic test promise**: any test that compares two
   sessions runs them under the same seed and same command sequence
   and asserts equality of a canonical state hash (§11.12 last line).

## Consequences

Positive:
- Combat, infection, event outcomes, loot draws become reproducible;
  replays and reloading a save give the same narrative.
- The `cosmetic_only` stream physically cannot influence combat: even
  a bug that draws `cosmetic_only` from a gameplay call site only
  produces a different dust mote.
- AI can author and review test cases by fixing the seed and the
  command log (§11.22.3).

Negative / constraints:
- The save header grows by the number of active streams; we mitigate
  by storing compressed counters for "long but stable" streams
  (`world_generation` typically counts in the tens of thousands).
- Stream name strings live in saves, content, and scripts. Adding a
  new stream is a content schema change and bumps the content
  fingerprint (§11.7 item 6).

## Alternatives Considered

- **Single global seeded RNG** — Rejected: a single counter cannot
  keep `cosmetic_only` from polluting gameplay (§11.2 item 4).
- **Per-call seeded splitmix (`hash(seed, index)`)** — Rejected: cool
  idea, but breaks the determinism across save/load because save
  cannot record the exact draw count without contention with cosmetic
  draws.
- **Game Maker-style global `randomise()` per scene** — Rejected:
  explicitly disallowed by §11.2 item 4 / §14.七 item 5.

## Open Questions

- Whether `cosmetic_only` ever warrants serialisation. Current call:
  no. Cosmetic state is regenerated at session start from the seed.
  If a future need arises (e.g. a long-running animation queue that
  must resume after load), this ADR is amended, not bypassed.

## Impact Surface

- `game/core/RngService.gd` (P0 task).
- `game/core/SeedMix.gd` (deterministic stream derivation).
- Save header schema (Stage 3 will formalise; this ADR pins the names).
- `tests/unit/test_rng_named_streams.py` — uses same seed twice, asserts
  domain-hash equal, draws from `cosmetic_only` does not.
