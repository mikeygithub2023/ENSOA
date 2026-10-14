/// Traduction des refus de la base en phrases que l'utilisateur comprend.
///
/// PostgreSQL parle à l'administrateur de base de données, pas au soutier :
///
///     insert or update on table "vehicule" violates foreign key constraint
///     "vehicule_type_vhl_id_fkey"
///
/// Cette phrase n'apprend rien à qui importe un parc automobile. Elle ne dit
/// ni ce qui manque, ni quoi corriger, et elle inquiète — on croit avoir
/// cassé quelque chose. Ce fichier la remplace par ce que l'utilisateur
/// pouvait vouloir savoir : quel renseignement est en cause, et ce qu'il
/// faut en faire.
///
/// DEUX PRINCIPES.
///
/// 1. Nos propres refus passent intacts. Une exception levée par un
///    déclencheur — « Activités Ordinaires ne contient que 300 L de Gasoil »
///    — est déjà écrite pour l'utilisateur. La traduire une seconde fois ne
///    ferait que l'appauvrir.
/// 2. Ce qu'on ne sait pas traduire garde sa trace technique. Un message
///    vague et sans code laisse l'utilisateur sans rien à signaler, et le
///    technicien sans rien à chercher.
library;

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Un nom de champ tel qu'on le dit en français, avec son genre — sans quoi
/// l'accord tombe faux une phrase sur deux.
class _Champ {
  const _Champ(this.nom, {this.feminin = false});
  final String nom;
  final bool feminin;

  String get article => feminin ? 'Cette ' : 'Ce ';
  String get accordUtilise => feminin ? 'utilisée' : 'utilisé';
  String get accordConnu => feminin ? 'connue' : 'connu';
}

/// Les colonnes que l'utilisateur rencontre. La clé est le suffixe du nom de
/// colonne : une contrainte s'appelle `vehicule_type_vhl_id_fkey`, et c'est
/// « type_vhl_id » qui nous intéresse.
///
/// Ce n'est pas un catalogue exhaustif de la base, et il n'a pas à l'être :
/// ce qui manque retombe sur le nom de la colonne, lisible faute d'être
/// élégant.
const _champs = <String, _Champ>{
  'immatriculation': _Champ('l\'immatriculation', feminin: true),
  'chassis': _Champ('le numéro de châssis'),
  'type_vhl_id': _Champ('le type de véhicule'),
  'modele_id': _Champ('le modèle'),
  'marque_id': _Champ('la marque', feminin: true),
  'vehicule_id': _Champ('le véhicule'),
  'repartition_id': _Champ('la répartition', feminin: true),
  'soute_id': _Champ('la soute', feminin: true),
  'soute_stock_id': _Champ('la ligne de stock', feminin: true),
  'source_stock_id': _Champ('la répartition d\'origine', feminin: true),
  'destination_stock_id': _Champ('la répartition servie', feminin: true),
  'type_stock_id': _Champ('le type de carburant'),
  'profile_id': _Champ('le destinataire'),
  'profil_personnalise_id': _Champ('le service'),
  'utilisateur_id': _Champ('l\'utilisateur'),
  'destinataire_id': _Champ('le destinataire'),
  'matricule': _Champ('le matricule'),
  'email': _Champ('l\'adresse électronique', feminin: true),
  'libelle': _Champ('le libellé'),
  'apprenant_id': _Champ('l\'apprenant'),
  'classe_id': _Champ('la classe', feminin: true),
  'division_id': _Champ('la division', feminin: true),
  'promotion_id': _Champ('la promotion', feminin: true),
  'cellule_id': _Champ('la cellule', feminin: true),
  'cours_id': _Champ('le cours'),
  'note_id': _Champ('la note', feminin: true),
  'activite_id': _Champ('l\'activité', feminin: true),
  'arme_id': _Champ('l\'arme', feminin: true),
  'mouvement_id': _Champ('le mouvement'),
};

/// La fiche elle-même, au singulier — pour dire laquelle résiste à une
/// suppression. Le genre suit, sans quoi « supprimée » tombe faux.
const _fiches = <String, _Champ>{
  'repartition': _Champ('cette répartition', feminin: true),
  'soute': _Champ('cette soute', feminin: true),
  'vehicule': _Champ('ce véhicule'),
  'marque_vhl': _Champ('cette marque', feminin: true),
  'modele_vhl': _Champ('ce modèle'),
  'type_vhl': _Champ('ce type de véhicule'),
  'profiles': _Champ('ce compte'),
  'profil_personnalise': _Champ('ce service'),
  'apprenants': _Champ('cet apprenant'),
  'classes': _Champ('cette classe', feminin: true),
  'divisions': _Champ('cette division', feminin: true),
  'promotions': _Champ('cette promotion', feminin: true),
  'activite': _Champ('cette activité', feminin: true),
  'cours': _Champ('ce cours'),
  'arme': _Champ('cette arme', feminin: true),
};

