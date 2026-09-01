-- ============================================================================
-- SCOLARITÉ (ENSOA GSES) — repris de 049_ordonnance_mouvement_consultation_supprimee.sql
--
-- FICHIER GÉNÉRÉ par supabase/outils/construire_migrations.sh.
-- Ne pas éditer à la main : corriger la source, puis relancer le script.
-- ============================================================================

-- Migration : ne pas remettre en stock les médicaments d'une consultation
-- supprimée.
--
-- Symptôme : supprimer un apprenant échouait sur
--
--   insert or update on table "mouvements_stock" violates foreign key
--   constraint "mouvements_stock_consultation_id_fkey"
--
-- « insert », et non « delete » : ce n'était pas la suppression qui butait,
-- mais une insertion déclenchée pendant celle-ci.
--
-- La chaîne :
--   apprenant supprimé
--     → cascade sur consultations_medicales
--       → cascade sur ordonnance_lignes
--         → `ordonnance_lignes_record_mouvement_delete` insère un mouvement
--           de stock rattaché à une consultation qui vient de disparaître.
--
-- ---------------------------------------------------------------------------
-- La correction ne se contente pas de couper le lien : elle supprime le
-- mouvement lui-même dans ce cas, parce que le mouvement n'a pas lieu d'être.
--
-- Ce déclencheur existe pour rendre au stock les médicaments d'une
-- prescription ANNULÉE : le médecin s'est ravisé, les boîtes retournent en
-- rayon. Supprimer un apprenant n'annule rien du tout — les médicaments ont
-- été servis et consommés. Les recréditer gonflerait le stock d'unités qui
-- n'existent plus, et l'infirmerie compterait des boîtes absentes de
-- l'étagère.
--
-- On distingue donc les deux cas par un test simple : la consultation
-- existe-t-elle encore ? Si oui, c'est une annulation, le stock est rendu.
-- Si non, elle est en cours de suppression, et le médicament reste consommé.

create or replace function scolarite.record_ordonnance_mouvement()
returns trigger
language plpgsql
security definer
set search_path = scolarite, socle, public
as $$
begin
  if tg_op = 'INSERT' then
    insert into scolarite.mouvements_stock (
      medicament_id, type, quantite, motif, consultation_id, auteur_id
    )
    values (
      new.medicament_id, 'sortie', new.quantite, 'Prescription',
      new.consultation_id, auth.uid()
    );
    return new;

  elsif tg_op = 'DELETE' then
    -- Annulation véritable : la consultation demeure, le stock est rendu.
    -- Consultation disparue : rien à rendre, le médicament a été servi.
    if exists (
      select 1 from scolarite.consultations_medicales c
      where c.id = old.consultation_id
    ) then
      insert into scolarite.mouvements_stock (
        medicament_id, type, quantite, motif, consultation_id, auteur_id
      )
      values (
        old.medicament_id, 'entree', old.quantite,
        'Annulation de prescription', old.consultation_id, auth.uid()
      );
    end if;
    return old;
  end if;

  return null;
end;
$$;
