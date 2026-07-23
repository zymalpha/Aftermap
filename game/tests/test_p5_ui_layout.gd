extends SceneTree

## Stage 15 P5 UI tests.
## Loads every P5 scene by uid (without rendering), asserts key nodes exist,
## and exercises set_accessibility / set_zoom / set_color_mode without errors.
##
## Run:  .tools/godot/Godot_v4.6.2-stable_win64.exe --headless --path . --script game/tests/test_p5_ui_layout.gd
## Exit code: 0 on full success, 1 on any failure.

const MAIN_MENU_TSCN: String = "res://game/presentation/scenes/main_menu.tscn"
const BASE_HUD_TSCN: String = "res://game/presentation/scenes/base_hud.tscn"
const MORNING_REPORT_TSCN: String = "res://game/presentation/scenes/morning_report.tscn"
const EVENT_DECISION_TSCN: String = "res://game/presentation/scenes/event_decision.tscn"
const FACILITY_UPGRADE_TSCN: String = "res://game/presentation/scenes/facility_upgrade.tscn"
const INVENTORY_TSCN: String = "res://game/presentation/scenes/inventory.tscn"
const TUTORIAL_TSCN: String = "res://game/presentation/scenes/tutorial.tscn"
const ACCESSIBILITY_TSCN: String = "res://game/presentation/scenes/accessibility_settings.tscn"

