class_name AtomicWrite extends RefCounted

## Static helpers implementing the 6-step atomic write protocol from ADR-0004:
##   1. Write to .tmp
##   2. Flush + fsync
##   3. Keep previous as .bak
##   4. Atomically rename .tmp -> live
##   5. Update header (caller's responsibility)
##   6. On failure: leave last good in place.

const _PATH: String = "res://game/adapters/saves/atomic_write.gd"

## Write `bytes` to `path` atomically. On success, the .bak file at
## `path.bak` (if it existed) is preserved; a previous `path` is copied
## to `path.bak` (along with its own `.bak.meta` sidecar) before rename.
## Returns OK on success; non-OK on any IO failure.
static func write_atomic(path: String, bytes: PackedByteArray) -> Error:
	var tmp_path: String = path + ".tmp"
	var meta_path: String = path + ".meta"
	var bak_path: String = path + ".bak"
	var bak_meta_path: String = path + ".bak.meta"

	# Step 1: open .tmp for write; truncate if exists.
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(bytes)
	# Step 2: flush (Godot has no fsync; close() flushes user-space buffers).
	f.close()

	# Step 3 (BEFORE writing new meta): keep previous as .bak.
	# Critical ordering: copy the old live+meta into .bak/.bak.meta BEFORE
	# we overwrite .meta with the new sha256. Otherwise subsequent rotations
	# would leave .bak.meta pointing at the new bytes and .bak's self-check
	# would always fail.
	if FileAccess.file_exists(path):
		var copy_err: Error = _copy_file(path, bak_path)
		if copy_err != OK:
			return copy_err
	if FileAccess.file_exists(meta_path):
		var mcopy_err: Error = _copy_file(meta_path, bak_meta_path)
		if mcopy_err != OK:
			return mcopy_err

	# Step 4: sidecar meta holds the sha256 of the freshly written bytes.
	var digest: String = sha256_of_bytes(bytes)
	var mf: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if mf == null:
		return FileAccess.get_open_error()
	mf.store_string(digest)
	mf.close()

	# Step 5: atomic rename .tmp -> path. Fallback: delete then rename.
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return ERR_FILE_CANT_OPEN
	var rename_err: Error = dir.rename(tmp_path, path.get_file())
	if rename_err != OK:
		# Best-effort fallback (not atomic, but covers FAT/exFAT edge cases).
		if FileAccess.file_exists(path):
			dir.remove(path.get_file())
		rename_err = dir.rename(tmp_path, path.get_file())
		if rename_err != OK:
			return rename_err

	return OK

## Verify that `path` exists, its sidecar meta holds a matching sha256,
## and the bytes haven't been tampered. The caller passes the actual file
## path; the matching sidecar is automatically selected (`.meta` for live,
## `.bak.meta` for backup) so backups carry their own historical sha256.
static func verify(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var meta_path: String = ""
	if path.ends_with(".bak"):
		meta_path = path + ".meta"   # e.g. save.bak -> save.bak.meta
	else:
		meta_path = path + ".meta"
	if not FileAccess.file_exists(meta_path):
		return false
	var expected: String = _read_text(meta_path).strip_edges()
	if expected.is_empty():
		return false
	var actual: String = sha256_of(path)
	return actual == expected

## Try live file, then .bak, then give up with empty PackedByteArray.
static func load_or_recover(path: String) -> PackedByteArray:
	if verify(path):
		return _read_bytes(path)
	var bak: String = path + ".bak"
	if verify(bak):
		push_warning("[AtomicWrite] live file invalid, recovered from .bak")
		return _read_bytes(bak)
	push_warning("[AtomicWrite] both live and .bak failed verification")
	return PackedByteArray()

## SHA-256 of a file's contents, lowercase hex (64 chars).
static func sha256_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var buf: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return sha256_of_bytes(buf)

## SHA-256 of an in-memory buffer, lowercase hex.
static func sha256_of_bytes(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	var err: Error = ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	ctx.update(bytes)
	return ctx.finish().hex_encode()

## Internals ------------------------------------------------------------------

static func _read_bytes(path: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var buf: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return buf

static func _read_text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t

static func _copy_file(src: String, dst: String) -> Error:
	var f: FileAccess = FileAccess.open(src, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var buf: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var out: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	if out == null:
		return FileAccess.get_open_error()
	out.store_buffer(buf)
	out.close()
	return OK