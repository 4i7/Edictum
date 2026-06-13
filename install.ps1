#Requires -Version 5.1
<#
  Edictum installer (Windows / PowerShell).
  Deploys agents, command, and the edictum skill into ~/.claude, and merges the
  always-on policy block into ~/.claude/CLAUDE.md (idempotent, backed up).
#>
$ErrorActionPreference = "Stop"

$repo = $PSScriptRoot
$src = Join-Path $repo "home-claude"
$dryRun = $false
$force = $false
$uninstall = $false
$projectOnly = $null

function Show-Usage {
  Write-Host @"
Usage: ./install.ps1 [--dry-run] [--force] [--project-only <path>] [--uninstall]

Options:
  --dry-run              Print planned actions without creating, copying, writing, or deleting.
  --force                Continue installation even when required prerequisites are missing.
  --project-only <path>  Install into <path>/.claude instead of the global ~/.claude.
  --uninstall            Remove only Edictum-installed files and the Edictum CLAUDE.md block.
  -h, --help             Show this help.
"@
}

for ($i = 0; $i -lt $args.Count; $i++) {
  switch ($args[$i]) {
    "--dry-run" { $dryRun = $true }
    "--force" { $force = $true }
    "--uninstall" { $uninstall = $true }
    "--project-only" {
      $i++
      if ($i -ge $args.Count) { throw "--project-only requires a path." }
      $projectOnly = $args[$i]
    }
    "-h" { Show-Usage; exit 0 }
    "--help" { Show-Usage; exit 0 }
    default { throw "Unknown argument: $($args[$i])" }
  }
}

if ($projectOnly) {
  $projectPath = [System.IO.Path]::GetFullPath($projectOnly)
  if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
    throw "--project-only path does not exist: $projectPath"
  }
  $claude = Join-Path $projectPath ".claude"
} else {
  $claude = Join-Path $env:USERPROFILE ".claude"
}

$claudemd = Join-Path $claude "CLAUDE.md"
$startTag = "<!-- EDICTUM:START"
$endTag = "<!-- EDICTUM:END -->"
$installedPaths = @(
  (Join-Path $claude "agents\spec-builder.md"),
  (Join-Path $claude "agents\acceptance-checker.md"),
  (Join-Path $claude "agents\pipeline-runner.md"),
  (Join-Path $claude "commands\delegate.md"),
  (Join-Path $claude "skills\edictum")
)

function Test-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function New-BackupPath($path) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $candidate = "$path.bak.$stamp"
  $n = 1
  while (Test-Path -LiteralPath $candidate) {
    $candidate = "$path.bak.$stamp.$n"
    $n++
  }
  return $candidate
}

function Get-LineNumber($content, $index) {
  if ($index -le 0) { return 1 }
  return (($content.Substring(0, $index) -split "`n").Count)
}

function Get-MarkerInfo($content, $path) {
  $pos = 0
  $openStart = -1
  $block = $null

  while ($pos -lt $content.Length) {
    $nextStart = $content.IndexOf($startTag, $pos)
    $nextEnd = $content.IndexOf($endTag, $pos)
    if ($nextStart -lt 0 -and $nextEnd -lt 0) { break }

    if ($nextEnd -ge 0 -and ($nextStart -lt 0 -or $nextEnd -lt $nextStart)) {
      if ($openStart -lt 0) {
        $line = Get-LineNumber $content $nextEnd
        return @{ Issue = "Found $endTag in $path near line $line without a preceding $startTag. Manually repair the marker block before re-running." }
      }
      $endIndex = $nextEnd + $endTag.Length
      if ($block) {
        $line = Get-LineNumber $content $openStart
        return @{ Issue = "Found multiple EDICTUM blocks in $path near line $line. Manually repair the marker blocks before re-running." }
      }
      $block = @{ Start = $openStart; End = $endIndex }
      $openStart = -1
      $pos = $endIndex
      continue
    }

    if ($openStart -ge 0) {
      $line = Get-LineNumber $content $nextStart
      return @{ Issue = "Found nested $startTag in $path near line $line before $endTag. Manually repair the marker block before re-running." }
    }
    if ($block) {
      $line = Get-LineNumber $content $nextStart
      return @{ Issue = "Found multiple EDICTUM blocks in $path near line $line. Manually repair the marker blocks before re-running." }
    }
    $openStart = $nextStart
    $pos = $nextStart + $startTag.Length
  }

  if ($openStart -ge 0) {
    $line = Get-LineNumber $content $openStart
    return @{ Issue = "Found $startTag in $path near line $line, but $endTag was not found. Manually repair the marker block before re-running." }
  }
  if ($block) { return @{ Issue = $null; HasBlock = $true; Start = $block.Start; End = $block.End } }
  return @{ Issue = $null; HasBlock = $false }
}

