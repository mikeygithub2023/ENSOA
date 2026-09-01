-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 035_cours.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : les cours d'une classe/stage, avec leurs exercices
-- d'application et leurs devoirs.
--
-- Une seule table plutôt que trois : un exercice d'application et un devoir
-- se décrivent exactement comme un cours (un titre, une matière, une date,
-- un document), seul leur rôle pédagogique diffère — d'où la colonne
-- `type`. `cours_id` rattache un exercice ou un devoir au cours qu'il
-- applique : c'est ce lien qui fait la différence entre une liasse de
-- fichiers et une progression pédagogique. Il reste facultatif, un exercice
-- pouvant être donné hors de tout cours enregistré.
--
-- `division_id` est dénormalisé depuis la classe/stage (comme sur
-- `consultations_medicales`) pour cloisonner par division sans jointure.
--
-- Le document lui-même vit dans un bucket privé : on ne garde ici que son
-- chemin et son nom d'origine, jamais d'URL — elle est signée à la demande
-- (même principe que les photos d'apprenants, migration 004).

create table scolarite.cours (
  id uuid primary key default gen_random_uuid(),
  division_id uuid not null references socle.divisions (id),
  classe_id uuid not null references scolarite.classes (id) on delete cascade,
  matiere_id uuid references scolarite.matieres (id),
  type text not null check (type in ('cours', 'exercice', 'devoir')),
  cours_id uuid references scolarite.cours (id) on delete set null,
  titre text not null,
  description text,
  date_seance date,
  date_remise date,
  fichier_path text,
  fichier_nom text,
  created_at timestamptz not null default now(),
  created_by uuid references socle.profiles (id) default auth.uid(),
  -- Un cours ne s'applique pas à lui-même.
  constraint cours_rattachement check (type <> 'cours' or cours_id is null)
);

create index cours_classe_idx on scolarite.cours (classe_id);
create index cours_parent_idx on scolarite.cours (cours_id);

alter table scolarite.cours enable row level security;

-- L'administrateur voit tout ; le chef de division et l'instructeur, leur
-- division (voir la migration 034, qui pose ce cloisonnement).
create policy cours_select_staff on scolarite.cours
  for select to authenticated
  using (
    socle.current_role() = 'admin'
    or (
      socle.current_role() in ('chef_division', 'instructeur')
      and division_id = socle.current_division()
    )
  );

-- L'élève/stagiaire accède aux cours de sa propre classe/stage : ils sont
-- faits pour lui.
create policy cours_select_own on scolarite.cours
  for select to authenticated
  using (
    exists (
      select 1 from scolarite.apprenants a
      where a.profile_id = auth.uid()
        and a.classe_id = cours.classe_id
    )
  );

create policy cours_write_admin on scolarite.cours
  for all to authenticated
  using (socle.current_role() = 'admin')
  with check (socle.current_role() = 'admin');

-- L'instructeur dépose ses propres cours, au même titre que le chef de
-- division : c'est lui qui enseigne.
create policy cours_write_division_staff on scolarite.cours
  for all to authenticated
  using (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  )
  with check (
    socle.current_role() in ('chef_division', 'instructeur')
    and division_id = socle.current_division()
  );

create trigger audit_cours
  after insert or update or delete on scolarite.cours
  for each row execute function socle.audit_trigger();

grant select, insert, update, delete on scolarite.cours to authenticated;

-- Bucket privé des documents pédagogiques — même dispositif que les photos
-- d'apprenants : aucune URL publique, une URL signée à la demande.
insert into storage.buckets (id, name, public)
values ('cours-documents', 'cours-documents', false)
on conflict (id) do nothing;

create policy cours_documents_select on storage.objects
  for select to authenticated
  using (bucket_id = 'cours-documents');

create policy cours_documents_write on storage.objects
  for all to authenticated
  using (bucket_id = 'cours-documents')
  with check (bucket_id = 'cours-documents');
