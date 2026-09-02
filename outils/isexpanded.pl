# Ajoute `isExpanded: true` à tout DropdownButtonFormField qui ne l'a pas.
#
# Outil d'amorçage, à lancer une fois. Un menu déroulant sans cette option
# laisse son libellé prendre sa largeur naturelle : dans une colonne étroite,
# il déborde et Flutter peint la bande jaune et noire. `isExpanded` lui impose
# la largeur disponible, et le texte trop long s'abrège au lieu de déborder.
#
# Le suivi des parenthèses est nécessaire : la liste d'arguments d'un de ces
# menus fait souvent vingt lignes, décoration et items compris, et une simple
# fenêtre de quelques lignes se trompe dans un sens ou dans l'autre.
#
#   perl outils/isexpanded.pl $(grep -rl DropdownButtonFormField lib --include=*.dart)

use strict;
use warnings;

for my $chemin (@ARGV) {
    open(my $e, '<:encoding(UTF-8)', $chemin) or die "$chemin : $!";
    my @lignes = <$e>;
    close($e);

    my @sortie;
    my $i = 0;
    my $modifie = 0;

    while ($i < @lignes) {
        my $ligne = $lignes[$i];
        push @sortie, $ligne;

        if ($ligne =~ /DropdownButtonFormField(?:<[^>]*>)?\(/) {
            # Parcourir la liste d'arguments jusqu'à la parenthèse fermante.
            my $profondeur = ($ligne =~ tr/(//) - ($ligne =~ tr/)//);
            my $j = $i + 1;
            my $aDeja = 0;
            while ($j < @lignes && $profondeur > 0) {
                $aDeja = 1 if $lignes[$j] =~ /\bisExpanded\s*:/;
                $profondeur += ($lignes[$j] =~ tr/(//) - ($lignes[$j] =~ tr/)//);
                $j++;
            }

            unless ($aDeja) {
                my ($marge) = $lignes[$i + 1] =~ /^(\s*)/ if $i + 1 < @lignes;
                $marge //= '  ';
                push @sortie, "${marge}isExpanded: true,\n";
                $modifie = 1;
            }
        }
        $i++;
    }

    if ($modifie) {
        open(my $s, '>:encoding(UTF-8)', $chemin) or die "$chemin : $!";
        print $s @sortie;
        close($s);
        print "corrigé : $chemin\n";
    }
}
