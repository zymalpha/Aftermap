# Changelog

All notable changes to Aftermap are recorded here. The format is loosely
based on [Keep a Changelog](https://keepachangelog.com/) and the project
adheres to [Semantic Versioning](https://semver.org/).

## [v0.1.0] — 2026-07-22 — P0/P1 spike

### Added

- **Engine + tooling baseline.** Godot 4.6.2 project; Python content
  schema validator; `run.sh` / `run.bat` spike runner; jsonschema-based
  offline validator in `tools/content_validator/`.
- **ADR set 0001–0006** locking engine, renderer, RNG, save, event, and
  map-pipeline decisions (see `docs/adr/`).
- **Content schemas + samples.** JSON schemas for `items`, `recipes`,
  `traits`, `events`, `event-chains`, `facilities`, `poi-rooms`; one
  sample file per kind.
- **`GameSession` core.** Single mutator of persistent gameplay state.
  8 named RNG streams (ADR-0003). Atomic, versioned, SHA-256-verified
  saves with `.bak` fallback (ADR-0004). Whitelisted event AST
  interpreter (ADR-0005).
- **Tactical session (P1 spike).** Grid + A* pathfinder + step-driven
  movement + FOV (ray-cast, symmetric) + sound pulses + alertness state
  machine + combat + search + infection hooks + `PauseQueue` command
  queue + pixel-scaling presentation node.
- **Headless test spike.** `166 PASS / 0 FAIL` across:
  `test_rng_determinism`, `test_save_atomic_recovery`,
  `test_event_interpreter`, `test_command_queue`,
  `test_grid_pathfind`, `test_pixel_scaling`, `test_content_schema`,
  `test_stage3_smoke`, `test_p1_tactical`.
- **Documentation.** API contracts for `GameSession`, tactical session,
  and `ContentDB`; production docs (`PROJECT_STATE`, `BACKLOG`,
  `DECISIONS`, `CHANGELOG_DEV`); this `CHANGELOG.md`; `README.md`
  quick-start.

### Known limitations (carried forward to P2)

- OSM/Overpass fetch deferred to P3 (ADR-0006 gate).
- Save migration scaffolding not yet implemented (P2 `SAVE-2`).
- Combat / infection / survivors domains are stubbed but wired through
  `GameSession` (P2 `COMBAT-2`, `INF-2`, `CORE-1`).
- Localization adapter directory empty (P2 `LOC-1`).
- Only `tactical.tscn` scene stub exists (P5).

[v0.1.0]: #v010--2026-07-22--p0p1-spike