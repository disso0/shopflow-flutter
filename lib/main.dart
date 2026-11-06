import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/providers/cart_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/product_detail_screen.dart';
import 'presentation/screens/cart_screen.dart';
import 'presentation/screens/checkout_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/orders_screen.dart';
import 'domain/providers/favorites_provider.dart';
import 'presentation/screens/favorites_screen.dart';
import 'presentation/screens/currency_settings_screen.dart';
import 'presentation/screens/order_detail_screen.dart';

import 'package:my_first_app/data/models/product.dart';

import 'data/models/currency_settings.dart';
import 'data/repositories/product_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем сохраненную тему.
  final prefs = await SharedPreferences.getInstance();
  final isDarkModeSaved = prefs.getBool('is_dark_mode') ?? false;

  // Загружаем сохранённый курс доллара.
  await CurrencySettings.load();

  runApp(MyApp(initialDarkMode: isDarkModeSaved));
}

class MyApp extends StatefulWidget {
  final bool initialDarkMode;
  final ProductRepository? productRepository;

  const MyApp({
    super.key,
    required this.initialDarkMode,
    this.productRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  // Функция переключения темы с мгновенным сохранением в локальную память
  Future<void> _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginPage(isDarkMode: _isDarkMode, onThemeChanged: _toggleTheme),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          return HomeScreen(
            isDarkMode: _isDarkMode,
            onThemeChanged: _toggleTheme,
            productRepository: widget.productRepository,
          );
        },
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final productId = state.pathParameters['id']!;
          // Извлекаем переданный объект Product из поля extra
          final product = state.extra as Product?;

          return ProductDetailPage(
            productId: productId,
            productFromRouter: product, // Передаем его в конструктор экрана
          );
        },
      ),

      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfilePage(
          onLogout: () {
            context.go('/login');
          },
        ),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/profile/orders',
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: '/profile/orders/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;

          return OrderDetailPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/settings/currency',
        builder: (context, state) => const CurrencySettingsScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider()..loadFavorites(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Магазин на Flutter Web',

        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey.shade100,
          cardColor: Colors.white,
          colorScheme: ColorScheme.light(
            surface: Colors.grey.shade100,
            surfaceContainer: Colors.white,
          ),
        ),

        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF121212),
            surfaceContainer: Color(0xFF1E1E1E),
          ),
        ),

        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
