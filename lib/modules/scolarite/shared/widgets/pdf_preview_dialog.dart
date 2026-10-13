import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:sig_ensoa/core/theme.dart' hide AlertLevel, AlertLevelColor;

/// Aperçu avant impression, commun à tous les documents PDF générés dans
/// l'application (permissions, bulletins...) — affiche [bytes] dans une
/// boîte de dialogue avec le contrôle d'impression natif fourni par
/// [PdfPreview].
Future<void> showPdfPreviewDialog(BuildContext context, Uint8List bytes) {
  final screenSize = MediaQuery.of(context).size;
  final width = screenSize.width - 48 < 900 ? screenSize.width - 48 : 900.0;
  final height = screenSize.height - 48 < 900 ? screenSize.height - 48 : 900.0;

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Aperçu avant impression',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) async => bytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                // Le bouton « partager » du greffon est actif par défaut.
                // Il écrit le document entier en clair dans le cache de
                // l'application, sans jamais l'effacer, puis l'ouvre à
                // l'application choisie — WhatsApp, Drive personnel. Un
                // bulletin, une liste nominative ou une demande de
                // pharmacie sortaient ainsi d'un geste, sans laisser la
                // moindre trace côté serveur : exactement ce que
                // FLAG_SECURE et le journal d'audit sont là pour empêcher.
                //
                // Cette boîte sert sept écrans ; la ligne les couvre tous.
                allowSharing: false,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
