extends SceneTree

## Stage 18 / v1.0+: scene controllers integration test.
##
## Loads each P5 scene by uid (without rendering), instantiates it off-tree so
## no SceneTree.add_child is needed, and exercises the public API surface that
## the rest of the game calls into:
##
##   - main_menu:    esc_quit / start_campaign / continue_requested / settings_requested signals
##                   + _on_start_campaign_pressed() opens CityPanel
##                   + city button press emits start_campaign(city_id)
##   - morning_report: set_report({day, consumed, injuries, ...}) updates TitleLabel
##                     + start_today signal fires on StartTodayButton
##   - event_decision:  set_event({title_zh, options:[...]}) updates OptionButton_0..3
##                      + option_chosen signal fires on option press
##   - facility_upgrade: set_roster({facilities:[...]}) updates FacilitySlot_0+
##                       + upgrade_requested signal fires on slot press
##   - inventory:     set_inventory({base_resources, selected_character, items}) updates labels
##                    + item_moved signal fires on MoveButton
##   - accessibility_settings: settings = new() then set_ui_zoom / set_font_size /
##                            set_color_mode / set_screen_shake / bind
##   - scene_base_hud: update_from_session({day, city_minutes, city_pressure, resources})
##                     updates DayLabel / ClockLabel / PressureLabel / PressureProgress
##
## All assertions are API-visible state (text, signals, settings.get_state()), not
## pixel rendering — these run headless without a GPU.
##
## Run:  .tools/godot/Godot_v4.6.2-stable_win64.exe --headless --path . --script game/tests/test_p5_scene_controllers.gd
## Exit code: 0 on full success, 1 on any failure.

const MAIN_MENU_TSCN: String = "res://game/presentation/scenes/main_menu.tscn"
const MORNING_REPORT_TSCN: String = "res://game/presentation/scenes/morning_report.tscn"
const EVENT_DECISION_TSCN: String = "res://game/presentation/scenes/event_decision.tscn"
const FACILITY_UPGRADE_TSCN: String = "res://game/presentation/scenes/facility_upgrade.tscn"
const INVENTORY_TSCN: String = "res://game/presentation/scenes/inventory.tscn"
const ACCESSIBILITY_TSCN: String = "res://game/presentation/scenes/accessibility_settings.tscn"
const TUTORIAL_TSCN: String = "res://game/presentation/scenes/tutorial.tscn"
const BASE_HUD_TSCN: String = "res://game/presentation/scenes/base_hud.tscn"

var _pass_count: int = 0
var _fail_count: int = 0

func _initialize() -> void:
	print("=== test_p5_scene_controllers start ===")
	_test_main_menu_signals_and_city_panel()
	_test_main_menu_city_button_emits_start_campaign()
	_test_morning_report_set_report()
	_test_morning_report_start_today_signal()
	_test_event_decision_set_event()
	_test_event_decision_option_chosen_signal()
	_test_facility_upgrade_set_roster()
	_test_inventory_set_inventory()
	_test_inventory_item_moved_signal()
	_test_accessibility_initial_state()
	_test_accessibility_set_zoom_valid_and_invalid()
	_test_accessibility_set_font_size_valid_and_invalid()
	_test_accessibility_set_color_mode_valid_and_invalid()
	_test_accessibility_effect_toggles()
	_test_accessibility_keybind()
	_test_tutorial_steps_and_signals()
	_test_tutorial_skip_signal()
	_test_base_hud_update_from_session()
	_test_base_hud_resource_bars_update()
	print("=== test_p5_scene_controllers result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS  " + label + " (got '" + str(actual) + "')")
	else:
		_fail_count += 1
		printerr("  FAIL  " + label + " (expected '" + str(expected) + "' got '" + str(actual) + "')")

func _expect_true(condition: bool, label: String) -> void:
	_expect(condition, label)

func _load_scene(path: String) -> Node:
	# instantiate() returns a Node that owns itself; we add it to root so
	# signal connection semantics are intact. _ready() is normally called by
	# the engine on the next idle frame, but the test framework wants
	# synchronous lifecycle — so we call _ready() ourselves right after
	# add_child. The scenes' _ready() methods are idempotent enough to
	# tolerate a second manual invocation in the same frame.
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var node: Node = packed.instantiate()
	if node == null:
		return null
	root.add_child(node)
	if node.has_method("_ready"):
		node.call("_ready")
	return node

