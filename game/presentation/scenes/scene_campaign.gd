extends Control

const Rules: GDScript = preload("res://game/domain/campaign/campaign_actions.gd")
const Copy: GDScript = preload("res://game/presentation/ui/campaign_text.gd")
const Style: GDScript = preload("res://game/presentation/ui/survival_theme.gd")
const Board: GDScript = preload("res://game/presentation/ui/tactical_board.gd")
const District: GDScript = preload("res://game/presentation/ui/district_map.gd")

var app: RefCounted
var state: Dictionary = {}
var selected_character: String = "chr_scout_wang"
var selected_location: String = "grocery"
var tab: String = "explore"
var shoot_mode: bool = false
var _content: VBoxContainer
var _status: Label
var _board: Control
var _refresh_pending: bool = false
var _dialog: Window

func _ready() -> void:
	theme = Style.create()
	app = get_tree().root.get_meta("app",null)
	var background: ColorRect = ColorRect.new()
	background.color = Style.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,22)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation",14)
	margin.add_child(_content)
	if app != null:
		app.campaign_changed.connect(_schedule_refresh)
	_refresh()

func _schedule_refresh() -> void:
	if _refresh_pending: return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if app == null or app.session == null: return
	state = app.session.base_state.get("campaign",{})
	if state.is_empty(): return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_board = null
	var header: HBoxContainer = HBoxContainer.new()
	_content.add_child(header)
	var title: VBoxContainer = VBoxContainer.new()
	header.add_child(title)
	_label(title,"AFTERMAP  /  末日坐标",25,Style.TEXT)
	_label(title,"南京避难所  ·  第 %02d 天" % int(app.session.clock.current_day),16,Style.MUTED)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var objective: VBoxContainer = VBoxContainer.new()
	objective.custom_minimum_size.x = 285
	header.add_child(objective)
	_label(objective,"短波联络  %d%%  /  第 7 天起可获救" % int(state.signal),16,Style.ACCENT)
	_bar(objective,int(state.signal),Style.ACCENT,8)
	_button(header,"玩法说明",_help,"HelpButton")
	_button(header,"保存并返回",_menu,"MenuButton")
	_resources()
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(body)
	match String(state.phase):
		"base": _base(body)
		"tactical": _tactical(body)
		"event": _event(body)
		"report": _report(body)
		"ending": _ending(body)
	var footer: HBoxContainer = HBoxContainer.new()
	_content.add_child(footer)
	_status = _label(footer,"",16,Style.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 28
	if not app.last_error.is_empty():
		_status.text = Copy.message(app.last_error)
		_status.modulate = Style.RED
	elif state.phase == "tactical":
		_status.text = Copy.message(String(state.mission.last))
		if state.mission.last == "found_loot": _status.text += "  " + Copy.resources(state.mission.last_data)
	elif state.phase == "base":
		_status.text = "目标：建造电台、完成联络，并坚持到第 7 天结束。也可以挑战生存 30 天。"
	else:
		_status.text = "每次有效行动后自动保存。"

func _resources() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	_content.add_child(row)
	var stock: Dictionary = app.session.base_state.stockpile
	for key in Copy.RESOURCES:
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Style.box(Style.PANEL,Style.BORDER,10))
		row.add_child(panel)
		var info: HBoxContainer = HBoxContainer.new()
		panel.add_child(info)
		_label(info,Copy.RESOURCES[key],16,Style.MUTED)
		var count: Label = _label(info,str(int(stock.get(key,0))),23,Style.TEXT)
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if (key=="food" and int(stock.get(key,0))<_living().size()*2) or (key=="water" and int(stock.get(key,0))<_living().size()*3):
			count.modulate = Style.RED

