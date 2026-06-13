#!/usr/bin/env bash
# Edictum installer (macOS / Linux / WSL).
# Deploys agents, command, and the edictum skill into ~/.claude, and merges the
# always-on policy block into ~/.claude/CLAUDE.md (idempotent, backed up).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/home-claude"
dry_run=0
force=0
uninstall=0
project_only=""

usage() {
  cat <<'EOF'
Usage: bash install.sh [--dry-run] [--force] [--project-only <path>] [--uninstall]

Options:
  --dry-run              Print planned actions without creating, copying, writing, or deleting.
  --force                Continue installation even when required prerequisites are missing.
  --project-only <path>  Install into <path>/.claude instead of the global ~/.claude.
  --uninstall            Remove only Edictum-installed files and the Edictum CLAUDE.md block.
  -h, --help             Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --project-only)
      shift
      [ "$#" -gt 0 ] || { echo "--project-only requires a path." >&2; exit 2; }
      project_only=$1
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "$project_only" ]; then
  [ -d "$project_only" ] || { echo "--project-only path does not exist: $project_only" >&2; exit 2; }
  project_root="$(cd "$project_only" && pwd)"
  claude="$project_root/.claude"
else
  claude="$HOME/.claude"
fi

claudemd="$claude/CLAUDE.md"
start="<!-- EDICTUM:START"
end="<!-- EDICTUM:END -->"

have() { command -v "$1" >/dev/null 2>&1; }

backup_path() {
  stamp="$(date '+%Y%m%d-%H%M%S')"
  candidate="$1.bak.$stamp"
  n=1
  while [ -e "$candidate" ]; do
    candidate="$1.bak.$stamp.$n"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

marker_state() {
  [ -f "$1" ] || { echo "none"; return; }
  awk -v s="$start" -v e="$end" '
    {
      si = index($0, s)
      ei = index($0, e)
      if (si && in_block) { print "bad:nested:" NR; bad=1; exit }
      if (ei && !in_block && !si) { print "bad:orphan:" NR; bad=1; exit }
      if (si) {
        if (completed) { print "bad:multiple:" NR; bad=1; exit }
        if (ei && ei > si) { completed=1; next }
        in_block=1
        start_line=NR
        next
      }
      if (ei && in_block) {
        in_block=0
        completed=1
      }
    }
    END {
      if (!bad) {
        if (in_block) { print "bad:missing:" start_line }
        else if (completed) { print "ok" }
        else { print "none" }
      }
    }
  ' "$1"
}

strip_block() {
  awk -v s="$start" -v e="$end" '
    {
      si = index($0, s)
      ei = index($0, e)
      if (skip) {
        if (ei) { skip=0 }
        next
      }
      if (si) {
        if (!ei || ei < si) { skip=1 }
        next
      }
    }
    !skip { print }
  ' "$1" | awk 'NF { last=NR } { line[NR]=$0 } END { for (i=1; i<=last; i++) print line[i] }'
}

restore_hint() {
  if [ -n "${1:-}" ]; then
    echo "  restore with: cp \"$1\" \"$claudemd\""
  else
    echo "  restore example: cp \"$claudemd.bak.<timestamp>\" \"$claudemd\""
  fi
}

check_prereqs() {
  required=()
  warn=()
  have node || required+=("node not found - install Node.js 18+.")
  have claude || required+=("claude CLI not found - npm i -g @anthropic-ai/claude-code")
  if ! have codex; then
    required+=("codex CLI not found - npm i -g @openai/codex; then 'codex login'")
  elif [ "$dry_run" -eq 1 ]; then
    warn+=("codex login status not checked during --dry-run to avoid writing CLI state.")
  elif ! codex login status 2>&1 | grep -qi "logged in"; then
    warn+=("codex is installed but not logged in - run 'codex login'.")
  fi
  if [ "$dry_run" -eq 1 ] && have claude; then
    warn+=("codex-plugin-cc status not checked during --dry-run to avoid writing CLI state.")
  elif ! { have claude && claude plugin list 2>&1 | grep -q "codex@openai-codex"; }; then
    required+=("codex-plugin-cc not installed - 'claude plugin marketplace add openai/codex-plugin-cc' then 'claude plugin install codex@openai-codex'")
  fi
}

echo "Edictum installer"
echo "  repo: $repo"
echo "  target: $claude"
[ "$dry_run" -eq 1 ] && echo "  mode: dry-run (no filesystem changes)"
[ "$uninstall" -eq 1 ] && echo "  action: uninstall"
echo

if [ "$uninstall" -eq 0 ]; then
  echo "Checking prerequisites..."
  check_prereqs
  if [ "${#required[@]}" -gt 0 ]; then
    printf '  [required missing] %s\n' "${required[@]}"
  else
    echo "  all required prerequisites present."
  fi
  [ "${#warn[@]}" -gt 0 ] && printf '  [warn] %s\n' "${warn[@]}"
  if [ "${#required[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
    echo "Required prerequisites are missing. No files were changed. Re-run with --force to continue anyway." >&2
    exit 1
  fi
fi

state="$(marker_state "$claudemd")"
case "$state" in
  bad:*)
    rest=${state#bad:}
    kind=${rest%%:*}
    line=${rest#*:}
    case "$kind" in
      missing) issue="Found $start in $claudemd near line $line, but $end was not found." ;;
      nested) issue="Found nested $start in $claudemd near line $line before $end." ;;
      multiple) issue="Found multiple EDICTUM blocks in $claudemd near line $line." ;;
      orphan) issue="Found $end in $claudemd near line $line without a preceding $start." ;;
      *) issue="Found an invalid EDICTUM marker block in $claudemd near line $line." ;;
    esac
    echo "$issue Manually repair the marker block before re-running." >&2
    echo "No files were changed." >&2
    exit 1
    ;;
