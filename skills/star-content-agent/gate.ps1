# Star-content-agent gate (Windows). Same usage, rules and exit codes as gate.sh.
# ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less scripts in the system code page.
# Data dir is fixed: %USERPROFILE%\star-content-agent (or $env:STAR_CONTENT_AGENT_HOME), wherever this script is installed.
# Call it like this:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "<data dir>\skill\gate.ps1" <platform> <subcommand> [args...]
#   e.g. ... gate.ps1 xhs open "https://..." --session sca-fav
#   ... gate.ps1 <platform> pace | pause <platform> <reason> | unpause <platform> | lock <run_id> [--take-stale] | unlock <run_id> | status
# Exit codes: 0 ok; 10 STOP file present; 11 platform paused; 12 daily request cap reached; 13 not allowed;
#             14 usage error; 15 another run holds the lock; 16 still waiting: run the exact same command again
# NOTE: not yet run on a real Windows machine. If the self-test in setup.md fails, fix this file
#       without relaxing any rule (gap, allowlist, pause, cap), or follow the feedback section in SKILL.md.

$ErrorActionPreference = 'Stop'
$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Data = if ($env:STAR_CONTENT_AGENT_HOME) { $env:STAR_CONTENT_AGENT_HOME } else { Join-Path $env:USERPROFILE 'star-content-agent' }
$G = Join-Path $Data 'gate'
$Tmp = Join-Path $Data 'tmp'
New-Item -ItemType Directory -Force -Path $G, $Tmp | Out-Null

$MinGap = 45; $MaxGap = 60; $ActionGap = 2; $PauseHours = 20; $DefaultLimit = 80
$Utf8 = New-Object System.Text.UTF8Encoding $false

