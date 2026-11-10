# -*- coding: utf-8 -*-
"""Scinde une fiche de renseignement de promotion en fichiers d'import.

Le classeur de renseignement de l'école porte les deux options dans la même
feuille. On en tire deux classeurs au format exact de l'import de
l'application — colonnes lues par position, en-tête sur la première ligne —
un par division :

    Matricule | Nom | Prénoms | Sexe | Téléphone | Date de naissance |
    Lieu de naissance | Situation matrimoniale | Enfant(s) |
    Nom et prénoms du père | Nom et prénoms de la mère | E-mail |
    Groupe sanguin | Taille (cm) | Poids (kg) | Personne à prévenir |
    Lien de parenté | Téléphone à prévenir | Diplôme

SECTION et SGPT sont laissées de côté, comme demandé. S/P et DEPT aussi :
la fiche de l'apprenant n'a pas de case pour eux.

L'import sait normaliser lui-même la situation matrimoniale, le groupe
sanguin, la taille et le poids : on lui passe donc les cellules telles
qu'elles sont écrites. Seule la personne à prévenir est découpée ici, parce
qu'une seule cellule y porte trois renseignements.

    python outils/scinder_fiche_renseignement.py <source.xlsx> <sortie>

Écrit au 10 novembre 2026 pour la 37e promotion. Si la feuille de la
promotion suivante range ses colonnes autrement, ce sont les constantes
COL_* et PREMIERE_LIGNE qu'il faut reprendre — rien d'autre.
"""
import datetime
import re
import sys
import zipfile

import openpyxl

SOURCE, SORTIE = sys.argv[1], sys.argv[2]

# Colonnes de la feuille source, numérotées à partir de 1 (A = 1).
COL_OPTION = 4
COL_NOM = 5
COL_PRENOMS = 6
COL_GENRE = 9
COL_NAISSANCE = 10
COL_LIEU = 11
COL_TELEPHONE = 14
COL_SITUATION = 15
COL_PERE = 16
COL_MERE = 17
COL_EMAIL = 18
COL_SANG = 19
COL_TAILLE = 20
COL_POIDS = 21
COL_CONTACT = 22
COL_DIPLOME = 23

PREMIERE_LIGNE = 5  # l'en-tête est en ligne 4

ENTETE = [
    'Matricule',
    'Nom',
    'Prénoms',
    'Sexe',
    'Téléphone',
    'Date de naissance',
    'Lieu de naissance',
    'Situation matrimoniale',
    'Enfant(s)',
    'Nom et prénoms du père',
    'Nom et prénoms de la mère',
    'E-mail',
    'Groupe sanguin',
    'Taille (cm)',
    'Poids (kg)',
    'Personne à prévenir',
    'Lien de parenté',
    'Téléphone à prévenir',
    'Diplôme',
]

# « ABE AMON JUSTINE (05 46 20 07 86) TANTE » : un nom, un ou deux numéros
# entre parenthèses, parfois le lien de parenté à la suite.
CONTACT = re.compile(r'^(?P<nom>[^(]*)\((?P<tel>[^)]*)\)\s*(?P<lien>.*)$')


def texte(valeur):
    """Une cellule telle qu'on veut la relire : sans espaces superflus."""
    if valeur is None:
        return ''
    return ' '.join(str(valeur).split())


def jour(valeur):
    """La date au format que l'import attend, JJ/MM/AAAA.

    Une cellule vraiment datée se présente en objet, les autres en texte
    déjà écrit dans ce format : on les ramène toutes à la même forme.
    """
    if isinstance(valeur, (datetime.datetime, datetime.date)):
        return f'{valeur.day:02d}/{valeur.month:02d}/{valeur.year:04d}'
    return texte(valeur)


def enfants(situation):
    """Le nombre d'enfants dit par la situation matrimoniale.

    « MARIE 2 ENFANTS » en porte deux ; « SANS ENFANT » n'en compte aucun et
    laisse la case vide — on ne sait pas, on ne dit pas.
    """
    trouve = re.search(r'(\d+)', situation)
    return trouve.group(1) if trouve else ''


def personne_a_prevenir(valeur):
    """Découpe « NOM (téléphone) LIEN » en ses trois renseignements."""
    brut = texte(valeur)
    if not brut:
        return '', '', ''
    trouve = CONTACT.match(brut)
    if not trouve:
        # Deux fiches ne portent qu'un nom : c'est déjà quelque chose.
        return brut, '', ''
    return (
        texte(trouve.group('nom')),
        texte(trouve.group('lien')),
        texte(trouve.group('tel')),
    )


