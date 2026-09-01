-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 047_duree_devoirs.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : un devoir peut être limité dans le temps.
--
-- Trois pièces :
--
-- 1. `cours.duree_minutes` — la durée fixée par l'instructeur. Facultative :
--    un devoir sans durée se compose sans montre, comme aujourd'hui.
--
-- 2. `qcm_participations.commence_le` — l'heure à laquelle l'élève a ouvert
--    le sujet, relevée par le serveur. C'est le point essentiel : un compte
--    à rebours calculé sur l'horloge du téléphone se contourne en reculant
--    l'heure de l'appareil. Le serveur, lui, ne se laisse pas remonter.
--
--    Une copie existe donc dès l'ouverture du sujet, et non plus seulement à
--    la remise. `terminee_at` distingue désormais les deux états : une
--    participation dont il est nul est une composition en cours.
--
-- 3. `qcm_participations.hors_delai` — la copie est-elle arrivée après le
--    temps imparti ? On l'accepte quand même : refuser reviendrait à mettre
--    zéro à l'élève dont le réseau a lâché à la dernière minute. Mais
--    l'instructeur le voit dans les résultats et tranche lui-même.
--
--    Deux minutes de battement couvrent la latence d'un envoi : au-delà, le
--    dépassement n'est plus imputable au réseau.

alter table scolarite.cours
  add column duree_minutes integer
    check (duree_minutes is null or (duree_minutes > 0 and duree_minutes <= 600));

alter table scolarite.qcm_participations
  add column commence_le timestamptz,
  add column hors_delai boolean not null default false;

-- Les copies déjà remises n'ont pas d'heure d'ouverture relevée : leur date
-- de création en tient lieu, et aucune n'était limitée dans le temps.
update scolarite.qcm_participations
  set commence_le = created_at
  where commence_le is null;

-- Ouvre le sujet et arme le chronomètre.
--
-- Rappelée à chaque ouverture de l'écran, elle ne remet jamais les compteurs
-- à zéro : l'élève qui reviendrait sur un devoir commencé retrouve le temps
-- qu'il lui reste, pas le temps entier.
--
-- Les paramètres de sortie portent des noms absents des tables (`demarre_a`
-- et non `commence_le`) : une homonymie rendrait la référence ambiguë et la
-- fonction échouerait à l'exécution.
create function scolarite.qcm_commencer(p_devoir_id uuid)
returns table (demarre_a timestamptz, secondes_restantes integer)
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_apprenant_id uuid;
  v_duree integer;
  v_debut timestamptz;
  v_termine timestamptz;
begin
  select a.id, c.duree_minutes into v_apprenant_id, v_duree
  from scolarite.apprenants a
  join scolarite.cours c on c.classe_id = a.classe_id
  where a.profile_id = auth.uid()
    and c.id = p_devoir_id
    and c.type = 'devoir';

  if v_apprenant_id is null then
    raise exception 'Ce devoir ne vous est pas destiné.';
  end if;

  select p.commence_le, p.terminee_at into v_debut, v_termine
  from scolarite.qcm_participations p
  where p.devoir_id = p_devoir_id and p.apprenant_id = v_apprenant_id;

  if v_termine is not null then
    raise exception 'Vous avez déjà composé ce devoir.';
  end if;

  if v_debut is null then
    insert into scolarite.qcm_participations (
      devoir_id, apprenant_id, commence_le
    )
    values (p_devoir_id, v_apprenant_id, now())
    returning qcm_participations.commence_le into v_debut;
  end if;

  return query
    select
      v_debut,
      case
        when v_duree is null then null::integer
        else greatest(
          0,
          v_duree * 60
            - floor(extract(epoch from (now() - v_debut)))::integer
        )
      end;
end;
$$;

revoke execute on function scolarite.qcm_commencer(uuid) from public;
grant execute on function scolarite.qcm_commencer(uuid) to authenticated;

-- La remise complète la copie ouverte au lieu d'en créer une.
drop function if exists scolarite.qcm_remettre(uuid, uuid[]);

create function scolarite.qcm_remettre(
  p_devoir_id uuid,
  p_propositions uuid[]
)
returns void
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
declare
  v_apprenant_id uuid;
  v_participation_id uuid;
  v_duree integer;
  v_debut timestamptz;
  v_termine timestamptz;
  v_note integer;
  v_bareme integer;
  v_hors_delai boolean := false;
begin
  select a.id, c.duree_minutes into v_apprenant_id, v_duree
  from scolarite.apprenants a
  join scolarite.cours c on c.classe_id = a.classe_id
  where a.profile_id = auth.uid() and c.id = p_devoir_id;

  if v_apprenant_id is null then
    raise exception 'Ce devoir ne vous est pas destiné.';
  end if;

  select p.id, p.commence_le, p.terminee_at
    into v_participation_id, v_debut, v_termine
  from scolarite.qcm_participations p
  where p.devoir_id = p_devoir_id and p.apprenant_id = v_apprenant_id;

  if v_termine is not null then
    raise exception 'Vous avez déjà composé ce devoir.';
  end if;

  -- Copie remise sans être passée par `qcm_commencer` : une version
  -- ancienne de l'application, ou un devoir ouvert avant cette migration.
  -- On l'accepte, sans pouvoir juger du délai.
  if v_participation_id is null then
    insert into scolarite.qcm_participations (
      devoir_id, apprenant_id, commence_le
    )
    values (p_devoir_id, v_apprenant_id, now())
    returning id, qcm_participations.commence_le
      into v_participation_id, v_debut;
  end if;

  if v_duree is not null and v_debut is not null then
    v_hors_delai := now()
      > v_debut + make_interval(mins => v_duree) + interval '2 minutes';
  end if;

  -- Points maximum : une bonne réponse rapporte un point.
  select count(*) into v_bareme
  from scolarite.qcm_questions q
  join scolarite.qcm_propositions p on p.question_id = q.id
  where q.devoir_id = p_devoir_id and p.correcte;

  -- Chaque proposition cochée compte +1 si elle est juste, −1 sinon. Une
  -- proposition étrangère à ce devoir est ignorée.
  select coalesce(sum(case when p.correcte then 1 else -1 end), 0)
    into v_note
  from scolarite.qcm_propositions p
  join scolarite.qcm_questions q on q.id = p.question_id
  where q.devoir_id = p_devoir_id
    and p.id = any(p_propositions);

  update scolarite.qcm_participations
    set note = v_note,
        bareme = v_bareme,
        terminee_at = now(),
        hors_delai = v_hors_delai
    where id = v_participation_id;

  -- L'élève peut revenir sur ses réponses tant qu'il n'a pas remis : on
  -- repart des propositions reçues, sans traîner d'anciennes.
  delete from scolarite.qcm_reponses where participation_id = v_participation_id;

  insert into scolarite.qcm_reponses (participation_id, proposition_id)
  select v_participation_id, p.id
  from scolarite.qcm_propositions p
  join scolarite.qcm_questions q on q.id = p.question_id
  where q.devoir_id = p_devoir_id and p.id = any(p_propositions);
end;
$$;

revoke execute on function scolarite.qcm_remettre(uuid, uuid[]) from public;
grant execute on function scolarite.qcm_remettre(uuid, uuid[]) to authenticated;
