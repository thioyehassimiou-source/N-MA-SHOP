; Script Inno Setup pour N'MaShop
; Ce fichier doit être compilé avec Inno Setup (https://jrsoftware.org/isinfo.php)
; Assurez-vous d'avoir exécuté "flutter build windows --release" avant de compiler ce script.

#define MyAppName "N'MaShop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "N'MaShop"
#define MyAppURL "https://nmashop.com"
#define MyAppExeName "nmashop.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant unique pour cette application
AppId={{E14D254C-A23B-49E8-97F2-ABCD12345678}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\NMaShop
DisableProgramGroupPage=yes
; Nom et emplacement du fichier d'installation généré
OutputDir=..\build\windows
OutputBaseFilename=NMaShop_Setup_v1.0.0

; Icône de l'installeur (.exe)
SetupIconFile=runner\resources\app_icon.ico

; Intégration des Conditions d'utilisation et Politique de confidentialité
LicenseFile=EULA.txt

; Pour rendre l'installeur très pro avec des images (décommentez et créez les images sur Windows)
;WizardImageFile=Images\setup_bg.bmp
;WizardSmallImageFile=Images\setup_icon.bmp

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; L'exécutable principal
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Toutes les DLLs et les ressources Flutter
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Note: Ne pas utiliser "Flags: ignoreversion" sur des fichiers système partagés.

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
