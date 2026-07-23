extends RefCounted
class_name GameApp
## ^ ADDS this to the project's global class registry, so other scripts
##   can use `GameApp.get_app(...)` without needing to load() it
##   as a GDScript first.

## Global application controller for Aftermap.
##
## Holds the live GameSession, DayStateMachine, Director and Interpreter.
## Owns the SceneRouter. Public API is small and event-shaped — scenes
## route their signals through here, and this object knows how to mutate
## the GameSession / advance the day / fire daily events.
##
## Lifecycle (D1 in plan):
##   - Instantiated by `game.gd` on _ready() and stored on
##     `get_tree().root.get_meta("app")`.
##   - Scenes fetch it via `GameApp.get_app(self)`.

const _PATH: String = "res://game/application/app.gd"

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")
const StateMachineScript: GDScript = preload("res://game/application/state_machine.gd")
const DirectorScript: GDScript = preload("res://game/domain/events/director.gd")
const InterpreterScript: GDScript = preload("res://game/domain/events/interpreter.gd")
const MorningReportScript: GDScript = preload("res://game/application/morning_report.gd")
const JobBoardScript: GDScript = preload("res://game/domain/base/jobs.gd")
const CharacterScript: GDScript = preload("res://game/domain/survivors/character.gd")
const BaseScript: GDScript = preload("res://game/domain/base/base.gd")
const FacilityScript: GDScript = preload("res://game/domain/base/facility.gd")
const MigrationScript: GDScript = preload("res://game/domain/world/migration.gd")
const SaveV1Script: GDScript = preload("res://game/adapters/saves/save_v1.gd")
const SceneRouterScript: GDScript = preload("res://game/application/scene_router.gd")

const DEFAULT_CONTENT_DIR: String = "res://content"
const SAVE_PATH: String = "user://save_slot_0.dat"
const CAMPAIGN_LENGTH: int = 30

## Default 4 characters seeded at game start (策划05 §2 baseline).
const DEFAULT_CHARACTER_IDS: Array[String] = [
	"chr_nurse_lin",
	"chr_engineer_chen",
	"chr_scout_wang",
	"chr_journalist_ma",
]

## Default facilities seeded in the base.
const DEFAULT_FACILITY_IDS: Array[String] = [
	"fac_sleep_basic",
	"fac_kitchen_basic",
	"fac_storage_basic",
	"fac_medical_basic",
]

const DEFAULT_JOB_ASSIGNMENTS: Array = [
	{"cid": "chr_nurse_lin", "role": "medical"},
	{"cid": "chr_engineer_chen", "role": "engineering"},
	{"cid": "chr_scout_wang", "role": "watch"},
	{"cid": "chr_journalist_ma", "role": "free"},
]

# === State ===
var router: RefCounted = null
var session: RefCounted = null
var state_machine: RefCounted = null
var director: RefCounted = null
var interpreter: RefCounted = null

# Per-campaign state (rebuilt on start_new_game)
var current_city: String = "nanjing"
var current_day: int = 1
var pending_event_payload: Dictionary = {}
var pending_event_id: String = ""
var awaiting_event_resolution: bool = false

# Last morning report (used to show in morning_report scene)
var last_morning_report: Dictionary = {}
var last_night_summary: Dictionary = {}

# Hooks for tests to inspect: has the user been asked to choose an
# option this day, what was last consumed, etc.
var event_history: Array = []  # Array of {day, event_id, chosen_index}

func _log(msg: String) -> void:
	push_warning("[GameApp] " + msg)

func _init(p_router: RefCounted = null) -> void:
	if p_router != null:
		router = p_router

## Static lookup helper for scenes: GameApp.get_app(self)
static func get_app(node: Node) -> RefCounted:
	if node == null:
		return null
	var tree: SceneTree = node.get_tree()
	if tree == null:
		return null
	if tree.root.has_meta("app"):
		return tree.root.get_meta("app")
	return null

## === Lifecycle =====================================================

