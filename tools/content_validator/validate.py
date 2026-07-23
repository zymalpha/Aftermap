#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/content_validator/validate.py
====================================

Validate content JSON files against the schemas in ``content/schemas/``.

Usage
-----

    python tools/content_validator/validate.py <content_dir>

Walk the given content directory recursively, match each ``*.json`` file
against a schema using its directory name, and report the first error per
file.  Exit code is ``0`` on success, ``1`` if any file fails.

Schema routing
--------------

The filename to schema mapping follows ADR-0001 / §11.7. The mapping is
fixed by convention:

============== =================================================
Directory       Schema
============== =================================================
items/          item.schema.json
facilities/     facility.schema.json
recipes/        recipe.schema.json
traits/         trait.schema.json
events/         event.schema.json
event-chains/   event-chain.schema.json
poi-rooms/      poi-room.schema.json
============== =================================================

Effect nodes (inside event/recipe effects) and condition nodes (inside
event triggers) are referenced through ``$ref`` to
``effect_node.schema.json`` and ``condition_node.schema.json``. JSON
Schema draft-07 resolver is configured locally — no network requests
are performed.

Path handling
-------------

All filesystem operations are UTF-8. Paths are normalised so the script
works on Windows (``\\``) and POSIX.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable, Optional, Tuple

try:
    from jsonschema import Draft7Validator
    from referencing import Registry, Resource
except ImportError:  # pragma: no cover - explicit failure mode
    sys.stderr.write(
        "ERROR: jsonschema package is missing. Install with:\n"
        "    pip install jsonschema\n"
    )
    sys.exit(2)


# ---------------------------------------------------------------------------
# Schema routing
# ---------------------------------------------------------------------------

# Map from content subdirectory name to the schema file (in
# content/schemas/). Subdirectory names are matched on the LAST path
# component of the file's parent folder, so content/items/foo.json matches
# even when content_dir is given as an absolute path.
DIR_TO_SCHEMA: dict[str, str] = {
    "items": "item.schema.json",
    "facilities": "facility.schema.json",
    "recipes": "recipe.schema.json",
    "traits": "trait.schema.json",
    "events": "event.schema.json",
    "event-chains": "event-chain.schema.json",
    "poi-rooms": "poi-room.schema.json",
    "specializations": "specialization.schema.json",
}


def load_schemas(schemas_dir: Path) -> dict[str, dict]:
    """Load every schema file in schemas_dir. Returns a name -> schema map."""
    loaded: dict[str, dict] = {}
    if not schemas_dir.exists():
        sys.stderr.write(
            f"ERROR: schema directory does not exist: {schemas_dir}\n"
        )
        sys.exit(2)
    for schema_path in sorted(schemas_dir.glob("*.schema.json")):
        try:
            with schema_path.open("r", encoding="utf-8") as fh:
                loaded[schema_path.name] = json.load(fh)
        except json.JSONDecodeError as exc:
            sys.stderr.write(
                f"ERROR: schema {schema_path} is not valid JSON: {exc}\n"
            )
            sys.exit(2)
    return loaded


def build_registry(schemas_dir: Path) -> Registry:
    """Build a referencing.Registry with all schemas loaded locally.

    Schemas are registered by both their filename and their ``$id``. The
    short ``$ref`` values (e.g. ``condition_node.schema.json``) used by
    sibling schemas resolve against this registry without HTTP fetch.
    """
    loaded = load_schemas(schemas_dir)
    resources: list[tuple[str, Resource]] = []
    for name, schema in loaded.items():
        resource = Resource.from_contents(schema)
        sid = schema.get("$id") if isinstance(schema, dict) else None
        if sid:
            resources.append((sid, resource))
        # Filename-only ref (the form used by sibling schemas).
        resources.append((name, resource))
    return Registry().with_resources(resources)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def iter_content_files(content_dir: Path) -> Iterable[Path]:
    """Yield every JSON file in the known content subdirectories."""
    for sub in DIR_TO_SCHEMA.keys():
        sub_path = content_dir / sub
        if not sub_path.exists():
            continue
        for json_path in sorted(sub_path.rglob("*.json")):
            if json_path.is_file():
                yield json_path


