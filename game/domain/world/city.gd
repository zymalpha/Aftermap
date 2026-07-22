class_name City extends RefCounted

## The campaign city. Holds 6 POIs at fixed positions and a simple
## travel-cost graph. Costs use Manhattan distance + party-size penalty
## per 策划09 §5.

const _PATH: String = "res://game/domain/world/city.gd"

const POIScript = preload("res://game/domain/world/poi.gd")

const POI_DEFS: Array = [
	{"poi_id": "poi_clinic_1",  "poi_class": "clinic",  "grid_pos": Vector2i(2,  4),  "grid_w": 12, "grid_h": 12},
	{"poi_id": "poi_grocery_1", "poi_class": "grocery", "grid_pos": Vector2i(8,  2),  "grid_w": 14, "grid_h": 10},
	{"poi_id": "poi_police_1",  "poi_class": "police",  "grid_pos": Vector2i(4,  8),  "grid_w": 16, "grid_h": 16},
	{"poi_id": "poi_school_1",  "poi_class": "school",  "grid_pos": Vector2i(12, 6),  "grid_w": 18, "grid_h": 14},
	{"poi_id": "poi_depot_1",   "poi_class": "depot",   "grid_pos": Vector2i(10, 12), "grid_w": 16, "grid_h": 16},
	{"poi_id": "poi_park_1",    "poi_class": "park",    "grid_pos": Vector2i(6,  12), "grid_w": 20, "grid_h": 20},
]

var pois: Dictionary = {}       # poi_id -> PointOfInterest
var positions: Dictionary = {}   # poi_id -> Vector2i
var home_id: String = "poi_base"  # shelter anchor

func _init() -> void:
	pois = {}
	positions = {}
	for def in POI_DEFS:
		var pid: String = String(def["poi_id"])
		var p: RefCounted = POIScript.new(pid, String(def["poi_class"]))
		p.grid_w = int(def["grid_w"])
		p.grid_h = int(def["grid_h"])
		pois[pid] = p
		positions[pid] = def["grid_pos"]

func _log(msg: String) -> void:
	push_warning("[City] " + msg)

func list_poi_ids() -> Array:
	var out: Array = []
	for k in pois.keys():
		out.append(String(k))
	return out

func get_poi(poi_id: String) -> RefCounted:
	return pois.get(poi_id, null)

func position_of(poi_id: String) -> Vector2i:
	var v: Variant = positions.get(poi_id, Vector2i.ZERO)
	if typeof(v) == TYPE_VECTOR2I:
		return v
	return Vector2i(0, 0)

## Distance between two POIs (Manhattan). Returns -1 if either unknown.
func distance_between(from_id: String, to_id: String) -> int:
	if not positions.has(from_id) or not positions.has(to_id):
		return -1
	var a: Vector2i = positions[from_id]
	var b: Vector2i = positions[to_id]
	return int(abs(a.x - b.x) + abs(a.y - b.y))

## Travel time in minutes. Base = 12 min per tile. Each tile adds +2 min
## per extra party member (>= 2 people). party_size <= 0 treated as 1.
func travel_time(from_id: String, to_id: String, party_size: int = 1) -> int:
	var d: int = distance_between(from_id, to_id)
	if d < 0:
		return -1
	var base: int = d * 12
	var extra: int = max(0, party_size - 1)
	return base + d * 2 * extra

## Add or replace a POI (for city customisation).
func register_poi(poi: RefCounted, pos: Vector2i) -> bool:
	if poi == null or String(poi.poi_id) == "":
		return false
	pois[String(poi.poi_id)] = poi
	positions[String(poi.poi_id)] = pos
	return true

func to_dict() -> Dictionary:
	var out: Dictionary = {"pois": {}, "positions": {}}
	for pid in pois.keys():
		(out["pois"] as Dictionary)[String(pid)] = (pois[pid] as RefCounted).to_dict()
		var p: Vector2i = positions[pid]
		(out["positions"] as Dictionary)[String(pid)] = [p.x, p.y]
	out["home_id"] = home_id
	return out

func from_dict(d: Dictionary) -> void:
	pois = {}
	positions = {}
	var p_dict: Variant = d.get("pois", {})
	if typeof(p_dict) != TYPE_DICTIONARY:
		return
	for pid in (p_dict as Dictionary).keys():
		var poi_ref: RefCounted = POIScript.new(String(pid), "clinic")
		poi_ref.from_dict((p_dict as Dictionary)[pid])
		pois[String(pid)] = poi_ref
	var pos_dict: Variant = d.get("positions", {})
	if typeof(pos_dict) == TYPE_DICTIONARY:
		for pid in (pos_dict as Dictionary).keys():
			var raw: Variant = (pos_dict as Dictionary)[pid]
			if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
				positions[String(pid)] = Vector2i(int(raw[0]), int(raw[1]))
	home_id = String(d.get("home_id", "poi_base"))