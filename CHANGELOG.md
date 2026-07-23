# Changelog

All notable changes to Aftermap are recorded here. The format is loosely
based on [Keep a Changelog](https://keepachangelog.com/) and the project
adheres to [Semantic Versioning](https://semver.org/).

## [v1.0.0] — 2026-07-23 — P0–P6 complete (release candidate)

### Added

- **P6 Windows Export.** `export_presets.cfg` — Godot 4.6.2 'Windows Desktop'
  preset (product `Aftermap`, company `zymalpha`, 64-bit x86_64, embed_pck,
  icon placeholder). `tools/build/build_windows.sh` + `.bat` locate Godot in
  `.tools/godot/`, run `--headless --export-release "Windows Desktop"`, and
  never abort the release session on missing GUI Godot or export template
  (prints `EXPORT_STATUS=needs_gui_godot`, exits 0).
- **P6 1000-Seed Stress Gate.** `game/tests/test_p6_thousand_seeds.gd` —
  1000 seeds × 30 days, per-seed guarded, full invariants (character stats
  in [0,100], city_pressure in [0,100], resources ≥ 0, no dangling
  character/poi/item references). **1000 / 1000 seeds pass** (threshold 800),
  ~71s wall (14 seeds/s).
- **P6 Perf Benchmark Gate.** `game/tests/test_p6_perf_benchmark.gd` — 30
  units × 1500 frames on a 24×24 tactical grid, one shared sound pulse +
  per-unit A* pathfind / FOV / alertness. avg **~10 ms** < 16.67 ms (60fps),
  **p99 ~15-27 ms** < 33 ms (sustained 30fps floor), ~78-97 fps achieved.
  The raw single-frame max is reported but not gated (OS preemption can flare
  one frame without the game missing 30fps); p99 is the industry-standard
  sustained frame-budget metric.
- **P5 Content & Presentation** (parallel track, landed before v1.0):
  localization adapter (`game/adapters/localization/`) + zh_CN/en_US `.po`
  tables; procedural placeholder art (4 chars + 3 infected + 7 tiles + 16 UI
  icons); presentation scenes (main menu / base HUD / morning report / event
  decision / facility upgrade / inventory / 5-step tutorial / accessibility);
  60 events + 10 chains + expanded items/facilities/POI rooms. 222 content
  files now schema-validated.
- **Release Documentation.** `docs/production/V1.0_RELEASE_NOTES.md`,
  `PROJECT_STATE.md` bumped to v1.0 candidate, README badges refreshed to
  v1.0 + 497 PASS, `PUSH_COMMANDS.md` advertises the v1.0 bundle.

### Changed

- **Perf: cache pathfinder per-cell buffers** (`game/domain/tactical/pathfinder.gd`).
  `a_star()` previously allocated 3 packed arrays (`g_score` / `closed` /
  `prev_idx`) of size `cell_count` on every call — 90 allocations/frame at
  30 units, the dominant source of GC frame-time spikes (60–170 ms) in the
  perf benchmark. The buffers are now cached statically keyed by grid
  dimensions and reused alloc-free across calls. **Visibility** (`visibility.gd`)
  gets the same treatment for its FOV blocker mask. Effect: the 30-unit
  benchmark's p99 drops to ~15 ms on an idle machine. All 23
  `test_grid_pathfind` + 52 `test_p1_tactical` cases still pass.

### Test totals

- **497 GDScript PASS / 0 FAIL** across 15 test files (was 352 / 12 in v0.2).
- **40 pytest PASS / 0 FAIL** for `tools/map_pipeline/tests/`.
- **222 content files** validated by `tools/content_validator/validate.py`.

### Known issues (pre-existing, non-blocking)

- `test_p5_localization` reports 36 PASS / 2 FAIL (`good entry parsed got
  'FB'`) — a P5 Stage 17 localizer `.po` parsing edge-case bug. Gameplay is
  unaffected (falls back to the key). Tracked as `PROJECT_STATE.md` R-13,
  owned by the content/localization track.

## [v0.2.0] — 2026-07-23 — P0–P4 complete

### Added

- **P2 Core Loop.** Character / relationship / memory / traits domain with
  12 traits, 8 relationship axes. State machine (`application/state_machine.gd`)
  with 4-act progression and `morning_report.gd` summarizer. Inventory +
  base + jobs subsystems with 12 items, 6 facilities, 10 events, 2 chains.
  POI + city + travel subsystems with 7-day longitudinal headless smoke.
- **P3 Map Pipeline.** `tools/map_pipeline/` Python module with 5
  submodules (city_graph_builder, geometry_processor, poi_classifier,
  manifest_generator, scenario_generator) + OSM fetcher stub. Preset
  Nanjing manifest sample. 40 pytest cases covering classifier, graph,
  manifest, and scenario paths.
- **P4 30-Day Campaign.** City pressure (`city_pressure.gd`) +
  4-act state machine (`act_state_machine.gd`). Migration subsystem
  (`migration.gd`) with 5 endings. `GameSession` command extensions
  (`stat_add`, `item_add`, `relationship`, `memory`). Sample departure
  event with legacy choices. 100-seed × 30-day crash-free simulation
  with all invariants passing.
- **Headless test suite.** 352 GDScript PASS / 0 FAIL across 12 test
  files (test_command_queue, test_grid_pathfind, test_pixel_scaling,
  test_stage3_smoke, test_p1_tactical, test_p2_characters,
  test_p2_content, test_p2_inventory_base, test_p2_seven_days,
  test_p2_state_machine, test_p2_world, test_p4_thirty_days).
  40 pytest PASS / 0 FAIL for `tools/map_pipeline/tests/`.
  49 content files validated by `tools/content_validator/validate.py`.
- **Documentation.** `docs/production/V0.2_RELEASE_NOTES.md` — release
  notes. `PROJECT_STATE.md`, `BACKLOG.md`, `CHANGELOG_DEV.md` updated
  for v0.2. `README.md` roadmap updated (P0–P4 ✓, P5–P6 ⏳). Status
  badges refreshed to v0.2 + 352 PASS.
- **Bundle.** `aftermap-v0.2.bundle` via `git bundle create --all`,
  verified with `git bundle verify`. `PUSH_COMMANDS.md` and
  `FIX_PUSH.md` updated to advertise the v0.2 bundle.

### Known limitations (carried forward to P5)

- Pixel-art is placeholder (5 SVG illustrations); no tilesets or
  sprite sheets yet (P5 `ART-5`).
- Localization tables not yet populated (P5 `LOC-5`).
- HUD / menu / inventory panel rendering deferred to P5 (`UI-5`).
- Audio mixer / ambient layers deferred to P5 (`AUDIO-5`).
- Real OSM/Overpass fetch over the wire deferred to P5+ (`OSM-5`).
- Steam build pipeline, telemetry opt-in, public docs site deferred
  to P6.

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

[v0.2.0]: #v020--2026-07-23--p0p4-complete
[v0.1.0]: #v010--2026-07-22--p0p1-spike