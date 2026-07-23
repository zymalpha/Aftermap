extends Control

## Base HUD overlay shown during BASE_PLANNING and DAY_ACTION.
## Layout (1280x720):
##   - Top bar: day + city clock + city pressure gauge (0-100 ring)
##   - Left: 6 facility status icons + tier
##   - Left-bottom: 4-12 character cards (avatar + 6 stats)
##   - Right-bottom: 7 resource bars (food/water/.../ammo)
##   - Center: job assignment panel (click char -> click role)
##
## This script is intentionally thin: it renders from a Dictionary payload
## supplied via update_from_session(); game logic stays in domain code.

const _PATH: String = "res://game/presentation/scenes/scene_base_hud.gd"

const RESOURCE_KEYS: Array[String] = [
	"food", "water", "material", "parts", "medical", "fuel", "ammo",
]
const STAT_KEYS: Array[String] = [
	"hp", "hunger", "energy", "morale", "stress", "infection",
]
const FACILITY_KINDS: Array[String] = [
	"sleep", "storage", "kitchen", "water", "medical", "power",
]
const ROLE_IDS: Array[String] = [
	"cook", "water", "medical", "engineering", "cleaning", "garden",
	"watch", "guard", "radio", "hauling", "rest", "free",
]

signal character_clicked(character_id: String)
signal role_clicked(role_id: String)
signal resource_clicked(resource_key: String)
signal facility_clicked(facility_id: String)

var _selected_character: String = ""
var _session_payload: Dictionary = {}

