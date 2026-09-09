extends SceneTree

const SessionScript: GDScript = preload("res://game/core/game_session.gd")
const Rules: GDScript = preload("res://game/domain/campaign/campaign_actions.gd")
const Save: GDScript = preload("res://game/adapters/saves/save_v1.gd")
const App: GDScript = preload("res://game/application/app.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_expedition_and_rejections()
	_test_save_roundtrip()
	_test_night_and_endings()
	_test_map_connectivity()
	print("PLAYABLE_CAMPAIGN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func fresh(seed_value: int = 42) -> RefCounted:
	var session: RefCounted = SessionScript.new()
	expect(session.new_game(seed_value).is_ok(),"content loads")
	for cid in App.DEFAULT_CHARACTER_IDS:
		var c: Dictionary = session.content.get_record("characters",cid).duplicate(true)
		c.stats = {"hp":100,"energy":80,"infection":0,"morale":60,"hunger":50,"stress":0}
		session.issue_command({"kind":"add_character","character":c})
	session.issue_command({"kind":"set_base_field","key":"stockpile","value":{"food":28,"water":36,"material":16,"parts":8,"medical":6,"fuel":4,"ammo":12}})
	act(session,"initialize")
	return session

func act(session: RefCounted, action: String, values: Dictionary = {}) -> RefCounted:
	var cmd: Dictionary = values.duplicate(true)
	cmd.kind = "campaign_action"
	cmd.action = action
	return session.issue_command(cmd)

func _test_expedition_and_rejections() -> void:
	var s: RefCounted = fresh()
	var original: String = JSON.stringify(s.to_dict())
	expect(not act(s,"depart",{"location":"bogus","character":"chr_scout_wang"}).is_ok(),"reject invalid destination")
	expect(JSON.stringify(s.to_dict())==original,"rejected action rolls back state and RNG")
	expect(act(s,"depart",{"location":"grocery","character":"chr_scout_wang"}).is_ok(),"depart")
	expect(s.base_state.campaign.phase=="tactical","enters tactical state")
	expect(int(s.base_state.campaign.actions)==1,"one action consumed")
	var stock: Dictionary = s.base_state.stockpile.duplicate(true)
	expect(act(s,"search").is_ok(),"search adjacent starting crate")
	expect(not s.base_state.campaign.mission.cargo.is_empty(),"cargo gained")
	expect(s.base_state.stockpile==stock,"cargo not credited before extraction")
	var turn: int = int(s.base_state.campaign.mission.turn)
	expect(not act(s,"search").is_ok(),"cannot loot same crate twice")
	expect(int(s.base_state.campaign.mission.turn)==turn,"invalid actions do not spend turns")
	expect(act(s,"move",{"target":[3,8]}).is_ok(),"move to visible street")
	expect(not act(s,"extract").is_ok(),"cannot extract remotely")
	expect(act(s,"move",{"target":[2,8]}).is_ok(),"return to exit")
	var cargo: Dictionary = s.base_state.campaign.mission.cargo.duplicate(true)
	expect(act(s,"extract").is_ok(),"extract")
	for key in cargo:
		expect(int(s.base_state.stockpile[key])==int(stock.get(key,0))+int(cargo[key]),"loot credited exactly once")
	expect(not act(s,"extract").is_ok(),"cannot extract twice")
	expect(act(s,"acknowledge").is_ok(),"return from report")
	expect(act(s,"build",{"facility":"water"}).is_ok(),"build purifier")
	expect(int(s.base_state.campaign.actions)==0,"construction consumes action")
	expect(not act(s,"depart",{"location":"park","character":"chr_scout_wang"}).is_ok(),"no unlimited sorties")
	expect(not act(s,"assign",{"character":"chr_scout_wang","role":"fake"}).is_ok(),"invalid job rejected")

func _test_save_roundtrip() -> void:
	var s: RefCounted = fresh(98124)
	act(s,"depart",{"location":"school","character":"chr_scout_wang"})
	act(s,"search")
	var path: String = "user://test_playable_roundtrip.dat"
	expect(Save.save(s,path)==OK,"save mid-expedition")
	var loaded: RefCounted = Save.load(path)
	expect(loaded!=null,"load saved expedition")
	if loaded==null: return
	expect(loaded.content.list_ids("events").size()>0,"content records reload with save")
	expect(JSON.stringify(loaded.base_state.campaign)==JSON.stringify(s.base_state.campaign),"mission positions, cargo, fog and phase preserved")
	for i in range(12):
		expect(loaded.rng.get_rng(&"combat_enemy")==s.rng.get_rng(&"combat_enemy"),"RNG bit-exact across JSON save")
	# Force a second valid generation, then corrupt primary to test fallback.
	expect(Save.save(loaded,path)==OK,"rotate previous save to backup")
	var f: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	f.store_string("corrupt")
	f.close()
	var recovered: RefCounted = Save.load(path)
	expect(recovered!=null,"backup recovery is reachable when primary hash fails")
	if recovered!=null: expect(recovered.base_state.campaign.phase=="tactical","backup preserves mission phase")
	for suffix in ["",".meta",".bak",".bak.meta",".tmp"]: DirAccess.remove_absolute(path+suffix)

func _test_night_and_endings() -> void:
	var s: RefCounted = fresh()
	act(s,"build",{"facility":"water"})
	act(s,"build",{"facility":"garden"})
	for day in range(1,31):
		expect(act(s,"end_day").is_ok(),"enter nightly choice")
		expect(s.base_state.campaign.phase=="event","night waits for player choice")
		expect(act(s,"choose",{"index":1}).is_ok(),"resolve free event option")
		expect(int(s.clock.current_day)==day+1,"day advances exactly once")
		for value in s.base_state.stockpile.values(): expect(int(value)>=0,"stock never negative")
		if day<30: expect(act(s,"acknowledge").is_ok(),"new day report can be closed")
	expect(s.base_state.campaign.ending=="survival","30-day run reaches survival ending")
	var before: String = JSON.stringify(s.to_dict())
	expect(not act(s,"end_day").is_ok(),"ending freezes campaign")
	expect(JSON.stringify(s.to_dict())==before,"ending cannot pay costs or mutate state")
	var rescue: RefCounted = fresh(55)
	act(rescue,"build",{"facility":"water"})
	act(rescue,"build",{"facility":"garden"})
	var cs: Dictionary = rescue.base_state.campaign.duplicate(true)
	cs.signal = 100
	rescue.issue_command({"kind":"set_base_field","key":"campaign","value":cs})
	for day in range(1,8):
		act(rescue,"end_day"); act(rescue,"choose",{"index":1})
		if day<7:
			expect(rescue.base_state.campaign.phase!="ending","rescue cannot arrive before day seven")
			act(rescue,"acknowledge")
	expect(rescue.base_state.campaign.ending=="rescue","complete signal plus day seven reaches rescue")
	var dying: RefCounted = fresh()
	for c in dying.characters:
		dying.issue_command({"kind":"stat_add","target":c.id,"stat":"hp","amount":-95})
		act(dying,"assign",{"character":c.id,"role":"guard"})
	dying.issue_command({"kind":"set_base_field","key":"stockpile","value":{}})
	act(dying,"end_day"); act(dying,"choose",{"index":1})
	expect(dying.base_state.campaign.ending=="defeat","starvation can defeat campaign")

func _test_map_connectivity() -> void:
	var Paths: GDScript = preload("res://game/domain/tactical/pathfinder.gd")
	var GridScript: GDScript = preload("res://game/domain/tactical/grid.gd")
	for location in Rules.data().locations:
		var s: RefCounted = fresh(732)
		act(s,"depart",{"location":location.id,"character":"chr_scout_wang"})
		var m: Dictionary = s.base_state.campaign.mission
		var walls: Array = []
		for p in m.walls: walls.append(Rules.cell(p))
		for crate in m.crates:
			var path: Array = Paths.a_star(GridScript.new(Rules.W,Rules.H),Rules.cell(m.player),Rules.cell(crate.pos),walls)
			expect(not path.is_empty(),"all loot containers reachable in "+location.id)
		var seen: Array = []
		for enemy in m.enemies:
			expect(not m.walls.has(enemy.pos) and not seen.has(enemy.pos),"enemies never overlap walls/each other")
			seen.append(enemy.pos)
