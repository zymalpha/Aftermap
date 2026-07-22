class_name MemoryStore extends RefCounted

## Per-character memory store. Holds two kinds of memory:
##   personal: up to 5 entries (per 策划04 §4)
##   relationship: up to 3 entries about specific relationships
## When a new entry arrives over the cap, the oldest is compressed:
## the two oldest personal entries collapse into one "compressed" entry
## whose summary_zh concatenates both. This is the §4 compression algo.

const _PATH: String = "res://game/domain/survivors/memory.gd"

const PERSONAL_LIMIT: int = 5
const RELATIONSHIP_LIMIT: int = 3

var personal: Array = []
var relationship: Array = []  # entries: { day, other_id, kind, summary_zh, payload }

func _log(msg: String) -> void:
	push_warning("[MemoryStore] " + msg)

func _normalize(entry: Dictionary) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var e: Dictionary = entry.duplicate(true)
	e["day"] = int(e.get("day", 0))
	e["kind"] = String(e.get("kind", ""))
	e["summary_zh"] = String(e.get("summary_zh", ""))
	if not e.has("payload"):
		e["payload"] = {}
	return e

## Add a personal memory; enforce 5-entry cap with §4 compression.
func add_personal(entry: Dictionary) -> int:
	var e: Dictionary = _normalize(entry)
	if e.is_empty():
		return personal.size()
	personal.append(e)
	while personal.size() > PERSONAL_LIMIT:
		_compress_personal()
	return personal.size()

func _compress_personal() -> void:
	if personal.size() < 2:
		if personal.size() == 1:
			personal.remove_at(0)
		return
	var a: Dictionary = personal[0]
	var b: Dictionary = personal[1]
	var combined: Dictionary = {
		"day": int(a.get("day", 0)),
		"kind": "compressed",
		"summary_zh": "%s + %s" % [String(a.get("summary_zh", "")), String(b.get("summary_zh", ""))],
		"payload": {"merged": [int(a.get("day", 0)), int(b.get("day", 0))]},
	}
	personal.remove_at(0)
	personal.remove_at(0)
	personal.insert(0, combined)

## Add a relationship memory; enforce 3-entry cap with FIFO eviction.
func add_relationship(entry: Dictionary) -> int:
	var e: Dictionary = _normalize(entry)
	if e.is_empty():
		return relationship.size()
	relationship.append(e)
	while relationship.size() > RELATIONSHIP_LIMIT:
		relationship.remove_at(0)
	return relationship.size()

func count_personal() -> int:
	return personal.size()

func count_relationship() -> int:
	return relationship.size()

func to_dict() -> Dictionary:
	return {
		"personal": personal.duplicate(true),
		"relationship": relationship.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	personal = []
	relationship = []
	if typeof(d) != TYPE_DICTIONARY:
		return
	var p: Variant = d.get("personal", [])
	if typeof(p) == TYPE_ARRAY:
		personal = (p as Array).duplicate(true)
	var r: Variant = d.get("relationship", [])
	if typeof(r) == TYPE_ARRAY:
		relationship = (r as Array).duplicate(true)