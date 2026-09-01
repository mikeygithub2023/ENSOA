/// Formate un entier avec un espace comme séparateur de milliers
/// (ex. 9999999 → "9 999 999"), pour la lisibilité des grandes quantités
/// (litres de carburant, kilométrages...).
String formatMilliers(int n) {
  final negatif = n < 0;
  final chiffres = n.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(chiffres[i]);
  }
  return (negatif ? '-' : '') + buffer.toString();
}
