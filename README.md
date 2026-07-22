# Aftermap — Repository README

A 2D-pixel apocalypse-management game (Godot 4.6.2). This README is the
30-minute quick-start for the **P0/P1 spike** (currently green: 166 PASS / 0 FAIL).
Full design source of truth: `README_ORIG_PLANNING.md`.

> **Status: v0.1.0 spike complete.** Tactical grid, pathfinding, FOV, sound,
> alertness, combat, search, and infection stubs all wire through `GameSession`.
> Next milestone is P2 (BACKLOG `docs/production/BACKLOG.md`).

## 30-Minute Quick Start

### 1. Prerequisites (5 min)

- **Python 3.9+** — for content schema validation.
- **Godot 4.6.2 (stable, win64 / linux / macos)** — for headless tests.
  Place the binary at `.tools/godot/Godot_v4.6.2-stable_win64.exe` (or have
  `godot` on `PATH`). Without Godot, the schema step still runs; the headless
  step warns and exits 0.
- A POSIX shell (`bash`) or Windows `cmd` for the bundled runners.

### 2. Clone (2 min)

```bash
git clone https://github.com/zymalpha/aftermap.git
cd aftermap
```

### 3. Run the spike (3 min)

```bash
# Linux / macOS / WSL
bash run.sh
# or the dedicated test runner
bash tools/build/run_tests.sh

# Windows
run.bat
REM or
tools\build\run_tests.bat
```

Expected tail:

```
=== Godot headless P0/P1 spike ===
-- test_rng_determinism --
-- test_save_atomic_recovery --
-- test_event_interpreter --
-- test_command_queue --
-- test_grid_pathfind --
-- test_pixel_scaling --
-- test_content_schema --
-- test_stage3_smoke --
-- test_p1_tactical --
=== 完成 ===
```

### 4. Read the docs (15 min)

| Doc                                                | What it tells you                                           |
| -------------------------------------------------- | ----------------------------------------------------------- |
| `docs/production/PROJECT_STATE.md`                 | Spike state, known risks, hard constraints, deliverables.   |
| `docs/production/BACKLOG.md`                       | P2–P6 card summary — what's next.                           |
| `docs/production/DECISIONS.md`                     | ADR index (0001–0006).                                      |
| `docs/production/CHANGELOG_DEV.md`                 | Stage 1–6 delivery log.                                     |
| `docs/api/game-session.md`                         | `GameSession` API contract (commands, RNG, save).          |
| `docs/api/tactical-session.md`                     | Tactical grid / pathfind / FOV / combat API contract.      |
| `docs/api/content-db.md`                           | Content DB contract (ids, lookup, kind enums).             |
| `docs/adr/0001..0006-*.md`                         | Architecture decision records.                              |
| `README_ORIG_PLANNING.md`                          | Full design source of truth.                                |

### 5. Edit a sample event (5 min)

Open `content/events/sample_first_night.json`, change `weight` from `60` to
`55`, rerun `bash run.sh`. The Python schema validator will catch any
shape mistake; the spike will still pass because it doesn't touch that field.

## Acceptance Checklist (P0/P1 spike)

A reviewer should be able to tick all of these in <30 min:

- [ ] `python tools/content_validator/validate.py content` exits 0.
- [ ] `bash run.sh` exits 0 and prints `=== 完成 ===` with no `WARN: ... exit non-zero` lines (when Godot is installed).
- [ ] On a machine without Godot, the same command exits 0 and prints exactly one `WARN: Godot 未安装...` line.
- [ ] Every file under `content/schemas/` is referenced from at least one schema (no orphans).
- [ ] Every JSON under `content/{items,events,event-chains,facilities,traits,poi-rooms,recipes}/` matches its schema.
- [ ] `docs/adr/0001..0006` exist with `Status: Accepted` (no `Superseded` yet).
- [ ] `docs/production/PROJECT_STATE.md` lists the same PASS/FAIL counts you observe locally.
- [ ] `git log --oneline` shows the seven commits from `97f64fc` through the current head.

## Known Limitations (this spike)

These are explicitly **deferred**, not bugs:

1. **No real OSM map fetch.** ADR-0006 defers OSM/Overpass to P3. The map
   pipeline only ingests hand-authored samples today.
2. **No save migration scaffolding.** `save_v1.gd` only knows version 1.
   Migration tooling is P2 (`SAVE-2`).
3. **Combat / infection / survivors behavior is stubbed.** The P1 spike
   wires the modules into `GameSession` so the round-trip works, but
   resolution math is a placeholder. Full implementation is P2
   (`COMBAT-2`, `INF-2`, `CORE-1`).
4. **Localization adapter is empty.** String tables land in P2 (`LOC-1`).
5. **No presentation scenes beyond `tactical.tscn` stub.** Full UI/UX pass
   is P5 (`UI-5`, `ART-5`, `A11Y-5`).
6. **Tests live under `game/tests/`.** The repo-root `tests/` directory is
   a `.gitkeep` placeholder and will either be populated or removed in
   P2 cleanup.

## Repository Layout

```
.
├── README.md                     # this file
├── README_ORIG_PLANNING.md       # design source of truth
├── CHANGELOG.md                  # public release notes
├── PUSH_INSTRUCTIONS.md          # GitHub push steps (Stage 7)
├── run.sh / run.bat              # full spike runner (schema + Godot)
├── project.godot                 # Godot project descriptor
├── game/                         # all GDScript (core / domain / presentation / tests)
│   ├── core/                     # GameSession, RNG, Clock, ContentDB
│   ├── domain/                   # tactical, events, infection, inventory, survivors, world
│   ├── adapters/                 # saves, localization, maps (stubs where empty)
│   ├── presentation/             # pixel scaling, scenes, UI
│   └── tests/                    # headless GDScript tests (run via run.sh)
├── content/                      # content JSON + schemas (validated by tools/content_validator)
├── docs/
│   ├── adr/                      # ADR-0001..0006
│   ├── api/                      # API contracts (game-session, tactical-session, content-db)
│   └── production/               # PROJECT_STATE, BACKLOG, DECISIONS, CHANGELOG_DEV
├── tools/
│   ├── build/                    # run_tests.sh, run_tests.bat (CI entry-points)
│   ├── content_validator/        # jsonschema-based offline validator
│   └── map_pipeline/             # P3 OSM pipeline stub
└── tests/                        # placeholder (.gitkeep)
```

## Hard Constraints (do not violate)

These come straight from the ADR set and `README_ORIG_PLANNING.md`. Violating
any of them is a release-blocker:

- Engine = **Godot 4.6.2 only**; renderer = **Compatibility / OpenGL only**; 30-AI cap.
- All gameplay randomness flows through the **8 named RNG streams** (`cosmetic_only` excluded).
- Saves are **atomic, versioned, SHA-256 verified** with a `.bak` fallback.
- Event effects are a **whitelisted AST** — no `eval`, no script injection.
- All gameplay state changes route through `GameSession` commands.
- Content IDs match `^[a-z]+_[a-z0-9_]+$` patterns.
- Display strings come from localization tables — never English literals in gameplay logic.

## License

TBD. See `LICENSE` once the project reaches v0.2.0 (REL-6).