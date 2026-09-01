import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suivi centralisé du "premier chargement terminé" par source de données
/// (une clé par notifier Supabase). Permet aux écrans d'afficher un skeleton
/// tant que les données n'ont jamais été chargées, sans changer la forme des
/// providers de liste existants (qui restent de simples `List<T>`).
class ChargementNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void marquerCharge(String cle) {
    if (!state.contains(cle)) state = {...state, cle};
  }
}

final chargementProvider = NotifierProvider<ChargementNotifier, Set<String>>(
  ChargementNotifier.new,
);

/// true dès que toutes les [cles] ont été chargées au moins une fois.
bool estCharge(WidgetRef ref, List<String> cles) {
  final charges = ref.watch(chargementProvider);
  return cles.every(charges.contains);
}
