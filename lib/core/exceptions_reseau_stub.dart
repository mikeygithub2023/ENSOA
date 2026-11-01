/// Pendant web du module de reconnaissance réseau : `dart:io` n'existe pas
/// dans le navigateur, donc aucun de ses types n'est jamais levé. On renvoie
/// toujours `false` et l'on s'en remet au repli par texte — `estProblemeReseau`
/// examine aussi le message de l'erreur (« failed host lookup »,
/// « clientexception », « connection timed out »), ce qui couvre le web.
bool estExceptionReseauBasNiveau(Object erreur) => false;

bool estCoupureSocket(Object erreur) => false;
