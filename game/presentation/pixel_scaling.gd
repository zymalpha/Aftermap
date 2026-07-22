class_name PixelScaling extends RefCounted

## Pure-math pixel scaling helper. No GPU access; safe in headless tests.
##
## Constraints (per design):
##   - Nearest-neighbor is the only allowed filter.
##   - Only integer scales are allowed (1x, 2x, 3x, ...).
##   - Non-integer scales are either rejected or clamped upward to the next
##     integer with a warning, depending on the entry point.
##   - PIXELS_PER_TILE = 32 is the canonical tile dimension used by the
##     grid module.

const _PATH: String = "res://game/presentation/pixel_scaling.gd"

const PIXELS_PER_TILE: int = 32

const FILTER_NEAREST: int = 0
const FILTER_LINEAR: int = 1  # defined but rejected at runtime; nearest-only policy

const SUPPORTED_SCALES: Array = [1, 2, 3]

# Strict mode: any non-integer factor is rejected with reason="non_integer_scale".
static func compute_scaled(src_w: int, src_h: int, scale: float, filter: int) -> Dictionary:
	if filter != FILTER_NEAREST:
		return {
			"rejected": true,
			"reason": "non_nearest_filter",
			"src_w": src_w,
			"src_h": src_h,
			"scale": scale,
			"filter": filter,
		}
	if not _is_integer(scale):
		return {
			"rejected": true,
			"reason": "non_integer_scale",
			"src_w": src_w,
			"src_h": src_h,
			"scale": scale,
			"filter": filter,
		}
	var s: int = int(scale)
	if s < 1:
		return {
			"rejected": true,
			"reason": "scale_below_one",
			"src_w": src_w,
			"src_h": src_h,
			"scale": s,
			"filter": filter,
		}
	var out_w: int = src_w * s
	var out_h: int = src_h * s
	return {
		"rejected": false,
		"reason": "",
		"src_w": src_w,
		"src_h": src_h,
		"scale": s,
		"filter": filter,
		"w": out_w,
		"h": out_h,
		"pixel_aligned": true,
	}

# Lenient mode: non-integer factor is rounded up to the next integer and
# a "warned" flag is set so the caller can surface a user-visible warning.
static func compute_scaled_clamped(src_w: int, src_h: int, scale: float, filter: int) -> Dictionary:
	if filter != FILTER_NEAREST:
		return {
			"rejected": true,
			"reason": "non_nearest_filter",
			"src_w": src_w,
			"src_h": src_h,
			"scale": scale,
			"filter": filter,
		}
	if scale < 1.0:
		return {
			"rejected": true,
			"reason": "scale_below_one",
			"src_w": src_w,
			"src_h": src_h,
			"scale": scale,
			"filter": filter,
		}
	var s: int = int(scale)
	var warned: bool = false
	var original: String = ""
	if float(s) != scale:
		warned = true
		original = str(scale)
		s = s + 1  # round up to next integer
		if s < 1:
			s = 1
	var out_w: int = src_w * s
	var out_h: int = src_h * s
	return {
		"rejected": false,
		"reason": "",
		"src_w": src_w,
		"src_h": src_h,
		"scale": s,
		"original_factor": original,
		"warned": warned,
		"filter": filter,
		"w": out_w,
		"h": out_h,
		"pixel_aligned": true,
	}

static func supported_scales() -> Array:
	return SUPPORTED_SCALES.duplicate()

static func _is_integer(v: float) -> bool:
	return floor(v) == v