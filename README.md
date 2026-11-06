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

### État à la fin de la journée

- `flutter analyze` : aucun avertissement
- **143 tests** passent, dont quatre fichiers nés aujourd'hui :
  `test/tableau_de_bord_test.dart`, `test/taches_test.dart`,
  `test/soutien_technique_onglets_test.dart` et
  `test/menu_libelles_test.dart`
- Les captures de la fiche se prennent avec `outils/captures_fiche_test.dart`,
  qui dessine les écrans réels sous le harnais de test
- **Poussé sur `migration-pwa`** : GitHub Actions reconstruit la PWA et la
  publie sur Cloudflare Pages ; les appareils installés prennent la nouvelle
  version à leur prochain lancement (voir [DEPLOIEMENT.md](DEPLOIEMENT.md))
