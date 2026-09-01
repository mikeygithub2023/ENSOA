#!/usr/bin/env bash
# ============================================================================
# Porte les écrans du soutien technique depuis « ERP ENSOA » vers le module
# logistique de l'application unifiée.
#
# Comme pour les migrations SQL : on ne réécrit pas ce qui marche, on le
# REQUALIFIE. La structure interne du module est conservée telle quelle
# (data/, features/, shared/), donc les imports relatifs entre ses fichiers
# restent valides. Seuls changent :
#
#   - les imports du socle, qui deviennent des imports `package:` (insensibles
#     à la profondeur des dossiers) ;
#   - les requêtes, qui visent désormais un schéma nommé plutôt que `public` ;
#   - `Permission.voirDashboard`, renommé lors de la fusion pour ne pas se
#     confondre avec le tableau de bord de la scolarité.
#
# Ce qui n'est PAS porté : l'authentification, le cadre et l'administration
# des comptes, tous trois remplacés par leur version unifiée.
#
# AMORÇAGE, à usage unique : une fois le module porté, il vit sa vie dans
# lib/modules/logistique et se corrige à la main. Rejouer ce script écraserait
# ces corrections.
# ============================================================================
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
racine="$(cd "$ici/../.." && pwd)"
erp="$(cd "$racine/../ERP ENSOA/lib" && pwd)"
sortie="$racine/lib/modules/logistique"

[ -d "$erp" ] || { echo "Source introuvable : $erp" >&2; exit 1; }

# compat.dart est écrit à la main : on ne l'efface pas.
rm -rf "$sortie/data" "$sortie/features" "$sortie/shared"
mkdir -p "$sortie"

cp -r "$erp/data/models" "$sortie/data_models_tmp"
mkdir -p "$sortie/data"
mv "$sortie/data_models_tmp" "$sortie/data/models"
cp -r "$erp/data/repositories" "$sortie/data/repositories"
# Le personnel, les services et les cellules sont encore des données en dur
# dans l'application d'origine — elles n'ont jamais été mises en base. On les
# reprend telles quelles pour que les écrans continuent de fonctionner ; leur
# passage en base réclamera un écran de référentiel.
cp -r "$erp/data/mock" "$sortie/data/mock"

mkdir -p "$sortie/features"
for module in armament audit dashboard fleet fuel notifications oa police tasks; do
  cp -r "$erp/features/$module" "$sortie/features/$module"
done

mkdir -p "$sortie/shared"
cp -r "$erp/shared/widgets" "$sortie/shared/widgets"
# L'icône d'arme est passée au socle, partagée avec le reste de l'application.
rm -f "$sortie/shared/widgets/weapon_icon.dart"

# --- Tables restées dans le schéma `socle` ---------------------------------
socle='profiles|service|cellule|historique|notification|device_token'

find "$sortie" -name '*.dart' -type f -not -name 'compat.dart' -print0 | while IFS= read -r -d '' f; do
  # -z : le fichier entier est traité d une seule pièce. Les requêtes tiennent
  # souvent sur deux lignes (supabase, puis .from() en dessous) : un sed ligne
  # par ligne les laisserait viser le schéma public, où les tables ne sont plus.
  sed -i -zE "
    # --- Imports du socle ---
    s|import '(\.\./)*core/security/roles\.dart'|import 'package:sig_ensoa/core/roles.dart'|g
    s|import '(\.\./)*core/security/session_controller\.dart'|import 'package:sig_ensoa/modules/logistique/compat.dart'|g
    s|import '(\.\./)*core/security/idle_guard\.dart'|import 'package:sig_ensoa/core/verrou_inactivite.dart'|g
    s|import '(\.\./)*core/supabase/supabase_config\.dart'|import 'package:sig_ensoa/core/supabase_client.dart'|g
    s|import '(\.\./)*core/theme/app_theme\.dart'|import 'package:sig_ensoa/core/theme.dart'|g
    s|import '(\.\./)*core/utils/chargement\.dart'|import 'package:sig_ensoa/core/chargement.dart'|g
    s|import '(\.\./)*core/utils/format\.dart'|import 'package:sig_ensoa/core/format.dart'|g
    s|import '(\.\./)*shared/widgets/weapon_icon\.dart'|import 'package:sig_ensoa/shared/widgets/icone_arme.dart'|g
    s|\bWeaponIcon\b|IconeArme|g

    # --- Schémas ---
    # Délimiteur # et non | : l'alternance des tables du socle en contient.
    s#supabase[[:space:]]*\.from\((['\"])($socle)\1#socle.from(\1\2\1#g
    s#supabase[[:space:]]*\.from\(#logistique.from(#g
    s#supabase[[:space:]]*\.rpc\(#logistique.rpc(#g

    # --- Renommages de fusion ---
    s|\bUserRole\b|RoleLogistique|g
    s|Permission\.voirDashboard\b|Permission.voirTableauBordLogistique|g
    # --- Chemins de navigation, préfixés par module ---
    # Les chemins nus se percutaient d'un module à l'autre : chacun vit
    # désormais sous son préfixe. (Pas d'accent inverse dans ce commentaire :
    # le programme sed passe par une chaîne entre guillemets, où le shell les
    # interpréterait comme une substitution de commande.)
    s|context\.go\('/parc|context.go('/logistique/parc|g
    s|context\.go\('/carburant|context.go('/logistique/carburant|g
    s|context\.go\('/armement|context.go('/logistique/armement|g
    s|context\.go\('/oa|context.go('/logistique/activites|g

    # Les permissions se calculent désormais à partir des deux familles de
    # rôles, il n'y a plus de table à un seul rôle à interroger.
    s|roleHas\(role, permission\)|permissionsDe(logistique: role).contains(permission)|
  " "$f"
done

echo "Module logistique porté :"
find "$sortie" -name '*.dart' | wc -l
echo "fichiers."