const AccessSettingsScript: GDScript = preload("res://game/presentation/ui/settings_accessibility.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p5_ui_layout start ===")
	_test_main_menu_layout()
	_test_base_hud_layout()
	_test_morning_report_layout()
	_test_event_decision_layout()
	_test_facility_upgrade_layout()
	_test_inventory_layout()
	_test_tutorial_layout()
	_test_accessibility_layout()
	_test_accessibility_set_zoom()
	_test_accessibility_set_font_size()
	_test_accessibility_set_color_mode()
	_test_accessibility_set_screen_shake()
	_test_accessibility_set_camera_shake()
	_test_accessibility_set_damage_vignette()
	_test_accessibility_set_motion_blur()
	_test_accessibility_set_keybinding()
	_test_accessibility_clear_keybinding()
	_test_accessibility_get_state()
	_test_main_menu_signals_present()
	_test_base_hud_signals_present()
	_test_morning_report_signal_present()
	_test_event_decision_signal_present()
	_test_facility_upgrade_signal_present()
	_test_inventory_signal_present()
	_test_tutorial_signal_present()
	print("=== test_p5_ui_layout result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _load_scene(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()

func _free_node(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()

# --- scene structure ------------------------------------------------------

func _test_main_menu_layout() -> void:
	print("[1] main_menu.tscn loads + key nodes")
	var n: Node = _load_scene(MAIN_MENU_TSCN)
	_expect(n != null, "main_menu instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("MainVBox/TitleLabel") != null, "title label present")
	_expect(n.get_node_or_null("MainVBox/SubtitleLabel") != null, "subtitle label present")
	_expect(n.get_node_or_null("MainVBox/CoordsLabel") != null, "coords label present")
	_expect(n.get_node_or_null("MainVBox/ButtonGrid/StartCampaignButton") != null, "Start button present")
	_expect(n.get_node_or_null("MainVBox/ButtonGrid/ContinueButton") != null, "Continue button present")
	_expect(n.get_node_or_null("MainVBox/ButtonGrid/SettingsButton") != null, "Settings button present")
	_expect(n.get_node_or_null("MainVBox/ButtonGrid/QuitButton") != null, "Quit button present")
	_expect(n.get_node_or_null("CityPanel") != null, "CityPanel present")
	_expect(n.get_node_or_null("CityPanel/CityPanelVBox/CityRow_nanjing/CityButton_nanjing") != null, "Nanjing button present")
	_expect(n.get_node_or_null("CityPanel/CityPanelVBox/CityRow_placeholder_east/CityButton_placeholder_east") != null, "Shanghai placeholder present")
	_expect(n.get_node_or_null("CityPanel/CityPanelVBox/CityRow_placeholder_west/CityButton_placeholder_west") != null, "Chongqing placeholder present")
	_expect(n.get_node_or_null("CityPanel/CityPanelVBox/CityPanelCancel") != null, "Cancel button present")
	_free_node(n)

func _test_base_hud_layout() -> void:
	print("[2] base_hud.tscn loads + key nodes")
	var n: Node = _load_scene(BASE_HUD_TSCN)
	_expect(n != null, "base_hud instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("TopBar/DayLabel") != null, "DayLabel present")
	_expect(n.get_node_or_null("TopBar/ClockLabel") != null, "ClockLabel present")
	_expect(n.get_node_or_null("TopBar/PressureLabel") != null, "PressureLabel present")
	_expect(n.get_node_or_null("TopBar/PressureProgress") != null, "PressureProgress present")
	_expect(n.get_node_or_null("FacilityPanel/FacilityBox") != null, "FacilityBox present")
	_expect(n.get_node_or_null("ResourcePanel/ResourceBox") != null, "ResourceBox present")
	_expect(n.get_node_or_null("CharacterPanel/CharacterBox") != null, "CharacterBox present")
	_expect(n.get_node_or_null("RolePanel/RoleGrid") != null, "RoleGrid present")
	# Role buttons (one per ROLE_IDS in scene_base_hud.gd)
	var grid: Node = n.get_node_or_null("RolePanel/RoleGrid")
	for role in ["cook", "water", "medical", "engineering", "cleaning", "garden", "watch", "guard", "radio", "hauling", "rest", "free"]:
		_expect(grid.get_node_or_null("Role_" + role) != null, "role %s present" % role)
	_free_node(n)

func _test_morning_report_layout() -> void:
	print("[3] morning_report.tscn loads + key nodes")
	var n: Node = _load_scene(MORNING_REPORT_TSCN)
	_expect(n != null, "morning_report instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("ReportVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("ReportVBox/SummaryList") != null, "SummaryList present")
	_expect(n.get_node_or_null("ReportVBox/StartTodayButton") != null, "StartTodayButton present")
	_free_node(n)

func _test_event_decision_layout() -> void:
	print("[4] event_decision.tscn loads + key nodes")
	var n: Node = _load_scene(EVENT_DECISION_TSCN)
	_expect(n != null, "event_decision instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("DecisionVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("DecisionVBox/DescriptionLabel") != null, "DescriptionLabel present")
	_expect(n.get_node_or_null("DecisionVBox/OptionList") != null, "OptionList present")
	_expect(n.get_node_or_null("DecisionVBox/OptionList/OptionButton_0") != null, "Option 0 present")
	_expect(n.get_node_or_null("DecisionVBox/OptionList/OptionButton_1") != null, "Option 1 present")
	_expect(n.get_node_or_null("DecisionVBox/OptionList/OptionButton_2") != null, "Option 2 present")
	_expect(n.get_node_or_null("DecisionVBox/OptionList/OptionButton_3") != null, "Option 3 present")
	_free_node(n)

func _test_facility_upgrade_layout() -> void:
	print("[5] facility_upgrade.tscn loads + key nodes")
	var n: Node = _load_scene(FACILITY_UPGRADE_TSCN)
	_expect(n != null, "facility_upgrade instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("UpgradeVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("UpgradeVBox/FacilityGrid") != null, "FacilityGrid present")
	_expect(n.get_node_or_null("UpgradeVBox/FacilityGrid/FacilitySlot_0") != null, "Facility slot 0 present")
	_expect(n.get_node_or_null("UpgradeVBox/FacilityGrid/FacilitySlot_11") != null, "Facility slot 11 present")
	_expect(n.get_node_or_null("UpgradeVBox/DetailPanel") != null, "DetailPanel present")
	_expect(n.get_node_or_null("UpgradeVBox/DetailPanel/DetailLabel") != null, "DetailLabel present")
	_free_node(n)

func _test_inventory_layout() -> void:
	print("[6] inventory.tscn loads + key nodes")
	var n: Node = _load_scene(INVENTORY_TSCN)
	_expect(n != null, "inventory instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("InventoryVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("InventoryHBox/BaseStockPanel") != null, "BaseStockPanel present")
	_expect(n.get_node_or_null("InventoryHBox/CharEquipmentPanel") != null, "CharEquipmentPanel present")
	_expect(n.get_node_or_null("InventoryHBox/BaseStockPanel/ResourceList") != null, "ResourceList present")
	_expect(n.get_node_or_null("InventoryHBox/CharEquipmentPanel/EquipmentList") != null, "EquipmentList present")
	_free_node(n)

func _test_tutorial_layout() -> void:
	print("[7] tutorial.tscn loads + key nodes")
	var n: Node = _load_scene(TUTORIAL_TSCN)
	_expect(n != null, "tutorial instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("TutorialVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("TutorialVBox/StepContent") != null, "StepContent present")
	_expect(n.get_node_or_null("TutorialVBox/StepContent/StepLabel") != null, "StepLabel present")
	_expect(n.get_node_or_null("TutorialVBox/StepContent/StepBody") != null, "StepBody present")
	_expect(n.get_node_or_null("TutorialVBox/NavBar/NextButton") != null, "NextButton present")
	_expect(n.get_node_or_null("TutorialVBox/NavBar/SkipButton") != null, "SkipButton present")
	_free_node(n)

func _test_accessibility_layout() -> void:
	print("[8] accessibility_settings.tscn loads + key nodes")
	var n: Node = _load_scene(ACCESSIBILITY_TSCN)
	_expect(n != null, "accessibility_settings instantiated")
	if n == null:
		return
	_expect(n.get_node_or_null("SettingsVBox/TitleLabel") != null, "TitleLabel present")
	_expect(n.get_node_or_null("SettingsVBox/ZoomRow") != null, "ZoomRow present")
	_expect(n.get_node_or_null("SettingsVBox/FontRow") != null, "FontRow present")
	_expect(n.get_node_or_null("SettingsVBox/ColorRow") != null, "ColorRow present")
	_expect(n.get_node_or_null("SettingsVBox/KeybindList") != null, "KeybindList present")
	_expect(n.get_node_or_null("SettingsVBox/EffectsRow") != null, "EffectsRow present")
	_expect(n.get_node_or_null("SettingsVBox/CloseButton") != null, "CloseButton present")
	_free_node(n)

# --- accessibility set_*(...) surface --------------------------------------

func _test_accessibility_set_zoom() -> void:
	print("[9] accessibility.set_ui_zoom valid + invalid")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_ui_zoom(1.0) == true, "1.0 accepted")
	_expect(s.set_ui_zoom(0.8) == true, "0.8 accepted")
	_expect(s.set_ui_zoom(1.2) == true, "1.2 accepted")
	_expect(s.set_ui_zoom(1.6) == true, "1.6 accepted")
	_expect(s.set_ui_zoom(0.5) == false, "0.5 rejected")
	_expect(s.set_ui_zoom(2.0) == false, "2.0 rejected")
	_expect(s.get_ui_zoom() == 1.6, "last good zoom persists")

func _test_accessibility_set_font_size() -> void:
	print("[10] accessibility.set_font_size valid + invalid")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_font_size("standard") == true, "standard accepted")
	_expect(s.set_font_size("small") == true, "small accepted")
	_expect(s.set_font_size("large") == true, "large accepted")
	_expect(s.set_font_size("huge") == false, "huge rejected")
	_expect(s.get_font_size() == "large", "last good font size persists")

func _test_accessibility_set_color_mode() -> void:
	print("[11] accessibility.set_color_mode valid + invalid")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_color_mode("default") == true, "default accepted")
	_expect(s.set_color_mode("protanopia") == true, "protanopia accepted")
	_expect(s.set_color_mode("deuteranopia") == true, "deuteranopia accepted")
	_expect(s.set_color_mode("high_contrast") == true, "high_contrast accepted")
	_expect(s.set_color_mode("rainbow") == false, "rainbow rejected")
	_expect(s.get_color_mode() == "high_contrast", "last good color mode persists")

func _test_accessibility_set_screen_shake() -> void:
	print("[12] accessibility.set_screen_shake")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_screen_shake(false) == true, "set false ok")
	_expect(s.get_screen_shake() == false, "screen shake disabled")
	_expect(s.set_screen_shake(true) == true, "set true ok")
	_expect(s.get_screen_shake() == true, "screen shake enabled")

