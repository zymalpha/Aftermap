# Dev Changelog — Stage 1 through Stage 13

> Internal delivery log. Public-facing entries go in `CHANGELOG.md` (repo root). One entry per stage; sub-bullets summarize what landed.

## Stage 1 — Repo scaffold (commit `97f64fc`)

- Initialized repo with planning docs and skeleton dirs (`game/`, `content/`, `tools/`, `tests/`, `docs/`).
- Captured `README_ORIG_PLANNING.md` as the design source of truth.
- Created `.gitkeep` placeholders for empty target dirs.

## Stage 2 — Tooling baseline (commit `e79e503`)

- `.gitignore` for Godot / Python / OS.
- `run.sh` + `run.bat` to drive Python schema check + Godot headless spike.
- `docs/` skeleton (adr / api / production subdirs).

## Stage 3 — P0 spike (commit `de4216c`)

- ADR set 0001–0006 (engine, renderer, RNG, saves, events, maps).
- JSON schemas for items / recipes / traits / events / chains / facilities / POI rooms.
- `tools/content_validator/validate.py` (Python, jsonschema).
- Sample content for every content kind.
- `GameSession` / `RNGService` / `Clock` / `Save` / `EventInterpreter`.
- 53 headless tests passing.

## Stage 4 — P0 spike close-out tests (commit `6b3b85f`)

- Added remaining P0 spike tests: `command_queue`, `grid_pathfind`, `pixel_scaling`.
- 53 → 114 PASS / 0 FAIL.

## Stage 5 — P1 spike (commit `c6c2320`)

- Tactical: grid + pathfind + movement + FOV + sound + alertness + combat + search + infection.
- Pixel-scaling presentation node + scene stub.
- `test_p1_tactical.gd` end-to-end tactical smoke.
- 114 → 166 PASS / 0 FAIL.

## Stage 6 — Documentation + delivery (commit `3f77c3d`)

- `docs/production/PROJECT_STATE.md` — spike status, risks, hard constraints, deliverables.
- `docs/production/BACKLOG.md` — P2–P6 card summaries.
- `docs/production/DECISIONS.md` — ADR index.
- `docs/production/CHANGELOG_DEV.md` — this file.
- `docs/api/game-session.md`, `tactical-session.md`, `content-db.md` — API contracts.
- `tools/build/run_tests.sh`, `tools/build/run_tests.bat` — test runners mirroring `run.sh` / `run.bat`.
- `README.md` — 30-min quick-start + acceptance checklist + known limits.
- `CHANGELOG.md` — public `v0.1.0` entry.

## Stage 7 — Bundle + push (commits `0389bcc`, `a07c73a`, `6a3f922`, `f5606e5`, `0876a67`)

- `git status` clean.
- `aftermap-p1.bundle` via `git bundle create --all`.
- `git bundle verify` PASS.
- `PUSH_INSTRUCTIONS.md` → `PUSH_COMMANDS.md` → `FIX_PUSH.md` with the GitHub push steps.
- `HOW_TO_VIEW.md` — 7 viewing paths, honest scope.
- 5 pixel-art SVG illustrations for README and docs.

## Stage 8 — P2 state machine + morning report (commit `a91a8c0`)

- `application/state_machine.gd` + `application/morning_report.gd`.
- First P2 spike test (test_p2_state_machine) — 26 PASS.

## Stage 9 — P2 character / relationship / memory / traits (commit `2fc24c1`)

- `domain/survivors/character.gd`, `relationship.gd`, `memory.gd`, `traits.gd`.
- `test_p2_characters.gd` — 40 PASS.

## Stage 10 — P2 inventory / base / jobs / world / content (commits `87b677a`, `30e4669`, `cf6b059`, `4e33044`)

- `domain/inventory/`, `domain/base/`, `domain/world/` modules.
- Expanded content: 12 items, 6 facilities, 10 events, 2 chains.
- 7-day longitudinal headless smoke (`test_p2_seven_days.gd`) — 12 PASS.
- Total P2 contribution: 184 PASS.

## Stage 11 — P3 map pipeline + GitHub hygiene (commits `05c2905`, `4b94f78`, `552e9ac`, `e21dc62`)

- `tools/map_pipeline/` Python module: osm_fetcher stub + 5 modules (city_graph_builder, geometry_processor, poi_classifier, manifest_generator, scenario_generator).
- Preset Nanjing manifest sample + schema.
- 40 pytest cases (classifier / graph / manifest / scenario).
- GitHub hygiene: emoji README + `.github/` templates + LICENSE + CI workflow.

## Stage 12 — P4 30-day campaign (commits `16719f4`, `5c7d177`, `c9b4c55`, `a0c0179`, `94397ff`)

- City pressure + 4-act state machine (`city_pressure.gd`, `act_state_machine.gd`).
- Migration subsystem + 5 endings (`migration.gd`).
- `GameSession` command extensions (stat_add / item_add / relationship / memory).
- Sample departure event with legacy choices.
- 100-seed x 30-day crash-free simulation passes (`test_p4_thirty_days.gd`) — 2 PASS / 0 FAIL.
- Total P4 contribution: 2 PASS.

## Stage 13 — v0.2 integration + bundle (this commit)

- Full regression sweep across all 12 GDScript tests + Python pytest + content validator.
- Updated `docs/production/PROJECT_STATE.md` to v0.2 status.
- Updated `docs/production/BACKLOG.md` with P2/P3/P4 marked done, P5/P6 prioritized.
- Updated `docs/production/CHANGELOG_DEV.md` (this entry).
- New `docs/production/V0.2_RELEASE_NOTES.md` — release notes for v0.2.
- Updated `CHANGELOG.md` with `v0.2.0` entry.
- Updated `README.md` roadmap (P0–P4 ✓, P5–P6 ⏳) + status badge to v0.2 + 352 PASS.
- Updated `PUSH_COMMANDS.md` + `FIX_PUSH.md` to advertise `aftermap-v0.2.bundle`.
- Updated `run.sh` to run the full P0–P4 + pytest suite.
- Generated `aftermap-v0.2.bundle` via `git bundle create --all`.
- Verified bundle with `git bundle verify`.
- Final result: 352 GDScript PASS / 40 pytest PASS / 49 content files validated / 0 FAIL across all paths.