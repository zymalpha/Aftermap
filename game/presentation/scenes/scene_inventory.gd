extends Control

## Inventory panel. Left: base stockpile (7 buckets). Right: selected
## character's equipment + items. Click-to-move or drag-and-drop via
## Godot's _get_drag_data / _can_drop_data / _drop_data hooks.

const _PATH: String = "res://game/presentation/scenes/scene_inventory.gd"

const RESOURCE_KEYS: Array[String] = [
	"food", "water", "material", "parts", "medical", "fuel", "ammo",
]

signal item_moved(item_id: String, from: String, to: String, qty: int)
signal back_to_menu()

var _resource_list: VBoxContainer = null
var _equipment_list: VBoxContainer = null
var _selected_character: String = ""
var _selected_item: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("InventoryVBox/InventoryHBox/BaseStockPanel/ResourceList"):
		# .tscn already defines the layout; bind _resource_list and the
		# Move buttons (which need pressed -> _on_resource_move_pressed
		# to actually fire).
		_resource_list = get_node_or_null("InventoryVBox/InventoryHBox/BaseStockPanel/ResourceList") as VBoxContainer
		if _resource_list != null:
			for key in RESOURCE_KEYS:
				var move_btn: Button = _resource_list.get_node_or_null("Resource_%s/MoveButton" % key) as Button
				if move_btn != null and move_btn.pressed.get_connections().is_empty():
					move_btn.pressed.connect(_on_resource_move_pressed.bind(key))
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "InventoryVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = "库存与装备"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "InventoryHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 32)
	vbox.add_child(hbox)
	var stock_panel: PanelContainer = PanelContainer.new()
	stock_panel.name = "BaseStockPanel"
	stock_panel.custom_minimum_size = Vector2(320, 320)
	hbox.add_child(stock_panel)
	_resource_list = VBoxContainer.new()
	_resource_list.name = "ResourceList"
	stock_panel.add_child(_resource_list)
	for i in range(RESOURCE_KEYS.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Resource_%s" % RESOURCE_KEYS[i]
		var lbl: Label = Label.new()
		lbl.name = "ResourceLabel"
		lbl.text = "%s 0" % RESOURCE_KEYS[i]
		lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(lbl)
		var move_btn: Button = Button.new()
		move_btn.name = "MoveButton"
		move_btn.text = "→角色"
		move_btn.custom_minimum_size = Vector2(64, 24)
		move_btn.pressed.connect(_on_resource_move_pressed.bind(RESOURCE_KEYS[i]))
		row.add_child(move_btn)
		_resource_list.add_child(row)
	var eq_panel: PanelContainer = PanelContainer.new()
	eq_panel.name = "CharEquipmentPanel"
	eq_panel.custom_minimum_size = Vector2(320, 320)
	hbox.add_child(eq_panel)
	var eq_v: VBoxContainer = VBoxContainer.new()
	eq_v.name = "EquipmentList"
	eq_panel.add_child(eq_v)
	var char_l: Label = Label.new()
	char_l.name = "CharLabel"
	char_l.text = "角色：—"
	char_l.add_theme_font_size_override("font_size", 16)
	eq_v.add_child(char_l)
	for i in range(3):
		var slot: HBoxContainer = HBoxContainer.new()
		slot.name = "EquipSlot_%d" % i
		var slot_l: Label = Label.new()
		slot_l.name = "EquipSlotLabel"
		slot_l.text = "槽位 %d —" % (i + 1)
		slot_l.add_theme_font_size_override("font_size", 16)
		slot.add_child(slot_l)
		eq_v.add_child(slot)
	var item_l: Label = Label.new()
	item_l.name = "ItemLabel"
	item_l.text = "物品 —"
	item_l.add_theme_font_size_override("font_size", 16)
	eq_v.add_child(item_l)

## Set the inventory snapshot. payload = {
##   "base_resources": { food, water, ... },
##   "selected_character": "c_alex" | "",
##   "items": [ { id, name_zh, qty } ]
## }
func set_inventory(payload: Dictionary) -> void:
	_ensure_layout()
	_selected_character = String(payload.get("selected_character", ""))
	var res: Dictionary = payload.get("base_resources", {})
	for i in range(RESOURCE_KEYS.size()):
		var row_name: String = "Resource_%s" % RESOURCE_KEYS[i]
		if _resource_list == null:
			break
		var row_v: Node = _resource_list.get_node_or_null(row_name)
		if row_v == null:
			continue
		var lbl: Label = row_v.get_node("ResourceLabel") as Label
		lbl.text = "%s %d" % [RESOURCE_KEYS[i], int(res.get(RESOURCE_KEYS[i], 0))]
	# Items list
	var eq_v: Node = get_node_or_null("InventoryVBox/InventoryHBox/CharEquipmentPanel/EquipmentList")
	if eq_v != null:
		var char_l: Label = eq_v.get_node("CharLabel") as Label
		char_l.text = "角色：%s" % (_selected_character if _selected_character != "" else "—")
		var items: Array = payload.get("items", [])
		var idx: int = 0
		for ch in eq_v.get_children():
			if ch is HBoxContainer and ch.name.begins_with("EquipSlot_"):
				var slot_l: Label = ch.get_node("EquipSlotLabel") as Label
				if idx < items.size() and typeof(items[idx]) == TYPE_DICTIONARY:
					var it: Dictionary = items[idx]
					slot_l.text = "槽位 %d %s x%d" % [idx + 1, String(it.get("name_zh", it.get("id", "?"))), int(it.get("qty", 0))]
				else:
					slot_l.text = "槽位 %d —" % (idx + 1)
				idx += 1

func _on_resource_move_pressed(resource_key: String) -> void:
	if _selected_character == "":
		push_warning("[Inventory] move before character selection")
		return
	item_moved.emit(resource_key, "base", "char:" + _selected_character, 1)

func set_selected_character(cid: String) -> void:
	_selected_character = cid

func get_selected_character() -> String:
	return _selected_character