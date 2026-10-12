// ============================================================================
// Ouverture d'un compte — côté serveur, jamais côté application.
//
// C'est cette fonction qui détient la clé service_role, donc le droit de
// créer un compte. Elle vérifie d'abord QUI appelle, et si l'appelant a la
// charge du poste demandé : sans ce contrôle, n'importe quel compte connecté
// pourrait appeler la fonction directement et se fabriquer un administrateur.
//
// Elle remplace les deux fonctions des applications d'origine
// (`create-user` côté scolarité, `admin-create-user` côté soutien technique).
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const socle = () => adminClient.schema("socle");

/// Les rôles que pose chaque poste — copie de `lib/core/postes.dart`.
/// L'infirmerie et l'administrateur en portent deux : une seule infirmerie
/// pour l'école, un seul administrateur pour les deux modules.
const ROLES_DU_POSTE: Record<string, [string | null, string | null]> = {
  administrateur: ["admin", "administrateur"],
  // Tous les services créés par l'administrateur portent ce même rôle ; la
  // ligne `profil_personnalise_id` dit lequel. Une valeur de rôle par
  // service aurait demandé une migration à chaque création.
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

/// Qui ouvre un compte pour qui — la chaîne de commandement.
///
/// La même table existe côté application (`postes.dart`), mais c'est
/// celle-ci qui fait foi : là-bas elle masque des choix dans une liste, ici
/// elle les refuse. Si vous modifiez l'une, modifiez l'autre.
const POSTES_CREABLES: Record<string, string[]> = {
  administrateur: [
    "administrateur",
    "chef_division",
    "commandant_promotion",
    "commandant_brigade",
    "infirmerie",
    "chef_soutien_technique",
    "poste_police",
    "officier_adjoint",
    "profil_personnalise",
    // Le chef du soutien technique arme ses trois services lui-meme, mais
    // sans exclusivite : l'ecole est restee sans armurier parce que lui
    // seul pouvait en nommer un.
    "soutien_petrolier",
    "garage",
    "armurerie",
  ],
  chef_soutien_technique: ["soutien_petrolier", "garage", "armurerie"],
};

/// Même règle que `Identite.emailDepuisMatricule` côté application. Calculé
/// ici plutôt que reçu du client : c'est la clé de connexion, elle ne se
/// négocie pas.
function emailDepuisMatricule(matricule: string): string {
  return matricule.toLowerCase().replace(/[^a-z0-9]/g, "") + "@sig.ensoa.ci";
}

/// Le poste de l'appelant, déduit de ses deux rôles.
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

    // Le client de l'appelant — sert uniquement à savoir QUI appelle, à
    // partir de son propre jeton.
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: appelant } } = await callerClient.auth.getUser();
    if (!appelant) return reponse({ error: "Non authentifié." }, 401);

    const { data: profilAppelant, error: erreurProfilAppelant } = await socle()
      .from("profiles")
      .select("role, role_logistique, actif")
      .eq("id", appelant.id)
      .maybeSingle();

    // Une lecture en panne n'est pas un compte fermé : les confondre a déjà
    // valu à l'administrateur qu'on lui dise que son propre compte était
    // désactivé.
    if (erreurProfilAppelant) {
      return reponse(
        { error: `Votre profil n'a pas pu être lu : ${erreurProfilAppelant.message}` },
        500,
      );
    }
    if (!profilAppelant) {
      return reponse({ error: "Aucun profil n'est rattaché à ce compte." }, 403);
    }
    if (!profilAppelant.actif) {
      return reponse({ error: "Compte désactivé." }, 403);
    }

    const posteAppelant = posteDepuisRoles(
      profilAppelant.role ?? null,
      profilAppelant.role_logistique ?? null,
    );
    const postesPermis = POSTES_CREABLES[posteAppelant ?? ""];
    if (!postesPermis) {
      return reponse({ error: "Vous n'êtes pas habilité à ouvrir un compte." }, 403);
    }

    const body = await req.json();
    const { matricule, nom, prenom, grade, poste, motDePasse, titre, divisionId, promotionId, celluleId, profilPersonnaliseId } = body as {
      matricule: string;
      nom: string;
      prenom: string;
      grade: string | null;
      poste: string;
      motDePasse: string;
      titre: string | null;
      divisionId: string | null;
      promotionId: string | null;
      celluleId: number | null;
      profilPersonnaliseId: string | null;
    };

    if (!matricule || !nom || !poste || !motDePasse) {
      return reponse({ error: "Champs manquants." }, 400);
    }
    if (motDePasse.length < 8) {
      return reponse({ error: "Le mot de passe doit faire au moins 8 caractères." }, 400);
    }

    // Le contrôle qui compte : l'appelant demande-t-il un poste dont il a la
    // charge ? Sans lui, il suffirait d'appeler la fonction directement, en
    // contournant la liste déroulante de l'application.
    if (!postesPermis.includes(poste)) {
      return reponse(
        { error: `Vous n'êtes pas habilité à ouvrir un compte « ${poste} ».` },
        403,
      );
    }

    const roles = ROLES_DU_POSTE[poste];
    if (!roles) return reponse({ error: `Poste inconnu : ${poste}.` }, 400);

    // Un compte « profil personnalisé » sans service désigné serait membre
    // d'une famille sans en être d'aucun service : il ne verrait jamais une
    // seule tâche, et rien à l'écran ne dirait pourquoi. La base porte la
    // même contrainte ; on refuse ici pour donner un message lisible.
    if (poste === "profil_personnalise" && !profilPersonnaliseId) {
      return reponse({ error: "Ce poste demande un service : choisissez-le." }, 400);
    }
    if (poste !== "profil_personnalise" && profilPersonnaliseId) {
      return reponse({ error: "Ce poste ne se rattache à aucun service." }, 400);
    }

    // Le service doit exister et être encore ouvert : on n'affecte personne
    // à un service dissous.
    if (profilPersonnaliseId) {
      const { data: service } = await socle()
        .from("profil_personnalise")
        .select("id, actif")
        .eq("id", profilPersonnaliseId)
        .maybeSingle();
      if (!service || service.actif !== true) {
        return reponse({ error: "Service inconnu ou retiré." }, 400);
      }
    }

    const email = emailDepuisMatricule(matricule);

    const { data: cree, error: erreurCreation } = await adminClient.auth.admin.createUser({
      email,
      password: motDePasse,
      email_confirm: true,
      user_metadata: { nom, prenom },
    });
    if (erreurCreation || !cree.user) {
      return reponse(
        { error: erreurCreation?.message ?? "Échec de la création du compte." },
        400,
      );
    }

    // Le déclencheur `on_auth_user_created` a déjà posé la ligne de profil :
    // on la complète plutôt que d'en insérer une seconde.
    const { error: erreurProfil } = await socle()
      .from("profiles")
      .upsert({
        id: cree.user.id,
        matricule,
        nom,
        prenom,
        grade,
        // Le titre sous lequel on le nomme, quand il diffère du libellé du
        // poste — « Commandant de l'école », par exemple.
        titre: titre && titre.trim() ? titre.trim() : null,
        role: roles[0],
        role_logistique: roles[1],
        division_id: divisionId,
        // La promotion que commande un Commandant de Brigade — elle borne
        // tout ce qu'il voit. Nulle pour les autres postes.
        promotion_id:
          poste === "commandant_brigade" || poste === "commandant_promotion"
            ? promotionId
            : null,
        cellule_id: celluleId,
        profil_personnalise_id: profilPersonnaliseId,
        actif: true,
        // Le mot de passe posé ici est connu de celui qui ouvre le compte :
        // il devra être remplacé à la première connexion, sans quoi deux
        // personnes pourraient entrer sous la même identité — et le journal
        // d'audit attribuerait à l'une ce que l'autre a fait.
        doit_changer_mot_de_passe: true,
      }, { onConflict: "id" });

    if (erreurProfil) {
      // Compte créé mais profil en échec (matricule déjà pris, par exemple) :
      // on annule la création pour ne pas laisser un compte orphelin.
      await adminClient.auth.admin.deleteUser(cree.user.id);
      return reponse({ error: erreurProfil.message }, 400);
    }

    return reponse({ id: cree.user.id, email }, 200);
  } catch (erreur) {
    return reponse({ error: String(erreur) }, 500);
  }
});
