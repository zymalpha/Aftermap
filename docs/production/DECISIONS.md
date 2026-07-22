# Decisions — ADR Index

| ID     | Title                                                    | Status   | Scope                                                          |
| ------ | -------------------------------------------------------- | -------- | -------------------------------------------------------------- |
| 0001   | Engine — Godot 4.6.2 + GDScript (static types) + Python map pipeline | Accepted | Whole project: engine, language, build tooling.                |
| 0002   | Renderer — Compatibility / OpenGL only, 2D pixel, 30-AI cap | Accepted | §11.21, §10 art constraints; P0 spike `pixel_render_stable`.   |
| 0003   | RNG — 8 named streams, seeded, deterministic              | Accepted | §11.2.4, §11.12, §11.22.1; P0 spike `rng_named_streams`.       |
| 0004   | Saves — Atomic, versioned, SHA-256, `.bak` fallback       | Accepted | §11.16, §11.7; P0 spike `atomic_save_recovery`.                |
| 0005   | Events — Whitelisted AST interpreter, no eval             | Accepted | §11.14, §11.20; P0 spike `event_interpreter`.                  |
| 0006   | Maps — Python preprocessing pipeline, OSM deferred to P3  | Accepted | §11.15, §11.17; P3 gate on real OSM ingest.                    |

## Pending / On-deck

- ADR-0007 (drafting in P2): Save migration scaffolding (SAVE-2).
- ADR-0008 (drafting in P2): Localization adapter contract (LOC-1).

## Rejected / Deferred

- Real OSM/Overpass fetcher — deferred behind ADR-0006 P3 gate.
- Steamworks integration — deferred to P6 (REL-6).

## How to add a new ADR

1. Copy the latest `docs/adr/NNNN-*.md` and renumber.
2. Keep the header (`Status / Date / Deciders / Related`).
3. Cross-link from this index table in the same commit.
4. If the ADR invalidates a prior one, mark the prior as `Superseded by NNNN` and link forward — do not delete.