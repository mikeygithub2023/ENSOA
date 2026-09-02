-- ============================================================================
-- Le journal d'audit revient à l'administrateur seul.
--
-- En fusionnant les deux journaux — celui de la scolarité et l'historique du
-- soutien technique —, j'avais ouvert la lecture au chef du Soutien
-- Technique en plus de l'administrateur : c'était le comportement de
-- l'application d'origine, où il consultait l'historique de son service. Le
-- journal unifié n'est plus cela : il porte les actions de toute l'école,
-- scolarité comprise — notes, fiches d'élèves, consultations médicales.
--
-- Un journal d'audit dit qui a fait quoi. C'est un instrument de
-- commandement, pas un tableau de bord de service : il revient à celui qui
-- commande l'école.
--
-- L'écriture ne bouge pas : chacun continue d'y inscrire ses propres
-- actions, sans quoi le journal ne vaudrait rien.
-- ============================================================================

drop policy if exists audit_log_select_soutien on socle.audit_log;

-- `audit_log_select_admin` (migration initiale de la scolarité) suffit
-- désormais : elle n'ouvre qu'au rôle `admin`, que seul le poste
-- d'administrateur porte.

-- Contrôle : plus qu'une seule politique de lecture sur le journal.
select policyname, cmd
from pg_policies
where schemaname = 'socle' and tablename = 'audit_log'
order by cmd, policyname;
