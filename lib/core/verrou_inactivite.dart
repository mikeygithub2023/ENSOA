import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';

/// Ferme la session après une période sans geste — nécessaire pour une
/// tablette posée en zone commune (mess, poste de garde) : celui qui la
/// reprend ne doit pas hériter de la session du précédent.
///
/// Repris tel quel de l'application tablette.
class VerrouInactivite extends ConsumerStatefulWidget {
  const VerrouInactivite({
    super.key,
    required this.child,
    this.delai = const Duration(minutes: 5),
  });

  final Widget child;
  final Duration delai;

  @override
  ConsumerState<VerrouInactivite> createState() => _VerrouInactiviteState();
}

class _VerrouInactiviteState extends ConsumerState<VerrouInactivite> {
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _relancer();
  }

  void _relancer() {
    _minuterie?.cancel();
    _minuterie = Timer(widget.delai, () {
      ref.read(authRepositoryProvider).deconnexion();
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _relancer(),
      onPointerMove: (_) => _relancer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
