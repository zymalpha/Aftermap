class_name Clock extends RefCounted

## Three-scale time tracker (ADR §11.4):
##   - CAMPAIGN_DAY:  integer day counter (1+)
##   - CITY_CLOCK:    minutes-of-day 0..1439 (start at 360 = 06:00)
##   - TACTICAL:      float seconds within a tactical scene

enum TimeScale {CAMPAIGN_DAY, CITY_CLOCK, TACTICAL}

const _PATH: String = "res://game/core/clock.gd"
const MINUTES_PER_DAY: int = 1440
const START_CITY_MINUTES: int = 360

var current_day: int = 1
var city_minutes: int = START_CITY_MINUTES
var tactical_seconds: float = 0.0

func _init() -> void:
	current_day = 1
	city_minutes = START_CITY_MINUTES
	tactical_seconds = 0.0

func _log(msg: String) -> void:
	push_warning("[Clock] " + msg)

## Advance time. dt interpretation depends on scale.
func tick(scale: int, dt: float) -> void:
	match scale:
		TimeScale.CAMPAIGN_DAY:
			current_day += int(dt)
		TimeScale.CITY_CLOCK:
			city_minutes = _wrap_minutes(city_minutes + int(dt))
		TimeScale.TACTICAL:
			tactical_seconds += dt
			if tactical_seconds >= 60.0:
				var advance_minutes: int = int(tactical_seconds) / 60
				tactical_seconds = fmod(tactical_seconds, 60.0)
				city_minutes = _wrap_minutes(city_minutes + advance_minutes)

func set_time_of_day(hour: int, minute: int = 0) -> void:
	var m: int = clamp(hour, 0, 23) * 60 + clamp(minute, 0, 59)
	city_minutes = _wrap_minutes(m)

func get_time_of_day_string() -> String:
	var h: int = city_minutes / 60
	var m: int = city_minutes % 60
	return "%02d:%02d" % [h, m]

func to_dict() -> Dictionary:
	return {
		"current_day": current_day,
		"city_minutes": city_minutes,
		"tactical_seconds": tactical_seconds,
	}

func from_dict(d: Dictionary) -> void:
	current_day = int(d.get("current_day", 1))
	city_minutes = int(d.get("city_minutes", START_CITY_MINUTES))
	tactical_seconds = float(d.get("tactical_seconds", 0.0))

func _wrap_minutes(m: int) -> int:
	var r: int = m % MINUTES_PER_DAY
	if r < 0:
		r += MINUTES_PER_DAY
	return r