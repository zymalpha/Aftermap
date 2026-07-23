extends RefCounted

## Test shim for SceneRouter. Records goto() calls instead of switching
## scenes. Lets us drive GameApp without needing a live SceneTree.

var tree: SceneTree = null
var goto_calls: Array = []  # Array of {scene: String, payload: Dictionary}

func goto(scene_name: String, payload: Dictionary = {}) -> void:
	goto_calls.append({"scene": scene_name, "payload": payload.duplicate(true)})

func get_current_scene() -> Node:
	return null

func last_scene() -> String:
	if goto_calls.is_empty():
		return ""
	return String(goto_calls[goto_calls.size() - 1]["scene"])

func call_count() -> int:
	return goto_calls.size()