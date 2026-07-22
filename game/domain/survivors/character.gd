class_name Character extends RefCounted

## Single survivor. Mirrors 策划04 §3 baseline.
##
## Fields:
##   id: String                       (safe_id ASCII)
##   display_name_zh: String
##   skills: { combat, medical, engineering, search, social } (0..5)
##   stats:  { hp, hunger, energy, morale, stress, infection } (0..100)
##   traits: { personalities: [String], values: [String], weaknesses: [String] }
##   relationships: { <other_id>: { trust:int(-100..100), intimacy:int(-100..100), tags: [String] } }
##   memories: [ { day, kind, summary_zh, payload } ]   (cap = 5 personal)
##   job: String                      (cook / water / ... / "" = idle)
##
## Methods clamp all writes to safe ranges.

const _PATH: String = "res://game/domain/survivors/character.gd"

const SKILL_KEYS: Array[String] = ["combat", "medical", "engineering", "search", "social"]
const STAT_KEYS: Array[String] = ["hp", "hunger", "energy", "morale", "stress", "infection"]

const PERSONALITY_LIMIT: int = 2
const VALUE_LIMIT: int = 1
const WEAKNESS_LIMIT: int = 1
const PERSONAL_MEMORY_LIMIT: int = 5
const RELATIONSHIP_MEMORY_LIMIT: int = 3

var id: String = ""
var display_name_zh: String = ""
var skills: Dictionary = {}
var stats: Dictionary = {}
var traits: Dictionary = {}
var relationships: Dictionary = {}
var memories: Array = []
var job: String = ""

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	display_name_zh = p_name
	skills = _default_skills()
	stats = _default_stats()
	traits = {"personalities": [], "values": [], "weaknesses": []}
	relationships = {}
	memories = []
	job = ""

func _log(msg: String) -> void:
	push_warning("[Character:" + id + "] " + msg)

func _default_skills() -> Dictionary:
	var d: Dictionary = {}
	for k in SKILL_KEYS:
		d[k] = 1
	return d

func _default_stats() -> Dictionary:
	return {
		"hp": 100,
		"hunger": 50,
		"energy": 70,
		"morale": 50,
		"stress": 10,
		"infection": 0,
	}

## Mutators (all clamp to valid ranges) -------------------------------------

func apply_injury(amount: int) -> int:
	if amount <= 0:
		return int(stats.get("hp", 0))
	var new_hp: int = clampi(int(stats.get("hp", 0)) - amount, 0, 100)
	stats["hp"] = new_hp
	return new_hp

func apply_infection(amount: int) -> int:
	if amount <= 0:
		return int(stats.get("infection", 0))
	var new_inf: int = clampi(int(stats.get("infection", 0)) + amount, 0, 100)
	stats["infection"] = new_inf
	return new_inf

func heal(amount: int) -> int:
	if amount <= 0:
		return int(stats.get("hp", 0))
	var new_hp: int = clampi(int(stats.get("hp", 0)) + amount, 0, 100)
	stats["hp"] = new_hp
	return new_hp

func consume_resource(kind: String, amount: int) -> int:
	if amount <= 0:
		return int(stats.get(kind, 0))
	if kind == "hunger":
		var nh: int = clampi(int(stats.get("hunger", 0)) - amount, 0, 100)
		stats["hunger"] = nh
		return nh
	if kind == "energy":
		var ne: int = clampi(int(stats.get("energy", 0)) - amount, 0, 100)
		stats["energy"] = ne
		return ne
	if kind == "stress":
		var ns: int = clampi(int(stats.get("stress", 0)) - amount, 0, 100)
		stats["stress"] = ns
		return ns
	return int(stats.get(kind, 0))

