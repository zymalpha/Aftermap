class_name PointOfInterest extends RefCounted

## A Point of Interest on the city grid. Mirrors 策划12 §6 POI model.
##
## Fields:
##   poi_id:     "poi_<class>_<n>"
##   poi_class:  clinic / grocery / police / school / depot / park
##   grid_w / grid_h: POI interior dimensions (for tactical scene)
##   loot_table: { item_id: { weight, min_qty, max_qty } }
##   cleared:    bool (true after first search)
##   loot_state: { item_id: qty_remaining }
##   notes:      String

const _PATH: String = "res://game/domain/world/poi.gd"

const POI_CLASSES: Array[String] = [
	"clinic", "grocery", "police", "school", "depot", "park",
]

var poi_id: String = ""
var poi_class: String = "clinic"
var grid_w: int = 16
var grid_h: int = 16
var loot_table: Dictionary = {}
var cleared: bool = false
var loot_state: Dictionary = {}
var notes: String = ""

func _init(p_id: String = "", p_class: String = "clinic") -> void:
	poi_id = p_id
	poi_class = p_class
	grid_w = 16
	grid_h = 16
	loot_table = {}
	cleared = false
	loot_state = {}
	notes = ""

func _log(msg: String) -> void:
	push_warning("[POI:" + poi_id + "] " + msg)

## Set loot table (from a LootTable row: { item_id, weight, min_qty, max_qty }).
func set_loot_table(rows: Array) -> void:
	loot_table = {}
	for row in rows:
		var iid: String = String(row.get("item_id", ""))
		if iid == "":
			continue
		loot_table[iid] = {
			"weight": int(row.get("weight", 0)),
			"min_qty": int(row.get("min_qty", 1)),
			"max_qty": int(row.get("max_qty", 1)),
		}

## Enter the POI. Returns Dictionary { entered, cleared, has_loot }.
func enter() -> Dictionary:
	return {"entered": true, "cleared": cleared, "has_loot": not cleared}

## Search the POI. Pure function: returns a dictionary of drops based on
## `rng` (RngService-like) and `stream` (StringName). Does not mutate
## loot_state — caller decides whether to apply via apply_loot().
func search(rng: RefCounted, stream: StringName) -> Array:
	if cleared:
		return []
	if rng == null or loot_table.is_empty():
		return []
	var total_w: int = 0
	for iid in loot_table.keys():
		total_w += int((loot_table[iid] as Dictionary).get("weight", 0))
	if total_w <= 0:
		return []
	var drops: Array = []
	var pick: int = int(rng.call("get_rng", stream)) % total_w
	var acc: int = 0
	var chosen_id: String = ""
	for iid in loot_table.keys():
		acc += int((loot_table[iid] as Dictionary).get("weight", 0))
		if pick < acc:
			chosen_id = String(iid)
			break
	if chosen_id != "":
		var row: Dictionary = loot_table[chosen_id]
		var max_q: int = int(row.get("max_qty", 1))
		var min_q: int = int(row.get("min_qty", 1))
		var qty: int = min_q
		if max_q > min_q:
			qty = int(rng.call("get_rng", stream)) % (max_q - min_q + 1) + min_q
		drops.append({"item_id": chosen_id, "qty": qty})
	return drops

## Apply loot drops into loot_state (decrement remaining). Returns the
## actual list of items granted (may be empty if pool exhausted).
func apply_loot(drops: Array) -> Array:
	var granted: Array = []
	if cleared:
		return granted
	for d in drops:
		var iid: String = String(d.get("item_id", ""))
		var qty: int = int(d.get("qty", 0))
		if iid == "" or qty <= 0:
			continue
		var remaining: int = int(loot_state.get(iid, qty))
		var take: int = min(qty, remaining)
		if take <= 0:
			continue
		loot_state[iid] = remaining - take
		granted.append({"item_id": iid, "qty": take})
	if not cleared:
		cleared = true
	return granted

## Loot the POI in one shot (search + apply). Convenience wrapper.
func loot(rng: RefCounted, stream: StringName) -> Array:
	var drops: Array = search(rng, stream)
	return apply_loot(drops)

func to_dict() -> Dictionary:
	return {
		"poi_id": poi_id,
		"poi_class": poi_class,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"loot_table": loot_table.duplicate(true),
		"cleared": cleared,
		"loot_state": loot_state.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	poi_id = String(d.get("poi_id", poi_id))
	poi_class = String(d.get("poi_class", poi_class))
	grid_w = int(d.get("grid_w", grid_w))
	grid_h = int(d.get("grid_h", grid_h))
	var lt: Variant = d.get("loot_table", {})
	if typeof(lt) == TYPE_DICTIONARY:
		loot_table = (lt as Dictionary).duplicate(true)
	cleared = bool(d.get("cleared", cleared))
	var ls: Variant = d.get("loot_state", {})
	if typeof(ls) == TYPE_DICTIONARY:
		loot_state = (ls as Dictionary).duplicate(true)