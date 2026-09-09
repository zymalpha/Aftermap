extends RefCounted

## All playable campaign mutations are invoked by GameSession.issue_command.
## JSON-compatible state (including tactical positions) survives save/load.
const GridScript: GDScript = preload("res://game/domain/tactical/grid.gd")
const Sight: GDScript = preload("res://game/domain/tactical/visibility.gd")
const Paths: GDScript = preload("res://game/domain/tactical/pathfinder.gd")
const CombatScript: GDScript = preload("res://game/domain/tactical/combat.gd")
const ROLES: Array[String] = ["water", "cook", "engineering", "medical", "guard", "rest"]
const W: int = 24
const H: int = 16
static var _definitions: Dictionary = {}
var session: RefCounted
var state: Dictionary
var mission: Dictionary

static func data() -> Dictionary:
	if _definitions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/campaign/scenario.json"))
		if parsed is Dictionary:
			_definitions = parsed
	return _definitions

func execute(owner: RefCounted, command: Dictionary) -> Dictionary:
	session = owner
	state = session.base_state.get("campaign", {})
	mission = state.get("mission", {})
	var action: String = String(command.get("action", ""))
	if action == "initialize":
		return _initialize()
	if state.is_empty():
		return _no("no_campaign")
	if action == "acknowledge" and state.phase == "report":
		state.phase = "base"
		return _ok()
	if state.phase == "ending":
		return _no("campaign_over")
	if action == "choose" and state.phase == "event":
		return _choose(int(command.get("index", -1)))
	if state.phase == "tactical":
		return _tactical(command)
	if state.phase != "base":
		return _no("wrong_phase")
	match action:
		"assign":
			var c: Dictionary = character(String(command.get("character", "")))
			var role: String = String(command.get("role", ""))
			if c.is_empty() or not ROLES.has(role) or int(c.stats.hp) <= 0:
				return _no("invalid_character")
			c.job = role
			return _ok("assigned")
		"build":
			return _build(String(command.get("facility", "")))
		"heal":
			return _heal(character(String(command.get("character", ""))))
		"radio":
			if not state.built.has("radio"):
				return _no("need_radio")
			if int(state.signal) >= 100:
				return _no("signal_complete")
			if int(state.actions) <= 0:
				return _no("no_actions")
			if not _pay({"parts":2,"fuel":1}):
				return _no("not_enough_resources")
			state.actions -= 1
			state.signal = mini(100, int(state.signal) + 20)
			_journal("radio", {"signal":state.signal})
			return _ok("radio")
		"depart":
			return _depart(String(command.get("location", "")), String(command.get("character", "")))
		"end_day":
			var events: Array = data().get("events", [])
			state.event_index = int(session.rng.get_rng(StringName("daily_director_play_" + str(session.clock.current_day)))) % events.size()
			state.phase = "event"
			return _ok()
	return _no("unknown_action")

func _initialize() -> Dictionary:
	state = {"phase":"base", "actions":2, "signal":0, "built":[], "mission":{}, "visits":{}, "journal":[], "kills":0, "sorties":0, "total_loot":0, "summary":{}, "event_index":0, "ending":""}
	session.base_state.campaign = state
	session.base_state.city_pressure = 8
	var defaults: Array = ["medical", "engineering", "water", "cook"]
	for i in range(session.characters.size()):
		session.characters[i].job = defaults[i % defaults.size()]
	_journal("arrival")
	return _ok()

func character(id: String) -> Dictionary:
	for c in session.characters:
		if String(c.get("id", "")) == id:
			return c
	return {}

func alive() -> Array:
	return session.characters.filter(func(c: Dictionary) -> bool: return int(c.stats.hp) > 0)

func _build(id: String) -> Dictionary:
	if state.built.has(id):
		return _no("already_built")
	if int(state.actions) <= 0:
		return _no("no_actions")
	for f in data().facilities:
		if f.id == id:
			if not _pay(f.cost):
				return _no("not_enough_resources")
			state.built.append(id)
			state.actions -= 1
			_journal("built", {"facility":id})
			return _ok("built")
	return _no("unknown_action")