def best_effort_line(
    data: object, instance_path: list, source_text: str
) -> Optional[int]:
    """Try to locate the failing node in the source JSON.

    JSON Schemas reference nodes by ``instance_path`` (list of keys / indices).
    We approximate a line number by re-serialising the same path through a
    targeted search. This is intentionally best-effort and returns ``None``
    on any failure so that the validator never crashes on diagnostics.
    """
    try:
        cursor: object = data
        for step in instance_path:
            if isinstance(step, int):
                cursor = cursor[step]
            else:
                cursor = cursor[step]
    except (KeyError, IndexError, TypeError):
        return None

    try:
        serialised = json.dumps(cursor, ensure_ascii=False)
    except (TypeError, ValueError):
        return None

    snippet = serialised[:80]
    for line_no, line in enumerate(source_text.splitlines(), start=1):
        if snippet[:40] in line:
            return line_no
    return None


def validate_file(
    json_path: Path,
    content_dir: Path,
    schemas: dict[str, dict],
    registry: Registry,
) -> tuple[int, list[str]]:
    """Validate a single JSON file. Returns (error_count, messages)."""
    relative = json_path.relative_to(content_dir)
    sub_dir = relative.parts[0] if len(relative.parts) > 1 else ""
    schema_name = DIR_TO_SCHEMA.get(sub_dir)
    if schema_name is None:
        return 0, []  # not our responsibility

    schema = schemas.get(schema_name)
    if schema is None:
        return 1, [
            f"{relative}: missing schema file '{schema_name}' in schemas/"
        ]

    try:
        with json_path.open("r", encoding="utf-8") as fh:
            text = fh.read()
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        return 1, [f"{relative}: invalid JSON ({exc.msg})"]

    validator = Draft7Validator(schema, registry=registry)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))

    if not errors:
        return 0, []

    messages: list[str] = []
    for err in errors:
        path_label = "/".join(str(p) for p in err.absolute_path) or "<root>"
        line_no = best_effort_line(data, list(err.absolute_path), text)
        prefix = f"{relative}"
        if line_no is not None:
            prefix = f"{relative}:{line_no}"
        messages.append(f"{prefix} -> {path_label}: {err.message}")
    return len(errors), messages


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="validate.py",
        description="Validate content JSON files against content/schemas.",
    )
    parser.add_argument(
        "content_dir",
        help="Path to the content/ directory (e.g. ./content).",
    )
    parser.add_argument(
        "--schemas",
        default=None,
        help="Override the schemas directory (default: <content_dir>/../content/schemas).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print summary lines, not individual error reports.",
    )
    return parser.parse_args(argv)


def resolve_schemas_dir(args: argparse.Namespace) -> Path:
    if args.schemas:
        return Path(args.schemas).resolve()
    content_dir = Path(args.content_dir).resolve()
    # Convention: schemas live in <repo>/content/schemas, sibling of content_dir.
    candidate = content_dir.parent / "content" / "schemas"
    if candidate.exists():
        return candidate
    # Fallback: schemas inside the content_dir itself.
    candidate = content_dir / "schemas"
    return candidate


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    content_dir = Path(args.content_dir).resolve()
    if not content_dir.exists():
        sys.stderr.write(f"ERROR: content directory not found: {content_dir}\n")
        return 2

    schemas_dir = resolve_schemas_dir(args)
    schemas = load_schemas(schemas_dir)
    registry = build_registry(schemas_dir)

    failed = 0
    total = 0
    for json_path in iter_content_files(content_dir):
        total += 1
        err_count, messages = validate_file(json_path, content_dir, schemas, registry)
        if err_count == 0:
            continue
        failed += 1
        if not args.quiet:
            for msg in messages:
                sys.stderr.write(f"FAIL: {msg}\n")

    if failed == 0:
        sys.stdout.write(f"OK: {total} files validated\n")
        return 0

    sys.stderr.write(
        f"FAIL: {failed} of {total} files failed validation (see messages above)\n"
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())