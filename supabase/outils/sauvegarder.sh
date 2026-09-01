#!/usr/bin/env bash
# ============================================================================
# Sauvegarde les deux bases d'origine.
#
# À lancer DANS GIT BASH (« C:\Program Files\Git\bin\bash.exe »), pas dans
# PowerShell : bash n'y est pas dans le PATH.
#
#   cd "/c/Mes Projets/SIG ENSOA/ENSOA UNIFIE"
#   bash supabase/outils/sauvegarder.sh
#
# QUAND : avant la bascule finale, pas avant de commencer. L'installation de
# la base unifiée ne détruit rien — elle ajoute trois schémas à côté de
# l'existant. Ce script sert au moment où on décide de couper l'ancien.
#
# PRÉREQUIS : pg_dump 17. `supabase db dump` passe par Docker Desktop, qui
# n'est pas installé ici — on appelle donc pg_dump directement, avec le script
# que la CLI génère elle-même (--dry-run), ce qui garde ses réglages exacts.
#
#   winget install -e --id PostgreSQL.PostgreSQL.17
#
# Le mot de passe est demandé à l'écran, sans écho. Il n'est écrit dans aucun
# fichier et n'apparaît pas dans l'historique du shell.
# ============================================================================
set -euo pipefail

racine="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$racine"   # la CLI cherche supabase/config.toml depuis le dossier courant

command -v pg_dump >/dev/null 2>&1 || {
  echo "pg_dump introuvable." >&2
  echo "Installe les outils client PostgreSQL 17, puis rouvre le terminal :" >&2
  echo "  winget install -e --id PostgreSQL.PostgreSQL.17" >&2
  echo "(ajoute C:\Program Files\PostgreSQL\17\bin au PATH si besoin)" >&2
  exit 1
}

dossier="$racine/sauvegardes/$(date +%Y-%m-%d)"
mkdir -p "$dossier"

read -r -s -p "Mot de passe de la base (le même sur les deux projets ? sinon relance) : " SUPABASE_DB_PASSWORD
echo
export SUPABASE_DB_PASSWORD

vider() { # $1 = ref du projet, $2 = nom court, $3... = options de dump
  local ref="$1" nom="$2" suffixe="$3"; shift 3
  echo "  → ${nom}_${suffixe}.sql"
  supabase db dump --project-ref "$ref" "$@" --dry-run 2>/dev/null \
    | bash > "$dossier/${nom}_${suffixe}.sql"
}

sauver() { # $1 = ref, $2 = nom court
  echo "Projet $2 ($1)"
  vider "$1" "$2" structure
  vider "$1" "$2" donnees --data-only
  vider "$1" "$2" comptes  --schema auth
}

sauver leswdaqpiyisharueufn gses
sauver alsglftuvvefxaadfzsj logistique

echo
echo "Sauvegardes dans : $dossier"
ls -lh "$dossier"
echo
echo "VÉRIFIE la taille des fichiers : un dump de quelques centaines d'octets"
echo "est un dump raté, pas une petite base."
