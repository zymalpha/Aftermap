"""Manifest generator + validator.

A *map pack manifest* is the canonical metadata document referenced by
ADR-0004 / ADR-0006 / §11.17. It pins down version, fingerprints, POI
list and the legal attribution string, so saves can compare the
``content_fingerprint`` against the data they were recorded with and
refuse to load if it has changed underneath them.

This module:

* builds a manifest from a scenario template (``generate``);
* validates a manifest against the contract (``validate``) and returns
  a tuple ``(ok, errors)`` so the CLI can surface every issue at once.

Validation is intentionally *not* delegated to ``jsonschema`` here —
this is the Python-side fast path used by unit tests and the CLI.
The ``content/schemas/manifest.schema.json`` file is the authoritative
JSON-Schema definition used by the content validator pipeline.
"""
from __future__ import annotations

import copy
import hashlib
import json
import re
import time
from dataclasses import dataclass, field
from typing import Any

#: Allowed ``source`` values for ``validate``. Enumerated here so the
#: Python-side fast path is identical to the JSON Schema enum.
ALLOWED_SOURCES: tuple[str, ...] = ("preset-demo", "osm-snapshot")

#: Allowed license strings. The schema is stricter; this list matches
#: the values we currently ship.
ALLOWED_LICENSES: tuple[str, ...] = ("ODbL", "ODbL-1.0", "internal")

#: Bumped whenever the on-the-wire manifest shape changes.
MANIFEST_VERSION_DEFAULT: str = "0.1.0"

#: Required fields per §11.17 / ADR-0006.
REQUIRED_FIELDS: tuple[str, ...] = (
    "city_id",
    "name",
    "version",
    "fingerprint",
    "content_fingerprint",
    "pois",
    "generated_at",
    "source",
    "license",
)

#: POI sub-record required fields.
REQUIRED_POI_FIELDS: tuple[str, ...] = (
    "poi_id",
    "name",
    "class",
    "lat",
    "lon",
    "grid_w",
    "grid_h",
    "container_count",
)


# ---------------------------------------------------------------------------
# Exceptions + result types
# ---------------------------------------------------------------------------


class ManifestValidationError(ValueError):
    """Raised when a manifest fails the contract checks below.

    ``:attr:`errors`` carries the full ordered list of failures so
    callers (notably the CLI) can render them all at once.
    """

    def __init__(self, errors: list[str]) -> None:
        super().__init__("; ".join(errors) if errors else "manifest invalid")
        self.errors = list(errors)


# ---------------------------------------------------------------------------
# ManifestGenerator
# ---------------------------------------------------------------------------


