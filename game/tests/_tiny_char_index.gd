extends RefCounted

## Tiny test helper exposing a get_character(id) callable for JobBoard.efficiency_snapshot.
## Not registered as class_name to avoid clutter.

var _dict: Dictionary = {}

func _init() -> void:
	_dict = {}

func set_dict(d: Dictionary) -> void:
	_dict = d.duplicate(true)

func get_character(id: String) -> Variant:
	if not _dict.has(id):
		return null
	return _dict[id]