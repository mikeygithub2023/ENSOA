// Edge Function : assistant-ia
//
// L'administrateur pose une question en français sur l'état de l'école ; la
// fonction rassemble un instantané des données, l'envoie à DeepSeek avec la
// question, et renvoie une réponse structurée — texte, points clés, et le
// cas échéant un graphique — que l'application affiche telle quelle.
//
// Deux partis pris tiennent le reste :
//
//   1. La clé DeepSeek ne quitte jamais le serveur. Embarquée dans
//      l'application, elle serait lisible par quiconque décompresse l'APK
//      ou observe les échanges réseau, et facturable à l'école par
//      n'importe qui.
//
//   2. Le modèle reçoit toujours un instantané agrégé, et en plus le
//      dossier détaillé des seuls apprenants que la question désigne.
//
//      Ce n'est pas une demi-mesure mais une nécessité : verser toute la
//      base à chaque question dépasserait la fenêtre de contexte du modèle
//      dès la deuxième promotion, et ferait payer à l'école, à chaque
//      question, la lecture de dossiers dont il n'est pas question.
//
//      Le répertoire — nom, matricule, classe — est donc envoyé en entier,
//      et sert au modèle à savoir qui existe. Les dossiers nominatifs
//      (notes, permissions, absences, consultations) ne suivent que pour
//      les apprenants nommés dans la question.
//
// ⚠ Ces dossiers comprennent des données de santé. Elles sortent de l'école
// vers un prestataire tiers à chaque question qui nomme quelqu'un. C'est un
// choix assumé du commandement, pas un effet de bord : quiconque reprend ce
// code doit le savoir avant de l'étendre.
//
// Réservée à l'administrateur : lui seul a vue sur toute l'école, et cette
// fonction s'exécute avec la clé de service, donc hors des règles de
// cloisonnement par division.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY");

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Compte les occurrences d'un champ — « combien par état ». */
function compterPar<T>(lignes: T[], champ: (l: T) => string | null): Record<string, number> {
  const compte: Record<string, number> = {};
  for (const ligne of lignes) {
    const cle = champ(ligne);
    if (cle) compte[cle] = (compte[cle] ?? 0) + 1;
  }
  return compte;
}

/** Minuscules sans accents : « Kouamé » et « kouame » doivent se rencontrer. */
function normaliser(texte: string): string {
  return texte
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9\s]/g, " ");
}

/** Nombre maximum de dossiers détaillés joints à une question.
 *
 * Une question porte sur une personne, parfois sur une poignée. Au-delà,
 * c'est une liste qu'on demande, et le répertoire agrégé y répond déjà —
 * inutile d'envoyer cinquante dossiers médicaux pour compter des absences.
 */
const MAX_DOSSIERS = 5;

/**
 * Les apprenants que la question désigne, par matricule ou par nom.
 *
 * Les fragments de moins de trois caractères sont ignorés : « Ba » ou « Ko »
 * rattraperaient la moitié de l'école.
 */
function apprenantsCites(question: string, apprenants: any[]): any[] {
  const q = ` ${normaliser(question)} `;
  const trouves = apprenants.filter((a: any) => {
    const matricule = normaliser(a.matricule ?? "");
    if (matricule.length >= 3 && q.includes(matricule)) return true;
    const nom = normaliser(a.nom ?? "");
    const prenom = normaliser(a.prenom ?? "");
    const parNom = nom.length >= 3 && q.includes(` ${nom} `);
    const parPrenom = prenom.length >= 3 && q.includes(` ${prenom} `);
    return parNom || parPrenom;
  });
  return trouves.slice(0, MAX_DOSSIERS);
}

/**
 * L'instantané agrégé, envoyé à chaque question : effectifs, moyennes,
 * comptes par état. Il répond à lui seul à la plupart des questions, et sert
 * de contexte à celles qui nomment quelqu'un.
 */
