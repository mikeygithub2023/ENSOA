import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sig_ensoa/modules/logistique/data/models/carburant.dart';
import 'package:sig_ensoa/modules/logistique/data/repositories/fuel_providers.dart';

/// Ce que la carte d'une soute doit montrer, et dans quel ordre.
///
/// Trois règles s'y croisent, et elles se contredisent si on les traite d'un
/// seul filtre :
///
///   - une répartition supprimée laisse sa ligne en base — les mouvements
///     qu'elle porte doivent rester lisibles — mais elle ne compte plus dans
///     l'état courant de la soute ;
///   - « Activités Ordinaires » vient en tête : c'est ce qui attend d'être
///     réparti, avant ce qui est déjà affecté ;
///   - la répartition d'accueil ne figure pas dans la liste des
///     répartitions, qui ne liste que les allocations.
///
/// Les notificateurs interrogent Supabase dès leur construction : on les
/// remplace par des listes fixes, sinon le test parlerait au réseau.
class _SoutesFigees extends SoutesNotifier {
  @override
  List<Soute> build() => const [Soute(id: '1', libelle: 'Soute Bouaké')];
}

class _StocksFiges extends SouteStocksNotifier {
  @override
  List<SouteStock> build() => const [
    // « AB1 » est nommée pour passer avant « Activités Ordinaires » si le
    // tri était purement alphabétique, et placée avant elle dans la liste
    // d'entrée pour qu'un simple ordre d'arrivée ne suffise pas non plus.
    SouteStock(
      id: '12',
      souteId: '1',
      typeStockId: '',
      repartitionId: '300',
      repartitionLibelle: 'AB1',
      qteGasoil: 500,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
    SouteStock(
      id: '10',
      souteId: '1',
      typeStockId: '',
      repartitionId: '100',
      repartitionLibelle: 'Activités Ordinaires',
      qteGasoil: 3000,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
    // BA2 a été supprimée : sa ligne survit, vidée, parce qu'une
    // distribution la désigne encore.
    SouteStock(
      id: '11',
      souteId: '1',
      typeStockId: '',
      repartitionId: '200',
      repartitionLibelle: 'BA2',
      repartitionSupprimee: true,
      qteGasoil: 0,
      qteSuper: 0,
      seuilNominal: 0,
      seuilCritique: 0,
    ),
  ];
}

class _RepartitionsFigees extends RepartitionsNotifier {
  @override
  List<Repartition> build() => const [
    Repartition(id: '100', libelle: 'Activités Ordinaires'),
    Repartition(id: '300', libelle: 'AB1'),
  ];
}

class _DistributionsFigees extends DistributionsNotifier {
  @override
  List<Distribution> build() => [
    Distribution(
      id: '1',
      souteStockId: '11', // la ligne de la répartition supprimée
      utilisateurId: 'u1',
      quantitePercue: 40,
      date: DateTime(2026, 3, 2),
      typeCarburant: 'Gasoil',
      destinataire: 'SLT Koné',
    ),
  ];
}

void main() {
  late ProviderContainer conteneur;

  setUp(() {
    conteneur = ProviderContainer(
      overrides: [
        soutesProvider.overrideWith(_SoutesFigees.new),
        souteStocksProvider.overrideWith(_StocksFiges.new),
        repartitionsProvider.overrideWith(_RepartitionsFigees.new),
        distributionsProvider.overrideWith(_DistributionsFigees.new),
      ],
    );
    addTearDown(conteneur.dispose);
  });

  test('la soute ne montre plus la répartition supprimée ni ses litres', () {
    final groupe = conteneur.read(soutesRegroupeesProvider).single;

    expect(groupe.repartitions.map((r) => r.repartitionLibelle), [
      'Activités Ordinaires',
      'AB1',
    ]);
    expect(groupe.quantiteTotale, 3500);
  });

  test('la répartition d\'accueil vient en tête de la soute', () {
    final groupe = conteneur.read(soutesRegroupeesProvider).single;

    // Elle n'est ni première dans la liste d'entrée, ni première par ordre
    // alphabétique : seule la règle peut l'avoir mise là.
    expect(groupe.repartitions.first.repartitionLibelle, 'Activités Ordinaires');
  });

  test('on ne distribue plus depuis une répartition supprimée', () {
    final lignes = conteneur.read(soutesAvecStockProvider);

    expect(
      lignes.map((v) => v.stock.repartitionLibelle),
      containsAll(['Activités Ordinaires', 'AB1']),
    );
    expect(lignes.map((v) => v.stock.repartitionLibelle), isNot(contains('BA2')));
  });

  test('la répartition d\'accueil ne paraît pas dans la liste', () {
    final liste = conteneur.read(repartitionsAvecSoutesProvider);

    // Elle naît avec la soute et personne ne la gère : la lister parmi les
    // allocations laisserait croire qu'on peut la renommer ou la supprimer.
    expect(liste.map((r) => r.repartition.libelle), ['AB1']);
  });

  test('la distribution déjà enregistrée garde le nom de BA2', () {
    final vue = conteneur.read(distributionsAvecLibellesProvider).single;

    expect(vue.repartitionLibelle, 'BA2');
    expect(vue.souteLibelle, 'Soute Bouaké');
  });
}
