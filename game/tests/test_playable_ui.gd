extends SceneTree

const App: GDScript = preload("res://game/application/app.gd")
const Router: GDScript = preload("res://game/application/scene_router.gd")
var app: RefCounted
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("UI FAIL: "+message)

func settle() -> void:
	for i in range(5): await process_frame

func press(node_name: String) -> void:
	var button: Button = current_scene.find_child(node_name,true,false) as Button
	expect(button!=null,"button exists: "+node_name)
	if button!=null:
		expect(not button.disabled,"button enabled: "+node_name)
		if not button.disabled:
			var pointer: InputEventMouseButton = InputEventMouseButton.new()
			pointer.position = button.get_global_rect().get_center()
			pointer.global_position = pointer.position
			pointer.button_index = MOUSE_BUTTON_LEFT
			pointer.pressed = true
			Input.parse_input_event(pointer)
			await process_frame
			pointer.pressed = false
			Input.parse_input_event(pointer)
	await settle()

func capture(name: String) -> void:
	# Commands can succeed even when an overflowing layout hides their controls.
	var bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(root.size))
	for node in current_scene.find_children("*","Button",true,false):
		if node.is_visible_in_tree():
			expect(bounds.encloses(node.get_global_rect()),"visible button fits viewport in %s: %s %s" % [name,node.name,node.get_global_rect()])
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	expect(image.save_png("res://build/qa/"+name+".png")==OK,"save screenshot")

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func _run() -> void:
	root.size = Vector2i(1280,800)
	var router: RefCounted = Router.new()
	router.tree = self
	app = App.new(router)
	app.save_path = "user://test_playable_ui.dat"
	root.set_meta("app",app)
	router.goto("main_menu",{})
	await settle()
	expect(current_scene!=null and current_scene.name=="MainMenu","real router reaches main menu")
	await capture("01-menu")
	await press("StartCampaignButton")
	await press("CityButton_nanjing")
	expect(current_scene!=null and current_scene.name=="Campaign","menu click reaches campaign")
	if current_scene==null or current_scene.name!="Campaign":
		quit(1)
		return
	await capture("02-base")
	await press("DepartButton")
	expect(app.session.base_state.campaign.phase=="tactical","depart control starts mission")
	await capture("03-tactical")
	await key(KEY_E)
	expect(not app.session.base_state.campaign.mission.cargo.is_empty(),"keyboard E actually searches")
	var focused: Button = current_scene.find_child("SearchButton",true,false) as Button
	expect(focused!=null,"search button can receive keyboard focus")
	if focused!=null: focused.grab_focus()
	await key(KEY_RIGHT)
	expect(app.session.base_state.campaign.mission.player==[3,8],"arrow key moves even when a button has focus")
	focused = current_scene.find_child("SearchButton",true,false) as Button
	if focused!=null: focused.grab_focus()
	var turn: int = int(app.session.base_state.campaign.mission.turn)
	await key(KEY_SPACE)
	expect(int(app.session.base_state.campaign.mission.turn)==turn+1,"space waits exactly once instead of pressing focused search button")
	await press("MenuButton")
	expect(current_scene.name=="MainMenu","save and return works")
	app.session = null
	await press("ContinueButton")
	expect(current_scene.name=="Campaign","continue reconnects real scene")
	expect(app.session.base_state.campaign.mission.player==[3,8],"continue restores exact tactical position")
	await key(KEY_A)
	await press("ExtractButton")
	expect(app.session.base_state.campaign.phase=="report","extract control shows report")
	await capture("04-return")
	await press("AcknowledgeButton")
	await press("EndDayButton")
	var confirmation: ConfirmationDialog = null
	for child in current_scene.get_children():
		if child is ConfirmationDialog: confirmation = child
	expect(confirmation!=null,"end day confirmation visible")
	if confirmation!=null: confirmation.confirmed.emit()
	await settle()
	expect(app.session.base_state.campaign.phase=="event","night event displayed")
	await capture("05-event")
	await press("EventOption_1")
	expect(int(app.session.clock.current_day)==2,"UI advances day once")
	await capture("06-morning")
	await press("AcknowledgeButton")
	await press("Tab_build")
	await capture("07-facilities")
	await press("Build_water")
	expect(app.session.base_state.campaign.built.has("water"),"construction control commits facility")
	for suffix in ["",".meta",".bak",".bak.meta",".tmp"]: DirAccess.remove_absolute(app.save_path+suffix)
	print("PLAYABLE_UI: failures=%d" % failures)
	quit(1 if failures else 0)