function Get-MarkerIssue($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $content = Get-Content -LiteralPath $path -Raw
  return (Get-MarkerInfo $content $path).Issue
}

function Remove-EdictumBlock($content) {
  $info = Get-MarkerInfo $content "CLAUDE.md"
  if ($info.Issue) { throw $info.Issue }
  if (-not $info.HasBlock) { return $content }
  return ($content.Substring(0, $info.Start) + $content.Substring($info.End)).TrimEnd() + "`r`n"
}

function Merge-EdictumBlock($content, $snippet) {
  $info = Get-MarkerInfo $content "CLAUDE.md"
  if ($info.Issue) { throw $info.Issue }
  if ($info.HasBlock) {
    return $content.Substring(0, $info.Start) + $snippet + $content.Substring($info.End)
  }
  return $content.TrimEnd() + "`r`n`r`n" + $snippet + "`r`n"
}

function Check-Prerequisites($skipExternalStatus) {
  $required = @()
  $warn = @()

  if (-not (Test-Cmd node)) { $required += "node not found - install Node.js 18+." }
  if (-not (Test-Cmd claude)) { $required += "claude CLI not found - npm i -g @anthropic-ai/claude-code" }
  if (-not (Test-Cmd codex)) {
    $required += "codex CLI not found - npm i -g @openai/codex; then 'codex login'"
  } elseif ($skipExternalStatus) {
    $warn += "codex login status not checked during --dry-run to avoid writing CLI state."
  } else {
    try { $login = (& codex login status) 2>&1 | Out-String } catch { $login = "" }
    if ($login -notmatch "Logged in") { $warn += "codex is installed but not logged in - run 'codex login'." }
  }

  $pluginOk = $false
  if ($skipExternalStatus -and (Test-Cmd claude)) {
    $pluginOk = $true
    $warn += "codex-plugin-cc status not checked during --dry-run to avoid writing CLI state."
  } elseif (Test-Cmd claude) {
    try { $plugins = (& claude plugin list) 2>&1 | Out-String } catch { $plugins = "" }
    if ($plugins -match "codex@openai-codex") { $pluginOk = $true }
  }
  if (-not $pluginOk) {
    $required += "codex-plugin-cc not installed - 'claude plugin marketplace add openai/codex-plugin-cc' then 'claude plugin install codex@openai-codex'"
  }

  return @{ Required = $required; Warn = $warn }
}

function Write-BackupRestoreHint($backupPath) {
  if ($backupPath) {
    Write-Host "  restore with: Copy-Item -LiteralPath `"$backupPath`" -Destination `"$claudemd`" -Force" -ForegroundColor Yellow
  } else {
    Write-Host "  restore example: Copy-Item -LiteralPath `"$claudemd.bak.<timestamp>`" -Destination `"$claudemd`" -Force" -ForegroundColor Yellow
  }
}

Write-Host "Edictum installer" -ForegroundColor Cyan
Write-Host "  repo: $repo"
Write-Host "  target: $claude"
if ($dryRun) { Write-Host "  mode: dry-run (no filesystem changes)" -ForegroundColor Yellow }
if ($uninstall) { Write-Host "  action: uninstall" -ForegroundColor Yellow }
Write-Host ""

if (-not $uninstall) {
  Write-Host "Checking prerequisites..." -ForegroundColor Cyan
  $checks = Check-Prerequisites $dryRun
  if ($checks.Required.Count) {
    $checks.Required | ForEach-Object { Write-Host "  [required missing] $_" -ForegroundColor Yellow }
  } else {
    Write-Host "  all required prerequisites present." -ForegroundColor Green
  }
  if ($checks.Warn.Count) { $checks.Warn | ForEach-Object { Write-Host "  [warn] $_" -ForegroundColor Yellow } }
  if ($checks.Required.Count -and -not $force) {
    Write-Host "Required prerequisites are missing. No files were changed. Re-run with --force to continue anyway." -ForegroundColor Red
    exit 1
  }
}

