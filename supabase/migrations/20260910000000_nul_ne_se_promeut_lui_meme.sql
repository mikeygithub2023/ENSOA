-- ============================================================================
-- Nul ne se promeut lui-même.
--
-- FAILLE CORRIGÉE ICI — vérifiée contre la base le 13/10/2026, exploitable.
--
-- La politique `profiles_update_self` autorise un compte à modifier SA ligne :
--
--   for update to authenticated using (id = auth.uid()) with check (id = auth.uid())
--
-- Elle borne la LIGNE, pas les COLONNES. Or `authenticated` détient le droit
-- UPDATE sur toute la table (`grant ... on all tables in schema socle`). Un
-- élève — dont le mot de passe d'ouverture est son numéro de téléphone, connu
-- de ses camarades — pouvait donc écrire :
--
--   update socle.profiles set role = 'admin' where id = auth.uid();
--
-- et devenir administrateur de l'école. Sans passer par l'application : l'URL
-- du projet et la clé publishable sont dans l'APK, qui se décompresse en
-- trente secondes. Il obtenait alors les dossiers de tous les apprenants, les
-- consultations médicales, l'inventaire d'armement et les dotations
-- nominatives — qui détient quelle arme.
--
-- POURQUOI UN DÉCLENCHEUR ET NON UN `REVOKE`. La RLS ne sait pas filtrer par
-- colonne. Un `revoke update ... grant update (colonne)` marcherait, mais
-- casserait les écrans d'administration, qui écrivent `role`,
-- `role_logistique`, `actif` et les portées par un UPDATE direct depuis le
-- client. Le déclencheur ne vise que le cas dangereux : quelqu'un qui modifie
-- SA PROPRE ligne sans être administrateur. Tout le reste passe comme avant.
--
-- CE QU'IL LAISSE PASSER, et doit laisser passer :
--   * son propre changement de mot de passe, qui baisse le drapeau ;
--   * la correction de son nom, de son grade, de son titre ;
--   * l'administrateur qui nomme, mute, désactive qui il veut ;
--   * le chef du soutien technique sur ses trois services.
-- ============================================================================

create or replace function socle.nul_ne_se_promeut_lui_meme()
returns trigger
language plpgsql
security definer
set search_path = socle, public
as $$
begin
  -- Seul le cas « je modifie ma propre ligne » est surveillé. Un
  -- administrateur agissant sur autrui, ou le chef du soutien technique sur
  -- ses services, passe par d'autres politiques et n'est pas concerné.
  if auth.uid() is null or auth.uid() <> old.id then
    return new;
  end if;

  -- L'administrateur peut tout, y compris sur lui-même : il doit pouvoir
  -- corriger son propre compte, et il est seul à ouvrir les autres.
  if socle.est_administrateur() then
    return new;
  end if;

  -- Les colonnes qui portent le pouvoir. On les réimpose plutôt que de lever
  -- une erreur : l'écran de changement de mot de passe envoie la ligne
  -- entière, et le faire échouer empêcherait quelqu'un de changer son mot de
  -- passe — c'est-à-dire exactement ce qu'on veut qu'il fasse.
  new.role := old.role;
  new.role_logistique := old.role_logistique;
  new.profil_personnalise_id := old.profil_personnalise_id;
  new.actif := old.actif;
  new.division_id := old.division_id;
  new.promotion_id := old.promotion_id;
  new.cellule_id := old.cellule_id;
  new.matricule := old.matricule;

  return new;
end $$;

drop trigger if exists nul_ne_se_promeut_lui_meme on socle.profiles;
create trigger nul_ne_se_promeut_lui_meme
before update on socle.profiles
for each row execute function socle.nul_ne_se_promeut_lui_meme();

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Un compte qui ne serait rattaché à aucun poste connu relève de l'autorité
-- de personne côté serveur ; la faille ci-dessus en faisait un chemin
-- d'escalade, et ils restent à reprendre en main.
-- ============================================================================
select matricule, role, role_logistique
from socle.profiles
where role = 'admin' and role_logistique is null;
