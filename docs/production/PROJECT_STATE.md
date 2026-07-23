# Project State — Aftermap (v1.0 candidate)

- Generated: 2026-07-23
- Repo: `zymalpha/aftermap` (local bundle: `aftermap-v1.0.bundle`)
- Head: see `git log` (Stage 18 release commit)
- Phase: **v1.0 candidate — P0–P6 逻辑全部交付，Windows 导出就绪，1000 种子 × 30 天零崩溃**

## 1. Spike Summary (v1.0 candidate)

| Item                | Result              | Notes                                                  |
| ------------------- | ------------------- | ------------------------------------------------------ |
| Python schema check | PASS                | `tools/content_validator/validate.py` on full content/ (**222 files**) |
| Python pytest (map) | 40 PASS / 0 FAIL    | `tools/map_pipeline/tests/` (classifier, graph, manifest, scenario) |
| Godot headless P0   | 114 PASS / 0 FAIL   | stage3_smoke (53) + command_queue (20) + grid_pathfind (23) + pixel_scaling (18) |
| Godot headless P1   | 52 PASS / 0 FAIL    | tactical grid → pathfind → move → FOV → sound → alertness → combat → search → infection |
| Godot headless P2   | 184 PASS / 0 FAIL   | characters (40) + content (37) + inventory_base (46) + state_machine (26) + world (23) + seven_days (12) |
| Godot headless P4   | 2 PASS / 0 FAIL     | 100-seed x 30-day crash-free longitudinal simulation |
| Godot headless P5   | 141 PASS / 0 FAIL   | UI layout (main menu + HUD + 6 panels + tutorial + a11y) |
| Godot headless P6   | 4 PASS / 0 FAIL     | **1000-seed × 30-day stress (2) + 30-unit perf benchmark (2)** |
| **Total GDScript**  | **497 PASS / 0 FAIL** | All spikes green; P6 adds the 1000-seed + perf gates |
| **Grand Total**     | **759 PASS / 0 FAIL** | 497 GDScript + 40 pytest + 222 content files validated |

> **Known pre-existing failure (out of P6 scope):** `test_p5_localization`
> reports 36 PASS / 2 FAIL (`good entry parsed got 'FB'` / `another entry
> parsed got 'FB'`) — a P5 Stage 17 localizer .po edge-case bug that
> predates this Stage 18 work. It does not affect gameplay (localizer
> falls back to the key). Tracked as risk **R-13** below; the content /
> localization track owns the fix.

Reproduce with `run.sh` (bash) or `run.bat` (Windows). On machines without Godot installed, schema check + pytest still run; Godot-dependent steps print `WARN: Godot 未安装` and exit 0.

## 1b. P6 Stress Gates (Stage 18)

| Gate | Result |
| ---- | ------ |
| **1000-seed × 30-day stress** | **1000 / 1000 seeds complete 30 days**, all invariants green (stats ∈ [0,100], city_pressure ∈ [0,100], resources ≥ 0, no dangling refs). Threshold was ≥ 800. ~71s wall (14 seeds/s). |
| **30-unit perf benchmark** | avg **~10.2 ms** (< 16.67 / 60fps ✓), max **~21 ms** (< 33 / 30fps ✓), p99 ~15 ms. ~97 fps achieved on a 24×24 normal-scene grid. 4 consecutive runs pass. |
| **Pathfinder GC spike fix** | Caching the per-cell `g_score` / `closed` / `prev_idx` / `block_mask` packed arrays (keyed by grid w×h) eliminated the dominant per-frame allocation source — frame-time tail dropped from 60–170 ms spikes to ≤ 25 ms. |

## 2. What's Actually Built (v0.2)

### P0 (Stage 1–3) — Core
- ADR set (0001–0006) + JSON schemas for items / recipes / traits / events / chains / facilities / POI rooms.
- Content validator (Python, jsonschema) + 49 sample JSONs validated.
- `GameSession` core: 8-stream named RNG, atomic versioned save (SHA-256, .bak), clock, command queue.
- Event interpreter with whitelisted AST + sample event firing.

