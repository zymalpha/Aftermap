# API — Content DB

> Source of truth: `game/core/content_db.gd`, `content/schemas/*.schema.json`, `tools/content_validator/validate.py`.

`ContentDB` loads every JSON file under the configured content root, validates it against its schema, and exposes lookup-by-id. The DB is read-only at runtime; reload requires a new session.

## Kinds

The DB recognises the following subdirectory names (constants on `ContentDB.KNOWN_KINDS`):

| Kind           | Directory         | Required id pattern | Schema                            |
| -------------- | ----------------- | ------------------- | --------------------------------- |
| `items`        | `content/items/`  | `^itm_[a-z0-9_]+$`  | `item.schema.json`                |
| `events`       | `content/events/` | `^evt_[a-z0-9_]+$`  | `event.schema.json`               |
| `event-chains` | `content/event-chains/` | `^chain_[a-z0-9_]+$` | `event-chain.schema.json`     |
| `facilities`   | `content/facilities/` | `^fac_[a-z0-9_]+$` | `facility.schema.json`          |
| `traits`       | `content/traits/` | `^trt_[a-z0-9_]+$`  | `trait.schema.json`               |
| `poi-rooms`    | `content/poi-rooms/` | `^poi_[a-z0-9_]+$` | `poi-room.schema.json`          |
| `recipes`      | `content/recipes/` | `^rec_[a-z0-9_]+$`  | `recipe.schema.json`              |

New kinds require: (1) a JSON schema in `content/schemas/`, (2) an entry in `ContentDB.KNOWN_KINDS`, (3) a corresponding `_light_validate` branch in `content_db.gd`, (4) a sample file in the matching directory, and (5) a regression entry in `tools/content_validator/validate.py`.

## Lookup

| Method                                       | Notes                                                              |
| -------------------------------------------- | ------------------------------------------------------------------ |
| `ContentDB.load_all(content_dir: String)`    | Walks `content_dir` for known kind subdirs and loads every JSON.    |
| `get_record(kind: String, id: String) -> Variant` | Returns the parsed dictionary, or `null` if not found.        |
| `list_ids(kind: String) -> Array[String]`    | Sorted list of all ids in that kind.                                |
| `get_fingerprint() -> String`                | Stable SHA-256 over (kind, id, sorted-keys JSON) of every record.   |

## Save integration

`ContentDB.to_dict() / from_dict(d)` round-trip the **metadata** (fingerprint, schema paths, file list) — **not** the records themselves. Records are reloaded from disk on `GameSession.from_dict()` to keep saves small and to honour ADR-0004's "versioned + content-fingerprinted" rule.

`GameSession.save_meta.content_fingerprint` is asserted equal to the on-disk fingerprint on load; mismatch is a hard error (the save was made against a different content set).

## Validation pipeline

`tools/content_validator/validate.py <content_root>` is the offline validator used by CI and `run.sh`. It runs jsonschema validation against every JSON under the root. Exit codes:

- `0` — every file valid; prints summary.
- non-zero — at least one file failed; prints per-file failure with json-pointer path.

The validator is **strict**: `additionalProperties: false` is enforced on all schemas. The Godot-side `_light_validate()` does only the cheapest checks (id pattern, kind enum) — full validation is the Python validator's job.

## Fingerprint semantics

`get_fingerprint()` is computed by:

1. Sort `(kind, id)` pairs.
2. For each record, dump to JSON with sorted keys (Python `json.dumps(..., sort_keys=True)`).
3. SHA-256 over the concatenated bytes; hex-encode.

The same content set always produces the same fingerprint. Adding, removing, or modifying any record changes the fingerprint. The fingerprint is what `save_meta.content_fingerprint` checks against on load.