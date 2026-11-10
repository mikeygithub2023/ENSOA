# -*- coding: utf-8 -*-
"""Écrit le SQL qui complète des fiches importées à moitié.

Pourquoi ce script existe. Le 10 novembre 2026, les 203 élèves de la 37e
promotion ont été importés par une version de l'application qui ne lisait
encore que **sept colonnes** : matricule, nom, prénoms, sexe, téléphone, date
et lieu de naissance. Les douze colonnes suivantes du classeur — filiation,
contact d'urgence, données médicales, diplôme — ont été lues par le tableur et
ignorées par l'application. La version qui les lit est partie en production
quelques minutes plus tard ; l'import, lui, était déjà passé.

Plutôt que de supprimer puis réimporter 203 fiches, on complète celles qui
sont là. Le script lit les mêmes classeurs d'import et rend un fichier SQL à
coller dans l'éditeur du tableau de bord Supabase.

Deux garanties tenues par le SQL produit :

  - il ne remplit que ce qui est **vide** (`coalesce`) : une case corrigée à
    la main depuis l'import n'est pas écrasée ;
  - il s'appuie sur nom + prénom + date de naissance, et se borne aux phases
    visées — il ne peut pas toucher une autre promotion.

    python outils/completer_fiches_depuis_import.py <sortie.sql> <classeur...>

Les règles de lecture des cellules sont celles de
`lib/modules/scolarite/features/apprenants/import_valeurs.dart` — reprises ici
à l'identique, y compris la règle qui les gouverne : devant une valeur qu'on
ne comprend pas, on rend `null` plutôt que de trancher.
"""
import re
import sys
import unicodedata

import openpyxl

SORTIE = sys.argv[1]
CLASSEURS = sys.argv[2:]

# La portée : les phases que le SQL a le droit de toucher.
PHASE = 'FCB'
PROMOTION = '37%'

GROUPES_SANGUINS = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}


def aplatir(valeur):
    sans_accent = ''.join(
        c for c in unicodedata.normalize('NFD', (valeur or '').strip().lower())
        if unicodedata.category(c) != 'Mn'
    )
    return sans_accent


def vide_en_nul(valeur):
    valeur = (valeur or '').strip()
    return valeur or None


def situation(valeur):
    v = aplatir(valeur)
    if not v:
        return None
    if v.startswith('celibataire'):
        return 'Célibataire'
    if v.startswith('marie'):
        return 'Marié(e)'
    if v.startswith('divorce'):
        return 'Divorcé(e)'
    if v.startswith('veu'):
        return 'Veuf(ve)'
    return None


def groupe_sanguin(valeur):
    v = re.sub(r'\s+', '', (valeur or '')).upper().replace('0', 'O')
    return v if v in GROUPES_SANGUINS else None


def premier_nombre(valeur):
    m = re.search(r'(\d+(?:[.,]\d+)?)', valeur or '')
    if not m:
        return None
    return float(m.group(1).replace(',', '.'))


def taille_cm(valeur):
    nombre = premier_nombre(valeur)
    if nombre is None:
        return None
    # Sous trois, c'est que la cellule parle en mètres : personne ne mesure
    # deux centimètres.
    return round(nombre * 100) if nombre < 3 else nombre


def entier(valeur):
    m = re.search(r'(\d+)', valeur or '')
    return int(m.group(1)) if m else None


def date_iso(valeur):
    """La colonne est écrite JJ/MM/AAAA ; PostgreSQL veut AAAA-MM-JJ."""
    valeur = (valeur or '').strip()
    m = re.match(r'^(\d{1,2})/(\d{1,2})/(\d{4})$', valeur)
    if not m:
        return None
    jour, mois, annee = m.groups()
    return f'{annee}-{int(mois):02d}-{int(jour):02d}'


def litteral(valeur):
    if valeur is None:
        return 'null'
    if isinstance(valeur, (int, float)):
        return repr(valeur)
    return "'" + str(valeur).replace("'", "''") + "'"


def cellule(ligne, index):
    if index >= len(ligne) or ligne[index] is None:
        return ''
    return str(ligne[index]).strip()


# Colonnes du classeur d'import, par position (voir
# scinder_fiche_renseignement.py et le modèle téléchargeable de l'application).
NOM, PRENOMS = 1, 2
NAISSANCE = 5
SITUATION, ENFANTS = 7, 8
PERE, MERE, EMAIL = 9, 10, 11
SANG, TAILLE, POIDS = 12, 13, 14
URGENCE_NOM, URGENCE_LIEN, URGENCE_TEL = 15, 16, 17
DIPLOME = 18

