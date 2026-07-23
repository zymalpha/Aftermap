extends Control

## 5-step first-day tutorial. step1: 基地建立, step2: 角色分配岗位,
## step3: 第一支外出队, step4: 战术暂停命令, step5: 返回结算.
##
## Navigation: NextButton (next step) and SkipButton (skip all).

const _PATH: String = "res://game/presentation/scenes/scene_tutorial.gd"

signal step_advanced(step_index: int)
signal tutorial_skipped()
signal tutorial_completed()

const STEPS: Array = [
	{
		"title": "第 1 步 / 5",
		"body": "欢迎来到 AFTERMAP。首先建立你的基地：选择起点城市，搭建 1-2 个基础设施（sleep + kitchen / water）。\n\n要点：物资会自动消耗；每天结束时检查库存。",
	},
	{
		"title": "第 2 步 / 5",
		"body": "为每个角色分配岗位。每个岗位最多 3 人，技能越高效率越高。\n\n推荐开局：cook + water + watch 各 1 人。",
	},
	{
		"title": "第 3 步 / 5",
		"body": "组建第一支外出队（party），前往最近 POI 搜索补给。\n\n提示：提前用 JOB 调度保留 1 人在 watch。",
	},
	{
		"title": "第 4 步 / 5",
		"body": "战术地图支持暂停与 2x 倍速。点击 单位 → 移动 / 攻击 / 搜索。\n\n按 Space 暂停/继续，按 1/2 切换 1x/2x。",
	},
	{
		"title": "第 5 步 / 5",
		"body": "外出队返回后，进入 DUSK_CHOICE → NIGHT_RESOLVE 结算。\n\n关注城市压力与伤病；第二天开始新一轮晨间报告。",
	},
]

var _step_index: int = 0
var _title_label: Label = null
var _step_label: Label = null
var _step_body: RichTextLabel = null
var _next_button: Button = null
var _skip_button: Button = null
var _complete_button: Button = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()
	_render_step()

func _ensure_layout() -> void:
	if has_node("TutorialVBox"):
		return
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "TutorialVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "首日引导"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	var content: PanelContainer = PanelContainer.new()
	content.name = "StepContent"
	content.custom_minimum_size = Vector2(720, 256)
	vbox.add_child(content)
	_step_label = Label.new()
	_step_label.name = "StepLabel"
	_step_label.text = "第 1 步 / 5"
	_step_label.add_theme_font_size_override("font_size", 24)
	content.add_child(_step_label)
	_step_body = RichTextLabel.new()
	_step_body.name = "StepBody"
	_step_body.bbcode_enabled = true
	_step_body.fit_content = true
	_step_body.custom_minimum_size = Vector2(720, 192)
	_step_body.add_theme_font_size_override("normal_font_size", 16)
	content.add_child(_step_body)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.name = "NavBar"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 16)
	vbox.add_child(nav)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "下一步"
	_next_button.custom_minimum_size = Vector2(96, 32)
	_next_button.pressed.connect(_on_next_pressed)
	nav.add_child(_next_button)
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "跳过教程"
	_skip_button.custom_minimum_size = Vector2(96, 32)
	_skip_button.pressed.connect(_on_skip_pressed)
	nav.add_child(_skip_button)

func _render_step() -> void:
	if _step_label != null:
		_step_label.text = String(STEPS[_step_index].get("title", ""))
	if _step_body != null:
		_step_body.text = String(STEPS[_step_index].get("body", ""))
	if _next_button != null:
		if _step_index >= STEPS.size() - 1:
			_next_button.text = "完成"
		else:
			_next_button.text = "下一步"

func _on_next_pressed() -> void:
	if _step_index >= STEPS.size() - 1:
		tutorial_completed.emit()
		return
	_step_index += 1
	_render_step()
	step_advanced.emit(_step_index)

func _on_skip_pressed() -> void:
	tutorial_skipped.emit()

func reset() -> void:
	_step_index = 0
	_render_step()

func get_step_index() -> int:
	return _step_index