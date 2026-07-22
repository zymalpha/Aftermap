"""Unit tests for :mod:`tools.map_pipeline.poi_classifier`.

Each of the 12 POI classes per §12.9.2 must round-trip through
:class:`POIClassifier.classify` with a representative set of OSM tags.
Unknown tags must either raise :class:`ValueError` or fall back to
:class:`POIClass.UNKNOWN` via :meth:`POIClassifier.classify_or_unknown`.
"""
from __future__ import annotations

import pytest

from tools.map_pipeline.poi_classifier import POIClass, POIClassifier


# ---------------------------------------------------------------------------
# Sample tag dicts covering all 12 classes
# ---------------------------------------------------------------------------

SAMPLES: dict[POIClass, dict[str, str]] = {
    POIClass.PHARMACY: {"amenity": "pharmacy", "dispensing": "yes"},
    POIClass.CLINIC: {"amenity": "clinic", "healthcare": "clinic"},
    POIClass.GROCERY: {"shop": "supermarket"},
    POIClass.DEPOT: {"amenity": "depot", "landuse": "depot"},
    POIClass.RESIDENCE: {"building": "apartments", "residential": "urban"},
    POIClass.POLICE: {"amenity": "police"},
    POIClass.SCHOOL: {"amenity": "school"},
    POIClass.GAS_STATION: {"amenity": "fuel"},
    POIClass.WAREHOUSE: {"building": "warehouse"},
    POIClass.PARK: {"leisure": "park"},
    POIClass.INDUSTRIAL: {"landuse": "industrial"},
    POIClass.OFFICE: {"building": "office"},
}


@pytest.fixture
def classifier() -> POIClassifier:
    """A fresh classifier with the default minimum score."""

    return POIClassifier()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("cls,tags", list(SAMPLES.items()))
def test_classifier_handles_each_of_the_12_classes(
    classifier: POIClassifier, cls: POIClass, tags: dict[str, str]
) -> None:
    """Each of the 12 POI classes must classify to itself."""

    assert classifier.classify(tags) is cls


def test_classifier_returns_high_confidence_for_decisive_tags(
    classifier: POIClassifier,
) -> None:
    """A single decisive rule should produce a near-1.0 confidence."""

    confidence = classifier.confidence({"amenity": "pharmacy"})
    assert confidence >= 0.9


def test_classifier_raises_on_empty_tags(classifier: POIClassifier) -> None:
    """Empty tags must raise :class:`ValueError`."""

    with pytest.raises(ValueError):
        classifier.classify({})


def test_classifier_or_unknown_returns_unknown_on_miss(
    classifier: POIClassifier,
) -> None:
    """Tags that hit no rule must resolve to :attr:`POIClass.UNKNOWN`."""

    assert classifier.classify_or_unknown({"random_tag": "nonsense"}) is POIClass.UNKNOWN


def test_classifier_or_unknown_returns_class_on_hit(
    classifier: POIClassifier,
) -> None:
    """The non-raising path must agree with the raising one."""

    tags = {"amenity": "fuel"}
    assert classifier.classify_or_unknown(tags) == classifier.classify(tags)


def test_classifier_confidence_is_zero_for_unmatched_tags(
    classifier: POIClassifier,
) -> None:
    """Tags scoring zero must produce zero confidence."""

    assert classifier.confidence({"x": "y"}) == 0.0