/// Les tables, pour dire vers quoi une référence pointait.
const _tables = <String, String>{
  'vehicule': 'le parc automobile',
  'type_vhl': 'le catalogue des types de véhicule',
  'modele_vhl': 'le catalogue des modèles',
  'marque_vhl': 'le catalogue des marques',
  'repartition': 'les répartitions',
  'soute': 'les soutes',
  'soute_type_stock': 'les stocks de soute',
  'profiles': 'les comptes',
  'profil_personnalise': 'les services',
  'apprenants': 'les apprenants',
  'classes': 'les classes',
  'activite': 'les activités',
};

/// Un refus de la base, dit en français.
String messageBaseDeDonnees(PostgrestException e) {
  final code = e.code ?? '';

  // Nos propres `raise exception` : déjà écrites pour celui qui les lira.
  if (code == 'P0001') return e.message;

  final champ = _champConcerne(e);
  final valeur = _valeurConcernee(e);

  switch (code) {
    case '23505': // unique_violation
      final quoi = champ ?? const _Champ('cette valeur', feminin: true);
      final precision = valeur == null ? '' : ' (« $valeur »)';
      return '${_capitale(quoi.nom)}$precision est déjà '
          '${quoi.accordUtilise} par une autre fiche. '
          'Corrigez-${quoi.feminin ? 'la' : 'le'}, ou retrouvez la fiche '
          'existante plutôt que d\'en créer une seconde.';

    case '23503': // foreign_key_violation
      // Deux situations contraires sous le même code, et le champ utile
      // n'est pas le même. Quand on désigne un absent, c'est la colonne
      // fautive qui compte. Quand une suppression est retenue, PostgreSQL
      // nomme la clé primaire de la fiche — « Key (id)=(9) » —, ce qui
      // n'apprend rien : ce qu'il faut dire, c'est quelle fiche résiste et
      // qui s'y rattache encore.
      if (_estSuppressionBloquee(e)) return _suppressionRetenue(e);

      final quoi = champ;
      if (quoi == null) {
        return 'Cette opération renvoie à une fiche qui n\'existe pas, ou '
            'qui a été supprimée entre-temps. Rafraîchissez l\'écran, puis '
            'réessayez.';
      }
      final vers = _tableReferencee(e);
      final ou = vers == null ? '' : ' dans $vers';
      final laquelle = valeur == null ? '' : ' (« $valeur »)';
      return '${_capitale(quoi.nom)}$laquelle n\'est pas '
          '${quoi.accordConnu}$ou. Vérifiez cette donnée, ou créez d\'abord '
          'la fiche correspondante.';

    case '23502': // not_null_violation
      final quoi = champ;
      return quoi == null
          ? 'Un renseignement obligatoire manque.'
          : '${_capitale(quoi.nom)} est obligatoire et n\'a pas été '
                'renseigné${quoi.feminin ? 'e' : ''}.';

    case '23514': // check_violation
      return 'Une valeur saisie n\'est pas acceptée : elle sort de ce que '
          'cette rubrique autorise. Vérifiez votre saisie.';

    case '22P02': // invalid_text_representation
    case '22003': // numeric_value_out_of_range
      return 'Une valeur n\'a pas le format attendu — un nombre là où du '
          'texte a été saisi, ou l\'inverse. Vérifiez votre saisie.';

    case '42501': // insufficient_privilege
      return 'Vous n\'avez pas le droit d\'effectuer cette opération. Si '
          'elle vous revient, signalez-le à l\'administrateur.';

    case '40001': // serialization_failure
    case '40P01': // deadlock_detected
      return 'Deux enregistrements simultanés se sont gênés. Réessayez.';

    case '57014': // query_canceled
      return 'Le serveur a mis trop de temps à répondre. Réessayez, et '
          'réduisez la période ou le nombre de lignes si cela se reproduit.';

    case 'PGRST116':
      return 'La fiche attendue est introuvable, ou plusieurs lui '
          'correspondent. Rafraîchissez l\'écran, puis réessayez.';

    case 'PGRST301':
      return 'Votre session a expiré. Reconnectez-vous pour continuer.';
  }

  // Un refus de la sécurité par ligne arrive parfois sans code exploitable :
  // le message, lui, le dit toujours.
  if (e.message.toLowerCase().contains('row-level security')) {
    return 'Vous n\'avez pas le droit d\'effectuer cette opération. Si elle '
        'vous revient, signalez-le à l\'administrateur.';
  }

  // Ce qu'on ne sait pas traduire garde sa trace : sans elle, l'utilisateur
  // n'a rien à signaler et le technicien rien à chercher.
  final trace = code.isEmpty ? '' : ' (code $code)';
  return 'Le serveur a refusé l\'opération$trace : ${e.message}';
}

