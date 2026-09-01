import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/erreurs.dart';
import '../../core/theme.dart';
import 'providers/auth_providers.dart';

/// Écran de connexion repris tel quel de l'application tablette : panneau de
/// gauche aux armoiries, formulaire à droite. Seul le second champ change —
/// le code PIN cède la place à un mot de passe.
class ConnexionScreen extends ConsumerStatefulWidget {
  const ConnexionScreen({super.key});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> {
  final _matriculeCtrl = TextEditingController();
  final _motDePasseCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _localAuth = LocalAuthentication();

  bool _loading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _matriculeCtrl.dispose();
    _motDePasseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .connexion(
            matricule: _matriculeCtrl.text.trim(),
            motDePasse: _motDePasseCtrl.text,
          );
      // Le routeur prend le relais dès que la session s'ouvre.
    } catch (erreur) {
      if (!mounted) return;

      // Une panne de réseau n'est pas une faute de saisie : elle passe en
      // message furtif, sans rien à corriger sous le formulaire. Et surtout
      // sans le détail technique — « Failed host lookup », l'adresse du
      // serveur — qui n'apprend rien à qui tient la tablette.
      if (estProblemeReseau(erreur)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serveur injoignable. Vérifiez la connexion.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _errorMessage = null);
        return;
      }

      // Un refus d'identifiants, lui, reste sous le formulaire : il demande
      // une correction. On ne distingue pas « identifiant inconnu » de « mot
      // de passe faux » — le faire dirait à un inconnu quels identifiants
      // existent.
      setState(
        () => _errorMessage = erreur is AuthException && erreur.statusCode == '400'
            ? 'Identifiant ou mot de passe incorrect. Vérifiez la saisie '
                  '(le clavier a pu corriger le texte).'
            : messageErreur(erreur),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _biometricUnlock() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        setState(
          () => _errorMessage = 'Biométrie non disponible sur cet appareil.',
        );
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authentification biométrique — SIG ENSOA',
      );
      if (ok && _matriculeCtrl.text.trim().isNotEmpty) {
        // La biométrie déverrouille l'accès local ; l'identité reste vérifiée
        // par le matricule et le mot de passe saisis.
        await _submit();
      }
    } catch (_) {
      setState(
        () => _errorMessage = 'Authentification biométrique indisponible.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 800)
            Expanded(
              child: Container(
                color: AppColors.militaryGreen,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/armoiries_ci.png',
                        height: 140,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                      const SizedBox(height: 24),
                      Image.asset(
                        'assets/images/logo_ensoa.png',
                        height: 90,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "ÉCOLE NATIONALE DES SOUS-OFFICIERS D'ACTIVE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Système de Gestion Intégrée de L'ENSOA",
                        style: TextStyle(color: AppColors.gold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment: const Alignment(0, -0.35),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Connexion',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Identifiez-vous avec votre identifiant et votre mot de passe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 96),
                        TextFormField(
                          controller: _matriculeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _motDePasseCtrl,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Se connecter'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _biometricUnlock,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Déverrouiller par biométrie'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Accès réservé au personnel autorisé de l'ENSOA. Toute tentative non autorisée est journalisée.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