func _base(body: HBoxContainer) -> void:
	_roster(body)
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	var nav: HBoxContainer = HBoxContainer.new()
	main.add_child(nav)
	for item in [["explore","街区探索"],["build","基地建设"],["journal","生存日志"]]:
		var b: Button = _button(nav,item[1],_set_tab.bind(item[0]),"Tab_"+item[0])
		if tab==item[0]: b.add_theme_stylebox_override("normal",Style.box(Color("354139"),Style.ACCENT,12))
	var info: Label = _label(nav,"行动 %d / 2" % int(state.actions),18,Style.ACCENT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if tab=="explore": _explore(main)
	elif tab=="build": _build(main)
	else: _journal(main)
	var bottom: HBoxContainer = HBoxContainer.new()
	main.add_child(bottom)
	var pressure: int = int(app.session.base_state.get("city_pressure",0))
	var hint: Label = _label(bottom,"城市威胁 %d / 100\n今晚消耗：食物 %d · 饮水 %d" % [pressure,_living().size()*2,_living().size()*3],16,Style.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(bottom,"结束这一天",_confirm_night,"EndDayButton",true)

func _roster(body: HBoxContainer) -> void:
	var panel: VBoxContainer = _panel(body,238)
	panel.add_theme_constant_override("separation",8)
	_label(panel,"幸存者  /  %d 人" % _living().size(),20,Style.TEXT)
	_label(panel,"选择出发人员，安排夜间工作。",14,Style.MUTED)
	if _character(selected_character).is_empty() or int(_character(selected_character).stats.hp)<=0:
		if not _living().is_empty(): selected_character = _living()[0].id
	for c in app.session.characters:
		var alive: bool = int(c.stats.hp)>0
		var card: VBoxContainer = VBoxContainer.new()
		card.add_theme_constant_override("separation",4)
		panel.add_child(card)
		var name: String = String(c.get("name_zh",c.id))
		var b: Button = _button(card,("●  " if c.id==selected_character and alive else "")+name,_select_character.bind(String(c.id)),"Character_"+c.id)
		b.disabled = not alive
		b.custom_minimum_size.y = 32
		b.add_theme_font_size_override("font_size",16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not alive:
			_label(card,"未能归来",14,Style.RED)
			continue
		_label(card,"健康 %d  ·  精力 %d  ·  感染 %d" % [int(c.stats.hp),int(c.stats.energy),int(c.stats.infection)],14,Style.MUTED)
		_bar(card,int(c.stats.hp),Style.GREEN if int(c.stats.hp)>35 else Style.RED,5)
		var role: OptionButton = OptionButton.new()
		role.name = "Role_"+String(c.id)
		role.add_theme_font_size_override("font_size",14)
		role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in Rules.ROLES: role.add_item(Copy.ROLES[id])
		role.select(maxi(0,Rules.ROLES.find(String(c.get("job","rest")))))
		role.tooltip_text = String(Copy.ROLE_HINTS.get(c.get("job","rest"),""))
		role.item_selected.connect(_assign.bind(String(c.id)))
		card.add_child(role)
	var heal: Button = _button(panel,"治疗所选成员  /  1 药品",_act.bind("heal",{"character":selected_character}),"HealBaseButton")
	heal.disabled = int(app.session.base_state.stockpile.get("medical",0))<1

func _explore(main: VBoxContainer) -> void:
	var area: HBoxContainer = HBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(area)
	var map: Control = District.new()
	map.name = "DistrictMap"
	map.selected = selected_location
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.location_selected.connect(_select_location)
	area.add_child(map)
	var details: VBoxContainer = _panel(area,260)
	var location: Dictionary = _location(selected_location)
	_label(details,"行动地点",14,Style.MUTED)
	_label(details,location.name,25,Style.TEXT)
	var risk: int = int(location.risk)
	_label(details,"危险程度  " + ["低","中","高"][risk-1],16,Style.GREEN if risk==1 else Style.RED)
	_wrap(details,location.description)
	_separator(details)
	_label(details,"选择地点",14,Style.MUTED)
	var locations: GridContainer = GridContainer.new()
	locations.columns = 2
	locations.add_theme_constant_override("h_separation",6)
	locations.add_theme_constant_override("v_separation",6)
	details.add_child(locations)
	for loc in Rules.data().locations:
		var b: Button = _button(locations,loc.name,_select_location.bind(String(loc.id)),"Location_"+loc.id)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 32
		b.add_theme_font_size_override("font_size",15)
		b.add_theme_stylebox_override("normal",Style.box(Style.PANEL,Color(loc.color) if loc.id==selected_location else Style.BORDER,6))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	_label(details,"消耗 1 次行动 · 12 精力",14,Style.MUTED)
	var name: String = String(_character(selected_character).get("name_zh","幸存者"))
	var depart: Button = _button(details,"派出"+name,_act.bind("depart",{"character":selected_character,"location":selected_location}),"DepartButton",true)
	depart.disabled = int(state.actions)<=0

func _build(main: VBoxContainer) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	main.add_child(grid)
	for f in Rules.data().facilities:
		var panel: VBoxContainer = _panel(grid)
		panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(panel,f.name,23,Style.ACCENT)
		_wrap(panel,f.description)
		_label(panel,"建造所需："+Copy.resources(f.cost),15,Style.MUTED)
		var built: bool = state.built.has(f.id)
		var b: Button = _button(panel,"已建成" if built else "建造  /  1 次行动",_act.bind("build",{"facility":f.id}),"Build_"+f.id)
		b.disabled = built or int(state.actions)<=0 or not _afford(f.cost)
		if f.id=="radio" and built:
			var contact: Button = _button(panel,"联络救援  /  2 零件 + 1 燃油",_act.bind("radio",{}),"RadioButton",true)
			contact.add_theme_font_size_override("font_size",15)
			contact.disabled = int(state.actions)<=0 or int(state.signal)>=100 or not _afford({"parts":2,"fuel":1})

func _journal(main: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries: Array = state.journal.duplicate()
	entries.reverse()
	for entry in entries: _wrap(list,Copy.journal(entry),16)

func _tactical(body: HBoxContainer) -> void:
	var mission: Dictionary = state.mission
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	var header: HBoxContainer = HBoxContainer.new()
	main.add_child(header)
	_label(header,_location(mission.location).name,23,Style.TEXT)
	var turns: Label = _label(header,"回合 %02d / 80" % int(mission.turn),17,Style.ACCENT)
	turns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_board = Board.new()
	_board.name = "TacticalBoard"
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.set_mission(mission)
	_board.cell_pressed.connect(_cell_pressed)
	main.add_child(_board)
	_label(main,"黄色：补给箱   绿色：撤离点   红色 !：已警觉   暗区：探索过的区域",14,Style.MUTED)
	var side: VBoxContainer = _panel(body,278)
	side.add_theme_constant_override("separation",8)
	var c: Dictionary = _character(mission.character)
	_label(side,String(c.get("name_zh","幸存者")),23,Style.TEXT)
	_label(side,"健康 %d / 100" % int(c.stats.hp),17,Style.TEXT)
	_bar(side,int(c.stats.hp),Style.GREEN if int(c.stats.hp)>35 else Style.RED,10)
	_label(side,"精力 %d  ·  感染 %d" % [int(c.stats.energy),int(c.stats.infection)],16,Style.MUTED)
	_separator(side)
	var mode: String = "潜行中" if mission.sneak else "正常行走"
	_button(side,mode+"  [C]",_act.bind("sneak",{}),"SneakButton")
	_button(side,"搜刮身边补给  [E]",_act.bind("search",{}),"SearchButton",true)
	var fire: Button = _button(side,("已选择射击" if shoot_mode else "切换射击")+"  [F]",_toggle_shoot,"ShootButton")
	if shoot_mode: fire.modulate = Style.ACCENT
	_button(side,"原地等待  [Space]",_act.bind("wait",{}),"WaitButton")
	_button(side,"包扎治疗  [H]",_act.bind("heal",{}),"HealButton")
	_separator(side)
	_label(side,"携带的补给",17,Style.ACCENT)
	_wrap(side,Copy.resources(mission.cargo),15)
	_wrap(side,"靠近感染者，点击它进行近战。射击模式下，点击视野内目标开火。",14)
	var space: Control = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(space)
	_wrap(side,"WASD / 方向键移动；点击地面向目标走一步。每次行动后，感染者行动一次。",14)
	_button(side,"带上补给撤离  [R]",_act.bind("extract",{}),"ExtractButton",true)

func _event(body: HBoxContainer) -> void:
	var event: Dictionary = Rules.data().events[int(state.event_index)]
	var panel: VBoxContainer = _center_panel(body)
	_label(panel,"入夜之前  /  一次选择",16,Style.ACCENT)
	_label(panel,event.title,34,Style.TEXT)
	_wrap(panel,event.description,21)
	_separator(panel)
	for i in range(event.options.size()):
		var option: Dictionary = event.options[i]
		var b: Button = _button(panel,option.label,_act.bind("choose",{"index":i}),"EventOption_"+str(i),i==0)
		b.disabled = not _afford(option.get("cost",{}))
		var effect: Array[String] = []
		if option.has("cost"): effect.append("消耗 "+Copy.resources(option.cost))
		if option.has("gain"): effect.append("获得 "+Copy.resources(option.gain))
		if option.has("signal"): effect.append("联络 +%d%%" % int(option.signal))
		var stat_names: Dictionary = {"hp":"健康","energy":"精力","morale":"士气","infection":"感染"}
		for key in option.get("stats",{}): effect.append("全员%s %+d" % [stat_names.get(key,key),int(option.stats[key])])
		_label(panel,"  /  ".join(effect),15,Style.MUTED)

func _report(body: HBoxContainer) -> void:
	var summary: Dictionary = state.summary
	var panel: VBoxContainer = _center_panel(body)
	if summary.get("kind","")=="sortie":
		var outcome: String = String(summary.outcome)
		var title: String = {"extracted":"平安归来","fallen":"空着的位置","forced_retreat":"在黑暗前撤回"}.get(outcome,"行动结束")
		_label(panel,"外出行动报告",16,Style.ACCENT)
		_label(panel,title,38,Style.RED if outcome=="fallen" else Style.GREEN)
		_wrap(panel,"未能返回的成员与物资已经失去。剩下的人还要继续前进。" if outcome=="fallen" else "补给已收入基地仓库。伤势与感染会保留，记得安排治疗和休息。",20)
		_label(panel,"行动耗时：%d 回合" % int(summary.turns),17,Style.MUTED)
		_label(panel,"带回物资",20,Style.ACCENT)
		_wrap(panel,Copy.resources(summary.cargo),22)
	else:
		_label(panel,"第 %02d 天  /  晨间报告" % int(app.session.clock.current_day),16,Style.ACCENT)
		_label(panel,"又看见了天亮",38,Style.GREEN)
		_wrap(panel,"昨夜消耗："+Copy.resources(summary.get("consumed",{})),20)
		_wrap(panel,"工作产出："+Copy.resources(summary.get("produced",{})),20)
		if summary.get("shortage",false):
			_wrap(panel,"食物或饮水不足。全员健康、精力与士气下降，请优先补给。",20,Style.RED)
		else: _wrap(panel,"所有人分到了食物与饮水。新的一天还有两次行动机会。",20)
		if int(summary.get("raid",0))>0: _wrap(panel,"夜间遭到袭击，一位成员受伤。加固围墙或安排守卫可以降低损失。",18,Style.RED)
	_separator(panel)
	_button(panel,"继续规划",_act.bind("acknowledge",{}),"AcknowledgeButton",true)

func _ending(body: HBoxContainer) -> void:
	var panel: VBoxContainer = _center_panel(body)
	var ending: String = String(state.ending)
	var title: String = {"rescue":"有人回应了坐标","survival":"我们把这里叫作家","defeat":"最后一盏灯熄灭了"}.get(ending,"旅程结束")
	var description: String = {"rescue":"杂音终于变成了清晰的人声。救援队找到了避难所，你们带着彼此离开了这片街区。","survival":"三十次日落之后，避难所仍然有人生火。你们没有等来奇迹，却建立了自己的秩序。","defeat":"没有人能够继续守住避难所。地图留在桌上，等待下一次有人重新展开。"}.get(ending,"")
	_label(panel,"战役结束",16,Style.ACCENT)
	_label(panel,title,38,Style.RED if ending=="defeat" else Style.GREEN)
	_wrap(panel,description,22)
	_separator(panel)
	_wrap(panel,"存活成员 %d 人  ·  度过 %d 天\n外出 %d 次  ·  带回 %d 份物资  ·  击倒 %d 名感染者" % [_living().size(),maxi(0,int(app.session.clock.current_day)-1),int(state.sorties),int(state.total_loot),int(state.kills)],20)
	_button(panel,"回到主菜单",_menu,"EndingMenuButton",true)

func _center_panel(body: HBoxContainer) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var panel: VBoxContainer = _panel(center,760)
	panel.add_theme_constant_override("separation",18)
	return panel

func _panel(parent: Node, width: float = 0) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	if width>0: panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	return box

func _label(parent: Node, text: String, size_px: int = 17, color: Color = Style.TEXT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _wrap(parent: Node, text: String, size_px: int = 17, color: Color = Style.MUTED) -> Label:
	var label: Label = _label(parent,text,size_px,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node, text: String, callback: Callable, node_name: String = "", accent: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	if not node_name.is_empty(): button.name = node_name
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	if accent:
		var accent_box: StyleBoxFlat = Style.box(Color("47523b"),Style.ACCENT,12)
		accent_box.content_margin_top = 5
		accent_box.content_margin_bottom = 5
		button.add_theme_stylebox_override("normal",accent_box)
		button.add_theme_color_override("font_color",Color("f4e6c3"))
	parent.add_child(button)
	return button

func _bar(parent: Node, value: int, color: Color, height: int) -> void:
	var bar: ProgressBar = ProgressBar.new()
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("fill",Style.box(color,color,0))
	parent.add_child(bar)

func _separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())

func _living() -> Array:
	return app.session.characters.filter(func(c: Dictionary) -> bool: return int(c.stats.hp)>0)

func _character(cid: String) -> Dictionary:
	for c in app.session.characters:
		if c.id == cid: return c
	return {}

func _location(id: String) -> Dictionary:
	for loc in Rules.data().locations:
		if loc.id==id: return loc
	return Rules.data().locations[0]

func _afford(cost: Dictionary) -> bool:
	for key in cost:
		if int(app.session.base_state.stockpile.get(key,0))<int(cost[key]): return false
	return true

func _act(action: String, values: Dictionary) -> void:
	if _refresh_pending: return
	app.campaign_action(action,values)

func _set_tab(value: String) -> void:
	tab = value
	_schedule_refresh()

func _select_character(cid: String) -> void:
	selected_character = cid
	_schedule_refresh()

func _select_location(id: String) -> void:
	selected_location = id
	_schedule_refresh()

func _assign(index: int, cid: String) -> void:
	_act("assign",{"character":cid,"role":Rules.ROLES[index]})

func _toggle_shoot() -> void:
	shoot_mode = not shoot_mode
	_schedule_refresh()

func _cell_pressed(target: Array) -> void:
	if state.phase != "tactical": return
	for enemy in state.mission.enemies:
		if enemy.pos==target and int(enemy.hp)>0:
			_act("shoot" if shoot_mode else "attack",{"target":target})
			return
	_act("move",{"target":target})

func _confirm_night() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "结束这一天"
	dialog.dialog_text = "将安排夜间工作、消耗食物与饮水。\n今天还剩 %d 次行动，确认入夜吗？" % int(state.actions)
	dialog.ok_button_text = "入夜"
	dialog.cancel_button_text = "继续准备"
	dialog.confirmed.connect(func() -> void: _act("end_day",{}); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	_dialog = dialog
	dialog.popup_centered(Vector2i(490,190))

func _help() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "生存手册"
	dialog.dialog_text = "目标：建造短波电台，联络进度达到 100%，并撑过第 7 天。\n也可以选择坚持 30 天，建立长期避难所。\n\n每天有 2 次行动，可用于出发、建造或联络。\n每位幸存者每晚消耗 2 食物、3 饮水；工作与设施会生产物资。\n先建净水器，保证水源；补给不足时优先去便利店或公园。\n\n外出：WASD / 方向键移动；点击地面走一步。\nE 搜刮 · C 潜行 · F 射击模式 · H 包扎 · Space 等待 · R 撤离。\n点击近处感染者进行近战，射击模式下点击远处目标开火。\n每次行动敌人也会行动；80 回合后会被迫撤离并损失部分补给。\n\n回到左侧绿色撤离点旁才能带回物资。阵亡会永久失去成员。\n有效行动后自动存档，可在任何阶段返回菜单继续游戏。"
	dialog.ok_button_text = "明白了"
	add_child(dialog)
	_dialog = dialog
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(710,540))

func _menu() -> void:
	app.back_to_menu()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if _refresh_pending or (is_instance_valid(_dialog) and _dialog.visible): return
	if event.keycode==KEY_ESCAPE:
		_help()
		get_viewport().set_input_as_handled()
		return
	if state.get("phase","")!="tactical": return
	var offset: Vector2i = Vector2i.ZERO
	match event.physical_keycode:
		KEY_W, KEY_UP: offset = Vector2i.UP
		KEY_S, KEY_DOWN: offset = Vector2i.DOWN
		KEY_A, KEY_LEFT: offset = Vector2i.LEFT
		KEY_D, KEY_RIGHT: offset = Vector2i.RIGHT
		KEY_E: _act("search",{})
		KEY_C: _act("sneak",{})
		KEY_F: _toggle_shoot()
		KEY_H: _act("heal",{})
		KEY_R: _act("extract",{})
		KEY_SPACE: _act("wait",{})
		_: return
	if offset!=Vector2i.ZERO:
		var next: Vector2i = Rules.cell(state.mission.player)+offset
		_cell_pressed([next.x,next.y])
	get_viewport().set_input_as_handled()
