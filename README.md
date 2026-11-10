# SIG ENSOA

ERP de l'École Nationale des Sous-Officiers d'Active. Scolarité, soutien
technique, santé et armement tiennent dans une seule application Flutter,
adossée à une base Supabase unique (schémas `socle`, `scolarite`,
`logistique`).

- Déploiement : [DEPLOIEMENT.md](DEPLOIEMENT.md)
- Base de données et migrations : [supabase/README.md](supabase/README.md)

```bash
flutter analyze && flutter test
```

---

# Journal

## 6 novembre 2026 — le menu se resserre

Quatre chantiers, un même fil : **une seule place par sujet**. L'application
avait grandi par ajouts successifs, et le même objet se retrouvait derrière
deux entrées de menu qui ne disaient pas tout à fait la même chose.

Le regroupement se fait toujours **par permission, jamais par rôle** : une
entrée est masquée pour qui voit déjà la même chose ailleurs, regroupée. Le
super administrateur tient donc la scolarité sous une rubrique à onglets,
tandis que l'instructeur garde ses entrées séparées — sans que personne n'ait
à rouvrir `nav_items.dart` chaque fois qu'un rôle s'ajoute.

### Un seul tableau de bord, derrière le premier bouton (`1f1d29e`)

L'accueil et le tableau de bord se répétaient **et se contredisaient**. Ils se
lisent désormais sur une seule page, et le deuxième bouton du menu disparaît.

Trois défauts corrigés au passage, tous les trois des chiffres faux — ce qui
est pire qu'un chiffre absent :

| Défaut | Ce qu'on voyait |
|---|---|
| Les compteurs d'accueil incluaient les véhicules, armes et munitions **supprimés** | 16/27 au lieu de 12/22 |
| La carte « carburant du jour » cumulait **tout l'historique** | un chiffre qui ne baissait jamais |
| L'icône du fusil | réduite à un trait |

La carte carburant traînait depuis un moment : elle avait été signalée sans
être reprise, faute d'occasion. L'occasion était là.

### La scolarité en une seule rubrique (`071d2ee`)

Élèves et stagiaires, cours, matières et bulletins passent sous une entrée
**Scolarité** à onglets, comme le soutien technique l'était déjà. Les autres
postes gardent leurs entrées de menu.

### La santé en une seule rubrique (`fcbd261`)

Consultations, visites médicales, pharmacie et dépenses passent sous une
entrée **Santé**. Le médecin, lui, garde ses entrées séparées : c'est son
métier entier, pas une rubrique parmi d'autres.

Le cadre à onglets, écrit pour la scolarité, est devenu commun
(`lib/shared/widgets/rubrique_a_onglets.dart`) : deux rubriques qui se
ressemblent et qu'on fait vivre séparément finissent par ne plus se
ressembler.

### Une seule page Tâches, et les tâches quotidiennes (`dc4d8a4`)

Activités, Tâches de l'équipe et Mes tâches se réunissent sous un seul menu.
La page présente ensemble les tâches rattachées à une activité et une
**nouvelle liste quotidienne**, que chacun tient pour soi ou qu'un
administrateur impute à une personne.

Nouvelle table `logistique.tache_quotidienne`
(migration `20261106000000_…_028_taches_quotidiennes.sql`), avec ses
politiques de sécurité par ligne : on tient ses propres tâches, un
administrateur tient celles de tout le monde.

### Les tâches quotidiennes, suite

La table venait d'être créée et **l'API ne la voyait pas** : PostgREST tient
un cache du schéma, qu'une nouvelle table ne suffit pas à rafraîchir. La
migration se termine maintenant par `notify pgrst, 'reload schema'`.

Et surtout — c'est le correctif qui compte — l'échec de lecture **se dit à
l'écran** au lieu d'afficher une liste vide. Une liste vide est une réponse :
« vous n'avez rien à faire aujourd'hui ». Ce n'était pas la réponse. Les
tâches d'activité, qui se chargent à part, ne sont plus privées d'affichage
par cet échec.

### Le soutien technique rendu entier

