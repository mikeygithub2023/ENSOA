import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sig_ensoa/modules/logistique/compat.dart';
import 'package:sig_ensoa/core/theme.dart';
import 'package:sig_ensoa/core/chargement.dart';
import '../../data/models/police.dart';
import '../../data/repositories/misc_providers.dart';
import '../../data/repositories/police_providers.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/widgets.dart';

enum _FiltreVisiteur { dansLeCamp, sortis }

class VisiteursTabContent extends ConsumerStatefulWidget {
  const VisiteursTabContent({super.key});

  @override
  ConsumerState<VisiteursTabContent> createState() =>
      _VisiteursTabContentState();
}

class _VisiteursTabContentState extends ConsumerState<VisiteursTabContent> {
  _FiltreVisiteur _filtre = _FiltreVisiteur.dansLeCamp;
  final Set<String> _sortiesEnCours = {};
  final _rechercheCtrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrerSortie(PassageVisiteur p) async {
    setState(() => _sortiesEnCours.add(p.id));
    final user = ref.read(sessionProvider)?.user;
    try {
      await ref
          .read(passagesVisiteursProvider.notifier)
          .enregistrerSortie(p.id);
      if (user != null) {
        ref
            .read(auditProvider.notifier)
            .log(
              auteurId: user.id,
              action: 'VISITEUR_SORTI',
              cible: p.nomVisiteur,
            );
      }
      if (mounted) {
        showSuccessSnackBar(context, 'Sortie enregistrée avec succès.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _sortiesEnCours.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = estCharge(ref, ['passages_visiteurs']);
    final passages = List.of(ref.watch(passagesVisiteursProvider))
      ..sort((a, b) => b.dateArrivee.compareTo(a.dateArrivee));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!charge) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 100),
        child: SkeletonList(itemCount: 4),
      );
    }

    final recherche = _recherche.trim().toLowerCase();
    final filtres = passages.where((p) {
      final passeFiltre = switch (_filtre) {
        _FiltreVisiteur.dansLeCamp => p.enCours,
        _FiltreVisiteur.sortis => !p.enCours,
      };
      if (!passeFiltre) return false;
      if (recherche.isEmpty) return true;
      final texte = '${p.nomVisiteur} ${p.contactVisiteur} ${p.nomRecu}'
          .toLowerCase();
      return texte.contains(recherche);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
      children: [
        TextField(
          controller: _rechercheCtrl,
          decoration: InputDecoration(
            hintText:
                'Rechercher un visiteur (nom, contact) ou une personne visitée...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _recherche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _rechercheCtrl.clear();
                      _recherche = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _recherche = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChipPill(
              label: 'Dans le camp',
              selected: _filtre == _FiltreVisiteur.dansLeCamp,
              onTap: () => setState(() => _filtre = _FiltreVisiteur.dansLeCamp),
            ),
            FilterChipPill(
              label: 'Sortis',
              selected: _filtre == _FiltreVisiteur.sortis,
              onTap: () => setState(() => _filtre = _FiltreVisiteur.sortis),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Visiteurs (${filtres.length})'),
        if (filtres.isEmpty)
          const EmptyState(message: 'Aucun visiteur pour ce filtre'),
        for (final p in filtres) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: p.couleurBadge.couleur.withValues(alpha: 0.15),
                backgroundImage: p.photoBase64 != null
                    ? MemoryImage(base64Decode(p.photoBase64!))
                    : null,
                child: p.photoBase64 == null
                    ? Icon(Icons.person_outline, color: p.couleurBadge.couleur)
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(p.nomVisiteur, overflow: TextOverflow.ellipsis),
                  ),
                  // Effectif et véhicule en tête de ligne : c'est ce que le
                  // planton doit voir sans lire, quand il compte ce qui est
                  // entré dans le camp.
                  if (p.accompagne) ...[
                    const SizedBox(width: 8),
                    StatusChip(
                      label: '+${p.nombreAccompagnants}',
                      level: AlertLevel.info,
                    ),
                  ],
                  if (p.avecVehicule) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                'Reçu par ${p.nomRecu} · Badge ${p.couleurBadge.label} · Arrivée le ${df.format(p.dateArrivee)}'
                '${p.dateSortie != null ? ' · Sortie le ${df.format(p.dateSortie!)}' : ''}'
                '${p.avecVehicule ? '\nVéhicule ${p.vehiculeImmatriculation}'
                          '${p.vehiculeDescription != null ? ' — ${p.vehiculeDescription}' : ''}' : ''}'
                '${p.accompagnants != null ? '\nAccompagné de : ${p.accompagnants}' : ''}',
              ),
              isThreeLine: true,
              trailing: p.enCours
                  ? OutlinedButton(
                      onPressed: _sortiesEnCours.contains(p.id)
                          ? null
                          : () => _enregistrerSortie(p),
                      child: _sortiesEnCours.contains(p.id)
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer la sortie'),
                    )
                  : StatusChip(label: 'Sorti', level: AlertLevel.info),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