async function rassemblerScolarite() {
  const [
    { data: divisions },
    { data: classes },
    { data: apprenants },
    { data: matieres },
    { data: controles },
    { data: notes },
    { data: permissions },
    { data: absences },
    { data: consultations },
    { data: medicaments },
    { data: depenses },
    { data: visites },
    { data: cours },
    { data: participations },
    { data: profiles },
  ] = await Promise.all([
    adminClient.schema("socle").from("divisions").select("id, nom"),
    adminClient.schema("scolarite").from("classes").select("id, nom, type, division_id"),
    adminClient.schema("scolarite").from("apprenants")
      .select("id, matricule, nom, prenom, classe_id, division_id, type, statut, profile_id"),
    adminClient.schema("scolarite").from("matieres").select("id, nom"),
    adminClient.schema("scolarite").from("controles").select("id, type, libelle, coefficient, inclus_bulletin"),
    adminClient.schema("scolarite").from("notes").select("note, controle_id"),
    adminClient.schema("scolarite").from("permissions").select("date_depart, date_retour"),
    adminClient.schema("scolarite").from("absences").select("date_debut, date_fin, justifiee"),
    adminClient.schema("scolarite").from("consultations_medicales").select("statut, type, pathologie, exemption, jours_repos"),
    adminClient.schema("scolarite").from("medicaments").select("nom, type, stock, seuil_alerte, date_peremption"),
    adminClient.schema("scolarite").from("depenses").select("type, categorie, montant, date_depense"),
    adminClient.schema("scolarite").from("visites_medicales").select("id, date_visite"),
    adminClient.schema("scolarite").from("cours").select("id, type, classe_id, resultats_publies"),
    adminClient.schema("scolarite").from("qcm_participations").select("note, bareme, terminee_at, hors_delai"),
    adminClient.schema("socle").from("profiles").select("role"),
  ]);

  const aujourdhui = new Date();
  const jour = new Date(aujourdhui.getFullYear(), aujourdhui.getMonth(), aujourdhui.getDate());

  const effectifParClasse = (classes ?? []).map((c: any) => ({
    classe: c.nom,
    type: c.type,
    division: (divisions ?? []).find((d: any) => d.id === c.division_id)?.nom ?? "—",
    effectif: (apprenants ?? []).filter((a: any) => a.classe_id === c.id).length,
  }));

  const permissionsEnCours = (permissions ?? []).filter(
    (p: any) => new Date(p.date_depart) <= jour && new Date(p.date_retour) >= jour,
  ).length;

  const stockMedicaments = (medicaments ?? []).map((m: any) => ({
    nom: m.nom,
    type: m.type,
    stock: m.stock,
    seuil_alerte: m.seuil_alerte,
    en_rupture: (m.stock ?? 0) <= 0,
    au_seuil: (m.stock ?? 0) > 0 && (m.stock ?? 0) <= (m.seuil_alerte ?? 0),
  }));

  const troisMois = new Date(jour);
  troisMois.setMonth(troisMois.getMonth() + 3);

  const copiesRemises = (participations ?? []).filter((p: any) => p.terminee_at);
  const moyenneQcm = copiesRemises.length === 0
    ? null
    : copiesRemises.reduce((total: number, p: any) => {
      const bareme = p.bareme ?? 0;
      if (bareme <= 0) return total;
      const sur20 = Math.max(0, ((p.note ?? 0) * 20) / bareme);
      return total + sur20;
    }, 0) / copiesRemises.length;

  const nomClasse = (id: string | null) =>
    (classes ?? []).find((c: any) => c.id === id)?.nom ?? "—";

  // Le répertoire complet : c'est lui qui permet au modèle de savoir qui
  // existe, et de rapprocher un nom mal orthographié dans la question du
  // bon apprenant. Trois champs par personne — le dossier ne suit que si
  // elle est nommée.
  const repertoire = (apprenants ?? []).map((a: any) => ({
    matricule: a.matricule,
    nom: `${a.prenom} ${a.nom}`.trim(),
    classe: nomClasse(a.classe_id),
    statut: a.statut,
  }));

  const donnees = {
    repertoire_apprenants: repertoire,
    effectifs: {
      apprenants_total: (apprenants ?? []).length,
      par_nature: compterPar(apprenants ?? [], (a: any) => a.type),
      par_statut: compterPar(apprenants ?? [], (a: any) => a.statut),
      divisions: (divisions ?? []).length,
      classes_et_stages: (classes ?? []).length,
      par_classe: effectifParClasse,
      espaces_eleves_ouverts: (apprenants ?? []).filter((a: any) => a.profile_id).length,
      comptes_personnel_par_role: compterPar(profiles ?? [], (p: any) => p.role),
    },
    scolarite: {
      matieres: (matieres ?? []).length,
      evaluations_total: (controles ?? []).length,
      evaluations_par_nature: compterPar(controles ?? [], (c: any) => c.type),
      evaluations_retenues_au_bulletin: (controles ?? []).filter((c: any) => c.inclus_bulletin).length,
      notes_saisies: (notes ?? []).length,
      moyenne_generale_ecole: (notes ?? []).length === 0
        ? null
        : Number(
          ((notes ?? []).reduce((t: number, n: any) => t + Number(n.note ?? 0), 0) /
            (notes ?? []).length).toFixed(2),
        ),
    },
    cours_et_devoirs: {
      total: (cours ?? []).length,
      par_type: compterPar(cours ?? [], (c: any) => c.type),
      devoirs_resultats_publies: (cours ?? []).filter((c: any) => c.type === "devoir" && c.resultats_publies).length,
      copies_remises: copiesRemises.length,
      copies_hors_delai: copiesRemises.filter((p: any) => p.hors_delai).length,
      moyenne_qcm_sur_20: moyenneQcm === null ? null : Number(moyenneQcm.toFixed(2)),
    },
    discipline_et_presence: {
      permissions_total: (permissions ?? []).length,
      permissions_en_cours: permissionsEnCours,
      absences_total: (absences ?? []).length,
      absences_non_justifiees: (absences ?? []).filter((a: any) => !a.justifiee).length,
    },
    sante: {
      consultations_total: (consultations ?? []).length,
      par_statut: compterPar(consultations ?? [], (c: any) => c.statut),
      urgences: (consultations ?? []).filter((c: any) => c.type === "urgence").length,
      // Comptées globalement : c'est ce qui éclaire les besoins de la
      // promotion, sans rattacher une pathologie à quiconque.
      pathologies_les_plus_frequentes: compterPar(consultations ?? [], (c: any) => c.pathologie),
      exemptions: (consultations ?? []).filter((c: any) => c.exemption).length,
      jours_repos_cumules: (consultations ?? []).reduce((t: number, c: any) => t + (c.jours_repos ?? 0), 0),
      visites_medicales: (visites ?? []).length,
    },
    pharmacie: {
      references: (medicaments ?? []).length,
      en_rupture: stockMedicaments.filter((m) => m.en_rupture).map((m) => m.nom),
      au_seuil: stockMedicaments.filter((m) => m.au_seuil).map((m) => m.nom),
      peremption_sous_trois_mois: (medicaments ?? [])
        .filter((m: any) => m.date_peremption && new Date(m.date_peremption) <= troisMois)
        .map((m: any) => `${m.nom} (${m.date_peremption})`),
      stock_par_medicament: stockMedicaments,
    },
    depenses: {
      total_enregistrees: (depenses ?? []).length,
      montant_total: (depenses ?? []).reduce((t: number, d: any) => t + Number(d.montant ?? 0), 0),
      montant_par_type: (depenses ?? []).reduce((acc: Record<string, number>, d: any) => {
        acc[d.type] = (acc[d.type] ?? 0) + Number(d.montant ?? 0);
        return acc;
      }, {}),
      montant_par_categorie: (depenses ?? []).reduce((acc: Record<string, number>, d: any) => {
        acc[d.categorie] = (acc[d.categorie] ?? 0) + Number(d.montant ?? 0);
        return acc;
      }, {}),
    },
  };

  // La liste brute repart avec l'instantané : c'est elle qui sert à
  // reconnaître les apprenants nommés dans la question.
  return { donnees, apprenants: apprenants ?? [], classes: classes ?? [] };
}