Le regroupement du matin avait une suite fâcheuse. « Soutien technique »
masque les trois entrées de menu séparées — Garage, Carburant, Armement — et
n'en montrait que les **tableaux de bord**. Le Garage, lui, donnait son espace
complet à onglets. Les deux autres services étaient donc **fermés au
commandant** : il en avait le droit, plus le chemin.

Chacun porte maintenant son espace entier, et chacun ouvre sur son tableau de
bord, comme le Garage :

| Service | Onglets |
|---|---|
| Garage | Tableau de bord · Liste des véhicules · Ordres de mission · Demandes de réparation · Réparations |
| Soutien pétrolier | Tableau de bord · Soute · Dépotage · Ventilation · Répartitions · Distributions |
| Armurerie | Tableau de bord · Armement · Munitions · Équipements |

Le tableau de bord entre aussi dans `/logistique/carburant` et
`/logistique/armement` : les chefs de service y gagnent la même entrée en
matière que le garagiste.

Trois niveaux d'onglets se superposent alors dans l'armurerie — le service, la
rubrique, la sous-rubrique. Chacun a son dessin pour qu'on lise d'un coup
d'œil celui qu'on manœuvre : bandeau-pilule, onglets soulignés, onglets
soulignés plus menus et bleus. L'armement bascule du bandeau-pilule aux
onglets soulignés quand il est emboîté : le niveau le plus haut est déjà pris
par les trois services.

### Le menu dit son nom

Une icône seule se devine ; elle ne se lit pas. L'infobulle, elle, oblige à
s'arrêter dessus et ne paraît jamais au doigt. Dès que la fenêtre dépasse 900
pixels de large, chaque entrée écrit donc son nom à côté de son icône ; en
dessous — téléphone, petite tablette — la barre se referme sur ses icônes et
l'infobulle reprend son office : la place y vaut mieux au contenu.

L'entrée ouverte se peint en pilule foncée, nom en blanc. Elle avait d'abord
disparu : la pilule se dessinait avec `Ink`, dont la décoration va sur la
couche d'encre du `Material` — c'est-à-dire **sous** le fond opaque de la
barre. Texte blanc sur blanc. Elle se peint maintenant sur place, dans un
`Container`, le `Material` transparent ne gardant que l'onde au toucher.

L'entrée `/logistique/taches` s'appelle désormais **Activités** — le nom de ce
qu'on y organise — et remonte juste avant le **Poste de Police**. Elle fermait
la marche, loin de ce à quoi elle sert. Le rail parcourt `elementsNav` dans
l'ordre de déclaration : c'est en déplaçant la déclaration qu'on déplace le
bouton.

### L'application de bureau vide son cache avant d'ouvrir

Deux caches retiennent la PWA sur le poste : celui du moteur web
(`DiskCache`) et celui du service worker (`CacheStorage`). Tant qu'ils
gardent l'ancienne version, un déploiement passe inaperçu — c'est ce qui est
arrivé ce matin, où il a fallu les effacer à la main sur le poste du
commandant.

`windows-pwa/FenetrePrincipale.cs` les efface maintenant au lancement, avant
de charger la page. Deux précautions :

- **la session reste ouverte.** On n'efface que ces deux caches ; les cookies
  et le stockage local — où vit la session Supabase — ne sont pas touchés.
- **hors réseau, on n'efface rien.** Le cache du service worker est alors
  tout ce qui permet encore d'ouvrir l'application. Un appel `HEAD` de deux
  secondes dit si le serveur répond ; s'il ne répond pas, on ouvre sans
  effacer.

Le prix : environ 6 Mo retéléchargés à chaque lancement sur un poste
connecté. Sur le réseau de l'école c'est une seconde ou deux, et cela vaut
mieux qu'une version périmée qu'on ne voit pas.

### Le sport dit la performance, pas seulement la note

La fiche de l'apprenant n'affichait que « 14 / 20 » par séance. Or cette note
est une lecture du barème : elle donne le rang, pas ce qui a été fait. Chaque
séance porte maintenant la performance sous son nom, dans l'unité de son
activité — `12′30″` pour un chrono, `12 rép.` pour une traction. Le calcul
de la note ne change pas.