/// Le champ en cause, cherché d'abord dans les détails — PostgreSQL y écrit
/// « Key (type_vhl_id)=(12) is not present in table "type_vhl" » —, puis
/// dans le nom de la contrainte, qui finit toujours par le nom de colonne.
_Champ? _champConcerne(PostgrestException e) {
  final details = e.details?.toString() ?? '';
  final cle = RegExp(r'Key \(([^)]+)\)').firstMatch(details)?.group(1);
  if (cle != null) {
    final direct = _champs[cle.trim()];
    if (direct != null) return direct;
  }

  final contrainte = _nomContrainte(e);
  if (contrainte != null) {
    // On retient la correspondance la plus longue : `type_vhl_id` doit
    // l'emporter sur `id` si les deux figuraient au catalogue.
    _Champ? meilleur;
    var longueur = 0;
    for (final entree in _champs.entries) {
      if (contrainte.endsWith(entree.key) && entree.key.length > longueur) {
        meilleur = entree.value;
        longueur = entree.key.length;
      }
    }
    if (meilleur != null) return meilleur;
  }

  // Faute de mieux, le nom de colonne brut reste plus parlant qu'un silence.
  if (cle != null && cle.trim().isNotEmpty) {
    return _Champ('le champ « ${cle.trim().replaceAll('_', ' ')} »');
  }
  return null;
}

/// La valeur fautive, telle que l'utilisateur l'a saisie.
String? _valeurConcernee(PostgrestException e) {
  final details = e.details?.toString() ?? '';
  final valeur = RegExp(
    r'Key \([^)]+\)=\(([^)]*)\)',
  ).firstMatch(details)?.group(1);
  if (valeur == null || valeur.trim().isEmpty) return null;
  return valeur.length > 60 ? '${valeur.substring(0, 57)}...' : valeur;
}

String? _nomContrainte(PostgrestException e) {
  final texte = '${e.message} ${e.details ?? ''}';
  return RegExp(r'constraint "([^"]+)"').firstMatch(texte)?.group(1);
}

String? _tableReferencee(PostgrestException e) {
  final details = e.details?.toString() ?? '';
  final table = RegExp(
    r'is not present in table "([^"]+)"',
  ).firstMatch(details)?.group(1);
  return table == null ? null : _tables[table] ?? 'la table « $table »';
}

/// « Cette répartition ne peut pas être supprimée : elle est encore utilisée
/// dans les stocks de soute. »
///
/// Les deux noms se lisent dans le message de PostgreSQL : la fiche qui
/// résiste dans « update or delete on table "repartition" », et ce qui la
/// retient dans « is still referenced from table "soute_type_stock" ».
String _suppressionRetenue(PostgrestException e) {
  final texte = '${e.message} ${e.details ?? ''}';
  final nomFiche = RegExp(
    r'(?:update or delete on table) "([^"]+)"',
  ).firstMatch(texte)?.group(1);
  final nomDependant = RegExp(
    r'still referenced from table "([^"]+)"',
  ).firstMatch(texte)?.group(1);

  final fiche = nomFiche == null ? null : _fiches[nomFiche];
  final sujet = fiche?.nom ?? 'cette fiche';
  final accord = (fiche?.feminin ?? true) ? 'e' : '';
  final dependant = nomDependant == null ? null : _tables[nomDependant];

  final cause = dependant == null
      ? 'd\'autres enregistrements s\'y rattachent encore'
      : 'elle est encore utilisée dans $dependant';

  return '${_capitale(sujet)} ne peut pas être supprimé$accord : $cause. '
      'Retirez ces rattachements d\'abord, ou conservez la fiche.';
}

/// La même erreur 23503 couvre deux situations contraires : on désigne une
/// fiche absente, ou l'on supprime une fiche dont d'autres dépendent. Seuls
/// les détails les distinguent.
bool _estSuppressionBloquee(PostgrestException e) {
  final texte = '${e.message} ${e.details ?? ''}'.toLowerCase();
  return texte.contains('is still referenced') ||
      texte.contains('update or delete on table');
}

String _capitale(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