func _heal(c: Dictionary) -> Dictionary:
	if c.is_empty() or int(c.stats.hp) <= 0:
		return _no("invalid_character")
	if int(c.stats.hp) >= 100 and int(c.stats.infection) == 0:
		return _no("healthy")
	if not _pay({"medical":1}):
		return _no("not_enough_resources")
	_change(c, "hp", 28)
	_change(c, "infection", -20)
	return _ok("healed")

func _depart(location_id: String, cid: String) -> Dictionary:
	if int(state.actions) <= 0:
		return _no("no_actions")
	var c: Dictionary = character(cid)
	if c.is_empty() or int(c.stats.hp) <= 0:
		return _no("invalid_character")
	if int(c.stats.energy) < 15:
		return _no("exhausted")
	var location: Dictionary = {}
	for loc in data().locations:
		if loc.id == location_id:
			location = loc
	if location.is_empty():
		return _no("unknown_location")
	state.actions -= 1
	_change(c, "energy", -12)
	state.visits[location_id] = int(state.visits.get(location_id, 0)) + 1
	state.sorties += 1
	mission = {"location":location_id,"character":cid,"player":[2,8],"exit":[1,8],"walls":[],"rooms":[],"crates":[],"enemies":[],"cargo":{},"visible":[],"explored":[],"turn":0,"sneak":true,"noise":0,"last":"arrived","last_data":{}}
	var walls: Array = mission.walls
	for x in range(W):
		walls.append([x,0]); walls.append([x,H-1])
	for y in range(1,H-1):
		walls.append([0,y]); walls.append([W-1,y])
	var rooms: Array = [[4,2,6,5],[13,2,8,5],[5,10,6,4],[15,10,6,4]]
	for r in rooms:
		mission.rooms.append(r)
		for x in range(r[0],r[0]+r[2]):
			walls.append([x,r[1]]); walls.append([x,r[1]+r[3]-1])
		for y in range(r[1]+1,r[1]+r[3]-1):
			walls.append([r[0],y]); walls.append([r[0]+r[2]-1,y])
		# Entrances always join the clear central street.
		var door_y: int = r[1]+r[3]-1 if r[1] < 8 else r[1]
		walls.erase([r[0]+2,door_y])
	var positions: Array = [[3,8],[6,4],[8,4],[15,4],[18,4],[7,12],[17,12]]
	var loot_stream: StringName = StringName("poi_scene_" + location_id)
	for p in positions:
		var loot: Dictionary = session.rng.pick(loot_stream, location.loot).duplicate(true)
		# Repeated visits deplete supplies without making a location unusable.
		var scale: float = maxf(0.5, 1.0 - (int(state.visits[location_id])-1)*0.12)
		for k in loot:
			loot[k] = maxi(1,int(round(int(loot[k])*scale)))
		mission.crates.append({"pos":p,"searched":false,"loot":loot})
	var count: int = mini(9, 1 + int(location.risk) + int(session.clock.current_day)/6)
	for i in range(count):
		_spawn_enemy(loot_stream)
	state.mission = mission
	state.phase = "tactical"
	_update_sight()
	_journal("departed", {"location":location_id,"character":cid})
	return _ok()

func _spawn_enemy(stream: StringName) -> void:
	for attempt in range(80):
		var p: Array = [12 + int(session.rng.get_rng(stream)) % 11, 1 + int(session.rng.get_rng(stream)) % 14]
		if mission.walls.has(p) or p == mission.player or _enemy_at(p) >= 0:
			continue
		var on_crate: bool = false
		for crate in mission.crates:
			if crate.pos == p:
				on_crate = true
		if on_crate:
			continue
		mission.enemies.append({"pos":p,"hp":27,"alert":0,"target":p.duplicate()})
		return

