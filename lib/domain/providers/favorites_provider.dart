import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/product.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _storageKey = 'favorite_products';

  final Map<String, Product> _favorites = {};

  bool _isLoaded = false;
  bool _isDisposed = false;

  Future<void>? _loadFuture;
  Future<void> _saveQueue = Future<void>.value();

  List<Product> get favorites => _favorites.values.toList();

  bool get isLoaded => _isLoaded;

  bool isFavorite(String productId) {
    return _favorites.containsKey(productId);
  }

  Future<void> loadFavorites() {
    if (_isLoaded) return Future<void>.value();

    return _loadFuture ??= _loadFavoritesInternal();
  }

  Future<void> _loadFavoritesInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_storageKey);

      if (savedData != null) {
        final List<dynamic> decoded = jsonDecode(savedData);

        for (final item in decoded) {
          final product = Product.fromMap(
            Map<String, dynamic>.from(item as Map),
          );
          _favorites[product.id] = product;
        }
      }
    } catch (e) {
      debugPrint('Не удалось загрузить избранное: $e');
    } finally {
      _isLoaded = true;

      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> toggleFavorite(Product product) async {
    if (!_isLoaded || _isDisposed) return;

    if (isFavorite(product.id)) {
      _favorites.remove(product.id);
    } else {
      _favorites[product.id] = product;
    }

    notifyListeners();

    await _saveFavorites();
  }

  Future<void> _saveFavorites() {
    final data = jsonEncode(
      _favorites.values.map((product) => product.toMap()).toList(),
    );

    _saveQueue = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, data);
      } catch (e) {
        debugPrint('Не удалось сохранить избранное: $e');
      }
    });

    return _saveQueue;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
