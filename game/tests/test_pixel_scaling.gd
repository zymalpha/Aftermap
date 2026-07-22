extends SceneTree

## Stage 4 / P0 spike: pixel scaling (nearest, integer-only).
##
## We don't open a real rendering context here. Instead we drive a small
## deterministic scaling table and assert:
##   - nearest at integer scales (1x, 2x, 3x) yields pixel-aligned buffers
##   - non-integer factors are rejected (or rounded with a warning)
##   - PIXELS_PER_TILE = 32 is honored

const PixelScalingScript: GDScript = preload("res://game/presentation/pixel_scaling.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_pixel_scaling start ===")
	_test_constants()
	_test_nearest_1x_pixel_aligned()
	_test_nearest_2x_pixel_aligned()
	_test_nearest_3x_pixel_aligned()
	_test_non_integer_rejected()
	_test_non_integer_clamped_with_warning()
	_test_scaling_api_table()
	print("=== test_pixel_scaling result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  " + label)
	else:
		_fail_count += 1
		printerr("  FAIL  " + label)

func _test_constants() -> void:
	print("[1] constants")
	_expect(PixelScalingScript.PIXELS_PER_TILE == 32, "PIXELS_PER_TILE=32")
	_expect(PixelScalingScript.FILTER_NEAREST == 0, "nearest filter id = 0")

func _test_nearest_1x_pixel_aligned() -> void:
	print("[2] 1x pixel-aligned")
	var src_w: int = 4
	var src_h: int = 4
	var out: Dictionary = PixelScalingScript.compute_scaled(src_w, src_h, 1, PixelScalingScript.FILTER_NEAREST)
	_expect(int(out["w"]) == 4 and int(out["h"]) == 4, "1x → 4x4")
	_expect(int(out["filter"]) == PixelScalingScript.FILTER_NEAREST, "filter = nearest")
	_expect(bool(out["pixel_aligned"]) == true, "pixel_aligned true at 1x")
	_expect(bool(out["rejected"]) == false, "1x not rejected")

func _test_nearest_2x_pixel_aligned() -> void:
	print("[3] 2x pixel-aligned")
	var out: Dictionary = PixelScalingScript.compute_scaled(8, 6, 2, PixelScalingScript.FILTER_NEAREST)
	_expect(int(out["w"]) == 16 and int(out["h"]) == 12, "8x6 at 2x → 16x12")
	_expect(bool(out["pixel_aligned"]) == true, "pixel_aligned true at 2x")

func _test_nearest_3x_pixel_aligned() -> void:
	print("[4] 3x pixel-aligned")
	var out: Dictionary = PixelScalingScript.compute_scaled(10, 7, 3, PixelScalingScript.FILTER_NEAREST)
	_expect(int(out["w"]) == 30 and int(out["h"]) == 21, "10x7 at 3x → 30x21")
	_expect(bool(out["pixel_aligned"]) == true, "pixel_aligned true at 3x")

func _test_non_integer_rejected() -> void:
	print("[5] 1.5x strict-reject")
	var out: Dictionary = PixelScalingScript.compute_scaled(4, 4, 1.5, PixelScalingScript.FILTER_NEAREST)
	_expect(bool(out["rejected"]) == true, "1.5x → rejected")
	_expect(String(out["reason"]) == "non_integer_scale", "reason = non_integer_scale")

func _test_non_integer_clamped_with_warning() -> void:
	print("[6] 1.5x clamped to 2x with warn")
	var out: Dictionary = PixelScalingScript.compute_scaled_clamped(4, 4, 1.5, PixelScalingScript.FILTER_NEAREST)
	_expect(int(out["scale"]) == 2, "1.5x clamped to 2")
	_expect(int(out["w"]) == 8 and int(out["h"]) == 8, "clamped output 8x8")
	_expect(bool(out["warned"]) == true, "warned=true")
	_expect(String(out["original_factor"]) == "1.5", "original_factor recorded")

func _test_scaling_api_table() -> void:
	print("[7] scaling table")
	var table: Array = PixelScalingScript.supported_scales()
	_expect(table.size() >= 3, "supports at least 1x/2x/3x")
	var has_1: bool = false
	var has_2: bool = false
	var has_3: bool = false
	for s in table:
		var v: int = int(s)
		if v == 1:
			has_1 = true
		elif v == 2:
			has_2 = true
		elif v == 3:
			has_3 = true
	_expect(has_1 and has_2 and has_3, "table includes 1, 2, 3")