func _tactical(command: Dictionary) -> Dictionary:
	var action: String = String(command.get("action", ""))
	var c: Dictionary = character(mission.character)
	var player: Vector2i = cell(mission.player)
	if action == "sneak":
		mission.sneak = not bool(mission.sneak)
		return _ok("sneak_on" if mission.sneak else "sneak_off")
	if action == "extract":
		if GridScript.chebyshev(player,cell(mission.exit)) > 1:
			return _no("return_to_exit")
		return _finish_mission("extracted")
	var noise: int = 0
	if action == "move":
		var target: Vector2i = cell(command.get("target", mission.player))
		if not mission.visible.has([target.x,target.y]):
			return _no("outside_sight")
		var blocked: Array = walls_as_cells()
		for enemy in mission.enemies:
			if int(enemy.hp) > 0:
				blocked.append(cell(enemy.pos))
		var path: Array = Paths.a_star(GridScript.new(W,H), player, target, blocked)
		if path.size() < 2:
			return _no("blocked")
		var next: Vector2i = path[1]
		mission.player = [next.x,next.y]
		mission.last = "moved"
		noise = 1 if mission.sneak else 4
	elif action == "search":
		var found: bool = false
		for crate in mission.crates:
			if not crate.searched and GridScript.chebyshev(player, cell(crate.pos)) <= 1 and Sight.can_see(GridScript.new(W,H), player, cell(crate.pos), walls_as_cells()):
				crate.searched = true
				for k in crate.loot:
					mission.cargo[k] = int(mission.cargo.get(k,0)) + int(crate.loot[k])
				mission.last = "found_loot"
				mission.last_data = crate.loot.duplicate(true)
				found = true
				break
		if not found:
			return _no("no_crate")
		noise = 3
	elif action == "attack" or action == "shoot":
		var target: Array = command.get("target", [])
		var index: int = _enemy_at(target)
		if index < 0 or not mission.visible.has(target):
			return _no("no_target")
		var distance: int = GridScript.chebyshev(player, cell(target))
		var max_range: int = 7 if action == "shoot" else 1
		if distance > max_range or not Sight.can_see(GridScript.new(W,H), player, cell(target),walls_as_cells()):
			return _no("out_of_range")
		if action == "shoot" and not _pay({"ammo":1}):
			return _no("no_ammo")
		var weapon: StringName = CombatScript.WEAPON_PISTOL_9MM if action == "shoot" else CombatScript.WEAPON_HATCHET
		var attack: Dictionary = CombatScript.resolve_attack({"skill_combat":int(c.get("starting_skills",{}).get("combat",1))+1,"stance":1 if mission.sneak else 0,"fatigue":100-int(c.stats.energy)}, {}, weapon, maxi(0,distance-1),0,false,false,session.rng)
		mission.enemies[index].hp = maxi(0, int(mission.enemies[index].hp)-int(attack.dmg))
		mission.last = "hit" if attack.hit else "miss"
		mission.last_data = {"damage":attack.dmg}
		if int(mission.enemies[index].hp) == 0:
			state.kills += 1
			mission.last = "killed"
		noise = 12 if action == "shoot" else 4
		if action == "shoot":
			session.base_state.city_pressure = mini(100, int(session.base_state.city_pressure)+1)
	elif action == "heal":
		var result: Dictionary = _heal(c)
		if not result.ok:
			return result
		mission.last = "healed"
	elif action == "wait":
		mission.last = "waited"
	else:
		return _no("unknown_action")
	mission.noise = noise
	mission.turn += 1
	if int(mission.turn) % 5 == 0:
		_change(c, "energy", -1)
	_enemy_turn(noise)
	if int(c.stats.hp) <= 0:
		return _finish_mission("fallen")
	if int(mission.turn) in [25,45,65]:
		_spawn_enemy(&"combat_reinforcements")
		mission.last = "reinforcements"
	if int(mission.turn) >= 80:
		for k in mission.cargo:
			mission.cargo[k] = int(mission.cargo[k])/2
		_change(c, "hp", -10)
		return _finish_mission("forced_retreat" if int(c.stats.hp)>0 else "fallen")
	_update_sight()
	return _ok()

