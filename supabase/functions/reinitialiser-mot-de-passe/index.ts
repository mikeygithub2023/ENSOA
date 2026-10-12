// ============================================================================
// Réinitialisation du mot de passe d'un compte — côté serveur.
//
// Changer le mot de passe de quelqu'un d'autre demande la clé `service_role`,
// qui ne doit jamais quitter le serveur : un client qui la détiendrait
// pourrait se donner n'importe quel compte.
//
// Avant cette fonction, un administrateur dont un agent avait perdu son mot
// de passe devait ouvrir la console Supabase. Qui tient les comptes doit
// pouvoir les débloquer depuis l'application.
//
// Trois garde-fous : l'appelant doit avoir la charge du poste visé — la même
// chaîne de commandement que l'ouverture d'un compte —, le mot de passe posé
// est provisoire et devra être remplacé à la première connexion, et personne
// ne réinitialise le sien par ce chemin : on change le sien en le
// connaissant, dans l'écran prévu pour cela.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const socle = () => adminClient.schema("socle");

/// Copie de `lib/core/postes.dart`, comme dans les deux autres fonctions.
/// Si vous modifiez l'une, modifiez les autres.
const ROLES_DU_POSTE: Record<string, [string | null, string | null]> = {
  administrateur: ["admin", "administrateur"],
  profil_personnalise: [null, "profil_personnalise"],
  chef_division: ["chef_division", null],
  commandant_promotion: ["commandant_promotion", null],
  commandant_brigade: ["commandant_brigade", null],
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
    "profil_personnalise",
    "chef_division",
    "commandant_promotion",
    "commandant_brigade",
    "infirmerie",
    "chef_soutien_technique",
    "poste_police",
    "officier_adjoint",
    // Le chef du soutien technique arme ses trois services lui-meme, mais
    // sans exclusivite : l'ecole est restee sans armurier parce que lui
    // seul pouvait en nommer un.
    "soutien_petrolier",
    "garage",
    "armurerie",
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

    const { id, motDePasse } = await req.json() as {
      id: string;
      motDePasse: string;
    };
    if (!id || !motDePasse) return reponse({ error: "Champs manquants." }, 400);
    if (motDePasse.length < 8) {
      return reponse({ error: "Le mot de passe doit faire au moins 8 caractères." }, 400);
    }

    // Son propre mot de passe se change en le connaissant, dans l'écran
    // prévu. Passer par ici reviendrait à s'en poser un sans preuve d'être
    // soi — et à le marquer « à changer » pour rien.
    if (id === appelant.id) {
      return reponse(
        { error: "Changez votre propre mot de passe depuis votre compte." },
        400,
      );
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
      return reponse({ error: "Vous n'êtes pas habilité à réinitialiser un mot de passe." }, 403);
    }

    const { data: cible } = await socle()
      .from("profiles").select("role, role_logistique").eq("id", id).maybeSingle();
    if (!cible) return reponse({ error: "Compte introuvable." }, 404);

    // Un compte dont le poste n'est pas reconnu ne relève de l'autorité de
    // personne, et deviendrait donc impossible à débloquer. C'est précisément
    // celui qu'il faut pouvoir reprendre en main — même raisonnement que pour
    // la suppression.
    const posteCible = posteDepuisRoles(cible.role ?? null, cible.role_logistique ?? null);
    if (posteCible && !postesPermis.includes(posteCible)) {
      return reponse({ error: "Ce compte ne relève pas de votre autorité." }, 403);
    }

    const { error } = await adminClient.auth.admin.updateUserById(id, {
      password: motDePasse,
    });
    if (error) return reponse({ error: error.message }, 400);

    // Le mot de passe posé ici est connu de celui qui l'a posé : tant qu'il
    // n'est pas remplacé, deux personnes peuvent entrer sous la même
    // identité, et le journal d'audit attribuerait à l'une ce que l'autre a
    // fait.
    const { error: erreurDrapeau } = await socle()
      .from("profiles")
      .update({ doit_changer_mot_de_passe: true })
      .eq("id", id);
    if (erreurDrapeau) {
      return reponse(
        {
          error:
            "Le mot de passe a été changé, mais le compte n'a pas été marqué " +
            `« à changer » : ${erreurDrapeau.message}`,
        },
        500,
      );
    }

    return reponse({ ok: true }, 200);
  } catch (erreur) {
    return reponse({ error: String(erreur) }, 500);
  }
});
