import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/erreurs.dart';
import '../../core/identite.dart';
import '../../core/theme.dart';
import 'providers/auth_providers.dart';

/// Imposé à la première connexion. Tant que le mot de passe posé par celui
/// qui a ouvert le compte n'a pas été remplacé, l'application ne donne accès
/// à rien d'autre que cet écran.
class ChangerMotDePasseScreen extends ConsumerStatefulWidget {
  const ChangerMotDePasseScreen({super.key});

  @override
  ConsumerState<ChangerMotDePasseScreen> createState() =>
      _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState
    extends ConsumerState<ChangerMotDePasseScreen> {
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!validerFormulaire(context, _formKey)) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .changerMotDePasse(actuel: _actuel.text, nouveau: _nouveau.text);
      ref.invalidate(profilCourantProvider);
    } catch (e) {
      // Le serveur répond « invalid credentials » quand le mot de passe
      // actuel est faux. Tel quel, le message désigne la mauvaise chose :
      // l'agent croit que c'est son NOUVEAU mot de passe qui est refusé, et
      // en essaie d'autres jusqu'à renoncer.
      final texte = '$e'.toLowerCase();
      final actuelFaux =
          texte.contains('invalid') ||
          texte.contains('incorrect') ||
          texte.contains('credential');
      setState(
        () => _erreur = actuelFaux
            ? 'Mot de passe actuel incorrect.'
            : 'Changement impossible : ${messageErreur(e)}',
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              color: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choisissez votre mot de passe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Celui qui a ouvert votre compte connaît encore le mot "
                        "de passe actuel. Remplacez-le avant d'aller plus loin.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 24),
                      // Le mot de passe actuel. Il prouve que celui qui est
                      // devant l'écran est bien le titulaire du compte, et
                      // non quelqu'un qui a trouvé la tablette ouverte ou
                      // rejoué une session. Sans lui, un jeton dérobé — il
                      // vaut plusieurs jours — suffisait à s'approprier le
                      // compte pour de bon.
                      //
                      // Pour un compte qu'un administrateur vient de
                      // débloquer, c'est le mot de passe provisoire qu'il
                      // a remis.
                      TextFormField(
                        controller: _actuel,
                        obscureText: true,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe actuel',
                          prefixIcon: Icon(Icons.lock_person_outlined),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Saisissez votre mot de passe actuel'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nouveau,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null ||
                              v.length < Identite.longueurMinimaleMotDePasse) {
                            return '${Identite.longueurMinimaleMotDePasse} caractères minimum';
                          }
                          // Remplacer un mot de passe par lui-même n'est pas
                          // un changement, et laisserait le compte marqué
                          // « à changer » alors qu'il ne l'est plus.
                          if (v == _actuel.text) {
                            return 'Choisissez un mot de passe différent';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        onFieldSubmitted: (_) => _valider(),
                        decoration: const InputDecoration(
                          labelText: 'Confirmation',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (v) => v != _nouveau.text
                            ? 'Les deux saisies diffèrent'
                            : null,
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _enCours ? null : _valider,
                        child: _enCours
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Valider'),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).deconnexion(),
                        child: const Text('Se déconnecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
