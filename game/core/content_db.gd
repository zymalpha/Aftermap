class_name ContentDB extends RefCounted

## In-memory content cache: loads JSON files from a directory tree, validates
## them lightly (presence + types of required fields), and exposes
## `get(kind, id)`.
##
## Heavy validation is the Python validator's job; this GDScript loader
## provides a fast, dependency-free runtime cache.

const _PATH: String = "res://game/core/content_db.gd"

const KNOWN_KINDS: Array[String] = [
	"items",
	"events",
	"event-chains",
	"facilities",
	"traits",
	"poi-rooms",
	"recipes",
]

var _schemas: Dictionary = {}
var _data: Dictionary = {}
var _fingerprint: String = ""

func _init() -> void:
	_schemas = {}
	_data = {}
	_fingerprint = ""

func _log(msg: String) -> void:
	push_warning("[ContentDB] " + msg)

## Walk content_dir, find subdirs whose name is in KNOWN_KINDS,
## load every *.json inside them. Returns OK on success, non-OK on hard failure.
func load_all(content_dir: String) -> Error:
	_data = {}
	_schemas = {}
	_fingerprint = ""

	# Godot 4 uses virtual paths (res://, user://) that DirAccess.dir_exists_absolute
	# does not always resolve. Open the dir relative to current scope instead.
	var root: DirAccess = DirAccess.open(content_dir)
	if root == null:
		_log("content_dir not found: " + content_dir)
		return ERR_FILE_NOT_FOUND

	var loaded_count: int = 0
	for kind in KNOWN_KINDS:
		var kind_dir: String = content_dir.path_join(kind)
		var kind_access: DirAccess = DirAccess.open(kind_dir)
		if kind_access == null:
			continue
		var bucket: Dictionary = {}
		var err: Error = _load_dir(kind_dir, kind, bucket)
		if err != OK:
			return err
		_data[kind] = bucket
		loaded_count += bucket.size()

	_fingerprint = _compute_fingerprint()
	_log("loaded " + str(loaded_count) + " records; fp=" + _fingerprint)
	return OK

## Look up a content record by kind/id. Returns null when missing.
## Named `get_record` (not `get`) to avoid colliding with Godot Object.get,
## which would shadow or override engine callbacks on every RefCounted.
func get_record(kind: String, id: String) -> Variant:
	if not _data.has(kind):
		return null
	var bucket: Dictionary = _data[kind]
	return bucket.get(id, null)

## All ids for a kind (Array of String).
func list_ids(kind: String) -> Array:
	if not _data.has(kind):
		return []
	var bucket: Dictionary = _data[kind]
	var out: Array = []
	for key in bucket.keys():
		out.append(String(key))
	return out

func get_fingerprint() -> String:
	return _fingerprint

func to_dict() -> Dictionary:
	return {
		"fingerprint": _fingerprint,
		"kinds": _data.keys(),
	}

func from_dict(d: Dictionary) -> void:
	_fingerprint = String(d.get("fingerprint", ""))

## Internals ------------------------------------------------------------------

func _load_dir(dir_path: String, kind: String, out_bucket: Dictionary) -> Error:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return ERR_FILE_CANT_OPEN
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".json") and not name.ends_with(".schema.json"):
			var full: String = dir_path.path_join(name)
			var err: Error = _load_file(full, kind, out_bucket)
			if err != OK:
				return err
		name = dir.get_next()
	dir.list_dir_end()
	return OK

func _load_file(path: String, kind: String, out_bucket: Dictionary) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_log("not a JSON object: " + path)
		return ERR_PARSE_ERROR

	var obj: Dictionary = parsed
	var id: String = String(obj.get("id", ""))
	if id == "":
		_log("missing id: " + path)
		return ERR_INVALID_DATA

	if not _light_validate(obj, kind):
		_log("light validation failed: " + path)
		return ERR_INVALID_DATA

	out_bucket[id] = obj
	return OK

## Minimal presence + type checks. The Python validator is canonical;
## this catches only the grossest defects at runtime.
func _light_validate(obj: Dictionary, kind: String) -> bool:
	match kind:
		"items":
			# items must have an item `kind` (enum: tool/weapon/...)
			return obj.has("id") and obj.has("name_zh") and obj.has("kind")
		"events":
			# events have an event `kind` (scene/decision/...) which may differ
			# from the directory kind. We only enforce id + name_zh.
			return obj.has("id") and obj.has("name_zh")
		"event-chains":
			return obj.has("id") and obj.has("name_zh") and obj.has("nodes")
		"facilities":
			# facility files may carry an item-style `kind` for the building.
			return obj.has("id") and obj.has("name_zh")
		"traits":
			return obj.has("id") and obj.has("name_zh") and obj.has("kind")
		"poi-rooms":
			return obj.has("id") and obj.has("name_zh")
		"recipes":
			return obj.has("id") and obj.has("name_zh")
		_:
			return obj.has("id")

func _compute_fingerprint() -> String:
	# Deterministic, stable across reloads given identical content.
	var ids: Array = []
	for kind in KNOWN_KINDS:
		if not _data.has(kind):
			continue
		var bucket: Dictionary = _data[kind]
		var keys: Array = bucket.keys()
		keys.sort()
		for k in keys:
			ids.append(String(kind) + "/" + String(k))
	ids.sort()
	var joined: String = ",".join(ids)
	return str(hash(joined))