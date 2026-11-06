import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/models/product.dart';
import 'package:my_first_app/domain/providers/favorites_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesProvider', () {
    late FavoritesProvider favoritesProvider;
    late Product testProduct;
    late Product secondProduct;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      testProduct = Product(
        id: 'test_product',
        title: 'Тестовый товар',
        subtitle: 'Описание товара',
        intPrice: 1000,
        category: 'test',
        icon: Icons.shopping_bag,
        iconColor: Colors.blue,
        detailedDescription: 'Тестовое описание',
        imageUrl: '',
      );

      secondProduct = Product(
        id: 'second_product',
        title: 'Второй товар',
        subtitle: 'Описание второго товара',
        intPrice: 2000,
        category: 'test',
        icon: Icons.headphones,
        iconColor: Colors.green,
        detailedDescription: 'Описание второго товара',
        imageUrl: '',
      );

      favoritesProvider = FavoritesProvider();
      await favoritesProvider.loadFavorites();
    });

    tearDown(() {
      favoritesProvider.dispose();
    });

    test('изначально список избранного пуст', () {
      expect(favoritesProvider.favorites, isEmpty);
      expect(favoritesProvider.isLoaded, isTrue);
    });

    test('добавляет товар в избранное', () async {
      await favoritesProvider.toggleFavorite(testProduct);

      expect(favoritesProvider.favorites.length, 1);
      expect(favoritesProvider.isFavorite('test_product'), isTrue);
    });

    test('повторное нажатие удаляет товар из избранного', () async {
      await favoritesProvider.toggleFavorite(testProduct);
      await favoritesProvider.toggleFavorite(testProduct);

      expect(favoritesProvider.favorites, isEmpty);
      expect(favoritesProvider.isFavorite('test_product'), isFalse);
    });

    test('сохраняет разные товары отдельно', () async {
      await favoritesProvider.toggleFavorite(testProduct);
      await favoritesProvider.toggleFavorite(secondProduct);

      expect(favoritesProvider.favorites.length, 2);
      expect(favoritesProvider.isFavorite('test_product'), isTrue);
      expect(favoritesProvider.isFavorite('second_product'), isTrue);
    });

    test('сохраняет избранное в SharedPreferences', () async {
      await favoritesProvider.toggleFavorite(testProduct);

      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('favorite_products');

      expect(savedData, isNotNull);
      expect(savedData, contains('test_product'));
    });

    test(
      'восстанавливает избранное после создания нового провайдера',
      () async {
        await favoritesProvider.toggleFavorite(testProduct);
        await favoritesProvider.toggleFavorite(secondProduct);

        final newFavoritesProvider = FavoritesProvider();
        await newFavoritesProvider.loadFavorites();

        expect(newFavoritesProvider.favorites.length, 2);
        expect(newFavoritesProvider.isFavorite('test_product'), isTrue);
        expect(newFavoritesProvider.isFavorite('second_product'), isTrue);

        newFavoritesProvider.dispose();
      },
    );
  });
}
