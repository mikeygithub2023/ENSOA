import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/apprenant.dart';
import '../../models/classe.dart';
import '../../models/controle.dart';
import '../../models/division.dart';
import '../../models/matiere.dart';
import '../../models/note.dart';
import 'package:sig_ensoa/modules/scolarite/compat.dart';
import '../../models/sous_module.dart';
import '../../shared/widgets/common.dart';
import '../matieres/providers/matieres_providers.dart';
import 'controles_tab_view.dart' show computeAvailableModuleMatieres;
import 'providers/apprenants_providers.dart';
import 'providers/controles_providers.dart';
import 'providers/sous_modules_providers.dart';
import 'register_controle_dialog.dart';
import 'register_note_dialog.dart';
import 'register_sous_module_dialog.dart';

class ControleDetailScreen extends ConsumerWidget {
  const ControleDetailScreen({super.key, required this.controleId});

  final String controleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controleAsync = ref.watch(controleByIdProvider(controleId));

    return controleAsync.when(
      data: (controle) {
        if (controle == null) {
          return const EmptyState(
            message: 'Contrôle introuvable.',
            icon: Icons.grading_outlined,
          );
        }
        final divisionsAsync = ref.watch(divisionsProvider);
        final classesAsync = ref.watch(classesListProvider);
        final divisions = {
          for (final d in divisionsAsync.value ?? <Division>[]) d.id: d,
        };
        final classes = {
          for (final c in classesAsync.value ?? <Classe>[]) c.id: c,
        };
        final division = divisions[controle.divisionId];
        final classe = classes[controle.classeId];
        if (division == null || classe == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ControleDetailView(
          controle: controle,
          division: division,
          classe: classe,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        message: 'Erreur de chargement : ${messageErreur(error)}',
        icon: Icons.error_outline,
      ),
    );
  }
}

int _byNomPrenom(Apprenant a, Apprenant b) {
  final byNom = a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
  return byNom != 0
      ? byNom
      : a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase());
}

