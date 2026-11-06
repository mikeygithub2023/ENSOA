; Installateur de SIG ENSOA pour le bureau (Windows).
;
; Il installe la petite application qui ouvre la PWA dans sa propre fenêtre
; (voir FenetrePrincipale.cs). Il reprend l'identifiant de l'ancien
; installateur de l'application Flutter : sur un poste qui l'avait, il la
; remplace — même dossier, mêmes raccourcis — et en efface les fichiers
; devenus inutiles.
;
; Compilation : outils\installateur_bureau.ps1

#define MonNom "SIG ENSOA"
#define MonEditeur "Ecole Nationale des Sous-Officiers d'Active"
#define MonExe "sig_ensoa.exe"
#define MaVersion "2.1.0"

[Setup]
; Le même AppId que l'installateur de l'application Flutter : c'est ce qui
; fait du nouveau une mise à jour de l'ancien.
AppId={{7A3C1E56-9B42-4D18-A5F1-2C8E6B0D7439}
AppName={#MonNom}
AppVersion={#MaVersion}
AppVerName={#MonNom} {#MaVersion}
AppPublisher={#MonEditeur}
DefaultDirName={autopf}\{#MonNom}
DefaultGroupName={#MonNom}
OutputDir=..\build\installateur
OutputBaseFilename=SIG-ENSOA-{#MaVersion}-bureau
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MonExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; Par utilisateur, sans mot de passe administrateur — comme l'ancien.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; L'application en cours d'exécution est fermée avant d'être remplacée.
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[InstallDelete]
; Les restes de l'application Flutter : son dossier de données et ses
; bibliothèques. Les DLL dont la nouvelle a besoin sont recopiées ensuite.
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\*.dll"

[Files]
Source: "bin\Release\net48\{#MonExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "bin\Release\net48\{#MonExe}.config"; DestDir: "{app}"; Flags: ignoreversion
Source: "bin\Release\net48\Microsoft.Web.WebView2.Core.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "bin\Release\net48\Microsoft.Web.WebView2.WinForms.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "bin\Release\net48\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MonNom}"; Filename: "{app}\{#MonExe}"
Name: "{group}\Désinstaller {#MonNom}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MonNom}"; Filename: "{app}\{#MonExe}"; Tasks: bureau

[UninstallDelete]
; Le cache de l'application et la session, propres à ce poste.
Type: filesandordirs; Name: "{localappdata}\SIG ENSOA"

[Run]
Filename: "{app}\{#MonExe}"; Description: "Lancer {#MonNom}"; \
  Flags: nowait postinstall skipifsilent
