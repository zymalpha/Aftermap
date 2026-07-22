# API — Tactical Session

> Source of truth: `game/domain/tactical/*.gd`, `game/presentation/pixel_scaling.gd`, `game/presentation/scenes/tactical.tscn`.

The tactical session is a stateful container that owns grid, pathfinder, movement, FOV, sound, alertness, combat, search, and the `PauseQueue` command queue. It is driven by `GameSession` clock ticks and never mutates gameplay state directly.

> Note: the current P1 spike inlines tactical modules directly inside test scripts (`test_p1_tactical.gd`) so we can exercise the end-to-end flow without committing to a final wrapper class. The modules documented below are the stable units; P2 wraps them behind `TacticalSession` (see BACKLOG `MAP-2`).

## Coordinate system

- Cells are `Vector2i`.
- `Grid.PIXELS_PER_TILE == 32`.
- World pixel position = `grid_to_world(cell)`; reverse via `world_to_grid(world)`.

## Grid (`game/domain/tactical/grid.gd`)

| Method                                          | Notes                                       |
| ----------------------------------------------- | ------------------------------------------- |
| `Grid(w: int, h: int)`                          | Rectangular grid; not tileset-aware.        |
| `size() -> Vector2i`                            | `(w, h)`.                                   |
| `in_bounds(p: Vector2i) -> bool`                | `0 ≤ x < w && 0 ≤ y < h`.                   |
| `world_to_grid(world: Vector2) -> Vector2i`     | Truncates.                                  |
| `grid_to_world(cell: Vector2i) -> Vector2`      | Cell origin in pixel space.                 |
| `to_dict() / from_dict()`                       | Save-roundtrip; preserves `w` and `h`.      |

## Pathfinder (`game/domain/tactical/pathfinder.gd`)

`Pathfinder.a_star(grid, start, goal, blocked) -> Array[Vector2i]`

- 8-directional, diagonal cost `1.5`, orthogonal `1.0`.
- `blocked` is an `Array[Vector2i]` of impassable cells (called *before* the move is committed).
- Returns the cell sequence **including** `start` and `goal`. Returns empty array if no path.
- `start` / `goal` must be `in_bounds`; out-of-bounds inputs return `[]`.

`Pathfinder` is **pure / static** — it owns no mutable heap state across calls. Used in `test_grid_pathfind.gd`.

## Visibility / FOV (`game/domain/tactical/visibility.gd`)

| Method                                                                                  | Returns                          |
| --------------------------------------------------------------------------------------- | -------------------------------- |
| `Visibility.fov_from(grid, origin, radius, blockers) -> Array[Vector2i]`                | All cells in FOV radius.         |
| `Visibility.can_see(grid, origin, target, blockers) -> bool`                            | Ray-cast LOS check.              |
| `Visibility.is_symmetric(grid, origins, radius, blockers) -> bool`                      | True iff `can_see(o1,o2)` for all pairs. |

`blockers` are opaque cells. Symmetry is asserted in the P1 spike.

## Sound (`game/domain/tactical/sound_pulse.gd`)

`SoundPulse` emits an audible pulse from a cell. Material constants:

| Material constant       | Attenuation |
| ----------------------- | ----------- |
| `MATERIAL_OPEN`         | 1.00        |
| `MATERIAL_DOOR_OPEN`    | 0.60        |
| `MATERIAL_WALL`         | 0.20        |
| `MATERIAL_DOOR_CLOSED`  | 0.00        |

Per-cell decay: `DECAY_PER_CELL = 0.5`. A pulse propagates outward; receivers multiply the per-step decay by the material attenuation of the cell they stand in.

## Alertness (`game/domain/tactical/alertness.gd`)

`Alertness.Stage`: `NONE → SUSPICIOUS → INVESTIGATING → ALERT → LOCKED_ON`.

Stimulus constants:

| Constant           | Meaning                            |
| ------------------ | ---------------------------------- |
| `STIM_VISIBLE_TARGET` | Target in FOV.                  |
| `STIM_HEARD_PULSE`    | Sound pulse above hearing floor.|
| `STIM_EVIDENCE`       | Corpse / broken door / blood.    |
| `STIM_LOST_TARGET`    | Target dropped from FOV.         |

