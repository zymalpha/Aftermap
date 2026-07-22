# Backlog — P2 through P6 (summary)

> Generated 2026-07-22 alongside P1 spike close-out. Cards below are summary stubs; full tickets live in the project tracker (TBD). Every card references the spike section / ADR it derives from.

## P2 — Core Loop / State Hardening

| Card       | Title                                       | Summary                                                                                                      | Source          |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| CORE-1     | Survivors domain behavior                   | Replace P1 stub counters with real survivor model (mood, energy, infection curve per §03 / §09).              | §03, §09        |
| COMBAT-2   | Combat resolution + wound states            | Move `combat.gd` from P1 stub to full melee/ranged resolution with wound / knockdown outcomes (ADR-0001).      | §05             |
| INF-2      | Infection progression                       | Realize `infection.gd` state machine (incubation → onset → critical) with sample events hooking in.           | §09             |
| SAVE-2     | Save format migration scaffolding           | Add `v1 → v2` migration runner behind ADR-0004 atomic contract; preserve SHA-256 chain.                       | ADR-0004, §11.16 |
| MAP-2      | Tactical scene polish                       | Replace `tactical.tscn` stub with full presentation scene (camera, fog overlay, action bar).                   | §07             |
| LOC-1      | Localization adapter entries                | Fill `game/adapters/localization/` with string-table loader and zh-CN sample table.                          | §11.18, ADR-0001 |
| TUT-1      | Tutorial event chain                        | Promote `sample_intro_welcome` chain to a real guided first-night flow.                                      | §08             |

## P3 — World / Map / OSM

| Card       | Title                                       | Summary                                                                                                      | Source          |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| OSM-3      | OSM fetch pipeline                          | Re-open ADR-0006 gate; implement Overpass query + tile ingest for the player's home region.                  | ADR-0006, §07   |
| MAP-3      | POI/room authoring tool                     | Authoring helper for `poi-rooms/*.json` with validator feedback loop.                                         | §07             |
| DIR-3      | Event director (60+ events quota)           | Hit §08 quota: 60+ independent events + chains by P3 close.                                                  | §08             |
| DIFF-3     | Difficulty curve                            | Day-band difficulty progression tuned against §11.22 streams.                                                | §11.22          |

## P4 — Progression / Save-Loop

| Card       | Title                                       | Summary                                                                                                      | Source          |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| PROG-4     | Survivor progression + traits               | Trait unlocks, level-up hooks, trait point economy (§03 / §11.6).                                             | §03, §11.6      |
| BASE-4     | Base / facility management                  | Turn `facilities/*.json` into actionable facilities with working-state effects.                                | §06             |
| REC-4      | Recipe crafting                             | Promote `recipes/*.json` into a real crafting loop with inventory dependencies.                               | §06, §11.6      |
| STORY-4    | Branching event chains                      | Implement chain continuation + branching consequences per §08.                                               | §08             |

## P5 — Content / UX Polish

| Card       | Title                                       | Summary                                                                                                      | Source          |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| AUDIO-5    | Sound pack + mixer                          | Replace P1 `sound_pulse.gd` stub with full mixer + ambient layers.                                           | §10, ADR-0002   |
| UI-5       | HUD + menu pass                             | Build out `presentation/ui/` (action bar, inventory grid, status panel).                                     | §10             |
| ART-5      | Pixel art pass                              | 2D pixel pass replacing the pixel-scaling node stub with real sprites / tilesets.                            | §10, ADR-0002   |
| A11Y-5     | Accessibility pass                          | Colorblind-safe palette, font scaling, key rebind.                                                            | §11.18          |

## P6 — Release Engineering

| Card       | Title                                       | Summary                                                                                                      | Source          |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| REL-6      | Steam build pipeline                        | Godot export presets + signing + depots for Steam (PC).                                                      | §14             |
| QA-6       | Full regression suite                       | Promote the 166-test spike to a tagged nightly run with trend report.                                         | §12.4           |
| OBS-6      | Telemetry opt-in                            | Anonymous crash / balance telemetry behind explicit opt-in.                                                  | §11.18          |
| DOC-6      | Public documentation site                   | Publish `docs/api/*.md` + design notes as a static site.                                                     | §14             |