lignes = []
ignorees = []
for chemin in CLASSEURS:
    feuille = openpyxl.load_workbook(chemin, data_only=True).active
    for brute in feuille.iter_rows(min_row=2, values_only=True):
        nom = cellule(brute, NOM)
        prenom = cellule(brute, PRENOMS)
        naissance = date_iso(cellule(brute, NAISSANCE))
        if not nom or not prenom:
            continue
        # Sans date de naissance, la fiche ne peut pas être retrouvée à coup
        # sûr : on préfère la laisser que d'en compléter une autre.
        if not naissance:
            ignorees.append(f'{nom} {prenom}')
            continue
        lignes.append((
            nom, prenom, naissance,
            situation(cellule(brute, SITUATION)),
            entier(cellule(brute, ENFANTS)),
            vide_en_nul(cellule(brute, PERE)),
            vide_en_nul(cellule(brute, MERE)),
            vide_en_nul(cellule(brute, EMAIL)),
            groupe_sanguin(cellule(brute, SANG)),
            taille_cm(cellule(brute, TAILLE)),
            premier_nombre(cellule(brute, POIDS)),
            vide_en_nul(cellule(brute, URGENCE_NOM)),
            vide_en_nul(cellule(brute, URGENCE_LIEN)),
            vide_en_nul(cellule(brute, URGENCE_TEL)),
            vide_en_nul(cellule(brute, DIPLOME)),
        ))

# Une clé en double rendrait l'« update ... from » non déterministe : il
# vaut mieux s'arrêter que compléter une fiche avec les renseignements d'une
# autre.
cles = [(n.upper(), p.upper(), d) for n, p, d, *_ in lignes]
doublons = {c for c in cles if cles.count(c) > 1}
if doublons:
    sys.exit(f'clés en double, rien écrit : {sorted(doublons)}')

valeurs = ',\n  '.join(
    '(' + ', '.join(litteral(v) for v in ligne) + ')' for ligne in lignes
)

sql = f"""-- Compléter les fiches importées à moitié.
--
-- Les élèves ont été enregistrés par une version de l'application qui ne
-- lisait que les sept premières colonnes du classeur. Ce script reprend les
-- douze suivantes dans les fiches déjà en place.
--
-- Il ne remplit que ce qui est vide : une case corrigée depuis l'import n'est
-- pas écrasée. Il se borne aux phases « {PHASE} » des promotions « {PROMOTION} ».
-- Il peut être rejoué sans dommage.
--
-- {len(lignes)} fiche(s) concernée(s).

begin;

create temporary table maj_fiches (
  nom                    text,
  prenom                 text,
  naissance              date,
  situation_matrimoniale text,
  nombre_enfants         integer,
  nom_pere               text,
  nom_mere               text,
  email                  text,
  groupe_sanguin         text,
  taille_cm              numeric,
  poids_kg               numeric,
  urgence_nom            text,
  urgence_lien           text,
  urgence_contact        text,
  diplome                text
) on commit drop;

insert into maj_fiches values
  {valeurs};

-- Les fiches visées : celles que l'import a posées, et elles seules. Une
-- table temporaire plutôt qu'une vue : elle disparaît avec la transaction,
-- et le script peut donc être relancé tel quel.
create temporary table cibles on commit drop as
select a.id, m.*
  from scolarite.apprenants a
  join maj_fiches m
    on upper(a.nom) = upper(m.nom)
   and upper(a.prenom) = upper(m.prenom)
   and a.date_naissance = m.naissance
 where a.classe_id in (
         select c.id
           from scolarite.classes c
           join scolarite.promotions p on p.id = c.promotion_id
          where upper(c.nom) = '{PHASE}'
            and p.nom like '{PROMOTION}'
       );

update scolarite.apprenants a
   set situation_matrimoniale =
         coalesce(a.situation_matrimoniale, c.situation_matrimoniale),
       nombre_enfants   = coalesce(a.nombre_enfants, c.nombre_enfants),
       nom_pere         = coalesce(a.nom_pere, c.nom_pere),
       nom_mere         = coalesce(a.nom_mere, c.nom_mere),
       email            = coalesce(a.email, c.email),
       groupe_sanguin   = coalesce(a.groupe_sanguin, c.groupe_sanguin),
       taille_cm        = coalesce(a.taille_cm, c.taille_cm),
       poids_kg         = coalesce(a.poids_kg, c.poids_kg),
       urgence_nom      = coalesce(a.urgence_nom, c.urgence_nom),
       urgence_lien     = coalesce(a.urgence_lien, c.urgence_lien),
       urgence_contact  = coalesce(a.urgence_contact, c.urgence_contact)
  from cibles c
 where c.id = a.id;

-- Le diplôme : au catalogue d'abord, rattaché ensuite. Le catalogue est
-- unique sur le nom, et insensible à la casse pour l'application : on ne crée
-- donc pas « Bac » à côté de « BAC ».
insert into scolarite.diplomes (nom)
select distinct on (upper(c.diplome)) c.diplome
  from cibles c
 where c.diplome is not null
   and not exists (
         select 1 from scolarite.diplomes d
          where upper(d.nom) = upper(c.diplome)
       )
 order by upper(c.diplome);

insert into scolarite.apprenant_diplomes (apprenant_id, diplome_id)
select c.id, d.id
  from cibles c
  join scolarite.diplomes d on upper(d.nom) = upper(c.diplome)
 where c.diplome is not null
    on conflict (apprenant_id, diplome_id) do nothing;

-- Le compte rendu : combien de fiches le script a effectivement touchées.
select count(*) as fiches_completees from cibles;

commit;
"""

with open(SORTIE, 'w', encoding='utf-8', newline='\n') as f:
    f.write(sql)

print(f'{len(lignes)} fiche(s) -> {SORTIE}')
if ignorees:
    print('sans date de naissance, laissées de côté :', ', '.join(ignorees))
