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
; Identifiant unique de l'application (double {{ pour échapper l'accolade ouvrante dans Inno Setup)
AppId={{E14D254C-A23B-49E8-97F2-ABCD12345678}
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

; Fermeture automatique des instances en cours d'exécution avant copie
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
; Nettoyage préalable des anciens exécutables et bibliothèques Flutter avant copie des nouveaux fichiers
Type: files; Name: "{app}\{#MyAppExeName}"
Type: files; Name: "{app}\*.dll"

[Files]
; Toutes les DLLs, exécutable principal et ressources Flutter
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.zip,*.iss"
; Package de dépendances C++ Microsoft pour SQLite (installation 100% transparente)
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\vc_redist.x64.exe')) or FileExists('windows\vc_redist.x64.exe') or FileExists('vc_redist.x64.exe')

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[UninstallDelete]
; Nettoyage des bases de données SQLite, préférences et caches de l'utilisateur lors de la désinstallation
Type: filesandordirs; Name: "{userappdata}\com.nmashop\nmashop"
Type: filesandordirs; Name: "{userappdata}\nmashop"
Type: filesandordirs; Name: "{localappdata}\nmashop"
Type: filesandordirs; Name: "{userappdata}\gescompta"
Type: filesandordirs; Name: "{userappdata}\com.example.nmashop"

[Run]
; Installation automatique et silencieuse des dépendances Visual C++ si présentes dans l'installeur
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/q /norestart"; StatusMsg: "Installation automatique des composants système requis (Visual C++)..."; Flags: waituntilterminated; Check: FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'))
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DelTree(ExpandConstant('{userappdata}\com.nmashop\nmashop'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\nmashop'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\nmashop'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\gescompta'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\com.example.nmashop'), True, True, True);
  end;
end;

