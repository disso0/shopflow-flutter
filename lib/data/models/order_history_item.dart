class OrderHistoryItem {
  final String id;
  final DateTime date;
  final double totalAmount;
  final int totalItems;

  // Снимок товаров на момент оформления заказа.
  final List<Map<String, dynamic>> products;

  // Данные доставки.
  final String customerName;
  final String phone;
  final String email;
  final String city;
  final String address;
  final String zipCode;

  // Способ оплаты.
  final String paymentMethod;
  // Статус заказа.
  final String status;

  OrderHistoryItem({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.totalItems,
    this.products = const [],
    this.customerName = '',
    this.phone = '',
    this.email = '',
    this.city = '',
    this.address = '',
    this.zipCode = '',
    this.paymentMethod = 'При получении',
    this.status = 'new',
  });

  factory OrderHistoryItem.fromMap(Map<String, dynamic> map) {
    return OrderHistoryItem(
      id: map['id']?.toString() ?? '',
      date:
          DateTime.tryParse(map['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalItems: (map['totalItems'] as num?)?.toInt() ?? 0,
      products: (map['products'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      customerName: map['customerName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      zipCode: map['zipCode']?.toString() ?? '',
      paymentMethod: map['paymentMethod']?.toString() ?? 'При получении',
      status: map['status']?.toString() ?? 'new',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'products': products,
      'customerName': customerName,
      'phone': phone,
      'email': email,
      'city': city,
      'address': address,
      'zipCode': zipCode,
      'paymentMethod': paymentMethod,
      'status': status,
    };
  }
}