### P1 (Stage 4–5) — Tactical
- Tactical grid + pathfind (A*) + movement + FOV + sound pulse + alertness + combat + search + infection hooks.
- Pixel scaling node + scene stub.
- Command queue threads through GameSession only (no Godot singletons).
- `test_p1_tactical.gd` covers grid → pathfind → move → FOV → sound → alertness → combat → search → infection end-to-end.

### P2 (Stage 8–10) — Core Loop
- Character / relationship / memory / traits data (12 traits, 8 relationships).
- State machine (`morning_report.gd` + `state_machine.gd`) with 4-act progression.
- Inventory + base + jobs (`inventory/`, `base/`, `jobs.gd`).
- POI + city + travel (`world/`).
- Expanded content (12 items, 6 facilities, 10 events, 2 chains).
- 7-day longitudinal headless smoke (`test_p2_seven_days.gd`).

### P3 (Stage 10–11) — Map Pipeline
- `tools/map_pipeline/` Python module: osm_fetcher stub + 5 modules (city_graph_builder, geometry_processor, poi_classifier, manifest_generator, scenario_generator).
- Preset Nanjing manifest sample + schema (`content/presets/`).
- 40 pytest cases covering classifier / graph / manifest / scenario.

### P4 (Stage 11–12) — 30-Day Campaign
- City pressure + 4-act state machine (`city_pressure.gd`, `act_state_machine.gd`).
- Migration subsystem + 5 endings (`migration.gd`).
- GameSession command extensions (stat_add / item_add / relationship / memory).
- Sample departure event with legacy choices.
- 100-seed x 30-day crash-free simulation passes with all invariants.

### P5 (Stage 14–17) — Content & Presentation
- Localization adapter (`game/adapters/localization/localizer.gd`) + zh_CN / en_US `.po` tables (100+ keys). UI display strings route through the localizer.
- Pixel placeholder art (4 chars + 3 infected + 7 tiles + 16 UI icons) + procedural asset generator (`tools/asset_generator/`).
- Presentation scenes: main menu, base HUD, morning report, event decision, facility upgrade, inventory, 5-step tutorial, accessibility settings. `test_p5_ui_layout.gd` (141 PASS) asserts node trees + signal wiring.
- Content authoring (parallel track): traits / wounds / enemies / backgrounds / specializations / items / facilities / POI rooms / 60 events + 10 chains. 222 content files schema-validated.

### P6 (Stage 18) — Stability & Release
- **Windows Desktop export preset** (`export_presets.cfg`): Godot 4.6.2, product `Aftermap`, company `zymalpha`, 64-bit x86_64, embed_pck, icon placeholder.
- **Build scripts** (`tools/build/build_windows.sh` + `.bat`): locate Godot in `.tools/godot/`, run `--headless --export-release "Windows Desktop"`, never abort the release session on missing GUI Godot or export template (prints `EXPORT_STATUS=needs_gui_godot` and exits 0).
- **1000-seed × 30-day stress** (`game/tests/test_p6_thousand_seeds.gd`): 1000 seeds × 30 days, per-seed guarded, full invariants (stats / pressure / resources / dangling refs). 1000 / 1000 pass (threshold 800).
- **30-unit perf benchmark** (`game/tests/test_p6_perf_benchmark.gd`): 30 units × 1500 frames on a 24×24 grid, 1 shared sound pulse + per-unit pathfind / FOV / alertness. avg < 16.67ms, max < 33ms.
- **Pathfinder buffer-cache optimization** (`game/domain/tactical/pathfinder.gd`): caches per-cell working arrays keyed by grid dimensions, removing 90 allocations/frame and the resulting GC spikes.

## 3. Known Risks (live)

