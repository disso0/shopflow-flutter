import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:my_first_app/main.dart';
import 'package:my_first_app/data/repositories/product_repository.dart';
import 'package:my_first_app/data/models/product_load_result.dart';
import 'package:my_first_app/data/repositories/order_repository.dart';
import 'package:my_first_app/domain/providers/cart_provider.dart';
import 'package:my_first_app/presentation/screens/orders_screen.dart';

class FakeProductRepository extends ProductRepository {
  @override
  Future<ProductLoadResult> getProducts() async {
    return ProductLoadResult(
      products: ProductRepository.mockProducts,
      source: ProductDataSource.demo,
    );
  }

  @override
  Future<ProductLoadResult?> refreshProductsFromApi() async {
    return ProductLoadResult(
      products: ProductRepository.mockProducts,
      source: ProductDataSource.demo,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Проверка авторизации и открытия каталога', (tester) async {
    // Увеличиваем размер окна теста, чтобы нижняя панель
    // корзины полностью помещалась на экране.
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // 1. Запускаем приложение с тестовым репозиторием.
    await tester.pumpWidget(
      MyApp(initialDarkMode: false, productRepository: FakeProductRepository()),
    );

    // 2. Проверяем экран авторизации.
    expect(find.text('Вход в приложение'), findsOneWidget);

    // 3. Вводим логин.
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');

    // 4. Вводим пароль.
    await tester.enterText(find.byType(TextField).at(1), 'test12345');

    // 5. Нажимаем кнопку входа.
    await tester.tap(find.text('Войти'));

    // 6. Запускаем таймер авторизации (2 секунды).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // 7. Даём каталогу завершить асинхронную загрузку.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // 8. Проверяем открытие каталога.
    expect(find.text('Каталог товаров'), findsOneWidget);

    // 9. Проверяем наличие демонстрационного товара.
    expect(find.text('Беспроводные наушники PRO'), findsOneWidget);

    // 10. Находим карточку наушников PRO.
    final productCard = find
        .ancestor(
          of: find.text('Беспроводные наушники PRO'),
          matching: find.byType(Card),
        )
        .first;

    // 11. Находим кнопку добавления именно в этой карточке.
    final addToCartButton = find.descendant(
      of: productCard,
      matching: find.byTooltip('Добавить в корзину'),
    );

    // 12. Прокручиваем вертикальный список каталога
    // до кнопки добавления товара.
    await tester.scrollUntilVisible(
      addToCartButton,
      300,
      scrollable: find.byType(Scrollable).last,
    );

    // Даём прокрутке завершиться.
    await tester.pumpAndSettle();

    // 13. Проверяем, что кнопка действительно видна.
    expect(addToCartButton, findsOneWidget);

    // 14. Добавляем наушники в корзину.
    await tester.tap(addToCartButton);
    await tester.pump();

    // 14. Открываем корзину.
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // 15. Проверяем наличие товара.
    expect(find.text('Беспроводные наушники PRO'), findsOneWidget);

    // 16. Проверяем стоимость одной позиции.
    expect(find.text('12500 ₽'), findsNWidgets(2));

    // 17. Увеличиваем количество товара до двух.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    // 18. Проверяем количество.
    expect(find.text('2'), findsOneWidget);

    // 19. Проверяем новую стоимость позиции и общий итог.
    expect(find.text('25000 ₽'), findsNWidgets(2));
    // 20. Находим кнопку оформления заказа.
    final checkoutButton = find
        .ancestor(
          of: find.text('Оформить заказ'),
          matching: find.byType(ElevatedButton),
        )
        .first;

    expect(checkoutButton, findsOneWidget);

    // Получаем координаты кнопки.
    final buttonRect = tester.getRect(checkoutButton);

    // Нажимаем по кнопке.
    await tester.tapAt(Offset(buttonRect.center.dx, buttonRect.top + 12));

    await tester.pumpAndSettle();

    // 21. Проверяем переход к оформлению заказа.
    expect(find.text('Контактные данные'), findsOneWidget);
    expect(find.text('Оформление заказа'), findsOneWidget);
    // Проверяем, что нельзя перейти дальше с пустыми полями.
    final contactNextButton = find
        .ancestor(
          of: find.text('Далее').first,
          matching: find.byType(ElevatedButton),
        )
        .first;

    await tester.ensureVisible(contactNextButton);
    await tester.pumpAndSettle();

    await tester.tap(contactNextButton);
    await tester.pumpAndSettle();

    // Проверяем сообщения об ошибках.
    expect(find.text('Введите имя'), findsOneWidget);
    expect(find.text('Введите телефон'), findsOneWidget);
    expect(find.text('Введите Email'), findsOneWidget);

    // 22. Заполняем контактные данные.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ФИО'),
      'Иванов Иван Иванович',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон'),
      '+79991234567',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ivanov@example.com',
    );
    // Проверяем неправильный формат Email.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ivanov',
    );

    await tester.tap(contactNextButton);
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный Email'), findsOneWidget);

