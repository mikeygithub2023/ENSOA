#!/usr/bin/env bash
# ============================================================================
# Construit les migrations de la base unifiée à partir des deux bases d'origine.
#
# Principe : on ne réécrit pas le SQL éprouvé, on le REQUALIFIE. Les tables de
# la scolarité passent dans le schéma `scolarite`, celles du soutien technique
# dans `logistique`, et le socle commun — l'identité (profiles), l'organisation
# (divisions, service, cellule) et les journaux — dans `socle`. Les trois schémas
# se créent À CÔTÉ de l'existant : aucune table d'origine n'est touchée, et le
# retour en arrière tient en un `drop schema socle, scolarite, logistique cascade`.
#
# Les politiques RLS ne sont pas retouchées : elles ne connaissent que des noms
# de tables, et ces noms sont requalifiés partout de la même façon, définitions
# et appels compris. C'est ce qui rend l'opération sûre — une politique mal
# retranscrite, c'est un dossier médical ouvert au mauvais service.
#
# UN FICHIER SOURCE = UNE MIGRATION. Les auteurs des deux bases ont découpé
# leurs migrations en étapes « a » puis « b » là où PostgreSQL refuse qu'une
# valeur d'énuméré fraîchement ajoutée serve dans la même transaction. Tout
# concaténer en un seul fichier casserait ce découpage : `supabase db push`
# passe chaque fichier dans une transaction.
#
# Le script est rejouable : il régénère les fichiers à l'identique.
# ============================================================================
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
racine="$(cd "$ici/../.." && pwd)"
projets="$(cd "$racine/.." && pwd)"
gses="$projets/ENSOA GSES/supabase"
erp="$projets/ERP ENSOA/supabase"
sortie="$racine/supabase/migrations"

[ -d "$gses" ] || { echo "Source introuvable : $gses" >&2; exit 1; }
[ -d "$erp" ]  || { echo "Source introuvable : $erp" >&2; exit 1; }
mkdir -p "$sortie"

# Les fichiers générés sont effacés puis reconstruits ; ceux écrits à la main
# (schemas, socle unifié, droits) ne portent pas de préfixe de module.
rm -f "$sortie"/*_scolarite_*.sql "$sortie"/*_logistique_*.sql

# --- Ce qui part dans `socle` ---------------------------------------------
# Tout le reste bascule dans le schéma du module. L'ordre compte : les noms
# les plus longs d'abord, sinon `notification` mangerait `notifications`.
socle_gses='profiles|divisions|audit_log|notifications|appareils|app_role|current_role|current_division|current_promotion|handle_new_user|audit_trigger'
socle_erp='profiles|service|cellule|historique|notifications|notification|device_token|user_role|current_user_role|marquer_pin_change'

requalifier() { # $1 = schéma cible, $2 = alternance des noms du socle
  sed -E "
    s/\bpublic\.($2)\b/@@SOCLE@@\1/g
    s/\bpublic\./$1./g
    s/@@SOCLE@@/socle./g
    s/\bin schema public\b/in schema $1/g
    s/\bsearch_path = public\b/search_path = $1, socle, public/g
  "
}

# Supprime le bloc allant de la première ligne qui matche $1 à la suivante
# qui matche $2 (bornes comprises).
supprimer_bloc() {
  DEB="$1" FIN="$2" awk '
    !dans && $0 ~ ENVIRON["DEB"] { dans = 1 }
    dans { if ($0 ~ ENVIRON["FIN"]) dans = 0; next }
    { print }
  '
}

version() { # $1 = heure (01 scolarité, 03 logistique), $2 = rang du fichier
  printf '20260829%02d%02d%02d' "$1" $(( $2 / 60 )) $(( $2 % 60 ))
}

entete() { # $1 = module, $2 = fichier d'origine
  printf -- '-- ============================================================================\n'
  printf -- '-- %s — repris de %s\n' "$1" "$2"
  printf -- '--\n'
  printf -- '-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.\n'
  printf -- '-- Ne pas éditer à la main : corriger la source, puis relancer le script.\n'
  printf -- '-- ============================================================================\n\n'
}

nom() { basename "$1" .sql | tr -c 'a-zA-Z0-9_\n' '_'; }

# --- 1. Scolarité ----------------------------------------------------------
# `schema.sql` a été régénéré en cours de route : il porte déjà le travail des
# deux premières migrations, dont les en-têtes le disent d'ailleurs — « Pour
# une base neuve, schema.sql (déjà mis à jour) suffit seul. » Les rejouer
# applique deux fois la même chose (la contrainte matieres_code_key existe
# déjà : SQLSTATE 42P07). Les 66 autres ont été vérifiées : aucune ne recrée
# une table, une politique, un index ou un déclencheur de schema.sql.
deja_dans_schema=' 001_grant_et_matieres_globales.sql 002_classes_et_coefficient.sql '

i=0
for f in "$gses/schema.sql" "$gses"/migrations/*.sql; do
  case "$deja_dans_schema" in
    *" $(basename "$f") "*) continue ;;
  esac
  cible="$sortie/$(version 1 "$i")_scolarite_$(nom "$f").sql"
  { entete 'SCOLARITÉ (ENSOA GSES)' "$(basename "$f")"; cat "$f"; } \
    | requalifier scolarite "$socle_gses" > "$cible"
  i=$((i + 1))
done
echo "Scolarité   : $i migrations"

# --- 2. Logistique — moins les objets que le socle unifié définit déjà ------
# Cinq blocs sont retirés de schema.sql (type user_role, service, cellule,
# profiles, current_user_role) : ils sont créés en version unifiée par
# 20260829020000_socle_unifie.sql. Les tables métier, la RLS et les
# déclencheurs, eux, sont intacts.
j=0
for f in "$erp/schema.sql" "$erp"/migration_*.sql; do
  cible="$sortie/$(version 3 "$j")_logistique_$(nom "$f").sql"
  {
    entete 'LOGISTIQUE (ERP ENSOA)' "$(basename "$f")"
    if [ "$(basename "$f")" = schema.sql ]; then
      cat "$f" \
        | supprimer_bloc '^create type public\.user_role as enum'        '^\);' \
        | supprimer_bloc '^create table public\.service \('              '^\);' \
        | supprimer_bloc '^create table public\.cellule \('              '^\);' \
        | supprimer_bloc '^create table public\.profiles \('             '^\);' \
        | supprimer_bloc '^create function public\.current_user_role\(\)' '^\$\$;'
    elif [ "$(basename "$f")" = migration_003_repartitions.sql ]; then
      # Cette migration amorce le stock réel de la Soute Bouaké, en supposant
      # que les soutes 1 et 2 existent — elles venaient de `seed.sql`, qu'on
      # n'applique pas : la base unifiée démarre sans données. La structure,
      # les politiques RLS et le référentiel des répartitions (BA1, CA1, CA2,
      # Général) sont conservés ; seules les lignes de stock sautent. Elles
      # restent dans le fichier d'origine si on veut les ressaisir.
      cat "$f" | supprimer_bloc "^update public\.soute set libelle = 'Soute Bouaké'" '^where soute_id = 2;'
    else
      cat "$f"
    fi
  } | sed -E "
        /alter type public\.user_role add value/d
        s/\bdoit_changer_pin\b/doit_changer_mot_de_passe/g
        s/\brole in \(/role_logistique in (/g
      " \
    | requalifier logistique "$socle_erp" > "$cible"
  j=$((j + 1))
done
echo "Logistique  : $j migrations"
echo "Total       : $(ls "$sortie"/*.sql | wc -l) fichiers dans supabase/migrations"