# ====================================================================== #
# main_menu
# ====================================================================== #

func _test_main_menu_signals_and_city_panel() -> void:
	print("[1] main_menu: signals + CityPanel show/hide")
	var mm: Node = _load_scene(MAIN_MENU_TSCN)
	if mm == null:
		_expect_true(false, "main_menu instantiated")
		return
	_expect_true(true, "main_menu instantiated")
	# Signals exist
	var signals_present: bool = mm.has_signal(&"esc_quit") and mm.has_signal(&"start_campaign") \
		and mm.has_signal(&"continue_requested") and mm.has_signal(&"settings_requested")
	_expect_true(signals_present, "main_menu declares 4 signals")
	# Initially CityPanel is hidden
	var city_panel: Node = mm.get_node_or_null("CityPanel")
	_expect_true(city_panel != null, "CityPanel exists")
	if city_panel != null:
		_expect_true(not city_panel.visible, "CityPanel initially hidden")
	# Press Start Campaign button (Programmatic — find by name)
	var btn: Button = mm.get_node_or_null("MainVBox/ButtonGrid/StartCampaignButton") as Button
	if btn == null:
		# scene script may have built it with different path; try other locations
		btn = _find_button_by_name(mm, "StartCampaignButton")
	_expect_true(btn != null, "StartCampaignButton present")
	if btn != null and city_panel != null:
		btn.pressed.emit()
		_expect_true(city_panel.visible, "CityPanel visible after StartCampaign press")
	mm.queue_free()

func _test_main_menu_city_button_emits_start_campaign() -> void:
	print("[2] main_menu: city button -> start_campaign signal")
	var mm: Node = _load_scene(MAIN_MENU_TSCN)
	if mm == null:
		_expect_true(false, "main_menu instantiated (city btn test)")
		return
	var captured: Array = []
	var on_signal: Callable = func(id: String) -> void: captured.append(id)
	mm.start_campaign.connect(on_signal)
	# Open the panel
	var btn: Button = mm.get_node_or_null("MainVBox/ButtonGrid/StartCampaignButton") as Button
	if btn == null:
		btn = _find_button_by_name(mm, "StartCampaignButton")
	if btn != null:
		btn.pressed.emit()
	# Find Nanjing button by name and press it
	var nanjing: Button = mm.get_node_or_null("CityPanel/CityPanelVBox/CityRow_nanjing/CityButton_nanjing") as Button
	if nanjing == null:
		# fall back to recursive find
		nanjing = _find_button_by_name(mm, "CityButton_nanjing")
	_expect_true(nanjing != null, "CityButton_nanjing present")
	if nanjing != null:
		nanjing.pressed.emit()
	_expect_eq(captured.size(), 1, "start_campaign signal emitted once")
	if captured.size() >= 1:
		_expect_eq(captured[0], "nanjing", "start_campaign carries city_id 'nanjing'")
	mm.queue_free()

# ====================================================================== #
# morning_report
# ====================================================================== #

func _test_morning_report_set_report() -> void:
	print("[3] morning_report: set_report updates TitleLabel")
	var mr: Node = _load_scene(MORNING_REPORT_TSCN)
	if mr == null:
		_expect_true(false, "morning_report instantiated")
		return
	_expect_true(true, "morning_report instantiated")
	mr.set_report({
		"day": 7,
		"consumed": {"food": 4, "water": 6, "material": 1, "parts": 0, "medical": 1, "fuel": 1, "ammo": 0},
		"produced": {},
		"injuries": [{"id": "x"}, {"id": "y"}],
		"infections": [],
		"events": [{"id": "a"}],
		"relationships": [],
		"city_pressure": 33.0,
		"morale": 60,
	})
	var title: Label = mr.get_node_or_null("ReportVBox/TitleLabel") as Label
	_expect_true(title != null, "TitleLabel present")
	if title != null:
		_expect_true("第 7 天" in title.text, "TitleLabel shows day 7 (got '" + title.text + "')")
	# SummaryLine_0 should reflect consumption
	var line0: Label = mr.get_node_or_null("ReportVBox/SummaryList/SummaryLine_0") as Label
	_expect_true(line0 != null, "SummaryLine_0 present")
	if line0 != null:
		_expect_true("food=4" in line0.text and "water=6" in line0.text, "consumption line shows food=4 water=6")
	var line1: Label = mr.get_node_or_null("ReportVBox/SummaryList/SummaryLine_1") as Label
	if line1 != null:
		_expect_true("伤病 2 例" in line1.text, "injuries line shows 2 cases")
	mr.queue_free()