## Start a fresh campaign. Loads content, seeds GameSession, sets up
## default 4 characters + 4 facilities + starting stockpile. Then routes
## to the morning_report scene.
func start_new_game(city_id: String) -> void:
	current_city = city_id
	current_day = 1
	pending_event_payload = {}
	pending_event_id = ""
	awaiting_event_resolution = false
	event_history = []
	last_night_summary = {}

	# 1. New GameSession
	session = GameSessionScript.new()
	var seed_value: int = int(Time.get_unix_time_from_system())
	var nr: RefCounted = session.new_game(seed_value, DEFAULT_CONTENT_DIR)
	if not nr.is_ok():
		_log("start_new_game: new_game failed: " + nr.message)
		return

	# 2. Hook up state machine + director + interpreter
	state_machine = StateMachineScript.new()
	director = DirectorScript.new()
	interpreter = InterpreterScript.new()
	_install_state_machine_hooks()

	# 3. Seed 4 default characters from content/characters/
	var content_db = session.content
	for cid in DEFAULT_CHARACTER_IDS:
		var record: Variant = content_db.get_record("characters", cid)
		if typeof(record) != TYPE_DICTIONARY:
			_log("character record not found: " + cid)
			continue
		var payload: Dictionary = (record as Dictionary).duplicate(true)
		# Default starting stats
		payload["stats"] = {
			"hp": 100, "hunger": 50, "energy": 80,
			"morale": 60, "stress": 5, "infection": 0,
		}
		payload["job"] = ""
		session.issue_command({"kind": "add_character", "character": payload})

	# 4. Seed 4 default facilities
	for fid in DEFAULT_FACILITY_IDS:
		var f_record: Variant = content_db.get_record("facilities", fid)
		if typeof(f_record) != TYPE_DICTIONARY:
			_log("facility record not found: " + fid)
			continue
		var f: RefCounted = FacilityScript.from_content(f_record as Dictionary)
		# Base state needs facilities map. Issue via set_base_field.
		# For now we store facilities list inside session.base_state["facilities"]
		var fac_list: Array = session.base_state.get("facilities", [])
		fac_list.append(f.to_dict())
		session.issue_command({"kind": "set_base_field", "key": "facilities", "value": fac_list})

	# 5. Seed starting stockpile
	session.issue_command({"kind": "set_base_field", "key": "stockpile", "value": {
		"food": 20, "water": 30, "material": 10, "parts": 4,
		"medical": 3, "fuel": 2, "ammo": 12,
	}})
	session.issue_command({"kind": "set_base_field", "key": "base_name", "value": "南京避难所"})
	session.issue_command({"kind": "set_base_field", "key": "population", "value": 4})

	# 6. Go to morning_report for day 1
	last_morning_report = _build_morning_report()
	_goto("morning_report", {"report": last_morning_report})

## Continue a saved campaign.
func continue_game() -> void:
	if session != null:
		_log("continue_game: existing session in progress, ignoring")
		return
	var loaded: RefCounted = SaveV1Script.load(SAVE_PATH)
	if loaded == null:
		_log("continue_game: no save found")
		return
	session = loaded
	state_machine = StateMachineScript.new()
	director = DirectorScript.new()
	interpreter = InterpreterScript.new()
	_install_state_machine_hooks()
	current_day = int(session.clock.current_day)
	last_morning_report = _build_morning_report()
	_goto("morning_report", {"report": last_morning_report})

## Player clicked "开始今天" in morning_report scene.
func start_today() -> void:
	if state_machine == null:
		_log("start_today: no state machine")
		return
	# Advance state machine: MORNING_REPORT -> BASE_PLANNING
	state_machine.advance_steps(1, {})
	# Hooks will fire: BASE_PLANNING auto-assigns jobs + advance to DAY_ACTION
	# Then NIGHT_MANAGEMENT will fire the daily event (if any)

## Stash the selected character for the next role assignment.
## Called from scene_base_hud's _on_character_pressed.
var _ui_selected_character: String = ""

func select_character_for_role(cid: String) -> void:
	_ui_selected_character = cid

func get_selected_character_for_role() -> String:
	return _ui_selected_character

## Player assigned a role to a character (from base_hud).
func handle_role_assign(character_id: String, role_id: String) -> void:
	if session == null:
		return
	if character_id == "":
		_log("handle_role_assign: empty character_id (no character selected)")
		return
	# mutate session.characters[i].job (it's a Dictionary in session.characters)
	var found: bool = false
	for i in range(session.characters.size()):
		var c: Variant = session.characters[i]
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if String((c as Dictionary).get("id", "")) == character_id:
			(c as Dictionary)["job"] = role_id
			found = true
			break
	if not found:
		_log("handle_role_assign: character_id not found: " + character_id)
	# Refresh base_hud
	_goto("base_hud", {"session": _session_payload_for_hud()})

