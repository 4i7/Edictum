# Edictum

**Token-efficient delegation for Claude Code.** Edictum turns your Claude Code main
session into a *commander* that plans and judges, and pushes the actual coding down to
OpenAI **Codex** (which runs on your ChatGPT subscription and costs **zero Claude
tokens**) and to cheap **sonnet subagents**. Frontier models (Fable 5, Opus 4.8) stay
expensive — Edictum keeps their tokens on judgment, not on diffs and fix loops.

## The problem it solves

Running a frontier model as the everyday driver burns tokens fast: it reads source,
writes code, re-reads diffs, and loops on fixes — all at frontier rates. Edictum
restructures that work:

- **Commander (main session, any tier)** decides *what* to build and writes a
  cold-executable task spec. It does not read source in bulk or write the code.
- **Codex** executes the spec end-to-end (branch → commit → push → draft PR → CI),
  on your ChatGPT plan's quota — not Claude's.
- **Sonnet subagents** draft the specs, verify acceptance criteria, and run the
  execute→verify→correct→review loop, so build logs / diffs / review prose never reach
  the commander's context.
- When a frontier commander (Fable 5) has set direction, it **hands control down** to
  Opus/Sonnet — within a session or across sessions — so routine progression doesn't
  run on frontier tokens.

## How it works

Three Claude Code primitives plus the Codex bridge:

| Piece | Type | Role |
|---|---|---|
| `edictum` | **Skill** | The on-demand playbook: delegation loop, spec format, Codex-invocation rules, model/effort selection, calibration. |
| Edictum block in `~/.claude/CLAUDE.md` | always-on policy | ~30 lines: role split, commander tiers, token-budget rules. The lean always-on core; detail lives in the skill. |
| `spec-builder`, `acceptance-checker`, `pipeline-runner` | **Subagents** (sonnet) | Draft specs, verify acceptance (CI-first), and own the full spec-batch loop. |
| `/delegate` | **Command** | Runs the whole decompose → spec → execute → verify → review → merge pipeline. |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | **MCP plugin** (external) | The Codex bridge. Edictum drives it; it is not bundled here. |

## Prerequisites

- **Node.js 18+**
- **Claude Code CLI** — `npm i -g @anthropic-ai/claude-code`
- **Codex CLI**, logged in — `npm i -g @openai/codex` then `codex login`
- **codex-plugin-cc** —
  `claude plugin marketplace add openai/codex-plugin-cc` then
  `claude plugin install codex@openai-codex`

The installer checks these and prints what's missing; it won't overwrite your work.

## Install

Clone, then run the installer for your shell:

```powershell
# Windows (PowerShell)
git clone https://github.com/4i7/Edictum.git
cd Edictum
./install.ps1
```

```bash
# macOS / Linux / WSL
git clone https://github.com/4i7/Edictum.git
cd Edictum
bash install.sh
```

The installer:
1. Verifies prerequisites (warns, never hard-blocks).
2. Copies `home-claude/{agents,commands,skills}` into `~/.claude/`.
3. Merges the Edictum policy block into `~/.claude/CLAUDE.md` between
   `<!-- EDICTUM:START -->` / `<!-- EDICTUM:END -->` markers — **backing up your
   existing `CLAUDE.md` to `CLAUDE.md.bak` first**, and replacing only the marked block
   on re-runs (idempotent).

Restart your Claude Code session afterward so the new skill/agents/command load.

## Repo hygiene

Edictum writes cold-executable specs and verdicts under local, ephemeral work
directories that may contain verbatim source or secrets. Add these paths to the
target project's `.gitignore`:

```
.claude/tasks/
.claude/tasks/results/
```

## Usage

- Just ask for multi-step implementation work normally — the commander policy + skill
  steer it into delegation automatically.
- Or invoke explicitly: **`/delegate <what you want built>`**.
- Borderline-small task you still want delegated? `/delegate` it. Frontier models
  implement directly only when checkable acceptance criteria can't be written at all.

## Calibrate to your project

Edictum ships with the author's calibration as an *example* (TS+Rust, n=7). Make it
yours: put your project's env/test workarounds in that project's `CLAUDE.md` so specs
inherit them, and after a few real runs update
`~/.claude/skills/edictum/reference/model-benchmarks.md` with what Codex actually
handled at what effort. Label anything unverified as 仮説 / 推定 / 要検証.

## Uninstall

Delete `~/.claude/skills/edictum/`, the three Edictum agents, `~/.claude/commands/delegate.md`,
and the `<!-- EDICTUM:START -->…<!-- EDICTUM:END -->` block from `~/.claude/CLAUDE.md`
(or restore `CLAUDE.md.bak`).

## Layout

```
home-claude/                      # mirrors ~/.claude/ ; the installer copies this in
  CLAUDE-policy-snippet.md        # the always-on block merged into ~/.claude/CLAUDE.md
  agents/{spec-builder,acceptance-checker,pipeline-runner}.md
  commands/delegate.md
  skills/edictum/
    SKILL.md                      # the on-demand playbook
    reference/{task-spec-template,handoff-template,model-benchmarks}.md
install.ps1 / install.sh
```

## License

MIT © 4i7. See [LICENSE](LICENSE).
