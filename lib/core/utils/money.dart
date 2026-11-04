/// Arrondi monetaire : un prix que l'app calcule est un multiple de
/// [kMoneyRoundingStep] DT (50 millimes), une somme qu'on peut vraiment payer
/// en especes.
///
/// Meme regle que la fonction SQL `public.round_money(x)` : le multiple du pas
/// le plus proche, moitie vers le haut (en valeur absolue, comme `ROUND`) :
///   0,805 -> 0,800   0,4025 -> 0,400   1,035 -> 1,050   2,375 -> 2,400
///
/// Le serveur reste l'autorite : le trigger `round_promo_prices` de
/// `vendor_items` arrondit `discount_price` et `happy_hour_price` avec le pas
/// de `global_settings.money_rounding_step` (modifiable dans l'admin). Le pas
/// fixe ci-dessous est la valeur par defaut de ce reglage ; il sert a ce que
/// l'app AFFICHE, avant l'enregistrement, le prix que le serveur gardera.
library;

/// Pas d'arrondi par defaut, en DT (valeur par defaut de
/// `global_settings.money_rounding_step`).
const double kMoneyRoundingStep = 0.05;

/// [amount] arrondi au multiple de [step] le plus proche, moitie vers le haut.
///
/// Le calcul passe par des entiers (dix-millioniemes de dinar) pour tomber du
/// meme cote que Postgres, qui calcule en decimal exact : en double, 2,375 ou
/// 12,9 x 0,85 ne valent pas exactement ce qu'ils affichent.
double roundMoney(double amount, {double step = kMoneyRoundingStep}) {
  if (!amount.isFinite) return amount;
  const scale = 10000000; // 1e7 : unites de 0,0000001 DT
  final stepUnits = (step * scale).round();
  if (stepUnits <= 0) return amount;
  final units = (amount * scale).round();
  final magnitude = units.abs();
  var steps = magnitude ~/ stepUnits;
  if ((magnitude % stepUnits) * 2 >= stepUnits) steps += 1;
  final rounded = steps * stepUnits;
  return (units < 0 ? -rounded : rounded) / scale;
}
