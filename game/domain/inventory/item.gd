class_name ItemDef extends RefCounted

## Definition of a single item stack. Lightweight runtime view of a
## content/items record. Mirrors content/items/<id>.json fields
## plus per-stack qty.

const _PATH: String = "res://game/domain/inventory/item.gd"

var id: String = ""
var name_zh: String = ""
var name_en: String = ""
var kind: String = "tool"
var weight_kg: float = 0.0
var stack_size: int = 1
var tags: Array = []
var value_tier: int = 1

func _init(p_id: String = "") -> void:
	id = p_id
	tags = []

func _log(msg: String) -> void:
	push_warning("[ItemDef:" + id + "] " + msg)

static func from_content(record: Dictionary) -> RefCounted:
	var it: RefCounted = (load("res://game/domain/inventory/item.gd") as GDScript).new()
	it.id = String(record.get("id", ""))
	it.name_zh = String(record.get("name_zh", ""))
	it.name_en = String(record.get("name_en", ""))
	it.kind = String(record.get("kind", "tool"))
	it.weight_kg = float(record.get("weight_kg", 0.0))
	it.stack_size = int(record.get("stack_size", 1))
	var tags_raw: Variant = record.get("tags", [])
	if typeof(tags_raw) == TYPE_ARRAY:
		it.tags = (tags_raw as Array).duplicate()
	it.value_tier = int(record.get("value_tier", 1))
	return it

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_zh": name_zh,
		"kind": kind,
		"weight_kg": weight_kg,
		"stack_size": stack_size,
		"tags": tags.duplicate(true),
		"value_tier": value_tier,
	}