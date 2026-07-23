extends Node

## Stage 17: per-scene Localizer autoload bridge.
##
## Loads the default zh_CN .po file from `res://game/adapters/localization/`
## on `_ready()`, instantiates a `Localizer` instance, and registers it on
## this scene as `localizer` so child nodes can pull translations.
##
## The localizer instance is also added to the tree's metadata so it can be
## retrieved by other scenes via `get_tree().get_meta("localizer")` once
## stage 18 wires the project-wide autoload.

const LocalizerScript: GDScript = preload("res://game/adapters/localization/localizer.gd")
const DEFAULT_PO: String = "res://game/adapters/localization/zh_CN.po"
const DEFAULT_LANG: StringName = &"zh_CN"

var localizer: RefCounted = null
var loaded: bool = false
var last_error: int = OK

func _ready() -> void:
	localizer = LocalizerScript.new()
	localizer.set_default_lang(DEFAULT_LANG)
	localizer.set_lang(DEFAULT_LANG)
	var err: int = localizer.load_from_po(DEFAULT_PO, DEFAULT_LANG)
	last_error = err
	loaded = (err == OK)
	# Best-effort: register on tree metadata so other systems can find it.
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.set_meta("localizer", localizer)
		tree.set_meta("localizer_default_lang", String(DEFAULT_LANG))
	if loaded:
		print("[MainMenuLocalizer] loaded ", localizer.size(), " entries from ", DEFAULT_PO)
	else:
		printerr("[MainMenuLocalizer] failed to load ", DEFAULT_PO, " err=", err)

func get_localizer() -> RefCounted:
	return localizer

func is_loaded() -> bool:
	return loaded