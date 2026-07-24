import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/features/product/product_page.dart';
import 'package:sweettime/shared/app_models.dart';

void main() {
  test('product hero prefers the server image over a bundled demo asset', () {
    final product = _product(
      imageUrl: 'https://cdn.example/products/drink.webp',
      assetImage: 'assets/images/legacy.png',
    );

    final provider = productHeroImageProvider(product);

    expect(provider, isA<NetworkImage>());
    expect(
      (provider! as NetworkImage).url,
      'https://cdn.example/products/drink.webp',
    );
  });

  test('product hero falls back to a bundled asset, then generated art', () {
    final assetProvider = productHeroImageProvider(
      _product(assetImage: 'assets/images/drink.png'),
    );

    expect(assetProvider, isA<AssetImage>());
    expect((assetProvider! as AssetImage).assetName, 'assets/images/drink.png');
    expect(productHeroImageProvider(_product()), isNull);
  });

  test('blank server image does not shadow the bundled asset', () {
    final provider = productHeroImageProvider(
      _product(imageUrl: '  ', assetImage: 'assets/images/drink.png'),
    );

    expect(provider, isA<AssetImage>());
  });
}

Product _product({String? imageUrl, String? assetImage}) {
  return Product(
    id: 'drink-1',
    category: const MenuCategory(
      id: 'tea',
      name: LocalizedText(ru: 'Чай', ky: 'Чай', en: 'Tea'),
    ),
    name: const LocalizedText(ru: 'Напиток', ky: 'Суусундук', en: 'Drink'),
    description: const LocalizedText(ru: '', ky: '', en: ''),
    basePrice: 300,
    accentColor: const Color(0xFFFF5C9A),
    rating: 4.8,
    reviewsCount: 12,
    sizes: const [],
    toppings: const [],
    availableBranchIds: const ['branch-1'],
    imageUrl: imageUrl,
    assetImage: assetImage,
  );
}
