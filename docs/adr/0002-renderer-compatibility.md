# ADR-0002: Renderer — Compatibility / OpenGL only, 2D pixel pipeline, 30 AI cap

- Status: Accepted
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.21 / §14.三 / §10_美术规范 (referenced) / §12.4 P0 spike
  `pixel_render_stable`

## Context

§14.三 (items 1, 2, 3, 6, 8) and §11.21 jointly impose a binding
performance budget on the renderer:

- Hardware target: Intel UHD Graphics (integrated, shared memory)
  on a Core i5-12450H / 16 GB laptop, Windows x86_64.
- Target 60 fps in normal tactical scenes, 30 fps minimum under stress
  (§11.21 / §14.三 item 7).
- 30 simulated AI units is a **stress ceiling only**, not a steady state
  (§14.三 item 8).
- Internal render resolution 1280×720, with window scaling to 1920×1080
  (§14.三 item 4).
- Pixel art must remain stable across resolutions; using high-res art
  and down-scaling is forbidden (§14.八 last bullet).

These come from the §11.1 table, the §11.21 budget table, and the
performance-floor statements in §14.三. The combination rules out the
Forward+ renderer, any 3D pipeline, dynamic shadows, full-screen
post-processing, and viewport-wide GPU particle stacks.

## Decision

1. The project ships **only** with the Compatibility / OpenGL backend.
   `project.godot` must set `rendering/renderer/rendering_method = "gl_compatibility"`.
   Forward+ is **not configured**, and 3D nodes are not imported.
2. The game is **strictly 2D** (`Node2D`, `TileMap`, `AnimatedSprite2D`,
   `Light2D` only). No `MeshInstance3D`, no `CSGShape3D`, no
   `WorldEnvironment` with 3D sky / volumetric fog.
3. **No dynamic lighting from `Light2D` for gameplay** — `Light2D` is
   allowed only for room-occlusion previews inside tactical scenes
   where the cost is bounded by room geometry, not by per-unit lights.
   Game visibility / line-of-sight is computed by `TacticalSimulation`,
   never by blending many GL lights (§11.13.3).
4. **No full-screen post-processing.** ColorRect / CanvasLayer overlays
   are allowed for fade and accessibility; ShaderMaterial post-effects
   are forbidden.
5. **Integer-stable upscaling.** `window/content_scale_mode = "viewport"`
   or `"integer"`, `content_scale_aspect = "expand"`, and pixel-art
   textures are imported with `filter` off (`nearest`), `mipmap` off,
   `repeat` honoured by the source art.
6. **Performance budget** (from §11.21):
   - 4 active player units (hard cap on player squad).
   - 30 simulated AI units (stress ceiling; default encounters far lower).
   - Memory ceiling: 2 GB for MVP runtime (§11.21).
   - Nightly settlement: < 200 ms for 12 survivors × 30 days (§11.21).

## Consequences

Positive:
- Compatibility renderer is the only path reliably supported by Intel
  UHD Graphics (§14.三 item 2).
- The "stress ceiling ≠ normal play" rule keeps day-to-day scenes
  responsive even when a designer briefly pushes the AI cap.
- Disallowing full-screen shaders forces ambient / atmosphere to come
  from tile art and CPU-driven VFX, which the content team can author
  in 32×32 grids as §14.八 item 1 prescribes.

Negative / constraints:
- We cannot use `Light2D` to express stealth cones. Visibility will
  have to be baked into `TileMap` tiles and surfaced as a binary /
  graded overlay; this is, in any case, what §11.13.2 requires for
  deterministic tests.
- Tile atlases must be designed so that night / day / rain variants
  are authored separately, not blended via shader — that raises the
  art asset count. Mitigated by §12.15 scope-locks and the "low-cost
  pixel pipeline" described in §14.八 item 1.
- The 30 AI cap forbids several "horde mode" prototypes.

## Alternatives Considered

- **Forward+ on high-end hardware** — Rejected: violates §14.三 item 2
  and the MVP's Windows x86_64 target.
- **Custom 2D pixel-perfect shader that scales nearest in a fragment**
  — Rejected: same visual result with less debuggability; viewports
  already give the same effect.
- **Light2D-based stealth** — Considered, deferred to P2+. Hidden cost
  scales with overlapping lights, not actors; we need
  per-tile visibility to remain testable (§11.22.4).
- **Dynamic resolution / FSR** — Deferred. The MVP does not need it, and
  we have no measurement proving that scaling is needed at all.

## Open Questions

- None at P0. The `pixel_render_stable` spike (§12.4) must validate
  step 5 across 1280×720, 1920×1080, 16:10 and ultra-wide aspect
  ratios. If it fails for any aspect ratio, this ADR reopens.

## Impact Surface

- `project.godot` — render method and viewport config (P0 task).
- `tools/build/` — Windows export preset must keep Compatibility mode.
- Art pipeline notes — recorded under `docs/production/ART_NOTES.md` later.
- Performance smoke script — `tests/headless/perf_smoke.py` will
  enforce the 4 + 30 unit budget before a build is signed off.
