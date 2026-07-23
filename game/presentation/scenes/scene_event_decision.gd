extends Control

## Event decision panel. Title + description + up to 4 option buttons,
## each with cost preview. Emits option_chosen(index, payload).

const _PATH: String = "res://game/presentation/scenes/scene_event_decision.gd"

const MAX_OPTIONS: int = 4

signal option_chosen(index: int, payload: Dictionary)

var _title_label: Label = null
var _description_label: RichTextLabel = null
var _option_list: VBoxContainer = null
var _current_event: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("DecisionVBox"):
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "DecisionVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "事件"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	_description_label = RichTextLabel.new()
	_description_label.name = "DescriptionLabel"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.custom_minimum_size = Vector2(640, 96)
	vbox.add_child(_description_label)
	_option_list = VBoxContainer.new()
	_option_list.name = "OptionList"
	vbox.add_child(_option_list)
	for i in range(MAX_OPTIONS):
		var btn: Button = Button.new()
		btn.name = "OptionButton_%d" % i
		btn.text = "选项 %d" % (i + 1)
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_option_list.add_child(btn)

## Set the event to display. payload = {
##   "id": String,
##   "title_zh": String,
##   "description": String (BBCode ok),
##   "options": [ {label_zh: String, cost_text: String, weight: float}, ... ]
## }
func set_event(payload: Dictionary) -> void:
	_current_event = payload.duplicate(true)
	if _title_label != null:
		_title_label.text = String(payload.get("title_zh", payload.get("id", "事件")))
	if _description_label != null:
		_description_label.text = String(payload.get("description", ""))
	_ensure_layout()
	if _option_list == null:
		return
	var opts: Array = payload.get("options", [])
	for i in range(MAX_OPTIONS):
		var btn_name: String = "OptionButton_%d" % i
		var btn_v: Node = _option_list.get_node_or_null(btn_name)
		if btn_v == null:
			continue
		if i < opts.size() and typeof(opts[i]) == TYPE_DICTIONARY:
			var opt: Dictionary = opts[i]
			var label: String = String(opt.get("label_zh", "选项 %d" % (i + 1)))
			var cost: String = String(opt.get("cost_text", ""))
			if cost != "":
				label = "%s  [%s]" % [label, cost]
			(btn_v as Button).text = label
			(btn_v as Button).disabled = false
		else:
			(btn_v as Button).text = "—"
			(btn_v as Button).disabled = true

func _on_option_pressed(idx: int) -> void:
	var opts: Array = _current_event.get("options", [])
	if idx < 0 or idx >= opts.size():
		push_warning("[EventDecision] option index out of range: %d" % idx)
		return
	var opt: Dictionary = opts[idx] if typeof(opts[idx]) == TYPE_DICTIONARY else {}
	option_chosen.emit(idx, opt)