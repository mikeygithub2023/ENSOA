import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sig_ensoa/core/formulaire.dart';
import '../../core/theme.dart';
import '../../models/profil_personnalise.dart';
import '../../modules/logistique/shared/widgets/widgets.dart';
import 'providers/profils_personnalises_providers.dart';

/// Les services que l'école crée elle-même.
///
/// L'Officier Adjoint répartit les tâches d'une activité entre quatre
/// services écrits dans le code — soutien pétrolier, garage, armurerie,
/// service de santé. L'école en compte d'autres : intendance, section des
/// sports, transmissions. Ils se créent ici, et l'on peut aussitôt leur
/// confier du travail et leur ouvrir un compte.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profils = ref.watch(profilsPersonnalisesProvider);

    return profils.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: 'Services illisibles : $e'),
      data: (liste) => Stack(
        children: [
          if (liste.isEmpty)
            const EmptyState(
              message:
                  'Aucun service créé. Le bouton ci-dessous en ouvre un — '
                  'intendance, section des sports, transmissions…',
              icon: Icons.workspaces_outline,
            )
          else
            ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: liste.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _LigneService(service: liste[i]),
            ),
          Positioned(
            right: 4,
            bottom: 12,
            child: FloatingActionButton.extended(
              onPressed: () => _ouvrirFormulaire(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau service'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneService extends ConsumerWidget {
  const _LigneService({required this.service});

  final ProfilPersonnalise service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (service.actif ? AppColors.blue : AppColors.inkMuted)
              .withValues(alpha: 0.12),
          child: Icon(
            Icons.workspaces_rounded,
            color: service.actif ? AppColors.blue : AppColors.inkMuted,
            size: 20,
          ),
        ),
        title: Text(
          service.libelle,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: service.actif ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
        subtitle: Text(
          service.description?.trim().isNotEmpty == true
              ? service.description!
              : service.actif
              ? 'En service'
              : 'Retiré — ne reçoit plus de tâches',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Renommer',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  _ouvrirFormulaire(context, ref, service: service),
            ),
            IconButton(
              tooltip: service.actif ? 'Retirer' : 'Remettre en service',
              icon: Icon(
                service.actif
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_outlined,
                color: service.actif ? AppColors.success : AppColors.inkMuted,
              ),
              onPressed: () => _basculer(context, ref, service),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retirer plutôt que supprimer : les tâches déjà confiées gardent le nom du
/// service qui les a reçues. Un service retiré ne paraît plus dans la
/// répartition ni à l'ouverture d'un compte, mais l'historique des activités
/// reste lisible.
Future<void> _basculer(
  BuildContext context,
  WidgetRef ref,
  ProfilPersonnalise service,
) async {
  final messager = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(profilsPersonnalisesRepositoryProvider)
        .changerActivite(service.id, !service.actif);
    ref.invalidate(profilsPersonnalisesProvider);
    messager.showSnackBar(
      SnackBar(
        content: Text(
          service.actif
              ? '${service.libelle} retiré.'
              : '${service.libelle} remis en service.',
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

Future<void> _ouvrirFormulaire(
  BuildContext context,
  WidgetRef ref, {
  ProfilPersonnalise? service,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ServiceFormDialog(service: service),
  );
}

class _ServiceFormDialog extends ConsumerStatefulWidget {
  const _ServiceFormDialog({this.service});

  /// Le service à renommer. Nul pour une création.
  final ProfilPersonnalise? service;

  @override
  ConsumerState<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _libelle = TextEditingController(
    text: widget.service?.libelle ?? '',
  );
  late final _description = TextEditingController(
    text: widget.service?.description ?? '',
  );
  bool _envoi = false;

  bool get _correction => widget.service != null;

  @override
  void dispose() {
    _libelle.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_correction ? 'Renommer le service' : 'Nouveau service'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _libelle,
                decoration: const InputDecoration(
                  labelText: 'Nom du service',
                  helperText:
                      "C'est sous ce nom que l'Officier Adjoint lui confiera "
                      'des tâches.',
                  helperMaxLines: 2,
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Donnez un nom à ce service'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Ce dont il a la charge (facultatif)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _soumettre,
          child: Text(_correction ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  Future<void> _soumettre() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() => _envoi = true);
    final depot = ref.read(profilsPersonnalisesRepositoryProvider);
    try {
      if (_correction) {
        await depot.renommer(
          widget.service!.id,
          _libelle.text,
          _description.text,
        );
      } else {
        await depot.creer(
          libelle: _libelle.text,
          description: _description.text,
        );
      }
      ref.invalidate(profilsPersonnalisesProvider);
      if (mounted) {
        showSuccessSnackBar(
          context,
          _correction ? 'Service renommé.' : 'Service créé.',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        showErrorSnackBar(context, e);
      }
    }
  }
}
