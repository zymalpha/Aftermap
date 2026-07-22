class_name SearchSystem extends RefCounted

## Container / room search resolver.
##
## Three modes per 策划06 §8:
##   QUICK     — low time, low sound, low risk; finds obvious items only
##   STANDARD  — moderate time/sound; balanced yield
##   THOROUGH  — high time/sound; highest yield AND highest risk
##
## Skill shortens time and improves identification; it never invents loot.

const _PATH: String = "res://game/domain/tactical/search.gd"

enum Mode {QUICK, STANDARD, THOROUGH}

const MODE_QUICK_SECONDS: float = 4.0
const MODE_STANDARD_SECONDS: float = 8.0
const MODE_THOROUGH_SECONDS: float = 16.0

const MODE_QUICK_SOUND: int = 2
const MODE_STANDARD_SOUND: int = 5
const MODE_THOROUGH_SOUND: int = 12

const MODE_QUICK_RISK: float = 0.05
const MODE_STANDARD_RISK: float = 0.12
const MODE_THOROUGH_RISK: float = 0.25

const SKILL_TIME_FACTOR: Array = [1.40, 1.20, 1.00, 0.85, 0.75, 0.65]
const SKILL_IDENTIFY_BONUS: Array = [0.0, 0.05, 0.10, 0.18, 0.25, 0.35]

# `container` is a Dictionary like:
#   {
#     "id": "cabinet_3",
#     "loot_pool": [ {id, weight, hidden:bool}, ... ],   # hidden items only in THOROUGH
#     "obvious": [ ... ],                                # always visible
#     "trap_chance": float,                              # 0..1; only triggers in THOROUGH with risk
#   }
#
# `mode` is Mode.QUICK/STANDARD/THOROUGH.
# `searcher_skill` is 0..5.
# `rng`: any object exposing get_float(stream, lo, hi).
#
# Returns:
#   { loot: [...], time_s: float, sound: int, risk_triggered: bool, identified_hidden: int }
static func search_container(container: Dictionary, mode: int, searcher_skill: int, rng: RefCounted) -> Dictionary:
	var skill: int = clampi(int(searcher_skill), 0, 5)
	var base_seconds: float = _seconds_for_mode(mode)
	var time_factor: float = SKILL_TIME_FACTOR[skill]
	var time_s: float = base_seconds * time_factor

	var sound: int = _sound_for_mode(mode)
	var risk: float = _risk_for_mode(mode)

	# Build the loot list.
	var loot: Array = []
	# Always include "obvious" items.
	var obvious: Array = container.get("obvious", [])
	for o in obvious:
		loot.append((o as Dictionary).duplicate(true))

	# Hidden items only in STANDARD or THOROUGH; chance improved by skill and
	# identification bonus.
	var pool: Array = container.get("loot_pool", [])
	var hidden_found: int = 0
	for entry in pool:
		var e: Dictionary = entry
		var hidden: bool = bool(e.get("hidden", false))
		if not hidden:
			# Non-hidden pool entries: include in STANDARD+THOROUGH.
			if mode >= Mode.STANDARD:
				loot.append(e.duplicate(true))
			continue
		if mode < Mode.THOROUGH:
			continue
		var weight: float = float(e.get("weight", 1.0))
		var chance: float = weight * (0.5 + SKILL_IDENTIFY_BONUS[skill])
		var roll: float = 0.0
		if rng != null:
			roll = rng.call("get_float", &"search_container", 0.0, 1.0)
		if roll < chance:
			loot.append(e.duplicate(true))
			hidden_found += 1

	# Trap roll: only meaningful in THOROUGH (or any mode that triggers risk).
	var trap_chance: float = float(container.get("trap_chance", 0.0))
	var triggered: bool = false
	if trap_chance > 0.0 and risk > 0.0:
		var r2: float = trap_chance * risk
		var roll2: float = 0.0
		if rng != null:
			roll2 = rng.call("get_float", &"search_trap", 0.0, 1.0)
		triggered = roll2 < r2

	return {
		"loot": loot,
		"time_s": time_s,
		"sound": sound,
		"risk_triggered": triggered,
		"identified_hidden": hidden_found,
	}

static func _seconds_for_mode(mode: int) -> float:
	match mode:
		Mode.QUICK: return MODE_QUICK_SECONDS
		Mode.STANDARD: return MODE_STANDARD_SECONDS
		Mode.THOROUGH: return MODE_THOROUGH_SECONDS
	return MODE_STANDARD_SECONDS

static func _sound_for_mode(mode: int) -> int:
	match mode:
		Mode.QUICK: return MODE_QUICK_SOUND
		Mode.STANDARD: return MODE_STANDARD_SOUND
		Mode.THOROUGH: return MODE_THOROUGH_SOUND
	return MODE_STANDARD_SOUND

static func _risk_for_mode(mode: int) -> float:
	match mode:
		Mode.QUICK: return MODE_QUICK_RISK
		Mode.STANDARD: return MODE_STANDARD_RISK
		Mode.THOROUGH: return MODE_THOROUGH_RISK
	return MODE_STANDARD_RISK