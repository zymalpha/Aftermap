# ADR-0006: Maps — Python preprocessing pipeline, OSM fetch deferred to P3, manifest contract now

- Status: Accepted (with explicit P3 gate on OSM fetching)
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.15 / §11.17 / §14.九 / §07 / §12.4 / §12.7 (P3 gate)

## Context

§11.15 and §11.17 jointly define a two-side map story:

- The **Python tool** under `tools/map_pipeline/` reads an OSM
  snapshot plus a config and emits a **versioned map pack**
  (`manifest.json`, `city_graph.json`, `districts.json`, `pois.json`,
  `geometry.*`, `generation_report.json`, `attribution.txt`).
- The **game client** reads only the map pack. It must never talk to
  the public internet, never pull OSM tiles at runtime, never see
  GPS coordinates or private addresses in any form the player could
  quote verbatim (§11.20, §14.九 item 4).
- §14.九 rules 1, 6, 7, 9:
  1. The default city (Nanjing) ships as an **offline preset map
     pack** in the Windows build.
  6. The game must display "Map data © OpenStreetMap contributors,
     ODbL".
  7. Map service queries follow OSM rate policies; no scraping bulk
     tiles.
  9. A failed generation must not produce a broken campaign.
- §14.七 item 13 says external inputs (file paths, OSM text, archive
  sizes) must be validated.
- §12.7 (P3) says the entire real-map pipeline does not enter
  production until P2's core loop has passed.

§14.九 items 1 and 9 are absolute: the MVP never depends on fetching
a real map at run time. The "任意地点" feature is marked
experimental and must always fall back to the preset offline pack.

## Decision

1. **Tool boundary**: `tools/map_pipeline/` is a Python 3.12 CLI with
   four subcommands — `fetch`, `build`, `validate`, `preview` —
   matching §11.15.3. It must run without Godot installed.
2. **OSM fetch is unimplemented at P0.** The `fetch` subcommand
   exists but raises `NotImplementedError("P3+ OSM fetch only; see
   ADR-0006")` until Stage 5 or later. All other subcommands work
   against a pre-existing snapshot directory.
3. **Manifest contract is defined today**, even though only preset
   maps populate it. Schema path: `content/schemas/manifest.schema.json`.
   Minimum fields:
   - `map_pack_id` (string, immutable)
   - `schema_version` (integer)
   - `seed` (string, hex)
   - `created_at`
   - `poi_classes` (array, mirrors `poi-room.schema.json`)
   - `districts[]`, `pois[]`, `roads[]`
   - `attribution` (object with OSM notice)
   - `content_fingerprint` (matches ADR-0004 fingerprint).
4. **Validated by the same content validator** as JSON content. The
   schema linter treats `manifest.schema.json` as just another
   schema; CI fails when any map pack lacks a matching manifest.
5. **Offline-first default**: the Windows build
   (`build/windows/Aftermap.exe`) ships a Nanjing preset pack under
   `content/maps/nanjing_preset/`. The game crashes loudly — with a
   localised message — if every pack is missing, instead of
   triggering a network fetch.
6. **Run-time isolation**: the game never imports the Python tool;
   the tool never imports GDScript. The contract is the manifest
   JSON.
7. **Attribution is a first-class artefact** (`attribution.txt`),
   in-game screen reachable from the main menu (§14.九 item 6).
8. **Privacy**: §11.20 forbids precise private coordinates in logs
   or builds; the manifest stores POI centroids rounded to 4
   decimal minutes (~11 m) by default, configurable down only for
   dev builds.

## Consequences

Positive:
- The schema is locked now, so P3 integration is mechanical.
- The MVP is fully playable offline (§14.九 item 1).
- §14.九 item 9 (failure does not brick the campaign) is satisfied
  by the offline-first default.

Negative / constraints:
- We carry both the Python tool and the content validator in CI;
  both depend on Python 3.12 + jsonschema already installed in
  Stage 2.
- A live OSM tool is not part of MVP; users on a clean machine can
  only play with the preset pack until P3 ships.

## Alternatives Considered

- **In-engine OSM parser in GDScript** — Rejected: §11.15 codifies
  Python; GIS tooling and libraries are dramatically better there.
- **Always-online fetch with cached fallback** — Rejected:
  §14.九 item 1 / §14.七 item 15 require offline-first MVP.
- **Implicit (non-versioned) map data** — Rejected: §11.17 requires
  immutable manifests and content fingerprints so saves can verify
  the underlying data has not changed underneath them.

## Open Questions

- Coordinate precision in user-visible runs of the dev build. We
  pick 4 decimal minutes by default; ADR will be updated if real
  campaigns need debug-grade precision.

## Impact Surface

- `tools/map_pipeline/` (placeholder + `NotImplementedError` for
  fetch; `build`, `validate`, `preview` ship as stubs returning
  artefacts).
- `content/schemas/manifest.schema.json` (Stage 2, separate from
  the seven content schemas).
- `tools/build/` — copies the preset pack into the Windows build.
- `docs/adr/0006-maps-pipeline-python.md` — this file.
