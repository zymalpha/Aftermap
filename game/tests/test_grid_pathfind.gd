extends SceneTree

## Stage 4 + Stage 5 spike: grid + A* + 30-unit perf budget (30fps < 33ms).
##
## Also covers chebyshev_distance correctness, world<->grid mapping, and
## 8-direction pathfinding on a 24x24 grid.

const GridScript: GDScript = preload("res://game/domain/tactical/grid.gd")
const PathfinderScript: GDScript = preload("res://game/domain/tactical/pathfinder.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_grid_pathfind start ===")
	_test_chebyshev_distance()
	_test_world_to_grid_and_back()
	_test_grid_constants()
	_test_pathfinder_open_grid()
	_test_pathfinder_blocked_path()
	_test_pathfinder_unreachable()
	_test_pathfinder_diagonal_shortcut()
	_test_perf_30_units_under_33ms()
	print("=== test_grid_pathfind result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  " + label)
	else:
		_fail_count += 1
		printerr("  FAIL  " + label)

func _test_chebyshev_distance() -> void:
	print("[1] chebyshev_distance")
	_expect(GridScript.chebyshev_distance(Vector2i(0, 0), Vector2i(3, 4)) == 4,
		"chebyshev (0,0)->(3,4) = 4")
	_expect(GridScript.chebyshev_distance(Vector2i(2, 2), Vector2i(2, 2)) == 0,
		"chebyshev same cell = 0")
	_expect(GridScript.chebyshev_distance(Vector2i(0, 0), Vector2i(7, 2)) == 7,
		"chebyshev horizontal = dx")
	_expect(GridScript.chebyshev_distance(Vector2i(5, 5), Vector2i(0, 0)) == 5,
		"chebyshev symmetric")

func _test_world_to_grid_and_back() -> void:
	print("[2] world <-> grid mapping")
	var g: RefCounted = GridScript.new(64, 64)
	_expect(g.world_to_grid(Vector2(0, 0)) == Vector2i(0, 0), "world(0,0) -> grid(0,0)")
	_expect(g.world_to_grid(Vector2(31, 31)) == Vector2i(0, 0), "world(31,31) still grid(0,0)")
	_expect(g.world_to_grid(Vector2(32, 32)) == Vector2i(1, 1), "world(32,32) -> grid(1,1)")
	_expect(g.world_to_grid(Vector2(96, 64)) == Vector2i(3, 2), "world(96,64) -> grid(3,2)")
	var cell: Vector2i = Vector2i(3, 2)
	var world: Vector2 = g.grid_to_world(cell)
	# World position is cell-center, so it lies within [cell*32, cell*32+32).
	_expect(world.x >= 96.0 and world.x < 128.0, "grid_to_world x in tile band")
	_expect(world.y >= 64.0 and world.y < 96.0, "grid_to_world y in tile band")
	_expect(g.in_bounds(Vector2i(0, 0)) and g.in_bounds(Vector2i(63, 63)),
		"in_bounds corners")
	_expect(not g.in_bounds(Vector2i(64, 0)) and not g.in_bounds(Vector2i(-1, 0)),
		"in_bounds rejects out-of-range")

func _test_grid_constants() -> void:
	print("[3] grid constants")
	_expect(GridScript.PIXELS_PER_TILE == 32, "PIXELS_PER_TILE=32")

func _test_pathfinder_open_grid() -> void:
	print("[4] A* on open 24x24 grid")
	var g: RefCounted = GridScript.new(24, 24)
	var path: Array = PathfinderScript.call("a_star", g, Vector2i(2, 2), Vector2i(20, 20), [])
	_expect(path.size() > 0, "found a path on open grid")
	_expect(Vector2i(path[0]) == Vector2i(2, 2), "path starts at start")
	_expect(Vector2i(path[path.size() - 1]) == Vector2i(20, 20), "path ends at goal")
	# 8-dir chebyshev cost from (2,2) to (20,20) is 18; with diagonal=1.5,
	# ortho=1, the optimal cost is 18 * 1.5 = 27.
	_expect(_path_cost(path) == 27.0, "optimal cost = 27.0 (18 diags)")

