class_name Visibility extends RefCounted

## Symmetric field-of-view (FOV).
##
## Per design spec, FOV must be 100% symmetric: if A sees B then B sees A.
## We compute visibility by direct raycasting from `origin` to every in-bounds
## cell within `radius`, and mark a target cell visible iff no blocker cell
## lies strictly between origin and the target on the ray. That's O(R^2 * R)
## per origin, but cheap enough for the MVP grid sizes (≤96x96) and trivially
## symmetric (the ray blocker test is symmetric: blocking cell B is between
## A and target T if and only if the same applies for B's reverse ray).

const _PATH: String = "res://game/domain/tactical/visibility.gd"

# Compute visible cells (Array[Vector2i]) from `origin` with the given `radius`.
# Blockers are opaque cells (Vector2i list). Origin is always visible.
static func fov_from(grid: RefCounted, origin: Vector2i, radius: int, blockers: Array) -> Array:
	if grid == null:
		return []
	var w: int = grid.grid_w
	var h: int = grid.grid_h
	if origin.x < 0 or origin.y < 0 or origin.x >= w or origin.y >= h:
		return []
	if radius < 0:
		radius = 0

	# Build blocker mask.
	var block: PackedByteArray = PackedByteArray()
	block.resize(w * h)
	block.fill(0)
	for b in blockers:
		var bv: Vector2i = b
		if bv.x >= 0 and bv.y >= 0 and bv.x < w and bv.y < h:
			block[bv.y * w + bv.x] = 1

	var out: Array = []
	var r2: int = radius * radius
	for y in range(origin.y - radius, origin.y + radius + 1):
		if y < 0 or y >= h:
			continue
		for x in range(origin.x - radius, origin.x + radius + 1):
			if x < 0 or x >= w:
				continue
			var dx: int = x - origin.x
			var dy: int = y - origin.y
			if dx * dx + dy * dy > r2:
				continue
			if _ray_clear(block, w, h, origin, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out

# True iff no blocker cell lies strictly between `a` and `b` (inclusive of
# endpoints a but not b — blocker on `b` itself does NOT block line of sight
# because targets are often behind cover that they themselves occupy).
static func _ray_clear(block: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	var steps: int = abs(dx)
	if abs(dy) > steps:
		steps = abs(dy)
	if steps == 0:
		return true
	for s in range(1, steps + 1):
		var ix: int = a.x + dx * s / steps
		var iy: int = a.y + dy * s / steps
		if (ix == b.x and iy == b.y):
			return true
		if block[iy * w + ix] == 1:
			return false
	return true

# Test if a specific target cell is visible from origin.
static func can_see(grid: RefCounted, origin: Vector2i, target: Vector2i, blockers: Array) -> bool:
	if grid == null:
		return false
	if origin == target:
		return true
	var w: int = grid.grid_w
	var h: int = grid.grid_h
	if origin.x < 0 or origin.y < 0 or origin.x >= w or origin.y >= h:
		return false
	if target.x < 0 or target.y < 0 or target.x >= w or target.y >= h:
		return false
	var block: PackedByteArray = PackedByteArray()
	block.resize(w * h)
	block.fill(0)
	for b in blockers:
		var bv: Vector2i = b
		if bv.x >= 0 and bv.y >= 0 and bv.x < w and bv.y < h:
			block[bv.y * w + bv.x] = 1
	return _ray_clear(block, w, h, origin, target)

# Symmetry check: for every pair (origin, target), fov(origin) contains
# target iff fov(target) contains origin. Returns true when consistent.
static func is_symmetric(grid: RefCounted, origins: Array, radius: int, blockers: Array) -> bool:
	for o in origins:
		var ov: Vector2i = o
		var visible: Array = fov_from(grid, ov, radius, blockers)
		for v in visible:
			var vv: Vector2i = v
			var reverse_visible: Array = fov_from(grid, vv, radius, blockers)
			var found: bool = false
			for r in reverse_visible:
				if Vector2i(r) == ov:
					found = true
					break
			if not found:
				return false
	return true