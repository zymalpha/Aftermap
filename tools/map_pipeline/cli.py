"""Command-line entry point for ``tools/map_pipeline``.

Subcommands mirror §11.15.3 / ADR-0006 §1:

* ``fetch``    — placeholder; prints a ``NotImplemented`` notice and
  exits with code 1. Real OSM fetch is gated behind ADR-0006 §2.
* ``build``    — generate a manifest + scenario from a local preset.
  Does not hit the network.
* ``validate`` — validate a manifest file against the contract.
* ``preview``  — print a human-readable summary + POI listing.

Run ``python -m tools.map_pipeline.cli --help`` for usage.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .manifest_generator import ManifestGenerator
from .osm_fetcher import NOT_IMPLEMENTED_REASON
from .scenario_generator import ScenarioGenerator


# Default repo-relative preset location. Centralised so tests and CLI
# agree on the canonical sample.
DEFAULT_PRESET_PATH: str = "content/maps/presets/nanjing_demo.json"


# ---------------------------------------------------------------------------
# Subcommand handlers
# ---------------------------------------------------------------------------


def _cmd_fetch(_: argparse.Namespace) -> int:
    """Run the ``fetch`` subcommand.

    Per ADR-0006 §2, real OSM fetching is deferred. We print a stable,
    greppable notice and exit ``1`` so CI catches any accidental call.
    """
    print(f"NotImplemented: {NOT_IMPLEMENTED_REASON}", file=sys.stderr)
    return 1


def _cmd_build(args: argparse.Namespace) -> int:
    """Generate a manifest + scenario from a local preset."""
    gen = ManifestGenerator(version=args.version)
    scenario = ScenarioGenerator().generate(
        city_graph=__import__(
            "tools.map_pipeline.city_graph_builder",
            fromlist=["CityGraph"],
        ).CityGraph(),
        party_size=args.party_size,
        rng_seed=args.seed,
    )
    preset = _load_preset(args.preset)
    pois = preset.get("pois", [])
    manifest = gen.generate(
        scenario.to_dict(),
        city_id=preset.get("city_id", "unknown"),
        name=preset.get("name", "unknown"),
        license=preset.get("license", "internal"),
        source=preset.get("source", "preset-demo"),
        pois=pois,
    )
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"wrote manifest: {output_path}")
    return 0


def _cmd_validate(args: argparse.Namespace) -> int:
    """Validate a manifest JSON file against the contract."""
    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        print(f"error: manifest not found: {manifest_path}", file=sys.stderr)
        return 2
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    gen = ManifestGenerator()
    ok, errors = gen.validate(data)
    if ok:
        print(f"OK: {manifest_path}")
        return 0
    print(f"FAIL: {manifest_path}", file=sys.stderr)
    for err in errors:
        print(f"  - {err}", file=sys.stderr)
    return 1


def _cmd_preview(args: argparse.Namespace) -> int:
    """Print a short summary + POI listing."""
    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        print(f"error: manifest not found: {manifest_path}", file=sys.stderr)
        return 2
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    print(f"Manifest: {manifest_path}")
    print(f"  city_id      = {data.get('city_id')!r}")
    print(f"  name         = {data.get('name')!r}")
    print(f"  version      = {data.get('version')!r}")
    print(f"  license      = {data.get('license')!r}")
    print(f"  source       = {data.get('source')!r}")
    print(f"  generated_at = {data.get('generated_at')!r}")
    print(f"  fingerprint  = {data.get('fingerprint')!r}")
    print(f"  POIs ({len(data.get('pois', []))}):")
    for poi in data.get("pois", []):
        print(
            f"    - {poi.get('poi_id'):>10}  {poi.get('class'):>11}  "
            f"{poi.get('name'):<24} grid={poi.get('grid_w')}x{poi.get('grid_h')}"
        )
    return 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_preset(path: str) -> dict:
    preset_path = Path(path)
    if not preset_path.exists():
        return {}
    return json.loads(preset_path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# Argparse wiring
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="map_pipeline",
        description=(
            "Map pipeline CLI. Subcommand 'fetch' is intentionally a "
            "no-op until the OSM gate re-opens (ADR-0006)."
        ),
    )
    sub = parser.add_subparsers(dest="subcommand", required=True)

    p_fetch = sub.add_parser("fetch", help="fetch OSM snapshot (deferred)")
    p_fetch.set_defaults(handler=_cmd_fetch)

    p_build = sub.add_parser(
        "build", help="build a manifest from a preset manifest sample"
    )
    p_build.add_argument(
        "--preset",
        default=DEFAULT_PRESET_PATH,
        help=f"preset manifest JSON (default: {DEFAULT_PRESET_PATH})",
    )
    p_build.add_argument("--party-size", type=int, default=4)
    p_build.add_argument("--seed", type=int, default=42)
    p_build.add_argument("--version", default="0.1.0")
    p_build.add_argument(
        "--output",
        default="build/manifest.json",
        help="output manifest path",
    )
    p_build.set_defaults(handler=_cmd_build)

    p_validate = sub.add_parser("validate", help="validate a manifest JSON file")
    p_validate.add_argument("manifest", help="path to manifest.json")
    p_validate.set_defaults(handler=_cmd_validate)

    p_preview = sub.add_parser("preview", help="print a manifest summary")
    p_preview.add_argument("manifest", help="path to manifest.json")
    p_preview.set_defaults(handler=_cmd_preview)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    handler = getattr(args, "handler", None)
    if handler is None:
        parser.print_help()
        return 2
    return int(handler(args))


if __name__ == "__main__":  # pragma: no cover - executed via __main__
    sys.exit(main())
