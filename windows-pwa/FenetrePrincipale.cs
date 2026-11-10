using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace SigEnsoa
{
    /// <summary>
    /// La fenêtre de SIG ENSOA : la PWA, sans barre d'adresse.
    ///
    /// Quand le serveur ne répond pas et que l'application n'est pas encore
    /// en cache, c'est un écran aux armoiries de l'ENSOA qui le dit, avec
    /// « Réessayer » — jamais la page d'erreur du moteur web, au nom du site.
    /// Une fois chargée, l'application reste en cache (service worker) et
    /// s'ouvre même sans réseau.
    /// </summary>
    internal sealed class FenetrePrincipale : Form
    {
        // SIG_ENSOA_ADRESSE ne sert qu'aux essais : pointer vers une adresse
        // muette fait paraître l'écran hors connexion sans couper le réseau.
        private static readonly string Adresse =
            Environment.GetEnvironmentVariable("SIG_ENSOA_ADRESSE")
            ?? "https://sig-ensoa.pages.dev/";
        private static readonly Uri Origine = new Uri(Adresse);

        private readonly WebView2 _web = new WebView2 { Dock = DockStyle.Fill };

        public FenetrePrincipale()
        {
            Text = "SIG ENSOA";
            Icon = new Icon(Ressource("app_icon.ico"));
            BackColor = Color.White;
            WindowState = FormWindowState.Maximized;
            MinimumSize = new Size(1024, 680);
            Controls.Add(_web);
            Load += async (s, e) => await DemarrerAsync();
        }

        private async System.Threading.Tasks.Task DemarrerAsync()
        {
            // Les données du moteur web (cache de l'application, session)
            // vivent dans le profil de l'utilisateur, à côté de rien d'autre.
            var dossier = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SIG ENSOA", "WebView2");
            try
            {
                var env = await CoreWebView2Environment.CreateAsync(null, dossier);
                await _web.EnsureCoreWebView2Async(env);
            }
            catch (WebView2RuntimeNotFoundException)
            {
                MessageBox.Show(
                    "Le moteur Microsoft Edge WebView2 est absent de ce poste.\n\n" +
                    "Installez-le depuis le site de Microsoft (« WebView2 Runtime »), " +
                    "puis relancez SIG ENSOA.",
                    "SIG ENSOA", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Close();
                return;
            }

            var reglages = _web.CoreWebView2.Settings;
            reglages.AreDevToolsEnabled = false;
            reglages.IsStatusBarEnabled = false;
            reglages.IsZoomControlEnabled = true;

            _web.CoreWebView2.DocumentTitleChanged += (s, e) =>
            {
                var titre = _web.CoreWebView2.DocumentTitle;
                Text = string.IsNullOrWhiteSpace(titre) || titre.Contains("pages.dev")
                    ? "SIG ENSOA" : titre;
            };
            _web.CoreWebView2.NavigationCompleted += SurNavigationTerminee;
            _web.CoreWebView2.NewWindowRequested += SurNouvelleFenetre;
            _web.CoreWebView2.WebMessageReceived += (s, e) =>
            {
                if (e.TryGetWebMessageAsString() == "reessayer") Ouvrir();
            };

            await ViderLeCacheAsync();
            Ouvrir();
        }

        /// <summary>
        /// Vide le cache avant d'ouvrir la page, pour que le poste prenne
        /// toujours la dernière version mise en ligne.
        ///
        /// Deux caches retiennent l'application : celui du moteur web
        /// (DiskCache) et celui du service worker (CacheStorage). Tant qu'ils
        /// gardent l'ancienne version, un déploiement passe inaperçu — c'est
        /// ce qui est arrivé le 6 novembre 2026, où il a fallu les effacer à
        /// la main sur le poste du commandant.
        ///
        /// On n'efface que ces deux-là : les cookies et le stockage local
        /// restent, donc la session reste ouverte et l'on ne se reconnecte
        /// pas à chaque lancement.
        ///
        /// Et l'on n'efface que si le serveur répond. Sans réseau, le cache
        /// du service worker est tout ce qui permet encore d'ouvrir
        /// l'application : l'effacer laisserait une fenêtre vide.
        /// </summary>
        private async System.Threading.Tasks.Task ViderLeCacheAsync()
        {
            if (!await ServeurJoignableAsync()) return;
            try
            {
                await _web.CoreWebView2.Profile.ClearBrowsingDataAsync(
                    CoreWebView2BrowsingDataKinds.DiskCache
                    | CoreWebView2BrowsingDataKinds.CacheStorage);
            }
            catch (Exception)
            {
                // Un cache qu'on n'a pas pu vider n'empêche pas d'ouvrir
                // l'application : au pire, elle s'ouvre sur la version
                // précédente, comme avant ce correctif.
            }
        }

        /// <summary>
        /// Le serveur répond-il, en deux secondes ? On ne demande que les
        /// en-têtes : rien à télécharger pour le savoir.
        /// </summary>
        private static async System.Threading.Tasks.Task<bool> ServeurJoignableAsync()
        {
            try
            {
                System.Net.ServicePointManager.SecurityProtocol =
                    System.Net.SecurityProtocolType.Tls12;
                using (var client = new System.Net.Http.HttpClient
                {
                    Timeout = TimeSpan.FromSeconds(2),
                })
                using (var demande = new System.Net.Http.HttpRequestMessage(
                    System.Net.Http.HttpMethod.Head, Adresse))
                using (var reponse = await client.SendAsync(demande))
                {
                    return reponse.IsSuccessStatusCode;
                }
            }
            catch (Exception)
            {
                return false;
            }
        }

        private void Ouvrir() => _web.CoreWebView2.Navigate(Adresse);

        private void SurNavigationTerminee(object sender, CoreWebView2NavigationCompletedEventArgs e)
        {
            if (e.IsSuccess) return;
            // L'arrêt volontaire d'un chargement n'est pas une panne.
            if (e.WebErrorStatus == CoreWebView2WebErrorStatus.OperationCanceled) return;
            _web.CoreWebView2.NavigateToString(PageHorsLigne());
        }

        /// <summary>
        /// Les liens vers un autre site s'ouvrent dans le navigateur du poste ;
        /// ceux de l'application restent dans sa fenêtre.
        /// </summary>
        private void SurNouvelleFenetre(object sender, CoreWebView2NewWindowRequestedEventArgs e)
        {
            if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out var cible)) return;
            if (cible.Host == Origine.Host)
            {
                e.NewWindow = _web.CoreWebView2;
                return;
            }
            if (cible.Scheme == Uri.UriSchemeHttps || cible.Scheme == Uri.UriSchemeHttp)
            {
                e.Handled = true;
                Process.Start(new ProcessStartInfo(cible.AbsoluteUri) { UseShellExecute = true });
            }
        }

        private static string PageHorsLigne()
        {
            using (var lecteur = new StreamReader(Ressource("hors_ligne.html")))
                return lecteur.ReadToEnd();
        }

        private static Stream Ressource(string nom) =>
            Assembly.GetExecutingAssembly().GetManifestResourceStream(nom)
            ?? throw new InvalidOperationException("Ressource absente : " + nom);
    }
}