func _enemy_turn(noise: int) -> void:
	var player: Vector2i = cell(mission.player)
	var c: Dictionary = character(mission.character)
	var blockers: Array = walls_as_cells()
	for enemy in mission.enemies:
		if int(enemy.hp) <= 0:
			continue
		var pos: Vector2i = cell(enemy.pos)
		var distance: int = GridScript.chebyshev(pos,player)
		var sees: bool = distance <= (3 if mission.sneak else 5) and Sight.can_see(GridScript.new(W,H),pos,player,blockers)
		if sees or distance <= noise:
			enemy.alert = 5
			enemy.target = mission.player.duplicate()
		if int(enemy.alert) <= 0:
			continue
		enemy.alert -= 1
		if distance <= 1 and Sight.can_see(GridScript.new(W,H),pos,player,blockers):
			var damage: int = 5 + int(session.rng.get_rng(&"combat_enemy")) % 6
			_change(c,"hp",-damage)
			_change(c,"infection",2)
			mission.last = "hurt"
			mission.last_data = {"damage":damage}
		else:
			var occupied: Array = blockers.duplicate()
			for other in mission.enemies:
				if int(other.hp)>0 and other != enemy:
					occupied.append(cell(other.pos))
			var path: Array = Paths.a_star(GridScript.new(W,H),pos,cell(enemy.target),occupied)
			if path.size()>1 and path[1] != player:
				var next: Vector2i = path[1]
				enemy.pos = [next.x,next.y]

func _finish_mission(outcome: String) -> Dictionary:
	var cargo: Dictionary = mission.cargo.duplicate(true) if outcome != "fallen" else {}
	_gain(cargo)
	for qty in cargo.values():
		state.total_loot += int(qty)
	state.summary = {"kind":"sortie", "outcome":outcome, "cargo":cargo,"character":mission.character,"turns":mission.turn}
	state.phase = "report"
	state.mission = {}
	session.base_state.population = alive().size()
	_journal(outcome,{"cargo":cargo,"character":mission.character})
	if alive().is_empty():
		_end("defeat")
	return _ok()

func _choose(index: int) -> Dictionary:
	var event: Dictionary = data().events[int(state.event_index)]
	if index < 0 or index >= event.options.size():
		return _no("invalid_option")
	var option: Dictionary = event.options[index]
	if not _pay(option.get("cost",{})):
		return _no("not_enough_resources")
	_gain(option.get("gain",{}))
	for c in alive():
		for stat in option.get("stats",{}):
			_change(c,stat,int(option.stats[stat]))
	state.signal = mini(100, int(state.signal)+int(option.get("signal",0)))
	_journal("event",{"title":event.title,"choice":option.label})
	_resolve_night()
	return _ok()

