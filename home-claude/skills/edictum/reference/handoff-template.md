# Commander Handoff Template (outgoing commander → incoming session)

Copy into `.claude/tasks/HANDOFF-<slug>.md` (project-local). Written by the outgoing
commander (any tier) once direction is set; the incoming session (any Claude model)
must be able to run the whole remaining workstream from this file + global CLAUDE.md
alone. Do NOT hand off while a Codex job is still in flight — job visibility is
scoped to the originating session, so the new session can't query or resume it.

---

# HANDOFF: <workstream title>

## Mission & intent
<1–3 sentences: the larger goal, who it's for, what done looks like. Intent makes
every downstream directive perform better — keep it.>

## Fixed decisions (do not re-litigate)
- <architecture / library / API choices already made, each in one line>
- <anything the incoming commander must NOT change without escalating>

## State
- Repo / working dir: `<path>`; base branch: `<branch>`
- Done: <merged PRs / completed specs, one line each>
- In flight: <spec → branch/PR → status — must be EMPTY at handoff; finish or
  cancel in-flight Codex jobs first>
- Prior verdicts: `.claude/tasks/results/<spec>-verdict.md` (pipeline-runner output)
- Pending specs: `.claude/tasks/<file>` (executor, effort) — in intended order

## Verification & review plan
- Acceptance: <per-spec via pipeline-runner / acceptance-checker; CI-first or local commands>
- Review cadence: <per-change | batched per N tasks | acceptance-only for mechanical work>
- Commander holistic pass: <at which checkpoint, what scope>

## Escalation criteria (back to user → Fable)
- Two consecutive FAILs on one spec
- <workstream-specific red flags, e.g. "any change to the provider security gates">

## Env notes
- <sandbox workarounds, quota state, anything from project CLAUDE.md worth pinning>
