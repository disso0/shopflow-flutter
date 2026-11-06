import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/models/order_history_item.dart';
import 'package:my_first_app/data/repositories/order_repository.dart';
import 'package:my_first_app/presentation/screens/orders_screen.dart';

void main() {
  group('OrdersPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('отображает пустое состояние, если заказов нет', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

      await tester.pumpAndSettle();

      expect(find.text('Мои заказы'), findsOneWidget);
      expect(find.text('Заказов пока нет'), findsOneWidget);
      expect(
        find.text('Оформленные заказы будут отображаться здесь.'),
        findsOneWidget,
      );
    });

    testWidgets('отображает сохранённый заказ', (tester) async {
      final repository = OrderRepository();

      await repository.saveOrder(
        OrderHistoryItem(
          id: 'TEST-001',
          date: DateTime(2026, 10, 30),
          totalAmount: 12500,
          totalItems: 1,
          customerName: 'Тестовый покупатель',
          paymentMethod: 'При получении',
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

      await tester.pumpAndSettle();

      expect(find.text('Заказ TEST-001'), findsOneWidget);
      expect(find.textContaining('Количество товаров: 1'), findsOneWidget);
      expect(find.textContaining('12500.00 ₽'), findsOneWidget);
    });

    testWidgets('показывает способ оплаты при раскрытии заказа', (
      tester,
    ) async {
      final repository = OrderRepository();

      await repository.saveOrder(
        OrderHistoryItem(
          id: 'PAYMENT-001',
          date: DateTime(2026, 10, 30),
          totalAmount: 15000,
          totalItems: 2,
          customerName: 'Тестовый покупатель',
          paymentMethod: 'Онлайн (демо)',
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

      await tester.pumpAndSettle();

      expect(find.text('Заказ PAYMENT-001'), findsOneWidget);

      // Раскрываем карточку заказа.
      await tester.tap(find.text('Заказ PAYMENT-001'));
      await tester.pumpAndSettle();

      expect(find.text('Способ оплаты: Онлайн (демо)'), findsOneWidget);

      expect(find.text('Состав заказа'), findsOneWidget);
      expect(find.text('Получатель и доставка'), findsOneWidget);
    });
  });
}
