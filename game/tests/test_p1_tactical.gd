extends SceneTree

## Stage 5 / P1 tactical lab test.
## Covers: grid, pathfinder, movement, visibility, sound_pulse,
##         alertness, combat, search, infection.
##
## Uses Script constants (no class_name globals) so the script can be
## loaded via --script before the global class registry is built.

const GridScript: GDScript = preload("res://game/domain/tactical/grid.gd")
const PathfinderScript: GDScript = preload("res://game/domain/tactical/pathfinder.gd")
const MovementScript: GDScript = preload("res://game/domain/tactical/movement.gd")
const VisibilityScript: GDScript = preload("res://game/domain/tactical/visibility.gd")
const SoundPulseScript: GDScript = preload("res://game/domain/tactical/sound_pulse.gd")
const AlertnessScript: GDScript = preload("res://game/domain/tactical/alertness.gd")
const CombatScript: GDScript = preload("res://game/domain/tactical/combat.gd")
const SearchScript: GDScript = preload("res://game/domain/tactical/search.gd")
const InfectionScript: GDScript = preload("res://game/domain/infection/infection.gd")
const RngServiceScript: GDScript = preload("res://game/core/rng_service.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p1_tactical start ===")
	_test_movement_speed_and_alert()
	_test_visibility_symmetric()
	_test_visibility_corners()
	_test_sound_pulse_attenuation()
	_test_sound_pulse_door_blocks()
	_test_alertness_promotion_and_decay()
	_test_alertness_locked_on_decay()
	_test_combat_hit_chance_range()
	_test_combat_rifle_vs_full_cover_never_hits()
	_test_combat_kill_pipe()
	_test_search_modes_yield()
	_test_search_thorough_finds_hidden()
	_test_infection_stage_progression()
	_test_infection_cleaning_pre_25()
	_test_infection_suppressant_floor()
	_test_infection_cannot_clean_post_25()
	_test_infection_terminal_at_100()
	_test_infected_scratch_dose_range()
	_test_bite_dose_range()
	print("=== test_p1_tactical result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

# ---- helpers
func _mk_rng(seed_value: int) -> RefCounted:
	var r: RefCounted = RngServiceScript.new()
	r.seed(seed_value)
	return r

# ---- movement
func _test_movement_speed_and_alert() -> void:
	print("[1] movement: speed 1x/2x, alert denies 2x")
	var m: RefCounted = MovementScript.new()
	_expect(m.get_speed() == 1, "default speed 1")
	_expect(m.request_speed(2, false) == true, "2x allowed when not alert")
	_expect(m.get_speed() == 2, "speed is 2")
	# Try to set 2x with alert: should be denied (request_speed returns false),
	# but the previously-set speed of 2 stays at 2 — so instead we test that
	# the call is rejected (no transition from alert → 2x accepted).
	var m2: RefCounted = MovementScript.new()
	_expect(m2.get_speed() == 1, "fresh movement at speed 1")
	_expect(m2.request_speed(2, true) == false, "2x denied when alert (from speed 1)")
	_expect(m2.get_speed() != 2, "speed did NOT become 2 when alert blocks from 1")
	# Now go to 2x cleanly, then trigger alert → must auto-downgrade to 1.
	_expect(m2.request_speed(2, false) == true, "2x allowed after alert cleared")
	_expect(m2.get_speed() == 2, "speed is 2")
	_expect(abs(m2.seconds_per_step() - 0.5) < 0.001, "2x = 0.5s/step")
	m2.set_alert(true)
	_expect(m2.get_speed() != 2, "alert auto-downgrades 2x → 1x")
	_expect(abs(m2.seconds_per_step() - 1.0) < 0.001, "1x = 1.0s/step")

# ---- visibility
func _test_visibility_symmetric() -> void:
	print("[2] visibility: symmetric FOV")
	var g: RefCounted = GridScript.new(16, 16)
	var blocked: Array = [Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 4)]
	var origins: Array = [Vector2i(2, 2), Vector2i(10, 10), Vector2i(3, 12), Vector2i(14, 14)]
	_expect(VisibilityScript.is_symmetric(g, origins, 6, blocked), "FOV symmetric across 4 origins")