@dataclass
class ManifestGenerator:
    """Generate + validate map pack manifests.

    The constructor accepts a clock callback so tests can pin
    ``generated_at`` to a deterministic value; production callers leave
    it on the default :func:`time.time`.
    """

    version: str = MANIFEST_VERSION_DEFAULT
    _clock: Any = field(default=time.time, repr=False)

    # ------------------------------------------------------------------
    # Generation
    # ------------------------------------------------------------------

    def generate(
        self,
        scenario: dict,
        *,
        city_id: str,
        name: str,
        license: str,
        source: str,
        pois: list[dict] | None = None,
    ) -> dict:
        """Build a manifest dict from a scenario template.

        ``scenario`` is the :meth:`POISceneTemplate.to_dict` payload
        produced by :mod:`scenario_generator`. It is included in the
        content fingerprint but is **not** serialised verbatim into
        the manifest — the manifest only stores metadata; the runtime
        city graph + scenarios are sibling artefacts.

        ``pois`` defaults to an empty list; callers typically load it
        from a preset manifest sample or from the content pipeline.
        """
        generated_at = _format_iso(self._clock())
        scenario_blob = json.dumps(scenario, sort_keys=True, ensure_ascii=False)
        content_fingerprint = hashlib.sha256(
            scenario_blob.encode("utf-8")
        ).hexdigest()

        pois_list = list(pois) if pois else []
        manifest: dict[str, Any] = {
            "city_id": city_id,
            "name": name,
            "version": self.version,
            "fingerprint": _placeholder_fingerprint(
                city_id, self.version, pois_list
            ),
            "content_fingerprint": content_fingerprint,
            "pois": pois_list,
            "generated_at": generated_at,
            "source": source,
            "license": license,
        }
        # Validate the freshly-built manifest so callers get a hard
        # failure rather than quietly producing garbage.
        ok, errors = self.validate(manifest)
        if not ok:
            raise ManifestValidationError(errors)
        return manifest

    # ------------------------------------------------------------------
    # Validation
    # ------------------------------------------------------------------

    def validate(self, manifest: dict) -> tuple[bool, list[str]]:
        """Return ``(ok, errors)``.

        ``ok`` is ``True`` iff ``errors`` is empty. ``errors`` is an
        ordered list of human-readable messages describing every
        failed check. The function never raises — callers can decide
        whether a hard failure is appropriate.
        """
        errors: list[str] = []
        if not isinstance(manifest, dict):
            return False, ["manifest must be a JSON object"]

        # Top-level required fields.
        for field_name in REQUIRED_FIELDS:
            if field_name not in manifest:
                errors.append(f"missing required field {field_name!r}")

        # Field type / value checks (only run when the field exists).
        _check_str(manifest, "city_id", errors)
        _check_str(manifest, "name", errors)
        _check_str(manifest, "version", errors, pattern=r"^\d+\.\d+\.\d+$")
        _check_str(manifest, "fingerprint", errors, pattern=r"^[0-9a-f]{8,}$")
        _check_str(manifest, "content_fingerprint", errors, pattern=r"^[0-9a-f]{8,}$")
        _check_str(manifest, "generated_at", errors)
        _check_str(manifest, "source", errors, allowed=ALLOWED_SOURCES)
        _check_str(manifest, "license", errors, allowed=ALLOWED_LICENSES)
        _check_list(manifest, "pois", errors)
        if "pois" in manifest and isinstance(manifest["pois"], list):
            for idx, poi in enumerate(manifest["pois"]):
                self._validate_poi(poi, idx, errors)

        return (len(errors) == 0), errors

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _validate_poi(
        self, poi: Any, idx: int, errors: list[str]
    ) -> None:
        prefix = f"pois[{idx}]"
        if not isinstance(poi, dict):
            errors.append(f"{prefix} must be a JSON object")
            return
        for fname in REQUIRED_POI_FIELDS:
            if fname not in poi:
                errors.append(f"{prefix} missing required field {fname!r}")
        if "poi_id" in poi and not _is_str(poi.get("poi_id")):
            errors.append(f"{prefix}.poi_id must be a string")
        if "name" in poi and not _is_str(poi.get("name")):
            errors.append(f"{prefix}.name must be a string")
        if "class" in poi and not _is_str(poi.get("class")):
            errors.append(f"{prefix}.class must be a string")
        if "lat" in poi and not _is_number(poi.get("lat")):
            errors.append(f"{prefix}.lat must be a number")
        if "lon" in poi and not _is_number(poi.get("lon")):
            errors.append(f"{prefix}.lon must be a number")
        if "grid_w" in poi and not _is_int(poi.get("grid_w")):
            errors.append(f"{prefix}.grid_w must be an integer")
        if "grid_h" in poi and not _is_int(poi.get("grid_h")):
            errors.append(f"{prefix}.grid_h must be an integer")
        if "container_count" in poi and not _is_int(poi.get("container_count")):
            errors.append(f"{prefix}.container_count must be an integer")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _placeholder_fingerprint(
    city_id: str, version: str, pois: list[dict]
) -> str:
    """Build a deterministic place-holder fingerprint for a manifest.

    Production will fold in the full content hash (graph + scenario +
    geometry); the placeholder is enough to satisfy schema-driven
    tests and to keep fingerprints stable across re-runs.
    """
    payload = json.dumps(
        {"city_id": city_id, "version": version, "pois": pois},
        sort_keys=True,
        ensure_ascii=False,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def _format_iso(ts: float) -> str:
    """Format ``ts`` as ISO-8601 UTC without milliseconds."""
    gm = time.gmtime(ts)
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", gm)


def _check_str(
    manifest: dict, field_name: str, errors: list[str], *,
    pattern: str | None = None, allowed: tuple[str, ...] | None = None,
) -> None:
    if field_name not in manifest:
        return  # already reported by required-field check
    value = manifest[field_name]
    if not _is_str(value):
        errors.append(f"{field_name!r} must be a string")
        return
    if pattern is not None and not re.search(pattern, value):
        errors.append(f"{field_name!r}={value!r} does not match required pattern {pattern!r}")
    if allowed is not None and value not in allowed:
        errors.append(
            f"{field_name!r}={value!r} not in allowed list {sorted(allowed)!r}"
        )


def _check_list(manifest: dict, field_name: str, errors: list[str]) -> None:
    if field_name not in manifest:
        return
    if not isinstance(manifest[field_name], list):
        errors.append(f"{field_name!r} must be a JSON array")


def _is_str(value: Any) -> bool:
    return isinstance(value, str) and bool(value)


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


# ---------------------------------------------------------------------------
# Convenience: deep-clone a manifest without mutating the original
# ---------------------------------------------------------------------------


def clone_manifest(manifest: dict) -> dict:
    """Return a deep copy of a manifest, useful for tamper-detection tests."""
    return copy.deepcopy(manifest)


__all__ = [
    "ManifestGenerator",
    "ManifestValidationError",
    "ALLOWED_SOURCES",
    "ALLOWED_LICENSES",
    "REQUIRED_FIELDS",
    "REQUIRED_POI_FIELDS",
    "clone_manifest",
]
