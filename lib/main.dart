import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/env.dart';
import 'core/push.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En parallèle plutôt qu'en séquence — réduit le délai avant le premier
  // frame Flutter.
  await Future.wait([
    // La tablette reste en paysage : c'est l'orientation dans laquelle les
    // tableaux et les formulaires de l'ERP ont été dessinés. Sans effet sur
    // le poste de travail Windows.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
    initializeDateFormatting('fr_FR'),
    initSupabase(),
    // Les notifications poussées : Android seulement, et sans bloquer le
    // démarrage si Firebase n'est pas joignable.
    Push.preparer(),
  ]);
  // Enregistrer le gestionnaire d.arrière-plan sur Windows lèverait : le
  // greffon n.y a pas d.implémentation.
  if (Push.supporte) {
    FirebaseMessaging.onBackgroundMessage(gestionnaireArrierePlan);
  }
  runApp(const ProviderScope(child: SigEnsoaApp()));
}

class SigEnsoaApp extends ConsumerWidget {
  const SigEnsoaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Toujours clair, quel que soit le réglage du système.
      //
      // L'application de la scolarité n'avait pas de thème sombre du tout, et
      // le cadre repris de la tablette peint ses surfaces en dur — carte
      // blanche, texte encre. Sous un système en mode sombre, les écrans qui
      // prennent leurs couleurs du thème écrivaient donc en blanc sur blanc.
      // Un vrai mode sombre demanderait de reprendre les deux jeux d'écrans ;
      // ce n'est pas le sujet aujourd'hui.
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routeurProvider),
    );
  }
}
