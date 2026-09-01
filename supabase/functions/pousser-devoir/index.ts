// Edge Function : pousser-devoir
//
// Envoie une notification poussée aux téléphones des élèves d'une
// classe/stage quand un devoir leur est donné.
//
// La notification en base (table `notifications`, trigger de la migration
// 045) reste la source de vérité : elle est consultable dans l'espace élève
// et survit à tout. Le message poussé n'en est que le rappel sur l'écran
// verrouillé — s'il se perd, l'élève retrouve son devoir en ouvrant
// l'application.
//
// Firebase Cloud Messaging remet les messages à des jetons d'appareil, pas à
// des comptes : la table `appareils` fait la correspondance (migration 046).
//
// Authentification auprès de Google : l'API FCM HTTP v1 exige un jeton
// OAuth2 obtenu en signant un JWT avec la clé privée d'un compte de service.
// Cette clé est un secret Supabase (`FCM_SERVICE_ACCOUNT`), jamais dans le
// dépôt ni dans l'application.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
/// Le compte de service Google qui signe les envois.
///
/// Les deux applications d'origine l'avaient nommé différemment — la
/// scolarité `FCM_SERVICE_ACCOUNT`, le soutien technique
/// `FIREBASE_SERVICE_ACCOUNT` — pour un seul et même projet Firebase. On
/// accepte les deux noms, et on retombe sur le second : c'est celui qui est
/// réellement renseigné sur le projet unifié, l'autre y ayant été créé vide.
///
/// Une valeur vide vaut une valeur absente : sans elle, la notification en
/// base est quand même posée, et c'est elle qui fait foi.
const FCM_SERVICE_ACCOUNT =
  (Deno.env.get("FCM_SERVICE_ACCOUNT")?.trim() ||
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT")?.trim()) ??
  "";

/** Les rôles autorisés à donner un devoir, donc à déclencher l'envoi. */
const ENCADREMENT = ["admin", "chef_division", "instructeur"];

type CompteDeService = {
  client_email: string;
  private_key: string;
  project_id: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function base64url(donnees: Uint8Array): string {
  let binaire = "";
  for (const octet of donnees) binaire += String.fromCharCode(octet);
  return btoa(binaire).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function base64urlTexte(texte: string): string {
  return base64url(new TextEncoder().encode(texte));
}

/** Extrait les octets DER d'une clé privée PEM (format PKCS#8). */
function pemVersOctets(pem: string): Uint8Array {
  const corps = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaire = atob(corps);
  const octets = new Uint8Array(binaire.length);
  for (let i = 0; i < binaire.length; i++) octets[i] = binaire.charCodeAt(i);
  return octets;
}

/**
 * Échange un JWT signé contre un jeton d'accès Google, valable une heure.
 *
 * Chaque appel de la fonction en redemande un : les invocations sont trop
 * espacées pour qu'un cache serve à quelque chose, et une instance Deno ne
 * survit pas d'un devoir à l'autre.
 */
async function jetonAcces(compte: CompteDeService): Promise<string> {
  const maintenant = Math.floor(Date.now() / 1000);
  const entete = base64urlTexte(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const charge = base64urlTexte(JSON.stringify({
    iss: compte.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: maintenant,
    exp: maintenant + 3600,
  }));

  const cle = await crypto.subtle.importKey(
    "pkcs8",
    pemVersOctets(compte.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cle,
    new TextEncoder().encode(`${entete}.${charge}`),
  );
  const jwt = `${entete}.${charge}.${base64url(new Uint8Array(signature))}`;

  const reponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!reponse.ok) {
    throw new Error(`Google a refusé la clé de service : ${await reponse
      .text()}`);
  }
  const corps = await reponse.json();
  return corps.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Méthode non autorisée" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "Non authentifié" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: { user: appelant }, error: erreurAppelant } = await admin.auth
    .getUser(authHeader.replace("Bearer ", ""));
  if (erreurAppelant || !appelant) {
    return jsonResponse({ error: "Session invalide" }, 401);
  }

  const { data: profil } = await admin.schema("socle").from("profiles")
    .select("role")
    .eq("id", appelant.id)
    .single();
  if (!profil || !ENCADREMENT.includes(profil.role)) {
    return jsonResponse(
      { error: "Seul l'encadrement peut notifier un devoir" },
      403,
    );
  }

  let devoirId: string | undefined;
  try {
    devoirId = (await req.json()).devoirId;
  } catch {
    return jsonResponse({ error: "Corps de requête invalide" }, 400);
  }
  if (!devoirId) return jsonResponse({ error: "devoirId manquant" }, 400);

  const { data: devoir } = await admin.schema("scolarite").from("cours")
    .select("id, titre, type, classe_id, date_remise, matieres(nom)")
    .eq("id", devoirId)
    .single();
  if (!devoir || devoir.type !== "devoir") {
    return jsonResponse({ error: "Devoir introuvable" }, 404);
  }

  // Sans clé de service, la notification en base a déjà été posée : on le
  // dit franchement plutôt que d'échouer, l'essentiel est enregistré.
  if (!FCM_SERVICE_ACCOUNT) {
    return jsonResponse({
      envoyees: 0,
      configure: false,
      message:
        "Firebase n'est pas configuré : les élèves verront le devoir dans " +
        "leur espace, mais aucune notification n'a été poussée.",
    });
  }

  const { data: apprenants } = await admin.schema("scolarite").from("apprenants")
    .select("profile_id")
    .eq("classe_id", devoir.classe_id)
    .not("profile_id", "is", null);

  const profils = (apprenants ?? []).map((a) => a.profile_id as string);
  if (profils.length === 0) {
    return jsonResponse({ envoyees: 0, configure: true });
  }

  const { data: appareils } = await admin.schema("socle").from("appareils")
    .select("jeton")
    .in("profile_id", profils);

  const jetons = (appareils ?? []).map((a) => a.jeton as string);
  if (jetons.length === 0) {
    return jsonResponse({ envoyees: 0, configure: true });
  }

  let compte: CompteDeService;
  let acces: string;
  try {
    compte = JSON.parse(FCM_SERVICE_ACCOUNT);
    acces = await jetonAcces(compte);
  } catch (e) {
    return jsonResponse({ error: `Firebase : ${(e as Error).message}` }, 500);
  }

  const matiere = (devoir.matieres as { nom: string } | null)?.nom;
  const remise = devoir.date_remise
    ? new Date(devoir.date_remise as string).toLocaleDateString("fr-FR")
    : null;
  const corps = [
    `Le devoir « ${devoir.titre} »`,
    matiere ? ` (${matiere})` : "",
    " vous a été donné",
    remise ? `, à composer avant le ${remise}` : "",
    ".",
  ].join("");

  const url =
    `https://fcm.googleapis.com/v1/projects/${compte.project_id}/messages:send`;

  const resultats = await Promise.all(jetons.map(async (jeton) => {
    const reponse = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${acces}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: jeton,
          notification: { title: "Nouveau devoir", body: corps },
          // `data` sert au tri côté application : un toucher sur la
          // notification doit ouvrir la rubrique Devoirs, pas l'accueil.
          data: { type: "devoir", devoirId: devoir.id as string },
          android: {
            priority: "HIGH",
            notification: { channel_id: "devoirs" },
          },
        },
      }),
    });
    return { jeton, ok: reponse.ok, statut: reponse.status };
  }));

  // Un jeton refusé est un jeton mort : application désinstallée, données
  // effacées. On le retire plutôt que de le réessayer à chaque devoir.
  const morts = resultats
    .filter((r) => !r.ok && (r.statut === 404 || r.statut === 400))
    .map((r) => r.jeton);
  if (morts.length > 0) {
    await admin.schema("socle").from("appareils").delete().in("jeton", morts);
  }

  return jsonResponse({
    configure: true,
    envoyees: resultats.filter((r) => r.ok).length,
    echouees: resultats.filter((r) => !r.ok).length,
    jetonsRetires: morts.length,
  });
});
