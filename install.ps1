#Requires -Version 5.1
<#
  Edictum installer (Windows / PowerShell).
  Deploys agents, command, and the edictum skill into ~/.claude, and merges the
  always-on policy block into ~/.claude/CLAUDE.md (idempotent, backed up).
#>
$ErrorActionPreference = "Stop"
$repo   = $PSScriptRoot
$claude = Join-Path $env:USERPROFILE ".claude"
$src    = Join-Path $repo "home-claude"

function Test-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

Write-Host "Edictum installer" -ForegroundColor Cyan
Write-Host "  repo: $repo"
Write-Host "  target: $claude`n"

# --- 1. Prerequisite checks (warn, never block) ---
Write-Host "Checking prerequisites..." -ForegroundColor Cyan
$warn = @()
if (-not (Test-Cmd node))   { $warn += "node not found - install Node.js 18+." }
if (-not (Test-Cmd claude)) { $warn += "claude CLI not found - npm i -g @anthropic-ai/claude-code" }
if (-not (Test-Cmd codex))  { $warn += "codex CLI not found - npm i -g @openai/codex; then 'codex login'" }
else {
  try { $login = (& codex login status) 2>&1 | Out-String } catch { $login = "" }
  if ($login -notmatch "Logged in") { $warn += "codex is installed but not logged in - run 'codex login'." }
}
$pluginOk = $false
if (Test-Cmd claude) {
  try { $plugins = (& claude plugin list) 2>&1 | Out-String } catch { $plugins = "" }
  if ($plugins -match "codex@openai-codex") { $pluginOk = $true }
}
if (-not $pluginOk) {
  $warn += "codex-plugin-cc not installed - 'claude plugin marketplace add openai/codex-plugin-cc' then 'claude plugin install codex@openai-codex'"
}
if ($warn.Count) { $warn | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Yellow } }
else { Write-Host "  all prerequisites present." -ForegroundColor Green }

# --- 2. Copy agents / command / skill ---
Write-Host "`nCopying assets into ~/.claude ..." -ForegroundColor Cyan
foreach ($sub in @("agents","commands","skills\edictum")) {
  $dst = Join-Path $claude $sub
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
}
Copy-Item (Join-Path $src "agents\*")  (Join-Path $claude "agents")  -Force
Copy-Item (Join-Path $src "commands\*") (Join-Path $claude "commands") -Force
Copy-Item (Join-Path $src "skills\edictum\*") (Join-Path $claude "skills\edictum") -Recurse -Force
Write-Host "  agents, command, and edictum skill installed." -ForegroundColor Green

# --- 3. Merge the policy block into CLAUDE.md (idempotent, backed up) ---
Write-Host "`nMerging policy block into ~/.claude/CLAUDE.md ..." -ForegroundColor Cyan
$snippet  = (Get-Content (Join-Path $src "CLAUDE-policy-snippet.md") -Raw).TrimEnd()
$claudemd = Join-Path $claude "CLAUDE.md"
$startTag = "<!-- EDICTUM:START"
$endTag   = "<!-- EDICTUM:END -->"

if (Test-Path $claudemd) {
  Copy-Item $claudemd "$claudemd.bak" -Force
  $content = Get-Content $claudemd -Raw
  $si = $content.IndexOf($startTag)
  if ($si -ge 0) {
    $ei = $content.IndexOf($endTag, $si)
    if ($ei -ge 0) {
      $ei += $endTag.Length
      $content = $content.Substring(0, $si) + $snippet + $content.Substring($ei)
    } else { $content = $content.TrimEnd() + "`r`n`r`n" + $snippet + "`r`n" }
  } else { $content = $content.TrimEnd() + "`r`n`r`n" + $snippet + "`r`n" }
  Set-Content -Path $claudemd -Value $content -Encoding UTF8
  Write-Host "  merged (backup: CLAUDE.md.bak)." -ForegroundColor Green
} else {
  Set-Content -Path $claudemd -Value ($snippet + "`r`n") -Encoding UTF8
  Write-Host "  created ~/.claude/CLAUDE.md with the Edictum block." -ForegroundColor Green
}

Write-Host "`nDone. Restart your Claude Code session to load the skill, agents, and command." -ForegroundColor Cyan
if ($warn.Count) { Write-Host "Resolve the [!] items above for full functionality." -ForegroundColor Yellow }
