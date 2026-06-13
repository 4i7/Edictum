# Task Spec Template (commander → Codex / Claude subagent)

Copy into `.claude/tasks/<executor>-p<priority>-<n>-<slug>.md` (executor: codex | sonnet | opus).
Specs must be executable cold — the implementer has no access to the planning conversation.
Reference examples of completed specs: your project's completed-specs archive (e.g. `.claude/tasks-archive/done/`).

---

# [Codex] P<priority>-<n>: <one-line title of the change>

## Context
- Target: <stack, e.g. Tauri 2 + React + plain CSS>. Working directory: `<repo-relative path>`.
- Relevant design decisions: <which library/function/module to build on — decided by the commander, not the implementer>
- Verification commands: `<build/test commands — include known sandbox workarounds verbatim,
  e.g. use npm.cmd not npm; see the known issues in project CLAUDE.md>`. UI check: `<how to launch>`.
- Dependencies: <other task specs that must land first, or "none">

## Delivery
- Branch: `<branch name>` (new or existing). If parallel tasks exist, create a dedicated
  `git worktree` for this task.
- delivery_mode: `<local_only | branch_only | pr_allowed>` (must be explicit. For user-owned
  repos, default: `pr_allowed`. For non-owned / unfamiliar / untrusted repos, downgrade to
  `branch_only` or `local_only` unless there is explicit user opt-in).
  - `local_only`: edit + test only; do not commit.
  - `branch_only`: commit to a local branch; do not push.
  - `pr_allowed`: commit → push → open draft PR → check CI. Non-owned repos require
    explicit user opt-in before selecting this mode.
- Only when `delivery_mode: pr_allowed`: after implementation, commit (English commit
  messages, one logical change per commit), push, open a draft PR, wait for CI green,
  and report the PR URL.
- <Only when there is no remote or the worktree is shared: explicitly say "leave changes uncommitted in the worktree">

## Current state
<What is wrong / missing, and why (root cause if known).>

### Current code
<For every region the spec changes: exact file paths + line numbers + verbatim
current snippets (the delegated specs that passed first-try all did this — default
to it for bug-fix/refactor work). Use plain pointers only for surrounding context
the implementer navigates but does not modify.>

## Changes
<Numbered, concrete steps. For each step state file path and what to change.
Mark explicitly which decisions are FIXED (architecture, API shape, naming) and
which are the implementer's choice ("implementation is up to you, but preserve X").>

## Acceptance criteria
<Checkable list. Each item verifiable by command or quick manual check:>
- <behavioral criterion 1>
- <behavioral criterion 2>
- `<build command>` passes.
- <if applicable> all existing tests pass / new test `<path>` is added and passes.
