import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/order_history_item.dart';
import '../../data/repositories/order_repository.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrderRepository _orderRepository = OrderRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<OrderHistoryItem> _orders = [];

  final Set<String> _updatingOrderIds = {};
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderRepository.getOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки истории заказов: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Не удалось загрузить историю заказов.';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    if (_updatingOrderIds.contains(orderId)) return;

    final orderIndex = _orders.indexWhere((order) => order.id == orderId);

    if (orderIndex == -1) return;

    if (_orders[orderIndex].status == newStatus) return;

    setState(() {
      _updatingOrderIds.add(orderId);
    });

    try {
      final updated = await _orderRepository.updateOrderStatus(
        orderId,
        newStatus,
      );

      if (!mounted) return;

      if (!updated) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Заказ не найден.')));
        return;
      }

      // Загружаем обновлённую историю.
      final orders = await _orderRepository.getOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус заказа обновлён.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Ошибка обновления статуса заказа: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось изменить статус заказа.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(orderId);
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

  List<OrderHistoryItem> get _filteredOrders {
    return _orders.where((order) {
      // Проверяем выбранный статус.
      final matchesStatus =
          _selectedStatus == 'all' || order.status == _selectedStatus;

      // Проверяем поисковый запрос.
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          order.id.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.phone.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  double _getDouble(dynamic value) {
    return value is num ? value.toDouble() : 0;
  }

  int _getInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад в профиль',
          onPressed: () => context.go('/profile'),
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
                      onPressed: _loadOrders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : _orders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 72,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Заказов пока нет',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Оформленные заказы будут отображаться здесь.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Фильтр заказов
                // Поиск заказов
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Поиск заказов',
                      hintText: 'Номер, имя или телефон',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Очистить поиск',
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Фильтр заказов',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Все заказы')),
                      DropdownMenuItem(value: 'new', child: Text('Новые')),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Подтверждённые'),
                      ),
                      DropdownMenuItem(
                        value: 'processing',
                        child: Text('В обработке'),
                      ),
                      DropdownMenuItem(
                        value: 'shipped',
                        child: Text('Отправленные'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Доставленные'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Отменённые'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                ),

                // Список заказов
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? const Center(
                          child: Text('Заказов с таким статусом нет.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];

                            return Card(
                              child: ExpansionTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.receipt_long),
                                ),
                                title: Text('Заказ ${order.id}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Дата: ${_formatDate(order.date)}'),
                                    Text(
                                      'Количество товаров: ${order.totalItems}',
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusLabel(order.status),
                                          style: TextStyle(
                                            color: _getStatusColor(
                                              order.status,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${order.totalAmount.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                children: [
                                  const Divider(),
                                  // Управление статусом заказа.
                                  Builder(
                                    builder: (context) {
                                      final isUpdating = _updatingOrderIds
                                          .contains(order.id);

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Статус заказа',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                const [
                                                  'new',
                                                  'confirmed',
                                                  'processing',
                                                  'shipped',
                                                  'delivered',
                                                  'cancelled',
                                                ].contains(order.status)
                                                ? order.status
                                                : 'new',
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'new',
                                                child: Text('Новый'),
                                              ),
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
                                            onChanged: isUpdating
                                                ? null
                                                : (newStatus) {
                                                    if (newStatus != null) {
                                                      _updateOrderStatus(
                                                        order.id,
                                                        newStatus,
                                                      );
                                                    }
                                                  },
                                          ),
                                          if (isUpdating) ...[
                                            const SizedBox(height: 8),
                                            const LinearProgressIndicator(),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Сохраняем статус...',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Способ оплаты.
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.payment,
                                          size: 20,
                                          color: Colors.deepPurple,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Способ оплаты: ${order.paymentMethod}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Состав заказа',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  ...order.products.map((product) {
                                    final title =
                                        product['title']?.toString() ?? 'Товар';

                                    final price = _getDouble(product['price']);
                                    final quantity = _getInt(
                                      product['quantity'],
                                    );

                                    final subtotal = _getDouble(
                                      product['subtotal'],
                                    );

                                    final actualSubtotal =
                                        product['subtotal'] is num
                                        ? subtotal
                                        : price * quantity;

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(title),
                                      subtitle: Text(
                                        '${price.toStringAsFixed(0)} ₽ × $quantity',
                                      ),
                                      trailing: Text(
                                        '${actualSubtotal.toStringAsFixed(0)} ₽',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }),

                                  if (order.customerName.isNotEmpty) ...[
                                    const Divider(),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Получатель и доставка',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Получатель: ${order.customerName}',
                                      ),
                                    ),

                                    if (order.phone.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Телефон: ${order.phone}'),
                                      ),

                                    if (order.email.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Email: ${order.email}'),
                                      ),

                                    if (order.city.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Город: ${order.city}'),
                                      ),

                                    if (order.address.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Адрес: ${order.address}'),
                                      ),

                                    if (order.zipCode.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Индекс: ${order.zipCode}'),
                                      ),
                                    const SizedBox(height: 16),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.go(
                                            '/profile/orders/${Uri.encodeComponent(order.id)}',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        label: const Text('Подробнее'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
