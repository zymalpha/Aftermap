extends RefCounted
class_name Localizer

## Stage 17 minimal PO-file localizer.
##
## Loads standard `.po` files into a nested Dictionary keyed by language then
## message-id, and resolves `tr()` calls against the currently active language
## with safe fallback to a default language when a key is missing.
##
## Implementation notes:
## - No third-party gettext/ICU dependency. The `.po` parser is hand-rolled and
##   tolerates blank lines, `msgid ""` empty ids, comment lines starting with
##   `#`, multi-line quoted strings concatenated by the parser, and unknown
##   header lines that are silently skipped.
## - When a key is missing in the active language we try `default_lang` first,
##   then the explicit fallback argument, then return the key itself so the
##   caller always receives a non-empty String.

const DEFAULT_LANG: StringName = &"zh_CN"

var _dict: Dictionary = {}             ## { lang: { msgid: msgstr } }
var _current_lang: StringName = DEFAULT_LANG
var _default_lang: StringName = DEFAULT_LANG
var _load_errors: int = 0               ## count of recoverable parse errors during last load

func set_default_lang(lang: StringName) -> void:
	if String(lang).is_empty():
		return
	_default_lang = lang

func get_default_lang() -> StringName:
	return _default_lang

func set_lang(lang: StringName) -> void:
	_current_lang = lang

func get_lang() -> StringName:
	return _current_lang

func available_langs() -> Array:
	return _dict.keys()

## Returns the number of (lang, key) entries currently loaded.
func size() -> int:
	var total: int = 0
	for lang in _dict.keys():
		var inner: Variant = _dict.get(lang, {})
		if typeof(inner) == TYPE_DICTIONARY:
			total += (inner as Dictionary).size()
	return total

## Count of recoverable parse errors from the most recent `load_from_po()` call.
func get_load_errors() -> int:
	return _load_errors

## Load (or replace) translations for a single language from a `.po` file.
## Returns OK on success (including "file not found" which is reported as a
## load error but does not crash), ERR_PARSE_ERROR on unrecoverable I/O issue.
func load_from_po(path: String, lang: StringName) -> int:
	_load_errors = 0
	if not FileAccess.file_exists(path):
		_load_errors += 1
		printerr("[Localizer] .po not found: ", path)
		return ERR_FILE_NOT_FOUND
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_load_errors += 1
		printerr("[Localizer] cannot open .po: ", path, " err=", FileAccess.get_open_error())
		return ERR_CANT_OPEN
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Dictionary = _parse_po_text(raw)
	var lang_dict: Dictionary = {}
	for key in parsed.keys():
		lang_dict[key] = parsed[key]
	_dict[String(lang)] = lang_dict
	# Ensure active and default languages have at least an empty bucket so
	# subsequent tr() calls don't crash.
	if not _dict.has(String(_current_lang)):
		_dict[String(_current_lang)] = {}
	if not _dict.has(String(_default_lang)):
		_dict[String(_default_lang)] = {}
	return OK

## Translate `key`. Lookup order: active language -> default language ->
## explicit fallback -> key itself (so caller always gets a non-empty String).
func tr(key: StringName, fallback: String = "") -> String:
	var sk: String = String(key)
	if sk.is_empty():
		return fallback
	var active: Variant = _dict.get(String(_current_lang), null)
	if typeof(active) == TYPE_DICTIONARY and (active as Dictionary).has(sk):
		return String((active as Dictionary)[sk])
	var default: Variant = _dict.get(String(_default_lang), null)
	if typeof(default) == TYPE_DICTIONARY and (default as Dictionary).has(sk):
		return String((default as Dictionary)[sk])
	if not fallback.is_empty():
		return fallback
	return sk

