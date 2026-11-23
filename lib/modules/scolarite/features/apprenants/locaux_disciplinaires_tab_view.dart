import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/division.dart';
import '../../models/local_disciplinaire.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'bureaux.dart';
import 'portee_promotion.dart';
import 'providers/apprenants_providers.dart';
import 'providers/locaux_disciplinaires_providers.dart';
import 'register_local_disciplinaire_dialog.dart';

/// Les séjours aux locaux disciplinaires de l'effectif retenu.
///
/// Même forme que les absences, mais ce qu'on y lit est autre : une
/// punition porte une durée décidée d'avance, un motif et l'autorité qui
/// l'a prononcée. La sortie se marque au retour — plus tôt si la punition
/// est levée.
class LocauxDisciplinairesTabView extends ConsumerWidget {
  const LocauxDisciplinairesTabView({
    super.key,
    required this.division,
    required this.classe,
    this.classesRetenues,
    this.apprenantsRetenus,
  });

  /// Nulle sous « Toutes » : la vue cumule alors ce que l'utilisateur a le
  /// droit de voir, divisions confondues.
  final Division? division;
  final Classe? classe;

  /// Phases d'une promotion sélectionnée sans phase précise, nul sinon.
  final Set<String>? classesRetenues;

  /// Les élèves d'une section retenue, nommément — nul sous « toutes les
  /// sections ».
  final Set<String>? apprenantsRetenus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classe = this.classe;
    final portee = classe == null ? classesRetenues : null;
    final division = this.division;
    final apprenantsAsync =
        (classe != null
                ? ref.watch(apprenantsByClasseProvider(classe.id))
                : division != null
                ? ref.watch(apprenantsByDivisionProvider(division.id))
                : ref.watch(apprenantsListProvider))
            .dansLesClasses(portee, (a) => a.classeId)
            .pourLesApprenants(apprenantsRetenus, (a) => a.id);
    final sejoursAsync =
        (classe != null
                ? ref.watch(locauxDisciplinairesByClasseProvider(classe.id))
                : division != null
                ? ref.watch(
                    locauxDisciplinairesByDivisionProvider(division.id),
                  )
                : ref.watch(locauxDisciplinairesTousProvider))
            .dansLesClasses(portee, (s) => s.classeId)
            .pourLesApprenants(apprenantsRetenus, (s) => s.apprenantId);
    final classesAsync = ref.watch(classesListProvider);

