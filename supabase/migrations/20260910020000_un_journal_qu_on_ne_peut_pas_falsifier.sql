-- ============================================================================
-- Un journal d'audit qu'on ne peut pas falsifier, et des notifications
-- qu'on ne peut pas usurper.
--
-- DEUX FAILLES CORRIGÉES ICI, toutes deux vérifiées contre la base :
--   audit_usurpation = ACCEPTEE
--   notif_usurpation = ACCEPTEE
--
-- --- Le journal ------------------------------------------------------------
--
-- `audit_log_insert` portait `with check (true)`, et `actor_id` n'a pas de
-- valeur par défaut. N'importe quel compte pouvait donc écrire une ligne
-- d'audit **en l'attribuant à quelqu'un d'autre** — l'administrateur, par
-- exemple, dont l'identifiant s'obtient par `socle.les_administrateurs()`.
-- Et noyer le journal sous de fausses entrées.
--
-- Ce n'est pas un défaut parmi d'autres. Le journal est la contrepartie
-- explicitement invoquée pour justifier l'élargissement des droits de
-- l'administrateur : « Ses actions restent tracées dans le journal, qui
-- enregistre l'auteur de chaque opération » (migration 20260830000000). Cette
-- non-répudiation n'existait pas. On la rétablit, et les décisions qui
-- s'appuyaient dessus redeviennent défendables.
--
-- --- Les notifications -----------------------------------------------------
--
-- `notifications_insert` portait aussi `with check (true)`. Tout compte
-- pouvait adresser à qui il voulait un message de son choix, qu'un
-- déclencheur transforme en notification poussée sur les tablettes. Dans le
-- canal officiel de l'école, c'est un hameçonnage crédible : « votre mot de
-- passe expire, changez-le ici ».
--
-- On garde ce dont l'application a besoin : s'écrire à soi-même, et le
-- pouvoir de l'administrateur d'écrire à tous. Les notifications nées d'un
-- déclencheur passent en `security definer` et ne sont pas concernées.
-- ============================================================================

-- --- Le journal -------------------------------------------------------------
alter table socle.audit_log alter column actor_id set default auth.uid();

drop policy if exists audit_log_insert on socle.audit_log;
create policy audit_log_insert on socle.audit_log
  for insert to authenticated
  with check (actor_id = auth.uid());

-- Une ligne d'audit ne se corrige pas et ne s'efface pas : c'est ce qui en
-- fait une preuve. Aucune politique `update` ni `delete` n'existe pour
-- `authenticated` — sauf `admin_tout_pouvoir`, posée en boucle sur les 67
-- tables, qui donne à l'administrateur le droit de réécrire le journal de ses
-- propres actes. On la lui retire ICI, et ici seulement.
drop policy if exists admin_tout_pouvoir on socle.audit_log;
create policy admin_lit_le_journal on socle.audit_log
  for select to authenticated
  using (socle.est_administrateur());

-- --- Les notifications ------------------------------------------------------
drop policy if exists notifications_insert on socle.notifications;
create policy notifications_insert on socle.notifications
  for insert to authenticated
  with check (
    -- S'écrire à soi-même : sans danger, et c'est ce que fait l'application
    -- du soutien technique quand elle note une tâche pour son propre service.
    profile_id = auth.uid()
    -- L'administrateur prévient qui il veut, y compris tout un rôle.
    or socle.est_administrateur()
  );

-- ============================================================================
-- Contrôle : doit retourner 0 ligne.
-- Une politique d'insertion du journal qui ne lierait pas l'auteur.
-- ============================================================================
select policyname, with_check
from pg_policies
where schemaname = 'socle' and tablename = 'audit_log' and cmd = 'INSERT'
  and coalesce(with_check, '') not like '%auth.uid()%';