var _top_bar: HBoxContainer = null
var _day_label: Label = null
var _clock_label: Label = null
var _pressure_label: Label = null
var _pressure_progress: ProgressBar = null
var _facility_box: VBoxContainer = null
var _character_box: VBoxContainer = null
var _resource_box: VBoxContainer = null
var _role_grid: GridContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("TopBar/DayLabel"):
		# .tscn already defines the layout; bind every instance variable
		# so update_from_session() can address the existing nodes.
		_top_bar = get_node_or_null("TopBar") as HBoxContainer
		_day_label = get_node_or_null("TopBar/DayLabel") as Label
		_clock_label = get_node_or_null("TopBar/ClockLabel") as Label
		_pressure_label = get_node_or_null("TopBar/PressureLabel") as Label
		_pressure_progress = get_node_or_null("TopBar/PressureProgress") as ProgressBar
		_facility_box = get_node_or_null("FacilityPanel/FacilityBox") as VBoxContainer
		_character_box = get_node_or_null("CharacterPanel/CharacterBox") as VBoxContainer
		_resource_box = get_node_or_null("ResourcePanel/ResourceBox") as VBoxContainer
		_role_grid = get_node_or_null("RolePanel/RoleGrid") as GridContainer
		if _role_grid != null:
			for role_id in ROLE_IDS:
				var role_btn: Button = _role_grid.get_node_or_null("Role_%s" % role_id) as Button
				if role_btn != null and role_btn.pressed.get_connections().is_empty():
					role_btn.pressed.connect(_on_role_pressed.bind(role_id))
		return
	# Top bar
	_top_bar = HBoxContainer.new()
	_top_bar.name = "TopBar"
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size = Vector2(0, 32)
	_top_bar.add_theme_constant_override("separation", 16)
	add_child(_top_bar)
	_day_label = Label.new()
	_day_label.name = "DayLabel"
	_day_label.text = "Day 1"
	_day_label.add_theme_font_size_override("font_size", 24)
	_top_bar.add_child(_day_label)
	_clock_label = Label.new()
	_clock_label.name = "ClockLabel"
	_clock_label.text = "08:00"
	_clock_label.add_theme_font_size_override("font_size", 16)
	_top_bar.add_child(_clock_label)
	_pressure_label = Label.new()
	_pressure_label.name = "PressureLabel"
	_pressure_label.text = "城市压力 0"
	_pressure_label.add_theme_font_size_override("font_size", 16)
	_top_bar.add_child(_pressure_label)
	_pressure_progress = ProgressBar.new()
	_pressure_progress.name = "PressureProgress"
	_pressure_progress.max_value = 100.0
	_pressure_progress.value = 0.0
	_pressure_progress.custom_minimum_size = Vector2(160, 16)
	_top_bar.add_child(_pressure_progress)
	# Facilities (left)
	var fac_panel: PanelContainer = PanelContainer.new()
	fac_panel.name = "FacilityPanel"
	fac_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fac_panel.offset_top = 32
	fac_panel.offset_bottom = 720
	_facility_box = VBoxContainer.new()
	_facility_box.name = "FacilityBox"
	fac_panel.add_child(_facility_box)
	add_child(fac_panel)
	for i in range(FACILITY_KINDS.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Facility_%s" % FACILITY_KINDS[i]
		var icon: ColorRect = ColorRect.new()
		icon.name = "FacilityIcon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.color = _facility_color(FACILITY_KINDS[i])
		row.add_child(icon)
		var lbl: Label = Label.new()
		lbl.name = "FacilityLabel"
		lbl.text = FACILITY_KINDS[i]
		lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(lbl)
		_facility_box.add_child(row)
	# Resources (right bottom)
	var res_panel: PanelContainer = PanelContainer.new()
	res_panel.name = "ResourcePanel"
	res_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	res_panel.offset_left = -256
	res_panel.offset_top = -256
	_resource_box = VBoxContainer.new()
	_resource_box.name = "ResourceBox"
	res_panel.add_child(_resource_box)
	add_child(res_panel)
	for i in range(RESOURCE_KEYS.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Resource_%s" % RESOURCE_KEYS[i]
		var bar: ProgressBar = ProgressBar.new()
		bar.name = "ResourceBar"
		bar.max_value = 100.0
		bar.value = 0.0
		bar.custom_minimum_size = Vector2(160, 16)
		row.add_child(bar)
		var lbl: Label = Label.new()
		lbl.name = "ResourceLabel"
		lbl.text = RESOURCE_KEYS[i]
		lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(lbl)
		_resource_box.add_child(row)
	# Character cards (left bottom)
	var char_panel: PanelContainer = PanelContainer.new()
	char_panel.name = "CharacterPanel"
	char_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	char_panel.offset_right = 256
	char_panel.offset_top = -256
	_character_box = VBoxContainer.new()
	_character_box.name = "CharacterBox"
	char_panel.add_child(_character_box)
	add_child(char_panel)
	# Role assignment grid (center)
	var role_panel: PanelContainer = PanelContainer.new()
	role_panel.name = "RolePanel"
	role_panel.set_anchors_preset(Control.PRESET_CENTER)
	role_panel.offset_left = -192
	role_panel.offset_right = 192
	role_panel.offset_top = -96
	role_panel.offset_bottom = 96
	_role_grid = GridContainer.new()
	_role_grid.name = "RoleGrid"
	_role_grid.columns = 4
	_role_grid.add_theme_constant_override("h_separation", 8)
	_role_grid.add_theme_constant_override("v_separation", 8)
	role_panel.add_child(_role_grid)
	add_child(role_panel)
	for i in range(ROLE_IDS.size()):
		var btn: Button = Button.new()
		btn.name = "Role_%s" % ROLE_IDS[i]
		btn.text = ROLE_IDS[i]
		btn.custom_minimum_size = Vector2(64, 32)
		btn.pressed.connect(_on_role_pressed.bind(ROLE_IDS[i]))
		_role_grid.add_child(btn)

func _facility_color(kind: String) -> Color:
	match kind:
		"sleep": return Color(0.4, 0.4, 0.7)
		"storage": return Color(0.5, 0.4, 0.3)
		"kitchen": return Color(0.7, 0.4, 0.3)
		"water": return Color(0.3, 0.5, 0.8)
		"medical": return Color(0.8, 0.3, 0.5)
		"power": return Color(0.8, 0.7, 0.3)
	return Color(0.5, 0.5, 0.5)

## Public API ----------------------------------------------------------------

func update_from_session(payload: Dictionary) -> void:
	_session_payload = payload.duplicate(true)
	_redraw()

func _redraw() -> void:
	if _day_label != null:
		_day_label.text = "Day %d" % int(_session_payload.get("day", 1))
	if _clock_label != null:
		var minutes: int = int(_session_payload.get("city_minutes", 0))
		var hh: int = minutes / 60
		var mm: int = minutes % 60
		_clock_label.text = "%02d:%02d" % [hh, mm]
	if _pressure_label != null and _pressure_progress != null:
		var p: float = float(_session_payload.get("city_pressure", 0.0))
		_pressure_label.text = "城市压力 %d" % int(round(p))
		_pressure_progress.value = clampf(p, 0.0, 100.0)
	# Resources
	if _resource_box != null:
		var res: Dictionary = _session_payload.get("resources", {})
		for i in range(RESOURCE_KEYS.size()):
			var row_name: String = "Resource_%s" % RESOURCE_KEYS[i]
			if _resource_box.has_node(row_name):
				var row: Node = _resource_box.get_node(row_name)
				var bar: ProgressBar = row.get_node("ResourceBar") as ProgressBar
				var label: Label = row.get_node("ResourceLabel") as Label
				var v: int = int(res.get(RESOURCE_KEYS[i], 0))
				bar.value = clampf(float(v), 0.0, 100.0)
				label.text = "%s %d" % [RESOURCE_KEYS[i], v]
	# Characters
	if _character_box != null:
		_clear_children(_character_box)
		var chars: Array = _session_payload.get("characters", [])
		for ch in chars:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			var card: HBoxContainer = HBoxContainer.new()
			card.name = "CharCard_%s" % String(ch.get("id", ""))
			var avatar: ColorRect = ColorRect.new()
			avatar.name = "Avatar"
			avatar.custom_minimum_size = Vector2(24, 24)
			avatar.color = Color(0.4, 0.6, 0.4)
			card.add_child(avatar)
			var info: Label = Label.new()
			info.name = "Info"
			info.text = String(ch.get("display_name_zh", ch.get("id", "?")))
			info.add_theme_font_size_override("font_size", 16)
			card.add_child(info)
			var stats_d: Dictionary = ch.get("stats", {})
			var stats_l: Label = Label.new()
			stats_l.name = "Stats"
			stats_l.text = _format_stats_line(stats_d)
			stats_l.add_theme_font_size_override("font_size", 16)
			card.add_child(stats_l)
			var sel: Button = Button.new()
			sel.name = "Select"
			sel.text = "选择"
			sel.custom_minimum_size = Vector2(48, 24)
			sel.pressed.connect(_on_character_pressed.bind(String(ch.get("id", ""))))
			card.add_child(sel)
			_character_box.add_child(card)

func _format_stats_line(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for k in STAT_KEYS:
		parts.append("%s=%d" % [k, int(stats.get(k, 0))])
	return " ".join(parts)

func _clear_children(parent: Node) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()

func _on_character_pressed(cid: String) -> void:
	_selected_character = cid
	character_clicked.emit(cid)

func _on_role_pressed(role_id: String) -> void:
	if _selected_character == "":
		push_warning("[BaseHUD] role %s clicked before a character was selected" % role_id)
		return
	role_clicked.emit(role_id)

func get_selected_character() -> String:
	return _selected_character

func set_selected_character(cid: String) -> void:
	_selected_character = cid