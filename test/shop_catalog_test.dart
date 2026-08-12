import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/shop/models/shop_catalog.dart';

void main() {
  test('catalog exposes every planned personalization category once', () {
    expect(shopCatalog, hasLength(10));
    expect(shopCatalog.map((entry) => entry.id).toSet(), {
      'clothing',
      'hair',
      'accessories',
      'shoes',
      'decoration',
      'furniture',
      'garden',
      'pet',
      'backgrounds',
      'themes',
    });
  });

  test('unavailable categories cannot expose a purchase destination', () {
    final unavailable = shopCatalog.where((entry) => !entry.canOpen);
    expect(unavailable, isNotEmpty);
    expect(
      unavailable.every(
        (entry) =>
            entry.access == ShopAccess.locked ||
            entry.access == ShopAccess.premiumFuture,
      ),
      isTrue,
    );
    expect(
      shopCatalog
          .where((entry) => entry.access == ShopAccess.coins)
          .every(
            (entry) =>
                entry.destination == ShopDestination.interior ||
                entry.destination == ShopDestination.garden,
          ),
      isTrue,
    );
  });
}
