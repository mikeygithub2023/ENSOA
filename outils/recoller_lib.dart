// ============================================================================
// Recolle les fichiers de `lib/` à partir de la sortie capturée par le
// harnais, après qu'une commande awk mal formée les a tous vidés.
//
// La sortie est la concaténation, dans l'ordre de `find`, du contenu de tous
// les fichiers — sans séparateur. Deux idées la redécoupent :
//
//   1. Les scripts de portage ont déjà régénéré la plupart des fichiers. Le
//      contenu INTÉGRAL d'un fichier régénéré se retrouve tel quel dans la
//      sortie, à une seule place : c'est un repère sans ambiguïté, là où huit
//      lignes d'imports n'en sont pas un.
//
//   2. Ce qui reste entre deux repères appartient aux fichiers que le portage
//      ne sait pas régénérer — ceux écrits à la main, et ceux que j'ai
//      retouchés après le portage. On les y découpe par leurs premières
//      lignes, cherchées dans ce seul intervalle.
//
// Usage : dart run outils/recoller_lib.dart <sortie.txt>
// ============================================================================

import 'dart:io';

/// Premières lignes des fichiers que le portage ne régénère pas à l'identique.
/// Elles ne servent qu'à découper l'intérieur d'un trou : deux fichiers qui
/// se suivent dans un même trou seraient sinon impossibles à séparer.
const ancresManuelles = <String, List<String>>{
  'lib/core/chargement.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';"],
  'lib/core/env.dart': ["/// Configuration Supabase de l'ERP unifié."],
  'lib/core/format.dart': ['/// Formate un entier avec un espace comme séparateur de milliers'],
  'lib/core/identite.dart': ["/// Comment on se connecte à l'ERP unifié."],
  'lib/core/postes.dart': ["import 'roles.dart';"],
  'lib/core/push.dart': ["import 'dart:io';", ''],
  'lib/core/roles.dart': ["/// Les rôles de l'école, dans les deux familles que la fusion réunit."],
  'lib/core/router.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:go_router/go_router.dart';", '', "import '../features/accueil/accueil_screen.dart';"],
  'lib/core/supabase_client.dart': ["import 'package:supabase_flutter/supabase_flutter.dart';", '', "import 'env.dart';"],
  'lib/core/theme.dart': ["import 'package:flutter/material.dart';", "import 'package:google_fonts/google_fonts.dart';"],
  'lib/core/verrou_inactivite.dart': ["import 'dart:async';"],
  'lib/features/accueil/accueil_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:go_router/go_router.dart';", "import 'package:intl/intl.dart';"],
  'lib/features/accueil/providers/apercu_providers.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../../core/supabase_client.dart';"],
  'lib/features/administration/administration_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../core/postes.dart';", "import '../../core/roles.dart';"],
  'lib/features/administration/data/comptes_repository.dart': ["import '../../../core/postes.dart';"],
  'lib/features/administration/modifier_compte_dialog.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../core/postes.dart';", "import '../../core/theme.dart';", "import '../../models/profil.dart';"],
  'lib/features/administration/nouveau_compte_dialog.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../core/identite.dart';"],
  'lib/features/administration/providers/comptes_providers.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../../models/profil.dart';"],
  'lib/features/auth/changer_mot_de_passe_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../core/identite.dart';"],
  'lib/features/auth/connexion_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:local_auth/local_auth.dart';"],
  'lib/features/auth/data/auth_repository.dart': ["import 'package:supabase_flutter/supabase_flutter.dart';", '', "import '../../../core/identite.dart';"],
  'lib/features/auth/ecran_demarrage.dart': ["import 'package:flutter/material.dart';", '', "import '../../core/theme.dart';"],
  'lib/features/auth/providers/auth_providers.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';"],
  'lib/features/shell/app_shell.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:go_router/go_router.dart';", '', "import '../../core/postes.dart';"],
  'lib/features/shell/nav_items.dart': ["import 'package:flutter/material.dart';", '', "import '../../core/roles.dart';"],
  'lib/features/tableau_de_bord/tableau_de_bord_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import '../../core/theme.dart';", "import '../../modules/logistique/features/dashboard/dashboard_screen.dart'"],
  'lib/main.dart': ["import 'package:flutter/material.dart';", "import 'package:firebase_messaging/firebase_messaging.dart';"],
  'lib/models/profil.dart': ["import '../core/roles.dart';"],
  'lib/modules/logistique/compat.dart': ['/// Passerelle entre les écrans repris du soutien technique et le socle commun.'],
  'lib/modules/logistique/data/repositories/organisation_providers.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:sig_ensoa/core/chargement.dart';"],
  'lib/modules/logistique/features/admin/assistant_ia.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import 'package:sig_ensoa/core/supabase_client.dart';"],
  'lib/modules/logistique/features/organisation/organisation_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:sig_ensoa/core/chargement.dart';"],
  'lib/modules/scolarite/compat.dart': ['/// Passerelle entre les écrans repris de la scolarité et le socle commun.'],
  'lib/shared/widgets/ecran_a_venir.dart': ["import 'package:flutter/material.dart';", '', "import '../../core/theme.dart';"],
  'lib/modules/logistique/data/mock/seed.dart': ["import 'package:sig_ensoa/core/roles.dart';", "import '../models/armement.dart';", "import '../models/audit_entry.dart';"],
  'lib/modules/logistique/data/models/personnel.dart': ["/// PERSONNEL — fiche du militaire (distinct d'UTILISATEUR, qui est un compte"],
  'lib/modules/logistique/data/repositories/misc_providers.dart': ["import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import 'package:sig_ensoa/core/roles.dart';", "import 'package:sig_ensoa/core/supabase_client.dart';"],
  'lib/modules/scolarite/features/apprenants/data/antecedents_medicaux_repository.dart': ["import 'package:sig_ensoa/core/supabase_client.dart';", "import '../../../models/antecedents_medicaux.dart';"],
  'lib/modules/scolarite/features/apprenants/grade_defaults.dart': ['/// Le grade que porte un élève du fait de la phase où il se trouve.'],
  'lib/modules/scolarite/shared/widgets/role_gate.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;", "import 'package:sig_ensoa/modules/scolarite/compat.dart';"],
  'lib/modules/scolarite/features/admin/espaces_eleves_screen.dart': ["import 'package:flutter/material.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';", '', "import 'package:sig_ensoa/core/erreurs.dart';", "import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;", "import '../../models/apprenant.dart';"],
  'lib/shared/widgets/icone_arme.dart': ["import 'package:flutter/material.dart';", '', "/// Icône « fusil d'assaut » — Material Icons n'en propose délibérément"],
};