func _test_visibility_corners() -> void:
	print("[3] visibility: corners and blockers")
	var g: RefCounted = GridScript.new(8, 8)
	var blocked: Array = [Vector2i(4, 4)]
	# Origin sees itself.
	var seen: Array = VisibilityScript.fov_from(g, Vector2i(0, 0), 4, blocked)
	_expect(seen.size() > 0, "FOV non-empty at origin")
	var found_self: bool = false
	for v in seen:
		if Vector2i(v) == Vector2i(0, 0):
			found_self = true
			break
	_expect(found_self, "origin always visible")
	# can_see sanity.
	_expect(VisibilityScript.can_see(g, Vector2i(0, 0), Vector2i(2, 2), []) == true,
		"can_see open line (0,0)-(2,2)")
	_expect(VisibilityScript.can_see(g, Vector2i(0, 0), Vector2i(7, 7), []) == true,
		"can_see diagonal far cell")
	_expect(VisibilityScript.can_see(g, Vector2i(0, 0), Vector2i(0, 5), [Vector2i(0, 3)]) == false,
		"wall blocks line (0,0)-(0,5) when blocker at (0,3)")

# ---- sound
func _test_sound_pulse_attenuation() -> void:
	print("[4] sound: open vs wall attenuation")
	var g: RefCounted = GridScript.new(10, 10)
	var mm: Dictionary = {}  # no walls; everything is OPEN
	mm[String.num(5, 0) + "," + String.num(0, 0)] = SoundPulseScript.MATERIAL_OPEN
	var d: Dictionary = SoundPulseScript.pulse(Vector2i(0, 0), 5, 100.0, g, mm)
	var key: String = String.num(5, 0) + "," + String.num(5, 0)
	_expect(d.has(key), "key (5,5) is in map")
	var heard: float = float(d[key])
	_expect(heard > 0.0 and heard <= 100.0, "heard in (0,100] for open grid")

func _test_sound_pulse_door_blocks() -> void:
	print("[5] sound: door_closed fully blocks")
	var g: RefCounted = GridScript.new(10, 1)
	var mm: Dictionary = {}
	mm["5,0"] = SoundPulseScript.MATERIAL_DOOR_CLOSED
	var d: Dictionary = SoundPulseScript.pulse(Vector2i(0, 0), 10, 100.0, g, mm)
	# Cells on the other side of the door should have ~0 heard.
	var reached: bool = false
	for k in d.keys():
		var parts: PackedStringArray = (k as String).split(",")
		if int(parts[0]) >= 6:
			reached = true
			break
	_expect(not reached, "closed door fully blocks sound")

# ---- alertness
func _test_alertness_promotion_and_decay() -> void:
	print("[6] alertness: promotion, decay 10s")
	var a: RefCounted = AlertnessScript.new()
	_expect(a.stage == AlertnessScript.Stage.NONE, "starts NONE")
	a.update([{"kind": AlertnessScript.STIM_HEARD_PULSE, "intensity": 10, "position": Vector2i(5, 5)}], 0.0)
	_expect(a.stage == AlertnessScript.Stage.SUSPICIOUS, "heard → SUSPICIOUS")
	a.update([{"kind": AlertnessScript.STIM_HEARD_PULSE, "intensity": 10, "position": Vector2i(5, 5)}], 0.0)
	a.update([{"kind": AlertnessScript.STIM_HEARD_PULSE, "intensity": 10, "position": Vector2i(5, 5)}], 0.0)
	_expect(a.stage == AlertnessScript.Stage.INVESTIGATING, "3 ticks sustained → INVESTIGATING")
	# Now decay
	a.update([], 11.0)
	_expect(a.stage == AlertnessScript.Stage.SUSPICIOUS, "decayed one step to SUSPICIOUS")
	a.update([], 11.0)
	_expect(a.stage == AlertnessScript.Stage.NONE, "decayed to NONE")

func _test_alertness_locked_on_decay() -> void:
	print("[7] alertness: locked_on then lost_target")
	var a: RefCounted = AlertnessScript.new()
	a.update([{"kind": AlertnessScript.STIM_VISIBLE_TARGET, "position": Vector2i(8, 8)}], 0.0)
	_expect(a.stage == AlertnessScript.Stage.LOCKED_ON, "visible target → LOCKED_ON")
	a.update([{"kind": AlertnessScript.STIM_LOST_TARGET}], 0.0)
	_expect(a.stage == AlertnessScript.Stage.ALERT, "lost target → ALERT (not NONE)")
	# ALERT → decay one step to INVESTIGATING after DECAY_SECS.
	a.update([], 11.0)
	_expect(a.stage == AlertnessScript.Stage.INVESTIGATING, "decay ALERT → INVESTIGATING")

