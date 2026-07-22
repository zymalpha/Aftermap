# Dev Changelog — Stage 1 through Stage 6

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
- 53 → 100+ PASS / 0 FAIL.

## Stage 5 — P1 spike (commit `c6c2320`)

- Tactical: grid + pathfind + movement + FOV + sound + alertness + combat + search + infection.
- Pixel-scaling presentation node + scene stub.
- `test_p1_tactical.gd` end-to-end tactical smoke.
- 100+ → 166 PASS / 0 FAIL.

## Stage 6 — Documentation + delivery (this commit)

- `docs/production/PROJECT_STATE.md` — spike status, risks, hard constraints, deliverables.
- `docs/production/BACKLOG.md` — P2–P6 card summaries.
- `docs/production/DECISIONS.md` — ADR index.
- `docs/production/CHANGELOG_DEV.md` — this file.
- `docs/api/game-session.md`, `tactical-session.md`, `content-db.md` — API contracts.
- `tools/build/run_tests.sh`, `tools/build/run_tests.bat` — test runners mirroring `run.sh` / `run.bat`.
- `README.md` — 30-min quick-start + acceptance checklist + known limits.
- `CHANGELOG.md` — public `v0.1.0` entry.

## Stage 7 — Bundle + push (next commit)

- `git status` clean.
- `aftermap-p1.bundle` via `git bundle create --all`.
- `git bundle verify` PASS.
- `PUSH_INSTRUCTIONS.md` with the GitHub push steps.