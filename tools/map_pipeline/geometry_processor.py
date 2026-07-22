"""Geometry element definitions + normalisation stub.

Maps the raw OSM element stream (``nodes``, ``ways``, ``relations``)
into the three geometry families the rest of the pipeline cares about:

* :class:`RoadSegment` — a drivable / walkable way tagged ``highway=*``.
* :class:`Building` — a closed way or multipolygon tagged ``building=*``.
* :class:`POI` — a node or way tagged with an amenity / shop / etc.

Per ADR-0006 §2, OSM ingest is deferred beyond P3, so this module
ships a stable **shape** — typed dataclasses with sensible defaults —
plus a :func:`normalize` stub that returns an empty list. The contract
is the typed dataclasses; the actual OSM normalisation will be filled
in when the gate re-opens. All calls into this module from P1/P2
content pipelines must therefore work against an empty input without
crashing.

Coordinates are stored as floats in WGS-84 degrees. Privacy / rounding
happens at the manifest layer (:mod:`manifest_generator`), not here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, List, Union


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Point:
    """A 2-D WGS-84 point in degrees."""

    lat: float
    lon: float


@dataclass(frozen=True)
class RoadSegment:
    """A linear sequence of :class:`Point` representing a single way."""

    osm_id: int
    points: List[Point]
    highway_tag: str = "unknown"
    name: str | None = None
    oneway: bool = False


@dataclass(frozen=True)
class Building:
    """A closed polygon outline (first point == last point in OSM convention)."""

    osm_id: int
    outline: List[Point]
    building_tag: str = "yes"
    name: str | None = None
    levels: int | None = None


@dataclass(frozen=True)
class POI:
    """An OSM point-of-interest, distinct from the geometry it sits on."""

    osm_id: int
    location: Point
    tags: dict = field(default_factory=dict)


# Convenience union used in public signatures.
GeometryElement = Union[RoadSegment, Building, POI]


# ---------------------------------------------------------------------------
# Public API (stub)
# ---------------------------------------------------------------------------


def normalize(elements: Iterable[dict]) -> List[GeometryElement]:
    """Normalise raw OSM elements into typed geometry dataclasses.

    Parameters
    ----------
    elements:
        An iterable of raw OSM element dicts (``{"type": ..., "id": ...,
        ...}``). May be empty.

    Returns
    -------
    list
        A list of :class:`RoadSegment`, :class:`Building`, or :class:`POI`.

    Notes
    -----
    Per ADR-0006 §2 the real implementation is deferred. Today the
    function is a deterministic placeholder: it consumes the iterable
    (so any upstream I/O is finalised) and returns ``[]``. Callers must
    therefore tolerate empty results without crashing.
    """
    # Drain the iterable for side-effect completeness (e.g. closing
    # upstream file handles) without retaining the elements.
    for _ in elements:
        pass
    return []


__all__ = [
    "Point",
    "RoadSegment",
    "Building",
    "POI",
    "GeometryElement",
    "normalize",
]
