class_name Facility extends RefCounted

## A single base facility. Mirrors 策划09 §9.
##   - kind: enum (sleep/storage/kitchen/water/medical/workbench/power/radio/watch/barrier/quarantine/garden)
##   - tier: 1 or 2
##   - build_cost: { resource_material, resource_parts, fuel, ammo_9mm, water, food }
##   - daily_upkeep: same shape, consumed per day
##   - power_draw_kw: signed (+ produces, - consumes)
##   - integrity: 0..100, drops on damage, recovers on repair

const _PATH: String = "res://game/domain/base/facility.gd"

const FACILITY_KINDS: Array[String] = [
	"sleep", "storage", "kitchen", "water", "medical",
	"workbench", "power", "radio", "watch", "barrier",
	"quarantine", "garden",
]

var id: String = ""
var kind: String = "sleep"
var tier: int = 1
var build_cost: Dictionary = {}
var daily_upkeep: Dictionary = {}
var power_draw_kw: float = 0.0
var integrity: int = 100
var notes: String = ""

func _init(p_id: String = "", p_kind: String = "sleep") -> void:
	id = p_id
	kind = p_kind
	tier = 1
	build_cost = {}
	daily_upkeep = {}
	power_draw_kw = 0.0
	integrity = 100

func _log(msg: String) -> void:
	push_warning("[Facility:" + id + "] " + msg)

static func from_content(record: Dictionary) -> RefCounted:
	var f: RefCounted = (load("res://game/domain/base/facility.gd") as GDScript).new(String(record.get("id", "")), String(record.get("kind", "sleep")))
	f.tier = clampi(int(record.get("tier", 1)), 1, 2)
	var bc: Variant = record.get("build_cost", {})
	if typeof(bc) == TYPE_DICTIONARY:
		f.build_cost = (bc as Dictionary).duplicate(true)
	var du: Variant = record.get("daily_upkeep", {})
	if typeof(du) == TYPE_DICTIONARY:
		f.daily_upkeep = (du as Dictionary).duplicate(true)
	f.power_draw_kw = float(record.get("power_draw_kw", 0.0))
	f.notes = String(record.get("notes", ""))
	return f

func level_up() -> bool:
	if tier >= 2:
		return false
	tier += 1
	return true

func damage(amount: int) -> int:
	if amount <= 0:
		return integrity
	integrity = clampi(integrity - amount, 0, 100)
	return integrity

func repair(amount: int) -> int:
	if amount <= 0:
		return integrity
	integrity = clampi(integrity + amount, 0, 100)
	return integrity

func total_upkeep(resource_key: String) -> int:
	return int(daily_upkeep.get(resource_key, 0))

func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"tier": tier,
		"build_cost": build_cost.duplicate(true),
		"daily_upkeep": daily_upkeep.duplicate(true),
		"power_draw_kw": power_draw_kw,
		"integrity": integrity,
	}

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	kind = String(d.get("kind", kind))
	tier = clampi(int(d.get("tier", tier)), 1, 2)
	var bc: Variant = d.get("build_cost", {})
	if typeof(bc) == TYPE_DICTIONARY:
		build_cost = (bc as Dictionary).duplicate(true)
	var du: Variant = d.get("daily_upkeep", {})
	if typeof(du) == TYPE_DICTIONARY:
		daily_upkeep = (du as Dictionary).duplicate(true)
	power_draw_kw = float(d.get("power_draw_kw", power_draw_kw))
	integrity = clampi(int(d.get("integrity", integrity)), 0, 100)