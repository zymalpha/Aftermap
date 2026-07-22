"""Unit tests for :mod:`tools.map_pipeline.manifest_generator`.

The Nanjing preset sample must validate as-is. Tampering with the
``fingerprint`` or ``license`` field must flip :meth:`validate` to a
failure with a recognisable error message.

These tests deliberately exercise the Python-side fast path; the JSON
Schema document under ``content/schemas/manifest.schema.json`` is
authoritative for the cross-tool contract.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.map_pipeline.manifest_generator import (
    ALLOWED_LICENSES,
    ManifestGenerator,
    clone_manifest,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def nanjing_preset() -> dict:
    preset_path = (
        Path(__file__).resolve().parents[3]
        / "content"
        / "maps"
        / "presets"
        / "nanjing_demo.json"
    )
    return json.loads(preset_path.read_text(encoding="utf-8"))


@pytest.fixture
def validator() -> ManifestGenerator:
    return ManifestGenerator()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_nanjing_preset_validates_clean(validator: ManifestGenerator, nanjing_preset: dict) -> None:
    """The as-shipped preset must pass :meth:`validate` without errors."""

    ok, errors = validator.validate(nanjing_preset)
    assert ok is True, f"unexpected errors: {errors!r}"


def test_tampered_fingerprint_fails_validation(
    validator: ManifestGenerator, nanjing_preset: dict
) -> None:
    """Flipping the fingerprint must invalidate the manifest."""

    tampered = clone_manifest(nanjing_preset)
    # Too short and non-hex; the pattern requires `[0-9a-f]{8,}`.
    tampered["fingerprint"] = "!!!"
    ok, errors = validator.validate(tampered)
    assert ok is False
    assert any("fingerprint" in err for err in errors)


def test_tampered_license_fails_validation(
    validator: ManifestGenerator, nanjing_preset: dict
) -> None:
    """An unsupported license must invalidate the manifest."""

    tampered = clone_manifest(nanjing_preset)
    tampered["license"] = "AllRightsReserved"
    # Sanity-check that our test value is genuinely off-list.
    assert tampered["license"] not in ALLOWED_LICENSES

    ok, errors = validator.validate(tampered)
    assert ok is False
    assert any("license" in err for err in errors)


def test_required_field_set_blocks_missing_top_level_fields(
    validator: ManifestGenerator, nanjing_preset: dict
) -> None:
    """Every required top-level field must be checked for absence."""

    for field_name in (
        "city_id",
        "name",
        "version",
        "fingerprint",
        "content_fingerprint",
        "pois",
        "generated_at",
        "source",
        "license",
    ):
        tampered = clone_manifest(nanjing_preset)
        del tampered[field_name]
        ok, errors = validator.validate(tampered)
        assert ok is False, f"expected {field_name} removal to fail"
        assert any(field_name in err for err in errors)


def test_missing_required_poi_subfield_fails(
    validator: ManifestGenerator, nanjing_preset: dict
) -> None:
    """Each required POI sub-record field must be checked for absence."""

    tampered = clone_manifest(nanjing_preset)
    del tampered["pois"][0]["grid_w"]
    ok, errors = validator.validate(tampered)
    assert ok is False
    assert any("grid_w" in err for err in errors)


def test_generate_round_trips_through_validate(
    validator: ManifestGenerator,
) -> None:
    """A freshly-built manifest must validate cleanly."""

    manifest = validator.generate(
        scenario={"placeholder": True},
        city_id="ci_demo_01",
        name="演示",
        license="internal",
        source="preset-demo",
        pois=[
            {
                "poi_id": "poi_demo_01",
                "name": "示范",
                "class": "clinic",
                "lat": 32.05,
                "lon": 118.78,
                "grid_w": 8,
                "grid_h": 8,
                "container_count": 1,
            }
        ],
    )
    ok, errors = validator.validate(manifest)
    assert ok is True, f"errors: {errors!r}"
    assert manifest["version"] == validator.version