esac

installed_paths=(
  "$claude/agents/spec-builder.md"
  "$claude/agents/acceptance-checker.md"
  "$claude/agents/pipeline-runner.md"
  "$claude/agents/vcs-runner.md"
  "$claude/commands/delegate.md"
  "$claude/skills/edictum"
)

if [ "$uninstall" -eq 1 ]; then
  echo "Uninstalling Edictum from $claude ..."
  backup=""
  if [ -f "$claudemd" ]; then
    if [ "$state" = "ok" ]; then
      backup="$(backup_path "$claudemd")"
      echo "  remove EDICTUM block from $claudemd"
      echo "  backup: $backup"
      if [ "$dry_run" -eq 0 ]; then
        cp -f "$claudemd" "$backup"
        tmp="$claudemd.tmp.$$"
        strip_block "$claudemd" > "$tmp"
        mv "$tmp" "$claudemd"
      fi
    else
      echo "  no EDICTUM block found in $claudemd; skipping CLAUDE.md edit."
    fi
  else
    echo "  no CLAUDE.md found; skipping CLAUDE.md edit."
  fi
  for path in "${installed_paths[@]}"; do
    echo "  remove if present: $path"
    if [ "$dry_run" -eq 0 ] && [ -e "$path" ]; then
      rm -rf "$path"
    fi
  done
  restore_hint "$backup"
  echo "Uninstall complete."
  exit 0
fi

snippet="$src/CLAUDE-policy-snippet.md"
backup="$(backup_path "$claudemd")"

echo "Planned asset copy:"
echo "  $src/agents/. -> $claude/agents/"
echo "  $src/commands/. -> $claude/commands/"
echo "  $src/skills/edictum/. -> $claude/skills/edictum/"
if [ -f "$claudemd" ]; then
  echo "Planned CLAUDE.md operation: merge existing EDICTUM block or append a new block."
  echo "  backup: $backup"
else
  echo "Planned CLAUDE.md operation: create $claudemd"
  echo "  initial backup after create: $backup"
fi

if [ "$dry_run" -eq 1 ]; then
  [ -n "$backup" ] && restore_hint "$backup"
  echo "Dry run complete. No files were changed."
  exit 0
fi

mkdir -p "$claude/agents" "$claude/commands" "$claude/skills/edictum"
cp -Rf "$src/agents/." "$claude/agents/"
cp -Rf "$src/commands/." "$claude/commands/"
cp -Rf "$src/skills/edictum/." "$claude/skills/edictum/"
echo "  agents, command, and edictum skill installed."

if [ -f "$claudemd" ]; then
  cp -f "$claudemd" "$backup"
  tmp="$claudemd.tmp.$$"
  strip_block "$claudemd" > "$tmp"
  if [ -s "$tmp" ]; then
    printf '\n\n' >> "$tmp"
  fi
  cat "$snippet" >> "$tmp"
  mv "$tmp" "$claudemd"
  echo "  merged CLAUDE.md (backup: $backup)."
  restore_hint "$backup"
else
  cp -f "$snippet" "$claudemd"
  cp -f "$claudemd" "$backup"
  echo "  created $claudemd with the Edictum block (initial backup: $backup)."
  restore_hint "$backup"
fi

echo
echo "Done. Restart your Claude Code session to load the skill, agents, and command."
