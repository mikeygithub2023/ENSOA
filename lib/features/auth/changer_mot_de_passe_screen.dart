import 'package:sig_ensoa/core/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
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
      await ref.read(authRepositoryProvider).changerMotDePasse(_nouveau.text);
      ref.invalidate(profilCourantProvider);
    } catch (e) {
      setState(() => _erreur = 'Changement impossible : $e');
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
                      TextFormField(
                        controller: _nouveau,
                        obscureText: true,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null ||
                                v.length < Identite.longueurMinimaleMotDePasse)
                            ? '${Identite.longueurMinimaleMotDePasse} caractères minimum'
                            : null,
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
