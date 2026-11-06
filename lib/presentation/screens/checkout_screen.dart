import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Импорты согласно нашей новой структуре папок
import '../../domain/providers/cart_provider.dart';
import '../../data/models/order_history_item.dart';
import '../../data/repositories/order_repository.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final OrderRepository _orderRepository = OrderRepository();
  int _currentStep = 0;
  String _paymentMethod = 'При получении';
  bool _isOrderProcessing = false;

  // Global Keys для валидации форм на каждом шаге
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // Контроллеры полей
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _phoneController.text = prefs.getString('user_phone') ?? '';
      _emailController.text = prefs.getString('user_email') ?? '';

      _cityController.text = prefs.getString('user_city') ?? '';
      _addressController.text = prefs.getString('user_address') ?? '';
      _zipController.text = prefs.getString('user_zip_code') ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _zipController.dispose();

    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) return _step1Key.currentState?.validate() ?? false;
    if (_currentStep == 1) return _step2Key.currentState?.validate() ?? false;
    if (_currentStep == 2) return _step3Key.currentState?.validate() ?? false;
    return false;
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        setState(() => _currentStep += 1);
      } else {
        _processOrder();
      }
    }
  }

  void _cancelStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      context.go('/cart');
    }
  }

  Future<void> _processOrder() async {
    if (_isOrderProcessing) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Защита от оформления пустого заказа.
    if (cartProvider.cartItems.isEmpty || cartProvider.totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Корзина пуста. Добавьте товары перед оформлением заказа.',
          ),
        ),
      );

      context.go('/cart');
      return;
    }

    setState(() => _isOrderProcessing = true);

    // Создаём снимок товаров в момент оформления заказа.
    final orderProducts = cartProvider.cartItems
        .map((item) {
          final price = item.product.intPrice;
          final quantity = item.quantity;

          return {
            'id': item.product.id,
            'title': item.product.title,
            'price': price,
            'quantity': quantity,
            'subtotal': price * quantity,
            'imageUrl': item.product.imageUrl,
          };
        })
        .toList(growable: false);

    // Рассчитываем сумму и количество из того же снимка.
    final double finalAmount = orderProducts
        .fold<int>(0, (sum, item) => sum + (item['subtotal'] as int))
        .toDouble();

    final int finalItemsCount = orderProducts.fold<int>(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );

    // Имитируем обработку заказа.
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      final orderId =
          '№${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final newOrder = OrderHistoryItem(
        id: orderId,
        date: DateTime.now(),
        totalAmount: finalAmount,
        totalItems: finalItemsCount,

        // Сохраняем товары и цены на момент покупки.
        products: orderProducts,

        // Сохраняем данные покупателя и доставки.
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        zipCode: _zipController.text.trim(),
        paymentMethod: _paymentMethod,
      );

      // Сохраняем заказ через репозиторий.
      await _orderRepository.saveOrder(newOrder);
    } catch (e) {
      debugPrint('Ошибка сохранения истории заказов: $e');

      if (!mounted) return;

      setState(() => _isOrderProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить заказ. Попробуйте ещё раз.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // Удаляем только товары, вошедшие в оформленный заказ.
    final purchasedQuantities = {
      for (final item in orderProducts)
        item['id'] as String: item['quantity'] as int,
    };

    cartProvider.removePurchasedItems(purchasedQuantities);

    if (!mounted) return;

    setState(() => _isOrderProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Заказ успешно оформлен! Спасибо за покупку!'),
        backgroundColor: Colors.green,
      ),
    );

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final currentTotalAmount = cartProvider.totalAmount;
    if (cartProvider.cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление заказа')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Корзина пуста',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Добавьте товары, прежде чем оформлять заказ.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.storefront),
                  label: const Text('Перейти в каталог'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа'), centerTitle: true),
      body: _isOrderProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Создаем ваш заказ...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme
                        .copyWith(primary: Colors.deepPurple),
                  ),
                  child: Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    onStepContinue: _nextStep,
                    onStepCancel: _cancelStep,
                    controlsBuilder: (context, controls) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: controls.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                _currentStep == 2
                                    ? 'Оплатить $currentTotalAmount ₽'
                                    : 'Далее',
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: controls.onStepCancel,
                              child: Text(
                                _currentStep == 0 ? 'Назад в корзину' : 'Назад',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      // ШАГ 1: КОНТАКТЫ
                      Step(
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.editing,
                        title: const Text('Контактные данные'),
                        content: Form(
                          key: _step1Key,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'ФИО',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Введите имя'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Телефон',
                                  prefixIcon: Icon(Icons.phone),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Введите телефон'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                validator: (val) {
                                  final email = val?.trim() ?? '';

                                  if (email.isEmpty) {
                                    return 'Введите Email';
                                  }

                                  final emailPattern = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );

                                  if (!emailPattern.hasMatch(email)) {
                                    return 'Введите корректный Email';
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ШАГ 2: ДОСТАВКА
                      Step(
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : (_currentStep == 1
                                  ? StepState.editing
                                  : StepState.indexed),
                        title: const Text('Адрес доставки'),
                        content: Form(
                          key: _step2Key,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  labelText: 'Город',
                                  prefixIcon: Icon(Icons.location_city),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Укажите город'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Адрес (Улица, дом, квартира)',
                                  prefixIcon: Icon(Icons.home),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Укажите адрес доставки'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _zipController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Почтовый индекс',
                                  prefixIcon: Icon(Icons.local_post_office),
                                ),
                                validator: (val) {
                                  final zip = val?.trim() ?? '';

                                  if (zip.length < 5 ||
                                      !RegExp(r'^\d+$').hasMatch(zip)) {
                                    return 'Введите индекс: минимум 5 цифр';
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ШАГ 3: ОПЛАТА

                      Step(
                        isActive: _currentStep == 2,
                        state: _currentStep == 2
                            ? StepState.editing
                            : StepState.indexed,
                        title: const Text('Способ оплаты'),
                        content: Form(
                          key: _step3Key,
                          child: RadioGroup<String>(
                            groupValue: _paymentMethod,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _paymentMethod = value;
                                });
                              }
                            },
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RadioListTile<String>(
                                  value: 'При получении',
                                  title: Text('Оплата при получении'),
                                  subtitle: Text(
                                    'Демонстрационный способ оплаты',
                                  ),
                                ),
                                RadioListTile<String>(
                                  value: 'Онлайн (демо)',
                                  title: Text('Онлайн-оплата'),
                                  subtitle: Text(
                                    'Демонстрация без ввода данных карты',
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Платёжная система не подключена. '
                                  'Реальное списание средств не производится.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
