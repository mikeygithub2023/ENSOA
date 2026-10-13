// ============================================================================
// Fonction serveur déclenchée par un Database Webhook sur INSERT dans la
// table `notification` (voir instructions de déploiement fournies à part).
// Résout les destinataires (utilisateur précis / rôle / global), retrouve
// leurs jetons d'appareil, et pousse la notification via Firebase Cloud
// Messaging — y compris quand l'application est fermée.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

// Le projet Firebase est lu dans le compte de service plutôt que codé en
// dur : une seule variable à poser, et rien à corriger si le projet change.

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// Un secret posé puis vidé vaut la chaîne vide, pas `undefined` : `??` ne
// bascule donc pas sur le suivant, et `JSON.parse("")` faisait échouer la
// fonction au chargement — aucune notification ne partait, sans un mot
// d'explication. On retient le premier secret réellement renseigné.
function secretRenseigne(...noms: string[]): string {
  for (const nom of noms) {
    const valeur = Deno.env.get(nom);
    if (valeur && valeur.trim()) return valeur;
  }
  throw new Error(
    "Aucun compte de service Firebase n'est renseigné : posez " +
      noms.join(" ou ") + " dans les secrets du projet.",
  );
}

const IDENTIFIANTS = JSON.parse(
  secretRenseigne("FCM_SERVICE_ACCOUNT", "FIREBASE_SERVICE_ACCOUNT"),
);

async function obtenirJetonAcces(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: IDENTIFIANTS,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const jeton = await client.getAccessToken();
  return jeton.token as string;
}

async function resoudreJetonsAppareils(notification: Record<string, unknown>): Promise<string[]> {
  const destinataireId = notification.destinataire_id as string | null;
  const roleCible = notification.role_cible as string | null;

  if (destinataireId) {
    const { data } = await supabase.schema("socle").from("device_token").select("token").eq("utilisateur_id", destinataireId);
    return (data ?? []).map((d) => d.token as string);
  }

  if (roleCible) {
    // `role_cible` porte un rôle du soutien technique : il se compare à
    // `role_logistique`, pas à `role`, qui est celui de la scolarité. La
    // confusion ne rendait jamais personne, et la notification n'atteignait
    // aucun appareil.
    const { data: profils } = await supabase.schema("socle").from("profiles")
      .select("id").eq("role_logistique", roleCible);
    const ids = (profils ?? []).map((p) => p.id as string);
    if (ids.length === 0) return [];
    const { data } = await supabase.schema("socle").from("device_token").select("token").in("utilisateur_id", ids);
    return (data ?? []).map((d) => d.token as string);
  }

  // Ni destinataire précis ni rôle : notification globale.
  const { data } = await supabase.schema("socle").from("device_token").select("token");
  return (data ?? []).map((d) => d.token as string);
}

Deno.serve(async (req) => {
  try {
    // Cette fonction n'avait AUCUN contrôle d'appelant : ni en-tête lu, ni
    // profil, ni rôle. Le seul laissez-passer était la clé publishable —
    // qui est publique par destination et voyage dans chaque APK. Quiconque
    // la lisait poussait une notification de son choix sur TOUTES les
    // tablettes de l'école, au nom de l'établissement : « changez votre mot
    // de passe ici ».
    //
    // Elle n'est appelée que par un déclencheur de la base, jamais par
    // l'application. Un secret partagé entre les deux suffit donc, et il ne
    // quitte jamais le serveur.
    const secretAttendu = Deno.env.get("WEBHOOK_SECRET");
    if (!secretAttendu) {
      // Mieux vaut refuser que s'ouvrir : un secret absent ne doit pas
      // valoir autorisation.
      return new Response("Secret de webhook non configuré", { status: 503 });
    }
    if (req.headers.get("x-webhook-secret") !== secretAttendu) {
      return new Response("Interdit", { status: 403 });
    }

    const payload = await req.json();
    const notification = payload.record as Record<string, unknown>;

    const jetons = await resoudreJetonsAppareils(notification);
    if (jetons.length === 0) return new Response("Aucun destinataire avec appareil enregistré", { status: 200 });

    const accessToken = await obtenirJetonAcces();

    await Promise.all(
      jetons.map((token) =>
        fetch(`https://fcm.googleapis.com/v1/projects/${IDENTIFIANTS.project_id}/messages:send`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: {
                title: notification.titre,
                body: notification.message,
              },
              android: { priority: "high" },
            },
          }),
        })
      ),
    );

    return new Response("OK", { status: 200 });
  } catch (erreur) {
    console.error(erreur);
    return new Response(String(erreur), { status: 500 });
  }
});
