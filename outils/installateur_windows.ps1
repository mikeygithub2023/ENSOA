# Produit l'installateur Windows de SIG ENSOA.
#
#   .\outils\installateur_windows.ps1            compile puis empaquette
#   .\outils\installateur_windows.ps1 -SansBuild empaquette le build existant
#
# Le script trouve ISCC.exe tout seul : Inno Setup s'installe selon les
# machines dans « Program Files » ou dans le profil de l'utilisateur, et la
# version installée change au fil des mises à jour.

param([switch]$SansBuild)

$ErrorActionPreference = 'Stop'
$racine = Split-Path -Parent $PSScriptRoot
Set-Location $racine

if (-not $SansBuild) {
  Write-Host 'Compilation de la version Windows...'
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'La compilation Flutter a échoué.' }
}

$release = Join-Path $racine 'build\windows\x64\runner\Release\sig_ensoa.exe'
if (-not (Test-Path $release)) {
  throw "Aucune version compilée : lancez le script sans -SansBuild."
}

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
& $iscc (Join-Path $racine 'windows\installateur\sig_ensoa.iss')
if ($LASTEXITCODE -ne 0) { throw "L'empaquetage a échoué." }

$sortie = Get-ChildItem (Join-Path $racine 'build\installateur') -Filter '*.exe' |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
$mo = [math]::Round($sortie.Length / 1MB, 1)
Write-Host ''
Write-Host "Installateur : $($sortie.FullName)  ($mo Mo)"
