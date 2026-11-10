# Produit l'installateur de SIG ENSOA pour le bureau (Windows) : la petite
# application qui ouvre la PWA dans sa propre fenêtre (dossier windows-pwa).
#
#   .\outils\installateur_bureau.ps1
#
# Comme installateur_windows.ps1, le script trouve ISCC.exe tout seul.

$ErrorActionPreference = 'Stop'
$racine = Split-Path -Parent $PSScriptRoot
$projet = Join-Path $racine 'windows-pwa'

Write-Host 'Compilation de l''application de bureau...'
dotnet build (Join-Path $projet 'SigEnsoa.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'La compilation a échoué.' }

$candidats = @(
  "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $candidats | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
  throw "Inno Setup est introuvable. Installez-le : winget install JRSoftware.InnoSetup"
}

Write-Host "Empaquetage avec $iscc"
& $iscc (Join-Path $projet 'installateur.iss')
if ($LASTEXITCODE -ne 0) { throw "L'empaquetage a échoué." }

$sortie = Get-ChildItem (Join-Path $racine 'build\installateur') -Filter '*-bureau.exe' |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
$ko = [math]::Round($sortie.Length / 1KB)
Write-Host ''
Write-Host "Installateur : $($sortie.FullName)  ($ko Ko)"
