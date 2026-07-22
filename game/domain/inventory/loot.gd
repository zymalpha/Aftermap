class_name LootTable extends RefCounted

## Loot table tied to a POI class. Maps POI -> weighted item pool.
## Loot draws use the campaign RNG (ADR-0003) so drops are reproducible
## given the same seed. Pure-data: no engine deps.

const _PATH: String = "res://game/domain/inventory/loot.gd"

## POI class -> Array of { item_id, weight, min_qty, max_qty }
const DEFAULT_TABLES: Dictionary = {
	"clinic": [
		{"item_id": "itm_bandage", "weight": 60, "min_qty": 1, "max_qty": 4},
		{"item_id": "itm_antibiotics", "weight": 30, "min_qty": 1, "max_qty": 2},
		{"item_id": "itm_water_bottle", "weight": 10, "min_qty": 1, "max_qty": 3},
	],
	"grocery": [
		{"item_id": "itm_canned_food", "weight": 50, "min_qty": 1, "max_qty": 6},
		{"item_id": "itm_water_bottle", "weight": 40, "min_qty": 1, "max_qty": 6},
		{"item_id": "itm_bandage", "weight": 10, "min_qty": 1, "max_qty": 2},
	],
	"police": [
		{"item_id": "itm_handgun", "weight": 30, "min_qty": 1, "max_qty": 1},
		{"item_id": "itm_9mm_ammo", "weight": 50, "min_qty": 4, "max_qty": 16},
		{"item_id": "itm_walkie_talkie", "weight": 15, "min_qty": 1, "max_qty": 2},
		{"item_id": "itm_flashlight", "weight": 5, "min_qty": 1, "max_qty": 1},
	],
	"school": [
		{"item_id": "itm_notebook", "weight": 50, "min_qty": 1, "max_qty": 3},
		{"item_id": "itm_bandage", "weight": 30, "min_qty": 1, "max_qty": 2},
		{"item_id": "itm_canned_food", "weight": 20, "min_qty": 1, "max_qty": 2},
	],
	"depot": [
		{"item_id": "itm_fuel_can", "weight": 30, "min_qty": 1, "max_qty": 2},
		{"item_id": "itm_crowbar", "weight": 20, "min_qty": 1, "max_qty": 1},
		{"item_id": "itm_map", "weight": 30, "min_qty": 1, "max_qty": 1},
		{"item_id": "itm_9mm_ammo", "weight": 20, "min_qty": 2, "max_qty": 8},
	],
	"park": [
		{"item_id": "itm_water_bottle", "weight": 60, "min_qty": 1, "max_qty": 4},
		{"item_id": "itm_canned_food", "weight": 30, "min_qty": 1, "max_qty": 2},
		{"item_id": "itm_notebook", "weight": 10, "min_qty": 1, "max_qty": 1},
	],
}

var tables: Dictionary = {}

func _init() -> void:
	tables = DEFAULT_TABLES.duplicate(true)

func _log(msg: String) -> void:
	push_warning("[LootTable] " + msg)

func get_table(poi_class: String) -> Array:
	return tables.get(poi_class, [])

## Draw N items from a POI's loot table using rng (RefCounted with
## get_rng(stream) returning int). Returns Array of { item_id, qty }.
func roll(poi_class: String, draws: int, rng: RefCounted, stream: StringName) -> Array:
	var table: Array = get_table(poi_class)
	if table.is_empty() or rng == null:
		return []
	var total_w: int = 0
	for row in table:
		total_w += int(row.get("weight", 0))
	if total_w <= 0:
		return []
	var out: Array = []
	for i in range(max(1, draws)):
		var pick: int = int(rng.call("get_rng", stream)) % total_w
		var acc: int = 0
		var chosen: Dictionary = table[0]
		for row in table:
			acc += int(row.get("weight", 0))
			if pick < acc:
				chosen = row
				break
		var qty: int = int(rng.call("get_rng", stream)) % (int(chosen.get("max_qty", 1)) - int(chosen.get("min_qty", 1)) + 1) + int(chosen.get("min_qty", 1))
		out.append({"item_id": String(chosen.get("item_id", "")), "qty": qty})
	return out

func to_dict() -> Dictionary:
	return {"tables": tables.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	var t: Variant = d.get("tables", {})
	if typeof(t) == TYPE_DICTIONARY:
		tables = (t as Dictionary).duplicate(true)