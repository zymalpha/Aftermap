# Content Validator

Validates the JSON content files under `content/` against the schemas in
`content/schemas/`.

## Requirements

- Python 3.10 or newer (3.12 used in development).
- `jsonschema` package (4.x). Install with:
  ```bash
  pip install jsonschema
  ```

## Usage

From the workspace root:

```bash
python tools/content_validator/validate.py content/
```

You can also validate a single content directory elsewhere; the schema
directory is auto-detected as `<content_dir>/../content/schemas`. To
override it explicitly:

```bash
python tools/content_validator/validate.py content/ --schemas content/schemas
```

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | All files validated successfully (`OK: N files validated` printed). |
| 1 | One or more files failed validation (first failure per file printed). |
| 2 | Setup error (missing `jsonschema`, missing directory, invalid schema). |

## What it validates

The validator walks every `.json` file inside the directories
`items/`, `facilities/`, `recipes/`, `traits/`, `events/`,
`event-chains/`, `poi-rooms/` (relative to the content root) and checks
it against the matching schema:

| Directory | Schema |
|---|---|
| `items/` | `item.schema.json` |
| `facilities/` | `facility.schema.json` |
| `recipes/` | `recipe.schema.json` |
| `traits/` | `trait.schema.json` |
| `events/` | `event.schema.json` |
| `event-chains/` | `event-chain.schema.json` |
| `poi-rooms/` | `poi-room.schema.json` |

Effects and conditions are referenced through `$ref` to
`effect_node.schema.json` and `condition_node.schema.json`. The validator
resolves them locally; no network access is required.

## CI usage

In CI / pre-commit, run the validator and abort on non-zero exit:

```bash
python tools/content_validator/validate.py content/ && echo "content OK"
```

If you want machine-readable output for build pipelines, combine with
`--quiet` to suppress the per-file failure messages and parse the final
`FAIL: x of y files failed` summary line instead.