func _test_accessibility_set_camera_shake() -> void:
	print("[13] accessibility.set_camera_shake")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_camera_shake(false) == true, "set false ok")
	_expect(s.get_camera_shake() == false, "camera shake disabled")
	_expect(s.set_camera_shake(true) == true, "set true ok")
	_expect(s.get_camera_shake() == true, "camera shake enabled")

func _test_accessibility_set_damage_vignette() -> void:
	print("[14] accessibility.set_damage_vignette")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_damage_vignette(false) == true, "set false ok")
	_expect(s.get_damage_vignette() == false, "damage vignette disabled")
	_expect(s.set_damage_vignette(true) == true, "set true ok")
	_expect(s.get_damage_vignette() == true, "damage vignette enabled")

func _test_accessibility_set_motion_blur() -> void:
	print("[15] accessibility.set_motion_blur")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.set_motion_blur(false) == true, "set false ok")
	_expect(s.get_motion_blur() == false, "motion blur disabled")
	_expect(s.set_motion_blur(true) == true, "set true ok")
	_expect(s.get_motion_blur() == true, "motion blur enabled")

func _test_accessibility_set_keybinding() -> void:
	print("[16] accessibility.bind / unbind / get_binding")
	var s: RefCounted = AccessSettingsScript.new()
	_expect(s.bind("pause", KEY_SPACE) == true, "bind pause=SPACE ok")
	_expect(s.bind("pause", KEY_P) == true, "rebind pause=P ok")
	_expect(s.bind("speed", KEY_1) == true, "bind speed=1 ok")
	_expect(s.get_binding("pause") == KEY_P, "pause is now P")
	_expect(s.get_binding("speed") == KEY_1, "speed is 1")
	_expect(s.get_binding("unknown") == 0, "unknown returns 0")
	_expect(s.bind("", KEY_A) == false, "empty action rejected")
	_expect(s.bind("pause", -1) == false, "negative keycode rejected")
	# Max 16 distinct bindings enforced.
	for i in range(20):
		s.bind("k_%d" % i, KEY_F1 + i)
	var count: int = s.get_binding_count()
	_expect(count <= 16, "binding cap <=16 enforced (got %d)" % count)

