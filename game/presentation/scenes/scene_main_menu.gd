extends Control

## Main menu scene. AFTERMAP title + apocalypse coordinates + city chooser.
##
## Layout (1280x720 reference):
##   - Title (AFTERMAP / 末日坐标) anchored top-center
##   - 4 buttons: 开始战役 / 继续战役 / 设置 / 离开
##   - 城市选择子面板 (南京 + 占位) 在开始战役按下后弹出
##   - esc_quit signal: emitted when 离开 pressed or ESC pressed
##
## All icons are 16/24/32 px slots; nearest-pixel scale per Stage 3 rules.
## No @tool. Static typed. Pure scene + script, no third-party deps.

const _PATH: String = "res://game/presentation/scenes/scene_main_menu.gd"

signal esc_quit()
signal start_campaign(city_id: String)
signal continue_requested()
signal settings_requested()

# Static spec: cities shown in the city picker. Keys are content ids.
const CITY_CHOICES: Array = [
	{"id": "nanjing", "label_zh": "南京", "subtitle": "六朝古都 · 长江防线", "enabled": true},
	{"id": "placeholder_east", "label_zh": "上海（占位）", "subtitle": "黄浦江畔", "enabled": false},
	{"id": "placeholder_west", "label_zh": "重庆（占位）", "subtitle": "山城 · 雾都", "enabled": false},
]

var _city_panel: PanelContainer = null
var _selected_city: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()
	_refresh_button_states()

func _ensure_layout() -> void:
	if has_node("MainVBox"):
		return
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "MainVBox"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = "AFTERMAP"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub: Label = Label.new()
	sub.name = "SubtitleLabel"
	sub.text = "末  日  坐  标"
	sub.add_theme_font_size_override("font_size", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var coords: Label = Label.new()
	coords.name = "CoordsLabel"
	coords.text = "32.0603°N  118.7969°E"
	coords.add_theme_font_size_override("font_size", 16)
	coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(coords)

	var spacer: Control = Control.new()
	spacer.name = "Spacer1"
	spacer.custom_minimum_size = Vector2(0, 32)
	root.add_child(spacer)

	# Buttons (icon-sized 24 px height via custom_minimum_size).
	var btn_grid: GridContainer = GridContainer.new()
	btn_grid.name = "ButtonGrid"
	btn_grid.columns = 1
	btn_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_grid.add_theme_constant_override("h_separation", 8)
	btn_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(btn_grid)

	var b_new: Button = _make_button("StartCampaignButton", "开始战役")
	b_new.pressed.connect(_on_start_campaign_pressed)
	btn_grid.add_child(b_new)

	var b_cont: Button = _make_button("ContinueButton", "继续战役")
	b_cont.pressed.connect(_on_continue_pressed)
	btn_grid.add_child(b_cont)

	var b_set: Button = _make_button("SettingsButton", "设置")
	b_set.pressed.connect(_on_settings_pressed)
	btn_grid.add_child(b_set)

	var b_quit: Button = _make_button("QuitButton", "离开")
	b_quit.pressed.connect(_on_quit_pressed)
	btn_grid.add_child(b_quit)

	# City picker panel (hidden until 开始战役 pressed).
	_ensure_city_panel()

func _make_button(node_name: String, text: String) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(192, 32)
	return b

func _ensure_city_panel() -> void:
	if _city_panel != null and is_instance_valid(_city_panel):
		return
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CityPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(384, 192)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "CityPanelVBox"
	panel.add_child(vbox)
	var title_l: Label = Label.new()
	title_l.name = "CityPanelTitle"
	title_l.text = "选择起点城市"
	title_l.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_l)
	for i in range(CITY_CHOICES.size()):
		var c: Dictionary = CITY_CHOICES[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "CityRow_%s" % String(c.get("id", ""))
		vbox.add_child(row)
		var btn: Button = Button.new()
		btn.name = "CityButton_%s" % String(c.get("id", ""))
		btn.text = String(c.get("label_zh", ""))
		btn.disabled = not bool(c.get("enabled", false))
		btn.pressed.connect(_on_city_button_pressed.bind(String(c.get("id", ""))))
		row.add_child(btn)
		var sub_l: Label = Label.new()
		sub_l.name = "CitySubLabel"
		sub_l.text = "  " + String(c.get("subtitle", ""))
		sub_l.add_theme_font_size_override("font_size", 16)
		row.add_child(sub_l)
	var cancel: Button = Button.new()
	cancel.name = "CityPanelCancel"
	cancel.text = "取消"
	cancel.pressed.connect(_on_city_cancel_pressed)
	vbox.add_child(cancel)
	add_child(panel)
	_city_panel = panel

func _refresh_button_states() -> void:
	# Continue is always enabled in the scaffold (real save-detection comes
	# later). Setting + Quit always enabled.
	pass

func _on_start_campaign_pressed() -> void:
	if _city_panel == null:
		_ensure_city_panel()
	_city_panel.visible = true
	_city_panel.set_anchors_preset(Control.PRESET_CENTER)

func _on_continue_pressed() -> void:
	continue_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_quit_pressed() -> void:
	esc_quit.emit()

func _on_city_button_pressed(city_id: String) -> void:
	_selected_city = city_id
	_city_panel.visible = false
	start_campaign.emit(city_id)

func _on_city_cancel_pressed() -> void:
	_city_panel.visible = false

## Public API ----------------------------------------------------------------

func get_selected_city() -> String:
	return _selected_city

func hide_city_panel() -> void:
	if _city_panel != null and is_instance_valid(_city_panel):
		_city_panel.visible = false

## Input --------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		esc_quit.emit()
		get_viewport().set_input_as_handled()