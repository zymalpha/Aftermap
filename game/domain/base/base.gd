class_name Base extends RefCounted

## The player's base camp. Owns:
##   - facilities: Dictionary keyed by id
##   - state: 6 base stats (integrity/defense/hygiene/noise/power/morale) 0..100
##   - stockpile: Stockpile
##   - jobs: JobBoard
##
## daily_tick(session) applies the §09 baseline per day:
##   - resource consumption (food/water per person)
##   - hygiene/noise drift based on jobs filled
##   - morale drift
##   - facility upkeep consumption
## Returns a Dictionary summary used by MorningReport.

const _PATH: String = "res://game/domain/base/base.gd"

const StockpileScript: GDScript = preload("res://game/domain/inventory/stock.gd")
const FacilityScript: GDScript = preload("res://game/domain/base/facility.gd")
const JobBoardScript: GDScript = preload("res://game/domain/base/jobs.gd")

const STATE_KEYS: Array[String] = [
	"integrity", "defense", "hygiene", "noise", "power", "morale",
]

const DEFAULT_STATE: Dictionary = {
	"integrity": 100,
	"defense": 60,
	"hygiene": 80,
	"noise": 20,
	"power": 70,
	"morale": 50,
}

var name: String = "Unnamed Shelter"
var facilities: Dictionary = {}  # id -> Facility
var state: Dictionary = {}
var jobs: RefCounted = null
var stockpile: RefCounted = null
var population: int = 0

func _init() -> void:
	state = DEFAULT_STATE.duplicate(true)
	jobs = JobBoardScript.new()
	stockpile = StockpileScript.new()
	facilities = {}
	population = 0

func _log(msg: String) -> void:
	push_warning("[Base] " + msg)

func add_facility(fac: RefCounted) -> bool:
	if fac == null or String(fac.id) == "":
		return false
	facilities[String(fac.id)] = fac
	return true

func remove_facility(fac_id: String) -> bool:
	if facilities.has(fac_id):
		facilities.erase(fac_id)
		return true
	return false

func get_facility(fac_id: String) -> RefCounted:
	return facilities.get(fac_id, null)

## Set the population. Used to drive daily_consumption.
func set_population(n: int) -> void:
	population = max(0, n)

## Assign role via JobBoard convenience.
func assign_role(character_id: String, role_id: String) -> bool:
	return jobs.assign(role_id, character_id)

## Daily tick: returns Dictionary consumed/produced for MorningReport.
func daily_tick(session: RefCounted = null) -> Dictionary:
	var consumed: Dictionary = {}
	var produced: Dictionary = {}
	for k in StockpileScript.RESOURCE_KEYS:
		consumed[k] = 0
		produced[k] = 0
	# 1. Food/water consumption.
	var cons: Dictionary = stockpile.daily_consumption(2, 3, population)
	consumed["food"] = int((cons["consumed"] as Dictionary).get("food", 0))
	consumed["water"] = int((cons["consumed"] as Dictionary).get("water", 0))
	# 2. Facility upkeep.
	for fid in facilities.keys():
		var f: RefCounted = facilities[fid]
		for r in f.daily_upkeep.keys():
			var qty: int = int(f.daily_upkeep[r])
			if qty > 0:
				consumed[String(r)] = int(consumed.get(String(r), 0)) + stockpile.consume(String(r), qty)
	# 3. Morale drift based on jobs filled.
	var active_jobs: Array = jobs.list_active_jobs()
	var filled: int = active_jobs.size()
	if filled >= 6:
		state["morale"] = clampi(int(state.get("morale", 50)) + 1, 0, 100)
	elif filled == 0:
		state["morale"] = clampi(int(state.get("morale", 50)) - 2, 0, 100)
	# 4. Hygiene/noise drift.
	if filled > 0:
		state["hygiene"] = clampi(int(state.get("hygiene", 80)) - 1, 0, 100)
		state["noise"] = clampi(int(state.get("noise", 20)) + 1, 0, 100)
	# 5. Power: sum facility power_draw_kw.
	var total_power: float = 0.0
	for fid in facilities.keys():
		total_power += float((facilities[fid] as RefCounted).power_draw_kw)
	# Map to 0..100: positive -> surplus, negative -> deficit (clamped).
	state["power"] = clampi(70 + int(total_power), 0, 100)
	# 6. Tiny food production if garden exists and assigned.
	if jobs.assignments.has("garden") and (jobs.assignments["garden"] as Array).size() > 0:
		var produced_food: int = stockpile.produce("food", 1)
		produced["food"] = produced_food
	return {"consumed": consumed, "produced": produced}

func to_dict() -> Dictionary:
	var facs: Dictionary = {}
	for fid in facilities.keys():
		(facs as Dictionary)[fid] = (facilities[fid] as RefCounted).to_dict()
	return {
		"name": name,
		"facilities": facs,
		"state": state.duplicate(true),
		"jobs": jobs.to_dict(),
		"stockpile": stockpile.to_dict(),
		"population": population,
	}

func from_dict(d: Dictionary) -> void:
	name = String(d.get("name", "Unnamed Shelter"))
	state = DEFAULT_STATE.duplicate(true)
	var st: Variant = d.get("state", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in (st as Dictionary).keys():
			state[String(k)] = clampi(int((st as Dictionary)[k]), 0, 100)
	var facs: Variant = d.get("facilities", {})
	facilities = {}
	if typeof(facs) == TYPE_DICTIONARY:
		for fid in (facs as Dictionary).keys():
			var f: RefCounted = FacilityScript.new(String(fid), "sleep")
			f.from_dict((facs as Dictionary)[fid])
			facilities[String(fid)] = f
	var jb: Variant = d.get("jobs", {})
	if typeof(jb) == TYPE_DICTIONARY:
		jobs.from_dict(jb)
	var sp: Variant = d.get("stockpile", {})
	if typeof(sp) == TYPE_DICTIONARY:
		stockpile.from_dict(sp)
	population = int(d.get("population", 0))