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
var _enter_hooks: Dictionary = {}  # state -> Array[Callable] — fired on enter
var _exit_hooks: Dictionary = {}   # state -> Array[Callable] — fired on exit

func _init() -> void:
	current_state = State.MORNING_REPORT
	day = 1
	_enter_hooks = {}
	_exit_hooks = {}

func _log(msg: String) -> void:
	push_warning("[DayStateMachine] " + msg)

## Register a callable to run when the named state is ENTERED.
## Hook signature: func(state: int, day: int, payload: Dictionary) -> void
func on_enter(state: int, hook: Callable) -> void:
	if not _enter_hooks.has(state):
		_enter_hooks[state] = []
	(_enter_hooks[state] as Array).append(hook)

## Register a callable to run when the named state is EXITED.
func on_exit(state: int, hook: Callable) -> void:
	if not _exit_hooks.has(state):
		_exit_hooks[state] = []
	(_exit_hooks[state] as Array).append(hook)

## Move to a new state. Fires exit hooks for the previous state, then
## enter hooks for the new one. Always returns OK.
##
## Day-rolling semantics: when transitioning from NIGHT_RESOLVE
## (outgoing) to MORNING_REPORT (incoming), the day counter is
## incremented by 1. This is the canonical "end of day" boundary.
## Hooks that drive day rolls via session.issue_command advance_day
## MUST NOT do so when the state machine is about to auto-roll —
## the App's NIGHT_RESOLVE hook is designed to NOT call advance_day,
## letting the state machine's transition auto-roll advance the day.
##
## Implementation note: we save the outgoing state BEFORE mutating
## current_state so we can detect the NIGHT_RESOLVE -> MORNING_REPORT
## edge. We also use separate _enter_hooks / _exit_hooks dicts
## (a previous version of this file mistakenly shared a single
## _hooks dict, which caused hooks to fire as both enter and exit).
func transition_to(new_state: int, payload: Dictionary = {}) -> int:
	if new_state == current_state:
		return OK
	var outgoing: int = current_state
	# Exit hooks for the OUTGOING state.
	if _exit_hooks.has(outgoing):
		for hook in (_exit_hooks[outgoing] as Array):
			if hook is Callable and (hook as Callable).is_valid():
				(hook as Callable).call(outgoing, day, payload)
	# Day-roll: NIGHT_RESOLVE -> MORNING_REPORT transitions advance day.
	if outgoing == State.NIGHT_RESOLVE and new_state == State.MORNING_REPORT:
		day += 1
	current_state = new_state
	# Enter hooks for the INCOMING state.
	if _enter_hooks.has(new_state):
		for hook in (_enter_hooks[new_state] as Array):
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
## Hooks may call transition_to() internally — for example the App
## uses NIGHT_MGMT hook to chain into NIGHT_RESOLVE when no event
## fires, and NIGHT_RESOLVE hook to chain into MORNING_REPORT for
## the next day. Once the chain has run to completion (NIGHT_MGMT ->
## NIGHT_RESOLVE -> MORNING_REPORT), current_state == MORNING_REPORT
## and the run_full_day loop is essentially done — any further
## iteration that re-enters NIGHT_RESOLVE would re-fire the
## advance_day hook and double the day counter.
##
## Strategy: after each transition, if current_state has wrapped
## *back to* MORNING_REPORT (start of next day), stop. Once we've
## visited NIGHT_RESOLVE AND MORNING_REPORT again, the day has rolled.
func run_full_day(payload: Dictionary = {}) -> Dictionary:
	var counts: Dictionary = {}
	for s in STATE_NAMES:
		counts[s] = 0
	if current_state != State.MORNING_REPORT:
		transition_to(State.MORNING_REPORT, payload)
		counts[STATE_NAMES[current_state]] = int(counts.get(STATE_NAMES[current_state], 0)) + 1
	var rolled: bool = false
	for s in TRANSITION_ORDER:
		if rolled:
			break
		if current_state != s:
			transition_to(s, payload)
		counts[STATE_NAMES[current_state]] = int(counts.get(STATE_NAMES[current_state], 0)) + 1
		# Detect roll: if we previously went past NIGHT_RESOLVE (e.g.
		# via hook chain) and have come back to MORNING_REPORT, the day
		# has rolled. We mark rolled so subsequent iterations break.
		if current_state == State.MORNING_REPORT and s != State.MORNING_REPORT:
			rolled = true
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