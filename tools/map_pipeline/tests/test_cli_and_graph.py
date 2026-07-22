"""Tests for :mod:`tools.map_pipeline.cli` + :mod:`city_graph_builder`.

These bring the rest of the Stage 11 surface under pytest. Kept small
because the OSM gate is closed; real ingestion tests will land when the
gate re-opens (ADR-0006 §2).
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.map_pipeline import cli
from tools.map_pipeline.city_graph_builder import CityGraph, Intersection, Road
from tools.map_pipeline.geometry_processor import (
    Building,
    POI,
    Point,
    RoadSegment,
    normalize,
)
from tools.map_pipeline.osm_fetcher import fetch_bbox


# ---------------------------------------------------------------------------
# OSM fetcher
# ---------------------------------------------------------------------------


def test_fetch_bbox_raises_not_implemented() -> None:
    """``fetch_bbox`` must always raise ``NotImplementedError`` (ADR-0006 §2)."""

    with pytest.raises(NotImplementedError) as excinfo:
        fetch_bbox(min_lat=0.0, min_lon=0.0, max_lat=1.0, max_lon=1.0)
    assert "ADR-0006" in str(excinfo.value)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def test_cli_fetch_exits_with_code_1(capsys: pytest.CaptureFixture[str]) -> None:
    """The ``fetch`` subcommand must exit non-zero and log the reason."""

    rc = cli.main(["fetch"])
    assert rc == 1
    captured = capsys.readouterr()
    assert "NotImplemented" in captured.err
    assert "ADR-0006" in captured.err


def test_cli_validate_on_clean_preset(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """``validate`` on the Nanjing preset must succeed."""

    # Create a copy in tmp_path so we don't accidentally mutate the repo.
    repo_preset = (
        Path(__file__).resolve().parents[3]
        / "content"
        / "maps"
        / "presets"
        / "nanjing_demo.json"
    )
    target = tmp_path / "nanjing.json"
    target.write_text(repo_preset.read_text(encoding="utf-8"), encoding="utf-8")

    rc = cli.main(["validate", str(target)])
    assert rc == 0
    out = capsys.readouterr().out
    assert "OK" in out


def test_cli_preview_lists_pois(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """``preview`` must list the POIs from a manifest."""

    repo_preset = (
        Path(__file__).resolve().parents[3]
        / "content"
        / "maps"
        / "presets"
        / "nanjing_demo.json"
    )
    target = tmp_path / "nanjing.json"
    target.write_text(repo_preset.read_text(encoding="utf-8"), encoding="utf-8")

    rc = cli.main(["preview", str(target)])
    assert rc == 0
    out = capsys.readouterr().out
    assert "poi_pharmacy_01" in out
    assert "POIs" in out


def test_cli_validate_missing_file_exits_2(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """An unknown manifest path must exit with code 2."""

    missing = tmp_path / "does_not_exist.json"
    rc = cli.main(["validate", str(missing)])
    assert rc == 2


# ---------------------------------------------------------------------------
# Geometry processor
# ---------------------------------------------------------------------------


def test_normalize_consumes_iterable_and_returns_empty() -> None:
    """``normalize`` must consume its input and return an empty list."""

    payload = [{"type": "way", "id": 1, "tags": {"highway": "residential"}}]
    out = normalize(payload)
    assert out == []


def test_geometry_dataclasses_constructable() -> None:
    """Geometry dataclasses must build and round-trip via repr."""

    seg = RoadSegment(
        osm_id=1,
        points=[Point(lat=0.0, lon=0.0), Point(lat=0.0, lon=1.0)],
        highway_tag="residential",
        name="Foo St",
        oneway=False,
    )
    bldg = Building(
        osm_id=2,
        outline=[Point(lat=0.0, lon=0.0), Point(lat=0.0, lon=1.0), Point(lat=0.0, lon=0.0)],
        building_tag="yes",
    )
    poi = POI(osm_id=3, location=Point(lat=0.0, lon=0.0), tags={"amenity": "cafe"})
    assert seg.highway_tag == "residential"
    assert bldg.building_tag == "yes"
    assert poi.tags["amenity"] == "cafe"


# ---------------------------------------------------------------------------
# City graph
# ---------------------------------------------------------------------------


def test_city_graph_construction_and_pathfinding() -> None:
    """A 3-node graph must support shortest-path queries."""

    nodes = [
        Intersection(node_id=1, location=Point(lat=0.0, lon=0.0)),
        Intersection(node_id=2, location=Point(lat=0.0, lon=1.0)),
        Intersection(node_id=3, location=Point(lat=0.0, lon=2.0)),
    ]
    edges = [
        Road(edge_id=10, src=1, dst=2, cost=5.0),
        Road(edge_id=11, src=2, dst=3, cost=5.0),
        Road(edge_id=12, src=1, dst=3, cost=100.0),  # worse — must not be picked
    ]
    graph = CityGraph(nodes=nodes, edges=edges)
    path = graph.shortest_path(1, 3)
    # Cheapest path is 1 -> 2 -> 3 with cost 10.
    assert path == [1, 2, 3]


def test_city_graph_nearest_node_picks_closest() -> None:
    """``nearest_node`` must return the closest by squared distance."""

    nodes = [
        Intersection(node_id=1, location=Point(lat=0.0, lon=0.0)),
        Intersection(node_id=2, location=Point(lat=0.0, lon=1.0)),
        Intersection(node_id=3, location=Point(lat=1.0, lon=0.0)),
    ]
    graph = CityGraph(nodes=nodes, edges=[])
    # nearest_node(x, y): dx = lon - x, dy = lat - y. Lookups:
    #   (x=0.9, y=0.9) -> node 2 (sq-dist 0.82) closer than node 1/3 (1.62).
    assert graph.nearest_node(0.9, 0.9) == 2
    # Query near origin picks node 1.
    assert graph.nearest_node(0.1, 0.1) == 1
    # Query near (lon=0, lat=1) picks node 3.
    assert graph.nearest_node(0.0, 0.9) == 3


def test_city_graph_from_roads_is_deterministic() -> None:
    """``from_roads`` must yield the same graph twice for the same input."""

    seg = RoadSegment(
        osm_id=7,
        points=[Point(lat=0, lon=0), Point(lat=0, lon=1)],
        highway_tag="residential",
    )
    g1 = CityGraph.from_roads([seg])
    g2 = CityGraph.from_roads([seg])
    assert len(g1.nodes) == len(g2.nodes) == 2
    # Same node ids assigned in the same order => deterministic.
    assert [n.node_id for n in g1.nodes] == [n.node_id for n in g2.nodes]


def test_city_graph_shortest_path_no_path_returns_empty() -> None:
    """An unreachable destination must return an empty path."""

    nodes = [Intersection(node_id=1, location=Point(0, 0))]
    graph = CityGraph(nodes=nodes, edges=[])
    assert graph.shortest_path(1, 99) == []
