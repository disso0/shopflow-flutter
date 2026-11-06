import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_history_item.dart';

class OrderRepository {
  static const String _historyKey = 'order_history';

  // Очередь операций сохранения заказов.
  Future<void> _saveQueue = Future<void>.value();

  Future<List<OrderHistoryItem>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString(_historyKey);

    if (historyString == null || historyString.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(historyString);

    if (decoded is! List) {
      throw const FormatException('Некорректный формат истории заказов');
    }

    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Некорректная запись заказа');
      }

      return OrderHistoryItem.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<OrderHistoryItem?> getOrderById(String id) async {
    final orders = await getOrders();

    for (final order in orders) {
      if (order.id == id) {
        return order;
      }
    }

    return null;
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    // Получаем текущую историю заказов.
    final orders = await getOrders();

    // Находим заказ по ID.
    final orderIndex = orders.indexWhere((order) => order.id == orderId);

    // Если заказ не найден, возвращаем false.
    if (orderIndex == -1) {
      return false;
    }

    // Создаём обновлённую запись заказа.
    final updatedOrder = OrderHistoryItem(
      id: orders[orderIndex].id,
      date: orders[orderIndex].date,
      totalAmount: orders[orderIndex].totalAmount,
      totalItems: orders[orderIndex].totalItems,
      products: orders[orderIndex].products,
      customerName: orders[orderIndex].customerName,
      phone: orders[orderIndex].phone,
      email: orders[orderIndex].email,
      city: orders[orderIndex].city,
      address: orders[orderIndex].address,
      zipCode: orders[orderIndex].zipCode,
      paymentMethod: orders[orderIndex].paymentMethod,
      status: newStatus,
    );

    // Обновляем заказ в истории.
    final prefs = await SharedPreferences.getInstance();

    orders[orderIndex] = updatedOrder;

    final saved = await prefs.setString(
      _historyKey,
      jsonEncode(orders.map((order) => order.toMap()).toList()),
    );

    if (!saved) {
      throw Exception('Не удалось обновить статус заказа');
    }

    return true;
  }

  Future<void> saveOrder(OrderHistoryItem order) {
    final saveOperation = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyKey);

      List<dynamic> history = [];

      if (historyString != null && historyString.isNotEmpty) {
        final decoded = jsonDecode(historyString);

        if (decoded is! List) {
          throw const FormatException('Некорректный формат истории заказов');
        }

        history = decoded;
      }

      history.insert(0, order.toMap());

      final saved = await prefs.setString(_historyKey, jsonEncode(history));

      if (!saved) {
        throw Exception('Не удалось сохранить историю заказов');
      }
    });

    // Даже если одна операция завершилась ошибкой,
    // следующая операция сможет продолжить работу.
    _saveQueue = saveOperation.catchError((Object error) {
      // Ошибка остаётся доступной вызывающему saveOrder().
    });

    return saveOperation;
  }
}