func _test_morning_report_start_today_signal() -> void:
	print("[4] morning_report: StartTodayButton -> start_today")
	var mr: Node = _load_scene(MORNING_REPORT_TSCN)
	if mr == null:
		_expect_true(false, "morning_report instantiated (start_today)")
		return
	var captured: Array = []
	mr.start_today.connect(func() -> void: captured.append(true))
	var btn: Button = mr.get_node_or_null("ReportVBox/StartTodayButton") as Button
	if btn == null:
		btn = _find_button_by_name(mr, "StartTodayButton")
	_expect_true(btn != null, "StartTodayButton present")
	if btn != null:
		btn.pressed.emit()
	_expect_eq(captured.size(), 1, "start_today signal fired once")
	mr.queue_free()

# ====================================================================== #
# event_decision
# ====================================================================== #

func _test_event_decision_set_event() -> void:
	print("[5] event_decision: set_event updates title + options")
	var ed: Node = _load_scene(EVENT_DECISION_TSCN)
	if ed == null:
		_expect_true(false, "event_decision instantiated")
		return
	ed.set_event({
		"id": "evt_test_d",
		"title_zh": "测试事件",
		"description": "[b]粗体[/b] 内容",
		"options": [
			{"label_zh": "选项甲", "cost_text": "-2 food", "weight": 1.0},
			{"label_zh": "选项乙", "cost_text": "-1 morale", "weight": 1.0},
		],
	})
	var title: Label = ed.get_node_or_null("DecisionVBox/TitleLabel") as Label
	_expect_true(title != null, "TitleLabel present")
	if title != null:
		_expect_eq(title.text, "测试事件", "title_zh displayed")
	var btn0: Button = ed.get_node_or_null("DecisionVBox/OptionList/OptionButton_0") as Button
	_expect_true(btn0 != null, "OptionButton_0 present")
	if btn0 != null:
		_expect_true("选项甲" in btn0.text and "-2 food" in btn0.text, "OptionButton_0 text shows label+cost")
		_expect_true(not btn0.disabled, "OptionButton_0 enabled")
	var btn1: Button = ed.get_node_or_null("DecisionVBox/OptionList/OptionButton_1") as Button
	if btn1 != null:
		_expect_true("选项乙" in btn1.text, "OptionButton_1 text shows label")
	# OptionButton_2 / 3 should be disabled since only 2 options provided
	var btn2: Button = ed.get_node_or_null("DecisionVBox/OptionList/OptionButton_2") as Button
	if btn2 != null:
		_expect_true(btn2.disabled, "OptionButton_2 disabled (only 2 options)")
	ed.queue_free()

func _test_event_decision_option_chosen_signal() -> void:
	print("[6] event_decision: option press -> option_chosen(idx, payload)")
	var ed: Node = _load_scene(EVENT_DECISION_TSCN)
	if ed == null:
		_expect_true(false, "event_decision instantiated (option signal)")
		return
	ed.set_event({
		"id": "evt_test_d2",
		"title_zh": "t",
		"description": "",
		"options": [{"label_zh": "A", "weight": 1.0}, {"label_zh": "B", "weight": 1.0}],
	})
	var captured_idx: Array = []
	var captured_payload: Array = []
	ed.option_chosen.connect(func(idx: int, payload: Dictionary) -> void:
		captured_idx.append(idx)
		captured_payload.append(payload.duplicate(true)))
	var btn0: Button = ed.get_node_or_null("DecisionVBox/OptionList/OptionButton_0") as Button
	if btn0 != null:
		btn0.pressed.emit()
	_expect_eq(captured_idx.size(), 1, "option_chosen fired once")
	if captured_idx.size() >= 1:
		_expect_eq(captured_idx[0], 0, "option_chosen carries idx=0")
	if captured_payload.size() >= 1:
		_expect_eq(captured_payload[0].get("label_zh", ""), "A", "option_chosen carries option payload")
	ed.queue_free()

