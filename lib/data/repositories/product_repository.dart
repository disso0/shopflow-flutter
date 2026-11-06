import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:my_first_app/data/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_app/data/models/product_load_result.dart';

class ProductRepository {
  final http.Client _client;

  ProductRepository({http.Client? client}) : _client = client ?? http.Client();
  Future<ProductLoadResult> getProducts() async {
    const cacheKey = 'cached_products';
    const cacheDateKey = 'cached_products_date';

    // 1. Сначала быстро читаем локальный кэш.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      final cachedDate = prefs.getString(cacheDateKey);

      if (cachedJson != null) {
        final decodedCache = jsonDecode(cachedJson);

        if (decodedCache is List && decodedCache.isNotEmpty) {
          final cachedProducts = decodedCache.map((item) {
            return Product.fromMap(Map<String, dynamic>.from(item as Map));
          }).toList();

          // Возвращаем сохранённые товары без ожидания API.
          return ProductLoadResult(
            products: cachedProducts,
            source: ProductDataSource.cache,
            lastUpdated: cachedDate == null
                ? null
                : DateTime.tryParse(cachedDate),
          );
        }
      }
    } catch (cacheError) {
      debugPrint('Не удалось прочитать кэш товаров: $cacheError');
    }

    // 2. Если кэша нет, запрашиваем API.
    try {
      final url = Uri.parse('https://fakestoreapi.com/products');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки товаров: ${response.statusCode}');
      }

      final decodedData = jsonDecode(response.body);

      if (decodedData is! List || decodedData.isEmpty) {
        throw const FormatException(
          'API вернул пустой или некорректный список товаров',
        );
      }

      final products = decodedData.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Некорректный формат товара в ответе API',
          );
        }

        return Product.fromRealApiJson(Map<String, dynamic>.from(item));
      }).toList();

      final now = DateTime.now();

      // Ошибка сохранения кэша не мешает показать товары из API.
      try {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          cacheKey,
          jsonEncode(products.map((p) => p.toMap()).toList()),
        );

        await prefs.setString(cacheDateKey, now.toIso8601String());
      } catch (cacheSaveError) {
        debugPrint('Не удалось сохранить кэш товаров: $cacheSaveError');
      }

      return ProductLoadResult(
        products: products,
        source: ProductDataSource.api,
        lastUpdated: now,
      );
    } catch (e) {
      debugPrint('Не удалось загрузить товары из API: $e');

      // 3. Если API недоступен, показываем демоданные.
      return ProductLoadResult(
        products: mockProducts,
        source: ProductDataSource.demo,
      );
    }
  }

  Future<ProductLoadResult?> refreshProductsFromApi() async {
    const cacheKey = 'cached_products';
    const cacheDateKey = 'cached_products_date';

    try {
      final url = Uri.parse('https://fakestoreapi.com/products');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки товаров: ${response.statusCode}');
      }

      final decodedData = jsonDecode(response.body);

      if (decodedData is! List || decodedData.isEmpty) {
        throw const FormatException(
          'API вернул пустой или некорректный список товаров',
        );
      }

      final products = decodedData.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Некорректный формат товара в ответе API',
          );
        }

        return Product.fromRealApiJson(Map<String, dynamic>.from(item));
      }).toList();

      final now = DateTime.now();

      try {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          cacheKey,
          jsonEncode(products.map((p) => p.toMap()).toList()),
        );

        await prefs.setString(cacheDateKey, now.toIso8601String());
      } catch (cacheSaveError) {
        debugPrint('Не удалось сохранить обновлённый кэш: $cacheSaveError');
      }

      return ProductLoadResult(
        products: products,
        source: ProductDataSource.api,
        lastUpdated: now,
      );
    } catch (e) {
      debugPrint('Не удалось обновить каталог через API: $e');
      return null;
    }
  }

  static const List<Product> mockProducts = [
    Product(
      id: 'headphones_pro',
      title: 'Беспроводные наушники PRO',
      subtitle: 'Звук высокой четкости и active-шумоподавление.',
      intPrice: 12500,
      category: 'Электроника',
      icon: Icons.headphones,
      iconColor: Colors.deepPurple,
      detailedDescription: 'Премиальные беспроводные наушники с системой активного шумоподавления (ANC).',
      imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=80',
    ),
    Product(
      id: 'sport_watch_x',
      title: 'Смарт-часы Sport X',
      subtitle: 'Мониторинг пульса, сна и 20 спортивных режимов.',
      intPrice: 8900,
      category: 'Гаджеты',
      icon: Icons.watch,
      iconColor: Colors.orange,
      detailedDescription: 'Умные часы для active образа жизни.',
      imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=80',
    ),
    Product(
      id: 'mech_keyboard',
      title: 'Механическая клавиатура',
      subtitle: 'RGB-подсветка, тихие переключатели Red Switched.',
      intPrice: 5400,
      category: 'Аксессуары',
      icon: Icons.keyboard,
      iconColor: Colors.blueGrey,
      detailedDescription:
          'Компактная механическая клавиатура с настраиваемой RGB-подсветкой.',
      imageUrl: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=80',
    ),
    Product(
      id: 'powerbank_20k',
      title: 'Внешний аккумулятор 20k',
      subtitle: 'Быстрая зарядка на 22.5W, три выходных порта.',
      intPrice: 2900,
      category: 'Электроника',
      icon: Icons.battery_charging_full,
      iconColor: Colors.green,
      detailedDescription: 'Портативная батарея емкостью 20 000 мАч.',
      imageUrl: 'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=500&auto=format&fit=crop&q=80',
    ),
    Product(
      id: 'ergonomic_mouse',
      title: 'Эргономичная мышь',
      subtitle: 'Беспроводное подключение, анатомическая форма под руку.',
      intPrice: 4200,
      category: 'Аксессуары',
      icon: Icons.mouse,
      iconColor: Colors.blue,
      detailedDescription:
          'Беспроводная мышь с уникальной анатомической формой.',
      imageUrl: 'https://images.unsplash.com/photo-1527814050087-3793815479db?w=500&auto=format&fit=crop&q=80',
    ),
  ];
}