func _test_accessibility_clear_keybinding() -> void:
	print("[17] accessibility.clear / clear_all")
	var s: RefCounted = AccessSettingsScript.new()
	s.bind("pause", KEY_SPACE)
	_expect(s.clear_binding("pause") == true, "clear pause ok")
	_expect(s.get_binding("pause") == 0, "pause cleared")
	_expect(s.clear_binding("never_bound") == false, "clear missing rejected")
	s.bind("a", KEY_A)
	s.bind("b", KEY_B)
	s.clear_all_bindings()
	_expect(s.get_binding_count() == 0, "clear_all empties map")

func _test_accessibility_get_state() -> void:
	print("[18] accessibility.get_state snapshot")
	var s: RefCounted = AccessSettingsScript.new()
	s.set_ui_zoom(1.2)
	s.set_font_size("large")
	s.set_color_mode("protanopia")
	s.bind("pause", KEY_SPACE)
	var st: Dictionary = s.get_state()
	_expect(float(st.get("ui_zoom", 0.0)) == 1.2, "ui_zoom in state")
	_expect(String(st.get("font_size", "")) == "large", "font_size in state")
	_expect(String(st.get("color_mode", "")) == "protanopia", "color_mode in state")
	_expect(typeof(st.get("keybindings", null)) == TYPE_DICTIONARY, "keybindings dict in state")
	_expect(int((st["keybindings"] as Dictionary).get("pause", 0)) == KEY_SPACE, "pause keybinding in state")

# --- signal presence ------------------------------------------------------

func _test_main_menu_signals_present() -> void:
	print("[19] main_menu signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_main_menu.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("esc_quit"), "esc_quit signal declared")
	_expect(sig_names.has("start_campaign"), "start_campaign signal declared")
	_expect(sig_names.has("continue_requested"), "continue_requested signal declared")
	_expect(sig_names.has("settings_requested"), "settings_requested signal declared")

func _test_base_hud_signals_present() -> void:
	print("[20] base_hud signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_base_hud.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("character_clicked"), "character_clicked signal declared")
	_expect(sig_names.has("role_clicked"), "role_clicked signal declared")
	_expect(sig_names.has("resource_clicked"), "resource_clicked signal declared")
	_expect(sig_names.has("facility_clicked"), "facility_clicked signal declared")

func _test_morning_report_signal_present() -> void:
	print("[21] morning_report signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_morning_report.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("start_today"), "start_today signal declared")

func _test_event_decision_signal_present() -> void:
	print("[22] event_decision signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_event_decision.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("option_chosen"), "option_chosen signal declared")

func _test_facility_upgrade_signal_present() -> void:
	print("[23] facility_upgrade signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_facility_upgrade.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("upgrade_requested"), "upgrade_requested signal declared")

func _test_inventory_signal_present() -> void:
	print("[24] inventory signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_inventory.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("item_moved"), "item_moved signal declared")

func _test_tutorial_signal_present() -> void:
	print("[25] tutorial signals present on script class")
	var script: GDScript = load("res://game/presentation/scenes/scene_tutorial.gd") as GDScript
	var sig_names: PackedStringArray = script.get_script_signal_list().map(func(s): return s.name)
	_expect(sig_names.has("step_advanced"), "step_advanced signal declared")
	_expect(sig_names.has("tutorial_skipped"), "tutorial_skipped signal declared")
	_expect(sig_names.has("tutorial_completed"), "tutorial_completed signal declared")