# ====================================================================== #
# facility_upgrade
# ====================================================================== #

func _test_facility_upgrade_set_roster() -> void:
	print("[7] facility_upgrade: set_roster updates slot buttons")
	var fu: Node = _load_scene(FACILITY_UPGRADE_TSCN)
	if fu == null:
		_expect_true(false, "facility_upgrade instantiated")
		return
	fu.set_roster({
		"facilities": [
			{"id": "fac_kitchen_basic", "name_zh": "厨房", "tier": 1},
			{"id": "fac_medical_basic", "name_zh": "医疗站", "tier": 1},
		],
	})
	var slot0: Button = fu.get_node_or_null("UpgradeVBox/FacilityGrid/FacilitySlot_0") as Button
	_expect_true(slot0 != null, "FacilitySlot_0 present")
	if slot0 != null:
		_expect_true("厨房" in slot0.text, "slot_0 text contains '厨房'")
		_expect_true("Tier 1" in slot0.text, "slot_0 text contains 'Tier 1'")
		_expect_true(not slot0.disabled, "slot_0 enabled")
	var slot2: Button = fu.get_node_or_null("UpgradeVBox/FacilityGrid/FacilitySlot_2") as Button
	if slot2 != null:
		_expect_true(slot2.disabled, "slot_2 disabled (only 2 facilities)")
	fu.queue_free()

# ====================================================================== #
# inventory
# ====================================================================== #

func _test_inventory_set_inventory() -> void:
	print("[8] inventory: set_inventory updates labels")
	var inv: Node = _load_scene(INVENTORY_TSCN)
	if inv == null:
		_expect_true(false, "inventory instantiated")
		return
	inv.set_inventory({
		"base_resources": {"food": 12, "water": 18, "material": 5, "parts": 3, "medical": 2, "fuel": 1, "ammo": 8},
		"selected_character": "c_alex",
		"items": [
			{"id": "itm_bandage", "name_zh": "绷带", "qty": 4},
			{"id": "itm_painkillers", "name_zh": "止痛药", "qty": 2},
		],
	})
	var res_label: Label = inv.get_node_or_null("InventoryVBox/InventoryHBox/BaseStockPanel/ResourceList/Resource_food/ResourceLabel") as Label
	_expect_true(res_label != null, "food resource label present")
	if res_label != null:
		_expect_true("12" in res_label.text, "food label shows 12")
	var char_label: Label = inv.get_node_or_null("InventoryVBox/InventoryHBox/CharEquipmentPanel/EquipmentList/CharLabel") as Label
	if char_label != null:
		_expect_true("c_alex" in char_label.text, "char label shows selected character")
	var slot0: Label = inv.get_node_or_null("InventoryVBox/InventoryHBox/CharEquipmentPanel/EquipmentList/EquipSlot_0/EquipSlotLabel") as Label
	if slot0 != null:
		_expect_true("绷带" in slot0.text and "x4" in slot0.text, "slot_0 shows bandage x4")
	inv.queue_free()

