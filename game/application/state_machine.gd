class_name DayStateMachine extends RefCounted

## Daily state machine for the P2 vertical slice.
## Six canonical states per 策划12 §8.1:
##   MORNING_REPORT -> BASE_PLANNING -> DAY_ACTION
##   -> DUSK_CHOICE -> NIGHT_MANAGEMENT -> NIGHT_RESOLVE
## After NIGHT_RESOLVE the day ends and MORNING_REPORT fires for the next day.
##
## This machine is purely campaign-side (ADR-0003, ADR-0005): it is a
## deterministic state holder, not a presentation scene driver. Presentation
## (UI / scene transitions) listens to enter/exit hooks, never drives them.

const _PATH: String = "res://game/application/state_machine.gd"

enum State {
	MORNING_REPORT,
	BASE_PLANNING,
	DAY_ACTION,
	DUSK_CHOICE,
	NIGHT_MANAGEMENT,
	NIGHT_RESOLVE,
}

const STATE_NAMES: Array[String] = [
	"MORNING_REPORT",
	"BASE_PLANNING",
	"DAY_ACTION",
	"DUSK_CHOICE",
	"NIGHT_MANAGEMENT",
	"NIGHT_RESOLVE",
]

## Canonical clockwise transition order. Index i -> next is i+1; last loops to first.
const TRANSITION_ORDER: Array = [
	State.MORNING_REPORT,
	State.BASE_PLANNING,
	State.DAY_ACTION,
	State.DUSK_CHOICE,
	State.NIGHT_MANAGEMENT,
	State.NIGHT_RESOLVE,
]

var current_state: int = State.MORNING_REPORT
var day: int = 1
var _hooks: Dictionary = {}  # state -> Array[Callable]

func _init() -> void:
	current_state = State.MORNING_REPORT
	day = 1
	_hooks = {}

func _log(msg: String) -> void:
	push_warning("[DayStateMachine] " + msg)

## Register a callable to run when the named state is ENTERED.
## Hook signature: func(state: int, day: int, payload: Dictionary) -> void
func on_enter(state: int, hook: Callable) -> void:
	if not _hooks.has(state):
		_hooks[state] = []
	(_hooks[state] as Array).append(hook)

func on_exit(state: int, hook: Callable) -> void:
	if not _hooks.has(state):
		_hooks[state] = []
	(_hooks[state] as Array).append(hook)

## Move to a new state. Fires exit hooks for the previous state, then
## enter hooks for the new one. Always returns OK.
## When transitioning from NIGHT_RESOLVE, day is incremented by 1.
func transition_to(new_state: int, payload: Dictionary = {}) -> int:
	if new_state == current_state:
		return OK
	# exit hooks for previous
	if _hooks.has(current_state):
		for hook in (_hooks[current_state] as Array):
			if hook is Callable and (hook as Callable).is_valid():
				(hook as Callable).call(current_state, day, payload)
	if current_state == State.NIGHT_RESOLVE:
		day += 1
	current_state = new_state
	if _hooks.has(new_state):
		for hook in (_hooks[new_state] as Array):
			if hook is Callable and (hook as Callable).is_valid():
				(hook as Callable).call(new_state, day, payload)
	return OK

## Advance through TRANSITION_ORDER by `n` steps.
func advance_steps(n: int = 1, payload: Dictionary = {}) -> int:
	var steps: int = max(1, n)
	for i in range(steps):
		var idx: int = TRANSITION_ORDER.find(current_state)
		if idx < 0:
			idx = 0
		var next_idx: int = (idx + 1) % TRANSITION_ORDER.size()
		var next_state: int = TRANSITION_ORDER[next_idx]
		transition_to(next_state, payload)
	return OK

## Convenience: run the full day cycle (6 transitions) and stop at
## NIGHT_RESOLVE. Returns Dictionary of state names -> entry counts.
func run_full_day(payload: Dictionary = {}) -> Dictionary:
	var counts: Dictionary = {}
	for s in STATE_NAMES:
		counts[s] = 0
	# If we somehow are mid-cycle, snap to MORNING_REPORT.
	if current_state != State.MORNING_REPORT:
		transition_to(State.MORNING_REPORT, payload)
	for s in TRANSITION_ORDER:
		transition_to(s, payload)
		counts[STATE_NAMES[s]] = int(counts.get(STATE_NAMES[s], 0)) + 1
	return counts

func get_state_name(state: int = -1) -> String:
	if state < 0:
		state = current_state
	if state >= 0 and state < STATE_NAMES.size():
		return STATE_NAMES[state]
	return "UNKNOWN"

func to_dict() -> Dictionary:
	return {
		"current_state": current_state,
		"current_state_name": get_state_name(current_state),
		"day": day,
	}

func from_dict(d: Dictionary) -> void:
	current_state = int(d.get("current_state", State.MORNING_REPORT))
	day = int(d.get("day", 1))