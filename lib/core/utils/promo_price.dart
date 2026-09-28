/// Prix d'un article apres une remise en pourcentage.
///
/// UNE seule fonction, utilisee a la fois par l'apercu affiche au commercant
/// et par l'ecriture en base : c'est ce qui garantit que le prix montre avant
/// l'enregistrement est exactement celui qui sera encaisse. Deux calculs
/// separes finiraient par diverger d'un millime, et le commercant aurait
/// raison de ne plus faire confiance a l'apercu.
///
/// L'arrondi est au millime parce que c'est l'unite reelle du dinar tunisien
/// et la precision de la colonne (`numeric(10,3)`). Ce n'est pas un arrondi
/// commercial : on ne rabote pas le prix vers un chiffre rond, on garde la
/// valeur exacte a la plus petite unite qui puisse etre encaissee. Sans cela
/// Postgres arrondirait lui-meme a l'insertion, et l'apercu mentirait.
double computePromoPrice(double originalPrice, double percent) {
  final raw = originalPrice * (1 - percent / 100);
  final rounded = (raw * 1000).round() / 1000;
  return rounded < 0 ? 0 : rounded;
}

/// Le pourcentage correspondant a un prix remise, pour reafficher une
/// promotion posee avant que `discount_percent` n'existe (ou depuis l'ecran
/// Happy Hour, qui n'enregistre qu'un prix).
double? percentFromPrices(double originalPrice, double? discountPrice) {
  if (discountPrice == null || originalPrice <= 0) return null;
  if (discountPrice >= originalPrice) return null;
  final pct = (1 - discountPrice / originalPrice) * 100;
  return (pct * 100).round() / 100;
}
