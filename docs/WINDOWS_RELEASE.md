# Windows Internal Release

Clockwork's first production release path is a Windows-only internal installer.

For the main project, product, and architectural context, start with
[PROJECT_GUIDE.md](PROJECT_GUIDE.md).

## Canonical release values

- Product name: `Clockwork`
- Publisher: `Clockwork Software`
- Version source: `pubspec.yaml`
- Windows install directory: `%LocalAppData%\Programs\Clockwork`
- Windows data directory: `%APPDATA%\Clockwork Software\Clockwork`
- Installer artifact: `ClockworkSetup-<version>.exe`

## Prerequisites

- Flutter Windows desktop toolchain
- Visual Studio Build Tools for Flutter Windows builds
- Inno Setup 6

## Build the installer

From the repo root:

```powershell
.\tool\release\build_windows_installer.ps1
```

What the script does:

1. Runs `flutter test`
2. Runs `flutter build windows --release`
3. Packages `build\windows\x64\runner\Release`
4. Produces `build\installer\ClockworkSetup-<version>.exe`

Optional flags:

```powershell
.\tool\release\build_windows_installer.ps1 -SkipTests
.\tool\release\build_windows_installer.ps1 -SkipFlutterBuild
.\tool\release\build_windows_installer.ps1 -InnoSetupCompiler "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
```

## UI verification before packaging

Before packaging a candidate release, review the layout guide and run the
targeted UI checks:

- Shared guide: [UI_DESIGN_GUIDE.md](UI_DESIGN_GUIDE.md)
- Preview run:

```powershell
flutter run -d windows --dart-define=CLOCKWORK_UI_PREVIEW=true
```

- Layout/widget checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\test\run_layout_checks.ps1
```

## Smoke test checklist

Use a clean Windows machine or VM for every candidate release.

1. Install `ClockworkSetup-<version>.exe`
2. Launch Clockwork from the Start Menu
3. Confirm the app opens without missing-file errors
4. Confirm required definitions load on first run
5. Create sample data and restart the app
6. Confirm the data is still present after restart
7. Uninstall Clockwork
8. Confirm the install directory is removed
9. Confirm `%APPDATA%\Clockwork Software\Clockwork` still exists
10. Reinstall the same or newer version and confirm the existing data is reused

## Internal install notes

- The installer is per-user and does not require admin rights.
- Because this release is not code-signed yet, Windows may show a SmartScreen warning.
- If SmartScreen appears, the user can select `More info` and then `Run anyway`.
- Uninstall removes the application binaries and shortcuts, but it does not remove the SQLite data directory.
- Upgrades are manual: run the newer installer on top of the existing installation.

## Out of scope for v1

- Auto-update infrastructure
- Microsoft Store packaging
- Public code-signing certificate integration
- Android, iOS, macOS, Linux, or web production packaging
