-- ============================================================================
-- Un compte désactivé ne peut plus rien.
--
-- FAILLE CORRIGÉE ICI — vérifiée contre la base : `current_role_ignore_actif = t`.
--
-- `socle.current_role()` et `socle.current_user_role()` lisent le rôle sans
-- regarder `actif`. Toutes les politiques bâties sur elles — c'est-à-dire
-- presque toutes — accordaient donc autant à un compte désactivé qu'à un
-- compte en service.
--
-- Le seul contrôle était un écran : `app_shell.dart` affiche « Compte
-- désactivé » et s'arrête là. Autant dire rien. L'application est un binaire
-- que l'utilisateur contrôle ; un agent muté, sanctionné ou parti gardait
-- l'accès complet aux dossiers, aux consultations et à l'armement en
-- appelant l'API directement, avec le jeton qu'il avait déjà.
--
-- Désactiver un compte redevient ce que l'administrateur croyait faire.
--
-- CE QUE CELA NE FAIT PAS : révoquer la session en cours. Le jeton reste
-- valide jusqu'à son expiration, mais il ne porte plus aucun rôle, donc plus
-- aucun droit. Pour une révocation immédiate, il faut supprimer le compte.
-- ============================================================================

create or replace function socle.current_role()
returns socle.app_role
language sql
security definer
stable
set search_path = socle, public
as $$
  select role from socle.profiles where id = auth.uid() and actif;
$$;

create or replace function socle.current_user_role()
returns socle.user_role
language sql
security definer
stable
set search_path = socle, public
as $$
  select role_logistique from socle.profiles where id = auth.uid() and actif;
$$;

-- `socle.est_administrateur()` vérifiait déjà `actif` ; on ne la touche pas.

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Un compte désactivé qui conserverait un rôle lisible.
-- ============================================================================
select count(*) as comptes_desactives_avec_role
from socle.profiles
where not actif and (role is not null or role_logistique is not null)
having count(*) < 0;