## Player picked an option in event_decision scene.
func handle_option_chosen(idx: int, payload: Dictionary) -> void:
	if not awaiting_event_resolution:
		_log("handle_option_chosen: not awaiting event resolution")
		return
	awaiting_event_resolution = false
	# Apply effects via interpreter
	if payload.has("effects") and typeof(payload["effects"]) == TYPE_ARRAY:
		for eff in payload["effects"]:
			var er: RefCounted = interpreter.apply_effect(eff, session)
			if not er.is_ok():
				_log("effect rejected: " + er.message)
	event_history.append({
		"day": current_day,
		"event_id": pending_event_id,
		"chosen_index": idx,
	})
	pending_event_id = ""
	pending_event_payload = {}
	# Advance state machine from NIGHT_MANAGEMENT to NIGHT_RESOLVE.
	# Use transition_to (not advance_steps) — advance_steps would
	# itself call transition_to, which fires enter hooks that can
	# recurse.
	#
	# Only fire if current_state is NIGHT_MANAGEMENT (avoid double-fire
	# when handle_option_chosen is called more than once before the
	# state machine advances).
	if state_machine.current_state == state_machine.State.NIGHT_MANAGEMENT:
		state_machine.transition_to(state_machine.State.NIGHT_RESOLVE, {})

## Player clicked "返回主菜单" from any scene.
func back_to_menu() -> void:
	_goto("main_menu", {})

## Player pressed "继续" in main_menu.
func handle_continue_requested() -> void:
	continue_game()

## Player pressed "设置" in main_menu — route to accessibility_settings.
func handle_settings_requested() -> void:
	_goto("accessibility_settings", {})

## Player pressed "退出" in main_menu — quit the game.
func handle_quit_requested() -> void:
	if router != null and router.tree != null:
		router.tree.quit()

## === Internal =======================================================

func _install_state_machine_hooks() -> void:
	# On entering NIGHT_MANAGEMENT, try to fire the day's event.
	state_machine.on_enter(state_machine.State.NIGHT_MANAGEMENT, _on_enter_night_management)
	# On entering NIGHT_RESOLVE, advance day + auto-save.
	state_machine.on_enter(state_machine.State.NIGHT_RESOLVE, _on_enter_night_resolve)
	# On entering MORNING_REPORT, build report and route.
	state_machine.on_enter(state_machine.State.MORNING_REPORT, _on_enter_morning_report)

func _on_enter_night_management(_state: int, _day: int, _payload: Dictionary) -> void:
	# Try to fire today's event. If one fires, _try_fire_daily_event()
	# will route us to event_decision. The state machine stays at
	# NIGHT_MANAGEMENT until the player picks an option; then
	# handle_option_chosen() advances to NIGHT_RESOLVE explicitly.
	#
	# If no event fires today, advance to NIGHT_RESOLVE.
	# CRITICAL: use transition_to, NOT advance_steps — advance_steps
	# would itself call transition_to, which would re-fire enter hooks,
	# which could cause infinite recursion.
	var picked: Dictionary = _try_fire_daily_event()
	if picked.is_empty():
		state_machine.transition_to(state_machine.State.NIGHT_RESOLVE, {})

func _on_enter_night_resolve(_state: int, _day: int, _payload: Dictionary) -> void:
	# Daily resource consumption via the actual base module.
	var base_obj: RefCounted = _rebuild_base_object()
	if base_obj != null:
		var summary: Dictionary = base_obj.daily_tick(session)
		last_night_summary = summary
		# Persist consumed/produced into session.base_state for next report
		session.base_state["consumed"] = summary.get("consumed", {})
		session.base_state["produced"] = summary.get("produced", {})

	# Advance state machine from NIGHT_RESOLVE -> MORNING_REPORT.
	# The state machine's transition_to auto-rolls `day` when leaving
	# NIGHT_RESOLVE for MORNING_REPORT (see state_machine.gd). We
	# additionally advance session.clock.current_day so the GameSession
	# clock stays in sync with the state machine.
	state_machine.transition_to(state_machine.State.MORNING_REPORT, {})
	# Sync session.clock to the state machine's day counter.
	# (We can't issue_command advance_day because the state machine
	# already advanced its own day; we just push session.clock forward.)
	var sm_day: int = int(state_machine.day)
	if session.clock.current_day < sm_day:
		session.clock.current_day = sm_day
	current_day = int(session.clock.current_day)

	# Auto-save every 5 days.
	if current_day % 5 == 0:
		_save_current()