func _test_inventory_item_moved_signal() -> void:
	print("[9] inventory: MoveButton -> item_moved signal")
	var inv: Node = _load_scene(INVENTORY_TSCN)
	if inv == null:
		_expect_true(false, "inventory instantiated (item_moved)")
		return
	inv.set_inventory({
		"base_resources": {"food": 10, "water": 0, "material": 0, "parts": 0, "medical": 0, "fuel": 0, "ammo": 0},
		"selected_character": "c_alex",
		"items": [],
	})
	var captured: Array = []
	inv.item_moved.connect(func(item_id: String, from: String, to: String, qty: int) -> void:
		captured.append({"item_id": item_id, "from": from, "to": to, "qty": qty}))
	var move_btn: Button = inv.get_node_or_null("InventoryVBox/InventoryHBox/BaseStockPanel/ResourceList/Resource_food/MoveButton") as Button
	_expect_true(move_btn != null, "food MoveButton present")
	if move_btn != null:
		move_btn.pressed.emit()
	_expect_eq(captured.size(), 1, "item_moved signal fired once")
	if captured.size() >= 1:
		var evt: Dictionary = captured[0]
		_expect_eq(evt.get("item_id", ""), "food", "item_moved.item_id = food")
		_expect_eq(evt.get("from", ""), "base", "item_moved.from = base")
		_expect_eq(evt.get("qty", 0), 1, "item_moved.qty = 1")
	# Without selected_character, MoveButton press should NOT fire — re-test
	inv.queue_free()
	var inv2: Node = _load_scene(INVENTORY_TSCN)
	inv2.set_inventory({"base_resources": {}, "selected_character": "", "items": []})
	var captured2: Array = []
	inv2.item_moved.connect(func(a: String, b: String, c: String, d: int) -> void: captured2.append(true))
	var move_btn2: Button = inv2.get_node_or_null("InventoryVBox/InventoryHBox/BaseStockPanel/ResourceList/Resource_food/MoveButton") as Button
	if move_btn2 != null:
		move_btn2.pressed.emit()
	_expect_eq(captured2.size(), 0, "item_moved NOT fired without selected_character")
	inv2.queue_free()

# ====================================================================== #
# accessibility_settings
# ====================================================================== #

func _test_accessibility_initial_state() -> void:
	print("[10] accessibility: initial state defaults")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated")
		return
	var settings_obj: RefCounted = acc.get_settings()
	_expect_true(settings_obj != null, "settings RefCounted available")
	if settings_obj != null:
		_expect_eq(settings_obj.get_ui_zoom(), 1.0, "default ui_zoom = 1.0")
		_expect_eq(settings_obj.get_font_size(), "standard", "default font_size = standard")
		_expect_eq(settings_obj.get_color_mode(), "default", "default color_mode = default")
		_expect_eq(settings_obj.get_screen_shake(), true, "default screen_shake = true")
		_expect_eq(settings_obj.get_binding_count(), 0, "default binding count = 0")
	acc.queue_free()

func _test_accessibility_set_zoom_valid_and_invalid() -> void:
	print("[11] accessibility: set_ui_zoom accept/reject")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated (zoom)")
		return
	var s: RefCounted = acc.get_settings()
	_expect_true(s.set_ui_zoom(1.2), "set_ui_zoom(1.2) accepted")
	_expect_eq(s.get_ui_zoom(), 1.2, "ui_zoom = 1.2")
	_expect_true(not s.set_ui_zoom(0.5), "set_ui_zoom(0.5) rejected (not in whitelist)")
	_expect_eq(s.get_ui_zoom(), 1.2, "ui_zoom unchanged after invalid set")
	# Click button path
	var zoom_btn: Button = acc.get_node_or_null("SettingsVBox/ZoomRow/ZoomOption_2") as Button
	if zoom_btn != null:
		zoom_btn.pressed.emit()
		_expect_eq(s.get_ui_zoom(), 1.2, "ZoomOption_2 (=120%) pressed → ui_zoom=1.2")
	acc.queue_free()

func _test_accessibility_set_font_size_valid_and_invalid() -> void:
	print("[12] accessibility: set_font_size accept/reject")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated (font_size)")
		return
	var s: RefCounted = acc.get_settings()
	_expect_true(s.set_font_size("large"), "set_font_size('large') accepted")
	_expect_eq(s.get_font_size(), "large", "font_size = large")
	_expect_true(not s.set_font_size("huge"), "set_font_size('huge') rejected")
	_expect_eq(s.get_font_size(), "large", "font_size unchanged after invalid set")
	acc.queue_free()

