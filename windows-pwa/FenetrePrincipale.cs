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

            Ouvrir();
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
