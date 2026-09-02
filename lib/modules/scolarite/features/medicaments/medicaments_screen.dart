import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;
import '../../models/medicament.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/ligne_cartes.dart';
import 'demandes_reapprovisionnement_view.dart';
import 'inventaire_dialog.dart';
import 'providers/medicaments_providers.dart';
import 'statistiques_medicales_view.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Les trois rubriques de la pharmacie : ce qu'il y a en stock, ce qui a
/// été commandé pour le regarnir, et ce que la troupe a consommé.
enum _Rubrique { catalogue, demandes, statistiques }

extension _RubriqueStyle on _Rubrique {
  String get label => switch (this) {
    _Rubrique.catalogue => 'Catalogue et stock',
    _Rubrique.demandes => 'Demandes de réapprovisionnement',
    _Rubrique.statistiques => 'Statistiques médicales',
  };

  IconData get icone => switch (this) {
    _Rubrique.catalogue => Icons.medication_outlined,
    _Rubrique.demandes => Icons.assignment_outlined,
    _Rubrique.statistiques => Icons.insights_outlined,
  };
}

/// Ce que le tableau de bord de la pharmacie met en avant, dans l'ordre
/// d'urgence. Ces filtres ne sont pas tous des états de stock : un
/// médicament dont la péremption approche appelle une décision même si son
/// stock est confortable — d'où une énumération propre à l'écran plutôt que
/// [EtatStock] seul.
enum _Filtre { tous, rupture, seuilAtteint, seuilProche, peremption }

extension _FiltreStyle on _Filtre {
  String get label => switch (this) {
    _Filtre.tous => 'Tous les médicaments',
    _Filtre.rupture => EtatStock.rupture.label,
    _Filtre.seuilAtteint => EtatStock.seuilAtteint.label,
    _Filtre.seuilProche => EtatStock.seuilProche.label,
    _Filtre.peremption => 'Péremption sous 3 mois',
  };

  String get description => switch (this) {
    _Filtre.tous => 'Catalogue complet',
    _Filtre.rupture => EtatStock.rupture.description,
    _Filtre.seuilAtteint => EtatStock.seuilAtteint.description,
    _Filtre.seuilProche => EtatStock.seuilProche.description,
    _Filtre.peremption => 'Périmés ou à moins de 3 mois',
  };

  IconData get icone => switch (this) {
    _Filtre.tous => Icons.medication_outlined,
    _Filtre.rupture => Icons.remove_shopping_cart_outlined,
    _Filtre.seuilAtteint => Icons.warning_amber_outlined,
    _Filtre.seuilProche => Icons.trending_down,
    _Filtre.peremption => Icons.event_busy_outlined,
  };

  Color get couleur => switch (this) {
    _Filtre.tous => AppColors.blueSoft,
    _Filtre.rupture => AppColors.danger,
    _Filtre.seuilAtteint => AppColors.warning,
    _Filtre.seuilProche => AppColors.blue,
    _Filtre.peremption => AppColors.blueDeep,
  };

  bool correspond(Medicament medicament) => switch (this) {
    _Filtre.tous => true,
    _Filtre.rupture => medicament.etatStock == EtatStock.rupture,
    _Filtre.seuilAtteint => medicament.etatStock == EtatStock.seuilAtteint,
    _Filtre.seuilProche => medicament.etatStock == EtatStock.seuilProche,
    _Filtre.peremption => medicament.peremptionAsurveiller,
  };
}

/// Pharmacie de l'infirmerie : le catalogue des médicaments et leur stock —
/// un seul stock pour toute l'école ("le point"), géré par l'administrateur
/// et le médecin, avec date de péremption, seuil d'alerte configurable et
/// journal des mouvements de stock. Le stock est décompté automatiquement à
/// chaque prescription (voir l'onglet Consultations médicales) ; il ne se
/// modifie ici que pour le réapprovisionner ou le corriger — toujours via un
/// mouvement journalisé.
///
/// L'écran s'ouvre sur l'état du stock (ruptures, seuils atteints ou en vue,
/// péremptions prochaines) : c'est ce qui appelle une commande ou une
/// décision. Le catalogue complet, rangé par classe pharmacologique, suit en
/// dessous et se restreint à un critère d'un clic sur sa carte. Deux autres
/// rubriques complètent le tableau : les demandes de réapprovisionnement
/// déjà établies, et les statistiques de consommation.
class MedicamentsScreen extends ConsumerStatefulWidget {
  const MedicamentsScreen({super.key});

