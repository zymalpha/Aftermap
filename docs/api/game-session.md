# API — GameSession

> Source of truth: `game/core/game_session.gd`, `game/core/rng_service.gd`, `game/core/clock.gd`, `game/core/command_result.gd`, `game/adapters/saves/atomic_write.gd`, `game/adapters/saves/save_v1.gd`.

`GameSession` is the only mutator of persistent gameplay state. Presentation, AI, and event interpreters must call `issue_command()` rather than poking fields directly. Every command runs as a single transaction; a rejected handler restores the pre-call snapshot before returning a `CommandResult`.

## Lifecycle

```gdscript
var s := GameSession.new()
s.new_game(seed_value, "res://content")   # loads ContentDB, seeds RNG, clock starts at day 1, 06:00
# ... play ...
var snapshot := s.to_dict()
save_v1.write_atomic("user://savegame.json", snapshot)
# later
var loaded := save_v1.read_atomic("user://savegame.json")
s.from_dict(loaded)
```

`new_game()` returns a `CommandResult`. It is rejected if content fails to load or seed is invalid; in that case the session is left in a fresh empty state and the caller must not call `issue_command()`.

## Commands

Dispatch is `match cmd["kind"]` — see `game/core/game_session.gd` for the canonical list. This contract lists the kinds the current spike exercises; new kinds must add a new `_cmd_*` handler and update this table in the same commit.

| `kind`            | Required fields                  | Result (ok)                  | Notes                                                                                                  |
| ----------------- | -------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| `set_flag`        | `flag`, `value`                  | `flag_set`                   | `flag` must match safe-id (`^[a-z0-9_]+$`). Writes into `base_state.flags`.                              |
| `add_character`   | `character.id`, ...              | `character_added`            | Appends to `characters`. `id` must be safe-id.                                                          |
| `set_base_field`  | `key`, `value`                   | `base_field_set`             | Writes into `base_state[key]`. `key` must be safe-id.                                                   |
| `advance_day`     | (none)                           | `day_advanced`               | Increments `clock.current_day` and resets `city_minutes` to `START_CITY_MINUTES` (360).                  |
| `set_city_minutes`| `minutes` (0..1439)              | `city_minutes_set`           | Sets time-of-day; wraps via `Clock._wrap_minutes`.                                                       |

Any other `kind` -> `CommandResult.rejected("unknown_kind: <name>")`.

### CommandResult

Defined in `game/core/command_result.gd` (immutable value):

| Field       | Type     | Notes                                                                       |
| ----------- | -------- | --------------------------------------------------------------------------- |
| `ok`        | `bool`   | `true` on commit, `false` on reject.                                        |
| `code`      | `String` | Stable string code (`flag_set`, `set_flag_missing_flag`, `unknown_kind`, …).|
| `payload`   | `Dictionary` | Handler-defined extra data; safe to ignore.                            |

Codes are stable across versions and may be matched on by tests or telemetry.

## RNG (ADR-0003)

`game/core/rng_service.gd`. Eight named streams:

| Stream                       | Prefix?       | Used by                          |
| ---------------------------- | ------------- | -------------------------------- |
| `world_generation`           | exact         | Map / world-gen code path        |
| `city_state`                 | exact         | Daily city-state churn           |
| `poi_scene_<poi-id>`         | prefix        | Per-POI scene RNG                |
| `daily_director_<day>`       | prefix        | Event director per day           |
| `event_<event-id>`           | prefix        | Event effect sampling            |
| `combat_<combat-id>`         | prefix        | Combat resolution                |
| `character_generation`       | exact         | Character creation               |
| `cosmetic_only`             | exact         | Visual-only RNG — never gameplay |

`RngService.seed(seed_value)` reseeds the deterministic core; derived stream seeds are mixed from the core. `cosmetic_only` is allowed to drift across sessions — never read it inside gameplay logic.

| Method                                                     | Returns                                                   |
| ---------------------------------------------------------- | --------------------------------------------------------- |
| `seed(seed_value: int)`                                    | `void`                                                    |
| `ensure_stream(stream: StringName)`                        | `void` — idempotent, safe to call once per stream per session. |
| `get_rng(stream: StringName) -> int`                       | Next int63 in `[0, INT63_MAX]`.                           |
| `get_float(stream: StringName, lo: float, hi: float) -> float` | Uniform float in `[lo, hi]`.                          |
| `pick(stream: StringName, items: Array) -> Variant`        | Deterministic index into `items`.                          |

## Clock

`game/core/clock.gd`. Three `TimeScale` enum values: `CAMPAIGN_DAY`, `CITY_CLOCK`, `TACTICAL`. The current spike only consumes `CITY_CLOCK` (60 fps in-game minutes) and `CAMPAIGN_DAY` (whole-day ticks).

| Method                                            | Notes                                                  |
| ------------------------------------------------- | ------------------------------------------------------ |
| `tick(scale: int, dt: float)`                     | `dt` is **seconds**. Wraps `city_minutes` 0..1439.     |
| `set_time_of_day(hour: int, minute: int = 0)`     | Validates `0 ≤ hour ≤ 23`, `0 ≤ minute ≤ 59`.          |
| `get_time_of_day_string() -> String`              | `"HH:MM"`.                                              |
| `current_day: int`                                | Read-only property.                                     |
| `city_minutes: int`                               | Read-only property.                                     |

## Saves (ADR-0004)

`game/adapters/saves/atomic_write.gd` + `save_v1.gd`. Save format is `v1`:

```jsonc
{
  "format_version": 1,
  "saved_at": "2026-07-22T...",
  "content_fingerprint": "<sha256-hex>",
  "payload": { ... GameSession.to_dict() ... }
}
```

| Method                                                              | Behavior                                                                                          |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `save_v1.write_atomic(path: String, payload: Dictionary) -> Error`   | Writes to `<path>.tmp`, SHA-256 hashes the JSON, fsyncs, atomically renames. On failure: `.bak` retained. |
| `save_v1.read_atomic(path: String) -> Dictionary`                   | Reads JSON, verifies `format_version == 1` and SHA-256. On failure: tries `.bak`. Raises otherwise. |
| `save_v1.verify(path: String) -> bool`                              | Non-throwing; returns `true` only if SHA matches.                                                  |

The `.bak` sibling is the previous known-good save. It is overwritten only after a successful write of a new save.

## Serialization round-trip

`GameSession.to_dict()` + `from_dict(d)` is the persistence contract. Round-tripping the same session through `to_dict() -> from_dict()` must yield identical `debug_dump()` output. The current spike enforces this in `test_save_atomic_recovery.gd`.