/**
 * Le dossier détaillé d'un apprenant : sa scolarité, ses permissions, ses
 * absences, ses passages à l'infirmerie.
 *
 * N'est constitué que pour les apprenants que la question nomme — et part
 * alors chez le prestataire avec le reste. Les données de santé en font
 * partie : c'est le choix assumé de l'école.
 */
async function dossierApprenant(apprenant: any, classes: any[]) {
  const [
    { data: notes },
    { data: permissions },
    { data: absences },
    { data: consultations },
    { data: participations },
  ] = await Promise.all([
    adminClient.schema("scolarite").from("notes")
      .select("note, controles(libelle, type, coefficient), matieres(nom)")
      .eq("apprenant_id", apprenant.id),
    adminClient.schema("scolarite").from("permissions")
      .select("date_depart, date_retour, localite, motif")
      .eq("apprenant_id", apprenant.id)
      .order("date_depart", { ascending: false }),
    adminClient.schema("scolarite").from("absences")
      .select("date_debut, date_fin, justifiee, motif")
      .eq("apprenant_id", apprenant.id)
      .order("date_debut", { ascending: false }),
    adminClient.schema("scolarite").from("consultations_medicales")
      .select(
        "date_souhaitee, type, statut, pathologie, pathologie_details, jours_repos, exemption, examens_demandes",
      )
      .eq("apprenant_id", apprenant.id)
      .order("date_souhaitee", { ascending: false }),
    adminClient.schema("scolarite").from("qcm_participations")
      .select("note, bareme, terminee_at, hors_delai")
      .eq("apprenant_id", apprenant.id),
  ]);

  const lignesNotes = (notes ?? []).map((n: any) => ({
    evaluation: n.controles?.libelle ?? "—",
    nature: n.controles?.type ?? "—",
    coefficient: n.controles?.coefficient ?? null,
    matiere: n.matieres?.nom ?? null,
    note: Number(n.note),
  }));

  const moyenne = lignesNotes.length === 0
    ? null
    : Number(
      (lignesNotes.reduce((t: number, l: any) => t + l.note, 0) / lignesNotes.length)
        .toFixed(2),
    );

  return {
    identite: {
      matricule: apprenant.matricule,
      nom: `${apprenant.prenom} ${apprenant.nom}`.trim(),
      nature: apprenant.type,
      statut: apprenant.statut,
      classe: (classes ?? []).find((c: any) => c.id === apprenant.classe_id)?.nom ?? "—",
      espace_eleve_ouvert: Boolean(apprenant.profile_id),
    },
    scolarite: {
      notes: lignesNotes,
      moyenne_simple_des_notes: moyenne,
      qcm_remis: (participations ?? []).filter((p: any) => p.terminee_at).length,
      qcm_hors_delai: (participations ?? []).filter((p: any) => p.hors_delai).length,
    },
    permissions: permissions ?? [],
    absences: absences ?? [],
    consultations_medicales: consultations ?? [],
  };
}

