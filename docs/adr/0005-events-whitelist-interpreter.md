# ADR-0005: Events — Whitelisted AST interpreter, no eval, all effects routed through GameSession commands

- Status: Accepted
- Date: 2026-07-22
- Deciders: Project tech lead
- Related: §11.14 / §11.20 / §14.七 item 6 / §08 / §12.4 P0 spike `event_interpreter`

## Context

§11.14 is unambiguous:

- Conditions and effects are whitelisted enums of "type + parameters".
- Data must never carry script paths, expressions, or system commands.
- Every effect runs a dry-run, then the chosen option's effects are
  applied **as one transaction**, with rollback on failure.
- Delayed effects use **absolute campaign day / minute** plus a stable
  instance ID.

§11.20 reinforces "external content is untrusted"; §14.七 item 6 says
explicitly "事件条件/效果使用白名单解释器，不能执行任意脚本".

If we adopted `Expression`, `Callable`, `parse()`, or `eval()` —
even gated — the security boundary between content authors and the
domain layer collapses. AI could be tricked into writing content that
executes arbitrary code, violating §14.七 item 13.

## Decision

1. **Effect / condition whitelists** are enums declared in
   `content/schemas/effect_node.schema.json` and
   `content/schemas/condition_node.schema.json`. The current allowed
   ops (this list grows with schema-version bumps):
   - Effects: `stat_add`, `stat_set`, `item_add`, `item_remove`,
     `spawn_npc`, `set_flag`, `unlock_event`, `queue_event`,
     `deal_damage`, `apply_infection`, `move_to`.
   - Conditions: `flag_has`, `stat_compare`, `rng_chance`,
     `time_in_range`, `item_count`, `relationship_threshold`,
     `city_pressure`.
2. **No scripting surface**. Any feature request that would require
   `Expression`, `Callable.eval`, `JSON.evaluate`, or `Object.call` on
   data is declined — the only escape hatch is to extend the
   whitelist through a schema bump.
3. **All effects route through GameSession commands** (§11.2 item 3,
   §11.9). The event interpreter never mutates `GameSession` state
   directly; it constructs a `CommandBatch`, runs dry-run validation,
   and only on success applies it. A failed batch is logged with an
   error code from §11.8.3.
4. **Transactional** at choice-commit time. Atomicity semantics mirror
   ADR-0004: the choice has either fully applied or not at all.
   In-flight state is the dry-run projection.
5. **Delayed / chained events** use absolute campaign time plus a
   stable instance UUID. The interpreter does not store closures or
   `Callable` references; delayed actions are persisted as data and
   re-applied on the next clock tick.
6. **Debugger visibility**. Per §11.14 last bullet, the interpreter
   exposes the condition tree, score breakdown, and dry-run vs
   applied diff. This is wired through `GameSession.debug_dump()`.
7. **Tests are mandatory**. §11.14 last line says explicitly: the
   interpreter's unit tests outrank writing more events.

## Consequences

Positive:
- The interpreter becomes an enumeration; AI and humans can read it
  exhaustively without surprises.
- Every effect has a deterministic dry-run, so the test suite can
  diff a "before applying" and "after applying" projection without
  rolling state back manually.
- Failed content is isolated — schema validation fails the build
  before the interpreter ever runs (§11.7).

Negative / constraints:
- Designers must ask for a new effect op via a schema bump and ADR
  patch. This is by design and matches §11.7 / §14.七 item 12.
- More verbose event payloads (one JSON object per effect), but
  each object is small and a content linter can catch typos.

## Alternatives Considered

- **Lua or GDScript eval inside an isolated sandbox** — Rejected:
  §11.14 forbids expressions and scripts; even a sandboxed eval
  adds attack surface and breaks the unit-test determinism
  guarantee.
- **Visual scripting embedded as data** — Considered, deferred: the
  GraphEdit node exposes `Callable` and cannot be parsed offline
  without re-implementing the editor. For the MVP, declarative
  enums are sufficient; visual scripting is a P5+ candidate.
- **Effect DSL compiled to GDScript at build time** — Rejected:
  blurs content / code boundary and prevents the content linter
  from running in CI without a Godot install.

## Open Questions

- None. Schema bump protocol for adding ops is described under
  ADR-0001 §"Impact Surface".

## Impact Surface

- `game/domain/events/Interpreter.gd` (declared in Stage 4/5).
- `content/schemas/effect_node.schema.json` (`allowed_effects` array).
- `content/schemas/event.schema.json` (uses oneOf `$ref` to
  effect_node and condition_node).
- `tests/unit/test_event_interpreter.py` — chosen from the spike
  `event_interpreter` (P0).
