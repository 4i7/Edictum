---
name: edictum
description: >-
  Token-efficient delegation playbook for Claude Code. Use whenever a request needs more than a trivial inline edit — any multi-step implementation, feature, bug-fix batch, audit, refactor, or migration. Edictum turns the main session into a COMMANDER that writes cold-executable task specs and delegates the actual coding to OpenAI Codex (free of Claude tokens) and to cheap sonnet subagents, then verifies via fresh-context checkers. Invoke when planning how to split or hand off implementation work, when deciding which model/effort to use, when Fable 5 wants to drop control to Opus/Sonnet, or when running the /delegate pipeline. Keywords: delegate, Codex, spec, pipeline-runner, handoff, token budget, division of labor.
---

# Edictum — Commander × Codex Delegation

The main session is a **commander**, not a coder. It steers; OpenAI **Codex** (runs on
the user's ChatGPT subscription — does NOT consume Claude tokens) and cheap **Claude
subagents** (sonnet) execute; **fresh-context checkers** verify. The goal is to keep
frontier (Fable 5 / Opus) tokens spent on judgment, not on diffs and fix loops.

The always-on decision policy (role split, tiers, token-budget rules) is in the user's
`~/.claude/CLAUDE.md` (Edictum block). THIS file is the detailed procedure: how to run
the loop, how to write specs, how to invoke Codex safely, and how to pick model/effort.

## Prerequisites (installed by Edictum)

- `codex` CLI authenticated (ChatGPT login) — the executor.
- `claude` CLI + the **codex-plugin-cc** plugin (`codex@openai-codex`) — the bridge.
- Subagents `spec-builder`, `acceptance-checker`, `pipeline-runner` (all pin sonnet)
  and the `/delegate` command, in `~/.claude/`.
- Companion script path: `"$CLAUDE_PLUGIN_ROOT/scripts/codex-companion.mjs"` when that
  var is set, else `"$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs"`.

## The delegation loop (run this for any multi-step implementation)

1. **Decide (terse).** Task split, approach, tech/API choices, executor + effort per
   task. **Size tasks as WORK STREAMS, not micro-patches** — Codex sustains 15–25 min
   autonomous runs, so "an audit plus fixing everything it finds" or "a feature plus
   its tests" is ONE spec. Split only at independently mergeable boundaries. Don't read
   source yourself — get repo knowledge from an `Explore` subagent (`model: sonnet`)
   and consume only its summary. Assign each spec a branch and `delivery_mode`;
   parallel specs on one repo get separate `git worktree`s.
2. **Spec.** Spawn `spec-builder` (sonnet) with a short directive (goal + intent, fixed
   decisions, likely files, constraints, executor + priority, branch/worktree, and the
   explicit `delivery_mode` chosen in step 1). It writes a cold-executable spec to
   `.claude/tasks/<executor>-p<priority>-<n>-<slug>.md`. Spawn several in parallel for
   independent tasks. Spec sections: Context (incl. env workarounds) / Current state
   (verbatim current code for changed regions) / Changes (fixed vs. free) /
   Acceptance criteria (runnable) / Delivery (branch, `delivery_mode`, commit/PR/CI policy).
   See `reference/task-spec-template.md`. The commander chooses `delivery_mode` per
   task: `local_only` = edit + test only, no commit; `branch_only` = commit to a
   local branch, no push; `pr_allowed` = push + open draft PR + CI, and remains the
   default for user-owned repos. For non-owned, unfamiliar, or untrusted repos,
   downgrade to `branch_only` or `local_only`; `pr_allowed` on a non-owned repo
   requires explicit user opt-in so Edictum never pushes or opens PRs with the
   user's `gh` auth without consent. Use `local_only` or `branch_only` for
   sensitive/private work.
   Keep `.claude/tasks/` and `.claude/tasks/results/` local and gitignored; they are
   ephemeral work products that may contain verbatim source or secrets.
3. **Execute end-to-end.** `Agent` tool, `subagent_type: "codex:codex-rescue"`, pointing
   at the spec file, `--write`, `--background`. Default `pr_allowed` delivery means
   Codex owns the full git lifecycle (branch → commit → push → draft PR → CI green)
   unless the spec explicitly chooses `branch_only` or `local_only`. **For 3+ specs or
   any tier handoff, hand the whole loop to `pipeline-runner`** instead of
   orchestrating per-spec. If the Codex dispatch fails on quota, billing, or auth,
   fall back to the general-purpose sonnet subagent per "Tiers, fallback, and handoff".
4. **Verify.** `acceptance-checker` (sonnet) checks the Acceptance criteria (CI-first when a PR
   exists) and returns PASS/FAIL ≤10 lines. You read the verdict, never the diff. ONE
   corrective dispatch on FAIL (bump effort one level): use Codex `--resume` for Codex
   jobs, or send the follow-up to the same fallback subagent when Codex is unavailable;
   take over only after a 2nd FAIL.
5. **Review — always via subagent, NEVER main-session `/codex:review`.** Default: one
   review over the combined changes per stream; per-change + adversarial framing for
   security/architectural changes; acceptance-only for mechanical edits. The subagent
   runs `node <companion> review|adversarial-review …` and returns counts + a one-line
   summary + a findings-file path. You consume count + path, never the review prose.
6. **Merge decision.** Merge when acceptance PASS, review findings resolved (or plan was
   acceptance-only), CI green, and change in-scope. For security-sensitive or
   architectural changes, first run `git diff --stat <base>...HEAD` and review the
   touched-file list, not the full diff, as a lightweight safety check. Otherwise
   escalate to the user. When checking 2+ read-only git/gh commands together, delegate
   to the `vcs-runner` (haiku) agent and consume only its summary. Don't use it for a
   single command; overhead exceeds savings. Write operations are out of scope and
   remain owned by Codex delivery.

`/delegate <request>` runs steps 1–6 for you.

## Invoking Codex safely (token discipline)

- **Delegate**: `Agent` tool, `subagent_type: "codex:codex-rescue"` (= `/codex:rescue`).
- **NEVER** run `/codex:review`, `/codex:adversarial-review`, or `/codex:result` from the
  main session — they force the full reviewer output / result payload back verbatim, so
  it lands in your context as input AND is re-emitted as frontier output tokens (double
  spend, the single largest leak). Route them through a subagent (`pipeline-runner` or an
  `acceptance-checker`-style sonnet wrapper) calling the companion script over Bash.
- `/codex:status` (terminal/idle check, no payload) and `/codex:cancel` are fine.
- `review`/`adversarial-review` are FOREGROUND-only (the `--background` flag is inert) and
  run from the target git worktree; a long review consumes the whole ~10 min Bash-call
  budget. Poll `task` runs with `status <job-id> --wait --timeout-ms <ms>` re-issued
  across Bash calls. Job visibility (`status`/`result` without an id, `--resume-last`) is
  scoped to the originating Claude session — always poll by explicit job-id, and never
  hand off a session with a Codex job still in flight.
- `--effort minimal` is unusable (conflicts with Codex web_search → HTTP 400).

## Model & effort selection

Full data + sources: `reference/model-benchmarks.md`.

| Task | Owner | Setting |
|---|---|---|
| Phase-zero judgment (ambiguous goals, architecture, risky tech) | Fable 5 (main) | hand off once direction is set |
| Progression planning, decomposition, directives | Commander (any tier) | — |
| Codebase exploration, large search | Claude subagent | `Explore` / `model: sonnet` |
| Routine AND work-stream implementation, tests, refactor | Codex | default gpt-5.5 / medium |
| Genuinely hard or >30-min-autonomy implementation (with spec) | Codex | `--model gpt-5.5 --effort high` |
| Mechanical bulk edits at volume | Codex | `--model gpt-5.4-mini --effort low\|medium` |
| Build repair, CI fixes, env, CLI investigation | Codex | gpt-5.5 (Terminal-Bench SOTA) |
| Code review | Codex via subagent | companion `review` — never main-session `/codex:review` |
| Execute→verify→correct loop over a spec batch | `pipeline-runner` | pins sonnet; `model: opus` for risky streams |
| Un-spec-able implementation (no checkable criteria) | Commander (main) | last resort; carve out spec-able parts |
| Final judgment, merge | Commander (main) | — |

Heuristics:

- Everyday implementation: GPT-5.5 ≈ Opus 4.8 (SWE-bench Verified 88.7% vs 88.6%).
- **Inference** "hard but specifiable is Codex territory": commander-written specs neutralize
  most of the SWE-bench-Pro gap (which measures *unsupervised* problem-solving). Validated
  on TS+Rust/web; treat other stacks/domains as unverified — probe with one spec first.
- **Effort**: gpt-5.5 / `medium` is the workhorse for routine AND work-stream specs. Don't
  blanket-raise to high; escalate by evidence (high up front only for genuinely hard or
  >30-min specs; bump one level on a corrective `--resume`). `xhigh`/`max` are exceptional.
- **Spec detail (delegated path)**: default to detailed specs — decisions + scope +
  acceptance criteria + env workarounds AND verbatim current code for the changed regions.
  Goals-only specs are a hypothesis for delegation (proven only in human-supervised manual runs).
- Reserve Fable for judgment under ambiguity. Anything specifiable is delegable to Codex,
  and its progression is commandable by Opus/Sonnet.
- Claude subagents take `model: fable|opus|sonnet|haiku`; per-subagent thinking effort is
  not settable (inherits the session). Always pin a subagent's model explicitly.

## Tiers, fallback, and handoff

- **Fable 5 → phase zero only.** Once direction is set, propose handing control to Opus
  (default commander) or Sonnet (routine streams) rather than burning frontier tokens.
- **Within a session**: delegate the spec-batch loop to `pipeline-runner`.
- **Codex unavailable**: when Codex cannot execute a spec because usage-limit/quota is
  exhausted, billing lapsed, auth failed, `pipeline-runner` returns
  `BLOCKED(quota|auth)`, or a direct `codex:codex-rescue` dispatch errors on limits,
  tell the user Codex is unavailable and that a Claude subagent is covering execution
  (this consumes Claude tokens, unlike Codex). Reroute that SAME spec to a built-in
  general-purpose subagent with `model: sonnet` to implement it (`haiku` only for
  trivial mechanical specs). If verification fails or review finds a fix-worthy issue,
  send the one corrective follow-up to that same fallback subagent, then continue the
  normal verify → review → merge loop.
- **Across sessions**: write `.claude/tasks/HANDOFF-<slug>.md` from `reference/handoff-template.md`
  and continue in a lower-tier session. Finish/cancel in-flight Codex jobs first (visibility
  is session-scoped).
- **Escalate back up** only for: two consecutive FAILs on one spec, an architectural
  surprise, or a scope change.

## Calibrate to your own project

Edictum ships with the author's calibration as an example. Replace it with yours:
1. Put your project's env/sandbox workarounds (e.g. a non-standard test command) in the
   project `CLAUDE.md` so `spec-builder` copies them into every spec's verification commands.
2. After a handful of real delegated runs, record in `reference/model-benchmarks.md` what
   difficulty Codex handled at what effort, and adjust the heuristics. Mark anything not yet
   observed as hypothesis / inference / unverified.
