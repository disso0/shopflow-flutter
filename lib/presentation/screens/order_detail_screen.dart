import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/order_history_item.dart';
import '../../data/repositories/order_repository.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrderRepository _orderRepository = OrderRepository();

  OrderHistoryItem? _order;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _orderRepository.getOrderById(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = order;
        _isLoading = false;

        if (order == null) {
          _errorMessage = 'Заказ не найден.';
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки заказа: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Не удалось загрузить заказ.';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_order == null || _isUpdatingStatus) return;

    // Если выбран тот же статус, ничего не делаем.
    if (_order!.status == newStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final updated = await _orderRepository.updateOrderStatus(
        widget.orderId,
        newStatus,
      );

      if (!mounted) return;

      if (!updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ не найден. Не удалось изменить статус.'),
          ),
        );
        return;
      }

      // Получаем обновлённый заказ из хранилища.
      final updatedOrder = await _orderRepository.getOrderById(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = updatedOrder;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус заказа успешно обновлён.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Ошибка обновления статуса заказа: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить новый статус.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'confirmed':
        return 'Подтверждён';
      case 'processing':
        return 'Собирается';
      case 'shipped':
        return 'Отправлен';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменён';
      default:
        return 'Неизвестен';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  double _getDouble(dynamic value) {
    return value is num ? value.toDouble() : 0;
  }

  int _getInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(OrderHistoryItem order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 12),
                Text(
                  'Заказ ${order.id}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Дата: ${_formatDate(order.date)}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Информация о заказе'),
                _infoRow('Номер:', order.id),
                _infoRow('Дата:', _formatDate(order.date)),
                _infoRow('Товаров:', '${order.totalItems}'),
                _infoRow('Оплата:', order.paymentMethod),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 125,
                            child: Text(
                              'Статус:',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusLabel(order.status),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Изменить статус:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: order.status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('Новый')),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Подтверждён'),
                          ),
                          DropdownMenuItem(
                            value: 'processing',
                            child: Text('Собирается'),
                          ),
                          DropdownMenuItem(
                            value: 'shipped',
                            child: Text('Отправлен'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Доставлен'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Отменён'),
                          ),
                        ],
                        onChanged: _isUpdatingStatus
                            ? null
                            : (newStatus) {
                                if (newStatus != null) {
                                  _updateOrderStatus(newStatus);
                                }
                              },
                      ),
                      if (_isUpdatingStatus) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 4),
                        const Text(
                          'Сохраняем статус...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(),
                _infoRow('Итого:', '${order.totalAmount.toStringAsFixed(2)} ₽'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Состав заказа'),

                if (order.products.isEmpty)
                  const Text('Информация о товарах отсутствует.'),

                ...order.products.map((product) {
                  final title = product['title']?.toString() ?? 'Товар';

                  final price = _getDouble(product['price']);
                  final quantity = _getInt(product['quantity']);
                  final subtotal = product['subtotal'] is num
                      ? _getDouble(product['subtotal'])
                      : price * quantity;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text('${price.toStringAsFixed(0)} ₽ × $quantity'),
                    trailing: Text(
                      '${subtotal.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Получатель и доставка'),

                _infoRow('ФИО:', order.customerName),
                _infoRow('Телефон:', order.phone),
                _infoRow('Email:', order.email),
                _infoRow('Город:', order.city),
                _infoRow('Адрес:', order.address),
                _infoRow('Индекс:', order.zipCode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о заказе'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад к заказам',
          onPressed: () => context.go('/profile/orders'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadOrder,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : _buildOrderDetails(_order!),
    );
  }
}
