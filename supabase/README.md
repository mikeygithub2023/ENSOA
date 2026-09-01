# Base unifiée ENSOA — mode opératoire

Une seule base pour les deux modules, dans le projet Supabase **ENSOA**
(`alsglftuvvefxaadfzsj`).

**Rien n'est effacé pour démarrer.** Les trois schémas de la base unifiée se
créent à côté de ce que le projet contient déjà : les anciennes tables du
soutien technique restent dans `public`, intactes, et servent de filet. Le
projet **ENSOA GSES** (`leswdaqpiyisharueufn`) n'est pas touché du tout — il
reste en service pendant toute la construction.

Retour en arrière complet, à tout moment avant la bascule :
`drop schema socle, scolarite, logistique cascade;`

## Organisation de la base

| Schéma | Contenu |
|---|---|
| `socle` | Le commun : `profiles` (identité unique), `divisions`, `service`, `cellule`, les journaux (`audit_log`, `historique`), notifications et jetons d'appareils. |
| `scolarite` | Les 39 tables de la scolarité, reprises telles quelles. |
| `logistique` | Les 29 tables du soutien technique, reprises telles quelles. |
| `public` | Rien de la base unifiée. L'ancien module logistique y dort jusqu'à la bascule. |

Une seule identité, deux familles de rôles portées par le même profil :

```
profiles.role             app_role   — scolarité         (nul si non concerné)
profiles.role_logistique  user_role  — soutien technique (nul si non concerné)
current_role()            lit role
current_user_role()       lit role_logistique
```

Les deux énumérations restent séparées **à dessein** : les ~100 politiques RLS
des deux bases interrogent ces deux fonctions. En gardant chacune sur sa
colonne, aucune politique n'a besoin d'être retouchée. Une politique mal
retranscrite, c'est le dossier médical d'un élève ouvert au garage.

Un même militaire peut cumuler les deux rôles — instructeur *et* armurier.

## Les migrations

99 fichiers. Ceux qui portent `_scolarite_` ou `_logistique_` sont **générés**
par `outils/construire_migrations.sh` à partir des deux dépôts d'origine : le
SQL éprouvé n'est pas réécrit, seulement requalifié (`public.` → `socle.`,
`scolarite.` ou `logistique.`). Ne pas les éditer à la main — corriger la
source, puis relancer le script.

Trois fichiers sont écrits à la main :

- `20260829000000_schemas.sql` — les trois schémas, leurs droits, `pg_net`
- `20260829020000_socle_unifie.sql` — l'identité unique
- `20260829040000_droits.sql` — les GRANT, en dernier

Un fichier source = une migration : les auteurs des deux bases ont découpé
leurs migrations en étapes `a`/`b` là où PostgreSQL refuse qu'une valeur
d'énuméré fraîchement ajoutée serve dans la même transaction. `supabase db
push` passe chaque fichier dans une transaction — ce découpage doit survivre.

## Ordre des opérations

Tout se lance **dans Git Bash** (`C:\Program Files\Git\bin\bash.exe`), depuis
ce dossier — pas dans PowerShell, où `bash` n'est pas dans le PATH.

```bash
cd "/c/Mes Projets/SIG ENSOA/ENSOA UNIFIE"

# 1. Installer la base unifiée (n'efface rien)
supabase link --project-ref alsglftuvvefxaadfzsj
supabase db push

# 2. Déclarer les schémas à l'API
#    Dashboard > Settings > API > Exposed schemas :
#    socle, scolarite, logistique
#    (sans ça, PostgREST renvoie 404 sur toutes les tables)

# 3. Créer le premier compte administrateur, puis vérifier la RLS

# 4. Construire l'application unifiée, la valider en service réel

# 5. AVANT la bascule seulement : sauvegarder les deux bases
bash supabase/outils/sauvegarder.sh

# 6. Bascule : couper les deux anciennes applications, puis nettoyer
#    l'ancien module logistique resté dans `public`
```

En cas de problème à l'étape 1 ou 3 : `outils/retour_arriere.sql`.

## Ce qui reste à faire après la base

- Les Edge Functions : `create-user` + `admin-create-user` → une seule, qui
  pose les deux rôles ; idem pour les deux fonctions de notification push et
  les deux assistants IA.
- L'application Flutter unifiée (module scolarité, module logistique, espace
  élève), avec `supabase.schema('socle'|'scolarite'|'logistique')`.

## Dette assumée, à traiter plus tard

Trois duplications sont conservées volontairement, parce que les fusionner
maintenant demanderait de réécrire du SQL éprouvé sans bénéfice immédiat :

- deux tables de notifications (`notifications` scolarité, `notification`
  logistique) ;
- deux journaux (`audit_log` par déclencheurs, `historique` écrit par l'app) ;
- deux tables de jetons push (`appareils`, `device_token`).

L'application peut les présenter comme un seul écran. La fusion se fera quand
le reste sera stable.
