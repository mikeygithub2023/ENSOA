using System;
using System.Threading;
using System.Windows.Forms;

namespace SigEnsoa
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            // Une seule fenêtre à la fois : deux instances se disputeraient le
            // même dossier de données du moteur web, et la seconde échouerait.
            using (var unique = new Mutex(true, @"Local\SIG_ENSOA_Bureau", out bool premiere))
            {
                if (!premiere) return;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new FenetrePrincipale());
            }
        }
    }
}
