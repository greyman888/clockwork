[CmdletBinding()]
param(
  [switch]$Preview
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$logPath = Join-Path $PSScriptRoot 'flutter_run_windows.log'
$runnerPidPath = Join-Path $PSScriptRoot 'flutter_run_windows_runner.pid'
$windowTitle = if ($Preview) {
  'Clockwork Dev Run (Preview)'
} else {
  'Clockwork Dev Run'
}

function Get-TrackedRunnerProcesses {
  Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" |
    Where-Object {
      $commandLine = $_.CommandLine
      $null -ne $commandLine -and
      $commandLine -like "*flutter run -d windows*" -and
      $commandLine -like "*$logPath*"
    }
}

function Stop-TrackedRunnerProcess {
  param([int]$ProcessId)

  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($null -eq $process) {
    return
  }

  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

if (Test-Path $runnerPidPath) {
  $previousRunnerPid = (Get-Content $runnerPidPath -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($previousRunnerPid -match '^\d+$') {
    Stop-TrackedRunnerProcess -ProcessId ([int]$previousRunnerPid)
  }
}

foreach ($runner in Get-TrackedRunnerProcesses) {
  Stop-TrackedRunnerProcess -ProcessId $runner.ProcessId
}

Get-Process Clockwork -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Path -like "$repoRoot\build\windows\x64\runner\Debug\*"
  } |
  Stop-Process -Force -ErrorAction SilentlyContinue

Remove-Item $logPath -Force -ErrorAction SilentlyContinue

$flutterCommand = if ($Preview) {
  'flutter run -d windows --dart-define=CLOCKWORK_UI_PREVIEW=true'
} else {
  'flutter run -d windows'
}

$runnerCommand = @"
Set-Location -LiteralPath '$repoRoot'
`$host.UI.RawUI.WindowTitle = '$windowTitle'
$flutterCommand *>&1 | Tee-Object -FilePath '$logPath'
"@

$process = Start-Process `
  -FilePath powershell `
  -WorkingDirectory $repoRoot `
  -ArgumentList @(
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    $runnerCommand
  ) `
  -PassThru

Set-Content -LiteralPath $runnerPidPath -Value $process.Id

Write-Host "Started $windowTitle."
Write-Host "Runner PID: $($process.Id)"
Write-Host "Log file: $logPath"
