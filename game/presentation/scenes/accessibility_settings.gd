extends Control

## Accessibility settings UI. Backed by settings_accessibility.gd
## (RefCounted model). This scene is pure presentation: option rows +
## effect toggles + 16-slot keybind list.

const _PATH: String = "res://game/presentation/scenes/accessibility_settings.gd"

const AccessSettingsScript: GDScript = preload("res://game/presentation/ui/settings_accessibility.gd")

const ZOOM_OPTIONS: Array = [0.8, 1.0, 1.2, 1.6]
const FONT_OPTIONS: Array[String] = ["small", "standard", "large"]
const COLOR_OPTIONS: Array[String] = ["default", "protanopia", "deuteranopia", "high_contrast"]
const EFFECT_TOGGLES: Array[String] = ["screen_shake", "camera_shake", "damage_vignette", "motion_blur"]

signal closed()

var settings: RefCounted = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if settings == null:
		settings = AccessSettingsScript.new()
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("SettingsVBox/KeybindList/KeybindVBox"):
		# .tscn already defines the layout; bind zoom/font/color/effect buttons
		# so their pressed signals reach the right handlers.
		if settings == null:
			settings = AccessSettingsScript.new()
		var zoom_row: HBoxContainer = get_node_or_null("SettingsVBox/ZoomRow") as HBoxContainer
		if zoom_row != null:
			for i in range(ZOOM_OPTIONS.size()):
				var btn: Button = zoom_row.get_node_or_null("ZoomOption_%d" % i) as Button
				if btn != null and btn.pressed.get_connections().is_empty():
					btn.pressed.connect(_on_zoom_pressed.bind(float(ZOOM_OPTIONS[i])))
		var font_row: HBoxContainer = get_node_or_null("SettingsVBox/FontRow") as HBoxContainer
		if font_row != null:
			for i in range(FONT_OPTIONS.size()):
				var btn: Button = font_row.get_node_or_null("FontOption_%d" % i) as Button
				if btn != null and btn.pressed.get_connections().is_empty():
					btn.pressed.connect(_on_font_pressed.bind(String(FONT_OPTIONS[i])))
		var color_row: HBoxContainer = get_node_or_null("SettingsVBox/ColorRow") as HBoxContainer
		if color_row != null:
			for i in range(COLOR_OPTIONS.size()):
				var btn: Button = color_row.get_node_or_null("ColorOption_%d" % i) as Button
				if btn != null and btn.pressed.get_connections().is_empty():
					btn.pressed.connect(_on_color_pressed.bind(String(COLOR_OPTIONS[i])))
		var effects_row: HBoxContainer = get_node_or_null("SettingsVBox/EffectsRow") as HBoxContainer
		if effects_row != null:
			for i in range(EFFECT_TOGGLES.size()):
				var btn: Button = effects_row.get_node_or_null("EffectToggle_%s" % EFFECT_TOGGLES[i]) as Button
				if btn != null and btn.pressed.get_connections().is_empty():
					btn.pressed.connect(_on_effect_pressed.bind(String(EFFECT_TOGGLES[i])))
		var close_btn: Button = get_node_or_null("SettingsVBox/CloseButton") as Button
		if close_btn != null and close_btn.pressed.get_connections().is_empty():
			close_btn.pressed.connect(_on_close_pressed)
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "SettingsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = "无障碍设置"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Zoom row
	var zoom_row: HBoxContainer = HBoxContainer.new()
	zoom_row.name = "ZoomRow"
	zoom_row.add_theme_constant_override("separation", 8)
	var zoom_l: Label = Label.new()
	zoom_l.name = "ZoomLabel"
	zoom_l.text = "UI 缩放"
	zoom_l.add_theme_font_size_override("font_size", 16)
	zoom_row.add_child(zoom_l)
	for i in range(ZOOM_OPTIONS.size()):
		var btn: Button = Button.new()
		btn.name = "ZoomOption_%d" % i
		btn.text = "%d%%" % int(ZOOM_OPTIONS[i] * 100)
		btn.custom_minimum_size = Vector2(64, 32)
		btn.pressed.connect(_on_zoom_pressed.bind(float(ZOOM_OPTIONS[i])))
		zoom_row.add_child(btn)
	vbox.add_child(zoom_row)
	# Font size row
	var font_row: HBoxContainer = HBoxContainer.new()
	font_row.name = "FontRow"
	font_row.add_theme_constant_override("separation", 8)
	var font_l: Label = Label.new()
	font_l.name = "FontLabel"
	font_l.text = "字号"
	font_l.add_theme_font_size_override("font_size", 16)
	font_row.add_child(font_l)
	for i in range(FONT_OPTIONS.size()):
		var btn: Button = Button.new()
		btn.name = "FontOption_%d" % i
		btn.text = FONT_OPTIONS[i]
		btn.custom_minimum_size = Vector2(64, 32)
		btn.pressed.connect(_on_font_pressed.bind(String(FONT_OPTIONS[i])))
		font_row.add_child(btn)
	vbox.add_child(font_row)
	# Color mode row
	var color_row: HBoxContainer = HBoxContainer.new()
	color_row.name = "ColorRow"
	color_row.add_theme_constant_override("separation", 8)
	var color_l: Label = Label.new()
	color_l.name = "ColorLabel"
	color_l.text = "色觉模式"
	color_l.add_theme_font_size_override("font_size", 16)
	color_row.add_child(color_l)
	for i in range(COLOR_OPTIONS.size()):
		var btn: Button = Button.new()
		btn.name = "ColorOption_%d" % i
		btn.text = COLOR_OPTIONS[i]
		btn.custom_minimum_size = Vector2(96, 32)
		btn.pressed.connect(_on_color_pressed.bind(String(COLOR_OPTIONS[i])))
		color_row.add_child(btn)
	vbox.add_child(color_row)
	# Keybind list (16 slots)
	var kb_panel: PanelContainer = PanelContainer.new()
	kb_panel.name = "KeybindList"
	vbox.add_child(kb_panel)
	var kb_v: VBoxContainer = VBoxContainer.new()
	kb_v.name = "KeybindVBox"
	kb_panel.add_child(kb_v)
	for i in range(16):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "KeybindSlot_%d" % i
		var action_l: Label = Label.new()
		action_l.name = "ActionLabel"
		action_l.text = "动作 %d" % (i + 1)
		action_l.add_theme_font_size_override("font_size", 16)
		row.add_child(action_l)
		var bind_l: Label = Label.new()
		bind_l.name = "BindingLabel"
		bind_l.text = "—"
		bind_l.add_theme_font_size_override("font_size", 16)
		row.add_child(bind_l)
		kb_v.add_child(row)
	# Effects row (4 toggles)
	var eff_row: HBoxContainer = HBoxContainer.new()
	eff_row.name = "EffectsRow"
	eff_row.add_theme_constant_override("separation", 8)
	var eff_l: Label = Label.new()
	eff_l.name = "EffectsLabel"
	eff_l.text = "效果"
	eff_l.add_theme_font_size_override("font_size", 16)
	eff_row.add_child(eff_l)
	for i in range(EFFECT_TOGGLES.size()):
		var btn: Button = Button.new()
		btn.name = "EffectToggle_%s" % EFFECT_TOGGLES[i]
		btn.text = EFFECT_TOGGLES[i]
		btn.custom_minimum_size = Vector2(96, 32)
		btn.pressed.connect(_on_effect_pressed.bind(String(EFFECT_TOGGLES[i])))
		eff_row.add_child(btn)
	vbox.add_child(eff_row)
	# Close
	var close: Button = Button.new()
	close.name = "CloseButton"
	close.text = "关闭"
	close.custom_minimum_size = Vector2(96, 32)
	close.pressed.connect(_on_close_pressed)
	vbox.add_child(close)

func _on_zoom_pressed(zoom: float) -> void:
	if settings != null:
		settings.set_ui_zoom(zoom)

func _on_font_pressed(size_name: String) -> void:
	if settings != null:
		settings.set_font_size(size_name)

func _on_color_pressed(mode: String) -> void:
	if settings != null:
		settings.set_color_mode(mode)

func _on_effect_pressed(effect: String) -> void:
	if settings == null:
		return
	match effect:
		"screen_shake":
			settings.set_screen_shake(not bool(settings.get_screen_shake()))
		"camera_shake":
			settings.set_camera_shake(not bool(settings.get_camera_shake()))
		"damage_vignette":
			settings.set_damage_vignette(not bool(settings.get_damage_vignette()))
		"motion_blur":
			settings.set_motion_blur(not bool(settings.get_motion_blur()))

func _on_close_pressed() -> void:
	closed.emit()

func get_settings() -> RefCounted:
	return settings

func attach_settings(s: RefCounted) -> void:
	settings = s