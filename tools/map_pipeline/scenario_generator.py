"""Deterministic scenario generator.

Produces a ``POISceneTemplate`` — a JSON-serialisable dict with
``grid``, ``containers``, ``enemies``, and ``loot`` — for a given
:class:`~city_graph_builder.CityGraph`, party size, and RNG seed.

ADR-0003 mandates that the random stream be:

* **named** — every draw names what it is for, so saves can re-seed;
* **deterministic** — ``generate(..., seed=42)`` produces the same
  output every time;
* **independent** — the seed does not share entropy with content
  authors' personal secrets.

We use :class:`random.Random` explicitly seeded so the rest of the
project can swap in a stream cipher later (§11.20) without touching
call sites.
"""
from __future__ import annotations

import hashlib
import json
import random
from dataclasses import dataclass, field
from typing import Any

from .city_graph_builder import CityGraph


@dataclass
class POISceneTemplate:
    """A fully self-contained scenario template.

    The dict shape matches what the manifest layer and the Godot
    loader expect; see ADR-0004 for the canonicalised JSON form.
    """

    scenario_id: str
    seed: int
    party_size: int
    grid: list[list[str]] = field(default_factory=list)
    containers: list[dict] = field(default_factory=list)
    enemies: list[dict] = field(default_factory=list)
    loot: list[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        """Return the scenario as a plain dict (JSON-serialisable)."""
        return {
            "scenario_id": self.scenario_id,
            "seed": self.seed,
            "party_size": self.party_size,
            "grid": self.grid,
            "containers": list(self.containers),
            "enemies": list(self.enemies),
            "loot": list(self.loot),
        }

    def hash(self) -> str:
        """SHA-256 hex digest over the canonicalised JSON form.

        Used by tests to compare two scenarios deterministically
        without enumerating their fields.
        """
        payload = json.dumps(self.to_dict(), sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# ScenarioGenerator
# ---------------------------------------------------------------------------


# Cheap-yet-loud tile alphabet so tests can visually inspect the grid.
_GRID_FLOOR_TILES = (".", ",", "~")     # dirt, dust, puddle
_GRID_WALL_TILES = ("#",)               # wall


class ScenarioGenerator:
    """Generate a :class:`POISceneTemplate` deterministically.

    Parameters
    ----------
    scenario_id_prefix:
        Used to compose the ``scenario_id`` so two generators in the
        same run do not collide on the hash.
    """

    DEFAULT_GRID_W: int = 12
    DEFAULT_GRID_H: int = 12

    def __init__(self, scenario_id_prefix: str = "scenario") -> None:
        self._scenario_id_prefix = scenario_id_prefix

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def generate(
        self,
        city_graph: CityGraph,
        party_size: int,
        rng_seed: int,
    ) -> POISceneTemplate:
        """Build a :class:`POISceneTemplate` for ``party_size`` characters.

        The city graph is consumed only for parameter consistency with
        downstream callers; today's generator produces a self-contained
        POI scene and does not depend on graph properties.
        """
        if party_size < 1:
            raise ValueError("ScenarioGenerator: party_size must be >= 1")

        rng = random.Random(int(rng_seed))

        # ---- Grid ----------------------------------------------------
        grid = self._build_grid(rng)

        # ---- Containers ---------------------------------------------
        container_count = self._draw_container_count(rng, party_size)
        containers = self._build_containers(rng, container_count)

        # ---- Enemies ------------------------------------------------
        enemy_count = self._draw_enemy_count(rng, party_size)
        enemies = self._build_enemies(rng, enemy_count)

        # ---- Loot ---------------------------------------------------
        loot = self._build_loot(rng, container_count)

        scenario_id = f"{self._scenario_id_prefix}_{int(rng_seed):08x}_p{party_size}"
        return POISceneTemplate(
            scenario_id=scenario_id,
            seed=int(rng_seed),
            party_size=int(party_size),
            grid=grid,
            containers=containers,
            enemies=enemies,
            loot=loot,
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _build_grid(self, rng: random.Random) -> list[list[str]]:
        h, w = self.DEFAULT_GRID_H, self.DEFAULT_GRID_W
        grid: list[list[str]] = []
        for y in range(h):
            row: list[str] = []
            for x in range(w):
                # Border walls; interior 70% floor / 30% wall by random.
                if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                    row.append(_GRID_WALL_TILES[0])
                else:
                    roll = rng.random()
                    row.append(
                        _GRID_FLOOR_TILES[rng.randrange(len(_GRID_FLOOR_TILES))]
                        if roll < 0.7
                        else _GRID_WALL_TILES[0]
                    )
            grid.append(row)
        return grid

    def _draw_container_count(self, rng: random.Random, party_size: int) -> int:
        base = rng.randint(3, 6)
        return base + max(0, party_size - 4)

    def _draw_enemy_count(self, rng: random.Random, party_size: int) -> int:
        base = rng.randint(2, 5)
        return max(1, base - max(0, party_size - 4))

    def _build_containers(
        self, rng: random.Random, count: int
    ) -> list[dict]:
        containers: list[dict] = []
        for i in range(count):
            containers.append(
                {
                    "container_id": f"c_{i:02d}",
                    "x": rng.randrange(1, self.DEFAULT_GRID_W - 1),
                    "y": rng.randrange(1, self.DEFAULT_GRID_H - 1),
                    "locked": rng.random() < 0.2,
                    "loot_table": f"lt_{rng.choice(['basic', 'medical', 'food'])}",
                }
            )
        return containers

    def _build_enemies(
        self, rng: random.Random, count: int
    ) -> list[dict]:
        enemies: list[dict] = []
        for i in range(count):
            enemies.append(
                {
                    "enemy_id": f"e_{i:02d}",
                    "kind": rng.choice(("walker", "runner", "bloater")),
                    "x": rng.randrange(1, self.DEFAULT_GRID_W - 1),
                    "y": rng.randrange(1, self.DEFAULT_GRID_H - 1),
                    "hp": rng.randint(20, 60),
                }
            )
        return enemies

    def _build_loot(
        self, rng: random.Random, container_count: int
    ) -> list[dict]:
        # One possible drop per container, weighted by a tier roll.
        drops: list[dict] = []
        for _ in range(container_count):
            roll = rng.random()
            if roll < 0.05:
                tier = "rare"
            elif roll < 0.35:
                tier = "uncommon"
            else:
                tier = "common"
            drops.append(
                {
                    "tier": tier,
                    "quantity": rng.randint(1, 3),
                    "kind": rng.choice(("ammo", "medicine", "food", "material")),
                }
            )
        return drops


__all__ = ["POISceneTemplate", "ScenarioGenerator"]
