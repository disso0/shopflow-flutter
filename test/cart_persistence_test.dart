import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/repositories/product_repository.dart';
import 'package:my_first_app/domain/providers/cart_provider.dart';
import 'package:my_first_app/data/models/cart_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Корзина сохраняется и восстанавливается после перезапуска', () async {
    // 1. Получаем демонстрационные товары.
    final products = ProductRepository.mockProducts;

    final headphones = products.firstWhere(
      (product) => product.id == 'headphones_pro',
    );

    final watch = products.firstWhere(
      (product) => product.id == 'sport_watch_x',
    );

    // 2. Создаём первую корзину.
    final firstCart = CartProvider();

    await firstCart.waitUntilInitialized();

    // 3. Добавляем наушники два раза и часы один раз.
    firstCart.addToCart(headphones);
    firstCart.addToCart(headphones);
    firstCart.addToCart(watch);

    // 4. Дожидаемся сохранения.
    await firstCart.waitUntilSaved();

    expect(firstCart.cartItems.length, 2);
    expect(firstCart.totalItemsCount, 3);

    final expectedTotal = headphones.intPrice * 2 + watch.intPrice;

    expect(firstCart.totalAmount, expectedTotal);

    // 5. Имитируем перезапуск: создаём новый CartProvider.
    firstCart.dispose();

    final restoredCart = CartProvider();

    // 6. Ждём восстановления данных.
    await restoredCart.waitUntilInitialized();

    // 7. Проверяем восстановленную корзину.
    expect(restoredCart.cartItems.length, 2);
    expect(restoredCart.totalItemsCount, 3);

    expect(
      restoredCart.cartItems
          .firstWhere((item) => item.product.id == 'headphones_pro')
          .quantity,
      2,
    );

    expect(
      restoredCart.cartItems
          .firstWhere((item) => item.product.id == 'sport_watch_x')
          .quantity,
      1,
    );

    expect(restoredCart.totalAmount, expectedTotal);

    // 8. Освобождаем ресурсы.
    restoredCart.dispose();
  });

  test('Удаление и очистка корзины сохраняются', () async {
    final products = ProductRepository.mockProducts;

    final headphones = products.firstWhere(
      (product) => product.id == 'headphones_pro',
    );

    final watch = products.firstWhere(
      (product) => product.id == 'sport_watch_x',
    );

    final cart = CartProvider();
    await cart.waitUntilInitialized();

    // Добавляем товары.
    cart.addToCart(headphones);
    cart.addToCart(headphones);
    cart.addToCart(watch);

    await cart.waitUntilSaved();

    // Уменьшаем количество наушников с 2 до 1.
    cart.decrementQuantity(headphones);
    await cart.waitUntilSaved();

    expect(
      cart.cartItems
          .firstWhere((item) => item.product.id == 'headphones_pro')
          .quantity,
      1,
    );

    // Удаляем часы.
    cart.removeFromCart(watch);
    await cart.waitUntilSaved();

    expect(cart.cartItems.length, 1);
    expect(cart.totalItemsCount, 1);

    // Имитируем перезапуск.
    cart.dispose();

    final restoredCart = CartProvider();
    await restoredCart.waitUntilInitialized();

    expect(restoredCart.cartItems.length, 1);
    expect(restoredCart.cartItems.first.product.id, 'headphones_pro');
    expect(restoredCart.cartItems.first.quantity, 1);

    // Полностью очищаем корзину.
    restoredCart.clearCart();
    await restoredCart.waitUntilSaved();

    restoredCart.dispose();

    // Проверяем пустую корзину после нового запуска.
    final emptyCart = CartProvider();
    await emptyCart.waitUntilInitialized();

    expect(emptyCart.cartItems, isEmpty);
    expect(emptyCart.totalItemsCount, 0);
    expect(emptyCart.totalAmount, 0);

    emptyCart.dispose();
  });
  test('быстрые изменения корзины сохраняются в правильном порядке', () async {
    final products = ProductRepository.mockProducts;
    final headphones = products.firstWhere(
      (product) => product.id == 'headphones_pro',
    );

    final cart = CartProvider();
    await cart.waitUntilInitialized();

    // Быстро изменяем корзину, не ожидая каждого сохранения.
    cart.addToCart(headphones);
    cart.addToCart(headphones);
    cart.decrementQuantity(headphones);
    cart.addToCart(headphones);

    // Ждём завершения всех операций сохранения.
    await cart.waitUntilSaved();

    expect(cart.cartItems.length, 1);
    expect(cart.cartItems.first.quantity, 2);
    expect(cart.totalItemsCount, 2);

    // Проверяем, что итоговое состояние действительно сохранено.
    cart.dispose();

    final restoredCart = CartProvider();
    await restoredCart.waitUntilInitialized();

    expect(restoredCart.cartItems.length, 1);
    expect(restoredCart.cartItems.first.quantity, 2);
    expect(restoredCart.totalItemsCount, 2);

    restoredCart.dispose();
  });
  test('изменения во время загрузки не теряются', () async {
    final products = ProductRepository.mockProducts;
    final headphones = products.firstWhere(
      (product) => product.id == 'headphones_pro',
    );

    final watch = products.firstWhere(
      (product) => product.id == 'sport_watch_x',
    );

    // Предварительно сохраняем один товар.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'shopping_cart',
      jsonEncode([CartItem(product: headphones, quantity: 2).toMap()]),
    );

    // Создаём провайдер и сразу добавляем другой товар,
    // не дожидаясь окончания первоначальной загрузки.
    final cart = CartProvider();
    cart.addToCart(watch);

    await cart.waitUntilInitialized();
    await cart.waitUntilSaved();

    expect(cart.cartItems.length, 2);
    expect(
      cart.cartItems
          .firstWhere((item) => item.product.id == 'headphones_pro')
          .quantity,
      2,
    );
    expect(
      cart.cartItems
          .firstWhere((item) => item.product.id == 'sport_watch_x')
          .quantity,
      1,
    );

    cart.dispose();
  });
}