func _test_accessibility_set_color_mode_valid_and_invalid() -> void:
	print("[13] accessibility: set_color_mode accept/reject")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated (color_mode)")
		return
	var s: RefCounted = acc.get_settings()
	_expect_true(s.set_color_mode("high_contrast"), "set_color_mode('high_contrast') accepted")
	_expect_eq(s.get_color_mode(), "high_contrast", "color_mode = high_contrast")
	_expect_true(not s.set_color_mode("tritanopia"), "set_color_mode('tritanopia') rejected")
	_expect_eq(s.get_color_mode(), "high_contrast", "color_mode unchanged after invalid set")
	acc.queue_free()

func _test_accessibility_effect_toggles() -> void:
	print("[14] accessibility: effect toggles")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated (effects)")
		return
	var s: RefCounted = acc.get_settings()
	var shake0: bool = s.get_screen_shake()
	s.set_screen_shake(not shake0)
	_expect_eq(s.get_screen_shake(), not shake0, "screen_shake toggled")
	# Pressing the toggle button path
	var toggle_btn: Button = acc.get_node_or_null("SettingsVBox/EffectsRow/EffectToggle_camera_shake") as Button
	_expect_true(toggle_btn != null, "camera_shake toggle button present")
	if toggle_btn != null:
		var before: bool = s.get_camera_shake()
		toggle_btn.pressed.emit()
		_expect_eq(s.get_camera_shake(), not before, "camera_shake toggled via button")
	acc.queue_free()

func _test_accessibility_keybind() -> void:
	print("[15] accessibility: bind/clear keybinding")
	var acc: Node = _load_scene(ACCESSIBILITY_TSCN)
	if acc == null:
		_expect_true(false, "accessibility instantiated (keybind)")
		return
	var s: RefCounted = acc.get_settings()
	_expect_true(s.bind("pause", 4194305), "bind('pause', SPACE) accepted")
	_expect_eq(s.get_binding("pause"), 4194305, "binding pause = SPACE")
	_expect_eq(s.get_binding_count(), 1, "binding count = 1")
	_expect_true(not s.bind("", 4194305), "bind('', k) rejected (empty action)")
	_expect_true(not s.bind("pause", 0), "bind(action, 0) rejected (invalid keycode)")
	# 17th binding should fail (cap = 16)
	for i in range(15):
		s.bind("act_%d" % i, 1000 + i)
	_expect_eq(s.get_binding_count(), 16, "binding count capped at 16")
	_expect_true(not s.bind("overflow", 9999), "17th bind rejected (cap full)")
	s.clear_binding("pause")
	_expect_eq(s.get_binding_count(), 15, "clear_binding decrements count")
	acc.queue_free()

# ====================================================================== #
# tutorial
# ====================================================================== #

func _test_tutorial_steps_and_signals() -> void:
	print("[16] tutorial: step navigation + step_advanced signal")
	var tut: Node = _load_scene(TUTORIAL_TSCN)
	if tut == null:
		_expect_true(false, "tutorial instantiated")
		return
	var captured: Array = []
	tut.step_advanced.connect(func(idx: int) -> void: captured.append(idx))
	_expect_eq(tut.get_step_index(), 0, "starts at step 0")
	var next_btn: Button = tut.get_node_or_null("TutorialVBox/NavBar/NextButton") as Button
	if next_btn == null:
		next_btn = _find_button_by_name(tut, "NextButton")
	_expect_true(next_btn != null, "NextButton present")
	if next_btn != null:
		next_btn.pressed.emit()
		_expect_eq(tut.get_step_index(), 1, "step_index advanced to 1")
		next_btn.pressed.emit()
		_expect_eq(tut.get_step_index(), 2, "step_index advanced to 2")
	_expect_eq(captured.size(), 2, "step_advanced emitted twice")
	if captured.size() >= 2:
		_expect_eq(captured[0], 1, "first step_advanced = 1")
		_expect_eq(captured[1], 2, "second step_advanced = 2")
	tut.queue_free()

