import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/models/order_history_item.dart';
import 'package:my_first_app/data/repositories/order_repository.dart';

void main() {
  group('OrderRepository', () {
    late OrderRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = OrderRepository();
    });

    test('возвращает пустой список, если истории заказов нет', () async {
      final orders = await repository.getOrders();

      expect(orders, isEmpty);
    });

    test('сохраняет заказ и возвращает его при чтении', () async {
      final order = OrderHistoryItem(
        id: 'TEST-001',
        date: DateTime(2026, 10, 30),
        totalAmount: 12500,
        totalItems: 1,
        customerName: 'Тестовый покупатель',
        phone: '123456789',
        email: 'test@example.com',
        city: 'Test City',
        address: 'Test Street 1',
        zipCode: '12345',
      );

      await repository.saveOrder(order);

      final orders = await repository.getOrders();

      expect(orders.length, 1);
      expect(orders.first.id, 'TEST-001');
      expect(orders.first.totalAmount, 12500);
      expect(orders.first.customerName, 'Тестовый покупатель');
    });

    test('сохраняет несколько заказов в правильном порядке', () async {
      final firstOrder = OrderHistoryItem(
        id: 'ORDER-001',
        date: DateTime(2026, 10, 29),
        totalAmount: 10000,
        totalItems: 1,
      );

      final secondOrder = OrderHistoryItem(
        id: 'ORDER-002',
        date: DateTime(2026, 10, 30),
        totalAmount: 20000,
        totalItems: 2,
      );

      await repository.saveOrder(firstOrder);
      await repository.saveOrder(secondOrder);

      final orders = await repository.getOrders();

      expect(orders.length, 2);
      expect(orders[0].id, 'ORDER-002');
      expect(orders[1].id, 'ORDER-001');
    });

    test('сохраняет количество и сумму каждого заказа отдельно', () async {
      final firstOrder = OrderHistoryItem(
        id: 'ORDER-003',
        date: DateTime(2026, 10, 30),
        totalAmount: 15000,
        totalItems: 3,
      );

      final secondOrder = OrderHistoryItem(
        id: 'ORDER-004',
        date: DateTime(2026, 10, 30),
        totalAmount: 25000,
        totalItems: 5,
      );

      await repository.saveOrder(firstOrder);
      await repository.saveOrder(secondOrder);

      final orders = await repository.getOrders();

      expect(orders[0].totalAmount, 25000);
      expect(orders[0].totalItems, 5);
      expect(orders[1].totalAmount, 15000);
      expect(orders[1].totalItems, 3);
    });

    test('выбрасывает FormatException при повреждённой истории', () async {
      SharedPreferences.setMockInitialValues({'order_history': 'это не JSON'});

      await expectLater(
        repository.getOrders(),
        throwsA(isA<FormatException>()),
      );
    });

    test('не перезаписывает повреждённую историю при сохранении', () async {
      const corruptedHistory = 'это не JSON';

      SharedPreferences.setMockInitialValues({
        'order_history': corruptedHistory,
      });

      final order = OrderHistoryItem(
        id: 'ORDER-005',
        date: DateTime(2026, 10, 30),
        totalAmount: 10000,
        totalItems: 1,
      );

      await expectLater(
        repository.saveOrder(order),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('order_history'), corruptedHistory);
    });

    test(
      'сохраняет одновременно отправленные заказы без потери данных',
      () async {
        final firstOrder = OrderHistoryItem(
          id: 'ORDER-006',
          date: DateTime(2026, 10, 30),
          totalAmount: 10000,
          totalItems: 1,
        );

        final secondOrder = OrderHistoryItem(
          id: 'ORDER-007',
          date: DateTime(2026, 10, 30),
          totalAmount: 20000,
          totalItems: 2,
        );

        final thirdOrder = OrderHistoryItem(
          id: 'ORDER-008',
          date: DateTime(2026, 10, 30),
          totalAmount: 30000,
          totalItems: 3,
        );

        await Future.wait([
          repository.saveOrder(firstOrder),
          repository.saveOrder(secondOrder),
          repository.saveOrder(thirdOrder),
        ]);

        final orders = await repository.getOrders();

        expect(orders.length, 3);

        final savedIds = orders.map((order) => order.id).toSet();

        expect(savedIds, containsAll(['ORDER-006', 'ORDER-007', 'ORDER-008']));
      },
    );

    test(
      'продолжает сохранять заказы после ошибки предыдущего сохранения',
      () async {
        SharedPreferences.setMockInitialValues({
          'order_history': 'это не JSON',
        });

        await expectLater(
          repository.saveOrder(
            OrderHistoryItem(
              id: 'ORDER-009',
              date: DateTime(2026, 10, 30),
              totalAmount: 10000,
              totalItems: 1,
            ),
          ),
          throwsA(isA<FormatException>()),
        );

        // Исправляем повреждённую историю.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('order_history', '[]');

        // Проверяем, что очередь не заблокирована предыдущей ошибкой.
        final nextOrder = OrderHistoryItem(
          id: 'ORDER-010',
          date: DateTime(2026, 10, 30),
          totalAmount: 20000,
          totalItems: 2,
        );

        await repository.saveOrder(nextOrder);

        final orders = await repository.getOrders();

        expect(orders.length, 1);
        expect(orders.first.id, 'ORDER-010');
      },
    );
    test('сохраняет выбранный способ оплаты', () async {
      final order = OrderHistoryItem(
        id: 'PAYMENT-001',
        date: DateTime(2026, 10, 30),
        totalAmount: 15000,
        totalItems: 1,
        paymentMethod: 'Онлайн (демо)',
      );

      await repository.saveOrder(order);

      final orders = await repository.getOrders();

      expect(orders.first.paymentMethod, 'Онлайн (демо)');
    });

    test('использует способ оплаты по умолчанию для старых заказов', () {
      final oldOrder = OrderHistoryItem.fromMap({
        'id': 'OLD-001',
        'date': '2026-10-30T12:00:00.000',
        'totalAmount': 10000,
        'totalItems': 1,
      });

      expect(oldOrder.paymentMethod, 'При получении');
    });
    test('находит заказ по ID', () async {
      final order = OrderHistoryItem(
        id: 'FIND-001',
        date: DateTime(2026, 10, 30),
        totalAmount: 15000,
        totalItems: 2,
      );

      await repository.saveOrder(order);

      final foundOrder = await repository.getOrderById('FIND-001');

      expect(foundOrder, isNotNull);
      expect(foundOrder!.id, 'FIND-001');
      expect(foundOrder.totalAmount, 15000);
    });

    test('возвращает null, если заказ с таким ID отсутствует', () async {
      final foundOrder = await repository.getOrderById('UNKNOWN-001');

      expect(foundOrder, isNull);
    });
    test('сохраняет и восстанавливает статус заказа', () async {
      final order = OrderHistoryItem(
        id: 'STATUS-001',
        date: DateTime(2026, 10, 30),
        totalAmount: 15000,
        totalItems: 2,
        status: 'confirmed',
      );

      await repository.saveOrder(order);

      final savedOrder = await repository.getOrderById('STATUS-001');

      expect(savedOrder, isNotNull);
      expect(savedOrder!.status, 'confirmed');
    });

    test('назначает статус new старым заказам без поля status', () {
      final oldOrder = OrderHistoryItem.fromMap({
        'id': 'OLD-STATUS-001',
        'date': '2026-10-30T12:00:00.000',
        'totalAmount': 10000,
        'totalItems': 1,
      });

      expect(oldOrder.status, 'new');
    });

    test('обновляет статус существующего заказа', () async {
      final order = OrderHistoryItem(
        id: 'UPDATE-001',
        date: DateTime(2026, 10, 30),
        totalAmount: 15000,
        totalItems: 2,
        customerName: 'Тестовый покупатель',
        paymentMethod: 'Онлайн (демо)',
        status: 'new',
      );

      await repository.saveOrder(order);

      final updated = await repository.updateOrderStatus(
        'UPDATE-001',
        'confirmed',
      );

      final savedOrder = await repository.getOrderById('UPDATE-001');

      expect(updated, isTrue);
      expect(savedOrder!.status, 'confirmed');
      expect(savedOrder.totalAmount, 15000);
      expect(savedOrder.paymentMethod, 'Онлайн (демо)');
      expect(savedOrder.customerName, 'Тестовый покупатель');
    });

    test('возвращает false, если заказ для обновления не найден', () async {
      final updated = await repository.updateOrderStatus(
        'UNKNOWN-001',
        'confirmed',
      );

      expect(updated, isFalse);
    });

    test('не изменяет другие заказы при обновлении статуса', () async {
      await repository.saveOrder(
        OrderHistoryItem(
          id: 'UPDATE-002',
          date: DateTime(2026, 10, 30),
          totalAmount: 10000,
          totalItems: 1,
          status: 'new',
        ),
      );

      await repository.saveOrder(
        OrderHistoryItem(
          id: 'UPDATE-003',
          date: DateTime(2026, 10, 30),
          totalAmount: 20000,
          totalItems: 2,
          status: 'new',
        ),
      );

      await repository.updateOrderStatus('UPDATE-002', 'shipped');

      final firstOrder = await repository.getOrderById('UPDATE-002');
      final secondOrder = await repository.getOrderById('UPDATE-003');

      expect(firstOrder!.status, 'shipped');
      expect(secondOrder!.status, 'new');
    });
  });
}
