; Inno Setup Script for The Pong Game!
#define MyAppName "The Pong Game!"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ImJustIvaan"
#define MyAppURL "https://pong.ivaan.cc"
#define MyAppExeName "pong_game.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{5F98A60A-15B7-4D2A-B94A-27E01A4BC18E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\The Pong Game
DefaultGroupName=The Pong Game
AllowNoIcons=yes
OutputDir=..\..\build\windows\installer
OutputBaseFilename=ThePongGame-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Universal architecture support for both x64 and ARM64 systems
ArchitecturesAllowed=x64compatible arm64
ArchitecturesInstallIn64BitMode=x64compatible arm64
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
#if DirExists("..\..\build\windows\arm64\runner\Release")
; If native ARM64 build is present, install ARM64 binaries on ARM64 systems
Source: "..\..\build\windows\arm64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsArm64System
; Install x64 binaries on x64 systems
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsNotArm64System
#else
; Universal deployment (runs natively on x64 and seamlessly on ARM64 Windows 11 via Prism emulation)
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[Icons]
Name: "{autoprograms}\The Pong Game"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\The Pong Game"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function IsArm64System: Boolean;
begin
  Result := IsArm64;
end;

function IsNotArm64System: Boolean;
begin
  Result := not IsArm64;
end;
