extends RefCounted

## Pure-data accessibility settings (no @tool, no GUI). Used by the
## accessibility_settings.tscn scene and consumed by the presentation
## layer to scale UI / pick fonts / toggle motion FX.
##
## API surface (all setters return true/false; false means invalid input,
## no state change):
##   - set_ui_zoom(0.8 | 1.0 | 1.2 | 1.6) -> bool
##   - set_font_size("small" | "standard" | "large") -> bool
##   - set_color_mode("default" | "protanopia" | "deuteranopia" | "high_contrast") -> bool
##   - set_screen_shake(bool), set_camera_shake(bool), set_damage_vignette(bool), set_motion_blur(bool)
##   - bind(action: String, keycode: int), clear_binding(action), clear_all_bindings()
##   - get_state() -> Dictionary (snapshot)
##
## Whitelisted values only; out-of-range input is rejected (no silent
## accepts). 16-binding cap mirrors the design's max rebindable actions.

const _PATH: String = "res://game/presentation/ui/settings_accessibility.gd"

const VALID_ZOOM: Array = [0.8, 1.0, 1.2, 1.6]
const VALID_FONT_SIZE: Array[String] = ["small", "standard", "large"]
const VALID_COLOR_MODE: Array[String] = ["default", "protanopia", "deuteranopia", "high_contrast"]
const MAX_BINDINGS: int = 16

var _ui_zoom: float = 1.0
var _font_size: String = "standard"
var _color_mode: String = "default"
var _screen_shake: bool = true
var _camera_shake: bool = true
var _damage_vignette: bool = true
var _motion_blur: bool = true
var _keybindings: Dictionary = {}

func _log(msg: String) -> void:
	push_warning("[Accessibility] " + msg)

## Zoom ---------------------------------------------------------------------

func set_ui_zoom(zoom: float) -> bool:
	if not (zoom in VALID_ZOOM):
		_log("reject ui_zoom=" + str(zoom))
		return false
	_ui_zoom = zoom
	return true

func get_ui_zoom() -> float:
	return _ui_zoom

## Font size ---------------------------------------------------------------

func set_font_size(size_name: String) -> bool:
	if not VALID_FONT_SIZE.has(size_name):
		_log("reject font_size=" + size_name)
		return false
	_font_size = size_name
	return true

func get_font_size() -> String:
	return _font_size

## Color mode --------------------------------------------------------------

func set_color_mode(mode: String) -> bool:
	if not VALID_COLOR_MODE.has(mode):
		_log("reject color_mode=" + mode)
		return false
	_color_mode = mode
	return true

func get_color_mode() -> String:
	return _color_mode

## Motion FX toggles -------------------------------------------------------

func set_screen_shake(on: bool) -> bool:
	_screen_shake = on
	return true

func get_screen_shake() -> bool:
	return _screen_shake

func set_camera_shake(on: bool) -> bool:
	_camera_shake = on
	return true

func get_camera_shake() -> bool:
	return _camera_shake

func set_damage_vignette(on: bool) -> bool:
	_damage_vignette = on
	return true

func get_damage_vignette() -> bool:
	return _damage_vignette

func set_motion_blur(on: bool) -> bool:
	_motion_blur = on
	return true

func get_motion_blur() -> bool:
	return _motion_blur

## Keybindings -------------------------------------------------------------

func bind(action: String, keycode: int) -> bool:
	if action == "" or keycode <= 0:
		_log("reject bind action=" + action + " keycode=" + str(keycode))
		return false
	if not _keybindings.has(action) and _keybindings.size() >= MAX_BINDINGS:
		_log("reject bind, full (cap %d)" % MAX_BINDINGS)
		return false
	_keybindings[action] = keycode
	return true

func clear_binding(action: String) -> bool:
	if not _keybindings.has(action):
		return false
	_keybindings.erase(action)
	return true

func clear_all_bindings() -> void:
	_keybindings.clear()

func get_binding(action: String) -> int:
	return int(_keybindings.get(action, 0))

func get_binding_count() -> int:
	return _keybindings.size()

func get_keybindings() -> Dictionary:
	return _keybindings.duplicate(true)

## Snapshot ----------------------------------------------------------------

func get_state() -> Dictionary:
	return {
		"ui_zoom": _ui_zoom,
		"font_size": _font_size,
		"color_mode": _color_mode,
		"screen_shake": _screen_shake,
		"camera_shake": _camera_shake,
		"damage_vignette": _damage_vignette,
		"motion_blur": _motion_blur,
		"keybindings": _keybindings.duplicate(true),
	}