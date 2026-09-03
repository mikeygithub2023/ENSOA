; Installateur Windows de SIG ENSOA.
;
; `flutter build windows` ne produit pas une application installable : il
; laisse un dossier « Release » où l'exécutable ne vaut rien sans les vingt
; DLL et le dossier `data` qui l'accompagnent. Copier ce dossier à la main sur
; chaque poste marche, mais rien n'annonce alors la version installée, rien ne
; crée le raccourci, et rien ne se désinstalle proprement.
;
; Ce script empaquette l'ensemble dans un unique `setup.exe`.
;
; Compilation :
;   "C:\Program Files\Inno Setup 7\ISCC.exe" windows\installateur\sig_ensoa.iss
; ou, plus simplement :
;   outils\installateur_windows.ps1

#define MonNom "SIG ENSOA"
#define MonEditeur "Ecole Nationale des Sous-Officiers d'Active"
#define MonExe "sig_ensoa.exe"
#define MaVersion "1.0.0"

[Setup]
AppId={{7A3C1E56-9B42-4D18-A5F1-2C8E6B0D7439}
AppName={#MonNom}
AppVersion={#MaVersion}
AppVerName={#MonNom} {#MaVersion}
AppPublisher={#MonEditeur}
DefaultDirName={autopf}\{#MonNom}
DefaultGroupName={#MonNom}
OutputDir=..\..\build\installateur
OutputBaseFilename=SIG-ENSOA-{#MaVersion}-installateur
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MonExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; L'installation par utilisateur n'exige pas de mot de passe administrateur.
; Sur les postes de l'école, celui qui installe n'est pas toujours celui qui
; détient ce mot de passe ; exiger l'élévation bloquerait le déploiement.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; L'application est en 64 bits : la proposer sur un Windows 32 bits
; produirait une installation qui ne démarre pas.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
; Tout le contenu du dossier Release, DLL et données comprises. Les fichiers
; de l'éditeur de liens (.exp, .lib) et le manifeste des ressources natives
; ne servent qu'à la compilation : les embarquer alourdirait l'installateur
; sans rien apporter au poste.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
  Excludes: "*.exp,*.lib,native_assets.json"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MonNom}"; Filename: "{app}\{#MonExe}"
Name: "{group}\Désinstaller {#MonNom}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MonNom}"; Filename: "{app}\{#MonExe}"; Tasks: bureau

[Run]
Filename: "{app}\{#MonExe}"; Description: "Lancer {#MonNom}"; \
  Flags: nowait postinstall skipifsilent