Séance et performance ne se rejoignent par aucune clé étrangère : toutes deux
pendent du sous-module. `SportRepository.fetchPerformancesApprenant` les
rapproche en deux requêtes, et `performancesParSeance` met en forme —
fonction pure, donc vérifiable sans base (`test/sport_performance_test.dart`).
Une séance dont l'activité a disparu du catalogue est laissée de côté : sans
unité, un nombre nu induirait en erreur.

L'élève voit la même chose sur son propre profil : `MonProfilScreen` réutilise
`ApprenantDetailView`.

## 10 novembre 2026

### L'import porte toute la fiche, et non plus l'état civil seul

Le modèle d'import ne prenait que nom, prénoms, sexe, téléphone, date et lieu
de naissance. La fiche de renseignement de l'école en porte bien davantage, et
l'application sait déjà tout stocker : douze colonnes se sont donc ajoutées à
la suite des précédentes — situation matrimoniale, enfants, père, mère,
e-mail, groupe sanguin, taille, poids, personne à prévenir, lien de parenté,
téléphone à prévenir, diplôme. Elles sont facultatives, et **un fichier écrit
pour l'ancien modèle reste lisible** : il s'arrête simplement plus tôt.

Ce qu'une cellule veut dire se lit dans `import_valeurs.dart`, à part du
dialogue et donc vérifiable (`test/import_apprenants_valeurs_test.dart`). La
règle y est la même partout : devant une valeur qu'on ne comprend pas, on rend
`null` plutôt que de trancher. Une case vide se complète ; une case fausse se
croit. « 1,73 M » et « 173 » donnent tous deux 173 cm — sous trois, la cellule
parle en mètres, personne ne mesure deux centimètres.

`outils/scinder_fiche_renseignement.py` découpe une fiche de promotion en un
classeur par division. Deux pièges s'y sont révélés, propres aux classeurs
écrits par openpyxl et non par Excel : la feuille y est désignée par un chemin
absolu que le lecteur de l'application ne sait pas suivre, et une cellule vide
s'y écrit `<c t="inlineStr" />`, forme sur laquelle il s'arrête net. Le script
corrige les deux. Le dialogue, lui, dit maintenant quoi faire quand un fichier
le déroute — le rouvrir dans Excel et l'y enregistrer à nouveau — au lieu de
rapporter « Null check operator used on a null value ».

### Le NOM avant le prénom

L'apprenant se lisait « ATSE ALEX AMIRAL ABE » : il fallait chercher le
patronyme au bout de trois ou quatre prénoms — la 37e promotion en compte qui
en portent quatre. C'est désormais « ABE ATSE ALEX AMIRAL », le nom d'usage
militaire, celui par lequel on appelle au rapport et par lequel les listes de
l'école sont tenues.

Un seul endroit construisait ce libellé, `Apprenant.nomComplet` : la liste,
les fiches, les feuilles de séance, les bulletins et les listes imprimées en
héritent d'un coup. Le tri des listes imprimées se faisait déjà par nom puis
prénom, et l'initiale de la pastille suit maintenant la même lettre que la
ligne.

`Profil` porte la même règle depuis toujours dans `nomDUsage`, mais son
`nomComplet` — celui que lit l'écran Administration — reste dans l'autre
ordre. À aligner le jour où l'on voudra la même lecture pour les comptes.

### Le grade suit la phase, et la division qui la donne

La Formation Commune de Base se fait des deux côtés de l'école. La règle
écrite le 1er septembre ne regardait que le nom de la phase : « FCB » donnait
« élève sous-officier d'active de première année » à tout le monde, spécialistes
compris. La division tranche désormais, dans l'application comme dans la base
(migration `20261110000000`), et la migration corrige au passage les élèves
déjà enregistrés sous le mauvais grade.

### La scolarité se partage entre deux bureaux

Proposition faite au commandement, et portée dans l'application : la scolarité
n'est pas un bureau mais deux.

- **Instruction** tient la notation — cours, matières, modules, contrôle
  continu, examens, bulletins, et les **résultats** qui s'en déduisent.
- **Ressources humaines** tiennent la personne — situation de prise d'armes,
  statistiques de l'effectif **sans les notes**, consultations, permissions,
  absences.

