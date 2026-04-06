[CmdletBinding()]
param(
    [string[]]$Tests = @(
        "test\ui_layout_test.dart",
        "test\week_page_test.dart"
    )
)

$repoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
$cleanupTargets = @(
    (Join-Path $repoRoot "build\unit_test_assets"),
    (Join-Path $repoRoot "build\native_assets")
)

foreach ($target in $cleanupTargets) {
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

Push-Location $repoRoot
try {
    & flutter test @Tests
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
