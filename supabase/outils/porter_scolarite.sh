#!/usr/bin/env bash
# ============================================================================
# Porte les écrans de la scolarité depuis « ENSOA GSES » vers le module
# scolarité de l'application unifiée.
#
# Même méthode que pour le soutien technique : on requalifie plutôt que de
# réécrire. La structure interne (features/, models/, shared/) est conservée,
# donc les imports relatifs du module restent valides. Changent seulement :
#
#   - les imports du socle, devenus des imports package: ;
#   - les requêtes, qui visent scolarite. ou socle. au lieu de public. ;
#   - les chemins de navigation, préfixés par module ;
#   - Profile / AppRole / currentProfileProvider, qui viennent de compat.dart.
#
# Ce qui n'est PAS porté : l'authentification et le cadre (remplacés par leur
# version unifiée), et les ÉCRANS d'administration (remplacés par l'écran des
# comptes unifié). Les dépôts et providers d'administration, eux, sont repris :
# d'autres écrans s'en servent pour résoudre qui a saisi quoi.
#
# AMORÇAGE, à usage unique : une fois porté, le module vit sa vie dans
# lib/modules/scolarite et se corrige à la main.
# ============================================================================
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
racine="$(cd "$ici/../.." && pwd)"
gses="$(cd "$racine/../ENSOA GSES/lib" && pwd)"
sortie="$racine/lib/modules/scolarite"

[ -d "$gses" ] || { echo "Source introuvable : $gses" >&2; exit 1; }

# --- Le socle emprunte trois utilitaires à la scolarité ---------------------
# Traduction des erreurs, renouvellement du jeton expiré, reprise après une
# connexion coupée : trois pièces d'infrastructure bien faites, dont le
# soutien technique profitera aussi.
cp "$gses/core/erreurs.dart" "$gses/core/session_fraiche.dart" \
   "$gses/core/reprise.dart" "$racine/lib/core/"

# compat.dart est écrit à la main.
rm -rf "$sortie/features" "$sortie/models" "$sortie/shared"
mkdir -p "$sortie/features" "$sortie/models" "$sortie/shared"

for module in apprenants bulletins consultations cours depenses matieres \
              medicaments visites dashboard; do
  [ -d "$gses/features/$module" ] && cp -r "$gses/features/$module" "$sortie/features/$module"
done

# De l'administration, on ne garde que la donnée : les écrans sont remplacés,
# mais `profilesListProvider` sert ailleurs (savoir qui a saisi une note).
mkdir -p "$sortie/features/admin"
cp -r "$gses/features/admin/data" "$sortie/features/admin/data"
cp -r "$gses/features/admin/providers" "$sortie/features/admin/providers"

cp -r "$gses/models/." "$sortie/models/"
# Le profil vient du socle : sa version scolarité vit dans compat.dart.
rm -f "$sortie/models/profile.dart"

cp -r "$gses/shared/." "$sortie/shared/"

# --- Tables restées dans le schéma socle -----------------------------------
socle='profiles|divisions|audit_log|notifications|appareils'

find "$sortie" -name '*.dart' -type f -not -name 'compat.dart' -print0 | while IFS= read -r -d '' f; do
  # -z : le fichier entier est traité d une seule pièce. Les requêtes tiennent
  # souvent sur deux lignes (supabase, puis .from() en dessous) : un sed ligne
  # par ligne les laisserait viser le schéma public, où les tables ne sont plus.
  sed -i -zE "
    # --- Imports du socle ---
    s|import '(\.\./)*core/theme\.dart'|import 'package:sig_ensoa/core/theme.dart'|g
    s|import '(\.\./)*core/erreurs\.dart'|import 'package:sig_ensoa/core/erreurs.dart'|g
    s|import '(\.\./)*core/supabase_client\.dart'|import 'package:sig_ensoa/core/supabase_client.dart'|g
    s|import '(\.\./)*core/session_fraiche\.dart'|import 'package:sig_ensoa/core/session_fraiche.dart'|g
    s|import '(\.\./)*core/reprise\.dart'|import 'package:sig_ensoa/core/reprise.dart'|g

    # Les deux applications avaient chacune son AlertLevel : trois niveaux
    # côté soutien technique (passé au socle avec le thème), quatre côté
    # scolarité, qui distingue en plus la réussite. Le module garde le sien.
    s|import 'package:sig_ensoa/core/theme\.dart';|import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;|g

    # --- Profil, rôles et session : la passerelle du module ---
    s|import '(\.\./)*models/profile\.dart'|import 'package:sig_ensoa/modules/scolarite/compat.dart'|g
    s|import '(\.\./)*features/auth/providers/auth_providers\.dart'|import 'package:sig_ensoa/modules/scolarite/compat.dart'|g
    s|import '(\.\./)*auth/providers/auth_providers\.dart'|import 'package:sig_ensoa/modules/scolarite/compat.dart'|g
    s|\.signOut\(\)|.deconnexion()|g

    # --- Schémas ---
    # Délimiteur # : l'alternance des tables du socle contient des barres.
    s#supabase[[:space:]]*\.from\((['\"])($socle)\1#socle.from(\1\2\1#g
    s#supabase[[:space:]]*\.from\(#scolarite.from(#g
    s#supabase[[:space:]]*\.rpc\(#scolarite.rpc(#g

    # --- Chemins de navigation, préfixés par module ---
    s|context\.go\('/apprenants|context.go('/scolarite/apprenants|g
    s|context\.push\('/apprenants|context.push('/scolarite/apprenants|g
    s|context\.go\('/visites-medicales|context.go('/scolarite/visites-medicales|g
    s|context\.push\('/visites-medicales|context.push('/scolarite/visites-medicales|g
  " "$f"
done

echo "Module scolarité porté :"
find "$sortie" -name '*.dart' | wc -l
echo "fichiers."
