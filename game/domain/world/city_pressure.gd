class_name CityPressure extends RefCounted

## 城市压力子系统（策划 03 §3.4 + 策划 09 §2）
##
## 长期压力值 0..100，单调递增。定义 5 个阈值，每个阈值对应一个城市
## 状态名称与一组游戏行为变化：
##   0..24   残余秩序（资源正常）
##   25..49  争夺（资源衰减、感染者迁移增加）
##   50..74  崩解（夜间威胁提高）
##   75..89  撤离期（迁徙事件集中）
##   90..100 封城（每日严重危机）
##
## daily_tick(day, events_today, rng) 推算该天结束后的压力增量：
##   1) 每日基础增长 = 1 + floor(day / 10)
##   2) 额外增长 = 未处理的大型威胁 + 高噪声行动 + 势力冲突 + 火灾
##   3) 缓解 = 完成公共设施目标 + 清理关键通路 + 势力协作
##   4) 净变化 = max(+1, min(+8, base + extra - relief))
##
## 字段：
##   value: float (0..100, 整数化存储)
##   threshold_index: int (0..4)
##   history: Array (每天净变化记录)
##
## 方法：
##   daily_tick(day, events_today, rng) -> float   返回该天净变化
##   threshold_index(pressure) -> int              返回 0..4
##   threshold_name(pressure) -> String
##   to_dict() / from_dict(d)

const _PATH: String = "res://game/domain/world/city_pressure.gd"

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100

## Threshold breakpoints: [0,25,50,75,90]
const THRESHOLDS: Array[int] = [0, 25, 50, 75, 90]

const THRESHOLD_NAMES: Array[String] = [
	"残余秩序",
	"争夺",
	"崩解",
	"撤离期",
	"封城",
]

## Daily growth bounds (策划 03 §3.4).
const MIN_DAILY_DELTA: int = 1
const MAX_DAILY_DELTA: int = 8

var value: int = 0
var history: Array = []  # Array of {day, delta, source_count}

func _init(p_value: int = 0) -> void:
	value = clampi(p_value, MIN_VALUE, MAX_VALUE)
	history = []

func _log(msg: String) -> void:
	push_warning("[CityPressure] " + msg)

## Compute the daily growth contribution from one event category
## (e.g. "untreated_threats", "loud_actions", "faction_clash", "fire",
## "public_facility", "key_route_clear", "faction_cooperation").
## Each entry contributes +1 to delta; relief entries subtract -1.
## The list itself may be empty (no extra effect).
func _extra_from_events(events_today: Array) -> int:
	var extra: int = 0
	for ev in events_today:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var category: String = String(ev.get("category", ""))
		match category:
			"untreated_threat", "loud_action", "faction_clash", "fire":
				extra += 1
			"public_facility", "key_route_clear", "faction_cooperation":
				extra -= 1
			_:
				pass
	return extra

## Run one day's pressure evolution. Returns the delta actually applied.
## rng is currently unused (deterministic formula), but kept in the
## signature so callers may plug in stochastic modifiers later.
func daily_tick(day: int, events_today: Array = [], rng: RefCounted = null) -> float:
	var base: int = 1 + int(floor(float(day) / 10.0))
	var extra: int = _extra_from_events(events_today)
	var raw: int = base + extra
	var delta: int = clampi(raw, MIN_DAILY_DELTA, MAX_DAILY_DELTA)
	# Only relax back to at most current; the brief says monotonic
	# (玩家可以拖慢但不能永久逆转城市压力). Even negative extras
	# are floored at +1 to enforce the minimum growth rate.
	if delta < MIN_DAILY_DELTA:
		delta = MIN_DAILY_DELTA
	var before: int = value
	value = clampi(before + delta, MIN_VALUE, MAX_VALUE)
	history.append({
		"day": day,
		"delta": value - before,
		"source_count": events_today.size(),
	})
	return float(value - before)

## 0..4 threshold index from the current (or supplied) pressure.
static func threshold_index_of(pressure: int) -> int:
	if pressure < 25:
		return 0
	if pressure < 50:
		return 1
	if pressure < 75:
		return 2
	if pressure < 90:
		return 3
	return 4

func threshold_index() -> int:
	return threshold_index_of(value)

## Threshold name for the current (or supplied) pressure.
static func threshold_name_of(pressure: int) -> String:
	var idx: int = threshold_index_of(pressure)
	if idx < 0 or idx >= THRESHOLD_NAMES.size():
		return THRESHOLD_NAMES[0]
	return THRESHOLD_NAMES[idx]

func threshold_name() -> String:
	return threshold_name_of(value)

## Convenience: human-readable breakdown for UI / morning report.
func describe() -> Dictionary:
	return {
		"value": value,
		"threshold_index": threshold_index(),
		"threshold_name": threshold_name(),
		"history_size": history.size(),
	}

func to_dict() -> Dictionary:
	return {
		"value": value,
		"history": history.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	value = clampi(int(d.get("value", 0)), MIN_VALUE, MAX_VALUE)
	history = []
	var raw: Variant = d.get("history", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) == TYPE_DICTIONARY:
				history.append((entry as Dictionary).duplicate(true))