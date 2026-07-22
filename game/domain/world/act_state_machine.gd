class_name ActStateMachine extends RefCounted

## 4 幕主线状态机（策划 02 §8 + 策划 12 §11）
##
## 第一幕：建立坐标 (day 1-7)    — 我们能否在这里活过一周？
## 第二幕：地图出现裂缝 (day 8-18) — 我们愿意为谁承担风险？
## 第三幕：离城窗口 (day 19-27)   — 什么值得被带到下一座城？
## 第四幕：最后一夜 (day 28-30)   — 离开是否意味着背叛家园？
##
## 字段：
##   current_act: int (1..4)
##   transitions_log: Array of { from, to, day }
##
## 方法：
##   current_act(day) -> int          (1..4)
##   act_name(act) -> String
##   core_question(act) -> String
##   daily_tick(day) -> bool          返回是否进入下一幕

const _PATH: String = "res://game/domain/world/act_state_machine.gd"

## Act day ranges (inclusive on both ends).
const ACT_DAY_RANGES: Array = [
	{"act": 1, "start": 1,  "end": 7},
	{"act": 2, "start": 8,  "end": 18},
	{"act": 3, "start": 19, "end": 27},
	{"act": 4, "start": 28, "end": 30},
]

const ACT_NAMES: Array[String] = [
	"建立坐标",
	"地图出现裂缝",
	"离城窗口",
	"最后一夜",
]

const CORE_QUESTIONS: Array[String] = [
	"我们能否在这里活过一周？",
	"我们愿意为谁承担风险？",
	"什么值得被带到下一座城？",
	"离开是否意味着背叛家园？",
]

var current_act: int = 1
var transitions_log: Array = []  # { from, to, day }

func _init() -> void:
	current_act = 1
	transitions_log = []

func _log(msg: String) -> void:
	push_warning("[ActStateMachine] " + msg)

## Map a day (>=1) to its act index (1..4). Day < 1 -> 0 (invalid sentinel).
static func act_for_day(day: int) -> int:
	if day < 1:
		return 0
	for spec in ACT_DAY_RANGES:
		var start_d: int = int(spec["start"])
		var end_d: int = int(spec["end"])
		if day >= start_d and day <= end_d:
			return int(spec["act"])
	# Beyond the last act: clamp to act 4.
	return int(ACT_DAY_RANGES[ACT_DAY_RANGES.size() - 1]["act"])

## What act the campaign is currently in for the given day. Updates
## current_act as a side effect when called from daily_tick(); this
## pure form does not mutate state.
func act_for_current_day(day: int) -> int:
	return act_for_day(day)

## Act name (1..4). Returns "" for unknown acts.
static func name_of_act(act: int) -> String:
	if act < 1 or act > ACT_NAMES.size():
		return ""
	return ACT_NAMES[act - 1]

func act_name(act: int) -> String:
	return name_of_act(act)

static func core_question_of(act: int) -> String:
	if act < 1 or act > CORE_QUESTIONS.size():
		return ""
	return CORE_QUESTIONS[act - 1]

func core_question(act: int) -> String:
	return core_question_of(act)

## Roll the campaign day forward. Returns true iff the act changed.
func daily_tick(day: int) -> bool:
	var next: int = act_for_day(day)
	if next == 0:
		return false
	if next != current_act:
		var from: int = current_act
		current_act = next
		transitions_log.append({
			"from": from,
			"to": next,
			"day": day,
		})
		return true
	return false

## Description for UI / morning report.
func describe() -> Dictionary:
	return {
		"current_act": current_act,
		"current_act_name": act_name(current_act),
		"core_question": core_question(current_act),
		"transitions": transitions_log.size(),
	}

func to_dict() -> Dictionary:
	return {
		"current_act": current_act,
		"transitions_log": transitions_log.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	current_act = clampi(int(d.get("current_act", 1)), 1, ACT_DAY_RANGES.size())
	transitions_log = []
	var raw: Variant = d.get("transitions_log", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) == TYPE_DICTIONARY:
				transitions_log.append((entry as Dictionary).duplicate(true))