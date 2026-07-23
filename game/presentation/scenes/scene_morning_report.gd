extends Control

## Morning Report scene (策划03 §2.3). Shown at the start of each day.
##
## Layout:
##   - Title: "第 N 天  晨间报告"
##   - 5 summary lines (consumption / injuries / events / relationships / pressure)
##   - "开始今天" button -> start_today signal -> state_machine.advance
##
## Pure scene script: receives a report Dictionary (matching MorningReport.build
## output) and renders it. No direct GameSession dependency.

const _PATH: String = "res://game/presentation/scenes/scene_morning_report.gd"

signal start_today()

var _summary_list: VBoxContainer = null
var _title_label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_layout()

func _ensure_layout() -> void:
	if has_node("ReportVBox/StartTodayButton"):
		# .tscn already defines the layout; bind instance variables + button.
		_title_label = get_node_or_null("ReportVBox/TitleLabel") as Label
		_summary_list = get_node_or_null("ReportVBox/SummaryList") as VBoxContainer
		var btn: Button = get_node_or_null("ReportVBox/StartTodayButton") as Button
		if btn != null and btn.pressed.get_connections().is_empty():
			btn.pressed.connect(_on_start_today_pressed)
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ReportVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "第 1 天  晨间报告"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	_summary_list = VBoxContainer.new()
	_summary_list.name = "SummaryList"
	vbox.add_child(_summary_list)
	for i in range(5):
		var row: Label = Label.new()
		row.name = "SummaryLine_%d" % i
		row.text = ""
		row.add_theme_font_size_override("font_size", 16)
		_summary_list.add_child(row)
	var btn: Button = Button.new()
	btn.name = "StartTodayButton"
	btn.text = "开始今天"
	btn.custom_minimum_size = Vector2(160, 32)
	btn.pressed.connect(_on_start_today_pressed)
	vbox.add_child(btn)

func set_report(report: Dictionary) -> void:
	if _title_label != null:
		_title_label.text = "第 %d 天  晨间报告" % int(report.get("day", 1))
	_ensure_layout()
	if _summary_list == null:
		return
	# Compose 5 summary lines from the report.
	var consumed: Dictionary = report.get("consumed", {})
	var injuries: Array = report.get("injuries", [])
	var events: Array = report.get("events", [])
	var relationships: Array = report.get("relationships", [])
	var pressure: float = float(report.get("city_pressure", 0.0))
	var lines: Array[String] = []
	lines.append("昨日消耗 food=%d water=%d material=%d parts=%d medical=%d fuel=%d ammo=%d" % [
		int(consumed.get("food", 0)), int(consumed.get("water", 0)),
		int(consumed.get("material", 0)), int(consumed.get("parts", 0)),
		int(consumed.get("medical", 0)), int(consumed.get("fuel", 0)),
		int(consumed.get("ammo", 0))])
	lines.append("伤病 %d 例" % injuries.size())
	lines.append("事件 %d 件" % events.size())
	lines.append("关系变动 %d 条" % relationships.size())
	lines.append("城市压力 %.1f" % pressure)
	for i in range(5):
		var row_name: String = "SummaryLine_%d" % i
		var node_v: Node = _summary_list.get_node_or_null(row_name)
		if node_v != null and node_v is Label:
			(node_v as Label).text = lines[i] if i < lines.size() else ""

func _on_start_today_pressed() -> void:
	start_today.emit()