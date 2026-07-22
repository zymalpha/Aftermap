class_name SaveV1 extends RefCounted

## Save format v1 (ADR-0004). JSON envelope with magic, schema version,
## content fingerprint, RNG state, clock state, content meta, and the
## full session payload. SHA-256 is computed over the canonical JSON
## and stored in the sidecar .meta (via AtomicWrite).

const _PATH: String = "res://game/adapters/saves/save_v1.gd"

const MAGIC: String = "AFTMAPv1"
const SCHEMA_VERSION: int = 1

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")

static func save(session: GameSession, path: String) -> Error:
	if session == null:
		return ERR_INVALID_PARAMETER

	var envelope: Dictionary = {
		"magic": MAGIC,
		"schema_version": SCHEMA_VERSION,
		"created_at": Time.get_datetime_string_from_system(true),
		"content_fingerprint": session.content.get_fingerprint(),
		"rng_state": session.rng.to_dict(),
		"clock_state": session.clock.to_dict(),
		"content_db_meta": session.content.to_dict(),
		"session_payload": session.to_dict(),
	}

	var text: String = JSON.stringify(envelope, "\t")
	var bytes: PackedByteArray = text.to_utf8_buffer()
	return AtomicWrite.write_atomic(path, bytes)

## Load and verify; returns a new GameSession or null on hard failure.
static func load(path: String) -> GameSession:
	if not AtomicWrite.verify(path):
		push_warning("[SaveV1] verification failed: " + path)
		return null

	var raw: PackedByteArray = AtomicWrite.load_or_recover(path)
	if raw.is_empty():
		return null

	var text: String = raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveV1] not a dict: " + path)
		return null

	var envelope: Dictionary = parsed
	if String(envelope.get("magic", "")) != MAGIC:
		push_warning("[SaveV1] bad magic: " + path)
		return null

	var ver: int = int(envelope.get("schema_version", 0))
	if ver != SCHEMA_VERSION:
		push_warning("[SaveV1] unsupported schema_version=" + str(ver))
		return null

	var session: GameSession = GameSessionScript.new()
	var payload: Variant = envelope.get("session_payload", {})
	if typeof(payload) == TYPE_DICTIONARY:
		session.from_dict(payload)
	return session

## Convenience for tests / inspectors.
static func inspect_header(path: String) -> Dictionary:
	var raw: PackedByteArray = AtomicWrite.load_or_recover(path)
	if raw.is_empty():
		return {}
	var text: String = raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).duplicate(true)