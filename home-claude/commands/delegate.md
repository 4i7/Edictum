---
description: Spec-driven delegation pipeline — decompose, spec via subagent, execute via Codex, verify via subagent
argument-hint: <task description> [--executor codex|sonnet|opus] [--effort low|medium|high|xhigh] [--fg]
---

Run the full delegation pipeline for the requested work, spending as few
main-session tokens as possible. The main session decides; subagents read and write.

Request:
$ARGUMENTS

Pipeline:

1. **Decide (main session, terse).** Determine: scope and task split (work-stream
   sized — an audit plus its fixes is ONE spec; split only at independently
   mergeable boundaries), approach and any technology/API choices, executor
   (default codex / gpt-5.5; effort default medium — proven sufficient for
   work-stream units; high only for genuinely hard or >30-min-autonomy specs, and as
   the bump on a corrective --resume after a FAIL; gpt-5.4-mini + low for mechanical
   bulk edits). Assign each spec its branch name and `delivery_mode`: `local_only`
   (edit + test only, no commit), `branch_only` (commit to a local branch, no push),
   or `pr_allowed` (push + open draft PR + CI; default for user-owned repos). For
   non-owned, unfamiliar, or untrusted repos, downgrade to `branch_only` or
   `local_only`; `pr_allowed` on a non-owned repo requires explicit user opt-in so
   Edictum never pushes or opens PRs with the user's `gh` auth without consent. Use
   `local_only` or `branch_only` for sensitive/private work. Parallel specs on the
   same repo get separate worktrees. Do not read source files for this — if repo knowledge is
   missing, get it from an `Explore` subagent (`model: sonnet`) and consume only its
   summary.
2. **Spec.** For each task, spawn the `spec-builder` agent (it defaults to sonnet)
   with a directive of roughly 10 lines: goal, fixed decisions, likely files,
   constraints, executor + priority, and the explicit `delivery_mode`. Spawn multiple
   spec-builders in parallel when tasks are independent.
3. **Sanity-check the spec path list** returned by spec-builder. Read a spec body
   only if its 5-line summary flags an open decision.
4. **Execute.** For 3+ specs, or whenever the loop should leave the main session
   (tier handoff), spawn ONE `pipeline-runner` agent with the spec paths,
   parallelism constraints, and review plan — it owns execute→verify→correct→review
   and returns a verdict table; skip to step 7 with its output. Otherwise hand each
   codex-targeted spec to the `codex:codex-rescue` subagent:
   instruct it to have Codex read the spec file at the given path and implement it
   (`--write`), following the spec's Delivery — by default through to commit, push,
   draft PR, and CI green. Default `--background` so several specs run concurrently
   (use foreground only if the user passed `--fg`). Specs targeted at sonnet/opus
   go to a general-purpose subagent with that `model:` instead.
5. **Verify.** When a job reports done, spawn `acceptance-checker` with the spec
   path. PASS → mark the task done. FAIL → send ONE corrective follow-up to Codex
   via `codex:codex-rescue` `--resume`, quoting the checker's findings verbatim; on
   a second FAIL, escalate to the main session (take over directly).
6. **Review (always via subagent — never main-session `/codex:review`).** State the
   plan in one line: default for nontrivial work is one review over the combined
   changes; per-change + adversarial framing for security/architectural changes;
   acceptance-checks-only for trivial mechanical edits. Execute it inside the
   `pipeline-runner` (it runs `review`/`adversarial-review` via the companion) or, on
   the ≤2-spec path, an `acceptance-checker`-style sonnet wrapper that calls
   `node <companion> review|adversarial-review …` and returns ONLY a findings count +
   one-line summary + the path to a findings file. The main session consumes count +
   path, never the review prose. Fix-worthy findings become one more corrective spec.
7. **Merge decision (main session).** Merge when acceptance is PASS, review findings
   are resolved (or the plan was acceptance-only), CI is green, and the change stayed
   in the spec's scope. If any is missing — or the change touches a fixed decision
   from a handoff doc — surface to the user instead of merging.
8. **Report (main session).** Final message to the user: per-task verdict table
   (task, executor, PASS/FAIL, review-findings count, verdict-file path) plus
   anything needing their judgment. No diff quotes, no spec recaps.

Main-session output budget for the whole pipeline: decisions, directives, and the
final report. Everything else lives in subagent transcripts and spec files.
