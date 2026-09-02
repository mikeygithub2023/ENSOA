import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'theme.dart';

/// Valide un formulaire, et le fait savoir autrement que par un liseré rouge.
///
/// `Form.validate()` marque les champs fautifs en rouge — ce qui suppose
/// qu'on les ait sous les yeux. Sur une tablette, un formulaire tient
/// rarement sur un écran : on appuie sur « Enregistrer », rien ne se passe,
/// et le champ qui manque est trois écrans plus haut, sous le clavier. Deux
/// signaux s'ajoutent donc : une vibration, qui dit qu'il s'est passé
/// quelque chose, et un bandeau qui NOMME le champ.
///
/// Le nom du champ n'est pas déclaré à la main : il est retrouvé dans
/// l'arbre. On descend depuis le formulaire jusqu'au premier champ en
/// erreur, puis on cherche sous lui le `InputDecorator` qui porte son
/// libellé. C'est un détour, mais il vaut mieux qu'une liste de libellés
/// recopiée dans vingt-six fichiers, qui mentirait au premier renommage.
bool validerFormulaire(BuildContext context, GlobalKey<FormState> cle) {
  final etat = cle.currentState;
  if (etat == null || etat.validate()) return true;

  HapticFeedback.vibrate();

  final champ = _premierChampEnErreur(cle.currentContext);
  final message = champ == null
      ? 'Il manque un champ obligatoire.'
      : 'Il manque : $champ';

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

  return false;
}

/// Le libellé du premier champ en erreur, ou son message de validation à
/// défaut de libellé. Nul si l'on n'a rien su lire — le formulaire dira
/// alors « il manque un champ obligatoire », ce qui vaut mieux que rien.
String? _premierChampEnErreur(BuildContext? contexteDuFormulaire) {
  if (contexteDuFormulaire is! Element) return null;

  String? trouve;

  void visiter(Element element) {
    if (trouve != null) return;

    if (element is StatefulElement && element.state is FormFieldState) {
      final champ = element.state as FormFieldState;
      if (champ.hasError) {
        trouve = _libelleSousLeChamp(element) ?? champ.errorText;
        return;
      }
    }
    element.visitChildren(visiter);
  }

  contexteDuFormulaire.visitChildren(visiter);
  return trouve;
}

/// Le libellé affiché d'un champ. `TextFormField` garde sa décoration dans
/// une fermeture, hors d'atteinte ; mais il finit par construire un
/// `InputDecorator`, dont la décoration, elle, est publique.
String? _libelleSousLeChamp(Element champ) {
  String? libelle;

  void chercher(Element element) {
    if (libelle != null) return;

    final widget = element.widget;
    if (widget is InputDecorator) {
      final d = widget.decoration;
      libelle = d.labelText ?? d.hintText;
      if (libelle != null) return;
    }
    element.visitChildren(chercher);
  }

  champ.visitChildren(chercher);
  return libelle;
}