    // Возвращаем корректный Email.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ivanov@example.com',
    );

    // 23. Переходим к адресу доставки.
    // Убираем фокус с поля Email.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Находим кнопку первого шага.
    final firstNextButton = find
        .ancestor(
          of: find.text('Далее').first,
          matching: find.byType(ElevatedButton),
        )
        .first;

    // Делаем кнопку видимой.
    await tester.ensureVisible(firstNextButton);
    await tester.pumpAndSettle();

    // Нажимаем кнопку.
    await tester.tap(firstNextButton);
    await tester.pumpAndSettle();

    expect(find.text('Адрес доставки'), findsOneWidget);

    expect(find.text('Адрес доставки'), findsOneWidget);
    // Проверяем, что нельзя продолжить без адреса.
    final deliveryNextButton = find
        .ancestor(
          of: find.text('Далее').at(1),
          matching: find.byType(ElevatedButton),
        )
        .first;

    await tester.ensureVisible(deliveryNextButton);
    await tester.pumpAndSettle();

    await tester.tap(deliveryNextButton);
    await tester.pumpAndSettle();

    expect(find.text('Укажите город'), findsOneWidget);
    expect(find.text('Укажите адрес доставки'), findsOneWidget);
    expect(find.text('Введите индекс: минимум 5 цифр'), findsOneWidget);
    // 24. Заполняем адрес.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Город'),
      'Москва',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Адрес (Улица, дом, квартира)'),
      'Ленина, 10, кв. 5',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Почтовый индекс'),
      '123456',
    );
    // Проверяем слишком короткий почтовый индекс.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Почтовый индекс'),
      '123',
    );

    await tester.tap(deliveryNextButton);
    await tester.pumpAndSettle();

    expect(find.text('Введите индекс: минимум 5 цифр'), findsOneWidget);

    // Возвращаем правильный индекс.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Почтовый индекс'),
      '123456',
    );
    // 25. Переходим к выбору оплаты.
    // Убираем фокус с поля почтового индекса.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Находим кнопку второго шага.
    // Она следует после кнопки первого шага.
    final secondNextButton = find
        .ancestor(
          of: find.text('Далее').at(1),
          matching: find.byType(ElevatedButton),
        )
        .first;

    await tester.ensureVisible(secondNextButton);
    await tester.pumpAndSettle();

    await tester.tap(secondNextButton);
    await tester.pumpAndSettle();

    expect(find.text('Способ оплаты'), findsOneWidget);
    expect(find.text('Оплата при получении'), findsOneWidget);

    // 26. Завершаем оформление заказа.
    // Находим активную кнопку оплаты.
    final payButton = find
        .ancestor(
          of: find.text('Оплатить 25000 ₽').last,
          matching: find.byType(ElevatedButton),
        )
        .last;

    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();

    await tester.tap(payButton);
    await tester.pump();

    // 27. Проверяем состояние обработки заказа.
    expect(find.text('Создаем ваш заказ...'), findsOneWidget);

    // 28. Ждём завершения имитации оформления (3 секунды).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 29. Проверяем успешное возвращение в каталог.
    expect(find.text('Каталог товаров'), findsOneWidget);
    // 29.1. Открываем профиль пользователя.
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    expect(find.text('Профиль пользователя'), findsOneWidget);

    // 29.2. Переходим в историю заказов.
    await tester.tap(find.text('Мои заказы'));
    await tester.pumpAndSettle();

    // 29.3. Проверяем открытие истории.
    expect(find.text('Мои заказы'), findsOneWidget);
    // 29.4. Проверяем сохранённый заказ.
    expect(find.textContaining('Заказ №'), findsOneWidget);
    expect(find.textContaining('Количество товаров: 2'), findsOneWidget);
    expect(find.text('25000.00 ₽'), findsOneWidget);

    // 29.5. Раскрываем карточку заказа.
    await tester.tap(find.textContaining('Заказ №'));
    await tester.pumpAndSettle();

    // 29.6. Проверяем состав заказа.
    expect(find.text('Состав заказа'), findsOneWidget);
    expect(find.text('Беспроводные наушники PRO'), findsOneWidget);
    expect(find.text('12500 ₽ × 2'), findsOneWidget);

    // 29.7. Проверяем данные покупателя.
    expect(find.text('Получатель: Иванов Иван Иванович'), findsOneWidget);
    expect(find.text('Телефон: +79991234567'), findsOneWidget);
    expect(find.text('Email: ivanov@example.com'), findsOneWidget);

    // 29.8. Проверяем доставку.
    expect(find.text('Город: Москва'), findsOneWidget);
    expect(find.text('Адрес: Ленина, 10, кв. 5'), findsOneWidget);
    expect(find.text('Индекс: 123456'), findsOneWidget);

    // 30. Проверяем, что заказ сохранён в истории.
    final orderRepository = OrderRepository();
    final orders = await orderRepository.getOrders();

    expect(orders, hasLength(1));
    expect(orders.first.totalAmount, 25000);
    expect(orders.first.totalItems, 2);
    expect(orders.first.customerName, 'Иванов Иван Иванович');
    expect(orders.first.email, 'ivanov@example.com');
    expect(orders.first.city, 'Москва');
    expect(orders.first.address, 'Ленина, 10, кв. 5');
    expect(orders.first.zipCode, '123456');

    // 31. Проверяем, что корзина после покупки очищена.
    final cartProvider = Provider.of<CartProvider>(
      tester.element(find.byType(OrdersPage)),
      listen: false,
    );

    await cartProvider.waitUntilSaved();

    expect(cartProvider.cartItems, isEmpty);
    expect(cartProvider.totalAmount, 0);
  });
}