/// Les fichiers que la régénération n'a pas recréés du tout.
const fichiersDisparus = [
  'lib/modules/logistique/data/repositories/organisation_providers.dart',
  'lib/modules/logistique/features/admin/assistant_ia.dart',
  'lib/modules/logistique/features/organisation/organisation_screen.dart',
  'lib/modules/scolarite/features/admin/espaces_eleves_screen.dart',
];

void main(List<String> args) {
  final lignes = File(args[0]).readAsLinesSync();

  final surDisque = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();

  // --- 1. Les repères : les fichiers régénérés, retrouvés en entier --------
  final blocs = <({String chemin, int debut, int fin})>[];
  final aRetrouver = <String>[...fichiersDisparus];

  for (final chemin in surDisque) {
    final contenu = File(chemin).readAsLinesSync();
    if (contenu.isEmpty) {
      aRetrouver.add(chemin);
      continue;
    }
    // Le fichier régénéré se termine par une ligne vide que `readAsLines`
    // rend en dernier élément vide : on la retire pour comparer.
    final corps = contenu.last.isEmpty
        ? contenu.sublist(0, contenu.length - 1)
        : contenu;
    final positions = _chercherToutes(lignes, corps);
    if (positions.length == 1) {
      blocs.add((chemin: chemin, debut: positions.first, fin: positions.first + corps.length));
    } else {
      // Introuvable en entier : le fichier a été retouché après le portage.
      // Il rejoint donc ceux à recoller depuis la sortie.
      aRetrouver.add(chemin);
    }
  }

  blocs.sort((a, b) => a.debut.compareTo(b.debut));
  stdout.writeln('${blocs.length} fichiers retrouvés intacts, '
      '${aRetrouver.length} à recoller depuis la sortie.');

  // --- 2. Les trous entre repères -----------------------------------------
  final trous = <({int debut, int fin})>[];
  var curseur = 0;
  for (final bloc in blocs) {
    if (bloc.debut > curseur) trous.add((debut: curseur, fin: bloc.debut));
    curseur = bloc.fin;
  }
  if (curseur < lignes.length) trous.add((debut: curseur, fin: lignes.length));

  stdout.writeln('${trous.length} trous à répartir.');

  // --- 3. On place chaque fichier manquant dans un trou --------------------
  final debuts = <String, int>{};
  final sansPlace = <String>[];

  for (final chemin in aRetrouver) {
    final a = ancresManuelles[chemin] ?? _ancreDepuisDisque(chemin);
    if (a.isEmpty) {
      sansPlace.add('$chemin (pas d\'ancre)');
      continue;
    }
    var place = -1;
    for (final trou in trous) {
      final p = _chercherDans(lignes, a, trou.debut, trou.fin);
      if (p >= 0) {
        place = p;
        break;
      }
    }
    if (place < 0) {
      sansPlace.add(chemin);
    } else {
      debuts[chemin] = place;
    }
  }

  if (sansPlace.isNotEmpty) {
    stderr.writeln('Sans place (${sansPlace.length}) :');
    for (final c in sansPlace) {
      stderr.writeln('  $c');
    }
  }

  // --- 4. Chaque fichier va de son début jusqu'au repère suivant -----------
  final frontieres = <int>[
    ...blocs.map((b) => b.debut),
    ...debuts.values,
    lignes.length,
  ]..sort();

  var ecrits = 0;
  for (final entree in debuts.entries) {
    final debut = entree.value;
    final fin = frontieres.firstWhere((f) => f > debut, orElse: () => lignes.length);
    final fichier = File(entree.key);
    fichier.parent.createSync(recursive: true);
    fichier.writeAsStringSync('${lignes.sublist(debut, fin).join('\n')}\n');
    ecrits++;
  }

  stdout.writeln('$ecrits fichiers recollés.');
  if (sansPlace.isNotEmpty) exit(1);
}

List<String> _ancreDepuisDisque(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) return const [];
  final l = f.readAsLinesSync();
  return l.take(8).toList();
}

List<int> _chercherToutes(List<String> lignes, List<String> motif) {
  final trouvees = <int>[];
  if (motif.isEmpty) return trouvees;
  for (var i = 0; i <= lignes.length - motif.length; i++) {
    var ok = true;
    for (var j = 0; j < motif.length; j++) {
      if (lignes[i + j] != motif[j]) {
        ok = false;
        break;
      }
    }
    if (ok) trouvees.add(i);
  }
  return trouvees;
}

int _chercherDans(List<String> lignes, List<String> motif, int debut, int fin) {
  for (var i = debut; i <= fin - motif.length; i++) {
    var ok = true;
    for (var j = 0; j < motif.length; j++) {
      if (lignes[i + j] != motif[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}