L'écran de l'effectif portait sept onglets pour tout le monde ; chacun n'y
avait affaire qu'à trois ou quatre. C'est le même écran, le même choix de
portée et la même liste nominative — qui reste aux deux bureaux, car c'est par
elle qu'on ouvre la fiche d'un élève —, mais le jeu d'onglets suit désormais le
bureau où l'on se trouve (`bureaux.dart`). Rien n'est retiré à personne : les
permissions ne bougent pas, seul le rangement change.

Le service **Santé** sort du même mouvement. Ses quatre écrans étaient logés
sous « Scolarité » faute de section à eux, alors qu'ils ne relèvent ni de l'un
ni de l'autre bureau. L'onglet « Consultations médicales » des RH reste la
lecture de ce que le service y a saisi.

La barre de gauche, elle, ne change pas d'allure. On avait essayé d'y écrire le
nom de chaque section au-dessus de ses entrées — `SectionNav` n'existait
jusqu'ici qu'en commentaire, sans rien afficher. Essayé et retiré : les
intertitres hachaient la lecture plus qu'ils n'éclairaient, et une colonne
d'icônes et de noms n'est pas un organigramme. La section reste la vérité de
rangement du menu, et `sectionsVues` permet de la vérifier en test plutôt qu'à
l'œil.

Chemins : `/instruction` (la rubrique groupée de l'administrateur, ex
`/scolarite/rubrique`) et `/ressources-humaines`. `/scolarite/apprenants` ne
bouge pas : il porte les fiches élèves et les contrôles en sous-routes.

### Les fiches importées à moitié, et comment on les complète

Les 203 élèves de la 37e promotion ont été importés à 16 h par la version de
l'application qui ne lisait encore que **sept colonnes** — matricule, nom,
prénoms, sexe, téléphone, date et lieu de naissance. La version qui lit les
douze suivantes (filiation, contact d'urgence, données médicales, diplôme) est
partie en production à 16 h 02 : l'import l'avait précédée de peu. Le tableur
portait tout, l'application n'en a retenu que le début — ce qui se voit à
l'œil sur une fiche, coupée net après « Lieu de naissance ».

Plutôt que de supprimer puis réimporter 203 fiches,
`outils/completer_fiches_depuis_import.py` relit les mêmes classeurs et écrit
le SQL qui complète celles qui sont là. Trois instructions, sans table
temporaire : l'éditeur SQL du tableau de bord Supabase valide chaque
instruction à part, et une table temporaire — même `on commit drop` — ne passe
pas de l'une à l'autre. Les valeurs sont donc écrites en toutes lettres dans
chacune, qui se suffit à elle-même et se relance sans dommage. Le fichier
produit est relu par le parseur de PostgreSQL (`pglast`) avant d'être remis. Il reprend à l'identique les règles de
lecture de `import_valeurs.dart` — même normalisation de la taille, du groupe
sanguin, de la situation matrimoniale — et le SQL produit ne remplit que ce
qui est **vide** : une case corrigée à la main depuis l'import n'est pas
écrasée. Il se borne aux phases visées, et peut être rejoué.

Au passage : la fiche écrivait « Née le » à tout le monde. Elle écrit « Né(e)
le ».

### État à la fin de la journée

- `flutter analyze` : aucun avertissement
- **177 tests** passent, dont `test/bureaux_scolarite_test.dart`, né de ce
  découpage
- **147 tests** passaient dans la journée, dont cinq fichiers nés aujourd'hui :
  `test/tableau_de_bord_test.dart`, `test/taches_test.dart`,
  `test/soutien_technique_onglets_test.dart`, `test/menu_libelles_test.dart`
  et `test/sport_performance_test.dart`
- Les captures de la fiche se prennent avec `outils/captures_fiche_test.dart`,
  qui dessine les écrans réels sous le harnais de test
- **Poussé sur `migration-pwa`** : GitHub Actions reconstruit la PWA et la
  publie sur Cloudflare Pages ; les appareils installés prennent la nouvelle
  version à leur prochain lancement (voir [DEPLOIEMENT.md](DEPLOIEMENT.md))
