// ============================================================================
// Suppression d'un compte — côté serveur, pour la même raison que l'ouverture.
//
// Deux garde-fous : l'appelant doit avoir la charge du poste supprimé, et
// personne ne peut supprimer son propre compte (une école sans
// administrateur ne se rouvre pas toute seule).
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const socle = () => adminClient.schema("socle");

const ROLES_DU_POSTE: Record<string, [string | null, string | null]> = {
  administrateur: ["admin", "administrateur"],
  chef_division: ["chef_division", null],
  commandant_brigade: ["commandant_brigade", null],
  instructeur: ["instructeur", null],
  infirmerie: ["medecin", "sante"],
  eleve_stagiaire: ["eleve_stagiaire", null],
  chef_soutien_technique: [null, "chef_soutien_technique"],
  soutien_petrolier: [null, "soutien_petrolier"],
  garage: [null, "garage"],
  armurerie: [null, "armurerie"],
  poste_police: [null, "poste_police"],
  officier_adjoint: [null, "officier_adjoint"],
};

const POSTES_CREABLES: Record<string, string[]> = {
  administrateur: [
    "administrateur",
    "chef_division",
    "commandant_brigade",
    "instructeur",
    "infirmerie",
    "chef_soutien_technique",
    "poste_police",
    "officier_adjoint",
  ],
  chef_soutien_technique: ["soutien_petrolier", "garage", "armurerie"],
};

function posteDepuisRoles(role: string | null, roleLogistique: string | null): string | null {
  for (const [poste, [s, l]] of Object.entries(ROLES_DU_POSTE)) {
    if (s === role && l === roleLogistique) return poste;
  }
  return null;
}

const reponse = (corps: unknown, status: number) =>
  new Response(JSON.stringify(corps), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return reponse({ error: "Non authentifié." }, 401);

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: appelant } } = await callerClient.auth.getUser();
    if (!appelant) return reponse({ error: "Non authentifié." }, 401);

    const { id } = await req.json() as { id: string };
    if (!id) return reponse({ error: "Compte à supprimer non précisé." }, 400);

    // Se supprimer soi-même laisserait potentiellement l'école sans
    // administrateur, sans moyen d'en refaire un depuis l'application.
    if (id === appelant.id) {
      return reponse({ error: "Vous ne pouvez pas supprimer votre propre compte." }, 400);
    }

    const { data: profilAppelant, error: erreurProfil } = await socle()
      .from("profiles").select("role, role_logistique, actif").eq("id", appelant.id).maybeSingle();
    // Une lecture en panne n'est pas un compte fermé : les confondre a déjà
    // valu à l'administrateur qu'on lui dise que son propre compte était
    // désactivé.
    if (erreurProfil) {
      return reponse(
        { error: `Votre profil n'a pas pu être lu : ${erreurProfil.message}` },
        500,
      );
    }
    if (!profilAppelant) {
      return reponse({ error: "Aucun profil n'est rattaché à ce compte." }, 403);
    }
    if (!profilAppelant.actif) return reponse({ error: "Compte désactivé." }, 403);

    const postesPermis = POSTES_CREABLES[
      posteDepuisRoles(profilAppelant.role ?? null, profilAppelant.role_logistique ?? null) ?? ""
    ];
    if (!postesPermis) {
      return reponse({ error: "Vous n'êtes pas habilité à supprimer un compte." }, 403);
    }

    const { data: cible } = await socle()
      .from("profiles").select("role, role_logistique").eq("id", id).maybeSingle();
    if (!cible) return reponse({ error: "Compte introuvable." }, 404);

    const posteCible = posteDepuisRoles(cible.role ?? null, cible.role_logistique ?? null);
    if (!posteCible || !postesPermis.includes(posteCible)) {
      return reponse({ error: "Ce compte ne relève pas de votre autorité." }, 403);
    }

    // Le profil part avec le compte : `socle.profiles.id` référence
    // `auth.users(id)` en on delete cascade.
    const { error } = await adminClient.auth.admin.deleteUser(id);
    if (error) return reponse({ error: error.message }, 400);

    return reponse({ ok: true }, 200);
  } catch (erreur) {
    return reponse({ error: String(erreur) }, 500);
  }
});
