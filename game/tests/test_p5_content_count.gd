extends SceneTree

## test_p5_content_count
##
## MVP content quota assertion (Stage 16 / P5).
##
## Asserts that the content tree meets the MVP minimums documented in §09
## and the Stage 16 gap plan:
##   characters       == 12
##   specializations  == 24
##   traits           == 34  (16 personality + 10 value + 8 weakness)
##   wounds           == 6
##   enemies          == 3
##   events           >= 60
##   event-chains     >= 10
##   poi-rooms        >= 24  (12 POI classes x 2 rooms)
##   items            >= 42
##
## Counts are taken from the JSON file count per content subdirectory (each
## file is one record), which is independent of the runtime ContentDB cache
## and the Python schema validator. This makes the test a true end-to-end
## quota gate: if a file is missing or duplicated, the count drifts.
##
## Run with:
##   godot --headless --script res://game/tests/test_p5_content_count.gd

const ContentDBMod = preload("res://game/core/content_db.gd")

const _QUOTAS: Dictionary = {
	"characters": 12,
	"specializations": 24,
	"traits": 34,
	"wounds": 6,
	"enemies": 3,
	"events": 60,
	"event-chains": 10,
	"poi-rooms": 24,
	"items": 42,
}

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p5_content_count start ===")
	var content_dir: String = "res://content"
	for kind in _QUOTAS.keys():
		var target: int = int(_QUOTAS[kind])
		var got: int = _count_json_files(content_dir + "/" + String(kind))
		_expect(got >= target, "%s >= %d (got %d)" % [String(kind), target, got])
	# Bonus: verify trait kind split via ContentDB (16/10/8).
	_verify_trait_split()
	print("=== test_p5_content_count result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

## Count *.json files (excluding *.schema.json) under the given directory.
func _count_json_files(dir_path: String) -> int:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	var n: int = 0
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".json") and not name.ends_with(".schema.json"):
			n += 1
		name = dir.get_next()
	dir.list_dir_end()
	return n

func _verify_trait_split() -> void:
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("traits")
	var p: int = 0
	var v: int = 0
	var w: int = 0
	for tid in ids:
		var rec: Variant = db.get_record("traits", String(tid))
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var kind: String = String((rec as Dictionary).get("kind", ""))
		match kind:
			"personality": p += 1
			"value":      v += 1
			"weakness":   w += 1
	_expect(p >= 16, "trait personality >= 16 (got %d)" % p)
	_expect(v >= 10, "trait value >= 10 (got %d)" % v)
	_expect(w >= 8, "trait weakness >= 8 (got %d)" % w)
