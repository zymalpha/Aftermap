class_name MorningReport extends RefCounted

## Build the day-start summary card (策划03 §2.3).
##
## Inputs:
##   - session: GameSession (refcounted)
##   - prev_day_summary: Dictionary from prior NIGHT_RESOLVE (may be empty)
##
## Output: a Dictionary with sections consumed by morning_report.md renderer:
##   {
##     "day": int,
##     "consumed": { food, water, material, parts, medical, fuel, ammo },
##     "produced": { ... same keys ... },
##     "injuries": [ { character_id, kind, severity } ],
##     "infections": [ { character_id, delta, stage } ],
##     "events": [ { id, title_zh, kind } ],
##     "relationships": [ { a, b, axis, delta } ],
##     "city_pressure": float,
##     "morale": int,
##     "weather_hint": String,
##     "summary_text": String,
##   }

const _PATH: String = "res://game/application/morning_report.gd"

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")

const CONSUMABLE_KEYS: Array[String] = [
	"food", "water", "material", "parts", "medical", "fuel", "ammo",
]

func _log(msg: String) -> void:
	push_warning("[MorningReport] " + msg)

## Build the report. Pure function: does not mutate `session`.
func build(session: RefCounted, prev_day_summary: Dictionary = {}) -> Dictionary:
	var day: int = 1
	var chars: Array = []
	var base: Dictionary = {}
	var flags: Dictionary = {}
	if session != null:
		day = int(session.clock.current_day)
		chars = session.characters
		base = session.base_state
		if typeof(base.get("flags", {})) == TYPE_DICTIONARY:
			flags = (base["flags"] as Dictionary).duplicate(true)

	var consumed: Dictionary = {}
	var produced: Dictionary = {}
	for k in CONSUMABLE_KEYS:
		consumed[k] = 0
		produced[k] = 0

	if typeof(prev_day_summary.get("consumed", null)) == TYPE_DICTIONARY:
		for k in CONSUMABLE_KEYS:
			consumed[k] = int((prev_day_summary["consumed"] as Dictionary).get(k, 0))
	if typeof(prev_day_summary.get("produced", null)) == TYPE_DICTIONARY:
		for k in CONSUMABLE_KEYS:
			produced[k] = int((prev_day_summary["produced"] as Dictionary).get(k, 0))

	var injuries: Array = []
	if typeof(prev_day_summary.get("injuries", null)) == TYPE_ARRAY:
		injuries = (prev_day_summary["injuries"] as Array).duplicate(true)

	var infections: Array = []
	if typeof(prev_day_summary.get("infections", null)) == TYPE_ARRAY:
		infections = (prev_day_summary["infections"] as Array).duplicate(true)

	var events: Array = []
	if typeof(prev_day_summary.get("events", null)) == TYPE_ARRAY:
		events = (prev_day_summary["events"] as Array).duplicate(true)

	var relationships: Array = []
	if typeof(prev_day_summary.get("relationships", null)) == TYPE_ARRAY:
		relationships = (prev_day_summary["relationships"] as Array).duplicate(true)

	var pressure: float = float(base.get("city_pressure", 0.0))
	var morale: int = int(base.get("morale", 50))

	var text: String = _compose_text(day, consumed, produced, injuries, infections, events, relationships, morale, pressure, chars.size(), flags)

	return {
		"day": day,
		"consumed": consumed,
		"produced": produced,
		"injuries": injuries,
		"infections": infections,
		"events": events,
		"relationships": relationships,
		"city_pressure": pressure,
		"morale": morale,
		"weather_hint": String(prev_day_summary.get("weather_hint", "unknown")),
		"summary_text": text,
	}

func to_dict(report: Dictionary) -> Dictionary:
	return report.duplicate(true)

func from_dict(d: Dictionary) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return build(null, {})
	return d.duplicate(true)

## Internals ----------------------------------------------------------------

func _compose_text(day: int, consumed: Dictionary, produced: Dictionary,
		injuries: Array, infections: Array, events: Array,
		rels: Array, morale: int, pressure: float,
		pop: int, flags: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Day %d 晨间报告" % day)
	lines.append("  人口: %d    士气: %d    城市压力: %.1f" % [pop, morale, pressure])
	lines.append("  昨日消耗 food=%d water=%d material=%d parts=%d medical=%d fuel=%d ammo=%d" % [
		int(consumed.get("food", 0)), int(consumed.get("water", 0)),
		int(consumed.get("material", 0)), int(consumed.get("parts", 0)),
		int(consumed.get("medical", 0)), int(consumed.get("fuel", 0)),
		int(consumed.get("ammo", 0))])
	lines.append("  昨日产出 food=%d water=%d material=%d parts=%d medical=%d fuel=%d ammo=%d" % [
		int(produced.get("food", 0)), int(produced.get("water", 0)),
		int(produced.get("material", 0)), int(produced.get("parts", 0)),
		int(produced.get("medical", 0)), int(produced.get("fuel", 0)),
		int(produced.get("ammo", 0))])
	if injuries.size() > 0:
		lines.append("  伤病 %d 例" % injuries.size())
	if infections.size() > 0:
		lines.append("  感染 %d 例" % infections.size())
	if events.size() > 0:
		lines.append("  昨日事件 %d 个" % events.size())
	if rels.size() > 0:
		lines.append("  关系变动 %d 条" % rels.size())
	if flags.size() > 0:
		lines.append("  当前旗标: %d" % flags.size())
	return "\n".join(lines)