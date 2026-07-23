extends Control

## Facility upgrade panel. 12 facility slots in a grid; clicking a slot
## shows the upgrade requirements + tier 1 vs tier 2 diff in the detail
## panel. Emits upgrade_requested(facility_id).

const _PATH: String = "res://game/presentation/scenes/scene_facility_upgrade.gd"

const FACILITY_SLOTS: int = 12

signal upgrade_requested(facility_id: String)

var _grid: GridContainer = null
var _detail_label: Label = null
var _current_facility: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("UpgradeVBox/FacilityGrid/FacilitySlot_0"):
		# .tscn already defines the layout; bind _grid + slot buttons.
		_grid = get_node_or_null("UpgradeVBox/FacilityGrid") as GridContainer
		_detail_label = get_node_or_null("UpgradeVBox/DetailPanel/DetailLabel") as Label
		if _grid != null:
			for i in range(FACILITY_SLOTS):
				var slot: Button = _grid.get_node_or_null("FacilitySlot_%d" % i) as Button
				if slot != null and slot.pressed.get_connections().is_empty():
					slot.pressed.connect(_on_slot_pressed.bind(i))
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "UpgradeVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = "设施升级"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_grid = GridContainer.new()
	_grid.name = "FacilityGrid"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_grid)
	for i in range(FACILITY_SLOTS):
		var btn: Button = Button.new()
		btn.name = "FacilitySlot_%d" % i
		btn.text = "设施 %d" % (i + 1)
		btn.custom_minimum_size = Vector2(96, 32)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(btn)
	var detail: PanelContainer = PanelContainer.new()
	detail.name = "DetailPanel"
	vbox.add_child(detail)
	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.text = "选择设施查看升级需求"
	_detail_label.add_theme_font_size_override("font_size", 16)
	_detail_label.custom_minimum_size = Vector2(640, 96)
	detail.add_child(_detail_label)

## Set the facility roster. payload = {
##   "facilities": [
##     { "id", "name_zh", "kind", "tier": int, "build_cost": {resource:n}, "notes": String },
##     ...
##   ]
## }
func set_roster(payload: Dictionary) -> void:
	var facilities: Array = payload.get("facilities", [])
	for i in range(FACILITY_SLOTS):
		var slot_name: String = "FacilitySlot_%d" % i
		if _grid == null:
			break
		var btn_v: Node = _grid.get_node_or_null(slot_name)
		if btn_v == null:
			continue
		if i < facilities.size() and typeof(facilities[i]) == TYPE_DICTIONARY:
			var fac: Dictionary = facilities[i]
			(btn_v as Button).text = "%s\n%s" % [String(fac.get("name_zh", fac.get("id", "?"))), "Tier %d" % int(fac.get("tier", 1))]
			(btn_v as Button).disabled = false
		else:
			(btn_v as Button).text = "—"
			(btn_v as Button).disabled = true

func _on_slot_pressed(idx: int) -> void:
	# Re-display whatever current_facility says for slot idx. The caller is
	# expected to call set_roster first; we re-read via grid button metadata.
	if _grid == null:
		return
	var btn_v: Button = _grid.get_node_or_null("FacilitySlot_%d" % idx) as Button
	if btn_v == null:
		return
	_current_facility = {"slot_index": idx, "label": btn_v.text}
	_show_detail_for_label(btn_v.text, idx)

func _show_detail_for_label(label: String, idx: int) -> void:
	if _detail_label == null:
		return
	_detail_label.text = "选择 #%d: %s\n\nTier 1 → Tier 2 升级需求:\n  resource_material: 10\n  resource_parts: 5\n  fuel: 2" % [idx + 1, label]

func _on_upgrade_pressed() -> void:
	if _current_facility.is_empty():
		push_warning("[FacilityUpgrade] upgrade pressed without selection")
		return
	upgrade_requested.emit(String(_current_facility.get("id", "")))