const SELECT_VEHICULE =
  "*, type_vhl(type, modele_vhl(modele, marque_vhl(marque)))";

/// L'instantané du soutien technique — repris de l'assistant de l'application
/// logistique, requalifié sur le schéma du module.
///
/// Agrégé, jamais nominatif : contrairement à la scolarité, il n'y a pas de
/// dossier de personne à joindre ici, seulement des états de parc, de stock
/// et de tâches.
async function rassemblerLogistique() {
  const st = () => adminClient.schema("logistique");

  const [
    { data: vehicules },
    { data: soutes },
    { data: souteStocks },
    { data: armes },
    { data: dotations },
    { data: munitions },
    { data: equipements },
    { data: passagesVisiteurs },
    { data: passagesVehicules },
    { data: activites },
    { data: taches },
  ] = await Promise.all([
    st().from("vehicule").select(SELECT_VEHICULE).eq("supprime", false),
    st().from("soute").select("id, libelle"),
    st().from("soute_type_stock").select(
      "soute_id, qte_gasoil, qte_super, seuil_critique",
    ),
    st().from("arme").select(
      "numero_serie, type, modele, etat, prochaine_inspection",
    ),
    st().from("dotation_arme").select(
      "beneficiaire_matricule, beneficiaire_nom, date_retour_prevue, date_retour_effective",
    ),
    st().from("stock_munition").select(
      "calibre, quantite_disponible, seuil_critique",
    ),
    st().from("equipement_protection").select(
      "libelle, quantite_disponible, seuil_critique",
    ),
    st().from("passage_visiteur").select("date_arrivee, date_sortie"),
    st().from("passage_vehicule").select("date_sortie, date_retour"),
    st().from("activite").select("titre, statut, date_activite"),
    st().from("tache_activite").select(
      "acteur, description, statut, date_limite",
    ),
  ]);

  const maintenant = new Date();

  const vehiculesVidange = (vehicules ?? [])
    .filter((v: any) => v.kilometrage >= v.kilometrage_vidange_prochaine)
    .map((v: any) =>
      `${v.immatriculation} (${
        v.type_vhl?.modele_vhl?.marque_vhl?.marque ?? ""
      } ${v.type_vhl?.modele_vhl?.modele ?? ""})`
    );

  const soutesAlerte = (soutes ?? []).map((s: any) => {
    const stocks = (souteStocks ?? []).filter((st: any) => st.soute_id === s.id);
    const total = stocks.reduce(
      (acc: number, st: any) => acc + (st.qte_gasoil ?? 0) + (st.qte_super ?? 0),
      0,
    );
    const seuil = stocks.reduce(
      (acc: number, st: any) => acc + (st.seuil_critique ?? 0),
      0,
    );
    return {
      libelle: s.libelle,
      stock_litres: total,
      seuil_critique: seuil,
      en_alerte: total <= seuil,
    };
  });

  const dotationsEnRetard = (dotations ?? []).filter((d: any) =>
    !d.date_retour_effective && d.date_retour_prevue &&
    new Date(d.date_retour_prevue) < maintenant
  );

  const parStatut = (lignes: any[]) =>
    (lignes ?? []).reduce((acc: Record<string, number>, l: any) => {
      acc[l.statut] = (acc[l.statut] ?? 0) + 1;
      return acc;
    }, {});

  return {
    vehicules: {
      total: (vehicules ?? []).length,
      disponibles: (vehicules ?? []).filter((v: any) =>
        v.etat === "disponible"
      ).length,
      en_mission: (vehicules ?? []).filter((v: any) =>
        v.etat === "en_mission"
      ).length,
      en_reparation: (vehicules ?? []).filter((v: any) =>
        v.etat === "en_reparation"
      ).length,
      hors_service: (vehicules ?? []).filter((v: any) =>
        v.etat === "hors_service"
      ).length,
      vidange_a_prevoir: vehiculesVidange,
    },
    carburant: { soutes: soutesAlerte },
    armement: {
      armes_total: (armes ?? []).length,
      armes_par_etat: (armes ?? []).reduce(
        (acc: Record<string, number>, a: any) => {
          acc[a.etat] = (acc[a.etat] ?? 0) + 1;
          return acc;
        },
        {},
      ),
      dotations_en_retard: dotationsEnRetard.map((d: any) =>
        d.beneficiaire_nom || d.beneficiaire_matricule
      ),
      munitions: (munitions ?? []).map((m: any) => ({
        calibre: m.calibre,
        quantite: m.quantite_disponible,
        seuil_critique: m.seuil_critique,
        en_alerte: m.quantite_disponible <= m.seuil_critique,
      })),
      equipements: (equipements ?? []).map((e: any) => ({
        libelle: e.libelle,
        quantite: e.quantite_disponible,
        seuil_critique: e.seuil_critique,
        en_alerte: e.quantite_disponible <= e.seuil_critique,
      })),
    },
    poste_police: {
      visiteurs_dans_le_camp: (passagesVisiteurs ?? []).filter((p: any) =>
        !p.date_sortie
      ).length,
      visiteurs_total: (passagesVisiteurs ?? []).length,
      vehicules_hors_du_camp: (passagesVehicules ?? []).filter((p: any) =>
        !p.date_retour
      ).length,
      vehicules_total: (passagesVehicules ?? []).length,
    },
    activites_oa: {
      total: (activites ?? []).length,
      par_statut: parStatut(activites ?? []),
      taches_total: (taches ?? []).length,
      taches_par_statut: parStatut(taches ?? []),
      taches_en_retard: (taches ?? []).filter((t: any) =>
        t.statut === "a_faire" && t.date_limite &&
        new Date(t.date_limite) < maintenant
      ).length,
    },
  };
}