$markerIssue = Get-MarkerIssue $claudemd
if ($markerIssue) {
  Write-Host $markerIssue -ForegroundColor Red
  Write-Host "No files were changed." -ForegroundColor Red
  exit 1
}

if ($uninstall) {
  Write-Host "Uninstalling Edictum from $claude ..." -ForegroundColor Cyan
  $backupPath = $null
  if (Test-Path -LiteralPath $claudemd) {
    $content = Get-Content -LiteralPath $claudemd -Raw
    if ($content.IndexOf($startTag) -ge 0) {
      $backupPath = New-BackupPath $claudemd
      Write-Host "  remove EDICTUM block from $claudemd"
      Write-Host "  backup: $backupPath"
      if (-not $dryRun) {
        Copy-Item -LiteralPath $claudemd -Destination $backupPath
        Set-Content -LiteralPath $claudemd -Value (Remove-EdictumBlock $content) -Encoding UTF8
      }
    } else {
      Write-Host "  no EDICTUM block found in $claudemd; skipping CLAUDE.md edit."
    }
  } else {
    Write-Host "  no CLAUDE.md found; skipping CLAUDE.md edit."
  }
  foreach ($path in $installedPaths) {
    Write-Host "  remove if present: $path"
    if (-not $dryRun -and (Test-Path -LiteralPath $path)) {
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
  Write-BackupRestoreHint $backupPath
  Write-Host "Uninstall complete." -ForegroundColor Cyan
  exit 0
}

$snippet = (Get-Content -LiteralPath (Join-Path $src "CLAUDE-policy-snippet.md") -Raw).TrimEnd()
$backup = New-BackupPath $claudemd

Write-Host "Planned asset copy:" -ForegroundColor Cyan
Write-Host "  $($src)\agents\* -> $(Join-Path $claude "agents")"
Write-Host "  $($src)\commands\* -> $(Join-Path $claude "commands")"
Write-Host "  $($src)\skills\edictum\* -> $(Join-Path $claude "skills\edictum")"
if (Test-Path -LiteralPath $claudemd) {
  Write-Host "Planned CLAUDE.md operation: merge existing EDICTUM block or append a new block."
  Write-Host "  backup: $backup"
} else {
  Write-Host "Planned CLAUDE.md operation: create $claudemd"
  Write-Host "  initial backup after create: $backup"
}

if ($dryRun) {
  if ($backup) { Write-BackupRestoreHint $backup }
  Write-Host "Dry run complete. No files were changed." -ForegroundColor Cyan
  exit 0
}

foreach ($sub in @("agents", "commands", "skills\edictum")) {
  New-Item -ItemType Directory -Force -Path (Join-Path $claude $sub) | Out-Null
}
Copy-Item (Join-Path $src "agents\*") (Join-Path $claude "agents") -Force
Copy-Item (Join-Path $src "commands\*") (Join-Path $claude "commands") -Force
Copy-Item (Join-Path $src "skills\edictum\*") (Join-Path $claude "skills\edictum") -Recurse -Force
Write-Host "  agents, command, and edictum skill installed." -ForegroundColor Green

if (Test-Path -LiteralPath $claudemd) {
  Copy-Item -LiteralPath $claudemd -Destination $backup
  $content = Get-Content -LiteralPath $claudemd -Raw
  Set-Content -LiteralPath $claudemd -Value (Merge-EdictumBlock $content $snippet) -Encoding UTF8
  Write-Host "  merged CLAUDE.md (backup: $backup)." -ForegroundColor Green
  Write-BackupRestoreHint $backup
} else {
  Set-Content -LiteralPath $claudemd -Value ($snippet + "`r`n") -Encoding UTF8
  Copy-Item -LiteralPath $claudemd -Destination $backup
  Write-Host "  created $claudemd with the Edictum block (initial backup: $backup)." -ForegroundColor Green
  Write-BackupRestoreHint $backup
}

Write-Host "`nDone. Restart your Claude Code session to load the skill, agents, and command." -ForegroundColor Cyan