# ---- combat
func _test_combat_hit_chance_range() -> void:
	print("[8] combat: hit chance in [5%, 95%]")
	var rng: RefCounted = _mk_rng(42)
	var attacker: Dictionary = {"skill_combat": 3, "fatigue": 0, "stance": 2}
	var target: Dictionary = {"skill_combat": 0}
	# Force a near-worst scenario: rifle vs full cover, target moving, dark, distant
	var r1: Dictionary = CombatScript.resolve_attack(attacker, target, CombatScript.WEAPON_RIFLE, 12, 2, true, true, rng)
	_expect(float(r1["hit_chance"]) >= 0.05, "hit_chance floor (5%)")
	# Force best scenario
	var r2: Dictionary = CombatScript.resolve_attack(attacker, target, CombatScript.WEAPON_CROSSBOW, 0, 0, false, false, rng)
	_expect(float(r2["hit_chance"]) <= 0.95, "hit_chance ceiling (95%)")

func _test_combat_rifle_vs_full_cover_never_hits() -> void:
	# Worst case hit_chance when full cover + distance is clamped at HIT_MIN (0.05).
	# That's not zero, so we instead assert that hit_chance == 0.05 exactly.
	print("[9] combat: rifle vs full cover → minimum hit chance")
	var rng: RefCounted = _mk_rng(7)
	var attacker: Dictionary = {"skill_combat": 0, "fatigue": 100, "stance": 0}
	var target: Dictionary = {"skill_combat": 5}
	var r: Dictionary = CombatScript.resolve_attack(attacker, target, CombatScript.WEAPON_RIFLE, 20, 2, true, true, rng)
	_expect(abs(float(r["hit_chance"]) - 0.05) < 0.001, "hit_chance clamped to 0.05")
	_expect(r["side_effects"].has("loud"), "rifle side effect 'loud'")

func _test_combat_kill_pipe() -> void:
	print("[10] combat: pipe at point blank hits (sanity)")
	var rng: RefCounted = _mk_rng(1)
	var attacker: Dictionary = {"skill_combat": 2, "fatigue": 0, "stance": 0}
	var target: Dictionary = {"skill_combat": 0}
	var hits: int = 0
	for i in range(50):
		var r: Dictionary = CombatScript.resolve_attack(attacker, target, CombatScript.WEAPON_PIPE, 1, 0, false, false, rng)
		if r["hit"]:
			hits += 1
	var label: String = "pipe at 1 cell with skill 2 hits > 60%% of 50 (got %d)" % hits
	_expect(hits >= 30, label)

# ---- search
func _test_search_modes_yield() -> void:
	print("[11] search: QUICK < STANDARD < THOROUGH")
	var rng: RefCounted = _mk_rng(3)
	var container: Dictionary = {
		"id": "cab_1",
		"obvious": [],
		"loot_pool": [
			{"id": "bandage", "hidden": false, "weight": 1.0},
			{"id": "rifle_ammo", "hidden": true, "weight": 1.0},
		],
		"trap_chance": 0.0,
	}
	var s_quick: Dictionary = SearchScript.search_container(container, SearchScript.Mode.QUICK, 2, rng)
	var s_std: Dictionary = SearchScript.search_container(container, SearchScript.Mode.STANDARD, 2, rng)
	_expect(int(s_quick["sound"]) < int(s_std["sound"]), "QUICK < STANDARD sound")
	_expect(float(s_quick["time_s"]) < float(s_std["time_s"]), "QUICK < STANDARD time")

func _test_search_thorough_finds_hidden() -> void:
	print("[12] search: THOROUGH can find hidden items")
	var rng: RefCounted = _mk_rng(5)
	var container: Dictionary = {
		"id": "safe_1",
		"obvious": [{"id": "candle"}],
		"loot_pool": [
			{"id": "loot_a", "hidden": true, "weight": 1.0},
			{"id": "loot_b", "hidden": true, "weight": 1.0},
		],
		"trap_chance": 0.0,
	}
	var s: Dictionary = SearchScript.search_container(container, SearchScript.Mode.THOROUGH, 5, rng)
	_expect(s["loot"].size() >= 1, "THOROUGH with skill 5 finds at least one hidden (got %d)" % s["loot"].size())

