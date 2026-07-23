extends RefCounted
class_name SceneRouter

## Loads and switches between scene files in res://game/presentation/scenes/.
##
## On every goto:
##   1. Disconnect signals from the previous scene (to avoid leaks).
##   2. Replace the running scene via tree.change_scene_to_packed().
##   3. After the new scene is installed, connect its signals to the
##      GameApp and apply any pending payload (e.g. set_morning_report
##      payload on the morning_report scene).
##
## Note: change_scene_to_packed() cannot be called from within a
## _ready() callback (Godot reports "Parent node is busy adding/
## removing children"). The router defers the actual scene switch
## to the next idle frame via call_deferred().

const _PATH: String = "res://game/application/scene_router.gd"

const SCENES_DIR: String = "res://game/presentation/scenes/"

var tree: SceneTree = null
var current_scene: Node = null
var _packed_cache: Dictionary = {}

# Deferred switch state.
var _pending_scene: String = ""
var _pending_payload: Dictionary = {}

func _log(msg: String) -> void:
	push_warning("[SceneRouter] " + msg)

## Switch to a named scene with optional payload.
## scene_name: file basename (e.g. "main_menu", "morning_report").
## payload: a Dictionary applied via set_* methods on the scene script.
func goto(scene_name: String, payload: Dictionary = {}) -> void:
	if tree == null:
		_log("goto: tree not set")
		return

	# If we're already inside a tree mutation (e.g. called from
	# _ready), defer the switch to the next idle frame.
	if _pending_scene != "":
		_log("goto: already pending scene '%s'; replacing with '%s'" % [_pending_scene, scene_name])
	_pending_scene = scene_name
	_pending_payload = payload.duplicate(true)
	tree.process_frame.connect(_do_pending_goto, CONNECT_ONE_SHOT)

## Process the deferred goto. Runs on the next idle frame after the
## caller (typically _ready) has finished mutating the tree.
func _do_pending_goto() -> void:
	var scene_name: String = _pending_scene
	var payload: Dictionary = _pending_payload
	_pending_scene = ""
	_pending_payload = {}

	if scene_name == "":
		return

	# 1. Disconnect signals on the previous scene (if alive)
	if current_scene != null and is_instance_valid(current_scene):
		_disconnect_scene_signals(current_scene)

	# 2. Load (cached) and switch
	var packed: PackedScene = _packed_cache.get(scene_name, null)
	if packed == null:
		var path: String = SCENES_DIR + scene_name + ".tscn"
		packed = load(path) as PackedScene
		if packed == null:
			_log("goto: failed to load " + path)
			return
		_packed_cache[scene_name] = packed
	var err: Error = tree.change_scene_to_packed(packed)
	if err != OK:
		_log("goto: change_scene_to_packed failed err=" + str(err))
		return

	# 3. The new scene is now tree.current_scene. Capture and wire up.
	current_scene = tree.current_scene
	if current_scene == null:
		_log("goto: current_scene is null after switch")
		return

	# Force _ready() to run synchronously (the engine defers it).
	# Without this, scene scripts' instance variables may still be null
	# when set_* is called. (See test_p5_scene_controllers.gd for why.)
	if current_scene.has_method("_ready"):
		current_scene.call("_ready")

	_connect_scene_signals(current_scene)
	_apply_payload(current_scene, scene_name, payload)

## Look up the currently-running scene.
func get_current_scene() -> Node:
	if current_scene != null and is_instance_valid(current_scene):
		return current_scene
	if tree != null:
		current_scene = tree.current_scene
	return current_scene

# === Signal wiring ==================================================

func _connect_scene_signals(scene: Node) -> void:
	# Look up the GameApp singleton via the tree root metadata.
	# (Avoid referencing the `GameApp` class_name directly so this
	# script compiles without a hard dependency on app.gd.)
	var AppCls: GDScript = load("res://game/application/app.gd")
	var app: RefCounted = null
	if AppCls != null and AppCls.has_method("get_app"):
		app = AppCls.get_app(scene)
	if app == null:
		# App not ready yet (e.g. during initial goto from main.gd).
		# No wiring possible; payload will still be applied.
		return

	# Helper: connect a signal to an app method if both exist
	_wire(scene, &"start_campaign", app, &"start_new_game")
	_wire(scene, &"continue_requested", app, &"handle_continue_requested")
	_wire(scene, &"settings_requested", app, &"handle_settings_requested")
	_wire(scene, &"esc_quit", app, &"handle_quit_requested")
	_wire(scene, &"start_today", app, &"start_today")
	_wire(scene, &"option_chosen", app, &"handle_option_chosen")
	_wire(scene, &"character_clicked", app, &"_log_role_click")
	# role_clicked is handled directly by scene_base_hud which forwards to App
	# (the signal can only carry role_id, but the handler needs cid too).
	_wire(scene, &"resource_clicked", app, &"_log_resource_click")
	_wire(scene, &"facility_clicked", app, &"_log_facility_click")
	_wire(scene, &"upgrade_requested", app, &"_log_upgrade_requested")
	_wire(scene, &"item_moved", app, &"_log_item_moved")
	_wire(scene, &"step_advanced", app, &"_log_step_advanced")
	_wire(scene, &"tutorial_skipped", app, &"_log_tutorial_skipped")
	_wire(scene, &"tutorial_completed", app, &"_log_tutorial_completed")
	_wire(scene, &"closed", app, &"back_to_menu")
	_wire(scene, &"back_to_menu", app, &"back_to_menu")

func _wire(scene: Node, signal_name: StringName, target: Object, method_name: StringName) -> void:
	if not scene.has_signal(signal_name):
		return
	if not target.has_method(method_name):
		return
	# Connect once. Callable.bind() creates a fresh callable each time,
	# so use is_connected with the same target+method identity.
	var callable: Callable = Callable(target, method_name)
	if scene.is_connected(signal_name, callable):
		return
	scene.connect(signal_name, callable)

func _disconnect_scene_signals(scene: Node) -> void:
	# SceneNode.signals are auto-cleaned on free, so this is mostly a no-op.
	# Kept as the seam for future per-signal teardown.
	pass

# === Payload application =============================================

func _apply_payload(scene: Node, scene_name: String, payload: Dictionary) -> void:
	if payload.is_empty():
		return

	# morning_report payload
	if scene_name == "morning_report" and payload.has("report"):
		if scene.has_method("set_report"):
			scene.set_report(payload["report"])

	# event_decision payload
	elif scene_name == "event_decision" and payload.has("event"):
		if scene.has_method("set_event"):
			scene.set_event(payload["event"])

	# base_hud payload
	elif scene_name == "base_hud" and payload.has("session"):
		if scene.has_method("update_from_session"):
			scene.update_from_session(payload["session"])

	# inventory payload
	elif scene_name == "inventory" and payload.has("inventory"):
		if scene.has_method("set_inventory"):
			scene.set_inventory(payload["inventory"])

	# facility_upgrade payload
	elif scene_name == "facility_upgrade" and payload.has("facilities"):
		if scene.has_method("set_roster"):
			scene.set_roster(payload["facilities"])

	# accessibility_settings — no payload needed
	# tutorial — no payload needed
	# main_menu payload: campaign_complete flag
	elif scene_name == "main_menu":
		if bool(payload.get("campaign_complete", false)):
			if scene.has_method("show_campaign_complete_banner"):
				scene.show_campaign_complete_banner()