func _resolve_night() -> void:
	var produced: Dictionary = {}
	var consumed: Dictionary = {}
	var guards: int = 0
	var medic: bool = false
	for c in alive():
		var role: String = String(c.get("job","rest"))
		match role:
			"water": _add(produced,"water",7)
			"cook": _add(produced,"food",4)
			"engineering":
				_add(produced,"material",3)
				_add(produced,"parts",1)
			"medical": medic = true
			"guard": guards += 1
		_change(c,"energy",26 if role=="rest" else 12)
		if role == "rest":
			_change(c,"hp",6)
	if state.built.has("water"): _add(produced,"water",6)
	if state.built.has("garden"): _add(produced,"food",4)
	_gain(produced)
	var population: int = alive().size()
	var shortage: bool = false
	for key in ["food","water"]:
		var need: int = population*(2 if key=="food" else 3)
		var available: int = int(session.base_state.stockpile.get(key,0))
		consumed[key] = mini(need,available)
		session.base_state.stockpile[key] = maxi(0,available-need)
		if available < need: shortage = true
	var raid: int = 0
	if int(session.clock.current_day) >= 5 and session.rng.get_float(&"city_state",0.0,1.0) < float(session.base_state.city_pressure)/160.0:
		raid = maxi(0,14-guards*5-(10 if state.built.has("barrier") else 0))
		if raid > 0 and not alive().is_empty():
			_change(session.rng.pick(&"city_state",alive()),"hp",-raid)
	for c in alive():
		if shortage:
			_change(c,"hp",-16); _change(c,"morale",-8); _change(c,"energy",-14)
		else:
			_change(c,"hp",3); _change(c,"morale",1)
		if medic and int(session.base_state.stockpile.get("medical",0)) > 0:
			_change(c,"hp",7); _change(c,"infection",-5)
		elif int(c.stats.infection)>0:
			_change(c,"infection",3)
		if int(c.stats.infection)>=100:
			_change(c,"hp",-25)
	var completed_day: int = int(session.clock.current_day)
	session.clock.current_day += 1
	session.clock.city_minutes = 480
	session.base_state.city_pressure = mini(100,int(session.base_state.city_pressure)+2)
	session.base_state.population = alive().size()
	state.actions = 2
	state.summary = {"kind":"night","day":completed_day,"produced":produced,"consumed":consumed,"shortage":shortage,"raid":raid}
	state.phase = "report"
	_journal("night",state.summary.duplicate(true))
	if alive().is_empty(): _end("defeat")
	elif int(state.signal)>=100 and completed_day>=7: _end("rescue")
	elif completed_day>=30: _end("survival")

func _end(ending: String) -> void:
	state.phase = "ending"
	state.ending = ending
	_journal("ending",{"ending":ending})

func _update_sight() -> void:
	mission.visible = []
	for p in Sight.fov_from(GridScript.new(W,H),cell(mission.player),7,walls_as_cells()):
		var encoded: Array = [p.x,p.y]
		mission.visible.append(encoded)
		if not mission.explored.has(encoded): mission.explored.append(encoded)

func _enemy_at(pos: Array) -> int:
	for i in range(mission.get("enemies",[]).size()):
		if int(mission.enemies[i].hp)>0 and mission.enemies[i].pos==pos: return i
	return -1

func walls_as_cells() -> Array:
	var out: Array = []
	for p in mission.get("walls",[]): out.append(cell(p))
	return out

static func cell(p: Array) -> Vector2i:
	if p.size()<2: return Vector2i(-1,-1)
	return Vector2i(int(p[0]),int(p[1]))

func _pay(cost: Dictionary) -> bool:
	for k in cost:
		if int(session.base_state.stockpile.get(k,0)) < int(cost[k]): return false
	for k in cost:
		session.base_state.stockpile[k] = int(session.base_state.stockpile.get(k,0))-int(cost[k])
	return true

func _gain(gain: Dictionary) -> void:
	for k in gain:
		session.base_state.stockpile[k] = int(session.base_state.stockpile.get(k,0))+int(gain[k])

func _change(c: Dictionary, stat: String, delta: int) -> void:
	c.stats[stat] = clampi(int(c.stats.get(stat,0))+delta,0,100)

func _add(d: Dictionary, key: String, amount: int) -> void:
	d[key] = int(d.get(key,0))+amount

func _journal(code: String, values: Dictionary = {}) -> void:
	state.journal.append({"day":session.clock.current_day,"code":code,"data":values.duplicate(true)})
	if state.journal.size()>180: state.journal.pop_front()

func _ok(code: String = "") -> Dictionary:
	return {"ok":true,"code":code}

func _no(code: String) -> Dictionary:
	return {"ok":false,"code":code}


static func normalize_saved_state(value: Variant) -> Variant:
	# JSON decodes numbers as floats. Grid coordinates and counters are
	# integers, including nested arrays used as occupancy/FOV keys.
	if value is float:
		return int(value)
	if value is Array:
		var result: Array = []
		for child in value: result.append(normalize_saved_state(child))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = normalize_saved_state(value[key])
		return result
	return value
