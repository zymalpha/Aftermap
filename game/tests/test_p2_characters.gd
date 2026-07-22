extends SceneTree

## Module B smoke: Character + Relationship + Memory + Trait data.
## Exits with code 0 on full success, 1 on any failure.

const CharacterScript: GDScript = preload("res://game/domain/survivors/character.gd")
const RelationshipScript: GDScript = preload("res://game/domain/survivors/relationship.gd")
const MemoryScript: GDScript = preload("res://game/domain/survivors/memory.gd")
const ContentDBScript: GDScript = preload("res://game/core/content_db.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_characters start ===")
	_test_character_defaults()
	_test_character_apply_injury_clamp()
	_test_character_apply_infection_clamp()
	_test_character_consume_resource()
	_test_character_modify_relationship_clamp()
	_test_character_add_memory_enforces_cap()
	_test_character_validate_invariants()
	_test_character_to_from_dict()
	_test_relationship_modify_axis()
	_test_relationship_add_tag()
	_test_relationship_reconcile()
	_test_memory_personal_compression()
	_test_memory_relationship_fifo()
	_test_memory_to_from_dict()
	_test_traits_loaded_count()
	print("=== test_p2_characters result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  " + label)
	else:
		_fail_count += 1
		printerr("  FAIL  " + label)

func _mk_char(id: String, name_zh: String) -> RefCounted:
	return CharacterScript.new(id, name_zh)

func _test_character_defaults() -> void:
	print("[1] Character defaults")
	var c: RefCounted = _mk_char("c_alex", "Alex")
	_expect(c.id == "c_alex", "id set")
	_expect(c.stats["hp"] == 100, "hp default 100")
	_expect(c.stats["infection"] == 0, "infection default 0")
	_expect(c.skills["combat"] == 1, "skills default 1")
	_expect(c.stats["morale"] == 50, "morale default 50")

func _test_character_apply_injury_clamp() -> void:
	print("[2] apply_injury clamps to 0")
	var c: RefCounted = _mk_char("c1", "C1")
	c.apply_injury(50)
	_expect(c.stats["hp"] == 50, "hp 50 after -50")
	c.apply_injury(999)
	_expect(c.stats["hp"] == 0, "hp clamped to 0")

func _test_character_apply_infection_clamp() -> void:
	print("[3] apply_infection clamps to 100")
	var c: RefCounted = _mk_char("c1", "C1")
	c.apply_infection(30)
	_expect(c.stats["infection"] == 30, "inf 30")
	c.apply_infection(200)
	_expect(c.stats["infection"] == 100, "inf clamped to 100")

func _test_character_consume_resource() -> void:
	print("[4] consume_resource")
	var c: RefCounted = _mk_char("c1", "C1")
	c.consume_resource("hunger", 20)
	_expect(c.stats["hunger"] == 30, "hunger 50-20=30")
	c.consume_resource("energy", 999)
	_expect(c.stats["energy"] == 0, "energy clamped 0")

func _test_character_modify_relationship_clamp() -> void:
	print("[5] modify_relationship clamps to ±100")
	var c: RefCounted = _mk_char("c_alex", "Alex")
	c.modify_relationship("c_bo", "trust", 50)
	_expect(c.relationships["c_bo"]["trust"] == 50, "trust +50 -> 50")
	c.modify_relationship("c_bo", "trust", 200)
	_expect(c.relationships["c_bo"]["trust"] == 100, "trust clamped 100")
	c.modify_relationship("c_bo", "intimacy", -999)
	_expect(c.relationships["c_bo"]["intimacy"] == -100, "intimacy clamped -100")
	c.modify_relationship("c_alex", "trust", 50)  # self -> no-op
	_expect(not c.relationships.has("c_alex"), "no self relationship")

func _test_character_add_memory_enforces_cap() -> void:
	print("[6] add_memory enforces 5-cap with compression")
	var c: RefCounted = _mk_char("c1", "C1")
	for i in range(8):
		c.add_memory({"day": i + 1, "kind": "scene", "summary_zh": "Day %d event" % (i + 1)})
	_expect(c.memories.size() <= 5, "memories size <= 5 (got %d)" % c.memories.size())
	var has_compressed: bool = false
	for m in c.memories:
		if typeof(m) == TYPE_DICTIONARY and String(m.get("kind", "")) == "compressed":
			has_compressed = true
			break
	_expect(has_compressed, "compression merged entries")

func _test_character_validate_invariants() -> void:
	print("[7] validate_invariants returns []")
	var c: RefCounted = _mk_char("c1", "C1")
	_expect(c.validate_invariants().size() == 0, "fresh char invariants clean")
	c.stats["hp"] = 200
	_expect(c.validate_invariants().size() > 0, "violation caught")

