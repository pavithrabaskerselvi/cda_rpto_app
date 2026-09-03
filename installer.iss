#define MyAppName "CDA RPTO"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Chennai Drone Academy"
#define MyAppExeName "cda_rpto_app.exe"

[Setup]
AppId={{CDA-RPTO-APP}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\CDA RPTO
DefaultGroupName=CDA RPTO

OutputDir=installer
OutputBaseFilename=CDA_RPTO_Setup

Compression=lzma
SolidCompression=yes

ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; \
Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\CDA RPTO"; \
Filename: "{app}\cda_rpto_app.exe"

Name: "{group}\CDA RPTO"; \
Filename: "{app}\cda_rpto_app.exe"

[Run]
Filename: "{app}\cda_rpto_app.exe"; \
Description: "Launch CDA RPTO"; \
Flags: nowait postinstall skipifsilent