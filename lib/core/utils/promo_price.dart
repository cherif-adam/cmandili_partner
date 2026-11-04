import 'money.dart';

/// Prix d'un article apres une remise en pourcentage.
///
/// UNE seule fonction, utilisee a la fois par l'apercu affiche au commercant
/// et par l'ecriture en base : c'est ce qui garantit que le prix montre avant
/// l'enregistrement est exactement celui qui sera encaisse. Deux calculs
/// separes finiraient par diverger, et le commercant aurait raison de ne plus
/// faire confiance a l'apercu.
///
/// Le prix est arrondi au pas monetaire (50 millimes, [roundMoney]) : 12,9 DT
/// a -15 % donne 10,965 DT, une somme que personne ne rend ; le prix affiche
/// et enregistre est 10,950 DT. Le trigger `round_promo_prices` de la base
/// applique la meme regle a l'ecriture (et au cron qui active les promotions
/// programmees) : sans le meme arrondi ici, l'apercu mentirait.
double computePromoPrice(double originalPrice, double percent) {
  final raw = originalPrice * (1 - percent / 100);
  final rounded = roundMoney(raw);
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
