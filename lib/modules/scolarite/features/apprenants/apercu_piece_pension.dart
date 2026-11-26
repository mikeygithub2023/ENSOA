// Revoir une pièce numérisée du dossier de pension, sans quitter l'écran.
//
// Une image s'affiche telle quelle ; un PDF passe par l'aperçu de la
// bibliothèque d'impression, qui sait déjà le rendre — page à page, avec
// l'impression et le partage. Aucune dépendance de plus.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:sig_ensoa/core/erreurs.dart';
import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;

/// Ce que l'aperçu rend au moment de se fermer.
enum ChoixApercu { fermer, remplacer }

/// Montre le scan [nom]. [charger] en lit les octets — depuis le dépôt, ou
/// depuis le fichier qu'on vient de choisir et qui n'est pas encore envoyé.
///
/// [peutRemplacer] ajoute le bouton « Remplacer » ; l'appelant choisit alors
/// le nouveau fichier.
Future<ChoixApercu> showApercuPiecePension(
  BuildContext context, {
  required String titre,
  required String nom,
  required Future<Uint8List> Function() charger,
  bool peutRemplacer = false,
}) async {
  final choix = await showDialog<ChoixApercu>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: _Apercu(
        titre: titre,
        nom: nom,
        charger: charger,
        peutRemplacer: peutRemplacer,
      ),
    ),
  );
  return choix ?? ChoixApercu.fermer;
}

bool _estPdf(String nom) => nom.toLowerCase().endsWith('.pdf');

class _Apercu extends StatefulWidget {
  const _Apercu({
    required this.titre,
    required this.nom,
    required this.charger,
    required this.peutRemplacer,
  });

  final String titre;
  final String nom;
  final Future<Uint8List> Function() charger;
  final bool peutRemplacer;

  @override
  State<_Apercu> createState() => _ApercuState();
}

class _ApercuState extends State<_Apercu> {
  late final Future<Uint8List> _octets = widget.charger();

  Future<void> _enregistrerSurLePoste(Uint8List octets) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la pièce',
        fileName: widget.nom,
        bytes: octets,
      );
    } catch (e) {
      messager.showSnackBar(
        SnackBar(
          content: Text('Enregistrement impossible : ${messageErreur(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.of(context).size;
    final largeur = taille.width - 48 < 900 ? taille.width - 48 : 900.0;
    final hauteur = taille.height - 48 < 800 ? taille.height - 48 : 800.0;

    return SizedBox(
      width: largeur,
      height: hauteur,
      child: FutureBuilder<Uint8List>(
        future: _octets,
        builder: (context, instantane) {
          final octets = instantane.data;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.titre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            widget.nom,
                            style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                      onPressed: () =>
                          Navigator.of(context).pop(ChoixApercu.fermer),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: switch (instantane.connectionState) {
                  ConnectionState.done when instantane.hasError => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "La pièce n'a pas pu être lue : "
                        '${messageErreur(instantane.error!)}',
                        style: const TextStyle(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  ConnectionState.done when octets != null =>
                    _estPdf(widget.nom)
                        ? PdfPreview(
                            build: (_) async => octets,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            pdfFileName: widget.nom,
                          )
                        : InteractiveViewer(
                            maxScale: 5,
                            child: Center(
                              child: Image.memory(
                                octets,
                                errorBuilder: (_, _, _) => const Text(
                                  "Ce fichier n'est pas une image lisible.",
                                  style: TextStyle(color: AppColors.danger),
                                ),
                              ),
                            ),
                          ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.peutRemplacer)
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(ChoixApercu.remplacer),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Remplacer'),
                      ),
                    OutlinedButton.icon(
                      onPressed: octets == null
                          ? null
                          : () => _enregistrerSurLePoste(octets),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Enregistrer sur le poste'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(ChoixApercu.fermer),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
