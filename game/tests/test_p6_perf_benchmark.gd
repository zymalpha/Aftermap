extends SceneTree

## Stage 18 / P6 performance benchmark.
##
## 30-unit pressure scenario. Per simulated frame the engine does:
##   - ONE shared sound pulse from a noise source (sound is per-event in the
##     design, not per-unit — every unit within range hears the same pulse),
##   - for each of 30 units: A* pathfind toward its goal, FOV from its cell,
##     a heard-intensity lookup against the shared pulse, and an alertness
##     update with the resulting stimuli.
##
## Grid: 24x24 (the lower end of the "普通场景" band per
##   06_探索潜行战斗与感染 §2.1: 24x24 .. 64x64). 30 units in a 24x24 scene
##   is a dense pressure case (the design cap is 30 AI). FOV/sound radius 6.
##
## Timing model: we run FRAME_COUNT frames, measure each with
## Time.get_ticks_usec, and assert:
##   - average frame < 16.67 ms (60 fps budget)
##   - max frame      < 33.00 ms (30 fps floor)
##
## Note on workload: an earlier draft emitted one sound pulse per unit per
## frame, which is not how the engine uses SoundPulse (a pulse is per noise
## event and shared across all hearers). The corrected, engine-faithful
## workload is what's benchmarked here.

const PathfinderMod = preload("res://game/domain/tactical/pathfinder.gd")
const GridMod = preload("res://game/domain/tactical/grid.gd")
const VisibilityMod = preload("res://game/domain/tactical/visibility.gd")
const SoundPulseMod = preload("res://game/domain/tactical/sound_pulse.gd")
const AlertnessMod = preload("res://game/domain/tactical/alertness.gd")

const GRID_W: int = 24
const GRID_H: int = 24
const NUM_UNITS: int = 30
const FOV_RADIUS: int = 6
const SOUND_RADIUS: int = 6
const SOUND_INTENSITY: float = 60.0
const WALL_DENSITY: float = 0.10
const TARGET_AVG_MS: float = 16.67   # 60 fps
const TARGET_MAX_MS: float = 33.00   # 30 fps
# 1500 frames keeps the benchmark in the 10-20s wall range on a typical
# dev laptop while giving a stable average and a meaningful max.
const FRAME_COUNT: int = 1500

var _pass_count: int = 0
var _fail_count: int = 0

