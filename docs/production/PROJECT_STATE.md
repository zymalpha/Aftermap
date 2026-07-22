# Project State — Aftermap (P0/P1 spike)

- Generated: 2026-07-22
- Repo: `zymalpha/aftermap` (local bundle: `aftermap-p1.bundle`)
- Head: `c6c2320`
- Phase: P0 + P1 spike complete (Stage 1–5 done; Stage 6 docs landing)

## 1. Spike Summary

| Item                | Result              | Notes                                                  |
| ------------------- | ------------------- | ------------------------------------------------------ |
| Python schema check | PASS                | `tools/content_validator/validate.py` on full content/ |
| Godot headless P0   | 53 PASS / 0 FAIL    | rng, save, event, command_queue, grid_pathfind, pixel  |
| Godot headless P1   | 113 PASS / 0 FAIL   | tactical, grid, pathfind, movement, FOV, sound, combat  |
| **Total**           | **166 PASS / 0 FAIL** | All spikes green; no warnings recorded                |

Reproduce with `run.sh` (bash) or `run.bat` (Windows). On machines without Godot installed, schema check still runs and P0/P1 headless steps print a `WARN: Godot 未安装` line.

## 2. What's Actually Built (this milestone)

P0 (Stage 1–3):
- ADR set (0001–0006) + JSON schemas for items / recipes / traits / events / chains / facilities / POI rooms.
- Content validator (Python, jsonschema) + 8 sample JSONs.
- `GameSession` core: 8-stream named RNG, atomic versioned save (SHA-256, .bak), clock, command queue.
- Event interpreter with whitelisted AST + sample event firing.

P1 (Stage 4–5):
- Tactical grid + pathfind (A*) + movement + FOV + sound pulse + alertness + combat + search + infection hooks.
- Pixel scaling node + scene stub.
- Command queue threads through GameSession only (no Godot singletons).
- `test_p1_tactical.gd` covers grid → pathfind → move → FOV → sound → alertness → combat → search → infection end-to-end.

## 3. Known Risks (live)

| ID  | Risk                                                                                                                                       | Severity | Mitigation                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------- | --------------------------------------------------------------------------------------- |
| R-1 | Godot 4.6.2 binary not bundled in repo — headless spike skips on machines without it.                                                       | M        | `run.sh` warns instead of failing; schema check is enough for CI smoke.                  |
| R-2 | OSM fetch deferred to P3 — only sample hand-authored tiles currently exercised by `map_pipeline`.                                            | L        | ADR-0006 records the gate; P3 must re-open before any real-world map ingest.             |
| R-3 | Event whitelist is closed (ADR-0005). New ops require ADR + interpreter patch.                                                              | L        | Whitelist is enforced at runtime; rejected ops never reach GameSession.                  |
| R-4 | Localization adapter directory empty (Stage 2 stub only).                                                                                   | M        | P2 backlog card `LOC-1`.                                                                 |
| R-5 | Tests directory at repo root is a `.gitkeep` placeholder; all headless tests live in `game/tests/`.                                         | L        | Will be removed or populated in P2 cleanup.                                              |
| R-6 | Save format is `v1` only; no migration scaffolding yet.                                                                                     | L        | Atomic write + SHA-256 makes any future migration safe; tracked under `SAVE-2` backlog.  |
| R-7 | Combat/infection/survivors domains have skeleton files but no behavior yet — current spike stubs return deterministic counters.            | M        | P2 backlog cards `COMBAT-2`, `INF-2`.                                                    |

## 4. Hard Constraints (do not violate)

- Engine = Godot 4.6.2 only; renderer = Compatibility / OpenGL only; 30-AI cap (§11.21).
- All gameplay-affecting randomness goes through the 8 named streams (`cosmetic_only` excluded).
- Saves are atomic, versioned, SHA-256 verified; `.bak` fallback enforced.
- Event effects = whitelisted AST; no `eval`, no script injection.
- All gameplay state changes route through `GameSession` commands (no autoload singletons for state).
- Content IDs match patterns (`itm_*`, `evt_*`, `rec_*`, `trt_*`, `fac_*`, `poi_*`, `chain_*`).
- Display strings come from localization; no English literals hard-coded into gameplay logic.

## 5. Out of Scope (this spike)

- Real OSM/Overpass fetching (P3 gate, ADR-0006).
- Map renderer beyond pixel-scaling node (P2 backlog).
- Save migration tooling (P2 backlog).
- Combat/infection full implementation (P2 backlog).
- Localization entries (P2 backlog).
- Presentation scenes other than `tactical.tscn` stub.

## 6. How to Verify

1. `python tools/content_validator/validate.py content`  -> exit 0.
2. With Godot 4.6.2 installed, `bash run.sh` (or `run.bat`) -> 166 PASS / 0 FAIL across the printed spike names.
3. Without Godot, schema step still passes; headless step warns but exits 0.

## 7. Deliverables (this bundle)

See "交付物" section below.

## 交付物

| Path                                       | Purpose                                                   |
| ------------------------------------------ | --------------------------------------------------------- |
| `docs/production/PROJECT_STATE.md`         | This file — spike status, risks, hard constraints.        |
| `docs/production/BACKLOG.md`               | P2–P6 backlog card summaries.                             |
| `docs/production/DECISIONS.md`             | ADR index (0001–0006) with status / scope.                |
| `docs/production/CHANGELOG_DEV.md`         | Stage 1–6 delivery log.                                   |
| `docs/api/game-session.md`                 | `GameSession` API contract (commands, RNG, save).         |
| `docs/api/tactical-session.md`             | Tactical grid / pathfind / FOV / combat API contract.     |
| `docs/api/content-db.md`                   | Content DB contract (ids, lookup, kind enums).            |
| `tools/build/run_tests.sh`                 | Bash test runner (mirrors `run.sh` spike scope).          |
| `tools/build/run_tests.bat`                | Windows test runner (mirrors `run.bat` spike scope).      |
| `README.md`                                | 30-min quick-start + acceptance checklist + known limits. |
| `CHANGELOG.md`                             | `v0.1.0` release entry.                                   |
| `aftermap-p1.bundle`                       | Single-file repo bundle (`git bundle create --all`).     |
| `PUSH_INSTRUCTIONS.md`                     | Steps to push `main` and the `aftermap-p1` tag to GitHub. |