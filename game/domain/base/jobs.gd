class_name JobBoard extends RefCounted

## Job assignment board. 12 canonical jobs per 策划09 §10.
##
## Efficiency per the prompt:
##   - 1st worker: skill=2 + good state (energy>=25, hp>=25) => 1.0 / hour
##   - 2nd worker on same role: 70%
##   - 3rd+ worker: 0% (no slot)
##
## State values are clamped to [0, 100] where applicable.

const _PATH: String = "res://game/domain/base/jobs.gd"

const JOB_IDS: Array[String] = [
	"cook", "water", "medical", "engineering", "cleaning", "garden",
	"watch", "guard", "radio", "hauling", "rest", "free",
]

const JOB_NAMES_ZH: Dictionary = {
	"cook": "厨房", "water": "供水", "medical": "医护", "engineering": "工程",
	"cleaning": "清洁", "garden": "菜园", "watch": "瞭望", "guard": "守卫",
	"radio": "电台", "hauling": "搬运", "rest": "休整", "free": "自由",
}

const JOB_SKILL: Dictionary = {
	"cook": "medical", "water": "engineering", "medical": "medical",
	"engineering": "engineering", "cleaning": "medical", "garden": "search",
	"watch": "search", "guard": "combat", "radio": "social", "hauling": "search",
	"rest": "", "free": "",
}

## assignments: { role_id: [character_id, character_id, ...] }  (cap 3 per role)
var assignments: Dictionary = {}

func _init() -> void:
	assignments = {}
	for j in JOB_IDS:
		assignments[j] = []

func _log(msg: String) -> void:
	push_warning("[JobBoard] " + msg)

## Assign a character to a role. Removes them from any previous role.
## Returns true on success, false if role_id is unknown or slot full.
func assign(role_id: String, character_id: String) -> bool:
	if not JOB_IDS.has(role_id):
		return false
	if character_id == "":
		return false
	# Remove from any prior role.
	for j in JOB_IDS:
		var arr: Array = assignments[j]
		var idx: int = arr.find(character_id)
		if idx >= 0:
			arr.remove_at(idx)
	var target: Array = assignments[role_id]
	if target.size() >= 3:
		return false
	if not target.has(character_id):
		target.append(character_id)
	return true

func unassign(character_id: String) -> int:
	var removed: int = 0
	for j in JOB_IDS:
		var arr: Array = assignments[j]
		var idx: int = arr.find(character_id)
		if idx >= 0:
			arr.remove_at(idx)
			removed += 1
	return removed

func list_active_jobs() -> Array:
	var out: Array = []
	for j in JOB_IDS:
		if (assignments[j] as Array).size() > 0:
			out.append({
				"role_id": j,
				"name_zh": String(JOB_NAMES_ZH.get(j, j)),
				"workers": (assignments[j] as Array).duplicate(true),
			})
	return out

## Compute per-worker efficiency given the worker's skills and stats.
## Returns Dictionary { worker_efficiency: [{character_id, skill, hours}], total_per_hour: float }
func efficiency_snapshot(character_index: RefCounted) -> Dictionary:
	# character_index: a RefCounted exposing get(id) -> Dictionary of stats+skills
	# We accept a callable-style helper to look up characters without coupling to Character class.
	var per_role: Dictionary = {}
	var grand_total: float = 0.0
	for j in JOB_IDS:
		var workers: Array = assignments[j]
		var worker_eff: Array = []
		for i in range(workers.size()):
			var cid: String = String(workers[i])
			var ch: Variant = character_index.call("get_character", cid)
			if typeof(ch) != TYPE_DICTIONARY:
				worker_eff.append({"character_id": cid, "skill": 0, "hours": 0.0})
				continue
			var eff: float = _worker_efficiency(j, ch)
			# Diminishing returns: 1st = 1.0, 2nd = 0.7, 3rd = 0.0
			if i == 1:
				eff *= 0.7
			elif i >= 2:
				eff = 0.0
			worker_eff.append({"character_id": cid, "skill": _skill_level(j, ch), "hours": eff})
			grand_total += eff
		per_role[j] = worker_eff
	return {"worker_efficiency": per_role, "total_per_hour": grand_total, "by_role": per_role}

func _skill_level(role_id: String, ch: Dictionary) -> int:
	var skill_key: String = String(JOB_SKILL.get(role_id, ""))
	if skill_key == "":
		return 0
	var skills: Variant = ch.get("skills", {})
	if typeof(skills) != TYPE_DICTIONARY:
		return 0
	return int((skills as Dictionary).get(skill_key, 0))

func _worker_efficiency(role_id: String, ch: Dictionary) -> float:
	var skill: int = _skill_level(role_id, ch)
	# Skill 2 + good state => 1.0 / hour. Linear scaling: skill 0 -> 0.0, skill 5 -> 1.6
	var base: float = 0.0
	if skill >= 2:
		base = 1.0 + 0.2 * (skill - 2)
	else:
		base = 0.5 * skill
	# State penalty if energy < 25 or hp < 25.
	var stats: Variant = ch.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY:
		var energy: int = int((stats as Dictionary).get("energy", 100))
		var hp: int = int((stats as Dictionary).get("hp", 100))
		if energy < 25 or hp < 25:
			base *= 0.5
	return base

func to_dict() -> Dictionary:
	return {"assignments": assignments.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	assignments = {}
	for j in JOB_IDS:
		assignments[j] = []
	if typeof(d) != TYPE_DICTIONARY:
		return
	var raw: Variant = d.get("assignments", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for j in JOB_IDS:
		if (raw as Dictionary).has(j):
			var arr_v: Variant = (raw as Dictionary)[j]
			if typeof(arr_v) == TYPE_ARRAY:
				assignments[j] = (arr_v as Array).duplicate(true)