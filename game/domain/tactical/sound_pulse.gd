class_name SoundPulse extends RefCounted

## Sound pulse propagation. Models the intensity heard at each cell when an
## event happens at `origin` with `intensity` (0..100) and an effective radius.
##
## Material attenuation multipliers (per spec):
##   open       = 1.00
##   wall       = 0.20
##   door_open  = 0.60
##   door_closed= 0.00
##
## Each cell's "material" is queried via the supplied `material_of(cell)`
## callback, defaulting to OPEN. The pulse at distance d, with intervening
## materials m1..mk, is:
##
##   heard = intensity * product(material multipliers) - decay_per_cell * d
##
## Floor at 0. Returns a Dictionary {cell: heard_intensity} (only cells with
## heard > 0 are included).

const _PATH: String = "res://game/domain/tactical/sound_pulse.gd"

const MATERIAL_OPEN: int = 0
const MATERIAL_WALL: int = 1
const MATERIAL_DOOR_OPEN: int = 2
const MATERIAL_DOOR_CLOSED: int = 3

const ATTEN_OPEN: float = 1.0
const ATTEN_WALL: float = 0.2
const ATTEN_DOOR_OPEN: float = 0.6
const ATTEN_DOOR_CLOSED: float = 0.0

const DECAY_PER_CELL: float = 0.5

# Compute heard-intensity at every cell reachable from origin within radius,
# using the supplied material map (Dictionary key "x,y" → int) or default OPEN.
#
# `material_map` may be null or empty; in that case every cell is OPEN.
static func pulse(origin: Vector2i, radius: int, intensity: float, grid: RefCounted, material_map: Dictionary) -> Dictionary:
	if grid == null:
		return {}
	if intensity <= 0.0:
		return {}
	if radius <= 0:
		var idx: String = _key(origin)
		if intensity > 0.0:
			return {idx: intensity}
		return {}
	var w: int = grid.grid_w
	var h: int = grid.grid_h
	if origin.x < 0 or origin.y < 0 or origin.x >= w or origin.y >= h:
		return {}

	var result: Dictionary = {}
	var r: int = radius
	for y in range(origin.y - r, origin.y + r + 1):
		if y < 0 or y >= h:
			continue
		for x in range(origin.x - r, origin.x + r + 1):
			if x < 0 or x >= w:
				continue
			var cell: Vector2i = Vector2i(x, y)
			var heard: float = _heard_at(origin, cell, intensity, material_map)
			if heard > 0.0:
				result[_key(cell)] = heard
	return result

# Static helper that returns heard intensity at `cell` from a pulse at `origin`.
# Exposed publicly for per-cell queries and tests.
static func heard_at(origin: Vector2i, cell: Vector2i, intensity: float, material_map: Dictionary) -> float:
	return _heard_at(origin, cell, intensity, material_map)

static func _heard_at(origin: Vector2i, cell: Vector2i, intensity: float, material_map: Dictionary) -> float:
	if origin == cell:
		return intensity
	var dx: int = abs(cell.x - origin.x)
	var dy: int = abs(cell.y - origin.y)
	# Distance in chebyshev.
	var dist: int = dx if dx > dy else dy
	var steps: int = dist
	if steps == 0:
		return intensity
	var product: float = 1.0
	for s in range(1, steps + 1):
		var t: float = float(s) / float(steps)
		var ix: int = origin.x + int(round(float(cell.x - origin.x) * t))
		var iy: int = origin.y + int(round(float(cell.y - origin.y) * t))
		var m: int = _material_at(Vector2i(ix, iy), material_map)
		product *= _atten(m)
		if product <= 0.0001:
			return 0.0
	var heard: float = intensity * product - DECAY_PER_CELL * float(dist)
	if heard < 0.0:
		heard = 0.0
	return heard

static func _material_at(cell: Vector2i, m: Dictionary) -> int:
	if m == null:
		return MATERIAL_OPEN
	var v: Variant = m.get(_key(cell), MATERIAL_OPEN)
	return int(v)

static func _atten(m: int) -> float:
	match m:
		MATERIAL_WALL: return ATTEN_WALL
		MATERIAL_DOOR_OPEN: return ATTEN_DOOR_OPEN
		MATERIAL_DOOR_CLOSED: return ATTEN_DOOR_CLOSED
		_: return ATTEN_OPEN

static func _key(c: Vector2i) -> String:
	return String.num(c.x, 0) + "," + String.num(c.y, 0)