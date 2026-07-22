# Backlog — P5 / P6 (current) + P2 / P3 / P4 closed

> Generated 2026-07-23 at v0.2 release. P2 / P3 / P4 cards below are marked complete and archived; P5 / P6 are the active backlog.

## P2 — Core Loop / State Hardening (Stage 8–10, DONE)

| Card       | Title                                       | Status   | Outcome                                                                                  |
| ---------- | ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- |
| CORE-1     | Survivors domain behavior                   | DONE     | Character / relationship / memory / traits implemented (`game/domain/survivors/`).      |
| COMBAT-2   | Combat resolution + wound states            | DONE     | Full combat resolver (P1 already wired through GameSession; P2 spike tests cover it).     |
| INF-2      | Infection progression                       | DONE     | Full infection state machine wired into GameSession with suppressant / cleaning hooks.   |
| SAVE-2     | Save format migration scaffolding           | DONE     | Atomic v1 + .bak fallback; v2 migration deferred to P6 `SAVE-6` (on-disk migration).     |
| MAP-2      | Tactical scene polish                       | DEFERRED | Presentation scenes deferred to P5 (`UI-5` / `ART-5`).                                    |
| LOC-1      | Localization adapter entries                | DEFERRED | Re-packaged as P5 `LOC-5`.                                                                 |
| TUT-1      | Tutorial event chain                        | DONE     | `sample_intro_welcome` chain + `evt_intro_welcome` fired in 7-day smoke.                  |

## P3 — World / Map / OSM (Stage 10–11, DONE)

| Card       | Title                                       | Status   | Outcome                                                                                  |
| ---------- | ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- |
| OSM-3      | OSM fetch pipeline                          | PARTIAL  | `tools/map_pipeline/` scaffold (5 modules) + osm_fetcher stub; live Overpass deferred to P5+. |
| MAP-3      | POI/room authoring tool                     | DONE     | `manifest_generator.py` + Nanjing preset sample authored.                                 |
| DIR-3      | Event director (60+ events quota)           | PARTIAL  | 10 events + 2 chains delivered in P2; full 60+ quota scheduled in P5 `STORY-5`.           |
| DIFF-3     | Difficulty curve                            | DONE     | City pressure + 4-act state machine drive day-band difficulty (P4).                       |

## P4 — Progression / Save-Loop (Stage 11–12, DONE)

| Card       | Title                                       | Status   | Outcome                                                                                  |
| ---------- | ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- |
| PROG-4     | Survivor progression + traits               | DONE     | 12 traits, stat_add / memory commands, 100-seed x 30-day invariants pass.                |
| BASE-4     | Base / facility management                  | DONE     | `base/` + `facility.gd` with garden / stockpile / jobs.                                   |
| REC-4      | Recipe crafting                             | PARTIAL  | Schema + samples present; runtime loop deferred to P5 `REC-5`.                             |
| STORY-4    | Branching event chains                      | DONE     | Migration subsystem with 5 endings + departure event sample.                              |

## P5 — Content / UX / Art (Stage 14–17, NOT STARTED)

| Card       | Title                                       | Priority | Summary                                                                                  | Source        |
| ---------- | ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- | ------------- |
| ART-5      | Placeholder art batch (tilesets / sprites)  | P0       | First batch of pixel-art SVG / PNG tilesets replacing placeholder blocks; targets 7 view paths in `HOW_TO_VIEW.md`. | §10, ADR-0002 |
| UI-5       | HUD + menu + inventory panel                | P0       | Render the existing `presentation/ui/hud.gd` + new inventory grid + status panel.        | §10           |
| AUDIO-5    | Sound pack + mixer                          | P1       | Replace P1 `sound_pulse.gd` stub with full mixer + ambient layers.                       | §10, ADR-0002 |
| A11Y-5     | Accessibility pass                          | P1       | Colorblind-safe palette, font scaling, key rebind.                                        | §11.18        |
| LOC-5      | Localization tables (zh-CN + en)            | P0       | `game/adapters/localization/` loader + zh-CN sample; replace English literals.            | §11.18, ADR-0001 |
| STORY-5    | Event director quota 60+                    | P1       | Hit §08 quota: 60+ independent events + 8+ chains by P5 close.                            | §08           |
| REC-5      | Recipe crafting runtime                     | P2       | Promote `recipes/*.json` into a real crafting loop with inventory dependencies.           | §06, §11.6    |
| OSM-5      | Live Overpass fetch                         | P2       | Re-open ADR-0006 gate; implement Overpass query + tile ingest for home region.            | ADR-0006, §07 |
| ENDING-5   | Ending narrative authoring                  | P2       | Author 5 endings into `content/endings/*.json`; currently sampled by P4 test.            | §08           |

## P6 — Release Engineering (Stage 18+, NOT STARTED)

| Card       | Title                                       | Priority | Summary                                                                                  | Source        |
| ---------- | ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- | ------------- |
| REL-6      | Steam build pipeline                        | P0       | Godot export presets + signing + depots for Steam (PC).                                  | §14           |
| QA-6       | Full regression suite (CI nightly)          | P0       | Promote the 352-test spike to a tagged nightly run with trend report.                     | §12.4         |
| DOC-6      | Public documentation site                   | P1       | Publish `docs/api/*.md` + design notes as a static site.                                  | §14           |
| OBS-6      | Telemetry opt-in                            | P1       | Anonymous crash / balance telemetry behind explicit opt-in.                              | §11.18        |
| SAVE-6     | On-disk save migration                      | P2       | `v1 → v2` migration runner behind ADR-0004 atomic contract.                              | ADR-0004, §11.16 |