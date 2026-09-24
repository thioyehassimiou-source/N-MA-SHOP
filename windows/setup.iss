; Script Inno Setup pour N'MaShop v1.0.0
; Fichier de configuration d'installeur professionnel Windows
; Gère le remplacement et la désinstallation propre automatique des anciennes versions.

#define MyAppName "N'MaShop"
#ifndef MyAppVersion
#define MyAppVersion "1.2.0"
#endif
#define MyAppPublisher "Hassimiou Thioye Développeur"
#define MyAppURL "https://github.com/thioyehassimiou-source/N-MA-SHOP"
#define MyAppContact "thioyehassimiou@gmail.com"
#define MyAppPhone "+224 624 19 30 69"
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
; Toujours réutiliser le dossier d'installation existant lors d'une mise à jour
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
OutputBaseFilename=NMaShop_Setup_v{#MyAppVersion}

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
; sqlite3.dll — bibliothèque SQLite native obligatoire pour le fonctionnement de la base de données
Source: "sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
; Package de dépendances C++ Microsoft (installation 100% transparente si présent)
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; Installation automatique et silencieuse des dépendances Visual C++ si présentes dans l'installeur
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/q /norestart"; StatusMsg: "Installation automatique des composants système requis (Visual C++)..."; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Suppression complète du dossier d'installation (inclut les fichiers créés après installation : base SQLite, logs, cache)
Type: filesandordirs; Name: "{app}"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
  // En mode mise à jour ou silencieux, continuer directement sans poser de question au client
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if MsgBox('Voulez-vous supprimer toutes vos données locales (bases de données, préférences, configuration) ?' #13#13 'ATTENTION : Cette action est irréversible et entraînera la perte de vos données !', mbConfirmation, MB_YESNO) = idYes then
    begin
      // Chemins réels utilisés par Flutter sur Windows (AppData\Roaming et AppData\Local)
      DelTree(ExpandConstant('{userappdata}\NMaShop'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\NMaShop'), True, True, True);
      DelTree(ExpandConstant('{userappdata}\CJP Hub'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\CJP Hub'), True, True, True);

      // Ancres de sécurité d'essai
      DeleteFile(ExpandConstant('{localappdata}\.sys_device_meta.bin'));
      DeleteFile(ExpandConstant('{userappdata}\.user_state_cache'));
      DeleteFile(ExpandConstant('{userappdata}\.sys_font_registry.bin'));
      DeleteFile(ExpandConstant('{localappdata}\Temp\.nma_sys_sec_alt'));

      // Nettoyage des anciens chemins potentiels (anciennes versions / ancien nom)
      DelTree(ExpandConstant('{userappdata}\com.nmashop\nmashop'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\com.nmashop\nmashop'), True, True, True);
      DelTree(ExpandConstant('{userappdata}\nmashop'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\nmashop'), True, True, True);
      DelTree(ExpandConstant('{userappdata}\gescompta'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\gescompta'), True, True, True);
      DelTree(ExpandConstant('{userappdata}\com.example.nmashop'), True, True, True);
    end;
  end;
end;