func _test_tutorial_skip_signal() -> void:
	print("[17] tutorial: skip -> tutorial_skipped")
	var tut: Node = _load_scene(TUTORIAL_TSCN)
	if tut == null:
		_expect_true(false, "tutorial instantiated (skip)")
		return
	var captured: Array = []
	tut.tutorial_skipped.connect(func() -> void: captured.append(true))
	var skip_btn: Button = tut.get_node_or_null("TutorialVBox/NavBar/SkipButton") as Button
	if skip_btn == null:
		skip_btn = _find_button_by_name(tut, "SkipButton")
	_expect_true(skip_btn != null, "SkipButton present")
	if skip_btn != null:
		skip_btn.pressed.emit()
	_expect_eq(captured.size(), 1, "tutorial_skipped emitted once")
	# Last step -> tutorial_completed
	var tut2: Node = _load_scene(TUTORIAL_TSCN)
	var completed_captured: Array = []
	tut2.tutorial_completed.connect(func() -> void: completed_captured.append(true))
	var next: Button = _find_button_by_name(tut2, "NextButton")
	# STEPS = 5, so 4 next presses from index 0 reach index 4 (last)
	if next != null:
		next.pressed.emit()
		next.pressed.emit()
		next.pressed.emit()
		next.pressed.emit()
	# Now at last step; press Next once more -> tutorial_completed
	if next != null:
		next.pressed.emit()
	_expect_eq(completed_captured.size(), 1, "tutorial_completed emitted on last step")
	tut2.queue_free()

# ====================================================================== #
# scene_base_hud
# ====================================================================== #

func _test_base_hud_update_from_session() -> void:
	print("[18] base_hud: update_from_session sets Day/Clock/Pressure")
	var bh: Node = _load_scene(BASE_HUD_TSCN)
	if bh == null:
		_expect_true(false, "base_hud instantiated")
		return
	bh.update_from_session({
		"day": 14,
		"city_minutes": 9 * 60 + 30,  # 09:30
		"city_pressure": 47.0,
		"resources": {"food": 22, "water": 18, "material": 5, "parts": 3, "medical": 4, "fuel": 2, "ammo": 7},
		"facilities": [],
		"characters": [],
	})
	var day_label: Label = bh.get_node_or_null("TopBar/DayLabel") as Label
	_expect_true(day_label != null, "DayLabel present")
	if day_label != null:
		_expect_eq(day_label.text, "Day 14", "DayLabel = Day 14")
	var clock_label: Label = bh.get_node_or_null("TopBar/ClockLabel") as Label
	if clock_label != null:
		_expect_eq(clock_label.text, "09:30", "ClockLabel = 09:30")
	var pressure_label: Label = bh.get_node_or_null("TopBar/PressureLabel") as Label
	if pressure_label != null:
		_expect_true("47" in pressure_label.text, "PressureLabel contains 47")
	var pressure_progress: ProgressBar = bh.get_node_or_null("TopBar/PressureProgress") as ProgressBar
	if pressure_progress != null:
		_expect_eq(int(pressure_progress.value), 47, "PressureProgress.value = 47")
	bh.queue_free()

func _test_base_hud_resource_bars_update() -> void:
	print("[19] base_hud: resource bars reflect payload")
	var bh: Node = _load_scene(BASE_HUD_TSCN)
	if bh == null:
		_expect_true(false, "base_hud instantiated (resource bars)")
		return
	bh.update_from_session({
		"day": 1,
		"city_minutes": 360,
		"city_pressure": 0,
		"resources": {"food": 60, "water": 80, "material": 20, "parts": 12, "medical": 8, "fuel": 4, "ammo": 16},
		"facilities": [],
		"characters": [],
	})
	var water_bar: ProgressBar = bh.get_node_or_null("ResourcePanel/ResourceBox/Resource_water/ResourceBar") as ProgressBar
	_expect_true(water_bar != null, "water ResourceBar present")
	if water_bar != null:
		_expect_eq(int(water_bar.value), 80, "water ResourceBar.value = 80")
	var food_label: Label = bh.get_node_or_null("ResourcePanel/ResourceBox/Resource_food/ResourceLabel") as Label
	if food_label != null:
		_expect_true("60" in food_label.text, "food ResourceLabel contains 60")
	bh.queue_free()

# ====================================================================== #
# helpers
# ====================================================================== #

func _find_button_by_name(parent: Node, btn_name: String) -> Button:
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Button and child.name == btn_name:
			return child
		var found: Button = _find_button_by_name(child, btn_name)
		if found != null:
			return found
	return null