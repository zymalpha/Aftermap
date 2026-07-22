class_name InfectionSystem extends RefCounted

## Infection exposure & stage progression.
##
## Stages (per 策划06 §16.3):
##   EXPOSED    0..24  — pre-establishment; processing and cleaning can drop value
##   LATENT     25..49 — established; daily growth +5 base; treatment cannot drop below 25
##   ONSET      50..74 — symptoms begin; risk of breakdown events
##   CRITICAL   75..99 — high risk of loss-of-control events
##   TERMINAL  100     — terminal flow
##
## Exposure dose sources (策划06 §5):
##   surface_touch:   0
##   mucosal_splash:  3..10
##   weapon_scratch:  5..15
##   infected_scratch:8..20
##   bite:            35..60
##   unprotected_processing: 10..25

const _PATH: String = "res://game/domain/infection/infection.gd"

enum Stage {EXPOSED, LATENT, ONSET, CRITICAL, TERMINAL}

const STAGE_NAMES: Array = ["EXPOSED", "LATENT", "ONSET", "CRITICAL", "TERMINAL"]

# Source kinds and their base dose ranges.
const SOURCE_KINDS: Dictionary = {
	"surface_touch":            [0, 0],
	"mucosal_splash":           [3, 10],
	"weapon_scratch":           [5, 15],
	"infected_scratch":         [8, 20],
	"bite":                     [35, 60],
	"unprotected_processing":   [10, 25],
}

# Stage thresholds (lower bound). ≥ upper bound moves to the next stage.
const THRESHOLD_LATENT: int = 25
const THRESHOLD_ONSET: int = 50
const THRESHOLD_CRITICAL: int = 75
const THRESHOLD_TERMINAL: int = 100

const INFECTION_MAX: int = 100

# Daily growth model (策划09 §12). Applied via daily_tick().
const DAILY_BASE_GROWTH: int = 5
const DAILY_GROWTH_FEVER: int = 2
const DAILY_GROWTH_DEHYDRATION: int = 2
const DAILY_GROWTH_FATIGUE: int = 2
const MEDICAL_BED_REDUCTION: int = 1
const SUPPRESSANT_MIN_GROWTH: int = 0  # net daily growth floor under suppressant
const SUPPRESSANT_RANGE: Array = [4, 7]

# A character state carries the infection value (0..100) and modifiers.
# We treat this as a small Dictionary to keep it free of Godot dependencies.
static func stage_of(value: int) -> int:
	if value >= THRESHOLD_TERMINAL:
		return Stage.TERMINAL
	if value >= THRESHOLD_CRITICAL:
		return Stage.CRITICAL
	if value >= THRESHOLD_ONSET:
		return Stage.ONSET
	if value >= THRESHOLD_LATENT:
		return Stage.LATENT
	return Stage.EXPOSED

static func stage_name(value: int) -> String:
	return STAGE_NAMES[stage_of(value)]

# Apply a single exposure event to the character's infection value.
# `state` is a Dictionary with at least { "infection": int (0..100) }.
# `source` is one of SOURCE_KINDS keys.
# `protection_factor` 0..1 reduces the dose (1 = no protection, 0 = full block).
# `rng`: any object exposing get_rng(stream) returning int.
# Returns:
#   { applied: bool, dose: int, new_value: int, stage: int, stage_changed: bool }
static func apply_exposure(state: Dictionary, source: String, protection_factor: float, rng: RefCounted) -> Dictionary:
	if not SOURCE_KINDS.has(source):
		return {"applied": false, "dose": 0, "new_value": int(state.get("infection", 0)),
				"stage": stage_of(int(state.get("infection", 0))), "stage_changed": false,
				"reason": "unknown_source"}
	var range_pair: Array = SOURCE_KINDS[source]
	var lo: int = int(range_pair[0])
	var hi: int = int(range_pair[1])
	var raw: int = lo
	if hi > lo and rng != null:
		raw = rng.call("get_rng", &"infection_exposure") % (hi - lo + 1) + lo
	elif hi > lo:
		raw = (lo + hi) / 2
	var pf: float = clampf(protection_factor, 0.0, 1.0)
	var dose: int = int(round(float(raw) * pf))
	if dose <= 0:
		return {"applied": false, "dose": 0,
				"new_value": int(state.get("infection", 0)),
				"stage": stage_of(int(state.get("infection", 0))),
				"stage_changed": false}

	var before_stage: int = stage_of(int(state.get("infection", 0)))
	var new_value: int = int(state.get("infection", 0)) + dose
	if new_value > INFECTION_MAX:
		new_value = INFECTION_MAX
	state["infection"] = new_value
	var after_stage: int = stage_of(new_value)
	return {
		"applied": true,
		"dose": dose,
		"new_value": new_value,
		"stage": after_stage,
		"stage_changed": before_stage != after_stage,
	}

# Clean an exposure before establishment (value < 25).
# `cleaning_skill`: 0..5; higher skill reduces more.
# `is_medical_station`: bool; doubles reduction.
# Returns how much the value dropped (clamped to keep value ≥ 0).
static func clean_exposure(state: Dictionary, cleaning_skill: int, is_medical_station: bool) -> Dictionary:
	var cur: int = int(state.get("infection", 0))
	if cur >= THRESHOLD_LATENT:
		return {"reduced": 0, "reason": "already_established"}
	var skill: int = clampi(int(cleaning_skill), 0, 5)
	var base_reduce: int = 3 + skill * 2  # 3..13
	if is_medical_station:
		base_reduce = base_reduce * 2
	var reduced: int = min(cur, base_reduce)
	state["infection"] = cur - reduced
	return {"reduced": reduced, "new_value": state["infection"]}

# Apply a single daily tick to established infection.
# `state` carries infection value and optionally:
#   fever: bool, dehydrated: bool, fatigue_below_25: bool, in_medical_bed: bool,
#   used_suppressant: bool, suppressant_quality: 0..2.
# Returns: { growth: int, new_value: int, stage: int, floor_applied: bool }
static func daily_tick(state: Dictionary) -> Dictionary:
	var cur: int = int(state.get("infection", 0))
	if cur < THRESHOLD_LATENT:
		# Pre-establishment: no forced growth, but base 0..4 from wound
		# contamination is handled separately. Here we just leave it.
		return {"growth": 0, "new_value": cur, "stage": stage_of(cur)}
	var growth: int = DAILY_BASE_GROWTH
	if bool(state.get("fever", false)):
		growth += DAILY_GROWTH_FEVER
	if bool(state.get("dehydrated", false)):
		growth += DAILY_GROWTH_DEHYDRATION
	if bool(state.get("fatigue_below_25", false)):
		growth += DAILY_GROWTH_FATIGUE
	if bool(state.get("in_medical_bed", false)):
		growth = max(0, growth - MEDICAL_BED_REDUCTION)
	if bool(state.get("used_suppressant", false)):
		var quality: int = int(state.get("suppressant_quality", 1))
		var qf: float = clampf(float(quality) / 2.0, 0.0, 1.0)
		var s_lo: int = SUPPRESSANT_RANGE[0]
		var s_hi: int = SUPPRESSANT_RANGE[1]
		var reduce: int = int(round(float(s_lo) + qf * float(s_hi - s_lo)))
		growth -= reduce
		if growth < SUPPRESSANT_MIN_GROWTH:
			growth = SUPPRESSANT_MIN_GROWTH
	var new_value: int = cur + growth
	if new_value > INFECTION_MAX:
		new_value = INFECTION_MAX
	state["infection"] = new_value
	return {"growth": growth, "new_value": new_value, "stage": stage_of(new_value)}