func _test_character_to_from_dict() -> void:
	print("[8] Character to/from_dict round-trip")
	var c: RefCounted = _mk_char("c_alex", "Alex")
	c.apply_injury(10)
	c.modify_relationship("c_bo", "trust", 7)
	c.add_memory({"day": 1, "kind": "scene", "summary_zh": "saw stranger"})
	var d: Dictionary = c.to_dict()
	var c2: RefCounted = CharacterScript.new()
	c2.from_dict(d)
	_expect(c2.id == "c_alex", "id preserved")
	_expect(c2.stats["hp"] == 90, "hp preserved")
	_expect(c2.relationships["c_bo"]["trust"] == 7, "trust preserved")
	_expect(c2.memories.size() == 1, "memory preserved")

func _test_relationship_modify_axis() -> void:
	print("[9] Relationship.modify")
	var rs: RefCounted = RelationshipScript.new()
	rs.modify("c_alex", "c_bo", "trust", 25)
	_expect(rs.get_axis("c_alex", "c_bo", "trust") == 25, "trust 25")
	_expect(rs.get_axis("c_bo", "c_alex", "trust") == 25, "bidirectional view same value")
	rs.modify("c_alex", "c_bo", "intimacy", 200)
	_expect(rs.get_axis("c_alex", "c_bo", "intimacy") == 100, "intimacy clamped 100")

func _test_relationship_add_tag() -> void:
	print("[10] Relationship.add_tag")
	var rs: RefCounted = RelationshipScript.new()
	rs.add_tag("c_a", "c_b", "friend")
	rs.add_tag("c_a", "c_b", "friend")  # idempotent
	var pair: Dictionary = rs.get_pair("c_a", "c_b")
	_expect((pair["canonical"]["tags"] as Array).size() == 1, "tag added once")
	rs.add_tag("c_a", "c_b", "stranger")  # unverified tag accepted silently? actually rejected
	# RELATIONSHIP_TAGS has "stranger" so this is accepted
	_expect((pair["canonical"]["tags"] as Array).size() == 2, "second valid tag added")

func _test_relationship_reconcile() -> void:
	print("[11] Relationship.reconcile")
	var rs: RefCounted = RelationshipScript.new()
	rs.modify("c_a", "c_b", "trust", 30)
	var n: int = rs.reconcile()
	_expect(n == 1, "1 pair reconciled")
	_expect(rs.get_axis("c_a", "c_b", "trust") == 30, "value preserved")

func _test_memory_personal_compression() -> void:
	print("[12] MemoryStore.add_personal compression")
	var m: RefCounted = MemoryScript.new()
	for i in range(7):
		m.add_personal({"day": i, "kind": "scene", "summary_zh": "M%d" % i})
	_expect(m.count_personal() <= 5, "personal size <= 5 (got %d)" % m.count_personal())
	var found_compressed: bool = false
	for e in m.personal:
		if typeof(e) == TYPE_DICTIONARY and String(e.get("kind", "")) == "compressed":
			found_compressed = true
			break
	_expect(found_compressed, "compression occurred")

func _test_memory_relationship_fifo() -> void:
	print("[13] MemoryStore.add_relationship FIFO")
	var m: RefCounted = MemoryScript.new()
	for i in range(6):
		m.add_relationship({"day": i, "other_id": "c_b", "kind": "bond", "summary_zh": "R%d" % i})
	_expect(m.count_relationship() <= 3, "relationship size <= 3 (got %d)" % m.count_relationship())
	_expect(m.relationship[0]["summary_zh"] == "R3", "FIFO drops oldest (R3 now at head)")

func _test_memory_to_from_dict() -> void:
	print("[14] MemoryStore round-trip")
	var m: RefCounted = MemoryScript.new()
	m.add_personal({"day": 1, "kind": "scene", "summary_zh": "intro"})
	var d: Dictionary = m.to_dict()
	var m2: RefCounted = MemoryScript.new()
	m2.from_dict(d)
	_expect(m2.count_personal() == 1, "personal restored")
	_expect(m2.personal[0]["summary_zh"] == "intro", "summary restored")

func _test_traits_loaded_count() -> void:
	print("[15] traits/ loaded")
	var db: RefCounted = ContentDBScript.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("traits")
	_expect(ids.size() >= 6, "loaded >= 6 traits (got %d)" % ids.size())
	_expect(ids.has("trt_loner"), "trt_loner present")
	_expect(ids.has("trt_empath"), "trt_empath present")
	_expect(ids.has("trt_value_no_abandon"), "trt_value_no_abandon present")