func modify_relationship(other_id: String, axis: String, amount: int) -> int:
	if other_id == "" or other_id == id:
		return 0
	if not relationships.has(other_id):
		relationships[other_id] = {"trust": 0, "intimacy": 0, "tags": []}
	var rel: Dictionary = relationships[other_id]
	if axis == "trust":
		var nt: int = clampi(int(rel.get("trust", 0)) + amount, -100, 100)
		rel["trust"] = nt
		return nt
	if axis == "intimacy":
		var ni: int = clampi(int(rel.get("intimacy", 0)) + amount, -100, 100)
		rel["intimacy"] = ni
		return ni
	return 0

func tag_relationship(other_id: String, tag: String) -> void:
	if other_id == "" or tag == "":
		return
	if not relationships.has(other_id):
		relationships[other_id] = {"trust": 0, "intimacy": 0, "tags": []}
	var rel: Dictionary = relationships[other_id]
	if not (rel["tags"] as Array).has(tag):
		(rel["tags"] as Array).append(tag)

## Memories ----------------------------------------------------------------

func add_memory(mem: Dictionary) -> int:
	if typeof(mem) != TYPE_DICTIONARY:
		return memories.size()
	# Enforce cap by compressing oldest entry when over limit.
	if memories.size() >= PERSONAL_MEMORY_LIMIT:
		_compress_oldest_memory()
	mem["day"] = int(mem.get("day", 0))
	mem["kind"] = String(mem.get("kind", ""))
	mem["summary_zh"] = String(mem.get("summary_zh", ""))
	if not mem.has("payload"):
		mem["payload"] = {}
	memories.append(mem)
	return memories.size()

func _compress_oldest_memory() -> void:
	# Replace the oldest two with a single summary entry (§04 §4).
	if memories.size() < 2:
		return
	var a: Dictionary = memories[0]
	var b: Dictionary = memories[1]
	var combined: Dictionary = {
		"day": int(a.get("day", 0)),
		"kind": "compressed",
		"summary_zh": "%s + %s" % [String(a.get("summary_zh", "")), String(b.get("summary_zh", ""))],
		"payload": {
			"merged_ids": [String(a.get("id", "?")), String(b.get("id", "?"))],
		},
	}
	memories.remove_at(0)
	memories.remove_at(0)
	memories.insert(0, combined)

## Serialisation ------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name_zh": display_name_zh,
		"skills": skills.duplicate(true),
		"stats": stats.duplicate(true),
		"traits": traits.duplicate(true),
		"relationships": relationships.duplicate(true),
		"memories": memories.duplicate(true),
		"job": job,
	}

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	display_name_zh = String(d.get("display_name_zh", display_name_zh))
	var sk: Variant = d.get("skills", {})
	if typeof(sk) == TYPE_DICTIONARY:
		skills = _default_skills()
		for k in (sk as Dictionary).keys():
			skills[String(k)] = clampi(int((sk as Dictionary)[k]), 0, 5)
	var st: Variant = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		stats = _default_stats()
		for k in (st as Dictionary).keys():
			stats[String(k)] = clampi(int((st as Dictionary)[k]), 0, 100)
	var tr: Variant = d.get("traits", {})
	if typeof(tr) == TYPE_DICTIONARY:
		traits = {
			"personalities": (tr as Dictionary).get("personalities", []),
			"values": (tr as Dictionary).get("values", []),
			"weaknesses": (tr as Dictionary).get("weaknesses", []),
		}
	var rel: Variant = d.get("relationships", {})
	if typeof(rel) == TYPE_DICTIONARY:
		relationships = (rel as Dictionary).duplicate(true)
	var mem: Variant = d.get("memories", [])
	if typeof(mem) == TYPE_ARRAY:
		memories = (mem as Array).duplicate(true)
	job = String(d.get("job", ""))

func validate_invariants() -> Array:
	var errs: Array = []
	for k in STAT_KEYS:
		var v: int = int(stats.get(k, 0))
		if v < 0 or v > 100:
			errs.append("stat %s out of range: %d" % [k, v])
	for k in SKILL_KEYS:
		var v2: int = int(skills.get(k, 0))
		if v2 < 0 or v2 > 5:
			errs.append("skill %s out of range: %d" % [k, v2])
	return errs