# ---- infection
func _test_infection_stage_progression() -> void:
	print("[13] infection: bite pushes into LATENT/ONSET")
	var rng: RefCounted = _mk_rng(11)
	var ch: Dictionary = {"infection": 0}
	# 5 bites without protection should push into ONSET or beyond.
	var stage_seen: Array = []
	for i in range(5):
		InfectionScript.apply_exposure(ch, "bite", 1.0, rng)
		stage_seen.append(InfectionScript.stage_name(int(ch["infection"])))
	var max_stage: int = -1
	for sn in stage_seen:
		var idx: int = InfectionScript.STAGE_NAMES.find(sn)
		if idx > max_stage:
			max_stage = idx
	_expect(max_stage >= InfectionScript.Stage.LATENT, "at least LATENT after 5 bites (max=%s)" % InfectionScript.STAGE_NAMES[max_stage])
	_expect(InfectionScript.stage_name(int(ch["infection"])) != "EXPOSED", "no longer EXPOSED")

func _test_infection_cleaning_pre_25() -> void:
	print("[14] infection: cleaning pre-25 reduces value")
	var ch: Dictionary = {"infection": 20}
	var r: Dictionary = InfectionScript.clean_exposure(ch, 2, false)
	_expect(int(r["reduced"]) > 0, "cleaning reduced value (got %d)" % int(r["reduced"]))
	_expect(int(ch["infection"]) < 20, "infection value dropped")

func _test_infection_suppressant_floor() -> void:
	print("[15] infection: suppressant floors daily growth at 0")
	var ch: Dictionary = {"infection": 30, "fever": true, "dehydrated": false, "fatigue_below_25": true, "in_medical_bed": false, "used_suppressant": true, "suppressant_quality": 2}
	var r: Dictionary = InfectionScript.daily_tick(ch)
	# Base growth = 5, fever = +2, fatigue = +2 → 9. Suppressant q=2 reduces by 7 → 2.
	_expect(int(r["growth"]) >= 0, "growth floor ≥ 0")

func _test_infection_cannot_clean_post_25() -> void:
	print("[16] infection: cannot clean established infection below 25")
	var ch: Dictionary = {"infection": 40}
	var r: Dictionary = InfectionScript.clean_exposure(ch, 5, true)
	_expect(String(r.get("reason", "")) == "already_established" or int(r.get("reduced", 0)) == 0,
		"cleaning refused post-25")

func _test_infection_terminal_at_100() -> void:
	print("[17] infection: ≥ 100 = TERMINAL")
	_expect(InfectionScript.stage_of(100) == InfectionScript.Stage.TERMINAL, "100 → TERMINAL")
	_expect(InfectionScript.stage_of(99) == InfectionScript.Stage.CRITICAL, "99 → CRITICAL")
	_expect(InfectionScript.stage_of(75) == InfectionScript.Stage.CRITICAL, "75 → CRITICAL")
	_expect(InfectionScript.stage_of(74) == InfectionScript.Stage.ONSET, "74 → ONSET")
	_expect(InfectionScript.stage_of(50) == InfectionScript.Stage.ONSET, "50 → ONSET")
	_expect(InfectionScript.stage_of(49) == InfectionScript.Stage.LATENT, "49 → LATENT")
	_expect(InfectionScript.stage_of(25) == InfectionScript.Stage.LATENT, "25 → LATENT")
	_expect(InfectionScript.stage_of(24) == InfectionScript.Stage.EXPOSED, "24 → EXPOSED")

func _test_infected_scratch_dose_range() -> void:
	print("[18] infection: infected_scratch dose in [8, 20] no protection")
	var rng: RefCounted = _mk_rng(17)
	var hi: int = -1
	var lo: int = 999
	for i in range(200):
		var ch: Dictionary = {"infection": 0}
		var r: Dictionary = InfectionScript.apply_exposure(ch, "infected_scratch", 1.0, rng)
		var d: int = int(r["dose"])
		if d > hi: hi = d
		if d < lo: lo = d
	_expect(lo >= 8 and hi <= 20 and lo <= hi, "infected_scratch range [8,20] (got [%d,%d])" % [lo, hi])

func _test_bite_dose_range() -> void:
	print("[19] infection: bite dose in [35, 60] no protection")
	var rng: RefCounted = _mk_rng(31)
	var hi: int = -1
	var lo: int = 999
	for i in range(300):
		var ch: Dictionary = {"infection": 0}
		var r: Dictionary = InfectionScript.apply_exposure(ch, "bite", 1.0, rng)
		var d: int = int(r["dose"])
		if d > hi: hi = d
		if d < lo: lo = d
	_expect(lo >= 35 and hi <= 60, "bite range [35,60] (got [%d,%d])" % [lo, hi])