const SCHEMA_ATTENDU = `{
  "reponse": "réponse textuelle claire et concise à la question, en français",
  "graphique": {
    "type": "barres" | "camembert" | "aucun",
    "titre": "titre du graphique",
    "series": [{"label": "...", "valeur": nombre}]
  },
  "points_cles": ["point clé 1", "point clé 2"]
}`;

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Méthode non autorisée" }, 405);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Non authentifié." }, 401);

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: appelant } } = await callerClient.auth.getUser();
    if (!appelant) return jsonResponse({ error: "Non authentifié." }, 401);

    const { data: profilAppelant } = await adminClient.schema("socle").from("profiles")
      .select("role, role_logistique")
      .eq("id", appelant.id)
      .maybeSingle();

    // Chacun n'interroge que ce qu'il commande. L'administrateur de l'école
    // porte les deux rôles : il voit tout. Le chef du Soutien Technique ne
    // voit que son service — l'assistant ne doit pas devenir la porte
    // dérobée par laquelle il lirait les dossiers médicaux des élèves.
    const voitScolarite = profilAppelant?.role === "admin";
    const voitLogistique = ["administrateur", "chef_soutien_technique"]
      .includes(profilAppelant?.role_logistique ?? "");

    if (!voitScolarite && !voitLogistique) {
      return jsonResponse(
        { error: "Réservé à l'administrateur et au chef du Soutien Technique." },
        403,
      );
    }

    if (!DEEPSEEK_API_KEY) {
      return jsonResponse({
        error:
          "L'assistant n'est pas configuré : la clé DeepSeek manque côté serveur.",
      }, 503);
    }

    const { question } = await req.json();
    if (!question || typeof question !== "string") {
      return jsonResponse({ error: "Question manquante." }, 400);
    }

    // On ne rassemble que ce que l'appelant a le droit de voir, et on ne paie
    // que ce qu'on rassemble.
    const scolarite = voitScolarite ? await rassemblerScolarite() : null;
    const logistique = voitLogistique ? await rassemblerLogistique() : null;

    // Les dossiers ne sont constitués que pour les apprenants effectivement
    // nommés : une question générale n'en déclenche aucun.
    const cites = scolarite
        ? apprenantsCites(question, scolarite.apprenants)
        : [];
    const dossiers = await Promise.all(
      cites.map((a: any) => dossierApprenant(a, scolarite!.classes)),
    );

    const donnees = {
      ...(scolarite ? { scolarite: scolarite.donnees } : {}),
      ...(logistique ? { soutien_technique: logistique } : {}),
    };

    const domaines = [
      voitScolarite ? "la scolarité et la santé" : null,
      voitLogistique ? "le soutien technique et les activités" : null,
    ].filter(Boolean).join(", ainsi que ");

    const systemPrompt =
      `Tu es un assistant d'analyse pour l'ERP de l'ENSOA (École Nationale des Sous-Officiers d'Active), ` +
      `sur ${domaines}. ` +
      `Réponds à la question de l'administrateur UNIQUEMENT à partir des données JSON fournies ci-dessous — ` +
      `n'invente jamais une donnée absente, dis-le franchement si l'information manque.\n\n` +
      (voitScolarite
        ? `Sous "scolarite", tu disposes de trois choses :\n` +
          `1. "repertoire_apprenants" : tous les apprenants de l'école (matricule, nom, classe, statut). ` +
          `Sers-t'en pour retrouver de qui parle la question, même si le nom y est mal orthographié.\n` +
          `2. Les statistiques agrégées de l'école.\n` +
          `3. "dossiers_nominatifs" : le dossier complet des apprenants que la question désigne — notes, ` +
          `permissions, absences, consultations médicales. Ce tableau est vide si la question ne nomme personne.\n\n` +
          `Si la question porte sur une personne dont le dossier n'est pas joint, dis-le et invite à la nommer ` +
          `par son matricule ou son nom exact. Si le dossier est joint, réponds avec précision, en nommant la personne.\n`
        : ``) +
      (voitLogistique
        ? `Sous "soutien_technique", tu disposes de l'état agrégé du parc, du carburant, ` +
          `de l'armement, du poste de police et des activités de l'officier adjoint. ` +
          `Ces données-là ne sont pas nominatives : n'invente aucun nom de conducteur ou de détenteur.\n`
        : ``) +
      `Ces informations sont confidentielles : réponds à la question posée, sans en étaler davantage que nécessaire.\n\n` +
      `Réponds TOUJOURS en JSON strict avec exactement cette forme :\n${SCHEMA_ATTENDU}\n` +
      `Choisis "aucun" pour le graphique si la question n'appelle pas de représentation visuelle pertinente. ` +
      `Utilise "camembert" pour une répartition ou une proportion, "barres" pour comparer des catégories.\n\n` +
      `Données actuelles de l'école :\n${JSON.stringify(donnees)}\n\n` +
      `dossiers_nominatifs :\n${JSON.stringify(dossiers)}`;

    const completion = await fetch("https://api.deepseek.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: question },
        ],
        response_format: { type: "json_object" },
        temperature: 0.3,
      }),
    });

    if (!completion.ok) {
      return jsonResponse(
        { error: `Erreur DeepSeek : ${await completion.text()}` },
        502,
      );
    }

    const resultat = await completion.json();
    const contenu = resultat.choices?.[0]?.message?.content;
    if (!contenu) return jsonResponse({ error: "Réponse vide de DeepSeek." }, 502);

    return new Response(contenu, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (erreur) {
    return jsonResponse({ error: String(erreur) }, 500);
  }
});
