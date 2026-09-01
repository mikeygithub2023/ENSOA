// Edge Function : espaces-eleves
//
// Ouvre et ferme les espaces élèves, en lot (toute une classe/stage) ou un
// par un. Réservée à l'administrateur : l'ouverture d'un espace est un acte
// de commandement, pas une conséquence automatique de l'inscription.
//
// Identifiants : le numéro de téléphone de l'élève sert de login et de mot
// de passe initial. Supabase authentifie par courriel, pas par numéro : on
// fabrique donc une adresse à partir du numéro normalisé
// (0908070405 -> 0908070405@eleve.ensoa.ci). L'application mobile ne
// demandera que le numéro et reconstituera l'adresse — l'élève n'a jamais à
// connaître ce détail.
//
// ⚠ Le numéro n'est pas un secret : il figure sur la fiche de l'élève et
// ses camarades le connaissent. C'est un mot de passe d'ouverture, à faire
// changer à la première connexion.
//
// Les tables sont désignées par leur schéma : le profil vit dans `socle`,
// l'apprenant et son cursus dans `scolarite`.
//
// Comme creer-compte, cette fonction s'exécute côté serveur : elle utilise la
// clé service, jamais embarquée dans l'application.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const DOMAINE = "eleve.ensoa.ci";

type Payload = {
  action: "creer" | "supprimer";
  /** Ouvre ou ferme l'espace de tous les apprenants de cette classe/stage. */
  classeId?: string;
  /** Ou seulement de ceux-ci. */
  apprenantIds?: string[];
};

