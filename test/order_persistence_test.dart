import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/models/order_history_item.dart';
import 'package:my_first_app/data/repositories/order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OrderRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = OrderRepository();
  });

  OrderHistoryItem createTestOrder({
    required String id,
    required String customerName,
  }) {
    return OrderHistoryItem(
      id: id,
      date: DateTime(2026, 10, 30),
      totalAmount: 25000,
      totalItems: 2,
      products: [
        {
          'id': 'headphones_pro',
          'title': 'Беспроводные наушники PRO',
          'price': 12500,
          'quantity': 2,
          'subtotal': 25000,
          'imageUrl': 'https://example.com/headphones.jpg',
        },
      ],
      customerName: customerName,
      phone: '+79991234567',
      email: 'test@example.com',
      city: 'Москва',
      address: 'Ленина, 10, кв. 5',
      zipCode: '123456',
    );
  }

  test('История заказов сохраняется и восстанавливается', () async {
    final order = createTestOrder(
      id: 'order_001',
      customerName: 'Иванов Иван Иванович',
    );

    // Сохраняем заказ.
    await repository.saveOrder(order);

    // Создаём новый экземпляр репозитория.
    final newRepository = OrderRepository();

    // Восстанавливаем историю.
    final orders = await newRepository.getOrders();

    expect(orders, hasLength(1));
    expect(orders.first.id, 'order_001');
    expect(orders.first.totalAmount, 25000);
    expect(orders.first.totalItems, 2);
    expect(orders.first.customerName, 'Иванов Иван Иванович');
    expect(orders.first.phone, '+79991234567');
    expect(orders.first.email, 'test@example.com');
    expect(orders.first.city, 'Москва');
    expect(orders.first.address, 'Ленина, 10, кв. 5');
    expect(orders.first.zipCode, '123456');
  });

  test('Новый заказ добавляется в начало истории', () async {
    final firstOrder = createTestOrder(
      id: 'order_001',
      customerName: 'Первый покупатель',
    );

    final secondOrder = createTestOrder(
      id: 'order_002',
      customerName: 'Второй покупатель',
    );

    await repository.saveOrder(firstOrder);
    await repository.saveOrder(secondOrder);

    final orders = await repository.getOrders();

    expect(orders, hasLength(2));
    expect(orders[0].id, 'order_002');
    expect(orders[1].id, 'order_001');
  });

  test('При отсутствии истории возвращается пустой список', () async {
    final orders = await repository.getOrders();

    expect(orders, isEmpty);
  });

  test('Повреждённый формат истории вызывает FormatException', () async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('order_history', '{"invalid": true}');

    expect(() => repository.getOrders(), throwsFormatException);
  });

  test('Некорректная запись заказа вызывает FormatException', () async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('order_history', '[123]');

    expect(() => repository.getOrders(), throwsFormatException);
  });
}