function Now { [DateTimeOffset]::Now.ToUnixTimeSeconds() }
function Say([string]$m) { [Console]::Error.WriteLine('[gate] ' + $m) }
function ReadText([string]$p, $def) { if (Test-Path -LiteralPath $p) { ([IO.File]::ReadAllText($p)).Trim() } else { $def } }
function WriteText([string]$p, $s) { [IO.File]::WriteAllText($p, [string]$s, $Utf8) }
function Log([string]$m) { [IO.File]::AppendAllText((Join-Path $Data 'requests.log'), ((Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz') + ' ' + $m + "`n"), $Utf8) }
function Fmt($ts) { [DateTimeOffset]::FromUnixTimeSeconds([int64]$ts).ToLocalTime().ToString('MM-dd HH:mm') }
function Today { Get-Date -Format 'yyyyMMdd' }

$MaxWait = [int](ReadText (Join-Path $G 'max-wait') 55)
$A = @($args)
if ($A.Count -lt 1) { Say 'usage: see the top of this file'; exit 14 }
$LockDir = Join-Path $G 'lock'
$Owner = Join-Path $LockDir 'owner'

# ---- management commands ----
if ($A[0] -eq 'lock') {
  if ($A.Count -lt 2) { exit 14 }
  try { New-Item -ItemType Directory -Path $LockDir | Out-Null; WriteText $Owner ($A[1] + ' ' + (Now)); Say ('locked: ' + $A[1]); exit 0 } catch {}
  $parts = (ReadText $Owner '? 0').Split(' ')
  $age = (Now) - [int64]$parts[1]
  if ($A.Count -ge 3 -and $A[2] -eq '--take-stale' -and $age -gt 10800) { WriteText $Owner ($A[1] + ' ' + (Now)); Say ('took over a stale lock from ' + $parts[0] + ', ' + $age + 's old'); exit 0 }
  Say ('another run (' + $parts[0] + ') started ' + $age + 's ago and has not finished'); exit 15
}
if ($A[0] -eq 'unlock') {
  if ($A.Count -lt 2) { exit 14 }
  $o = (ReadText $Owner '').Split(' ')[0]
  if ($o -eq $A[1]) { Remove-Item -LiteralPath $LockDir -Recurse -Force; Say ('unlocked: ' + $A[1]); exit 0 }
  Say ('the lock does not belong to ' + $A[1]); exit 14
}
if ($A[0] -eq 'pause') {
  if ($A.Count -lt 3) { exit 14 }
  $until = (Now) + $PauseHours * 3600
  $reason = ($A[2..($A.Count - 1)] -join ' ')
  WriteText (Join-Path $G ('pause.' + $A[1])) ([string]$until + ' ' + $reason)
  Log ($A[1] + ' pause ' + $reason); Say ($A[1] + ' paused until ' + (Fmt $until)); exit 0
}
if ($A[0] -eq 'unpause') {
  if ($A.Count -lt 2) { exit 14 }
  Remove-Item -LiteralPath (Join-Path $G ('pause.' + $A[1])) -ErrorAction SilentlyContinue
  Log ($A[1] + ' unpause'); Say ($A[1] + ' unpaused'); exit 0
}
if ($A[0] -eq 'status') {
  if (Test-Path -LiteralPath (Join-Path $Data 'STOP')) { 'STOP: on (STOP file in the data dir)' }
  if (Test-Path -LiteralPath $LockDir) { 'lock: ' + (ReadText $Owner '') }
  Get-ChildItem -LiteralPath $G -Filter 'pause.*' -ErrorAction SilentlyContinue | ForEach-Object {
    $u, $r = (ReadText $_.FullName '0').Split(' ', 2)
    $p = $_.Name.Substring(6)
    if ([int64]$u -gt (Now)) { $p + ' paused until ' + (Fmt $u) + ': ' + $r } else { $p + ' pause expired' }
  }
  Get-ChildItem -LiteralPath $G -Filter ('count.*.' + (Today)) -ErrorAction SilentlyContinue | ForEach-Object {
    $_.Name.Split('.')[1] + ' requests today: ' + (ReadText $_.FullName '0')
  }
  exit 0
}

# ---- platform commands ----
if ($A.Count -lt 2) { exit 14 }
$P = $A[0]; $Sub = $A[1]
$Rest = @(); if ($A.Count -gt 2) { $Rest = @($A[2..($A.Count - 1)]) }
if ($P -notmatch '^[a-z0-9-]+$') { Say 'platform name: lowercase letters, digits and dashes only'; exit 14 }
# close is only cleanup (closing our own tab), so it is allowed even under STOP or a pause
if ($Sub -ne 'close') {
  if (Test-Path -LiteralPath (Join-Path $Data 'STOP')) { Say 'STOP file present, not touching any platform'; exit 10 }
  $pf = Join-Path $G ('pause.' + $P)
  if (Test-Path -LiteralPath $pf) {
    $u, $r = (ReadText $pf '0').Split(' ', 2)
    if ([int64]$u -gt (Now)) { Say ($P + ' is paused until ' + (Fmt $u) + ': ' + $r); exit 11 }
  }
}

if (@('open', 'scroll', 'pace') -contains $Sub) { $Kind = 'request' }
elseif (@('click', 'eval', 'screenshot') -contains $Sub) { $Kind = 'action' }
elseif (@('state', 'find', 'get', 'extract', 'network', 'close', 'frames') -contains $Sub) { $Kind = 'free' }
elseif ($Sub -eq 'wait') {
  if ($Rest.Count -ge 1 -and $Rest[0] -eq 'time') { Say 'do not use "wait time" for pacing (it returns as soon as the page is quiet); the gate paces requests'; exit 13 }
  $Kind = 'free'
}
else { Say ('subcommand not allowed: ' + $Sub); exit 13 }

$joined = ' ' + ($Rest -join ' ') + ' '
if ($Sub -ne 'pace' -and $joined -notlike '* --session sca-*') { Say 'a --session whose name starts with sca- is required'; exit 14 }

if ($Sub -eq 'eval') {
  $name = if ($Rest.Count -ge 1) { [string]$Rest[0] } else { '' }
  if ($name -notmatch '^@[a-z-]+$') { Say 'eval only runs @script names from skill\js\'; exit 13 }
  $js = Join-Path (Join-Path $SkillDir 'js') ($name.Substring(1) + '.js')
  if (-not (Test-Path -LiteralPath $js)) { Say ('no such script: ' + $name); exit 13 }
  $arg = '0'; $after = @()
  if ($Rest.Count -ge 2 -and -not ([string]$Rest[1]).StartsWith('--')) { $arg = [string]$Rest[1]; if ($Rest.Count -gt 2) { $after = @($Rest[2..($Rest.Count - 1)]) } }
  elseif ($Rest.Count -ge 2) { $after = @($Rest[1..($Rest.Count - 1)]) }
  if ($arg -notmatch '^[0-9.]+$') { Say 'eval argument must be a number'; exit 14 }
  # One line, comments removed: the js files use only /* */ comments and no double quotes,
  # so the code survives being passed through opencli.cmd.
  $code = ([IO.File]::ReadAllText($js)).Replace('__ARG__', $arg) -replace '/\*.*?\*/', '' -replace '\s*\r?\n\s*', ' '
  $Rest = @($code) + $after
}

if ($Sub -eq 'screenshot') {
  $first = if ($Rest.Count -ge 1) { [string]$Rest[0] } else { '' }
  if (-not ($first.StartsWith($Tmp + '\') -and $first.EndsWith('.png'))) { Say ('screenshot path must be the first argument, like ' + $Tmp + '\<name>.png'); exit 14 }
}

if ($Kind -eq 'request') {
  $cf = Join-Path $G ('count.' + $P + '.' + (Today))
  $c = [int](ReadText $cf 0)
  $limit = [int](ReadText (Join-Path $G ('limit.' + $P)) $DefaultLimit)
  if ($c -ge $limit) { Say ($P + ': ' + $c + ' requests today, cap is ' + $limit + '; leave the rest for tomorrow'); exit 12 }
  $last = [int64](ReadText (Join-Path $G ('last.' + $P)) 0)
  $gf = Join-Path $G ('gap.' + $P)
  $gap = [int](ReadText $gf (Get-Random -Minimum $MinGap -Maximum ($MaxGap + 1)))
  WriteText $gf $gap
  $remain = $last + $gap - (Now)
  if ($remain -gt $MaxWait) { Start-Sleep -Seconds $MaxWait; Say ('still ' + ($remain - $MaxWait) + 's to wait: run the exact same command again'); exit 16 }
  if ($remain -gt 0) { Start-Sleep -Seconds $remain }
  WriteText (Join-Path $G ('last.' + $P)) (Now); Remove-Item -LiteralPath $gf -ErrorAction SilentlyContinue
  WriteText $cf ($c + 1)
}
elseif ($Kind -eq 'action') {
  $af = Join-Path $G ('action.' + $P)
  $r2 = [int64](ReadText $af 0) + $ActionGap - (Now)
  if ($r2 -gt 0) { Start-Sleep -Seconds $r2 }
  WriteText $af (Now)
}
Log ($P + ' ' + $Sub + ' ' + $Kind)
if ($Sub -eq 'pace') { exit 0 }

$oc = ReadText (Join-Path $G 'opencli-path') ''
if (-not $oc) {
  $cmd = Get-Command 'opencli.cmd' -ErrorAction SilentlyContinue
  if (-not $cmd) { $cmd = Get-Command 'opencli' -ErrorAction SilentlyContinue }
  if ($cmd) { $oc = $cmd.Source }
}
if (-not $oc) { Say ('opencli not found; write its full path into ' + (Join-Path $G 'opencli-path')); exit 14 }

$env:OPENCLI_CACHE_DIR = Join-Path $Tmp 'opencli-cache'
$env:OPENCLI_WINDOW = 'background'
$env:OPENCLI_BROWSER_IDLE_TIMEOUT = '600'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$extra = @()
if ($joined -notlike '* --window *') { $extra += @('--window', 'background') }
$prof = ReadText (Join-Path $G 'profile') ''
if ($prof -and $joined -notlike '* --profile *') { $extra += @('--profile', $prof) }

$ErrorActionPreference = 'Continue'
if ($Sub -eq 'close') {
  $env:OPENCLI_CLOSE_OWNED_TAB = '1'
  & $oc browser close @Rest @extra
  if ($LASTEXITCODE -eq 0) { exit 0 }
  $env:OPENCLI_CLOSE_OWNED_TAB = '0'
  & $oc browser close @Rest @extra
  exit $LASTEXITCODE
}
& $oc browser $Sub @Rest @extra
exit $LASTEXITCODE
