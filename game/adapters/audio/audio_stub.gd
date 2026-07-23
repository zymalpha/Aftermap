extends Node
class_name AudioStub

## Stage 17 audio stub.
##
## Provides a stable, file-system-tolerant interface for SFX and BGM playback.
## No real audio is emitted — the stub only logs the calls and tracks state so
## downstream systems (UI, event feedback) can wire to it now and swap in real
## AudioStreamPlayer / AudioStreamPlayer2D nodes later without code changes.
##
## The stub is deliberately forgiving: missing sound ids, missing stream
## resources, or invalid parameters never crash the calling scene.

const SFX_DICT: Dictionary = {
	&"ui.click": "res://assets/audio/sfx/ui_click.ogg",
	&"ui.hover": "res://assets/audio/sfx/ui_hover.ogg",
	&"ui.confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	&"ui.cancel": "res://assets/audio/sfx/ui_cancel.ogg",
	&"ui.error": "res://assets/audio/sfx/ui_error.ogg",
	&"event.choice": "res://assets/audio/sfx/event_choice.ogg",
	&"event.surprise": "res://assets/audio/sfx/event_surprise.ogg",
	&"event.combat_hit": "res://assets/audio/sfx/combat_hit.ogg",
	&"item.pickup": "res://assets/audio/sfx/item_pickup.ogg",
	&"item.drop": "res://assets/audio/sfx/item_drop.ogg",
	&"facility.build": "res://assets/audio/sfx/facility_build.ogg",
	&"facility.break": "res://assets/audio/sfx/facility_break.ogg",
	&"morning.bell": "res://assets/audio/sfx/morning_bell.ogg",
}

const BGM_DICT: Dictionary = {
	&"main_theme": "res://assets/audio/bgm/main_theme.ogg",
	&"menu": "res://assets/audio/bgm/menu.ogg",
	&"morning_calm": "res://assets/audio/bgm/morning_calm.ogg",
	&"exploration": "res://assets/audio/bgm/exploration.ogg",
	&"combat": "res://assets/audio/bgm/combat.ogg",
	&"tension": "res://assets/audio/bgm/tension.ogg",
	&"ending_hopeful": "res://assets/audio/bgm/ending_hopeful.ogg",
	&"ending_bleak": "res://assets/audio/bgm/ending_bleak.ogg",
}

## Cumulative call counters — useful for tests and UI badges.
var sfx_call_count: int = 0
var bgm_call_count: int = 0
var stop_call_count: int = 0

var _current_bgm: StringName = &""
var _last_volume_db: float = 0.0
var _last_fade_ms: int = 1000
var _muted: bool = false

func _ready() -> void:
	# Pure stub — no signals, no playback nodes.
	pass

func is_muted() -> bool:
	return _muted

func set_muted(muted: bool) -> void:
	_muted = muted

## Play a short sound effect by id. `volume_db` is recorded but not applied.
## Returns true when the id was recognized, false otherwise (never crashes).
func play_sfx(id: StringName, volume_db: float = 0.0) -> bool:
	sfx_call_count += 1
	var sid: String = String(id)
	if sid.is_empty():
		print("[AudioStub] play_sfx empty id (volume=", volume_db, ")")
		return false
	var path: Variant = SFX_DICT.get(id, null)
	if path == null:
		print("[AudioStub] play_sfx unknown id: ", sid)
		return false
	if _muted:
		print("[AudioStub] play_sfx muted, skipping: ", sid)
		return true
	# Real implementation would resolve `path` to an AudioStream and feed it
	# to an AudioStreamPlayer. The stub only logs the resolved id/path/volume.
	print("[AudioStub] play_sfx id=", sid, " path=", path, " volume_db=", volume_db)
	return true

## Crossfade to a background track by id. `fade_ms` is recorded but not
## applied. Returns true when the id was recognized.
func play_bgm(id: StringName, fade_ms: int = 1000) -> bool:
	bgm_call_count += 1
	_last_fade_ms = fade_ms
	var sid: String = String(id)
	if sid.is_empty():
		print("[AudioStub] play_bgm empty id (fade=", fade_ms, ")")
		return false
	var path: Variant = BGM_DICT.get(id, null)
	if path == null:
		print("[AudioStub] play_bgm unknown id: ", sid)
		return false
	if _muted:
		print("[AudioStub] play_bgm muted, skipping: ", sid)
		_current_bgm = id
		return true
	_current_bgm = id
	print("[AudioStub] play_bgm id=", sid, " path=", path, " fade_ms=", fade_ms)
	return true

## Stop the currently playing background track.
func stop_bgm() -> void:
	stop_call_count += 1
	if _current_bgm == &"":
		print("[AudioStub] stop_bgm (no active track)")
		return
	print("[AudioStub] stop_bgm id=", String(_current_bgm))
	_current_bgm = &""

func get_current_bgm() -> StringName:
	return _current_bgm

func get_last_volume_db() -> float:
	return _last_volume_db

func get_last_fade_ms() -> int:
	return _last_fade_ms

## Look up the underlying resource path for an SFX id (test helper).
func get_sfx_path(id: StringName) -> String:
	var v: Variant = SFX_DICT.get(id, "")
	if typeof(v) == TYPE_STRING:
		return v
	return ""

func get_bgm_path(id: StringName) -> String:
	var v: Variant = BGM_DICT.get(id, "")
	if typeof(v) == TYPE_STRING:
		return v
	return ""

func has_sfx(id: StringName) -> bool:
	return SFX_DICT.has(id)

func has_bgm(id: StringName) -> bool:
	return BGM_DICT.has(id)

func sfx_count() -> int:
	return SFX_DICT.size()

func bgm_count() -> int:
	return BGM_DICT.size()