extends Node

## Boot script for the entry scene (res://game/main.tscn).
##
## On _ready() we instantiate the SceneRouter + GameApp singleton, store
## the app on `tree.root.get_meta("app")`, then route to the main_menu
## scene. From that point, all scene transitions and game logic flow
## through GameApp.
##
## D1: explicit singleton (no project.godot autoload entry). This
##     avoids touching the project file's [autoload] section.

const _PATH: String = "res://game.gd"

const SceneRouterScript: GDScript = preload("res://game/application/scene_router.gd")
const GameAppScript: GDScript = preload("res://game/application/app.gd")

func _ready() -> void:
	# Set the default font for any future Label (so Chinese renders in
	# the bundled theme instead of as tofu boxes).
	# Theme is picked up via project.godot's default Godot theme.
	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("[boot] no SceneTree")
		return

	var router: RefCounted = SceneRouterScript.new()
	router.tree = tree

	var app: RefCounted = GameAppScript.new(router)
	tree.root.set_meta("app", app)
	print("[boot] GameApp singleton ready on tree.root")

	# First scene: main_menu.
	router.goto("main_menu", {})

func _process(_dt: float) -> void:
	# Reserved for future per-frame hooks (autosave timer, etc.).
	pass