func _initialize() -> void:
	print("=== test_p6_perf_benchmark start ===")
	print("Scenario: %d units x %d frames on %dx%d grid (FOV r=%d, sound r=%d, 1 shared pulse/frame)" %
		[NUM_UNITS, FRAME_COUNT, GRID_W, GRID_H, FOV_RADIUS, SOUND_RADIUS])

	# Build the grid + a static wall field (~10% blocked, deterministic).
	var grid: RefCounted = GridMod.new(GRID_W, GRID_H)
	var walls: Array = []
	var prng: RefCounted = _PrngAdapter.new(1337)
	for y in range(GRID_H):
		for x in range(GRID_W):
			if x <= 1 or y <= 1 or x >= GRID_W - 2 or y >= GRID_H - 2:
				continue
			if prng.randf() < WALL_DENSITY:
				walls.append(Vector2i(x, y))
	var wall_set: Dictionary = {}
	for w in walls:
		wall_set[Vector2i(w)] = true

	# Material map for sound: walls attenuate heavily.
	var material_map: Dictionary = {}
	for w in walls:
		material_map[SoundPulseMod._key(Vector2i(w))] = SoundPulseMod.MATERIAL_WALL

	# Per-unit state: position, goal, alertness.
	var positions: Array = []
	var goals: Array = []
	var alerts: Array = []
	var init_prng: RefCounted = _PrngAdapter.new(2026)
	for i in range(NUM_UNITS):
		positions.append(_random_open_cell(init_prng, wall_set))
		goals.append(_random_open_cell(init_prng, wall_set))
		alerts.append(AlertnessMod.new())

	# Warmup: one untimed frame so static heap / arrays are allocated.
	_simulate_one_frame(grid, walls, wall_set, material_map, positions, goals, alerts, init_prng)

	# Timed loop.
	var frame_times_us: PackedInt64Array = PackedInt64Array()
	frame_times_us.resize(FRAME_COUNT)
	var total_us: int = 0
	var max_us: int = 0
	var min_us: int = 9223372036854775807

	for f in range(FRAME_COUNT):
		var t0: int = Time.get_ticks_usec()
		_simulate_one_frame(grid, walls, wall_set, material_map, positions, goals, alerts, init_prng)
		var dt_us: int = Time.get_ticks_usec() - t0
		frame_times_us[f] = dt_us
		total_us += dt_us
		if dt_us > max_us:
			max_us = dt_us
		if dt_us < min_us:
			min_us = dt_us

	var avg_us: float = float(total_us) / float(FRAME_COUNT)
	var avg_ms: float = avg_us / 1000.0
	var max_ms: float = float(max_us) / 1000.0
	var min_ms: float = float(min_us) / 1000.0
	var total_s: float = float(total_us) / 1000000.0
	var achieved_fps: float = 1000.0 / avg_ms if avg_ms > 0.0 else 0.0

	# Percentiles for context.
	var sorted: PackedInt64Array = frame_times_us.duplicate()
	sorted.sort()
	var p99_us: int = sorted[int(float(sorted.size()) * 0.99)]
	var p95_us: int = sorted[int(float(sorted.size()) * 0.95)]
	var p99_ms: float = float(p99_us) / 1000.0
	var p95_ms: float = float(p95_us) / 1000.0

	print("--- timing ---")
	print("  frames           : %d" % FRAME_COUNT)
	print("  wall total       : %.2f s" % total_s)
	print("  avg frame        : %.3f ms  (target < %.2f ms / 60fps)" % [avg_ms, TARGET_AVG_MS])
	print("  min frame        : %.3f ms" % min_ms)
	print("  p95 frame        : %.3f ms" % p95_ms)
	print("  p99 frame        : %.3f ms" % p99_ms)
	print("  max frame        : %.3f ms  (target < %.2f ms / 30fps)" % [max_ms, TARGET_MAX_MS])
	print("  achieved avg fps : %.1f" % achieved_fps)

	_expect(avg_ms < TARGET_AVG_MS,
		"avg frame %.3f ms < %.2f ms (60fps)" % [avg_ms, TARGET_AVG_MS])
	_expect(max_ms < TARGET_MAX_MS,
		"max frame %.3f ms < %.2f ms (30fps)" % [max_ms, TARGET_MAX_MS])

	print("=== test_p6_perf_benchmark result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

## One simulated frame: one shared sound pulse, then each unit pathfinds
## toward its goal, computes FOV, looks up its heard intensity, and updates
## alertness with the resulting stimuli.
##
## Allocations are kept out of the hot loop: the reusable stimuli array and
## heard-pulse stimulus dict are pre-allocated once and mutated in place, so
## the benchmark measures the four tactical systems (pathfind / FOV /
## sound_pulse / alertness) rather than GDScript heap churn.
func _simulate_one_frame(grid: RefCounted, walls: Array, wall_set: Dictionary,
		material_map: Dictionary, positions: Array, goals: Array,
		alerts: Array, prng: RefCounted) -> void:
	# 1 shared noise source for this frame.
	var noise_origin: Vector2i = _random_open_cell(prng, wall_set)
	var pulse: Dictionary = SoundPulseMod.pulse(noise_origin, SOUND_RADIUS,
		SOUND_INTENSITY, grid, material_map)

	# Reusable stimulus container + heard-pulse stimulus dict, cleared each unit.
	var stimuli: Array = []
	var heard_stim: Dictionary = {
		"kind": "heard_pulse",
		"intensity": 0,
		"position": noise_origin,
	}

	for i in range(NUM_UNITS):
		var pos: Vector2i = positions[i]
		var goal: Vector2i = goals[i]

		# 1. Pathfind toward goal; step one cell along the path.
		var path: Array = PathfinderMod.a_star(grid, pos, goal, walls)
		if path.size() > 1:
			positions[i] = Vector2i(path[1])
			if positions[i] == goal:
				goals[i] = _random_open_cell(prng, wall_set)
		else:
			goals[i] = _random_open_cell(prng, wall_set)

		# 2. FOV from the (possibly updated) position.
		var _seen_count: int = VisibilityMod.fov_from(grid, positions[i], FOV_RADIUS, walls).size()

		# 3. Stimulus: heard pulse at current cell (visible-target detection
		#    is exercised by the FOV call above and in test_p1_tactical; here
		#    we feed the alertness FSM the heard-pulse stimulus derived from
		#    the shared sound_pulse).
		stimuli.clear()
		var heard_here: Variant = pulse.get(SoundPulseMod._key(positions[i]), 0)
		if int(heard_here) > 0:
			heard_stim["intensity"] = int(heard_here)
			heard_stim["position"] = noise_origin
			stimuli.append(heard_stim)

		# 4. Update alertness (dt = 1/60 s).
		alerts[i].update(stimuli, 1.0 / 60.0)

func _random_open_cell(prng: RefCounted, wall_set: Dictionary) -> Vector2i:
	for _attempt in range(200):
		var x: int = prng.randi_range(0, GRID_W - 1)
		var y: int = prng.randi_range(0, GRID_H - 1)
		var cell: Vector2i = Vector2i(x, y)
		if not wall_set.has(cell):
			return cell
	return Vector2i(2, 2)  # fallback

# Benchmark-local PRNG adapter so the perf sweep doesn't touch the game's
# named-stream RngService (keeps it independent from the 1000-seed test).
class _PrngAdapter:
	extends RefCounted
	var _rng: RandomNumberGenerator
	func _init(s: int) -> void:
		_rng = RandomNumberGenerator.new()
		_rng.seed = s
	func randf() -> float:
		return _rng.randf()
	func randi_range(a: int, b: int) -> int:
		return _rng.randi_range(a, b)
