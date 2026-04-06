#ifndef AppVersion
  #error AppVersion define is required.
#endif
#ifndef VersionInfoVersion
  #error VersionInfoVersion define is required.
#endif
#ifndef ProductName
  #error ProductName define is required.
#endif
#ifndef Publisher
  #error Publisher define is required.
#endif
#ifndef ExecutableName
  #error ExecutableName define is required.
#endif
#ifndef InstallerArtifactBaseName
  #error InstallerArtifactBaseName define is required.
#endif
#ifndef InstallerArtifactVersion
  #error InstallerArtifactVersion define is required.
#endif
#ifndef InnoAppId
  #error InnoAppId define is required.
#endif
#ifndef WindowsInstallDir
  #error WindowsInstallDir define is required.
#endif
#ifndef WindowsDataDir
  #error WindowsDataDir define is required.
#endif
#ifndef ReleaseDir
  #error ReleaseDir define is required.
#endif
#ifndef OutputDir
  #error OutputDir define is required.
#endif

[Setup]
AppId={#InnoAppId}
AppName={#ProductName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
AppComments=User data is stored under {#WindowsDataDir} and is preserved on uninstall.
DefaultDirName={#WindowsInstallDir}
DefaultGroupName={#ProductName}
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename={#InstallerArtifactBaseName}-{#InstallerArtifactVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#ExecutableName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#VersionInfoVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#ProductName}"; Filename: "{app}\{#ExecutableName}"
Name: "{group}\Uninstall {#ProductName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#ExecutableName}"; Description: "Launch {#ProductName}"; Flags: nowait postinstall skipifsilent
