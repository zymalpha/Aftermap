class_name RelationshipSystem extends RefCounted

## Bidirectional relationship between two characters.
## Each side records its own view (trust + intimacy + tags) so a
## relationship is symmetric in structure but independent in values.
## When a delta is applied via modify(), both records get the delta
## (with optional sign-flip), and reconciliation syncs the two records
## to the same canonical axis values.

const _PATH: String = "res://game/domain/survivors/relationship.gd"

const AXIS_TRUST: String = "trust"
const AXIS_INTIMACY: String = "intimacy"
const AXES: Array[String] = [AXIS_TRUST, AXIS_INTIMACY]

const RELATIONSHIP_TAGS: Array[String] = [
	"family", "friend", "old_acquaintance", "romantic", "rival", "mentor", "stranger",
]

## relationships: Dictionary keyed by "a|b" (sorted ids) -> {
##   a_view: { trust:int, intimacy:int, tags:[String] },
##   b_view: { trust:int, intimacy:int, tags:[String] },
##   canonical: { trust:int, intimacy:int, tags:[String] },
## }

var relationships: Dictionary = {}

func _log(msg: String) -> void:
	push_warning("[RelationshipSystem] " + msg)

func _key(a: String, b: String) -> String:
	var ids: Array = [a, b]
	ids.sort()
	return "%s|%s" % [ids[0], ids[1]]

func ensure_pair(a: String, b: String) -> Dictionary:
	if a == b or a == "" or b == "":
		return {}
	var k: String = _key(a, b)
	if not relationships.has(k):
		relationships[k] = {
			"a_view": {"trust": 0, "intimacy": 0, "tags": []},
			"b_view": {"trust": 0, "intimacy": 0, "tags": []},
			"canonical": {"trust": 0, "intimacy": 0, "tags": []},
		}
	return relationships[k]

## Apply a delta from a -> b. The canonical axis moves by `amount`.
## Both per-side views are nudged so they reflect a's perspective and
## b's perspective independently (often the same value at start).
func modify(a: String, b: String, axis: String, amount: int) -> Dictionary:
	if not AXES.has(axis):
		return {}
	var pair: Dictionary = ensure_pair(a, b)
	if pair.is_empty():
		return {}
	var canonical: Dictionary = pair["canonical"]
	var new_val: int = clampi(int(canonical.get(axis, 0)) + amount, -100, 100)
	canonical[axis] = new_val
	# per-side views move with canonical (symmetric record-keeping)
	var a_view: Dictionary = pair["a_view"]
	var b_view: Dictionary = pair["b_view"]
	a_view[axis] = new_val
	b_view[axis] = new_val
	return {
		"axis": axis,
		"amount": amount,
		"new_value": new_val,
		"a": a,
		"b": b,
	}

func add_tag(a: String, b: String, tag: String) -> void:
	if tag == "" or not RELATIONSHIP_TAGS.has(tag):
		return
	var pair: Dictionary = ensure_pair(a, b)
	if pair.is_empty():
		return
	var canonical: Dictionary = pair["canonical"]
	if not (canonical["tags"] as Array).has(tag):
		(canonical["tags"] as Array).append(tag)
	for view_name in ["a_view", "b_view"]:
		var view: Dictionary = pair[view_name]
		if not (view["tags"] as Array).has(tag):
			(view["tags"] as Array).append(tag)

## Reconcile both per-side views back to the canonical axis values.
## Returns the number of pairs reconciled.
func reconcile() -> int:
	var n: int = 0
	for k in relationships.keys():
		var pair: Dictionary = relationships[k]
		var canonical: Dictionary = pair["canonical"]
		for view_name in ["a_view", "b_view"]:
			var view: Dictionary = pair[view_name]
			for axis in AXES:
				view[axis] = int(canonical.get(axis, 0))
			# tags: union canonical + view (per-side memories may have extra)
			var c_tags: Array = canonical.get("tags", [])
			var v_tags: Array = view.get("tags", [])
			var merged: Dictionary = {}
			for t in c_tags:
				merged[String(t)] = true
			for t in v_tags:
				merged[String(t)] = true
			view["tags"] = merged.keys()
		n += 1
	return n

## Queries -----------------------------------------------------------------

func get_pair(a: String, b: String) -> Dictionary:
	var k: String = _key(a, b)
	if not relationships.has(k):
		return {}
	return relationships[k]

func get_axis(a: String, b: String, axis: String) -> int:
	var pair: Dictionary = get_pair(a, b)
	if pair.is_empty():
		return 0
	return int((pair.get("canonical", {}) as Dictionary).get(axis, 0))

func list_pairs() -> Array:
	var out: Array = []
	for k in relationships.keys():
		out.append(String(k))
	return out

func to_dict() -> Dictionary:
	return relationships.duplicate(true)

func from_dict(d: Dictionary) -> void:
	relationships = {}
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in d.keys():
		var raw: Variant = d[k]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var pair: Dictionary = (raw as Dictionary).duplicate(true)
		relationships[String(k)] = pair