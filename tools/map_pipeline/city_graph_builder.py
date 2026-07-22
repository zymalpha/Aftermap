"""Road-graph representation + simple pathfinding.

The :class:`CityGraph` mirrors §11.17 / ADR-0006: it is the artefact the
game client reads at run-time. Today's graph is built from preset
manifests; tomorrow it will be derived from :mod:`geometry_processor`
output once the OSM gate re-opens.

The graph is intentionally small and inspectable so unit tests can
hand-build instances without going through the OSM pipeline. Edges are
labelled with a positive cost in arbitrary units (seconds of travel at
1 m/s by default). :meth:`nearest_node` and :meth:`shortest_path` are
deterministic (no random tie-breaks), which is required by ADR-0003
(reproducibility).
"""
from __future__ import annotations

import heapq
import math
from dataclasses import dataclass, field
from typing import Iterable, List

from .geometry_processor import Point, RoadSegment


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Intersection:
    """A graph node; an intersection or POI connector on a road segment."""

    node_id: int
    location: Point


@dataclass(frozen=True)
class Road:
    """A directed weighted edge between two intersections."""

    edge_id: int
    src: int       # node_id
    dst: int       # node_id
    cost: float    # seconds of travel
    name: str | None = None


@dataclass
class CityGraph:
    """A weighted directed graph of intersections and roads."""

    nodes: List[Intersection] = field(default_factory=list)
    edges: List[Road] = field(default_factory=list)
    # Adjacency: src node_id -> list of (dst, cost, edge_id)
    _adj: dict[int, list[tuple[int, float, int]]] = field(
        default_factory=dict, init=False, repr=False
    )

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------

    def __post_init__(self) -> None:
        # Initialise adjacency lazily as nodes/edges are appended.
        self._adj = {}
        for n in self.nodes:
            self._adj.setdefault(n.node_id, [])
        for e in self.edges:
            self._adj.setdefault(e.src, []).append((e.dst, e.cost, e.edge_id))
            # If the edge isn't explicitly reversed, also link back so
            # callers can treat the graph as undirected when needed.
            self._adj.setdefault(e.dst, []).append((e.src, e.cost, e.edge_id))

    @classmethod
    def from_roads(
        cls,
        roads: Iterable[RoadSegment],
        *,
        default_cost: float = 60.0,
    ) -> "CityGraph":
        """Construct a :class:`CityGraph` from raw road segments.

        For Stage 11 the construction is intentionally literal: every
        segment becomes one edge keyed by the segment ``osm_id``. Real
        snapping / splitting of overlapping segments lands with the
        OSM gate in P3 (ADR-0006 §2).
        """
        nodes: list[Intersection] = []
        edges: list[Road] = []
        node_counter = 0
        edge_counter = 0
        seen_node_ids: dict[int, int] = {}

        def _intern_node(candidate_id: int, location: Point) -> int:
            nonlocal node_counter
            mapped = seen_node_ids.get(candidate_id)
            if mapped is not None:
                return mapped
            node_counter += 1
            nodes.append(Intersection(node_id=node_counter, location=location))
            seen_node_ids[candidate_id] = node_counter
            return node_counter

        for seg in roads:
            if not seg.points:
                continue
            first_pt = seg.points[0]
            last_pt = seg.points[-1]
            src = _intern_node(seg.osm_id * 2, first_pt)
            dst = _intern_node(seg.osm_id * 2 + 1, last_pt)
            cost = default_cost * max(1, len(seg.points) - 1)
            edges.append(
                Road(
                    edge_id=edge_counter,
                    src=src,
                    dst=dst,
                    cost=float(cost),
                    name=seg.name,
                )
            )
            edge_counter += 1

        graph = cls(nodes=nodes, edges=edges)
        return graph

    # Stage-11 alias so callers can spell the method the way the
    # requirements document does. Identical to ``from_roads`` — the
    # real ``from_osm`` will be wired up when the OSM gate re-opens.
    @classmethod
    def from_osm(
        cls,
        elements: Iterable[dict],
        *,
        default_cost: float = 60.0,
    ) -> "CityGraph":
        """Placeholder for real OSM -> CityGraph conversion.

        Per ADR-0006 §2 the OSM gate is closed, so this drains its
        iterable and returns an empty graph.
        """
        for _ in elements:
            pass
        return cls()

    # ------------------------------------------------------------------
    # Queries
    # ------------------------------------------------------------------

    def nearest_node(self, x: float, y: float) -> int:
        """Return the node id nearest to the given ``(x, y)`` degrees."""
        if not self.nodes:
            raise IndexError("CityGraph.nearest_node: graph is empty")
        best_id = self.nodes[0].node_id
        best_dist = math.inf
        for n in self.nodes:
            dx = n.location.lon - x
            dy = n.location.lat - y
            d2 = dx * dx + dy * dy
            if d2 < best_dist:
                best_dist = d2
                best_id = n.node_id
        return best_id

    def shortest_path(self, src: int, dst: int) -> List[int]:
        """Dijkstra shortest path from ``src`` to ``dst`` by edge cost.

        Returns a list of node ids, including ``src`` and ``dst``. If
        no path exists an empty list is returned. Behaviour is fully
        deterministic: ties on the heap are broken by ``node_id`` in
        ascending order so two runs with identical input produce
        identical output (ADR-0003 §3).
        """
        if src not in self._adj or dst not in self._adj:
            return []
        # Tie-break (node_id, edge_id) ensures deterministic ordering.
        heap: list[tuple[float, int, int, list[int]]] = [(0.0, 0, src, [src])]
        visited: set[int] = set()
        while heap:
            cost, _, current, path = heapq.heappop(heap)
            if current in visited:
                continue
            visited.add(current)
            if current == dst:
                return path
            for neighbour, edge_cost, edge_id in self._adj.get(current, []):
                if neighbour in visited:
                    continue
                heapq.heappush(
                    heap,
                    (
                        cost + edge_cost,
                        edge_id,
                        neighbour,
                        path + [neighbour],
                    ),
                )
        return []


__all__ = ["Intersection", "Road", "CityGraph"]
