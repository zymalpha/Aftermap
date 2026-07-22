class_name Grid extends RefCounted

## Tactical grid. Logical 1m squares; presentation uses 32x32 pixel tiles.
## All positions are Vector2i with (x, y). World <-> grid mapping is exact
## (multiples of PIXELS_PER_TILE).

const _PATH: String = "res://game/domain/tactical/grid.gd"

const PIXELS_PER_TILE: int = 32

var grid_w: int = 0
var grid_h: int = 0

func _init(w: int = 0, h: int = 0) -> void:
	grid_w = w
	grid_h = h

func size() -> Vector2i:
	return Vector2i(grid_w, grid_h)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < grid_w and p.y < grid_h

func world_to_grid(world: Vector2) -> Vector2i:
	var x: int = int(floor(world.x / float(PIXELS_PER_TILE)))
	var y: int = int(floor(world.y / float(PIXELS_PER_TILE)))
	return Vector2i(x, y)

func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x) * float(PIXELS_PER_TILE) + float(PIXELS_PER_TILE) * 0.5,
		float(cell.y) * float(PIXELS_PER_TILE) + float(PIXELS_PER_TILE) * 0.5,
	)

# Chebyshev distance (king-move) between two grid cells. Returns -1 if either
# cell is out of bounds.
static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	if dx < 0 or dy < 0:
		return -1
	return dx if dx > dy else dy

# Manhattan distance (4-direction). Returns -1 if either cell invalid.
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	if dx < 0 or dy < 0:
		return -1
	return dx + dy

# Static chebyshev helper usable without a Grid instance.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return chebyshev_distance(a, b)

func to_dict() -> Dictionary:
	return {"grid_w": grid_w, "grid_h": grid_h}

func from_dict(d: Dictionary) -> void:
	grid_w = int(d.get("grid_w", 0))
	grid_h = int(d.get("grid_h", 0))