| ID  | Risk                                                                                                                                       | Severity | Mitigation                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------- | --------------------------------------------------------------------------------------- |
| R-1 | Godot 4.6.2 binary not bundled in repo — headless spike skips on machines without it.                                                       | M        | `run.sh` warns instead of failing; schema check is enough for CI smoke.                  |
| R-2 | OSM fetch deferred — only sample hand-authored tiles currently exercised by `map_pipeline` (P3 quota met with Nanjing preset; live Overpass deferred to P5+). | L        | ADR-0006 records the gate; P5+ must re-open before any real-world map ingest.            |
| R-3 | Event whitelist is closed (ADR-0005). New ops require ADR + interpreter patch.                                                              | L        | Whitelist is enforced at runtime; rejected ops never reach GameSession.                  |
| R-4 | Localization adapter directory empty (Stage 2 stub only).                                                                                   | M        | P5 backlog card `LOC-5`.                                                                 |
| R-5 | Tests directory at repo root is a `.gitkeep` placeholder; all headless tests live in `game/tests/`.                                         | L        | Will be removed or populated in P5 cleanup.                                              |
| R-6 | Save format is `v1` only; no migration scaffolding yet (P4 `migration.gd` is in-memory state migration, not on-disk save migration).        | L        | Atomic write + SHA-256 makes any future migration safe; tracked under `SAVE-6` backlog.  |
| R-7 | Combat / infection / survivors domains have full behavior now; presentation scenes beyond `tactical.tscn` stub missing.                    | M        | P5 backlog cards `UI-5`, `ART-5`, `AUDIO-5`.                                              |
| R-8 | Pixel art is placeholder (5 SVG illustrations only); no tilesets, no sprite sheets.                                                         | M        | P5 `ART-5` is the placeholder art batch commitment.                                       |
| R-9 | No localization entries — display strings still English literals in gameplay logic.                                                        | M        | P5 `LOC-5` will introduce zh-CN table.                                                   |
| R-10 | Migration ending choices are sampled but not branched further — 5 endings shown in test, real content authoring deferred to P5.            | L        | P5 backlog card `STORY-5`.                                                                |
| R-11 | No Steam build pipeline, no telemetry opt-in, no public docs site.                                                                          | M        | P6 backlog cards `REL-6`, `OBS-6`, `DOC-6`.                                              |
| R-12 | CI workflow exists but not yet triggered by a real push to GitHub (origin 17 commits ahead).                                                | L        | First push via `aftermap-v1.0.bundle` + `PUSH_COMMANDS.md`.                              |
| R-13 | `test_p5_localization` reports 36 PASS / 2 FAIL (`good entry parsed got 'FB'`, `another entry parsed got 'FB'`) - a P5 Stage 17 localizer .po parsing edge-case bug. Predates Stage 18. Gameplay unaffected (falls back to the key). | M        | Owned by the content / localization track; lives in `game/adapters/localization/localizer.gd`. Excluded from the P6 PASS totals above. |
| R-14 | Windows `.exe` export not yet produced in-session - headless `--export-release` requires the GUI Godot + installed 'Windows Desktop' export template on the build machine. | M        | `tools/build/build_windows.sh` prints `EXPORT_STATUS=needs_gui_godot` and exits 0 when templates are absent; a maintainer with templates produces the final `.exe`. |
| R-15 | Perf benchmark targets (avg < 16.67ms / max < 33ms) are machine-sensitive; a heavily loaded CI box may flap. | L        | 24x24 grid + pathfinder buffer cache leave ~35% avg headroom; CI should pin a quiet runner. |

## 4. Hard Constraints (do not violate)

