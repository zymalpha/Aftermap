extends SceneTree

## Stage 17 localization smoke test.
##
## Loads zh_CN.po + en_US.po, asserts 50+ keys translate as expected,
## exercises fallback behavior, lang switching, and malformed .po recovery.

const LocalizerScript: GDScript = preload("res://game/adapters/localization/localizer.gd")
const ZH_PO: String = "res://game/adapters/localization/zh_CN.po"
const EN_PO: String = "res://game/adapters/localization/en_US.po"

var _pass_count: int = 0
var _fail_count: int = 0

func _initialize() -> void:
	print("=== Stage 17 localization test start ===")
	_test_load_zh()
	_test_load_en()
	_test_basic_translation_zh()
	_test_basic_translation_en()
	_test_lang_switch()
	_test_fallback_when_missing_in_active()
	_test_explicit_fallback_argument()
	_test_50_key_coverage()
	_test_corrupt_po_does_not_crash()
	_test_empty_key_returns_fallback()
	_test_unicode_preserved()
	print("=== Stage 17 localization test result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _make_loc() -> RefCounted:
	var l: RefCounted = LocalizerScript.new()
	l.set_default_lang(&"zh_CN")
	return l

# --------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------- #

func _test_load_zh() -> void:
	print("[1] Load zh_CN.po")
	var l: RefCounted = _make_loc()
	var err: int = l.load_from_po(ZH_PO, &"zh_CN")
	_expect(err == OK, "load_from_po returns OK (err=" + str(err) + ")")
	_expect(l.get_load_errors() == 0, "no parse errors during zh load (errors=" + str(l.get_load_errors()) + ")")
	_expect(l.size() >= 100, ">=100 zh entries loaded (size=" + str(l.size()) + ")")
	_expect(String(l.get_lang()) == "zh_CN", "active lang = zh_CN")

func _test_load_en() -> void:
	print("[2] Load en_US.po")
	var l: RefCounted = _make_loc()
	var err: int = l.load_from_po(EN_PO, &"en_US")
	_expect(err == OK, "load_from_po returns OK (err=" + str(err) + ")")
	_expect(l.get_load_errors() == 0, "no parse errors during en load (errors=" + str(l.get_load_errors()) + ")")
	_expect(l.size() >= 100, ">=100 en entries loaded (size=" + str(l.size()) + ")")

func _test_basic_translation_zh() -> void:
	print("[3] Basic zh translation")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	l.load_from_po(EN_PO, &"en_US")
	_expect(l.lookup(&"ui.menu.title", "Aftermap") == "末日坐标：Aftermap", "zh ui.menu.title")
	_expect(l.lookup(&"ui.menu.start", "Aftermap") == "开始战役", "zh ui.menu.start")
	_expect(l.lookup(&"ui.hud.food", "Aftermap") == "食物", "zh ui.hud.food")
	_expect(l.lookup(&"content.item.itm_bandage", "Bandage") == "绷带", "zh content.item.itm_bandage")
	_expect(l.lookup(&"content.facility.fac_barrier_basic", "Aftermap") == "防御围栏", "zh fac_barrier_basic")

func _test_basic_translation_en() -> void:
	print("[4] Basic en translation")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	l.load_from_po(EN_PO, &"en_US")
	l.set_lang(&"en_US")
	_expect(l.lookup(&"ui.menu.title", "Aftermap") == "Aftermap", "en ui.menu.title")
	_expect(l.lookup(&"ui.menu.start", "Aftermap") == "Start Campaign", "en ui.menu.start")
	_expect(l.lookup(&"ui.hud.food", "Aftermap") == "Food", "en ui.hud.food")
	_expect(l.lookup(&"content.item.itm_bandage", "Bandage") == "Bandage", "en itm_bandage")
	_expect(l.lookup(&"content.facility.fac_barrier_basic", "Aftermap") == "Barrier", "en fac_barrier_basic")

func _test_lang_switch() -> void:
	print("[5] Lang switch round-trip")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	l.load_from_po(EN_PO, &"en_US")
	l.set_lang(&"zh_CN")
	var zh_value: String = l.lookup(&"ui.menu.title", "Aftermap")
	_expect(zh_value == "末日坐标：Aftermap", "before switch zh title")
	l.set_lang(&"en_US")
	var en_value: String = l.lookup(&"ui.menu.title", "Aftermap")
	_expect(en_value == "Aftermap", "after switch en title")
	l.set_lang(&"zh_CN")
	_expect(l.lookup(&"ui.menu.title", "Aftermap") == zh_value, "switch back zh title")
	_expect(String(l.get_lang()) == "zh_CN", "get_lang returns zh_CN")

func _test_fallback_when_missing_in_active() -> void:
	print("[6] Fallback to default lang when active lacks key")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	# Load only zh_CN, then ask for en_US -> should fall back to zh_CN default.
	l.load_from_po(EN_PO, &"en_US")
	# Simulate: clear en_US bucket to force fallback.
	l._dict["en_US"] = {}
	l.set_lang(&"en_US")
	var v: String = l.lookup(&"ui.menu.title", "Aftermap")
	_expect(v == "末日坐标：Aftermap", "missing in en falls back to zh_CN (got '" + v + "')")

func _test_explicit_fallback_argument() -> void:
	print("[7] Explicit fallback argument")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	l.load_from_po(EN_PO, &"en_US")
	# Completely unknown key => should return the fallback string we pass.
	var v: String = l.lookup(&"definitely.not.a.real.key", "DEFAULT_FALLBACK")
	_expect(v == "DEFAULT_FALLBACK", "unknown key returns explicit fallback")
	# Empty key also returns fallback.
	var v2: String = l.lookup(&"", "ANOTHER_FALLBACK")
	_expect(v2 == "ANOTHER_FALLBACK", "empty key returns explicit fallback")
	# When fallback is empty AND key is unknown -> returns the key itself.
	var v3: String = l.lookup(&"definitely.not.a.real.key", "")
	_expect(v3 == "definitely.not.a.real.key", "unknown key with empty fallback returns key")

func _test_50_key_coverage() -> void:
	print("[8] 50+ key coverage (zh + en match)")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	l.load_from_po(EN_PO, &"en_US")
	var keys: Array[StringName] = [
		&"ui.menu.title", &"ui.menu.start", &"ui.menu.continue",
		&"ui.menu.load", &"ui.menu.save", &"ui.menu.settings",
		&"ui.menu.quit", &"ui.menu.new_game", &"ui.menu.language",
		&"ui.menu.credits", &"ui.menu.back", &"ui.menu.confirm_quit",
		&"ui.hud.resources", &"ui.hud.food", &"ui.hud.water",
		&"ui.hud.medicine", &"ui.hud.materials", &"ui.hud.fuel",
		&"ui.hud.ammo", &"ui.hud.parts", &"ui.hud.morale",
		&"ui.hud.defense", &"ui.hud.power", &"ui.hud.day",
		&"ui.hud.time", &"ui.hud.pause", &"ui.hud.resume",
		&"ui.hud.status", &"ui.hud.members",
		&"ui.morning.report", &"ui.morning.summary", &"ui.morning.resources_change",
		&"ui.morning.events", &"ui.morning.injuries", &"ui.morning.weather",
		&"ui.morning.weather.clear", &"ui.morning.weather.rain", &"ui.morning.weather.storm",
		&"ui.morning.weather.fog", &"ui.morning.actions", &"ui.morning.confirm",
		&"ui.event.decision", &"ui.event.option.stay", &"ui.event.option.scavenge",
		&"ui.event.option.trade", &"ui.event.option.fight", &"ui.event.option.flee",
		&"ui.event.option.help", &"ui.event.option.ignore", &"ui.event.option.investigate",
		&"ui.event.option.wait", &"ui.event.outcome",
		&"ui.facility.build", &"ui.facility.upgrade", &"ui.facility.repair",
		&"ui.facility.power_on", &"ui.facility.power_off", &"ui.facility.upkeep",
	]
	var matched: int = 0
	for k in keys:
		l.set_lang(&"zh_CN")
		var zh_v: String = l.lookup(k, "")
		l.set_lang(&"en_US")
		var en_v: String = l.lookup(k, "")
		if not zh_v.is_empty() and not en_v.is_empty() and zh_v != en_v:
			matched += 1
	_expect(matched >= 50, "at least 50 keys translate in both zh and en (matched=" + str(matched) + "/" + str(keys.size()) + ")")
	_expect(l.size() >= 100, "Localizer.size() >= 100 across both langs")

func _test_corrupt_po_does_not_crash() -> void:
	print("[9] Corrupt .po does not crash")
	var l: RefCounted = _make_loc()
	# Write a deliberately malformed .po to user://.
	var tmp_path: String = "user://_stage17_corrupt.po"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f != null:
		f.store_string("garbage no header line\n")
		f.store_string("random garbage\n")
		f.close()
	var err: int = l.load_from_po(tmp_path, &"test")
	_expect(err == OK, "load_from_po on garbage returns OK (err=" + str(err) + ")")
	_expect(l.get_load_errors() >= 1, "garbage lines counted as parse errors (errors=" + str(l.get_load_errors()) + ")")
	# Missing file path
	var err2: int = l.load_from_po("user://_definitely_does_not_exist.po", &"missing")
	_expect(err2 == ERR_FILE_NOT_FOUND, "missing file returns ERR_FILE_NOT_FOUND (err=" + str(err2) + ")")
	_expect(l.get_load_errors() >= 1, "missing file counted as parse error")

	# Mixed valid + invalid entry
	var tmp_path2: String = "user://_stage17_mixed.po"
	var f2: FileAccess = FileAccess.open(tmp_path2, FileAccess.WRITE)
	if f2 != null:
		f2.store_string("msgid \"good.key\"\n")
		f2.store_string("msgstr \"good value\"\n")
		f2.store_string("\n")
		f2.store_string("this is junk between entries\n")
		f2.store_string("msgid \"another.key\"\n")
		f2.store_string("msgstr \"another value\"\n")
		f2.close()
	var l2: RefCounted = _make_loc()
	l2.load_from_po(tmp_path2, &"test")
	_expect(l2.lookup(&"good.key", "FB") == "good value", "good entry parsed (got '" + l2.lookup(&"good.key", "FB") + "')")
	_expect(l2.lookup(&"another.key", "FB") == "another value", "another entry parsed (got '" + l2.lookup(&"another.key", "FB") + "')")
	_expect(l2.get_load_errors() >= 1, "junk line counted as parse error")

func _test_empty_key_returns_fallback() -> void:
	print("[10] Empty key returns fallback")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	_expect(l.lookup(&"", "EMPTY_FB") == "EMPTY_FB", "empty key returns fallback")
	_expect(l.lookup(&"", "") == "", "empty key + empty fallback returns empty")

func _test_unicode_preserved() -> void:
	print("[11] UTF-8 unicode preserved end-to-end")
	var l: RefCounted = _make_loc()
	l.load_from_po(ZH_PO, &"zh_CN")
	var title: String = l.lookup(&"ui.menu.title", "")
	_expect(title == "末日坐标：Aftermap", "title has Chinese chars (got '" + title + "')")
	var tutorials: Array[StringName] = [
		&"ui.tutorial.welcome", &"ui.tutorial.resources",
		&"ui.tutorial.facility", &"ui.tutorial.events",
		&"ui.tutorial.scavenge", &"ui.tutorial.members",
		&"ui.tutorial.save", &"ui.tutorial.endings",
	]
	var ok: bool = true
	for t in tutorials:
		var v: String = l.lookup(t, "")
		if v.is_empty() or v == String(t):
			ok = false
			break
	_expect(ok, "all 8 tutorial entries resolve to non-empty Chinese strings")