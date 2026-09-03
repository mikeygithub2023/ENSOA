package ci.ensoa.sig_ensoa

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /**
     * L'application refuse d'être capturée.
     *
     * Elle affiche des dossiers d'élèves, des consultations médicales, des
     * effectifs et des inventaires d'armement : une capture d'écran sort ces
     * données de l'application sans laisser de trace au journal d'audit, et
     * circule ensuite sans contrôle.
     *
     * FLAG_SECURE couvre d'un seul geste la capture d'écran, l'enregistrement
     * vidéo, le partage d'écran et la vignette de la liste des applications
     * récentes — celle-ci montrait encore le dernier écran consulté à qui
     * prenait la tablette en main.
     *
     * CE QU'IL NE FAIT PAS : empêcher qu'on photographie l'écran avec un autre
     * appareil. Aucun réglage logiciel ne le peut ; c'est une mesure de
     * discipline, pas de technique.
     *
     * Pour une version de diagnostic — pour envoyer une capture décrivant une
     * anomalie —, commenter l'appel ci-dessous et recompiler.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }
}
