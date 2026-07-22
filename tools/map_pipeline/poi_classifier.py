"""POI classification from OSM tags.

Mirrors the 12 POI classes defined in :file:`content/schemas/poi-room.schema.json`
and §12.9.2 of the planning docs:

    pharmacy / clinic / grocery / depot / residence / police /
    school / gas_station / warehouse / park / industrial / office

The classifier is **deterministic and pure**: given the same tag dict it
returns the same POI class. It scores each candidate class on a small
set of OSM tag rules and returns the highest-confidence hit. Tag sets
that match no rule raise :class:`ValueError`, which is how the caller
distinguishes "unknown" from "low confidence"; the :class:`POIClassifier`
also exposes :meth:`POIClassifier.confidence` for a numeric read-out.

This module is intentionally framework-free so it can be unit-tested
without Godot, network, or filesystem dependencies.
"""
from __future__ import annotations

from enum import Enum
from typing import Mapping


class POIClass(str, Enum):
    """The 12 POI classes required by §12.9.2 / P5 quota."""

    PHARMACY = "pharmacy"
    CLINIC = "clinic"
    GROCERY = "grocery"
    DEPOT = "depot"
    RESIDENCE = "residence"
    POLICE = "police"
    SCHOOL = "school"
    GAS_STATION = "gas_station"
    WAREHOUSE = "warehouse"
    PARK = "park"
    INDUSTRIAL = "industrial"
    OFFICE = "office"
    UNKNOWN = "unknown"


# Numeric weight per hit. Higher == stronger evidence. The classifier
# sums weights for matching tags and picks the class with the highest
# total score.
_TAG_WEIGHTS: dict[POIClass, dict[str, int]] = {
    POIClass.PHARMACY: {
        "amenity=pharmacy": 10,
        "shop=pharmacy": 8,
        "healthcare=pharmacy": 9,
        "dispensing=yes": 3,
    },
    POIClass.CLINIC: {
        "amenity=clinic": 10,
        "amenity=doctors": 9,
        "amenity=hospital": 7,
        "healthcare=clinic": 9,
        "healthcare=hospital": 7,
    },
    POIClass.GROCERY: {
        "shop=supermarket": 10,
        "shop=convenience": 8,
        "shop=greengrocer": 9,
        "shop=bakery": 5,
        "shop=butcher": 5,
    },
    POIClass.DEPOT: {
        "amenity=depot": 10,
        "landuse=depot": 9,
        "industrial=depots": 9,
        "railway=depot": 8,
    },
    POIClass.RESIDENCE: {
        "building=residential": 9,
        "building=house": 8,
        "building=apartments": 10,
        "building=dormitory": 8,
        "landuse=residential": 7,
        "residential=*": 4,  # weak signal — see ``*`` notes in classifier
    },
    POIClass.POLICE: {
        "amenity=police": 10,
        "office=government": 4,
        "government=police": 9,
    },
    POIClass.SCHOOL: {
        "amenity=school": 10,
        "amenity=kindergarten": 9,
        "amenity=college": 9,
        "amenity=university": 9,
    },
    POIClass.GAS_STATION: {
        "amenity=fuel": 10,
        "shop=gas": 7,
        "highway=services": 4,
    },
    POIClass.WAREHOUSE: {
        "building=warehouse": 10,
        "landuse=industrial": 3,
        "warehouse=*": 6,
    },
    POIClass.PARK: {
        "leisure=park": 10,
        "leisure=garden": 8,
        "leisure=playground": 7,
        "landuse=recreation_ground": 7,
        "boundary=national_park": 9,
    },
    POIClass.INDUSTRIAL: {
        "landuse=industrial": 10,
        "building=industrial": 9,
        "industrial=*": 5,
        "man_made=works": 6,
    },
    POIClass.OFFICE: {
        "building=office": 10,
        "office=*": 7,
        "landuse=commercial": 5,
    },
}


def _tag_key(tag_key: str, tag_value: str) -> str:
    """Build the ``"key=value"`` lookup key used by :data:`_TAG_WEIGHTS`."""

    return f"{tag_key}={tag_value}"


def _score_for_class(class_: POIClass, tags: Mapping[str, str]) -> int:
    """Sum weights of all matching tag rules for ``class_``."""

    total = 0
    rules = _TAG_WEIGHTS.get(class_, {})
    for rule_key, weight in rules.items():
        # Wildcard rules (e.g. ``"residential=*"``) match any value.
        if rule_key.endswith("=*"):
            key = rule_key[:-2]
            if key in tags:
                total += weight
            continue
        key, value = rule_key.split("=", 1)
        if tags.get(key) == value:
            total += weight
    return total


class POIClassifier:
    """Score OSM tags against the 12-class taxonomy.

    Stateless and side-effect free. The only configuration knob is the
    *minimum* score; below that, classify raises :class:`ValueError`
    so callers can route low-confidence hits to the ``UNKNOWN`` enum
    (or to a quarantine file) rather than guessing.
    """

    #: Default threshold for :meth:`classify`. Below this, the call raises.
    DEFAULT_MIN_SCORE: int = 5

    def __init__(self, min_score: int | None = None) -> None:
        self.min_score = (
            self.DEFAULT_MIN_SCORE if min_score is None else int(min_score)
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def classify(self, tags: Mapping[str, str]) -> POIClass:
        """Return the highest-scoring :class:`POIClass` for ``tags``.

        Raises
        ------
        ValueError
            If no class scores at or above ``self.min_score``. The
            message lists the top candidate so callers can decide
            whether to log, surface, or fall back to ``UNKNOWN``.
        """
        scored = sorted(
            ((c, _score_for_class(c, tags)) for c in POIClass if c is not POIClass.UNKNOWN),
            key=lambda item: (-item[1], item[0].value),
        )
        best, best_score = scored[0]
        if best_score < self.min_score:
            raise ValueError(
                "POIClassifier.classify: no class reached "
                f"min_score={self.min_score}; best candidate was "
                f"{best.value!s} at score={best_score}"
            )
        return best

    def confidence(self, tags: Mapping[str, str]) -> float:
        """Return a confidence score in ``[0.0, 1.0]``.

        Uses the classifier's top score normalised by a fixed saturation
        point. A score at or above ``10`` (any single decisive tag rule
        hit) saturates at ``1.0``.
        """
        scored = (
            _score_for_class(c, tags)
            for c in POIClass
            if c is not POIClass.UNKNOWN
        )
        top = max(scored, default=0)
        # Saturate at 10 (any single decisive rule) so the scale is
        # well-behaved for downstream consumers.
        return min(1.0, top / 10.0)

    def classify_or_unknown(self, tags: Mapping[str, str]) -> POIClass:
        """Like :meth:`classify` but returns :attr:`POIClass.UNKNOWN` on miss."""
        try:
            return self.classify(tags)
        except ValueError:
            return POIClass.UNKNOWN


__all__ = ["POIClass", "POIClassifier"]
