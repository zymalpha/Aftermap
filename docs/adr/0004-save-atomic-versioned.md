# ADR-0004: Saves — Atomic, versioned, SHA-256 checked, .bak fallback

- Status: Accepted
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.16 / §11.7 / §14.七 item 8 / §12.4 P0 spike `atomic_save_recovery`

## Context

§11.16 mandates that every save be:

- structured into per-slot files (`slot_<id>/header.json`,
  `session.dat`, `tactical.dat`, `history.jsonl`, `checksums.json`);
- written via a 6-step atomic protocol
  (§11.16.2 — temp file → flush → retain previous → replace → update
  header → never delete last good);
- versioned with `save_schema_version` and `content_fingerprint`
  (§11.16.3);
- migratable, with chain-of-version migrations, automatic backup before
  migration, and 3 historical-version fixtures (§11.16.3).

§11.7 item 7 / §11.16.3 also require the build to refuse to load a
corrupt or downgraded save without surfacing an understandable error.

§14.七 item 8 codifies "no partial state" at command-execution
boundaries, which interacts with the write protocol: a save
transaction cannot commit halfway.

## Decision

1. **Six-step atomic protocol** (verbatim from §11.16.2):
   1. Write to a same-directory temp file.
   2. Flush (`f.flush()` + OS-level `fsync` where the platform
      supports it).
   3. Keep a copy of the previous version as `*.bak` next to the
      slot.
   4. Atomically replace the live file
      (`os.rename(...)`, fall back to `MoveFileExW` with replace
      flag on Windows).
   5. Update `header.json`.
   6. On any failure, leave the last known-good save in place.
2. **`checksums.json` uses SHA-256** (`hashlib.sha256` in Python, or
   `HashingContext` with SHA-256 in GDScript). The slot file and the
   `checksums.json` together cover every file the loader reads back.
3. **Version header** contains at minimum:
   - `save_schema_version` (integer, monotonic).
   - `content_fingerprint` (hash of the loaded `ContentDB`).
   - `seed` (root seed).
   - `created_at` and `updated_at` ISO-8601 strings.
   - Stream state — see ADR-0003.
4. **Migration chain** loads each version's `migrate(from_v, session)`
   in order, with an automatic pre-migration backup. The chain must
   hold fixtures for the last 3 schema versions in
   `tests/fixtures/saves/`.
5. **Loader contract**: if `checksums.json` fails validation, the
   loader must (a) attempt the `.bak` copy, (b) if also invalid,
   refuse to launch the campaign and surface an error code from
   §11.8.3 (`ERR_SAVE_CORRUPT`) with a localised key.
6. **Production builds isolate** a corrupt save — they do not silently
   delete it. Dev builds log the full trace.

## Consequences

Positive:
- A power-loss / forced-exit scenario cannot leave an un-recoverable
  save. §12.4 P0 spike `atomic_save_recovery` will deliberately kill
  the process mid-write and prove recovery from `.bak`.
- Content updates can rewrite IDs without breaking ongoing
  campaigns, because migration replaces deprecated IDs via the
  mapping table (§11.6.1).
- Save failure is loud, never silent.

Negative / constraints:
- Every commit of a state mutation implies IO. Combat tick rates
  cannot push saves at 60 Hz; we only save at documented
  checkpoints (§03 morning / night / end-of-day / save-slot action).
- We must maintain migration code forever for any saved version, or
  remove support deliberately and document it (which §11.6.1
  permits).
- SHA-256 + `fsync` adds latency. We measure against the
  2-second-write / 5-second-load budget (§11.21) at P6.

## Alternatives Considered

- **Rollback journal (WAL)** — Defer. Strong guarantee but requires
  a custom binary format and conflict-resolution code; not justified
  for the MVP scale.
- **Single serialized JSON** — Rejected. No checksum separation,
  no atomic rename granularity, no migration path.
- **Autosave to a cloud-sync folder** — Explicitly forbidden by
  §11.18 / §14.四. No remote dependency in MVP.

## Open Questions

- Whether Windows `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING`
  behaves atomically on network drives. **Assumption: save slot lives
  on the local filesystem only**. If a future platform wants network
  storage, this ADR reopens.
- Whether to compress `session.dat` with `zstd`. **Defer to Stage 5**;
  current MVP JSON is small enough to skip.

## Impact Surface

- `game/adapters/saves/AtomicWriter.gd` (Python twin
  `tools/build/save_smoke.py`).
- Slot path resolver under `%LOCALAPPDATA%/Aftermap/saves/slot_<id>/`.
- Migration modules under `game/adapters/saves/migrations/`.
- Unit tests in `tests/unit/test_atomic_save.gd` (Stage 4).
