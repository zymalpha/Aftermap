"""Unit tests for :mod:`tools.map_pipeline.scenario_generator`.

Two contracts must hold:

1. :meth:`ScenarioGenerator.generate` with the same seed must return a
   :class:`POISceneTemplate` whose ``hash()`` is identical across calls.
2. A scenario must serialise via :meth:`POISceneTemplate.to_dict` and
   the manifest layer must round-trip it deterministically (ADR-0003
   §3 — no random tie-breaks).
"""
from __future__ import annotations

import pytest

from tools.map_pipeline.city_graph_builder import CityGraph
from tools.map_pipeline.scenario_generator import POISceneTemplate, ScenarioGenerator


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def empty_graph() -> CityGraph:
    return CityGraph()


@pytest.fixture
def generator() -> ScenarioGenerator:
    return ScenarioGenerator()


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------


def test_generate_with_same_seed_is_deterministic(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """Two calls with the same seed must produce identical hashes."""

    a = generator.generate(empty_graph, party_size=4, rng_seed=42)
    b = generator.generate(empty_graph, party_size=4, rng_seed=42)
    assert a.hash() == b.hash()


def test_generate_with_different_seeds_diverges(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """Different seeds must produce different hashes (with overwhelming probability)."""

    a = generator.generate(empty_graph, party_size=4, rng_seed=1)
    b = generator.generate(empty_graph, party_size=4, rng_seed=2)
    assert a.hash() != b.hash()


def test_generate_party_size_enforced(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """``party_size`` must be a positive integer."""

    with pytest.raises(ValueError):
        generator.generate(empty_graph, party_size=0, rng_seed=42)


def test_party_size_affects_enemy_and_container_counts(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """A bigger party should generally produce a different shape."""

    small = generator.generate(empty_graph, party_size=1, rng_seed=42)
    big = generator.generate(empty_graph, party_size=6, rng_seed=42)
    # Different party sizes should change the scenario fingerprint.
    assert small.hash() != big.hash()


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------


def test_scenario_template_has_required_collections(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """A generated template must expose all four collections."""

    scene = generator.generate(empty_graph, party_size=4, rng_seed=42)
    assert isinstance(scene, POISceneTemplate)
    assert scene.grid and isinstance(scene.grid[0], list)
    assert scene.containers
    assert scene.enemies
    # ``loot`` is derived from containers; should always be present.
    assert scene.loot


def test_scenario_template_to_dict_round_trip(
    generator: ScenarioGenerator, empty_graph: CityGraph
) -> None:
    """``to_dict()`` must produce a JSON-serialisable dict."""

    import json

    scene = generator.generate(empty_graph, party_size=4, rng_seed=42)
    payload = scene.to_dict()
    # Must serialise without raising — proves no unsupported types.
    encoded = json.dumps(payload, ensure_ascii=False)
    decoded = json.loads(encoded)
    assert decoded["seed"] == 42
    assert decoded["party_size"] == 4
    assert decoded["scenario_id"].endswith("_p4")
