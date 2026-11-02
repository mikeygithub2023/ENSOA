/*
 * Copyright 2020 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package ci.ensoa.sig_ensoa;

import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Le lanceur de SIG ENSOA.
 *
 * Tant que l'application n'a jamais été chargée sur l'appareil, Chrome ne peut
 * rien afficher d'elle sans réseau : il montrerait sa propre page d'erreur, au
 * nom du site. On vérifie donc d'abord que le serveur répond ; s'il ne répond
 * pas, c'est un écran aux couleurs de l'ENSOA qui le dit, avec « Réessayer ».
 *
 * Une fois l'application chargée une fois, son service worker la garde en
 * cache : elle s'ouvre même sans réseau, et l'on n'attend plus rien.
 */
public class LauncherActivity
        extends com.google.androidbrowserhelper.trusted.LauncherActivity {

    private static final String PREFERENCES = "sig_ensoa";
    private static final String DEJA_CHARGEE = "deja_chargee";
    private static final int DELAI_MS = 8000;

    private static final int NAVY = Color.parseColor("#101F3C");
    private static final int GRIS = Color.parseColor("#6B7690");

    private final Handler principal = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Setting an orientation crashes the app due to the transparent background on Android 8.0
        // Oreo and below. We only set the orientation on Oreo and above. This only affects the
        // splash screen and Chrome will still respect the orientation.
        // See https://github.com/GoogleChromeLabs/bubblewrap/issues/496 for details.
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
            setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        } else {
            setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
        }
        if (!dejaChargee()) verifierServeur();
    }

    @Override
    protected boolean shouldLaunchImmediately() {
        return dejaChargee();
    }

    private boolean dejaChargee() {
        return getSharedPreferences(PREFERENCES, MODE_PRIVATE)
                .getBoolean(DEJA_CHARGEE, false);
    }

    private void verifierServeur() {
        afficher(false);
        final String adresse = getLaunchingUrl().toString();
        new Thread(() -> {
            boolean repond = false;
            HttpURLConnection connexion = null;
            try {
                connexion = (HttpURLConnection) new URL(adresse).openConnection();
                connexion.setConnectTimeout(DELAI_MS);
                connexion.setReadTimeout(DELAI_MS);
                connexion.setRequestMethod("HEAD");
                int code = connexion.getResponseCode();
                repond = code >= 200 && code < 400;
            } catch (Exception ignore) {
                // Pas de réseau, serveur muet ou adresse bloquée : même écran.
            } finally {
                if (connexion != null) connexion.disconnect();
            }
            final boolean ok = repond;
            principal.post(() -> {
                if (isFinishing()) return;
                if (ok) {
                    SharedPreferences.Editor e =
                            getSharedPreferences(PREFERENCES, MODE_PRIVATE).edit();
                    e.putBoolean(DEJA_CHARGEE, true).apply();
                    launchTwa();
                } else {
                    afficher(true);
                }
            });
        }).start();
    }

    /** L'écran d'attente, ou celui de l'échec avec son bouton « Réessayer ». */
    private void afficher(boolean echec) {
        LinearLayout ecran = new LinearLayout(this);
        ecran.setOrientation(LinearLayout.VERTICAL);
        ecran.setGravity(Gravity.CENTER);
        ecran.setBackgroundColor(Color.WHITE);
        int marge = dp(32);
        ecran.setPadding(marge, marge, marge, marge);

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.splash);
        logo.setAdjustViewBounds(true);
        ecran.addView(logo, new LinearLayout.LayoutParams(dp(120), dp(120)));

        TextView titre = texte(
                echec ? "Connexion impossible" : "SIG ENSOA", 20, NAVY, true);
        ecran.addView(titre, marges(dp(20)));

        if (echec) {
            ecran.addView(texte(
                    "Le serveur de SIG ENSOA ne répond pas.\n"
                            + "Vérifiez la connexion Internet de l'appareil, puis réessayez.",
                    15, GRIS, false), marges(dp(8)));

            Button reessayer = new Button(this);
            reessayer.setText("Réessayer");
            reessayer.setAllCaps(false);
            reessayer.setTextColor(Color.WHITE);
            reessayer.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
            GradientDrawable fond = new GradientDrawable();
            fond.setColor(NAVY);
            fond.setCornerRadius(dp(24));
            reessayer.setBackground(fond);
            reessayer.setPadding(dp(32), 0, dp(32), 0);
            reessayer.setOnClickListener(v -> verifierServeur());
            LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dp(48));
            p.topMargin = dp(24);
            ecran.addView(reessayer, p);
        } else {
            ecran.addView(texte("Connexion au serveur…", 15, GRIS, false), marges(dp(8)));
            ProgressBar attente = new ProgressBar(this);
            LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(dp(36), dp(36));
            p.topMargin = dp(20);
            ecran.addView(attente, p);
        }
        setContentView(ecran);
    }

    private TextView texte(String contenu, int taille, int couleur, boolean gras) {
        TextView t = new TextView(this);
        t.setText(contenu);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, taille);
        t.setTextColor(couleur);
        t.setGravity(Gravity.CENTER);
        if (gras) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    private LinearLayout.LayoutParams marges(int haut) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        p.topMargin = haut;
        return p;
    }

    private int dp(int valeur) {
        return Math.round(valeur * getResources().getDisplayMetrics().density);
    }
}
