// Arrondi a 50 millimes cote partenaire : la regle de public.round_money(x),
// le prix d'une promotion en pourcentage et le prix Happy Hour.
//
// Le trigger round_promo_prices de vendor_items (migration
// 20261104120000_arrondi_50_millimes.sql) arrondit ces prix de la meme facon a
// l'ecriture : ces tests verifient que l'apercu montre au commercant est
// exactement le prix que la base gardera.

import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_partner/core/utils/money.dart';
import 'package:cmandili_partner/core/utils/promo_price.dart';
import 'package:cmandili_partner/features/menu/presentation/happy_hour_setup/happy_hour_setup_controller.dart';

bool _isCashAmount(double amount) => (amount * 1000).round() % 50 == 0;

void main() {
  group('roundMoney (meme regle que round_money en SQL)', () {
    test('les exemples de la regle', () {
      expect(roundMoney(0.805), 0.800);
      expect(roundMoney(0.4025), 0.400);
      expect(roundMoney(1.035), 1.050);
      expect(roundMoney(2.375), 2.400);
    });

    test('un multiple du pas ne bouge pas', () {
      for (final v in [0.0, 0.05, 6.75, 24.0, 30.0]) {
        expect(roundMoney(v), v);
      }
    });
  });

  group('computePromoPrice (promotion en pourcentage)', () {
    test('repas 30 DT a -20 % : 24,000 DT', () {
      expect(computePromoPrice(30, 20), 24.0);
    });

    test('12,9 DT a -15 % : 10,965 calcule, 10,950 affiche et enregistre', () {
      expect(computePromoPrice(12.9, 15), 10.95);
    });

    test('7,5 DT a -10 % : 6,750 DT (deja rond)', () {
      expect(computePromoPrice(7.5, 10), 6.75);
    });

    test('tout prix promo est un montant en especes', () {
      for (var price = 0.5; price <= 60; price += 0.35) {
        for (var pct = 1; pct <= 70; pct++) {
          final p = computePromoPrice(price, pct.toDouble());
          expect(_isCashAmount(p), isTrue, reason: '$price DT -$pct % -> $p');
        }
      }
    });
  });

  group('Happy Hour', () {
    test('priceForPercent : 30 DT a -20 % = 24, 12,9 DT a -15 % = 10,95', () {
      expect(HappyHourSetupController.priceForPercent(30, 20), 24.0);
      expect(HappyHourSetupController.priceForPercent(12.9, 15), 10.95);
    });

    test('validatePrice juge le prix arrondi, celui qui sera enregistre', () {
      // 9,99 s'arrondit a 10,000 : ce n'est plus une remise sur 10 DT.
      expect(HappyHourSetupController.validatePrice('9.99', 10),
          HappyHourFieldError.priceTooHigh);
      expect(HappyHourSetupController.validatePrice('9.95', 10), isNull);
      expect(HappyHourSetupController.validatePrice('9,95', 10), isNull);
      // 0,02 s'arrondit a 0 : pas un prix.
      expect(HappyHourSetupController.validatePrice('0.02', 10),
          HappyHourFieldError.priceInvalid);
      expect(HappyHourSetupController.validatePrice('', 10),
          HappyHourFieldError.priceRequired);
    });
  });
}
