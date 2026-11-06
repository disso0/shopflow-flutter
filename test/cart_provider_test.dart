import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/models/product.dart';
import 'package:my_first_app/domain/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartProvider', () {
    late CartProvider cartProvider;
    late Product testProduct;

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

      cartProvider = CartProvider();
      await cartProvider.waitUntilInitialized();
    });

    tearDown(() {
      cartProvider.dispose();
    });

    test('добавляет товар в корзину', () {
      cartProvider.addToCart(testProduct);

      expect(cartProvider.cartItems.length, 1);
      expect(cartProvider.cartItems.first.product.id, 'test_product');
      expect(cartProvider.cartItems.first.quantity, 1);
    });

    test('повторное добавление увеличивает количество', () {
      cartProvider.addToCart(testProduct);
      cartProvider.addToCart(testProduct);

      expect(cartProvider.cartItems.length, 1);
      expect(cartProvider.cartItems.first.quantity, 2);
    });

    test('правильно рассчитывает сумму корзины', () {
      cartProvider.addToCart(testProduct);
      cartProvider.addToCart(testProduct);

      expect(cartProvider.totalAmount, 2000);
      expect(cartProvider.totalItemsCount, 2);
    });
    test('обновляет цену товара, сохраняя его количество', () {
      cartProvider.addToCart(testProduct);
      cartProvider.addToCart(testProduct);

      final updatedProduct = Product(
        id: 'test_product',
        title: 'Тестовый товар',
        subtitle: 'Описание товара',
        intPrice: 1500,
        category: 'test',
        icon: Icons.shopping_bag,
        iconColor: Colors.blue,
        detailedDescription: 'Тестовое описание',
        imageUrl: '',
      );

      cartProvider.updateProductPrices([updatedProduct]);

      expect(cartProvider.cartItems.length, 1);
      expect(cartProvider.cartItems.first.product.intPrice, 1500);
      expect(cartProvider.cartItems.first.quantity, 2);
      expect(cartProvider.totalAmount, 3000);
      expect(cartProvider.totalItemsCount, 2);
    });

    test('уменьшает количество товара', () {
      cartProvider.addToCart(testProduct);
      cartProvider.addToCart(testProduct);

      cartProvider.decrementQuantity(testProduct);

      expect(cartProvider.cartItems.first.quantity, 1);
      expect(cartProvider.totalAmount, 1000);
    });

    test('удаляет товар при уменьшении количества до нуля', () {
      cartProvider.addToCart(testProduct);

      cartProvider.decrementQuantity(testProduct);

      expect(cartProvider.cartItems, isEmpty);
      expect(cartProvider.totalAmount, 0);
    });

    test('полностью очищает корзину', () {
      cartProvider.addToCart(testProduct);
      cartProvider.clearCart();

      expect(cartProvider.cartItems, isEmpty);
      expect(cartProvider.totalAmount, 0);
      expect(cartProvider.totalItemsCount, 0);
    });

    test(
      'восстанавливает корзину после повторного создания провайдера',
      () async {
        // Добавляем два одинаковых товара.
        cartProvider.addToCart(testProduct);
        cartProvider.addToCart(testProduct);

        // Ждём завершения сохранения данных.
        await cartProvider.waitUntilSaved();

        // Создаём новый провайдер, имитируя повторный запуск приложения.
        final newCartProvider = CartProvider();

        // Ждём загрузки корзины из SharedPreferences.
        await newCartProvider.waitUntilInitialized();

        expect(newCartProvider.cartItems.length, 1);
        expect(newCartProvider.cartItems.first.product.id, 'test_product');
        expect(newCartProvider.cartItems.first.quantity, 2);
        expect(newCartProvider.totalAmount, 2000);

        newCartProvider.dispose();
      },
    );
    test('выбрасывает StateError при изменении после dispose', () {
      // Создаём отдельный экземпляр для этого теста.
      final disposedProvider = CartProvider();

      // Уничтожаем его.
      disposedProvider.dispose();

      // Проверяем, что после dispose нельзя добавлять товары.
      expect(
        () => disposedProvider.addToCart(testProduct),
        throwsA(isA<StateError>()),
      );
    });
    test('удаляет только количество товаров из оформленного заказа', () {
      cartProvider.addToCart(testProduct);
      cartProvider.addToCart(testProduct);

      // Фиксируем заказ на два товара.
      final purchasedQuantities = {testProduct.id: 2};

      // После оформления в корзину добавили ещё один товар.
      cartProvider.addToCart(testProduct);

      // Удаляем только товары из первоначального заказа.
      cartProvider.removePurchasedItems(purchasedQuantities);

      expect(cartProvider.cartItems.length, 1);
      expect(cartProvider.cartItems.first.quantity, 1);
      expect(cartProvider.totalAmount, 1000);
      expect(cartProvider.totalItemsCount, 1);
    });
  });
}