def rendre_les_cibles_relatives(chemin):
    """Écrit la feuille en cible relative dans les relations du classeur.

    openpyxl désigne la feuille par « /xl/worksheets/sheet1.xml », chemin
    absolu que la norme admet. Le lecteur Excel de l'application, lui,
    préfixe la cible par « xl/ » sans y regarder : il cherche alors
    « xl//xl/worksheets/sheet1.xml », ne trouve rien, et rejette le fichier
    entier. On lui donne donc la forme qu'il attend.

    Le correctif vit aussi dans l'application, qui sait maintenant lire les
    deux formes — ceci ne sert qu'à ce que les fichiers d'aujourd'hui
    s'importent sans attendre la prochaine mise en ligne.
    """
    with zipfile.ZipFile(chemin) as source:
        entrees = [(i, source.read(i.filename)) for i in source.infolist()]

    with zipfile.ZipFile(chemin, 'w', zipfile.ZIP_DEFLATED) as sortie:
        for info, contenu in entrees:
            if info.filename == 'xl/_rels/workbook.xml.rels':
                contenu = contenu.replace(b'Target="/xl/', b'Target="')
            sortie.writestr(info, contenu)


wb = openpyxl.load_workbook(SOURCE, data_only=True)
ws = wb[wb.sheetnames[0]]

groupes = {'SPECIALISTE': [], 'GENERALISTE': []}
inconnus = []

for numero, ligne in enumerate(
    ws.iter_rows(min_row=PREMIERE_LIGNE, max_row=ws.max_row, values_only=True),
    PREMIERE_LIGNE,
):
    def cellule(colonne):
        return texte(ligne[colonne - 1])

    nom = cellule(COL_NOM)
    prenoms = cellule(COL_PRENOMS)
    if not nom and not prenoms:
        continue

    situation = cellule(COL_SITUATION)
    prevenir_nom, prevenir_lien, prevenir_tel = personne_a_prevenir(
        ligne[COL_CONTACT - 1]
    )

    rangee = [
        '',  # matricule : la feuille n'en porte pas
        nom,
        prenoms,
        cellule(COL_GENRE),
        cellule(COL_TELEPHONE),
        jour(ligne[COL_NAISSANCE - 1]),
        cellule(COL_LIEU),
        situation,
        enfants(situation),
        cellule(COL_PERE),
        cellule(COL_MERE),
        cellule(COL_EMAIL),
        cellule(COL_SANG),
        cellule(COL_TAILLE),
        cellule(COL_POIDS),
        prevenir_nom,
        prevenir_lien,
        prevenir_tel,
        cellule(COL_DIPLOME),
    ]

    option = cellule(COL_OPTION).upper()
    if option in groupes:
        groupes[option].append(rangee)
    else:
        inconnus.append((numero, option or '(vide)', nom, prenoms))

NOMS = {
    'SPECIALISTE': '37e-promotion-specialistes.xlsx',
    'GENERALISTE': '37e-promotion-generalistes.xlsx',
}

for option, rangees in groupes.items():
    classeur = openpyxl.Workbook()
    feuille = classeur.active
    feuille.title = 'Apprenants'
    feuille.append(ENTETE)
    for rangee in rangees:
        # Une cellule vide s'écrit None, jamais '' : openpyxl rendrait sinon
        # une chaîne en ligne sans contenu — <c t="inlineStr" /> —, forme
        # que le lecteur Excel de l'application ne sait pas lire, et le
        # fichier entier serait rejeté.
        feuille.append([valeur if valeur != '' else None for valeur in rangee])
    # Tout se lit en texte : sans cela Excel ferait d'un
    # « 05 01 32 06 45 » un nombre, et d'une date un numéro de série.
    for colonnes in feuille.iter_cols():
        for cellule_ in colonnes:
            cellule_.number_format = '@'
    chemin = f'{SORTIE}/{NOMS[option]}'
    classeur.save(chemin)
    rendre_les_cibles_relatives(chemin)
    print(f'{option:12s} {len(rangees):3d} apprenants -> {chemin}')

if inconnus:
    print('\nOption non reconnue :')
    for numero, option, nom, prenoms in inconnus:
        print(f'  ligne {numero} : « {option} » — {nom} {prenoms}')