String _formatNote(num value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

/// Page de détail d'un contrôle — même gabarit que la fiche apprenant
/// (en-tête avec retour/titre/actions, puis sections en Card), plutôt
/// qu'une fenêtre popup. Les notes sont rangées par matière puis par ordre
/// alphabétique des apprenants, affichées sur le même modèle de tuile que
/// les Permissions (partie bleue avec boutons modifier/supprimer).
class ControleDetailView extends ConsumerWidget {
  const ControleDetailView({
    super.key,
    required this.controle,
    required this.division,
    required this.classe,
  });

  final Controle controle;
  final Division division;
  final Classe classe;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le contrôle'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${controle.libelle} » ? Les notes associées seront également supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(controlesRepositoryProvider).deleteControle(controle.id);
      ref.invalidate(controlesByClasseProvider(controle.classeId));
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/apprenants');
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contrôle supprimé.'),
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

  /// Suppression directe (administrateur) — soit une note sans demande en
  /// attente, soit la confirmation d'une demande faite par un autre profil.
  Future<void> _confirmDeleteNote(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          note.suppressionDemandee
              ? 'Confirmer la suppression'
              : 'Supprimer la note',
        ),
        content: Text(
          note.suppressionDemandee
              ? 'Une suppression a été demandée pour cette note. Confirmer la suppression définitive ?'
              : 'Voulez-vous vraiment supprimer cette note ?',
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
    if (confirmed != true) return;
    try {
      await ref.read(controlesRepositoryProvider).deleteNote(note.id);
      ref.invalidate(notesByControleProvider(controle.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Note supprimée.'),
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

  /// Un profil non-administrateur ne peut pas supprimer directement (RLS) :
  /// il déclenche une demande, qui notifie tous les administrateurs.
  Future<void> _confirmRequestDeletion(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Demander la suppression'),
        content: const Text(
          'La suppression de cette note sera soumise à un administrateur pour validation. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Demander'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(controlesRepositoryProvider).requestNoteDeletion(note.id);
      ref.invalidate(notesByControleProvider(controle.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demande de suppression envoyée à l\'administrateur.'),
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

  /// L'administrateur rejette une demande de suppression : la note est
  /// conservée, la demande annulée.
  Future<void> _confirmRejectDeletion(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Rejeter la demande'),
        content: const Text(
          'La note sera conservée et la demande de suppression annulée. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(controlesRepositoryProvider).rejectNoteDeletion(note.id);
      ref.invalidate(notesByControleProvider(controle.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demande de suppression rejetée.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apprenantsAsync = ref.watch(
      apprenantsByClasseProvider(controle.classeId),
    );
    final notesAsync = ref.watch(notesByControleProvider(controle.id));
    final role = ref.watch(currentProfileProvider).value?.role;
    final isAdmin = role == AppRole.admin;

    // Le Commandant de Brigade ne note que le sport. Sur un contrôle d'une
    // autre nature, l'écran ne lui propose pas de saisir : le serveur le
    // refuserait, et un bouton qui ne mène qu'à un refus vaut moins que pas
    // de bouton du tout. Il continue de lire ces notes — commander une
    // promotion, c'est en connaître les résultats.
    final peutNoter =
        !(role == AppRole.commandantBrigade &&
            controle.type != ControleType.sport);

    List<Matiere> editModuleMatieres = const [];
    if (controle.type == ControleType.module) {
      final matieres = ref.watch(matieresCatalogueProvider).value ?? const [];
      final matiereModules =
          ref.watch(matiereModulesProvider).value ?? const [];
      final allControles =
          ref.watch(controlesByClasseProvider(controle.classeId)).value ??
          const [];
      editModuleMatieres = computeAvailableModuleMatieres(
        classeId: controle.classeId,
        allControles: allControles,
        matieres: matieres,
        matiereModules: matiereModules,
        excludeControleId: controle.id,
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/scolarite/apprenants'),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.blueMist,
                child: Icon(
                  Icons.grading_outlined,
                  color: AppColors.blueDeep,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controle.libelle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${controle.type.sectionLabel(classe.type)} · ${classe.nom} · ${division.nom}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: 'Coefficient ${controle.coefficient}',
                level: AlertLevel.info,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
                onPressed: () => showEditControleDialog(
                  context,
                  division: division,
                  classe: classe,
                  existing: controle,
                  moduleMatieres: editModuleMatieres,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Supprimer',
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          controle.type == ControleType.module
              ? _ModuleNotesBody(
                  controle: controle,
                  apprenantsAsync: apprenantsAsync,
                  notesAsync: notesAsync,
                  isAdmin: isAdmin,
                  peutNoter: peutNoter,
                  onDeleteNote: (note) =>
                      _confirmDeleteNote(context, ref, note),
                  onRequestDeletion: (note) =>
                      _confirmRequestDeletion(context, ref, note),
                  onRejectDeletion: (note) =>
                      _confirmRejectDeletion(context, ref, note),
                )
              : _MatiereNotesBody(
                  controle: controle,
                  apprenantsAsync: apprenantsAsync,
                  notesAsync: notesAsync,
                  isAdmin: isAdmin,
                  peutNoter: peutNoter,
                  onDeleteNote: (note) =>
                      _confirmDeleteNote(context, ref, note),
                  onRequestDeletion: (note) =>
                      _confirmRequestDeletion(context, ref, note),
                  onRejectDeletion: (note) =>
                      _confirmRejectDeletion(context, ref, note),
                ),
        ],
      ),
    );
  }
}

/// Corps de la page pour un contrôle de type "module" : le module se
/// décompose en sous-modules, chacun avec son coefficient, et les notes se
/// rattachent à un sous-module — jamais au module lui-même, dont la note
/// est la moyenne pondérée des siens (voir `moyennes.dart`).
///
/// Tant qu'aucun sous-module n'est défini, il n'y a rien à noter : la page
/// invite d'abord à les créer.
class _ModuleNotesBody extends ConsumerWidget {
  const _ModuleNotesBody({
    required this.controle,
    required this.apprenantsAsync,
    required this.notesAsync,
    required this.isAdmin,
    required this.peutNoter,
    required this.onDeleteNote,
    required this.onRequestDeletion,
    required this.onRejectDeletion,
  });

  final Controle controle;
  final AsyncValue<List<Apprenant>> apprenantsAsync;
  final AsyncValue<List<Note>> notesAsync;
  final bool isAdmin;

  /// L'utilisateur peut-il saisir une note sur ce contrôle ?
  final bool peutNoter;
  final ValueChanged<Note> onDeleteNote;
  final ValueChanged<Note> onRequestDeletion;
  final ValueChanged<Note> onRejectDeletion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sousModulesAsync = ref.watch(
      sousModulesByModuleProvider(controle.id),
    );

    return sousModulesAsync.when(
      data: (sousModules) => apprenantsAsync.when(
        data: (apprenants) => notesAsync.when(
          data: (notes) {
            if (apprenants.isEmpty) {
              return const EmptyState(
                message: 'Aucun apprenant dans cette phase ou ce stage.',
                icon: Icons.groups_outlined,
              );
            }
            final sortedApprenants = [...apprenants]..sort(_byNomPrenom);
            final apprenantsById = {for (final a in sortedApprenants) a.id: a};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SousModulesSection(
                  module: controle,
                  sousModules: sousModules,
                  notes: notes,
                ),
                const SizedBox(height: 24),
                if (sousModules.isEmpty)
                  const EmptyState(
                    message:
                        'Aucun sous-module : ce module n\'a rien à noter.\n'
                        'Ajoutez-en un ci-dessus — la note du module sera la '
                        'moyenne pondérée de ses sous-modules.',
                    icon: Icons.segment_outlined,
                  )
                else
                  // Le sport ne passe pas par ici : ses séances se tiennent
                  // dans la rubrique Sport de la phase, et leurs notes
                  // viennent du barème de l'activité, pas d'une saisie.
                  for (final sousModule in sousModules.where(
                    (s) => !s.estSeance,
                  )) ...[
                    _NotesSection(
                      controleId: controle.id,
                      matiere: null,
                      sousModule: sousModule,
                      title:
                          '${sousModule.nom} · coefficient '
                          '${sousModule.coefficient}',
                      emptyMessage:
                          'Aucune note enregistrée pour ${sousModule.nom}.',
                      apprenants: sortedApprenants,
                      apprenantsById: apprenantsById,
                      notes: notes
                          .where((n) => n.sousModuleId == sousModule.id)
                          .toList(),
                      isAdmin: isAdmin,
                      peutNoter: peutNoter,
                      onDeleteNote: onDeleteNote,
                      onRequestDeletion: onRequestDeletion,
                      onRejectDeletion: onRejectDeletion,
                    ),
                    const SizedBox(height: 16),
                  ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'Erreur de chargement : ${messageErreur(error)}',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(
          'Erreur de chargement : ${messageErreur(error)}',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Erreur de chargement : ${messageErreur(error)}',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}

/// Corps de la page pour un contrôle continu/examen : un même contrôle
/// couvre plusieurs matières, donc les notes sont rangées par matière puis
/// par ordre alphabétique des apprenants.
class _MatiereNotesBody extends ConsumerWidget {
  const _MatiereNotesBody({
    required this.controle,
    required this.apprenantsAsync,
    required this.notesAsync,
    required this.isAdmin,
    required this.peutNoter,
    required this.onDeleteNote,
    required this.onRequestDeletion,
    required this.onRejectDeletion,
  });

  final Controle controle;
  final AsyncValue<List<Apprenant>> apprenantsAsync;
  final AsyncValue<List<Note>> notesAsync;
  final bool isAdmin;

  /// L'utilisateur peut-il saisir une note sur ce contrôle ?
  final bool peutNoter;
  final ValueChanged<Note> onDeleteNote;
  final ValueChanged<Note> onRequestDeletion;
  final ValueChanged<Note> onRejectDeletion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matieresAsync = ref.watch(matieresCatalogueProvider);
    final modulesAsync = ref.watch(matiereModulesProvider);

    return matieresAsync.when(
      data: (matieres) => modulesAsync.when(
        data: (modules) => apprenantsAsync.when(
          data: (apprenants) => notesAsync.when(
            data: (notes) {
              final matieresById = {for (final m in matieres) m.id: m};
              final classeMatieres =
                  modules
                      .where((m) => m.classeId == controle.classeId)
                      .map((m) => matieresById[m.matiereId])
                      .whereType<Matiere>()
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
                    );

              if (classeMatieres.isEmpty) {
                return const EmptyState(
                  message:
                      'Aucune matière configurée pour cette phase ou ce stage.\nConfigurez les matières depuis la rubrique Matières.',
                  icon: Icons.menu_book_outlined,
                );
              }
              if (apprenants.isEmpty) {
                return const EmptyState(
                  message: 'Aucun apprenant dans cette phase ou ce stage.',
                  icon: Icons.groups_outlined,
                );
              }

              final sortedApprenants = [...apprenants]..sort(_byNomPrenom);
              final apprenantsById = {
                for (final a in sortedApprenants) a.id: a,
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final matiere in classeMatieres) ...[
                    _NotesSection(
                      controleId: controle.id,
                      matiere: matiere,
                      title: matiere.nom,
                      emptyMessage:
                          'Aucune note enregistrée pour ${matiere.nom}.',
                      apprenants: sortedApprenants,
                      apprenantsById: apprenantsById,
                      notes: notes
                          .where((n) => n.matiereId == matiere.id)
                          .toList(),
                      isAdmin: isAdmin,
                      peutNoter: peutNoter,
                      onDeleteNote: onDeleteNote,
                      onRequestDeletion: onRequestDeletion,
                      onRejectDeletion: onRejectDeletion,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              'Erreur de chargement : ${messageErreur(error)}',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'Erreur de chargement : ${messageErreur(error)}',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(
          'Erreur de chargement : ${messageErreur(error)}',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Erreur de chargement : ${messageErreur(error)}',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}

/// Liste de notes pour un couple (contrôle, matière) — ou, pour un
/// contrôle de type "module" (voir [_ModuleNotesBody]), pour un couple
/// (module, sous-module) : [matiere] est alors `null` et [sousModule]
/// renseigné. Exactement l'un des deux, comme l'exige la base.
class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.controleId,
    required this.matiere,
    this.sousModule,
    required this.title,
    required this.emptyMessage,
    required this.apprenants,
    required this.apprenantsById,
    required this.notes,
    required this.isAdmin,
    required this.peutNoter,
    required this.onDeleteNote,
    required this.onRequestDeletion,
    required this.onRejectDeletion,
  });

  final String controleId;
  final Matiere? matiere;
  final SousModule? sousModule;
  final String title;
  final String emptyMessage;
  final List<Apprenant> apprenants;
  final Map<String, Apprenant> apprenantsById;
  final List<Note> notes;
  final bool isAdmin;

  /// L'utilisateur peut-il saisir une note sur ce contrôle ?
  final bool peutNoter;
  final ValueChanged<Note> onDeleteNote;
  final ValueChanged<Note> onRequestDeletion;
  final ValueChanged<Note> onRejectDeletion;

  @override
  Widget build(BuildContext context) {
    final notedApprenantIds = notes.map((n) => n.apprenantId).toSet();
    final apprenantsSansNote = apprenants
        .where((a) => !notedApprenantIds.contains(a.id))
        .toList();
    final sortedNotes = [...notes]
      ..sort((a, b) {
        final apprenantA = apprenantsById[a.apprenantId];
        final apprenantB = apprenantsById[b.apprenantId];
        if (apprenantA == null || apprenantB == null) return 0;
        return _byNomPrenom(apprenantA, apprenantB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: title)),
            if (peutNoter)
              FilledButton.icon(
                onPressed: apprenantsSansNote.isEmpty
                    ? null
                    : () => showRegisterNoteDialog(
                        context,
                        controleId: controleId,
                        matiere: matiere,
                        sousModule: sousModule,
                        apprenants: apprenantsSansNote,
                      ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Enregistrer une note'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedNotes.isEmpty)
          EmptyState(message: emptyMessage, icon: Icons.grading_outlined)
        else
          Column(
            children: [
              for (final note in sortedNotes) ...[
                _NoteTile(
                  note: note,
                  apprenant: apprenantsById[note.apprenantId],
                  onEdit: () {
                    final apprenant = apprenantsById[note.apprenantId];
                    if (apprenant == null) return;
                    showEditNoteDialog(
                      context,
                      controleId: controleId,
                      matiere: matiere,
                      sousModule: sousModule,
                      apprenant: apprenant,
                      existing: note,
                    );
                  },
                  isAdmin: isAdmin,
                  peutNoter: peutNoter,
                  onConfirmDelete: () => onDeleteNote(note),
                  onRequestDeletion: () => onRequestDeletion(note),
                  onRejectDeletion: () => onRejectDeletion(note),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.apprenant,
    required this.onEdit,
    required this.isAdmin,
    required this.peutNoter,
    required this.onConfirmDelete,
    required this.onRequestDeletion,
    required this.onRejectDeletion,
  });

  final Note note;
  final Apprenant? apprenant;
  final VoidCallback onEdit;
  final bool isAdmin;

  /// L'utilisateur peut-il saisir une note sur ce contrôle ?
  final bool peutNoter;
  final VoidCallback onConfirmDelete;
  final VoidCallback onRequestDeletion;
  final VoidCallback onRejectDeletion;

  @override
  Widget build(BuildContext context) {
    final pending = note.suppressionDemandee;
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
                  Row(
                    children: [
                      Text(
                        apprenant?.nomComplet ?? 'Apprenant inconnu',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (note.modifiee) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Note précédente : ${_formatNote(note.previousNote!)} / 20',
                          child: const StatusChip(
                            label: 'Note modifiée',
                            level: AlertLevel.warning,
                          ),
                        ),
                      ],
                      if (pending) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Suppression demandée le '
                              '${note.deletionRequestedAt!.day.toString().padLeft(2, '0')}/'
                              '${note.deletionRequestedAt!.month.toString().padLeft(2, '0')}/'
                              '${note.deletionRequestedAt!.year}',
                          child: const StatusChip(
                            label: 'Suppression demandée',
                            level: AlertLevel.critical,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Note : ${_formatNote(note.note)} / 20',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (peutNoter)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Modifier',
              ),
            if (isAdmin && pending)
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.inkMuted,
                ),
                onPressed: onRejectDeletion,
                tooltip: 'Rejeter la demande',
              ),
            IconButton(
              icon: Icon(
                pending && !isAdmin
                    ? Icons.hourglass_empty
                    : Icons.delete_outline,
                size: 20,
                color: pending && !isAdmin
                    ? AppColors.inkMuted
                    : AppColors.danger,
              ),
              onPressed: pending && !isAdmin
                  ? null
                  : (isAdmin ? onConfirmDelete : onRequestDeletion),
              tooltip: pending && !isAdmin
                  ? 'Suppression déjà demandée'
                  : (isAdmin ? 'Supprimer' : 'Demander la suppression'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les sous-modules du module, avec leur coefficient et le nombre de notes
/// déjà saisies. C'est ici qu'on les crée, les renomme, les repondère ou
/// les supprime — la note du module découle entièrement de cette liste.
class _SousModulesSection extends ConsumerWidget {
  const _SousModulesSection({
    required this.module,
    required this.sousModules,
    required this.notes,
  });

  final Controle module;
  final List<SousModule> sousModules;
  final List<Note> notes;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SousModule sousModule,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nbNotes = notes.where((n) => n.sousModuleId == sousModule.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le sous-module'),
        content: Text(
          nbNotes == 0
              ? 'Voulez-vous vraiment supprimer « ${sousModule.nom} » ?'
              : 'Voulez-vous vraiment supprimer « ${sousModule.nom} » ? '
                    'Ses $nbNotes note${nbNotes > 1 ? 's' : ''} '
                    'seront supprimée${nbNotes > 1 ? 's' : ''} avec lui, et '
                    'la note du module sera recalculée sans elle'
                    '${nbNotes > 1 ? 's' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(sousModulesRepositoryProvider)
          .deleteSousModule(sousModule.id);
      ref.invalidate(sousModulesByModuleProvider(module.id));
      ref.invalidate(notesByControleProvider(module.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sous-module supprimé.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCoef = sousModules.fold<num>(0, (t, s) => t + s.coefficient);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Sous-modules')),
            FilledButton.icon(
              onPressed: () => showSousModuleDialog(context, module: module),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un sous-module'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sousModules.isEmpty
              ? 'La note du module est la moyenne pondérée de ses sous-modules.'
              : 'Moyenne pondérée sur un total de coefficients de '
                    '${_formatNote(totalCoef)}.',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (sousModules.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final sousModule in sousModules)
                _SousModuleTile(
                  key: ValueKey(sousModule.id),
                  module: module,
                  sousModule: sousModule,
                  nbNotes: notes
                      .where((n) => n.sousModuleId == sousModule.id)
                      .length,
                  onDelete: () => _confirmDelete(context, ref, sousModule),
                ),
            ],
          ),
      ],
    );
  }
}

class _SousModuleTile extends StatelessWidget {
  const _SousModuleTile({
    super.key,
    required this.module,
    required this.sousModule,
    required this.nbNotes,
    required this.onDelete,
  });

  final Controle module;
  final SousModule sousModule;
  final int nbNotes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.segment_outlined, color: AppColors.blueDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sousModule.nom,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coefficient ${_formatNote(sousModule.coefficient)} · '
                  '$nbNotes note${nbNotes > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modifier',
            onPressed: () => showSousModuleDialog(
              context,
              module: module,
              existing: sousModule,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: 'Supprimer',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
