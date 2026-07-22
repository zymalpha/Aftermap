class_name Stockpile extends RefCounted

## Base inventory. Holds two layers:
##   resources: 7-bucket tally (food/water/material/parts/medical/fuel/ammo)
##   items:     { item_id: qty } for tracked stackable items
##
## Daily consumption is the canonical §09 baseline:
##   food  = food_per_person * people
##   water = water_per_person * people
##
## Items can be added/removed/consumed/produced. Resource buckets are
## never negative (clamped at 0).

const _PATH: String = "res://game/domain/inventory/stock.gd"

const RESOURCE_KEYS: Array[String] = [
	"food", "water", "material", "parts", "medical", "fuel", "ammo",
]

const DEFAULT_FOOD_PER_PERSON: int = 2
const DEFAULT_WATER_PER_PERSON: int = 3

var resources: Dictionary = {}
var items: Dictionary = {}

func _init() -> void:
	resources = {}
	for k in RESOURCE_KEYS:
		resources[k] = 0
	items = {}

func _log(msg: String) -> void:
	push_warning("[Stockpile] " + msg)

## Resource ops ------------------------------------------------------------

func add(resource_key: String, qty: int) -> int:
	if not RESOURCE_KEYS.has(resource_key):
		return int(resources.get(resource_key, 0))
	var cur: int = int(resources.get(resource_key, 0))
	resources[resource_key] = max(0, cur + qty)
	return int(resources[resource_key])

func remove(resource_key: String, qty: int) -> int:
	if not RESOURCE_KEYS.has(resource_key):
		return int(resources.get(resource_key, 0))
	var cur: int = int(resources.get(resource_key, 0))
	var new_val: int = max(0, cur - qty)
	resources[resource_key] = new_val
	# Return how many were actually consumed (capped at cur).
	if qty >= cur:
		return cur
	return qty

func consume(resource_key: String, qty: int) -> int:
	return remove(resource_key, qty)

func produce(resource_key: String, qty: int) -> int:
	return add(resource_key, qty)

func get_resource(resource_key: String) -> int:
	return int(resources.get(resource_key, 0))

## Item ops ---------------------------------------------------------------

func add_item(item_id: String, qty: int) -> int:
	if item_id == "" or qty <= 0:
		return int(items.get(item_id, 0))
	items[item_id] = int(items.get(item_id, 0)) + qty
	return int(items[item_id])

func remove_item(item_id: String, qty: int) -> int:
	if item_id == "" or qty <= 0:
		return int(items.get(item_id, 0))
	var cur: int = int(items.get(item_id, 0))
	var actual: int = min(cur, qty)
	items[item_id] = cur - actual
	return actual

## Daily consumption: returns Dictionary { consumed: { food, water, ... }, missing: { food, water, ... } }
## missing indicates shortfall (insufficient resources to consume full amount).
func daily_consumption(food_per_person: int = DEFAULT_FOOD_PER_PERSON,
		water_per_person: int = DEFAULT_WATER_PER_PERSON, people: int = 1) -> Dictionary:
	var people_n: int = max(1, people)
	var need_food: int = food_per_person * people_n
	var need_water: int = water_per_person * people_n
	var have_food: int = get_resource("food")
	var have_water: int = get_resource("water")
	var ate: int = consume("food", need_food)
	var drank: int = consume("water", need_water)
	return {
		"consumed": {"food": ate, "water": drank},
		"needed": {"food": need_food, "water": need_water},
		"missing": {"food": need_food - ate, "water": need_water - drank},
	}

## Serialisation ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"resources": resources.duplicate(true),
		"items": items.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	resources = {}
	for k in RESOURCE_KEYS:
		resources[k] = 0
	var res_raw: Variant = d.get("resources", {})
	if typeof(res_raw) == TYPE_DICTIONARY:
		for k in (res_raw as Dictionary).keys():
			resources[String(k)] = max(0, int((res_raw as Dictionary)[k]))
	items = {}
	var items_raw: Variant = d.get("items", {})
	if typeof(items_raw) == TYPE_DICTIONARY:
		for k in (items_raw as Dictionary).keys():
			items[String(k)] = max(0, int((items_raw as Dictionary)[k]))