extends SceneTree

## Stage 19 GameApp smoke test.
##
## Verifies the wiring between GameApp, GameSession, DayStateMachine and
## Director works without actually switching scenes. We don't exercise
## the SceneRouter (which needs a real running SceneTree); instead we
## substitute a no-op router so App's _goto() calls are tracked but
## don't crash.

const GameAppScript: GDScript = preload("res://game/application/app.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _initialize() -> void:
	print("=== test_app_smoke start ===")
	_test_app_instantiates_with_router()
	_test_app_start_new_game_seeds_state()
	_test_app_start_today_advances_state_machine()
	_test_app_handle_role_assign_persists_job()
	_test_app_handle_option_chosen_applies_effects()
	_test_app_state_machine_hooks_advance_day_at_night_resolve()
	_test_app_fires_event_via_director()
	print("=== test_app_smoke result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _make_app() -> RefCounted:
	# A minimal router shim — has goto() that records calls instead of
	# actually switching scenes. This lets us drive App's API without
	# needing a live SceneTree.
	var RouterShim = preload("res://game/tests/_router_shim.gd")
	var router = RouterShim.new()
	router.tree = self
	var app: RefCounted = GameAppScript.new(router)
	return app

func _test_app_instantiates_with_router() -> void:
	print("[1] App instantiates and stores router")
	var app: RefCounted = _make_app()
	_expect(app != null, "app created")
	_expect(app.router != null, "router stored")

func _test_app_start_new_game_seeds_state() -> void:
	print("[2] App.start_new_game seeds session + 4 chars + 4 facilities")
	var app: RefCounted = _make_app()
	# Stub router goto so App doesn't crash on missing .tscn context.
	app.start_new_game("nanjing")
	_expect(app.session != null, "session created")
	_expect(app.session.characters.size() == 4, "4 characters seeded (got %d)" % app.session.characters.size())
	var fac_list: Array = app.session.base_state.get("facilities", [])
	_expect(fac_list.size() == 4, "4 facilities seeded (got %d)" % fac_list.size())
	var stockpile: Dictionary = app.session.base_state.get("stockpile", {})
	_expect(stockpile.has("food") and stockpile["food"] > 0, "stockpile food > 0 (got %d)" % stockpile.get("food", 0))
	_expect(app.session.base_state.get("base_name", "") == "南京避难所", "base_name = 南京避难所")
	_expect(app.current_day == 1, "current_day = 1")
	_expect(app.state_machine != null, "state machine created")
	_expect(app.director != null, "director created")

func _test_app_start_today_advances_state_machine() -> void:
	print("[3] App.start_today advances state machine")
	var app: RefCounted = _make_app()
	app.start_new_game("nanjing")
	# start_new_game ended at MORNING_REPORT (state 0). start_today
	# should advance at least to BASE_PLANNING (state 1).
	app.start_today()
	_expect(app.state_machine.current_state != app.state_machine.State.MORNING_REPORT, "no longer at MORNING_REPORT")

func _test_app_handle_role_assign_persists_job() -> void:
	print("[4] App.handle_role_assign persists character job")
	var app: RefCounted = _make_app()
	app.start_new_game("nanjing")
	var first_cid: String = String((app.session.characters[0] as Dictionary).get("id", ""))
	app.handle_role_assign(first_cid, "cook")
	var updated_job: String = String((app.session.characters[0] as Dictionary).get("job", ""))
	_expect(updated_job == "cook", "first character job = cook (got '%s')" % updated_job)

func _test_app_handle_option_chosen_applies_effects() -> void:
	print("[5] App.handle_option_chosen applies effects to session")
	var app: RefCounted = _make_app()
	app.start_new_game("nanjing")
	# Simulate that an event is awaiting resolution.
	app.pending_event_id = "evt_test"
	app.pending_event_payload = {
		"id": "evt_test",
		"options": [
			{"label_zh": "Test option", "effects": [
				{"op": "set_flag", "flag": "test_flag", "value": true},
			]},
		],
	}
	app.awaiting_event_resolution = true
	app.handle_option_chosen(0, app.pending_event_payload["options"][0])
	_expect(not app.awaiting_event_resolution, "awaiting_event_resolution cleared")
	_expect(bool(app.session.base_state["flags"]["test_flag"]) == true, "test_flag set to true")
	# Verify stat_add (target=community → all characters): each character's
	# morale gets +5.
	var initial_party_morale: int = 0
	for c in app.session.characters:
		if typeof(c) == TYPE_DICTIONARY:
			initial_party_morale += int((c as Dictionary).get("stats", {}).get("morale", 0))
	app.awaiting_event_resolution = true
	app.handle_option_chosen(0, {"label_zh": "x", "effects": [
		{"op": "stat_add", "target": "community", "stat": "morale", "amount": 5},
	]})
	var new_party_morale: int = 0
	for c in app.session.characters:
		if typeof(c) == TYPE_DICTIONARY:
			new_party_morale += int((c as Dictionary).get("stats", {}).get("morale", 0))
	var n_chars: int = app.session.characters.size()
	_expect(new_party_morale == initial_party_morale + 5 * n_chars, "party morale += 5 * %d chars (delta=%d)" % [n_chars, new_party_morale - initial_party_morale])

func _test_app_state_machine_hooks_advance_day_at_night_resolve() -> void:
	print("[6] App NIGHT_RESOLVE hook advances day")
	var app: RefCounted = _make_app()
	app.start_new_game("nanjing")
	var before_day: int = int(app.session.clock.current_day)
	# Run a full day cycle: MORNING_REPORT -> ... -> NIGHT_RESOLVE
	app.state_machine.run_full_day({})
	# After run_full_day we're at NIGHT_RESOLVE (state 5). NIGHT_RESOLVE
	# hook hasn't fired yet (it fires on enter; run_full_day ends AT
	# NIGHT_RESOLVE but the enter hook for NIGHT_RESOLVE does fire as
	# part of run_full_day's transition_to calls).
	var after_full_day: int = int(app.session.clock.current_day)
	# The hook advances day by 1 and transitions to MORNING_REPORT.
	_expect(after_full_day == before_day + 1, "after run_full_day + hook: day %d -> %d" % [before_day, after_full_day])

func _test_app_fires_event_via_director() -> void:
	print("[7] App picks event via director in expected window")
	var app: RefCounted = _make_app()
	app.start_new_game("nanjing")
	# Sweep days 1..30; collect picks; ensure at least one fired.
	var picks: Array = []
	for day in range(1, 31):
		var picked: StringName = app.director.pick_event_for_day(day, app.session)
		if String(picked) != "":
			picks.append(String(picked))
	_expect(picks.size() > 0, "director fires at least one event across days 1-30 (got %d)" % picks.size())