  @override
  ConsumerState<MedicamentsScreen> createState() => _MedicamentsScreenState();
}

class _MedicamentsScreenState extends ConsumerState<MedicamentsScreen> {
  _Filtre _filtre = _Filtre.tous;
  _Rubrique _rubrique = _Rubrique.catalogue;

  @override
  Widget build(BuildContext context) {
    final medicamentsAsync = ref.watch(medicamentsProvider);
    final catalogue = _rubrique == _Rubrique.catalogue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Pharmacie',
          // Les actions sur le catalogue n'ont pas de sens sous la rubrique
          // des demandes, qui porte les siennes.
          trailing: catalogue
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: medicamentsAsync.maybeWhen(
                        data: (medicaments) =>
                            () => showInventaireDialog(
                              context,
                              medicaments: medicaments,
                            ),
                        orElse: () => null,
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Inventaire'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAddDialog(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 16),
        SegmentedButton<_Rubrique>(
          segments: [
            for (final rubrique in _Rubrique.values)
              ButtonSegment(
                value: rubrique,
                icon: Icon(rubrique.icone, size: 18),
                label: Text(rubrique.label),
              ),
          ],
          selected: {_rubrique},
          onSelectionChanged: (selection) =>
              setState(() => _rubrique = selection.first),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (_rubrique) {
            _Rubrique.statistiques => const StatistiquesMedicalesView(),
            _ => medicamentsAsync.when(
              data: (medicaments) {
                if (!catalogue) {
                  return DemandesReapprovisionnementView(
                    medicaments: medicaments,
                  );
                }
                if (medicaments.isEmpty) {
                  return const EmptyState(
                    message: 'Aucun médicament au catalogue.',
                    icon: Icons.medication_outlined,
                  );
                }
                final affiches = medicaments.where(_filtre.correspond).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TableauStock(
                      medicaments: medicaments,
                      filtre: _filtre,
                      onFiltre: (filtre) => setState(() => _filtre = filtre),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: affiches.isEmpty
                          ? EmptyState(
                              message:
                                  'Aucun médicament dans cet état : '
                                  '${_filtre.label.toLowerCase()}.',
                              icon: Icons.medication_outlined,
                            )
                          : _CatalogueParType(medicaments: affiches),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                message: 'Erreur de chargement : ${messageErreur(error)}',
                icon: Icons.error_outline,
              ),
            ),
          },
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final nomController = TextEditingController();
    final uniteController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final seuilController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();
    DateTime? datePeremption;
    TypeMedicament type = TypeMedicament.antalgique;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Nouveau médicament'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TypeMedicament>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    isExpanded: true,
                    items: [
                      for (final t in TypeMedicament.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (value) => setState(() => type = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: uniteController,
                    decoration: const InputDecoration(
                      labelText: 'Unité (ex. comprimé, ml) — facultatif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock initial',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse(v?.trim() ?? '');
                      if (value == null || value < 0) {
                        return 'Nombre entier positif requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: seuilController,
                    decoration: const InputDecoration(
                      labelText: 'Seuil d\'alerte stock bas',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse(v?.trim() ?? '');
                      if (value == null || value < 0) {
                        return 'Nombre entier positif requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Date de péremption (facultatif)',
                    value: datePeremption,
                    onChanged: (v) => setState(() => datePeremption = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (!validerFormulaire(context, formKey)) return;
                try {
                  await ref
                      .read(medicamentsRepositoryProvider)
                      .createMedicament(
                        nom: nomController.text.trim(),
                        unite: uniteController.text.trim().isEmpty
                            ? null
                            : uniteController.text.trim(),
                        stock: int.parse(stockController.text.trim()),
                        seuilAlerte: int.parse(seuilController.text.trim()),
                        type: type,
                        datePeremption: datePeremption,
                      );
                  ref.invalidate(medicamentsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Médicament créé avec succès.'),
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
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// État du stock en un coup d'œil : le catalogue entier, puis ce qui
/// appelle une commande ou une décision. Chaque carte restreint le
/// catalogue à son critère ; un second clic revient à la liste complète.
class _TableauStock extends StatelessWidget {
  const _TableauStock({
    required this.medicaments,
    required this.filtre,
    required this.onFiltre,
  });

  final List<Medicament> medicaments;
  final _Filtre filtre;
  final ValueChanged<_Filtre> onFiltre;

  @override
  Widget build(BuildContext context) {
    final cartes = <Widget>[
      for (final candidat in _Filtre.values)
        _CarteStock(
          label: candidat.label,
          description: candidat.description,
          icone: candidat.icone,
          couleur: candidat.couleur,
          nombre: medicaments.where(candidat.correspond).length,
          selectionne: filtre == candidat,
          principal: candidat == _Filtre.tous,
          onTap: () => onFiltre(filtre == candidat ? _Filtre.tous : candidat),
        ),
    ];

    return LigneCartes(cartes: cartes);
  }
}

class _CarteStock extends StatelessWidget {
  const _CarteStock({
    required this.label,
    required this.description,
    required this.icone,
    required this.couleur,
    required this.nombre,
    required this.selectionne,
    required this.onTap,
    this.principal = false,
  });

  final String label;
  final String description;
  final IconData icone;
  final Color couleur;
  final int nombre;
  final bool selectionne;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: principal ? AppColors.navy : AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: selectionne
              ? (principal ? AppColors.blueBright : couleur)
              : AppColors.border,
          width: selectionne ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: principal ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, color: couleur, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                '$nombre',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: principal ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: principal ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: principal ? AppColors.blueSoft : AppColors.inkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le catalogue rangé par classe pharmacologique, chaque groupe trié par
/// nom.
class _CatalogueParType extends StatelessWidget {
  const _CatalogueParType({required this.medicaments});

  final List<Medicament> medicaments;

  @override
  Widget build(BuildContext context) {
    final parType = <TypeMedicament, List<Medicament>>{};
    for (final medicament in medicaments) {
      parType.putIfAbsent(medicament.type, () => []).add(medicament);
    }
    for (final groupe in parType.values) {
      groupe.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    }

    return ListView(
      children: [
        for (final type in TypeMedicament.values)
          if (parType[type] != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                type.label.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  fontSize: 13,
                ),
              ),
            ),
            for (final medicament in parType[type]!) ...[
              _MedicamentTile(medicament: medicament),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 3650)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value != null ? _dateFmt.format(value!) : ''),
      ),
    );
  }
}

class _MedicamentTile extends ConsumerWidget {
  const _MedicamentTile({required this.medicament});

  final Medicament medicament;

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final nomController = TextEditingController(text: medicament.nom);
    final uniteController = TextEditingController(text: medicament.unite);
    final seuilController = TextEditingController(
      text: medicament.seuilAlerte.toString(),
    );
    final formKey = GlobalKey<FormState>();
    DateTime? datePeremption = medicament.datePeremption;
    TypeMedicament type = medicament.type;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Modifier le médicament'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TypeMedicament>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    isExpanded: true,
                    items: [
                      for (final t in TypeMedicament.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (value) => setState(() => type = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: uniteController,
                    decoration: const InputDecoration(
                      labelText: 'Unité (ex. comprimé, ml) — facultatif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: seuilController,
                    decoration: const InputDecoration(
                      labelText: 'Seuil d\'alerte stock bas',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse(v?.trim() ?? '');
                      if (value == null || value < 0) {
                        return 'Nombre entier positif requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Date de péremption (facultatif)',
                    value: datePeremption,
                    onChanged: (v) => setState(() => datePeremption = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (!validerFormulaire(context, formKey)) return;
                try {
                  await ref
                      .read(medicamentsRepositoryProvider)
                      .updateMedicament(
                        id: medicament.id,
                        nom: nomController.text.trim(),
                        unite: uniteController.text.trim().isEmpty
                            ? null
                            : uniteController.text.trim(),
                        seuilAlerte: int.parse(seuilController.text.trim()),
                        type: type,
                        datePeremption: datePeremption,
                      );
                  ref.invalidate(medicamentsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Médicament modifié avec succès.'),
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
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestockDialog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deltaController = TextEditingController();
    final motifController = TextEditingController(text: 'Réapprovisionnement');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Réapprovisionner « ${medicament.nom} »'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: deltaController,
                decoration: InputDecoration(
                  labelText:
                      'Quantité à ajouter au stock (${medicament.stock})',
                  helperText:
                      'Utiliser un nombre négatif pour corriger un stock trop élevé.',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                autofocus: true,
                validator: (v) {
                  final value = int.tryParse(v?.trim() ?? '');
                  if (value == null || value == 0) return 'Nombre requis';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: motifController,
                decoration: const InputDecoration(labelText: 'Motif'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!validerFormulaire(context, formKey)) return;
              try {
                await ref
                    .read(medicamentsRepositoryProvider)
                    .ajusterStock(
                      medicament.id,
                      delta: int.parse(deltaController.text.trim()),
                      motif: motifController.text.trim(),
                    );
                ref.invalidate(medicamentsProvider);
                ref.invalidate(mouvementsStockProvider(medicament.id));
                if (context.mounted) Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Stock mis à jour avec succès.'),
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
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistoriqueDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Historique — ${medicament.nom}'),
        content: SizedBox(
          width: 420,
          child: _MouvementsList(medicamentId: medicament.id),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Supprimer le médicament'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${medicament.nom} » du catalogue ? Cette action est irréversible.',
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
          .read(medicamentsRepositoryProvider)
          .deleteMedicament(medicament.id);
      ref.invalidate(medicamentsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Médicament supprimé.'),
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
                    medicament.nom,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (medicament.unite != null &&
                      medicament.unite!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      medicament.unite!,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (medicament.datePeremption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Péremption : ${_dateFmt.format(medicament.datePeremption!)}',
                      style: TextStyle(
                        color: medicament.perime
                            ? AppColors.danger
                            : AppColors.inkMuted,
                        fontSize: 12,
                        fontWeight: medicament.perime
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (medicament.perime) ...[
              const StatusChip(label: 'Périmé', level: AlertLevel.critical),
              const SizedBox(width: 8),
            ] else if (medicament.perimeBientot) ...[
              const StatusChip(
                label: 'Péremption proche',
                level: AlertLevel.warning,
              ),
              const SizedBox(width: 8),
            ],
            StatusChip(
              // L'état est nommé sur la pastille dès qu'il appelle une
              // commande : la couleur seule ne dirait pas si le seuil est
              // atteint ou seulement en vue.
              label: medicament.etatStock == EtatStock.suffisant
                  ? 'Stock : ${medicament.stock}'
                  : 'Stock : ${medicament.stock} — ${medicament.etatStock.label}',
              level: switch (medicament.etatStock) {
                EtatStock.rupture => AlertLevel.critical,
                EtatStock.seuilAtteint => AlertLevel.warning,
                EtatStock.seuilProche => AlertLevel.info,
                EtatStock.suffisant => AlertLevel.success,
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _showRestockDialog(context, ref),
              child: const Text('Réapprovisionner'),
            ),
            IconButton(
              icon: const Icon(Icons.history, size: 20),
              tooltip: 'Historique des mouvements',
              onPressed: () => _showHistoriqueDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Modifier',
              onPressed: () => _showEditDialog(context, ref),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.danger,
              ),
              tooltip: 'Supprimer',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _MouvementsList extends ConsumerWidget {
  const _MouvementsList({required this.medicamentId});

  final String medicamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yyyy à HH:mm');
    final mouvementsAsync = ref.watch(mouvementsStockProvider(medicamentId));

    return mouvementsAsync.when(
      data: (mouvements) {
        if (mouvements.isEmpty) {
          return const Text(
            'Aucun mouvement enregistré.',
            style: TextStyle(color: AppColors.inkMuted),
          );
        }
        return SizedBox(
          height: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: mouvements.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final mouvement = mouvements[index];
              final positif = mouvement.type == MouvementType.entree;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    positif
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    size: 18,
                    color: positif ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${positif ? '+' : '-'}${mouvement.quantite} · ${mouvement.motif}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(mouvement.createdAt),
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Erreur de chargement : ${messageErreur(error)}',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}