## Returns true if the active language (or fallback) has an entry for `key`.
func has(key: StringName) -> bool:
	var sk: String = String(key)
	var active: Variant = _dict.get(String(_current_lang), null)
	if typeof(active) == TYPE_DICTIONARY and (active as Dictionary).has(sk):
		return true
	var default: Variant = _dict.get(String(_default_lang), null)
	if typeof(default) == TYPE_DICTIONARY and (default as Dictionary).has(sk):
		return true
	return false

# --------------------------------------------------------------------- #
# .po parser
# --------------------------------------------------------------------- #

func _parse_po_text(raw: String) -> Dictionary:
	var result: Dictionary = {}
	var cur_id: String = ""
	var cur_str: String = ""
	var in_msgstr: bool = false
	var msgid_present: bool = false
	var msgstr_present: bool = false

	var lines: PackedStringArray = raw.split("\n", false)
	for line_raw in lines:
		var line: String = line_raw.strip_edges()
		if line.is_empty():
			# blank line terminates current entry
			if msgid_present and msgstr_present and not cur_id.is_empty():
				result[cur_id] = cur_str
			cur_id = ""
			cur_str = ""
			in_msgstr = false
			msgid_present = false
			msgstr_present = false
			continue
		if line.begins_with("#"):
			# comment / reference line — ignored
			continue
		if line.begins_with("msgid "):
			# Flush any prior entry on encountering a new msgid.
			if msgid_present and msgstr_present and not cur_id.is_empty():
				result[cur_id] = cur_str
			cur_id = ""
			cur_str = ""
			in_msgstr = false
			msgid_present = true
			msgstr_present = false
			var rest: String = line.substr(5).strip_edges()
			cur_id = _decode_quoted(rest)
			continue
		if line.begins_with("msgstr "):
			in_msgstr = true
			msgstr_present = true
			var rest2: String = line.substr(6).strip_edges()
			cur_str = _decode_quoted(rest2)
			continue
		if line.begins_with("\""):
			# continuation line for msgid or msgstr
			var cont: String = _decode_quoted(line)
			if in_msgstr:
				cur_str += cont
			else:
				cur_id += cont
			continue
		# Unknown header (e.g. "msgctxt", "msgid_plural", deprecated headers,
		# or genuinely malformed input). We treat unknown lines as a
		# recoverable parse error and skip them — but flush any half-built
		# entry first so we never half-poison the next one.
		_load_errors += 1
		if msgid_present and msgstr_present and not cur_id.is_empty():
			result[cur_id] = cur_str
		cur_id = ""
		cur_str = ""
		in_msgstr = false
		msgid_present = false
		msgstr_present = false

	# Trailing entry without trailing newline.
	if msgid_present and msgstr_present and not cur_id.is_empty():
		result[cur_id] = cur_str
	return result

## Parse `"foo"` / `"foo" "bar"` style C-escape quoted strings.
## Supports standard PO escapes: \n \r \t \" \\ .
func _decode_quoted(s: String) -> String:
	var t: String = s.strip_edges()
	if t.length() < 2:
		return ""
	if t[0] != "\"":
		return ""
	if t[t.length() - 1] != "\"":
		# tolerate but record error
		_load_errors += 1
		var last_quote: int = t.rfind("\"")
		if last_quote <= 0:
			return ""
		t = t.substr(0, last_quote + 1)
	var inner: String = t.substr(1, t.length() - 2)
	var out: PackedByteArray = PackedByteArray()
	var i: int = 0
	var n: int = inner.length()
	while i < n:
		var ch: String = inner.substr(i, 1)
		if ch == "\\" and i + 1 < n:
			var nx: String = inner.substr(i + 1, 1)
			match nx:
				"n":
					out.append(10)
				"r":
					out.append(13)
				"t":
					out.append(9)
				"\"":
					out.append(34)
				"\\":
					out.append(92)
				"0":
					out.append(0)
				_:
					# unknown escape — pass through the escaped char as literal.
					out.append(nx.unicode_at(0))
			i += 2
		else:
			out.append(ch.unicode_at(0))
			i += 1
	return out.get_string_from_utf8()