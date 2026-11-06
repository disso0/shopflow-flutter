import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/providers/cart_provider.dart';

class ProductDetailPage extends StatelessWidget {
  final String productId;
  final Product?
  productFromRouter; // ДОБАВЛЯЕМ ПАРАМЕТР: Принимаем объект из роутера

  const ProductDetailPage({
    super.key,
    required this.productId,
    this.productFromRouter, // Регистрируем в конструкторе
  });

  Widget _buildFeature(IconData icon, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: isDark ? Colors.lightBlueAccent : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Умный поиск: если объект передан через роутер — берем его.
    // Если его нет — ищем в локальном кэше моков.
    final Product product =
        productFromRouter ??
        ProductRepository.mockProducts.firstWhere(
          (p) => p.id == productId,
          orElse: () => const Product(
            id: '',
            title: 'Товар не найден',
            subtitle: '',
            intPrice: 0,
            category: '',
            icon: Icons.error_outline,
            iconColor: Colors.grey,
            detailedDescription:
                'К сожалению, запрашиваемый товар не существует.',
          ),
        );

    // Если товар не найден и в кэше — показываем заглушку ошибки
    if (product.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(product.title),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Text(
              'Товар с ID "$productId" не найден',
              style: const TextStyle(fontSize: 18, color: Colors.red),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(product.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                Container(
                  width: 280,
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              product.icon,
                              size: 100,
                              color: product.iconColor,
                            );
                          },
                        )
                      : Icon(product.icon, size: 100, color: product.iconColor),
                ),

                const SizedBox(height: 24),
                Text(
                  product.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 15,
                            color: Colors.green,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'В наличии',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Описание товара',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.detailedDescription,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Особенности',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (product.id == 'mech_keyboard') ...[
                      _buildFeature(
                        Icons.keyboard,
                        'Механические переключатели Red',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.bolt,
                        'Быстрый отклик клавиш',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.palette_outlined,
                        'Настраиваемая RGB-подсветка',
                        isDark,
                      ),
                    ] else if (product.id == 'headphones_pro') ...[
                      _buildFeature(
                        Icons.headphones,
                        'Активное шумоподавление (ANC)',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.graphic_eq,
                        'Звук высокой чёткости',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.wifi,
                        'Беспроводное подключение',
                        isDark,
                      ),
                    ] else if (product.id == 'powerbank_20k') ...[
                      _buildFeature(
                        Icons.battery_charging_full,
                        'Ёмкость 20 000 мА·ч',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.bolt,
                        'Быстрая зарядка до 22,5 Вт',
                        isDark,
                      ),
                      _buildFeature(Icons.usb, 'Три выходных порта', isDark),
                    ] else if (product.id == 'ergonomic_mouse') ...[
                      _buildFeature(Icons.mouse, 'Эргономичная форма', isDark),
                      _buildFeature(
                        Icons.wifi,
                        'Беспроводное подключение',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.touch_app,
                        'Удобное управление',
                        isDark,
                      ),
                    ] else if (product.id == 'sport_watch_x') ...[
                      _buildFeature(
                        Icons.favorite_border,
                        'Мониторинг пульса',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.nights_stay_outlined,
                        'Отслеживание сна',
                        isDark,
                      ),
                      _buildFeature(
                        Icons.directions_run,
                        '20 спортивных режимов',
                        isDark,
                      ),
                    ] else ...[
                      _buildFeature(
                        Icons.check_circle_outline,
                        'Практичный дизайн',
                        isDark,
                      ),
                    ],
                  ],
                ),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      cartProvider.addToCart(product);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.title} добавлен в корзину!'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 22),
                    label: const Text(
                      'Добавить в корзину',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF2563EB)
                          .withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
