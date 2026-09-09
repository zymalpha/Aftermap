extends Control

signal location_selected(id: String)
const Rules: GDScript = preload("res://game/domain/campaign/campaign_actions.gd")
const Colors: GDScript = preload("res://game/presentation/ui/survival_theme.gd")
var selected: String = "grocery"
var points: Dictionary = {}
var positions: Dictionary = {"grocery":Vector2(0.19,0.70),"park":Vector2(0.74,0.79),"pharmacy":Vector2(0.20,0.36),"school":Vector2(0.36,0.16),"clinic":Vector2(0.64,0.38),"police":Vector2(0.83,0.57)}

func _ready() -> void:
	custom_minimum_size = Vector2(400,380)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("121e23"))
	for x in range(0,int(size.x),24): draw_line(Vector2(x,0),Vector2(x,size.y),Color("1c2b30"))
	for y in range(0,int(size.y),24): draw_line(Vector2(0,y),Vector2(size.x,y),Color("1c2b30"))
	# A schematic of the preset POIs; no claim of a live OSM basemap.
	var path: PackedVector2Array = PackedVector2Array()
	for p in [Vector2(.1,.85),Vector2(.23,.58),Vector2(.5,.56),Vector2(.62,.30),Vector2(.9,.19)]: path.append(p*size)
	draw_polyline(path,Color("263b43"),18,true)
	draw_polyline(path,Color("44606a"),1,true)
	points.clear()
	var font: Font = get_theme_default_font()
	for loc in Rules.data().locations:
		var center: Vector2 = positions[loc.id]*size
		points[loc.id] = center
		var color: Color = Color(loc.color)
		var hub: Vector2 = Vector2(.46,.56)*size
		draw_line(hub,center,Color("455650"),1,true)
		draw_circle(center,21,Color("19262c"))
		draw_arc(center,21,0,TAU,32,color,2,true)
		draw_circle(center,6,color)
		if loc.id == selected:
			draw_arc(center,28,0,TAU,32,Colors.ACCENT,2,true)
			draw_circle(center,36,Color(0.9,0.72,0.4,0.07))
		draw_string(font,center+Vector2(-65,46),loc.name,HORIZONTAL_ALIGNMENT_CENTER,130,17,Colors.TEXT)
	var home_pos: Vector2 = size*Vector2(.46,.56)
	draw_rect(Rect2(home_pos-Vector2(8,8),Vector2(16,16)),Colors.GREEN)
	draw_string(font,home_pos+Vector2(-55,30),"避难所",HORIZONTAL_ALIGNMENT_CENTER,110,16,Colors.GREEN)
	draw_string(font,Vector2(16,28),"N ↑   南京 / 街区示意",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Colors.MUTED)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for id in points:
			if event.position.distance_to(points[id])<45:
				selected = id
				queue_redraw()
				location_selected.emit(id)
				accept_event()
				return
