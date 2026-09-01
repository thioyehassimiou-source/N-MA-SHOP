; Script Inno Setup pour N'MaShop v1.0.0
; Fichier de configuration d'installeur professionnel Windows
; Gère le remplacement et la désinstallation propre automatique des anciennes versions.

#define MyAppName "N'MaShop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "CJP Hub"
#define MyAppURL "https://nmashop.com"
#define MyAppExeName "nmashop.exe"
#define BuildDir "..\build\windows\x64\runner\Release"
#define MyAppId "{E14D254C-A23B-49E8-97F2-ABCD12345678}"

[Setup]
; Identifiant unique de l'application
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\N'MaShop
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallFilesDir={app}

; Fermeture automatique des instances en cours d'exécution
CloseApplications=yes
CloseApplicationsFilter=*.exe
RestartApplications=no

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

[InstallDelete]
; Nettoyage des anciens exécutables et bibliothèques Flutter avant copie
Type: files; Name: "{app}\{#MyAppExeName}"
Type: files; Name: "{app}\*.dll"

[Files]
; Toutes les DLLs, exécutable principal et ressources Flutter
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.zip,*.iss"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Détecte si une ancienne version est déjà installée sur le système et exécute son désinstalleur silencieusement
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstall: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1');
  sUnInstall := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstall) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstall);
  Result := sUnInstall;
end;

function InitializeSetup(): Boolean;
var
  iResultCode: Integer;
  sUnInstall: String;
begin
  Result := True;
  sUnInstall := GetUninstallString();
  if sUnInstall <> '' then
  begin
    sUnInstall := RemoveQuotes(sUnInstall);
    // Désinstallation automatique et silencieuse de l'ancienne version
    Exec(sUnInstall, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, iResultCode);
  end;
end;