func _test_pathfinder_blocked_path() -> void:
	print("[5] A* around a wall")
	var g: RefCounted = GridScript.new(10, 10)
	# Vertical wall at x=5, y in [0..8], with a gap at y=9 (forced detour).
	var blocked: Array = []
	for y in range(9):
		blocked.append(Vector2i(5, y))
	var path: Array = PathfinderScript.call("a_star", g, Vector2i(0, 0), Vector2i(9, 9), blocked)
	_expect(path.size() > 0, "found detour around wall")
	# Verify path does not step on a blocked cell.
	for p in path:
		var pv: Vector2i = p
		for b in blocked:
			if pv == Vector2i(b):
				_expect(false, "path crossed a blocked cell")
				return
	_expect(true, "path avoids blocked cells")

func _test_pathfinder_unreachable() -> void:
	print("[6] A* unreachable")
	var g: RefCounted = GridScript.new(6, 6)
	# Wall fully enclosing (5,5) except the corner, but (5,5) is itself blocked.
	var blocked: Array = []
	for x in range(6):
		blocked.append(Vector2i(x, 5))
	blocked.append(Vector2i(5, 4))
	var path: Array = PathfinderScript.call("a_star", g, Vector2i(0, 0), Vector2i(5, 5), blocked)
	_expect(path.size() == 0, "unreachable returns []")

func _test_pathfinder_diagonal_shortcut() -> void:
	print("[7] diagonal shortcut cost")
	var g: RefCounted = GridScript.new(10, 10)
	var path: Array = PathfinderScript.call("a_star", g, Vector2i(0, 0), Vector2i(5, 5), [])
	# Each diagonal costs 1.5; 5 diagonals = 7.5.
	_expect(_path_cost(path) == 7.5, "5-diagonal path cost 7.5")

func _test_perf_30_units_under_33ms() -> void:
	print("[8] perf: 30 units, 30fps budget (33ms)")
	# Use a 32x32 grid (well within MVP scene size) — typical tactical combat
	# room — with sparse blockers. 30 pathfinds must finish under 33ms.
	var g: RefCounted = GridScript.new(32, 32)
	var start: Vector2i = Vector2i(2, 2)
	var blocked: Array = []
	# A handful of wall segments to keep paths interesting but short.
	for x in range(0, 32, 8):
		blocked.append(Vector2i(x, 16))
	blocked.append(Vector2i(15, 8))
	blocked.append(Vector2i(15, 9))
	# Warmup pass — first call pays JIT-like / allocation costs.
	PathfinderScript.call("a_star", g, start, Vector2i(28, 28), blocked)
	# Pre-compute goal positions to keep the timed loop tight.
	var goals: Array = []
	for i in range(30):
		var gx: int = 2 + (i * 5 + 3) % 28
		var gy: int = 2 + (i * 7 + 5) % 28
		goals.append(Vector2i(gx, gy))
	var t0: int = Time.get_ticks_usec()
	var ok_count: int = 0
	for i in range(30):
		var goal: Vector2i = goals[i]
		var p: Array = PathfinderScript.call("a_star", g, start, goal, blocked)
		if p.size() > 0:
			ok_count += 1
	var t1: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(t1 - t0) / 1000.0
	print("    elapsed_ms=%.3f  ok_paths=%d/30" % [elapsed_ms, ok_count])
	_expect(ok_count == 30, "30/30 paths found")
	_expect(elapsed_ms < 33.0, "elapsed_ms < 33ms (got %.3f)" % elapsed_ms)

func _path_cost(path: Array) -> float:
	var c: float = 0.0
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		var dx: int = abs(b.x - a.x)
		var dy: int = abs(b.y - a.y)
		if dx != 0 and dy != 0:
			c += PathfinderScript.COST_DIAG
		else:
			c += PathfinderScript.COST_ORTHO
	return c