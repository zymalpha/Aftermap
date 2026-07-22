class_name Alertness extends RefCounted

## Enemy awareness / alertness state machine. Five stages per spec:
##   NONE → SUSPICIOUS → INVESTIGATING → ALERT → LOCKED_ON
##
## Promotion logic (deterministic, single-step):
##   - NEW visible target:  jump to LOCKED_ON
##   - NEW heard pulse above SUSPICIOUS_THRESHOLD:  SUSPICIOUS
##   - Sustained hearing of any intensity for HEAR_TICKS ticks: INVESTIGATING
##   - Seeing a corpse / broken door (external evidence) at EVIDENCE_THRESHOLD: ALERT
##
## Decay: if `decay_timer` reaches DECAY_SECS without new stimulus, the agent
## steps DOWN one stage (never below NONE). LOCKED_ON is sticky while the
## target is in FOV; it falls to ALERT otherwise.

const _PATH: String = "res://game/domain/tactical/alertness.gd"

enum Stage {NONE, SUSPICIOUS, INVESTIGATING, ALERT, LOCKED_ON}

# Stimulus kind labels used by update().
const STIM_VISIBLE_TARGET: StringName = &"visible_target"
const STIM_HEARD_PULSE: StringName = &"heard_pulse"
const STIM_EVIDENCE: StringName = &"evidence"      # e.g. corpse, broken door
const STIM_LOST_TARGET: StringName = &"lost_target" # target dropped from FOV

const SUSPICIOUS_THRESHOLD: int = 5    # intensity ≥ this = heard something
const INVESTIGATING_THRESHOLD: int = 15 # sustained-tick threshold
const HEAR_TICKS: int = 3               # ticks of sustained hearing
const ALERT_THRESHOLD: int = 30         # evidence-level intensity
const DECAY_SECS: float = 10.0

# Stage step ordering, used by decay and promotion.
const _STAGE_ORDER: Array = [Stage.NONE, Stage.SUSPICIOUS, Stage.INVESTIGATING, Stage.ALERT, Stage.LOCKED_ON]

var stage: int = Stage.NONE
var target: Vector2i = Vector2i(-1, -1)
var last_known_pos: Vector2i = Vector2i(-1, -1)
var decay_timer: float = 0.0
var _hear_ticks: int = 0

func _init() -> void:
	stage = Stage.NONE
	target = Vector2i(-1, -1)
	last_known_pos = Vector2i(-1, -1)
	decay_timer = 0.0
	_hear_ticks = 0

func get_stage_name() -> String:
	match stage:
		Stage.NONE: return "NONE"
		Stage.SUSPICIOUS: return "SUSPICIOUS"
		Stage.INVESTIGATING: return "INVESTIGATING"
		Stage.ALERT: return "ALERT"
		Stage.LOCKED_ON: return "LOCKED_ON"
	return "NONE"

func is_alert() -> bool:
	return stage >= Stage.ALERT

func is_combat() -> bool:
	return stage == Stage.LOCKED_ON

# Update the agent's awareness with a list of stimuli applied this tick.
# Each stimulus is a Dictionary:
#   { kind: StringName, intensity: int (optional), position: Vector2i }
# `dt` is the tick delta in seconds (used by the decay timer).
func update(stimuli: Array, dt: float) -> void:
	if dt <= 0.0:
		dt = 0.0

	# Highest-stimulus wins. If anything is visible we lock on immediately.
	for s in stimuli:
		var stim: Dictionary = s
		var kind: StringName = StringName(String(stim.get("kind", &"")))
		if kind == STIM_VISIBLE_TARGET:
			var pos: Vector2i = Vector2i(stim.get("position", Vector2i(-1, -1)))
			stage = Stage.LOCKED_ON
			target = pos
			last_known_pos = pos
			decay_timer = 0.0
			_hear_ticks = 0
			return

	# Evidence (corpse / broken door): jump to ALERT if intensity is sufficient.
	for s in stimuli:
		var stim2: Dictionary = s
		var kind2: StringName = StringName(String(stim2.get("kind", &"")))
		if kind2 == STIM_EVIDENCE:
			var inten: int = int(stim2.get("intensity", 0))
			if inten >= ALERT_THRESHOLD:
				stage = Stage.ALERT
				last_known_pos = Vector2i(stim2.get("position", last_known_pos))
				decay_timer = 0.0
				_hear_ticks = 0
				return
			elif inten >= INVESTIGATING_THRESHOLD and stage < Stage.INVESTIGATING:
				stage = Stage.INVESTIGATING
				last_known_pos = Vector2i(stim2.get("position", last_known_pos))
				decay_timer = 0.0
				return

	# Heard pulse: aggregate max intensity across the tick.
	var max_pulse: int = 0
	var pulse_pos: Vector2i = Vector2i(-1, -1)
	for s in stimuli:
		var stim3: Dictionary = s
		var kind3: StringName = StringName(String(stim3.get("kind", &"")))
		if kind3 == STIM_HEARD_PULSE:
			var inten3: int = int(stim3.get("intensity", 0))
			if inten3 > max_pulse:
				max_pulse = inten3
				pulse_pos = Vector2i(stim3.get("position", pulse_pos))

	if max_pulse > 0:
		_hear_ticks += 1
		decay_timer = 0.0
		# Heard something new: at minimum SUSPICIOUS.
		if max_pulse >= SUSPICIOUS_THRESHOLD and stage < Stage.SUSPICIOUS:
			stage = Stage.SUSPICIOUS
			last_known_pos = pulse_pos
		elif max_pulse > 0 and stage == Stage.NONE:
			stage = Stage.SUSPICIOUS
			last_known_pos = pulse_pos
		# Sustained hearing bumps us to INVESTIGATING.
		if _hear_ticks >= HEAR_TICKS and stage < Stage.INVESTIGATING:
			stage = Stage.INVESTIGATING
			last_known_pos = pulse_pos
	else:
		_hear_ticks = 0
		decay_timer += dt
		if decay_timer >= DECAY_SECS:
			_decay_one_step()

	# Lost target: drop out of LOCKED_ON.
	for s in stimuli:
		var stim4: Dictionary = s
		var kind4: StringName = StringName(String(stim4.get("kind", &"")))
		if kind4 == STIM_LOST_TARGET:
			if stage == Stage.LOCKED_ON:
				stage = Stage.ALERT
				decay_timer = 0.0

func _decay_one_step() -> void:
	if stage == Stage.NONE:
		return
	# Decay to previous stage.
	var idx: int = _STAGE_ORDER.find(stage)
	if idx <= 0:
		stage = Stage.NONE
		decay_timer = 0.0
		return
	stage = _STAGE_ORDER[idx - 1]
	decay_timer = 0.0
	# Reset heard-ticks counter on each decay to avoid immediate re-promotion.
	_hear_ticks = 0

func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"target_x": target.x,
		"target_y": target.y,
		"lkx": last_known_pos.x,
		"lky": last_known_pos.y,
		"decay_timer": decay_timer,
		"hear_ticks": _hear_ticks,
	}

func from_dict(d: Dictionary) -> void:
	stage = int(d.get("stage", Stage.NONE))
	target = Vector2i(int(d.get("target_x", -1)), int(d.get("target_y", -1)))
	last_known_pos = Vector2i(int(d.get("lkx", -1)), int(d.get("lky", -1)))
	decay_timer = float(d.get("decay_timer", 0.0))
	_hear_ticks = int(d.get("hear_ticks", 0))