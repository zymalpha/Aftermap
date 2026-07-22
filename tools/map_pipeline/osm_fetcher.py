"""OSM (OpenStreetMap) fetcher for the Aftermap map pipeline.

This module is part of the ``tools/map_pipeline/`` Python tool boundary
defined by ADR-0006 / §11.15.

Per ADR-0006 §2, real OSM fetching is **explicitly deferred** beyond the
P3 gate. The MVP ships with hand-authored preset packs only; any call
into :func:`fetch_bbox` therefore raises
:class:`NotImplementedError` so that misconfigurations fail loudly
instead of silently hitting the network.

The intent is to keep the tool-call surface stable so the rest of the
pipeline (geometry, POI classification, city graph, scenario generation,
manifest, CLI) can be developed and tested today. When P3 re-opens the
gate, this file is the *only* place that needs to change — the rest of
``tools/map_pipeline`` already consumes :class:`bytes` payloads.
"""
from __future__ import annotations

from typing import Final

#: Reason returned by :func:`fetch_bbox` when invoked before the P3 gate.
#: Kept as a module constant so callers and tests can assert on it.
NOT_IMPLEMENTED_REASON: Final[str] = (
    "OSM fetch deferred to P3+；见 ADR-0006"
)


def fetch_bbox(
    min_lat: float,
    min_lon: float,
    max_lat: float,
    max_lon: float,
    *,
    timeout_s: float = 30.0,
) -> bytes:
    """Fetch an OSM snapshot for the given bounding box.

    Parameters
    ----------
    min_lat, min_lon, max_lat, max_lon:
        Geographic bounding box in WGS-84 degrees. ``min_lat`` is the
        southern edge, ``max_lat`` the northern edge, and similarly for
        ``min_lon`` / ``max_lon`` east/west.
    timeout_s:
        Network timeout (seconds). Accepted for API compatibility with
        future implementations; ignored today.

    Returns
    -------
    bytes
        A raw OSM snapshot payload (XML or protobuf) ready to be fed
        into :mod:`geometry_processor`.

    Raises
    ------
    NotImplementedError
        Always. Real OSM ingest is gated behind ADR-0006 §2 / Stage 5
        or later. Until then, callers must use a preset pack under
        ``content/maps/presets/``.
    """
    # NOTE: this function must perform ZERO network I/O. The contract is
    # a stable signature + a loud failure. Do not add ``requests``,
    # ``urllib``, or async fetches here.
    del min_lat, min_lon, max_lat, max_lon, timeout_s  # satisfy linters
    raise NotImplementedError(NOT_IMPLEMENTED_REASON)


__all__ = ["fetch_bbox", "NOT_IMPLEMENTED_REASON"]
