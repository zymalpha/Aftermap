class_name Pathfinder extends RefCounted

## A* on a tactical grid with 8-direction movement.
## Costs: orthogonal = 1.0, diagonal = 1.5 (chebyshev-friendly).
## Heuristic: chebyshev (admissible & consistent for 8-dir with sqrt(2)~=1.5 cap).
##
## Performance: 30 pathfinds on a 48x48 grid must finish well under the 30fps
## frame budget (33ms). To make this achievable in GDScript, all per-cell
## open-set state (g_score, came_from, closed) lives in flat Packed*Arrays
## indexed by (y * w + x), and the open set is a tiny binary heap.
##
## Caps at grid_w * grid_h <= ~10 million cells (PackedArray resize ceiling
## in practice). Plenty for tactical scenes (max 96x96 = 9216 cells).

const _PATH: String = "res://game/domain/tactical/pathfinder.gd"

const COST_ORTHO: float = 1.0
const COST_DIAG: float = 1.5

const DIRS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                     Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1),
]

const INF: float = 1.0e30

# Static heap storage. Reused across calls.
static var _heap_keys: PackedInt32Array = PackedInt32Array()
static var _heap_f: PackedFloat32Array = PackedFloat32Array()
static var _heap_n: int = 0

static func _heap_reset() -> void:
	_heap_n = 0

static func _heap_push(k: int, f: float) -> void:
	# Resize if needed (geometric).
	if _heap_n >= _heap_keys.size():
		var cap: int = 1024 if _heap_keys.size() == 0 else _heap_keys.size() * 2
		_heap_keys.resize(cap)
		_heap_f.resize(cap)
	_heap_keys[_heap_n] = k
	_heap_f[_heap_n] = f
	var idx: int = _heap_n
	_heap_n += 1
	while idx > 0:
		var parent: int = (idx - 1) >> 1
		if _heap_f[idx] < _heap_f[parent]:
			var tk: int = _heap_keys[idx]
			var tf: float = _heap_f[idx]
			_heap_keys[idx] = _heap_keys[parent]
			_heap_f[idx] = _heap_f[parent]
			_heap_keys[parent] = tk
			_heap_f[parent] = tf
			idx = parent
		else:
			break

static func _heap_pop() -> int:
	if _heap_n == 0:
		return -1
	var top_k: int = _heap_keys[0]
	_heap_n -= 1
	if _heap_n > 0:
		var last_k: int = _heap_keys[_heap_n]
		var last_f: float = _heap_f[_heap_n]
		_heap_keys[0] = last_k
		_heap_f[0] = last_f
		var i: int = 0
		while true:
			var l: int = i * 2 + 1
			var r: int = l + 1
			var s: int = i
			if l < _heap_n and _heap_f[l] < _heap_f[s]:
				s = l
			if r < _heap_n and _heap_f[r] < _heap_f[s]:
				s = r
			if s == i:
				break
			var tk: int = _heap_keys[i]
			var tf: float = _heap_f[i]
			_heap_keys[i] = _heap_keys[s]
			_heap_f[i] = _heap_f[s]
			_heap_keys[s] = tk
			_heap_f[s] = tf
			i = s
	return top_k

# A static helper. grid: a Grid; start/goal: Vector2i cells; blocked: Array[Vector2i].
# Returns Array[Vector2i] path (start to goal inclusive) or [] if unreachable / invalid.
static func a_star(grid: RefCounted, start: Vector2i, goal: Vector2i, blocked: Array) -> Array:
	if grid == null:
		return []
	var w: int = grid.grid_w
	var h: int = grid.grid_h
	if start.x < 0 or start.y < 0 or start.x >= w or start.y >= h:
		return []
	if goal.x < 0 or goal.y < 0 or goal.x >= w or goal.y >= h:
		return []
	if start == goal:
		return [start]

	var cell_count: int = w * h
	# Block mask: 1 if cell blocked, 0 otherwise.
	var block_mask: PackedByteArray = PackedByteArray()
	block_mask.resize(cell_count)
	block_mask.fill(0)
	for b in blocked:
		var bv: Vector2i = b
		if bv.x >= 0 and bv.y >= 0 and bv.x < w and bv.y < h:
			block_mask[bv.y * w + bv.x] = 1

	var start_idx: int = start.y * w + start.x
	var goal_idx: int = goal.y * w + goal.x
	if block_mask[start_idx] == 1 or block_mask[goal_idx] == 1:
		return []

	# Per-cell state.
	var g_score: PackedFloat32Array = PackedFloat32Array()
	g_score.resize(cell_count)
	g_score.fill(INF)
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(cell_count)
	closed.fill(0)
	var prev_idx: PackedInt32Array = PackedInt32Array()
	prev_idx.resize(cell_count)
	prev_idx.fill(-1)

	g_score[start_idx] = 0.0
	_heap_reset()
	_heap_push(start_idx, _heuristic_idx(start.x, start.y, goal.x, goal.y))

	var max_iters: int = cell_count * 8 + 64
	var iters: int = 0

	while _heap_n > 0 and iters < max_iters:
		iters += 1
		var cur_idx: int = _heap_pop()
		if cur_idx == goal_idx:
			return _reconstruct(prev_idx, cur_idx, w, start)
		closed[cur_idx] = 1
		var cur_x: int = cur_idx % w
		var cur_y: int = cur_idx / w
		var cur_g: float = g_score[cur_idx]

		for d in DIRS:
			var nx: int = cur_x + d.x
			var ny: int = cur_y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nidx: int = ny * w + nx
			if block_mask[nidx] == 1 or closed[nidx] == 1:
				continue
			if d.x != 0 and d.y != 0:
				var ox_idx: int = cur_y * w + (cur_x + d.x)
				var oy_idx: int = (cur_y + d.y) * w + cur_x
				if block_mask[ox_idx] == 1 and block_mask[oy_idx] == 1:
					continue
			var step_cost: float = COST_DIAG if (d.x != 0 and d.y != 0) else COST_ORTHO
			var tentative_g: float = cur_g + step_cost
			if tentative_g < g_score[nidx]:
				g_score[nidx] = tentative_g
				prev_idx[nidx] = cur_idx
				var f: float = tentative_g + _heuristic_idx(nx, ny, goal.x, goal.y)
				_heap_push(nidx, f)

	return []  # unreachable

static func _heuristic_idx(px: int, py: int, gx: int, gy: int) -> float:
	var dx: int = abs(px - gx)
	var dy: int = abs(py - gy)
	var dmin: int = dx if dx < dy else dy
	var dmax: int = dx if dx > dy else dy
	return float(dmin) * COST_DIAG + float(dmax - dmin) * COST_ORTHO

static func _heuristic(p: Vector2i, goal: Vector2i) -> float:
	return _heuristic_idx(p.x, p.y, goal.x, goal.y)

static func _reconstruct(prev_idx: PackedInt32Array, end_idx: int, w: int, start: Vector2i) -> Array:
	var path: Array = []
	var cur_idx: int = end_idx
	var guard: int = 100000
	while guard > 0:
		guard -= 1
		var x: int = cur_idx % w
		var y: int = cur_idx / w
		path.push_front(Vector2i(x, y))
		var prev: int = prev_idx[cur_idx]
		if prev < 0:
			break
		cur_idx = prev
	return path