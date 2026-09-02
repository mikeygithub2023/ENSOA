-- ============================================================================
-- Les notifications arrivent sans qu'on ait à changer d'écran.
--
-- Le compteur de la barre se tenait à jour au changement d'écran : un
-- administrateur qui laisse sa session ouverte sans rien toucher ne voyait
-- donc jamais arriver une demande de suppression. Or c'est précisément ce
-- qu'on attend d'une notification.
--
-- On inscrit la table au flux temps réel de Supabase. La RLS continue de
-- s'appliquer : chacun ne reçoit que ce qu'il a le droit de lire.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'socle'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table socle.notifications;
  end if;
end $$;

-- Contrôle : la table doit figurer dans la publication.
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'socle';
