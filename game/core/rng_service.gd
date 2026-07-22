class_name RngService extends RefCounted

## Per ADR-0003: 8 named streams, XorShift64 state, deterministic per seed.
## Stream names are stable strings used both at runtime and in save files.

const _PATH: String = "res://game/core/rng_service.gd"

const STREAM_WORLD: StringName = &"world_generation"
const STREAM_CITY: StringName = &"city_state"
const STREAM_POI_PREFIX: StringName = &"poi_scene_"
const STREAM_DIRECTOR_PREFIX: StringName = &"daily_director_"
const STREAM_EVENT_PREFIX: StringName = &"event_"
const STREAM_COMBAT_PREFIX: StringName = &"combat_"
const STREAM_CHARACTER: StringName = &"character_generation"
const STREAM_COSMETIC: StringName = &"cosmetic_only"

const _NAMED_STREAMS: Array = [
	STREAM_WORLD,
	STREAM_CITY,
	STREAM_CHARACTER,
	STREAM_COSMETIC,
]

# 64-bit signed int max (positive half)
const INT63_MAX: int = 0x7FFFFFFFFFFFFFFF

var _state: Dictionary = {}

func _init() -> void:
	_state = {}

func _log(msg: String) -> void:
	push_warning("[RngService] " + msg)

# Seed all 4 static named streams. POI/director/event/combat streams are
# derived lazily from world_generation via ensure_stream().
func seed(seed_value: int) -> void:
	var s0: int = _mix_seed(seed_value)
	_state = {}
	for stream_name in _NAMED_STREAMS:
		_state[stream_name] = _derive_pair(s0, String(stream_name))

# Derive a state pair for a prefixed stream name. Stable across sessions.
func ensure_stream(stream: StringName) -> void:
	if _state.has(stream):
		return
	var seed_pair: Variant = _state.get(STREAM_WORLD, [0, 0])
	var s0: int = int(seed_pair[0])
	_state[stream] = _derive_pair(s0, String(stream))

# XorShift64 step on the named stream. Returns int in [0, INT63_MAX].
# Avoid using 0xFFFFFFFFFFFFFFFF literals; rely on GDScript int64 wrap and
# only mask out the sign bit at the end.
func get_rng(stream: StringName) -> int:
	if not _state.has(stream):
		ensure_stream(stream)
	var pair: Array = _state[stream]
	var x: int = int(pair[0])
	var s1: int = int(pair[1])
	# XorShift64 algorithm (Marsaglia). Rely on int64 wrap for the shifts.
	x = x ^ (x << 13)
	x = x ^ (x >> 7)
	x = x ^ (x << 17)
	x = x & INT63_MAX
	# splitmix-like s1 increment (golden ratio constant as decimal literal).
	# Stored as two int-32 halves added together to bypass Godot's hex literal
	# overflow warning while staying within signed-int64 range.
	var inc_hi: int = 2654435761   # 0x9E3779B9
	var inc_lo: int = 2086026445   # 0x7F4A7C15
	s1 = s1 + (inc_hi * 4294967296) + inc_lo
	if s1 == 0:
		s1 = 1
	pair[0] = x
	pair[1] = s1
	_state[stream] = pair
	return x

# Float in [lo, hi) using stream's next int.
func get_float(stream: StringName, lo: float, hi: float) -> float:
	if hi <= lo:
		return lo
	var v: int = get_rng(stream)
	var u: float = float(v) / float(INT63_MAX)
	return lo + (hi - lo) * u

# Uniformly pick from a non-empty Array. Returns null on empty.
func pick(stream: StringName, items: Array) -> Variant:
	if items.is_empty():
		return null
	var n: int = items.size()
	var idx: int = get_rng(stream) % n
	return items[idx]

# Persistent state for save files.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key in _state.keys():
		var pair: Array = _state[key]
		out[String(key)] = [int(pair[0]), int(pair[1])]
	return out

func from_dict(d: Dictionary) -> void:
	_state = {}
	for key in d.keys():
		var pair_raw: Variant = d[key]
		if typeof(pair_raw) != TYPE_ARRAY:
			continue
		var pair: Array = pair_raw
		if pair.size() < 2:
			continue
		_state[StringName(String(key))] = [int(pair[0]), int(pair[1])]

# ------------------------------------------------------------------ internals

func _mix_seed(seed_value: int) -> int:
	var x: int = seed_value
	if x == 0:
		x = 0x123456789ABCDEF
	x = x ^ (x << 30)
	x = x ^ (x >> 27)
	x = x ^ (x << 4)
	return x & INT63_MAX

func _derive_pair(s0: int, salt: String) -> Array:
	var h: int = hash(salt)
	var a: int = s0 ^ (h & 0xFFFFFFFF)
	var b: int = s0 ^ ((h >> 32) & 0xFFFFFFFF)
	if a == 0:
		a = 1
	if b == 0:
		b = 1
	return [a, b]