    // La saisie demande une division, et une phase quand il y en a une. Le
    // personnel de l'école n'en a pas : c'est sa division qui le délimite.
    final peutEnregistrer = ouvreUneFiche(
      division: division,
      classeInscription: classe,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Locaux disciplinaires'),
            ),
            if (peutEnregistrer && division != null)
              FilledButton.icon(
                onPressed: apprenantsAsync.maybeWhen(
                  data: (apprenants) => apprenants.isEmpty
                      ? null
                      : () => showRegisterLocalDisciplinaireDialog(
                          context,
                          division: division,
                          classe: classe,
                          apprenants: apprenants,
                        ),
                  orElse: () => null,
                ),
                icon: const Icon(Icons.gavel_outlined, size: 18),
                label: const Text('Mettre aux arrêts'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apprenantsAsync.when(
            data: (apprenants) {
              final apprenantsById = {for (final a in apprenants) a.id: a};
              final classesById = {
                for (final c in classesAsync.value ?? const <Classe>[]) c.id: c,
              };
              return sejoursAsync.when(
                data: (sejours) {
                  if (sejours.isEmpty) {
                    return EmptyState(
                      message: classe != null
                          ? 'Personne aux locaux disciplinaires pour cette phase ou ce stage.'
                          : 'Personne aux locaux disciplinaires pour cette division.',
                      icon: Icons.gavel_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: sejours.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sejour = sejours[index];
                      final classeId = sejour.classeId;
                      return _SejourTile(
                        sejour: sejour,
                        apprenant: apprenantsById[sejour.apprenantId],
                        classeNom: classe == null && classeId != null
                            ? classesById[classeId]?.nom
                            : null,
                        onDelete: () => _confirmerSuppression(
                          context,
                          ref,
                          sejour,
                        ),
                        onMarquerSortie: () =>
                            _marquerSortie(context, ref, sejour),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  message: 'Erreur de chargement : ${messageErreur(error)}',
                  icon: Icons.error_outline,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              message: 'Erreur de chargement : ${messageErreur(error)}',
              icon: Icons.error_outline,
            ),
          ),
        ),
      ],
    );
  }

  /// Tout ce qui peut porter ce séjour : la phase quand il y en a une, la
  /// division toujours, et la vue d'ensemble.
  void _rafraichir(WidgetRef ref, LocalDisciplinaire sejour) {
    final classeId = sejour.classeId;
    if (classeId != null) {
      ref.invalidate(locauxDisciplinairesByClasseProvider(classeId));
    }
    ref.invalidate(locauxDisciplinairesByDivisionProvider(sejour.divisionId));
    ref.invalidate(locauxDisciplinairesTousProvider);
  }

  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
    LocalDisciplinaire sejour,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer cette mise aux arrêts'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette mise aux locaux '
          'disciplinaires ? Elle disparaîtra de la prise d\'armes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref
          .read(locauxDisciplinairesRepositoryProvider)
          .supprimer(sejour.id);
      _rafraichir(ref, sejour);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mise aux arrêts supprimée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _marquerSortie(
    BuildContext context,
    WidgetRef ref,
    LocalDisciplinaire sejour,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final date = await showDatePicker(
      context: context,
      initialDate: _auPlusTot(DateTime.now(), sejour.dateDebut),
      firstDate: sejour.dateDebut,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Date de sortie',
    );
    if (date == null) return;
    try {
      await ref
          .read(locauxDisciplinairesRepositoryProvider)
          .marquerSortie(sejour.id, dateSortie: date);
      _rafraichir(ref, sejour);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sortie enregistrée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : ${messageErreur(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Le sélecteur refuse une date initiale antérieure à sa borne basse :
  /// une punition enregistrée pour demain n'en aurait aucune de valide.
  static DateTime _auPlusTot(DateTime date, DateTime borne) =>
      date.isBefore(borne) ? borne : date;
}

class _SejourTile extends StatelessWidget {
  const _SejourTile({
    required this.sejour,
    required this.apprenant,
    required this.onDelete,
    required this.onMarquerSortie,
    this.classeNom,
  });

  final LocalDisciplinaire sejour;
  final Apprenant? apprenant;
  final String? classeNom;
  final VoidCallback onDelete;
  final VoidCallback onMarquerSortie;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final enRetard = sejour.sortieEnRetard(DateTime.now());
    final periode = sejour.enCours
        ? 'Du ${fmt.format(sejour.dateDebut)} au '
              '${fmt.format(sejour.dateFinPrevue)}'
        : 'Du ${fmt.format(sejour.dateDebut)} au '
              '${fmt.format(sejour.dateSortie!)}';

    return Material(
      color: AppColors.blueMist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${apprenant?.nomComplet ?? 'Apprenant inconnu'}'
                    '${classeNom != null ? ' · $classeNom' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$periode · '
                    '${sejour.jours} jour${sejour.jours > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sejour.motif +
                        (sejour.autorite != null
                            ? ' · ${sejour.autorite}'
                            : ''),
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (sejour.enCours) ...[
              StatusChip(
                label: enRetard ? 'Sortie à marquer' : 'Aux arrêts',
                level: enRetard ? AlertLevel.critical : AlertLevel.warning,
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onMarquerSortie,
                child: const Text('Marquer la sortie'),
              ),
            ] else
              const StatusChip(label: 'Sorti', level: AlertLevel.info),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.danger,
              ),
              onPressed: onDelete,
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }
}
