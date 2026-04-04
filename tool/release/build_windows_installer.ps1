[CmdletBinding()]
param(
    [string]$InnoSetupCompiler,
    [switch]$SkipTests,
    [switch]$SkipFlutterBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDirectory '..\..')).Path
$configPath = Join-Path $scriptDirectory 'windows_release_config.psd1'
$config = Import-PowerShellDataFile -Path $configPath

$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$pubspecContent = Get-Content -Raw -Path $pubspecPath
if ($pubspecContent -notmatch '(?m)^version:\s*([^\s#]+)\s*$') {
    throw "Could not find a pubspec version in $pubspecPath."
}

$appVersion = $Matches[1]
if ($appVersion -match '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
    $versionInfoVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
}
elseif ($appVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $versionInfoVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
}
else {
    throw "Unsupported pubspec version format '$appVersion'. Use semantic versioning with an optional +build suffix."
}

$releaseDirectory = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$installerOutputDirectory = Join-Path $repoRoot 'build\installer'
$innoScriptPath = Join-Path $repoRoot $config.InnoScriptPath

if (-not $SkipTests) {
    Write-Host 'Running flutter test...'
    & flutter test
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter test failed.'
    }
}

if (-not $SkipFlutterBuild) {
    Write-Host 'Building Windows release bundle...'
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter build windows --release failed.'
    }
}

if (-not (Test-Path -Path $releaseDirectory -PathType Container)) {
    throw "Windows release bundle not found at $releaseDirectory."
}

if (-not $InnoSetupCompiler) {
    $compilerCandidates = @(
        $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe' }),
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' })
    ) | Where-Object { $_ -and (Test-Path -Path $_ -PathType Leaf) }

    if ($compilerCandidates.Count -eq 0) {
        throw 'Inno Setup 6 was not found. Install Inno Setup or pass -InnoSetupCompiler <path-to-ISCC.exe>.'
    }

    $InnoSetupCompiler = $compilerCandidates[0]
}

New-Item -ItemType Directory -Force -Path $installerOutputDirectory | Out-Null

$isccArguments = @(
    "/DAppVersion=$appVersion"
    "/DVersionInfoVersion=$versionInfoVersion"
    "/DProductName=$($config.ProductName)"
    "/DPublisher=$($config.Publisher)"
    "/DPublisherDirectoryName=$($config.PublisherDirectoryName)"
    "/DExecutableName=$($config.ExecutableName)"
    "/DInstallerArtifactBaseName=$($config.InstallerArtifactBaseName)"
    "/DInnoAppId=$($config.InnoAppId)"
    "/DWindowsInstallDir=$($config.WindowsInstallDir)"
    "/DWindowsDataDir=$($config.WindowsDataDir)"
    "/DReleaseDir=$releaseDirectory"
    "/DOutputDir=$installerOutputDirectory"
    $innoScriptPath
)

Write-Host "Building installer with $InnoSetupCompiler..."
& $InnoSetupCompiler @isccArguments
if ($LASTEXITCODE -ne 0) {
    throw 'Inno Setup compilation failed.'
}

$installerArtifact = Join-Path $installerOutputDirectory "$($config.InstallerArtifactBaseName)-$appVersion.exe"
if (-not (Test-Path -Path $installerArtifact -PathType Leaf)) {
    throw "Expected installer artifact was not created at $installerArtifact."
}

Write-Host ''
Write-Host "Installer ready: $installerArtifact"
Write-Host "User data directory: $($config.WindowsDataDir)"
