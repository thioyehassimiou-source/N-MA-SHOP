; Script Inno Setup pour N'MaShop v1.0.0
; Fichier de configuration d'installeur professionnel Windows (style OBS Studio)

#define MyAppName "N'MaShop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "CJP Hub"
#define MyAppURL "https://nmashop.com"
#define MyAppExeName "nmashop.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant unique de l'application
AppId={{E14D254C-A23B-49E8-97F2-ABCD12345678}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\N'MaShop
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

; Nom et emplacement du fichier d'installation généré
OutputDir=..\build\windows
OutputBaseFilename=NMaShop_Setup_v1.0.0

; Icône de l'installeur (.exe)
SetupIconFile=runner\resources\app_icon.ico

; Intégration du contrat de licence utilisateur (EULA)
LicenseFile=EULA.txt

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Toutes les DLLs, exécutable principal et ressources Flutter
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.zip,*.iss"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
