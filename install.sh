#!/usr/bin/env bash
# Edictum installer (macOS / Linux / WSL).
# Deploys agents, command, and the edictum skill into ~/.claude, and merges the
# always-on policy block into ~/.claude/CLAUDE.md (idempotent, backed up).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude="$HOME/.claude"
src="$repo/home-claude"

have() { command -v "$1" >/dev/null 2>&1; }

echo "Edictum installer"
echo "  repo: $repo"
echo "  target: $claude"
echo

# --- 1. Prerequisite checks (warn, never block) ---
echo "Checking prerequisites..."
warn=()
have node   || warn+=("node not found - install Node.js 18+.")
have claude || warn+=("claude CLI not found - npm i -g @anthropic-ai/claude-code")
if ! have codex; then
  warn+=("codex CLI not found - npm i -g @openai/codex; then 'codex login'")
elif ! codex login status 2>&1 | grep -qi "logged in"; then
  warn+=("codex is installed but not logged in - run 'codex login'.")
fi
if ! { have claude && claude plugin list 2>&1 | grep -q "codex@openai-codex"; }; then
  warn+=("codex-plugin-cc not installed - 'claude plugin marketplace add openai/codex-plugin-cc' then 'claude plugin install codex@openai-codex'")
fi
if [ "${#warn[@]}" -gt 0 ]; then printf '  [!] %s\n' "${warn[@]}"; else echo "  all prerequisites present."; fi

# --- 2. Copy agents / command / skill ---
echo
echo "Copying assets into ~/.claude ..."
mkdir -p "$claude/agents" "$claude/commands" "$claude/skills/edictum"
cp -Rf "$src/agents/."        "$claude/agents/"
cp -Rf "$src/commands/."      "$claude/commands/"
cp -Rf "$src/skills/edictum/." "$claude/skills/edictum/"
echo "  agents, command, and edictum skill installed."

# --- 3. Merge the policy block into CLAUDE.md (idempotent, backed up) ---
echo
echo "Merging policy block into ~/.claude/CLAUDE.md ..."
snippet="$src/CLAUDE-policy-snippet.md"
claudemd="$claude/CLAUDE.md"
start="<!-- EDICTUM:START"
end="<!-- EDICTUM:END -->"

if [ -f "$claudemd" ]; then
  cp -f "$claudemd" "$claudemd.bak"
  # Strip any existing EDICTUM block, then append the fresh snippet.
  awk -v s="$start" -v e="$end" '
    index($0,s){skip=1}
    !skip{print}
    skip && index($0,e){skip=0}
  ' "$claudemd" | sed -e 's/[[:space:]]*$//' > "$claudemd.tmp"
  # collapse trailing blank lines, then append snippet
  awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++)print a[i]}' "$claudemd.tmp" > "$claudemd"
  rm -f "$claudemd.tmp"
  printf '\n\n' >> "$claudemd"
  cat "$snippet" >> "$claudemd"
  echo "  merged (backup: CLAUDE.md.bak)."
else
  cp -f "$snippet" "$claudemd"
  echo "  created ~/.claude/CLAUDE.md with the Edictum block."
fi

echo
echo "Done. Restart your Claude Code session to load the skill, agents, and command."
[ "${#warn[@]}" -gt 0 ] && echo "Resolve the [!] items above for full functionality."
exit 0