type Resultat = {
  apprenantId: string;
  nom: string;
  statut: "cree" | "supprime" | "ignore";
  motif?: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Ne garde que les chiffres : les numéros sont saisis « 09 08 07 04 05 ». */
function normaliserTelephone(valeur: string | null): string | null {
  if (!valeur) return null;
  const chiffres = valeur.replace(/\D/g, "");
  // Supabase exige au moins 6 caractères de mot de passe ; un numéro trop
  // court est de toute façon inexploitable comme identifiant.
  return chiffres.length >= 6 ? chiffres : null;
}

function nomComplet(a: { prenom: string | null; nom: string | null }): string {
  return [a.prenom, a.nom].filter((s) => s && s.trim()).join(" ").trim() ||
    "Apprenant";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Méthode non autorisée" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Non authentifié" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const {
    data: { user: caller },
    error: callerError,
  } = await admin.auth.getUser(authHeader.replace("Bearer ", ""));
  if (callerError || !caller) {
    return jsonResponse({ error: "Session invalide" }, 401);
  }

  const { data: callerProfile, error: callerProfileError } = await admin.schema("socle").from("profiles")
    .select("role")
    .eq("id", caller.id)
    .single();
  if (callerProfileError || !callerProfile || callerProfile.role !== "admin") {
    return jsonResponse(
      { error: "Seul un administrateur peut gérer les espaces élèves" },
      403,
    );
  }

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Corps de requête invalide" }, 400);
  }

  if (payload.action !== "creer" && payload.action !== "supprimer") {
    return jsonResponse({ error: "action doit valoir creer ou supprimer" }, 400);
  }
  if (!payload.classeId && !payload.apprenantIds?.length) {
    return jsonResponse(
      { error: "Indiquez une classe/stage ou une liste d'apprenants" },
      400,
    );
  }

  let requete = admin.schema("scolarite").from("apprenants")
    .select("id, nom, prenom, telephone, division_id, grade, profile_id");
  if (payload.classeId) requete = requete.eq("classe_id", payload.classeId);
  if (payload.apprenantIds?.length) {
    requete = requete.in("id", payload.apprenantIds);
  }

  const { data: apprenants, error: apprenantsError } = await requete;
  if (apprenantsError) {
    return jsonResponse({ error: apprenantsError.message }, 400);
  }

  const resultats: Resultat[] = [];

  for (const apprenant of apprenants ?? []) {
    const nom = nomComplet(apprenant);

    if (payload.action === "supprimer") {
      if (!apprenant.profile_id) {
        resultats.push({
          apprenantId: apprenant.id,
          nom,
          statut: "ignore",
          motif: "Aucun espace ouvert",
        });
        continue;
      }
      // On délie d'abord : si la suppression du compte échoue, la fiche de
      // l'apprenant ne reste pas rattachée à un profil fantôme.
      //
      // Et pas seulement la fiche : plusieurs tables gardent l'identité de
      // qui a créé ou modifié une ligne, par une clé étrangère vers
      // `profiles` sans ON DELETE. Un élève ayant déposé un cours, ou dont
      // le compte a servi à enregistrer quoi que ce soit, ne pourrait plus
      // être supprimé — la base refuserait, et le message ne parlerait que
      // de contrainte. On détache donc tout ce qui peut l'être.
      const detachements: Array<[string, string]> = [
        ["apprenants", "profile_id"],
        ["apprenants", "deletion_requested_by"],
        ["notes", "deletion_requested_by"],
        ["mouvements_stock", "auteur_id"],
        ["antecedents_medicaux", "updated_by"],
        ["depenses", "created_by"],
        ["demandes_reapprovisionnement", "created_by"],
        ["cours", "created_by"],
        ["performances_sportives", "saisie_par"],
      ];
      let echecDetachement: string | null = null;
      for (const [table, colonne] of detachements) {
        const { error: erreurDetachement } = await admin.schema("scolarite").from(table)
          .update({ [colonne]: null })
          .eq(colonne, apprenant.profile_id);
        if (erreurDetachement) {
          echecDetachement = `${table}.${colonne} : ${erreurDetachement.message}`;
          break;
        }
      }
      if (echecDetachement) {
        resultats.push({
          apprenantId: apprenant.id,
          nom,
          statut: "ignore",
          motif: `Compte non détaché de ${echecDetachement}`,
        });
        continue;
      }

      const { error } = await admin.auth.admin.deleteUser(apprenant.profile_id);
      if (!error) {
        // `profiles` ne dépend pas de `auth.users` : sans cette ligne, le
        // profil survivrait au compte et l'élève resterait un utilisateur
        // fantôme, sans titulaire et sans accès.
        await admin.schema("socle").from("profiles").delete().eq("id", apprenant.profile_id);
      }
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: error ? "ignore" : "supprime",
        motif: error?.message,
      });
      continue;
    }

    if (apprenant.profile_id) {
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: "ignore",
        motif: "Espace déjà ouvert",
      });
      continue;
    }

    const telephone = normaliserTelephone(apprenant.telephone);
    if (!telephone) {
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: "ignore",
        motif: "Numéro de téléphone manquant ou trop court",
      });
      continue;
    }

    const email = `${telephone}@${DOMAINE}`;
    const { data: cree, error: creationError } = await admin.auth.admin
      .createUser({
        email,
        password: telephone,
        email_confirm: true,
        user_metadata: { nom: apprenant.nom, prenom: apprenant.prenom },
      });
    if (creationError || !cree.user) {
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: "ignore",
        // Deux apprenants partageant un numéro tombent ici : le second est
        // refusé, et c'est bien ce qu'il faut — deux espaces ne peuvent pas
        // partager le même identifiant.
        motif: creationError?.message ?? "Création du compte impossible",
      });
      continue;
    }

    // Le trigger handle_new_user a déjà créé un profil par défaut.
    const { error: profilError } = await admin.schema("socle").from("profiles")
      .update({
        nom: apprenant.nom,
        prenom: apprenant.prenom,
        role: "eleve_stagiaire",
        division_id: apprenant.division_id,
        grade: apprenant.grade,
        // Le numéro de téléphone n'est qu'un mot de passe d'ouverture :
        // l'élève devra en choisir un autre avant d'accéder à son espace.
        doit_changer_mot_de_passe: true,
      })
      .eq("id", cree.user.id);
    if (profilError) {
      await admin.auth.admin.deleteUser(cree.user.id);
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: "ignore",
        motif: profilError.message,
      });
      continue;
    }

    const { error: lienError } = await admin.schema("scolarite").from("apprenants")
      .update({ profile_id: cree.user.id })
      .eq("id", apprenant.id);
    if (lienError) {
      await admin.auth.admin.deleteUser(cree.user.id);
      resultats.push({
        apprenantId: apprenant.id,
        nom,
        statut: "ignore",
        motif: lienError.message,
      });
      continue;
    }

    resultats.push({ apprenantId: apprenant.id, nom, statut: "cree" });
  }

  return jsonResponse({ resultats });
});
