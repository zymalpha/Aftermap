extends Control

signal cell_pressed(target: Array)
const Rules: GDScript = preload("res://game/domain/campaign/campaign_actions.gd")
const Colors: GDScript = preload("res://game/presentation/ui/survival_theme.gd")
var mission: Dictionary = {}
var hover: Vector2i = Vector2i(-1,-1)
var tile: float = 32.0
var origin: Vector2 = Vector2.ZERO
var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(func() -> void: hover = Vector2i(-1,-1); queue_redraw())
	resized.connect(queue_redraw)
	for name in ["tile_concrete","tile_grass","tile_wall_h"]:
		_textures[name] = load("res://game/assets_art/tiles/" + name + ".png")
	_textures["scout"] = load("res://game/assets_art/characters/char_03_scout_base.png")
	_textures["infected"] = load("res://game/assets_art/infected/wanderer_base.png")

func set_mission(value: Dictionary) -> void:
	mission = value
	queue_redraw()

func cell_center(p: Array) -> Vector2:
	return origin + (Vector2(p[0],p[1])+Vector2(0.5,0.5))*tile

func _draw() -> void:
	if mission.is_empty(): return
	tile = minf(size.x/Rules.W, size.y/Rules.H)
	origin = (size-Vector2(Rules.W,Rules.H)*tile)/2.0
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a1115"))
	var visible: Array = mission.visible
	var explored: Array = mission.explored
	for y in range(Rules.H):
		for x in range(Rules.W):
			var p: Array = [x,y]
			var rect: Rect2 = Rect2(origin+Vector2(x,y)*tile,Vector2.ONE*tile)
			if not explored.has(p):
				draw_rect(rect,Color("0d171d"))
				draw_rect(rect,Color("142126"),false,0.5)
				continue
			var is_wall: bool = mission.walls.has(p)
			var name: String = "tile_wall_h" if is_wall else "tile_concrete"
			if not is_wall and (x<3 or x>21): name = "tile_grass"
			if _textures.has(name): draw_texture_rect(_textures[name],rect,false,Color("91a29c") if is_wall else Color("6f837e"))
			else: draw_rect(rect,Colors.BORDER if is_wall else Colors.PANEL)
			if not is_wall:
				for room in mission.rooms:
					if Rect2i(room[0],room[1],room[2],room[3]).has_point(Vector2i(x,y)):
						draw_rect(rect,Color(0.43,0.34,0.18,0.22))
			if not visible.has(p): draw_rect(rect,Color(0.02,0.04,0.07,0.74))
			draw_rect(rect,Color(0.6,0.7,0.65,0.08),false,0.5)
	var exit_center: Vector2 = cell_center(mission.exit)
	draw_rect(Rect2(exit_center-Vector2.ONE*tile*0.45,Vector2.ONE*tile*0.9),Color("375e4e"))
	draw_rect(Rect2(exit_center-Vector2.ONE*tile*0.45,Vector2.ONE*tile*0.9),Colors.GREEN,false,2)
	draw_string(get_theme_default_font(),exit_center+Vector2(-tile*0.22,tile*0.2),"撤",HORIZONTAL_ALIGNMENT_LEFT,-1,int(tile*0.5),Colors.TEXT)
	for crate in mission.crates:
		if not explored.has(crate.pos): continue
		var center: Vector2 = cell_center(crate.pos)
		var rect: Rect2 = Rect2(center-Vector2.ONE*tile*0.26,Vector2.ONE*tile*0.52)
		var color: Color = Color("5e665c") if crate.searched else Colors.ACCENT
		if not visible.has(crate.pos): color = color.darkened(0.65)
		draw_rect(rect,Color("57462d"))
		draw_rect(rect,color,false,2)
		draw_line(center-Vector2(tile*0.26,0),center+Vector2(tile*0.26,0),color,2)
		if not crate.searched: draw_line(center-Vector2(0,tile*0.26),center+Vector2(0,tile*0.26),color,2)
	for enemy in mission.enemies:
		if not visible.has(enemy.pos): continue
		var center: Vector2 = cell_center(enemy.pos)
		if int(enemy.hp)<=0:
			draw_circle(center,tile*0.17,Color("62433d"))
			continue
		draw_circle(center+Vector2(0,tile*0.22),tile*0.28,Color(0,0,0,0.5))
		if _textures.has("infected"):
			draw_texture_rect(_textures.infected,Rect2(center-Vector2(tile*0.4,tile*0.7),Vector2(tile*0.8,tile*1.1)),false)
		draw_rect(Rect2(center+Vector2(-tile*0.3,tile*0.32),Vector2(tile*0.6,3)),Color("302225"))
		draw_rect(Rect2(center+Vector2(-tile*0.3,tile*0.32),Vector2(tile*0.6*int(enemy.hp)/27.0,3)),Colors.RED)
		if int(enemy.alert)>0: draw_string(get_theme_default_font(),center+Vector2(tile*0.25,-tile*0.3),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,int(tile*0.6),Colors.RED)
	var player_center: Vector2 = cell_center(mission.player)
	draw_circle(player_center,tile*0.43,Color(0.72,0.89,0.7,0.18))
	draw_arc(player_center,tile*0.43,0,TAU,32,Colors.GREEN,2)
	if _textures.has("scout"):
		draw_texture_rect(_textures.scout,Rect2(player_center-Vector2(tile*0.4,tile*0.72),Vector2(tile*0.8,tile*1.13)),false)
	if hover.x>=0 and visible.has([hover.x,hover.y]):
		draw_rect(Rect2(origin+Vector2(hover)*tile+Vector2.ONE,Vector2.ONE*(tile-2)),Colors.ACCENT,false,2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var local: Vector2 = event.position-origin
		hover = Vector2i(int(floor(local.x/tile)),int(floor(local.y/tile)))
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if hover.x>=0 and hover.x<Rules.W and hover.y>=0 and hover.y<Rules.H:
			cell_pressed.emit([hover.x,hover.y])
		accept_event()
