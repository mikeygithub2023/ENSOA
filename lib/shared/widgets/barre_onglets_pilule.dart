import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Les grandes rubriques d'un regroupement, en bandeau segmenté : indicateur
/// plein sur fond clair. Les sous-rubriques qu'elles contiennent, elles, sont
/// soulignées, pour qu'on lise d'un coup d'œil le niveau où l'on se trouve.
class BarreOngletsPilule extends StatelessWidget {
  const BarreOngletsPilule({
    super.key,
    required this.libelles,
    this.controller,
  });

  final List<String> libelles;

  /// Sans lui, la barre suit le `DefaultTabController` au-dessus d'elle.
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blueMist,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: [for (final libelle in libelles) Tab(text: libelle)],
      ),
    );
  }
}
