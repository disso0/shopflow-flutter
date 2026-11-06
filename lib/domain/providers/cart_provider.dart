import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/product.dart';
import '../../data/models/cart_item.dart';

class CartProvider with ChangeNotifier {
  static const String _storageKey = 'shopping_cart';

  final List<CartItem> _cartItems = [];

  late final Future<void> _initialization;
  Future<void> _saveQueue = Future<void>.value();

  bool _isDisposed = false;
  void _checkNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'CartProvider уже уничтожен. Нельзя использовать его после dispose().',
      );
    }
  }

  CartProvider() {
    _initialization = _loadCartFromStorage();
  }

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);

  bool get isInitialized => _isInitialized;
  bool _isInitialized = false;

  int get totalAmount {
    return _cartItems.fold(
      0,
      (sum, item) => sum + item.product.intPrice * item.quantity,
    );
  }

  int get totalItemsCount {
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> waitUntilInitialized() => _initialization;

  void addToCart(Product product) {
    _checkNotDisposed();
    final index = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index >= 0) {
      _cartItems[index].quantity++;
    } else {
      _cartItems.add(CartItem(product: product, quantity: 1));
    }

    _onCartChanged();
  }

  /// Обновляет цены товаров в корзине, сохраняя их количество.
  void updateProductPrices(List<Product> updatedProducts) {
    _checkNotDisposed();
    // Создаём быстрый поиск товаров по ID.
    final productsById = {
      for (final product in updatedProducts) product.id: product,
    };

    var hasChanges = false;

    for (var i = 0; i < _cartItems.length; i++) {
      final cartItem = _cartItems[i];

      // Ищем обновлённый товар по ID.
      final updatedProduct = productsById[cartItem.product.id];

      if (updatedProduct != null &&
          updatedProduct.intPrice != cartItem.product.intPrice) {
        _cartItems[i] = CartItem(
          product: updatedProduct,
          quantity: cartItem.quantity,
        );

        hasChanges = true;
      }
    }

    if (hasChanges) {
      _onCartChanged();
    }
  }

  void decrementQuantity(Product product) {
    _checkNotDisposed();
    final index = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index < 0) return;

    if (_cartItems[index].quantity > 1) {
      _cartItems[index].quantity--;
    } else {
      _cartItems.removeAt(index);
    }

    _onCartChanged();
  }

  void removeFromCart(Product product) {
    _checkNotDisposed();
    _cartItems.removeWhere((item) => item.product.id == product.id);

    _onCartChanged();
  }

  void clearCart() {
    _checkNotDisposed();
    _cartItems.clear();
    _onCartChanged();
  }

  /// Удаляет только товары и количество, вошедшие в оформленный заказ.
  void removePurchasedItems(Map<String, int> purchasedQuantities) {
    _checkNotDisposed();

    var hasChanges = false;

    for (final entry in purchasedQuantities.entries) {
      final index = _cartItems.indexWhere(
        (item) => item.product.id == entry.key,
      );

      if (index == -1) continue;

      final purchasedQuantity = entry.value;

      if (purchasedQuantity <= 0) continue;

      final remainingQuantity = _cartItems[index].quantity - purchasedQuantity;

      if (remainingQuantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = remainingQuantity;
      }

      hasChanges = true;
    }

    if (hasChanges) {
      _onCartChanged();
    }
  }

  void _onCartChanged() {
    _checkNotDisposed();

    notifyListeners();

    unawaited(
      _saveCartToStorage().catchError((Object error) {
        debugPrint('Ошибка при автоматическом сохранении корзины: $error');
      }),
    );
  }

  Future<void> waitUntilSaved() => _saveQueue;
  Future<void> _loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString(_storageKey);

      if (cartString != null) {
        final List<dynamic> decodedList =
            jsonDecode(cartString) as List<dynamic>;

        final loadedItems = decodedList
            .map(
              (item) =>
                  CartItem.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        // Не затираем изменения, сделанные во время загрузки.
        for (final loadedItem in loadedItems) {
          final index = _cartItems.indexWhere(
            (item) => item.product.id == loadedItem.product.id,
          );

          if (index == -1) {
            _cartItems.add(loadedItem);
          } else {
            _cartItems[index].quantity += loadedItem.quantity;
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке корзины: $e');
    } finally {
      _isInitialized = true;

      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _saveCartToStorage() {
    // Создаём снимок текущего состояния корзины.
    final snapshot = jsonEncode(
      _cartItems.map((item) => item.toMap()).toList(),
    );

    // Добавляем операцию в очередь сохранения.
    final saveOperation = _saveQueue.then((_) async {
      await _initialization;

      final prefs = await SharedPreferences.getInstance();

      final saved = await prefs.setString(_storageKey, snapshot);

      if (!saved) {
        throw Exception('Не удалось сохранить корзину в SharedPreferences');
      }
    });

    // Сохраняем операцию в очереди без перехвата ошибки.
    // Поэтому waitUntilSaved() сможет получить исключение.
    _saveQueue = saveOperation;

    return saveOperation;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