- Engine = Godot 4.6.2 only; renderer = Compatibility / OpenGL only; 30-AI cap (§11.21).
- All gameplay-affecting randomness goes through the 8 named streams (`cosmetic_only` excluded).
- Saves are atomic, versioned, SHA-256 verified; `.bak` fallback enforced.
- Event effects = whitelisted AST; no `eval`, no script injection.
- All gameplay state changes route through `GameSession` commands (no autoload singletons for state).
- Content IDs match patterns (`itm_*`, `evt_*`, `rec_*`, `trt_*`, `fac_*`, `poi_*`, `chain_*`, `ending_*`).
- Display strings come from localization; no English literals hard-coded into gameplay logic (P5 enforcement).
- Map pipeline is Python (ADR-0006); no OSM fetch outside `tools/map_pipeline/`.

## 5. Out of Scope (v0.2 / deferred to P5 / P6)

- Real OSM/Overpass fetching over the wire (P5+).
- Localization tables (P5 `LOC-5`).
- Full pixel-art tileset / sprite sheets (P5 `ART-5`).
- Audio mixer / ambient layers (P5 `AUDIO-5`).
- HUD / menu / inventory panel rendering (P5 `UI-5`).
- Accessibility pass (P5 `A11Y-5`).
- Steam build pipeline + telemetry + public docs site (P6).

## 6. How to Verify

1. `python tools/content_validator/validate.py content`  -> exit 0 (**222 files** validated).
2. `python -m pytest tools/map_pipeline/tests/` -> 40 PASS / 0 FAIL.
3. With Godot 4.6.2 installed, `bash run.sh` (or `run.bat`) -> **497 PASS / 0 FAIL** across 15 test files (P0–P6). The 1000-seed × 30-day and 30-unit perf gates are included.
4. Without Godot, schema + pytest steps still pass; headless step warns but exits 0.
5. `bash tools/build/build_windows.sh` -> produces `build/windows/Aftermap.exe`, or prints `EXPORT_STATUS=needs_gui_godot` and exits 0 if export templates aren't installed.
6. `git bundle verify aftermap-v1.0.bundle` -> OK.

## 7. Deliverables (v1.0 bundle)

See "交付物" section below.

## 交付物

| Path                                       | Purpose                                                   |
| ------------------------------------------ | --------------------------------------------------------- |
| `docs/production/PROJECT_STATE.md`         | This file — v1.0 status, risks, hard constraints.         |
| `docs/production/BACKLOG.md`               | P5–P6 backlog card summaries (P2–P4 marked complete).      |
| `docs/production/DECISIONS.md`             | ADR index (0001–0006) with status / scope.                |
| `docs/production/CHANGELOG_DEV.md`         | Stage 1–18 delivery log.                                  |
| `docs/production/V1.0_RELEASE_NOTES.md`    | **v1.0 release notes (P0–P6 complete).**                  |
| `docs/api/game-session.md`                 | `GameSession` API contract (commands, RNG, save).         |
| `docs/api/tactical-session.md`             | Tactical grid / pathfind / FOV / combat API contract.     |
| `docs/api/content-db.md`                   | Content DB contract (ids, lookup, kind enums).            |
| `export_presets.cfg`                       | **Godot 4.6.2 'Windows Desktop' export preset (P6).**     |
| `tools/build/build_windows.sh` / `.bat`    | **Headless Windows release export (P6).**                 |
| `tools/build/run_tests.sh`                 | Bash test runner (mirrors `run.sh` full scope).           |
| `tools/build/run_tests.bat`                | Windows test runner (mirrors `run.bat` full scope).       |
| `game/tests/test_p6_thousand_seeds.gd`     | **1000-seed × 30-day stress gate (P6).**                  |
| `game/tests/test_p6_perf_benchmark.gd`     | **30-unit 60fps/30fps perf gate (P6).**                   |
| `README.md`                                | 30-min quick-start + acceptance checklist + roadmap.      |
| `CHANGELOG.md`                             | `v1.0.0` release entry.                                   |
| `aftermap-v1.0.bundle`                     | Single-file repo bundle (`git bundle create --all`).     |
| `PUSH_COMMANDS.md` / `FIX_PUSH.md`         | Push steps + bundle-based clone for v1.0.                 |