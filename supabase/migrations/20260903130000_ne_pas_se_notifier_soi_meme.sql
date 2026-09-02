-- ============================================================================
-- On ne se prévient pas soi-même.
--
-- L'administrateur enregistre un dépotage, et sa propre pastille s'allume
-- pour le lui annoncer. Le chef du soutien technique établit un bon d'arme,
-- et reçoit la nouvelle qu'il vient d'écrire. Ce bruit-là décrédibilise tout
-- le reste : au bout de trois notifications inutiles, plus personne ne
-- regarde les siennes.
--
-- L'auteur de l'écriture est retiré des destinataires. `auth.uid()` reste
-- lisible dans une fonction `security definer` — c'est un paramètre de
-- session, non un privilège — et vaut nul pour une écriture faite hors
-- session, par une fonction serveur ou à la main : tout le monde est alors
-- prévenu, ce qui est le comportement voulu.
-- ============================================================================

create or replace function socle.notifier(
  p_destinataires uuid[],
  p_type text,
  p_titre text,
  p_message text
)
returns void
language sql security definer
set search_path = socle, public
as $$
  insert into socle.notifications (profile_id, type, title, message)
  select distinct d, p_type, p_titre, p_message
  from unnest(p_destinataires) as d
  where d is not null
    and d is distinct from auth.uid();
$$;
