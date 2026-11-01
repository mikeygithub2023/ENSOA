# Déploiement de la PWA — SIG ENSOA

L'application est désormais une **PWA** (Progressive Web App) : une page web
installable qui se met à jour toute seule. Plus d'APK ni d'EXE à redistribuer.

## 1. Construire la version web

```bash
flutter build web --release
```

Le résultat est dans `build/web/`. C'est **tout le contenu de ce dossier** qui
est publié chez l'hébergeur.

> Déploiement à la racine d'un domaine (le cas d'un hébergeur statique dédié) :
> la commande ci-dessus suffit. Pour un sous-dossier (`exemple.com/ensoa/`),
> construire avec `flutter build web --release --base-href /ensoa/`.

## 2. Publier chez un hébergeur statique gratuit

Trois choix équivalents, tous en HTTPS (obligatoire pour une PWA) :

### Cloudflare Pages (recommandé)
1. Créer un compte sur [pages.cloudflare.com](https://pages.cloudflare.com).
2. « Upload assets » → glisser le dossier `build/web`, ou connecter le dépôt
   Git avec la commande de build `flutter build web --release` et le dossier de
   sortie `build/web`.
3. L'URL `https://sig-ensoa.pages.dev` (ou un domaine propre) est prête.

### Netlify
- Glisser `build/web` sur [app.netlify.com/drop](https://app.netlify.com/drop),
  ou `netlify deploy --prod --dir build/web` avec la CLI.
- Le fichier `web/_redirects` (déjà présent, copié dans `build/web`) gère le
  repli SPA.

### Vercel
- `vercel --prod` en pointant le dossier `build/web`.
- Ajouter un `vercel.json` avec une règle de réécriture vers `/index.html` si
  l'on passe un jour aux URL « propres » (actuellement inutile : routage par
  hash `#`).

## 3. Installer l'application (côté utilisateur)

- **Android / tablette** : ouvrir l'URL dans Chrome → menu ⋮ → « Ajouter à
  l'écran d'accueil ». L'icône de l'ENSOA apparaît comme une vraie appli.
- **Windows / poste de travail** : ouvrir l'URL dans Edge ou Chrome → icône
  d'installation dans la barre d'adresse (ou menu → « Installer SIG ENSOA »).
  L'appli s'ouvre dans sa propre fenêtre, sans barre de navigateur.

## 4. Mettre à jour

C'est là tout l'intérêt du changement :

1. Modifier le code.
2. `flutter build web --release`.
3. Republier `build/web` (re-glisser, ou `git push` si le dépôt est connecté).

Au prochain lancement, chaque appareil télécharge la nouvelle version en
arrière-plan et l'applique **sans réinstallation**. Le service worker
(`flutter_service_worker.js`, enregistré depuis `index.html`) détecte le
changement grâce à l'empreinte des fichiers.

## Limites de cette étape (niveau A)

- **Connexion requise** : l'application se charge hors-ligne, mais les données
  (Supabase) exigent Internet. La consultation et la saisie hors-ligne
  (niveaux B et C) restent à faire.
- **Biométrie** : masquée sur web (navigateur sans équivalent). Connexion par
  matricule + mot de passe.
- **Notifications poussées** : désarmées sur web. Le push navigateur
  demanderait un service worker dédié et une clé VAPID — à traiter plus tard.
- **Appareil photo** (inscription) : le bouton « prendre une photo » est
  remplacé par le choix de fichier, qui ouvre la caméra là où le navigateur le
  permet.