Thresholds:

| Threshold name              | Value | Meaning                                            |
| --------------------------- | ----- | -------------------------------------------------- |
| `SUSPICIOUS_THRESHOLD`      | 5     | Intensity ≥ this = "heard something".              |
| `INVESTIGATING_THRESHOLD`   | 15    | Sustained ticks of hearing push to INVESTIGATING.  |
| `HEAR_TICKS`                | 3     | Number of sustained ticks before escalating.       |
| `ALERT_THRESHOLD`           | 30    | Evidence-level intensity = full combat alert.       |
| `DECAY_SECS`                | 10.0  | Intensity decay window.                            |

`Alertness.update(stimuli: Array, dt: float)` advances the state machine. Stimulus shape: `{"kind": STIM_*, "intensity": int, "source": Vector2i}`. To / from dict for save round-trip.

## Movement (`game/domain/tactical/movement.gd`)

`MovementSystem` is step-driven.

| Property / method                          | Notes                                                            |
| ------------------------------------------ | ---------------------------------------------------------------- |
| `ALLOWED_SPEED = [1, 2]`                   | 1x = one cell per second; 2x = one cell per 0.5s.               |
| `request_speed(s: int, alert: bool)`       | Returns true on accept; false on reject (invalid speed).        |
| `plan_path(path: Array[Vector2i])`          | Stores planned path.                                             |
| `pop_next() -> Vector2i`                   | Pops next cell.                                                  |
| `step_count() / remaining() / has_more()`  | Bookkeeping.                                                     |
| `to_dict() / from_dict()`                  | Save round-trip.                                                 |

`MovementSystem` does not move entities on its own; the calling system (a `TacticalSession` wrapper or test) pops cells and applies them.

## Combat (`game/domain/tactical/combat.gd`)

Weapon constants: `WEAPON_KNIFE`, `WEAPON_PIPE`, `WEAPON_HATCHET`, `WEAPON_SLEDGE`, `WEAPON_CROSSBOW`, `WEAPON_PISTOL_9MM`, `WEAPON_SHOTGUN`, `WEAPON_RIFLE`. Each maps to base damage / range / sound. Resolution formula (P1 stub):

```
hit_chance = clamp(
  base + SKILL_HIT_PER_LEVEL * skill_level
        - DISTANCE_PENALTY_PER_CELL * distance
        - MOVE_PENALTY * (moved_this_turn ? 1 : 0)
        - FULL_COVER_PENALTY * full_cover
        - HALF_COVER_PENALTY * half_cover
        - DARKNESS_PENALTY * (dark ? 1 : 0)
        - FATIGUE_PENALTY_MAX * fatigue_ratio,
  HIT_MIN, HIT_MAX)
```

Final implementation lives in P2 (BACKLOG `COMBAT-2`). The current spike stubs deterministic counters that match the formula shape so end-to-end tests can wire it through `GameSession` without behavioral risk.

## Search (`game/domain/tactical/search.gd`)

`SearchSystem.Mode`: `QUICK`, `STANDARD`, `THOROUGH`. Each has cost (`MODE_*_SECONDS`), sound radius (`MODE_*_SOUND`), and discovery risk (`MODE_*_RISK`). Skill tables (`SKILL_TIME_FACTOR[6]`, `SKILL_IDENTIFY_BONUS[6]`) reduce time and raise identify chance.

## PauseQueue (`game/domain/tactical/command_queue.gd`)

`ALLOWED_SPEEDS = [0, 1, 2]` where `0` means paused. Holds pending tactical commands while paused; flushes on resume. Round-trips through `to_dict() / from_dict()`.

## Pixel scaling (`game/presentation/pixel_scaling.gd`)

Single `Node2D`-compatible helper that snaps a viewport to integer pixel sizes for the Compatibility renderer. Used by `tactical.tscn`. Documented for completeness — behavior is exercised in `test_pixel_scaling.gd`.