// ============================================================================
// Les fonctions appelées depuis l'application web.
//
// Avant d'envoyer la vraie requête, le navigateur demande au serveur s'il
// accepte un appel venu d'un autre domaine (requête OPTIONS, dite « CORS »).
// Sans réponse favorable, il n'envoie rien et l'application ne reçoit qu'un
// « Failed to fetch ». L'application de bureau ne pose pas cette question :
// c'est pourquoi ces fonctions marchaient sous Windows et pas sur le web.
// ============================================================================

const ENTETES_CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, " +
    "x-supabase-client-platform, x-supabase-client-platform-version, " +
    "x-supabase-client-runtime, x-supabase-client-runtime-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

/// `Deno.serve`, en répondant à la question préalable du navigateur et en
/// ajoutant les en-têtes CORS à chaque réponse.
export function servir(
  traiter: (req: Request) => Response | Promise<Response>,
) {
  return Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: ENTETES_CORS });
    }
    const reponse = await traiter(req);
    const entetes = new Headers(reponse.headers);
    for (const [cle, valeur] of Object.entries(ENTETES_CORS)) {
      entetes.set(cle, valeur);
    }
    return new Response(reponse.body, {
      status: reponse.status,
      statusText: reponse.statusText,
      headers: entetes,
    });
  });
}
