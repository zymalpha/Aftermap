# ADR-0001: Engine — Godot 4.6.2 + GDScript (static types) + Python map pipeline

- Status: Accepted
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.1 / §14.三 / §12.4 (P0)

## Context

We need to lock the engine and language stack for the whole project so that
multi-round AI iterations do not keep rewriting core code. The selection must
satisfy the four hard pillars of the MVP:

1. The game is 2D tile-based (top-down city + grid tactical), not 3D
   (§14.三, item 3).
2. The reference host is an Intel UHD Graphics iGPU with 16 GB RAM running
   Windows x86_64 — the engine must run there with the **Compatibility/OpenGL
   renderer**, not Forward+ (§14.三, items 1, 2).
3. All game content must be data-defined (JSON + JSON Schema) so AI can
   author and validate reproducibly (§11.7 / §11.4).
4. Real-world map preprocessing requires a strong GIS / geometry / batch-test
   ecosystem that GDScript does not provide (§11.1).

The default city is Nanjing (南京), the launch language is Simplified Chinese,
and the build target is `build/windows/Aftermap.exe` (§14.一).

## Decision

We adopt the stack exactly as recommended in §11.1 with no open questions:

| Layer | Choice |
|---|---|
| Game client | **Godot 4.6.2 stable**, portable build under `.tools/godot/` |
| Renderer | **Compatibility / OpenGL** only (no Forward+) |
| Game script | **GDScript with static typing** (`var x: int`, no `Variant` for hot paths) |
| Content | **JSON + JSON Schema (draft-07)**, validated by `tools/content_validator/` |
| Map preprocessing | **Python 3.12** standalone CLI in `tools/map_pipeline/` |
| Version control | **Git** in this workspace |
| Auto tests | **Godot headless** + Python content validator |

The script mode "statically typed GDScript" is mandatory for any file that
participates in combat, RNG advancement, save/load, or command results
(§11.2 item 3 + §14.七 item 1). Dynamic typing is allowed only for throwaway
editor glue.

GDScript must stay text-friendly so the AI assistant can read and review the
code (§11.1). We do **not** introduce third-party plugins, asset packs with
incompatible licences, or remote services at this stage.

## Consequences

Positive:
- Stable, well-known engine; portable build avoids touching system PATH.
- Static typing gives faster iteration in the Godot editor and reduces
  AI drift when refactoring.
- Splitting Python map pipeline from GDScript game logic follows §11.2
  (module unidirectional dependency): content does not depend on game code.

Negative / constraints:
- Compatibility renderer forbids 3D, dynamic shadows, full-screen
  post-processing, GPU particles (§14.三, items 2, 6). Any spike that
  attempts these is rejected outright.
- Python map pipeline cannot share types with GDScript — manifests and
  schemas are the only contract (§11.15). Validated by
  `tools/content_validator/validate.py` plus a separate `manifest.schema.json`.
- GDScript's single-threaded nature forces tactical sim to be conservative;
  see ADR-0002 for the unit / AI cap that compensates.

## Alternatives Considered

- **Unity 2D (URP / built-in)** — Rejected: heavier editor footprint,
  consumes more memory on the iGPU host, C# tooling pulls a 600+ MB
  install per machine, and licence tracking per export is heavier.
- **Godot with Forward+ + 3D** — Rejected: explicitly disallowed by
  §14.三. Forward+ does not run reliably on Intel UHD Graphics and
  the game is 2D.
- **GDScript untyped + custom DSL** — Rejected: violates §11.2 item 2
  and §11.7: AI would lose static reviewability; determinism becomes
  harder to assert.
- **Rust + macroquad / Bevy** — Rejected: build toolchain cost, slower
  iteration, and no TileMap parity with the script density we need.

## Open Questions

- None. The P0 spike `pixel_render_stable` (TAC-001-adjacent) is the one
  that will validate this ADR with multi-resolution screenshots
  (§11.21 / §12.4). If it fails, this ADR is reopened, not patched.

## Impact Surface

- `project.godot` — declare Compatibility renderer explicitly.
- `.tools/godot/` — pin the 4.6.2 portable download (already done in Stage 1).
- `tools/map_pipeline/` — Python CLI, no Godot dependency.
- `docs/adr/0006-maps-pipeline-python.md` — formalises the boundary.
- `docs/adr/0002-renderer-compatibility.md` — codifies what the renderer
  may never do.
