import 'package:flutter/material.dart';

import 'currency_settings.dart';
import 'product_translations.dart';

class Product {
  // Добавляем обязательное уникальное поле ID для поддержки GoRouter и Deep Linking
  final String id;
  final String title;
  final String subtitle;
  final int intPrice;

  /// Форматированная цена для отображения в интерфейсе.
  String get price {
    final formatted = intPrice.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ' ',
    );

    return '$formatted ₽';
  }

  final String category;
  final IconData icon;
  final Color iconColor;
  final String detailedDescription;
  final String? imageUrl;

  const Product({
    required this.id, // Регистрируем id в конструкторе
    required this.title,
    required this.subtitle,
    required this.intPrice,
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.detailedDescription,
    this.imageUrl,
  });

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'headphones':
        return Icons.headphones;
      case 'watch':
        return Icons.watch;
      case 'keyboard':
        return Icons.keyboard;
      case 'battery_charging_full':
        return Icons.battery_charging_full;
      case 'mouse':
        return Icons.mouse;
      default:
        return Icons.shopping_bag;
    }
  }

  String _getStringFromIcon() {
    if (icon == Icons.headphones) return 'headphones';
    if (icon == Icons.watch) return 'watch';
    if (icon == Icons.keyboard) return 'keyboard';
    if (icon == Icons.battery_charging_full) return 'battery_charging_full';
    if (icon == Icons.mouse) return 'mouse';
    return 'shopping_bag';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Сохраняем id в мапу
      'title': title,
      'subtitle': subtitle,
      'intPrice': intPrice,
      'category': category,
      'iconName': _getStringFromIcon(),
      'iconColorValue': iconColor
          .toARGB32(), // Ваше современное решение сохранено
      'detailedDescription': detailedDescription,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id:
          map['id'] as String? ??
          '', // Извлекаем id, страхуясь от null через оператор ??
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      intPrice: map['intPrice'] as int,
      category: map['category'] as String,
      icon: _getIconFromString(map['iconName'] as String),
      iconColor: Color(map['iconColorValue'] as int),
      detailedDescription: map['detailedDescription'] as String,
      imageUrl: map['imageUrl'] as String?,
    );
  }
  // Добавьте этот метод внутрь класса Product для парсинга данных из реального API
  factory Product.fromRealApiJson(Map<String, dynamic> json) {
    // Получаем цену товара в долларах из API.
    final double rawPrice = (json['price'] as num).toDouble();

    // Переводим доллары в рубли по заданному курсу.
    final int calculatedPrice = (rawPrice * CurrencySettings.usdToRubRate)
        .round();

    // Определяем иконку на основе категории, приходящей с сервера
    final String serverCategory = json['category'] as String? ?? 'other';

    String displayCategory;
    IconData itemIcon = Icons.shopping_bag;
    Color itemColor = Colors.blueGrey;

    switch (serverCategory.toLowerCase()) {
      case 'electronics':
        displayCategory = 'Электроника';
        itemIcon = Icons.headphones;
        itemColor = Colors.deepPurple;
        break;

      case 'jewelery':
        displayCategory = 'Украшения';
        itemIcon = Icons.watch;
        itemColor = Colors.orange;
        break;

      case "men's clothing":
      case "women's clothing":
        displayCategory = 'Одежда';
        itemIcon = Icons.shopping_bag;
        itemColor = Colors.blueGrey;
        break;

      default:
        displayCategory = 'Другое';
        break;
    }
    final int productId = (json['id'] as num).toInt();

    final translation = ProductTranslations.products[productId];

    final String translatedTitle =
        translation?['title'] ?? (json['title'] as String? ?? '');

    final String translatedDescription =
        translation?['description'] ?? (json['description'] as String? ?? '');

    return Product(
      id: json['id'].toString(), // Превращаем int с сервера в ваш String id
      title: translatedTitle,
      subtitle: displayCategory,

      intPrice: calculatedPrice,
      category: displayCategory,
      icon: itemIcon,
      iconColor: itemColor,
      detailedDescription: translatedDescription,
      imageUrl: json['image'] as String?,
    );
  }
}
