-- ============================================================================
-- Pourquoi un enregistrement est-il refusé ?
--
-- Lire le code ne suffit plus : les requêtes sont justes, les colonnes
-- existent, les politiques sont en place. Ce qui manque, c'est la réponse du
-- serveur — et l'application, jusqu'ici, la remplaçait par « Erreur
-- Supabase : ... ».
--
-- Ce script rejoue les deux enregistrements qui échouent (une vidange, une
-- distribution) SOUS L'IDENTITÉ DE L'ADMINISTRATEUR, exactement comme
-- l'application les envoie, et rapporte ce que PostgreSQL répond.
--
-- Rien n'est écrit : tout est annulé à la fin (`rollback`).
--
-- OÙ : Dashboard Supabase > SQL Editor > coller ce fichier entier > Run.
--      Recopier le tableau de résultat.
-- ============================================================================

begin;

create or replace function pg_temp.diagnostic()
returns table (etape text, verdict text)
language plpgsql
as $diag$
declare
  admin_id      uuid;
  vehicule_test bigint;
  stock_test    bigint;
begin
  -- --- 1. Le compte qui se connecte ---------------------------------------
  select p.id into admin_id
  from socle.profiles p
  where p.role_logistique = 'administrateur'
  order by p.created_at
  limit 1;

  if admin_id is null then
    return query select
      'compte administrateur'::text,
      'AUCUN profil ne porte role_logistique = administrateur — '
      'toutes les politiques d''écriture de l''admin sont donc inopérantes.'::text;
    return;
  end if;

  return query
    select 'compte administrateur'::text,
           (p.matricule
            || '  ·  role=' || coalesce(p.role::text, '∅')
            || '  ·  role_logistique=' || coalesce(p.role_logistique::text, '∅')
            || '  ·  actif=' || p.actif)::text
    from socle.profiles p where p.id = admin_id;

  -- --- 2. Y a-t-il seulement de quoi enregistrer ? -------------------------
  -- Un formulaire peut échouer faute de référentiel, pas faute de droits.
  return query select 'véhicules'::text,
                      (select count(*) from logistique.vehicule)::text;
  return query select 'soutes'::text,
                      (select count(*) from logistique.soute)::text;
  return query select 'répartitions'::text,
                      (select count(*) from logistique.repartition)::text;
  return query select 'lignes soute × répartition'::text,
                      (select count(*) from logistique.soute_type_stock)::text;

  select v.id into vehicule_test from logistique.vehicule v order by v.id limit 1;
  select s.id into stock_test
  from logistique.soute_type_stock s order by s.id limit 1;

  -- --- 3. Ce que la RLS accorde à ce compte -------------------------------
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', admin_id, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;

  return query select 'socle.current_user_role()'::text,
                      coalesce(socle.current_user_role()::text, '∅ (nul)');

  -- --- 4. L'insertion d'une vidange, telle que l'application l'envoie ------
  if vehicule_test is null then
    return query select 'insertion vidange'::text,
                        'IMPOSSIBLE À TESTER — aucun véhicule en base.'::text;
  else
    begin
      insert into logistique.vidange
        (filtre_vidange, type_huile, qte_huile, vehicule_id, utilisateur_id)
      values ('DIAGNOSTIC', 'DIAGNOSTIC', 1, vehicule_test, admin_id);
      return query select 'insertion vidange'::text, 'ACCEPTÉE'::text;
    exception when others then
      return query select 'insertion vidange'::text,
                          ('REFUSÉE — ' || sqlstate || ' : ' || sqlerrm)::text;
    end;
  end if;

  -- --- 5. La mise à jour du véhicule qui suit la vidange -------------------
  if vehicule_test is not null then
    begin
      update logistique.vehicule
      set kilometrage_vidange_prochaine = kilometrage_vidange_prochaine
      where id = vehicule_test;
      if not found then
        return query select 'mise à jour véhicule'::text,
                            'REFUSÉE — 0 ligne touchée (la RLS masque la ligne).'::text;
      else
        return query select 'mise à jour véhicule'::text, 'ACCEPTÉE'::text;
      end if;
    exception when others then
      return query select 'mise à jour véhicule'::text,
                          ('REFUSÉE — ' || sqlstate || ' : ' || sqlerrm)::text;
    end;
  end if;

  -- --- 6. L'insertion d'une distribution ----------------------------------
  if stock_test is null then
    return query select 'insertion distribution'::text,
                        'IMPOSSIBLE À TESTER — aucune ligne soute × répartition. '
                        'C''est déjà la cause : le formulaire n''a rien à choisir.'::text;
  else
    begin
      insert into logistique.distribution
        (soute_stock_id, utilisateur_id, qte_percue, type_carburant,
         contact, grade_destinataire, destinataire,
         vehicule, vhl_immatriculation, kilometrage, motif)
      values (stock_test, admin_id, 1, 'Gasoil',
              'DIAGNOSTIC', 'DIAGNOSTIC', 'DIAGNOSTIC',
              'DIAGNOSTIC', 'DIAGNOSTIC', 0, null);
      return query select 'insertion distribution'::text, 'ACCEPTÉE'::text;
    exception when others then
      return query select 'insertion distribution'::text,
                          ('REFUSÉE — ' || sqlstate || ' : ' || sqlerrm)::text;
    end;

    -- La distribution retire ensuite du stock : deuxième requête, deuxième
    -- occasion d'être refusée.
    begin
      update logistique.soute_type_stock
      set qte_gasoil = qte_gasoil
      where id = stock_test;
      if not found then
        return query select 'mise à jour du stock'::text,
                            'REFUSÉE — 0 ligne touchée (la RLS masque la ligne).'::text;
      else
        return query select 'mise à jour du stock'::text, 'ACCEPTÉE'::text;
      end if;
    exception when others then
      return query select 'mise à jour du stock'::text,
                          ('REFUSÉE — ' || sqlstate || ' : ' || sqlerrm)::text;
    end;
  end if;

  reset role;
end;
$diag$;

select * from pg_temp.diagnostic();

-- Rien n'est conservé : ni les lignes de test, ni la fonction.
rollback;