func _on_enter_morning_report(_state: int, _day: int, _payload: Dictionary) -> void:
	current_day = int(session.clock.current_day)
	if current_day > CAMPAIGN_LENGTH:
		_log("campaign complete after day 30")
		_goto("main_menu", {"campaign_complete": true})
		return
	last_morning_report = _build_morning_report()
	_goto("morning_report", {"report": last_morning_report})

func _try_fire_daily_event() -> Dictionary:
	var picked_id: StringName = director.pick_event_for_day(current_day, session)
	if String(picked_id) == "":
		return {}
	var rec: Variant = session.content.get_record("events", String(picked_id))
	if typeof(rec) != TYPE_DICTIONARY:
		return {}
	var record: Dictionary = rec
	# Build payload matching scene_event_decision.set_event shape
	var options: Array = []
	if record.has("options"):
		for opt in record["options"]:
			if typeof(opt) == TYPE_DICTIONARY:
				var o: Dictionary = opt
				options.append({
					"label_zh": String(o.get("label_zh", "?")),
					"effects": o.get("effects", []),
					"weight": o.get("weight", 50),
					"cost_text": "",
				})
	pending_event_payload = {
		"id": String(picked_id),
		"title_zh": String(record.get("name_zh", "事件")),
		"description": String(record.get("description_zh", "")),
		"options": options,
	}
	pending_event_id = String(picked_id)
	awaiting_event_resolution = true
	_goto("event_decision", {"event": pending_event_payload})
	return pending_event_payload

func _build_morning_report() -> Dictionary:
	var mr: RefCounted = MorningReportScript.new()
	return mr.build(session, last_night_summary)

func _save_current() -> void:
	if session == null:
		return
	var err: Error = SaveV1Script.save(session, SAVE_PATH)
	if err != OK:
		_log("auto-save failed err=" + str(err))

func _goto(scene_name: String, payload: Dictionary) -> void:
	if router != null:
		router.goto(scene_name, payload)

func _session_payload_for_hud() -> Dictionary:
	if session == null:
		return {}
	var res: Dictionary = session.base_state.get("stockpile", {})
	var chars: Array = []
	for c in session.characters:
		if typeof(c) == TYPE_DICTIONARY:
			chars.append((c as Dictionary).duplicate(true))
	return {
		"day": int(session.clock.current_day),
		"city_minutes": int(session.clock.city_minutes),
		"city_pressure": float(session.base_state.get("city_pressure", 0.0)),
		"resources": res,
		"facilities": session.base_state.get("facilities", []),
		"characters": chars,
	}

## Rebuild a live Base instance from session.base_state so we can call
## daily_tick() (which mutates the stockpile). For MVP, the base is
## stateless across ticks — we re-construct it each time.
func _rebuild_base_object() -> RefCounted:
	if session == null:
		return null
	var base: RefCounted = BaseScript.new()
	var stockpile_dict: Dictionary = session.base_state.get("stockpile", {})
	for k in BaseScript.DEFAULT_STATE.keys():
		pass  # default state already set in _init
	# Apply stockpile to base
	for k in stockpile_dict.keys():
		base.stockpile.resources[String(k)] = int(stockpile_dict[k])
	# Re-create facilities
	var fac_list: Array = session.base_state.get("facilities", [])
	for f_dict in fac_list:
		if typeof(f_dict) != TYPE_DICTIONARY:
			continue
		var f: RefCounted = FacilityScript.new(String(f_dict.get("id", "")), String(f_dict.get("kind", "sleep")))
		f.from_dict(f_dict)
		base.add_facility(f)
	base.set_population(int(session.base_state.get("population", 0)))
	# Re-assign jobs
	for c in session.characters:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cid: String = String(c.get("id", ""))
		var job: String = String(c.get("job", ""))
		if job != "":
			base.assign_role(cid, job)
	return base

func _log_warning(msg: String) -> void:
	_log(msg)