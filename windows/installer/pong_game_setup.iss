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
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\The Pong Game"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\The Pong Game"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
