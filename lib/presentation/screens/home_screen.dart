import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/providers/cart_provider.dart';

import 'package:my_first_app/data/models/product.dart';
import 'package:my_first_app/data/repositories/product_repository.dart'; // Подключаем репозиторий сетей
import 'package:my_first_app/data/models/product_load_result.dart';

import '../widgets/shimmer_loading.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged;
  final ProductRepository? productRepository;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.productRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final ProductRepository _productRepository =
      widget.productRepository ?? ProductRepository();

  // ignore: prefer_final_fields
  String _searchQuery = '';
  // ignore: prefer_final_fields
  String _selectedCategory = 'Все';
  // ignore: prefer_final_fields
  String _sortType = 'none';
  final TextEditingController _minPriceController = TextEditingController();

  final TextEditingController _maxPriceController = TextEditingController();

  int? _minPrice;
  int? _maxPrice;
  bool _isLoading = true;
  bool _isRefreshingCatalog = false;
  String? _loadError;
  ProductDataSource? _productDataSource;
  DateTime? _productsLastUpdated;

  // Динамический список для загруженных из бэкенда товаров
  List<Product> _serverProducts = [];

  final PageController _pageController = PageController();
  Timer? _bannerTimer;
  Timer? _searchDebounce;
  int _currentBannerPage = 0;

  late AnimationController _cartAnimationController;
  late Animation<double> _cartScaleAnimation;

  // Обновленный список категорий в соответствии с FakeStoreAPI
  final List<String> categories = [
    'Все',
    'Электроника',
    'Украшения',
    'Аксессуары',
    'Одежда',
  ];

  final List<Map<String, dynamic>> banners = [
    {
      'title': 'Распродажа Электроники',
      'subtitle': 'На все наушники PRO и аксессуары',
      'discount': '-20%',
      'colors': <Color>[Colors.blue.shade700, Colors.deepPurple.shade600],
    },
    {
      'title': 'Спорт и Стиль',
      'subtitle': 'Умные часы Sport X с влагозащитой',
      'discount': '-15%',
      'colors': <Color>[Colors.orange.shade700, Colors.red.shade600],
    },
    {
      'title': 'Прокачай рабочее место',
      'subtitle': 'Механические клавиатуры и мыши',
      'discount': '-30%',
      'colors': <Color>[Colors.teal.shade700, Colors.green.shade600],
    },
  ];
  String _formatProductsDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _startBannerAutoPlay();
    _loadBackendData(); // Вызываем асинхронную загрузку из API

    _cartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _cartScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _cartAnimationController, curve: Curves.easeOut),
    );
  }

  // Асинхронный метод получения товаров из репозитория

  Future<void> _loadBackendData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Сначала получаем кэш или демоданные.
      final result = await _productRepository.getProducts();

      if (!mounted) return;

      context.read<CartProvider>().updateProductPrices(result.products);

      setState(() {
        _serverProducts = result.products;
        _isLoading = false;
        _loadError = null;
        _productDataSource = result.source;
        _productsLastUpdated = result.lastUpdated;
      });

      // Затем обновляем каталог через API в фоне.
      final freshResult = await _productRepository.refreshProductsFromApi();

      if (!mounted) return;

      if (freshResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет соединения. Показаны сохранённые товары.'),
          ),
        );
        return;
      }

      context.read<CartProvider>().updateProductPrices(freshResult.products);

      setState(() {
        _serverProducts = freshResult.products;
        _productDataSource = freshResult.source;
        _productsLastUpdated = freshResult.lastUpdated;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Не удалось загрузить товары.';
      });

      debugPrint('Ошибка загрузки каталога: $e');
    }
  }

  void _startBannerAutoPlay() {
    _stopBannerAutoPlay();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _currentBannerPage = (_currentBannerPage + 1) % banners.length;
        _pageController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
  }

  // Логика фильтрации теперь работает со списком _serverProducts
  List<Product> get _filteredProducts {
    final filtered = _serverProducts.where((product) {
      final matchesCategory =
          _selectedCategory == 'Все' || product.category == _selectedCategory;
      final titleLower = product.title.toLowerCase();
      final subtitleLower = product.subtitle.toLowerCase();
      final categoryLower = product.category.toLowerCase();
      final matchesMinPrice =
          _minPrice == null || product.intPrice >= _minPrice!;

      final matchesMaxPrice =
          _maxPrice == null || product.intPrice <= _maxPrice!;
      final descriptionLower = product.detailedDescription.toLowerCase();
      final searchLower = _searchQuery.trim().toLowerCase();

      final matchesSearch =
          titleLower.contains(searchLower) ||
          subtitleLower.contains(searchLower) ||
          categoryLower.contains(searchLower) ||
          descriptionLower.contains(searchLower);
      return matchesCategory &&
          matchesSearch &&
          matchesMinPrice &&
          matchesMaxPrice;
    }).toList();

    if (_sortType == 'lowToHigh') {
      filtered.sort((a, b) => a.intPrice.compareTo(b.intPrice));
    } else if (_sortType == 'highToLow') {
      filtered.sort((a, b) => b.intPrice.compareTo(a.intPrice));
    }

    return filtered;
  }

  void _addProductToCart(CartProvider cartProvider, Product product) {
    cartProvider.addToCart(product);

    _cartAnimationController.forward().then((_) {
      _cartAnimationController.reverse();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.title} добавлен в корзину!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMobileFilters() {
    String selectedSort = _sortType;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Фильтры',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Сортировка',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedSort,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('По умолчанию'),
                        ),
                        DropdownMenuItem(
                          value: 'lowToHigh',
                          child: Text('Сначала дешевле'),
                        ),
                        DropdownMenuItem(
                          value: 'highToLow',
                          child: Text('Сначала дороже'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setSheetState(() {
                          selectedSort = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Цена товара, ₽',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'От',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'До',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    FilledButton(
                      onPressed: () {
                        final minText = _minPriceController.text.trim();
                        final maxText = _maxPriceController.text.trim();

                        final minPrice = minText.isEmpty
                            ? null
                            : int.tryParse(minText);

                        final maxPrice = maxText.isEmpty
                            ? null
                            : int.tryParse(maxText);

                        String? error;

                        if ((minText.isNotEmpty && minPrice == null) ||
                            (maxText.isNotEmpty && maxPrice == null)) {
                          error = 'Введите корректную цену.';
                        } else if ((minPrice != null && minPrice < 0) ||
                            (maxPrice != null && maxPrice < 0)) {
                          error = 'Цена не может быть отрицательной.';
                        } else if (minPrice != null &&
                            maxPrice != null &&
                            minPrice > maxPrice) {
                          error = 'Минимальная цена не может быть больше максимальной.';
                        }

                        if (error != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }

                        setState(() {
                          _sortType = selectedSort;
                          _minPrice = minPrice;
                          _maxPrice = maxPrice;
                        });

                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Применить фильтры'),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton(
                      onPressed: () {
                        _minPriceController.clear();
                        _maxPriceController.clear();

                        setState(() {
                          _minPrice = null;
                          _maxPrice = null;
                          _sortType = 'none';
                        });

                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Сбросить фильтры'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _pageController.dispose();
    _stopBannerAutoPlay();
    _cartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredProducts;
    final cartProvider = Provider.of<CartProvider>(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isViewportReady = screenWidth >= 200;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        actionsPadding: EdgeInsets.zero,
        title: isViewportReady
            ? Text(
                isMobile ? 'Каталог' : 'Каталог товаров',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        actions: isViewportReady
            ? [
                if (isMobile) ...[
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.shopping_cart),
                    tooltip: 'Корзина',
                    onPressed: () => context.go('/cart'),
                  ),

                  PopupMenuButton<String>(
                    constraints: const BoxConstraints(minWidth: 40),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.menu),
                    tooltip: 'Меню',
                    onSelected: (value) async {
                      switch (value) {
                        case 'profile':
                          context.go('/profile');
                          break;
                        case 'favorites':
                          context.go('/favorites');
                          break;
                        case 'currency':
                          await context.push('/settings/currency');
                          if (!mounted) return;
                          await _loadBackendData();
                          break;
                        case 'theme':
                          widget.onThemeChanged();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'profile',
                        child: Text('Личный кабинет'),
                      ),
                      PopupMenuItem(
                        value: 'favorites',
                        child: Text('Избранное'),
                      ),
                      PopupMenuItem(
                        value: 'currency',
                        child: Text('Настройка валюты'),
                      ),
                      PopupMenuItem(
                        value: 'theme',
                        child: Text('Сменить тему'),
                      ),
                    ],
                  ),
                ] else ...[
                  // Настройка валюты
                  IconButton(
                    icon: const Icon(Icons.currency_exchange),
                    tooltip: 'Настроить курс доллара',
                    onPressed: () async {
                      await context.push('/settings/currency');

                      if (!mounted) return;

                      await _loadBackendData();
                    },
                  ),

                  // Профиль
                  IconButton(
                    icon: const Icon(Icons.person),
                    tooltip: 'Личный кабинет',
                    onPressed: () => context.go('/profile'),
                  ),

                  // Избранное
                  IconButton(
                    icon: const Icon(Icons.favorite),
                    tooltip: 'Избранное',
                    onPressed: () => context.go('/favorites'),
                  ),

                  // Тема
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    tooltip: 'Сменить тему',
                    onPressed: widget.onThemeChanged,
                  ),

                  // Корзина
                  ScaleTransition(
                    scale: _cartScaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart),
                          tooltip: 'Корзина',
                          onPressed: () => context.go('/cart'),
                        ),
                        if (cartProvider.cartItems.isNotEmpty)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${cartProvider.cartItems.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ]
            : [],
      ),

      body: _isLoading
          ? LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                final columns = width >= 1400
                    ? 5
                    : width >= 1100
                    ? 4
                    : width >= 700
                    ? 3
                    : width >= 400
                    ? 2
                    : 1;

                return ShimmerCatalogPlaceholder(
                  isMobile: columns == 1,
                  columns: columns,
                );
              },
            )
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить товары',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadBackendData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_productDataSource != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(switch (_productDataSource!) {
                        ProductDataSource.api =>
                          'Каталог обновлён${_productsLastUpdated != null ? ' · ${_formatProductsDate(_productsLastUpdated!)}' : ''}',
                        ProductDataSource.cache =>
                          'Офлайн-режим · сохранённые товары${_productsLastUpdated != null ? ' · ${_formatProductsDate(_productsLastUpdated!)}' : ''}',
                        ProductDataSource.demo => 'Демонстрационные товары',
                      }, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchDebounce?.cancel();

                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          if (!mounted) return;

                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск товаров...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Очистить поиск',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).width < 600 ? 125 : 150,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: banners.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentBannerPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final banner = banners[index];
                        final colors = banner['colors'] as List<Color>;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: EdgeInsets.all(
                            MediaQuery.sizeOf(context).width < 600 ? 14 : 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      banner['title'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            MediaQuery.sizeOf(context).width <
                                                600
                                            ? 18
                                            : 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      banner['subtitle'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  banner['discount'] as String,
                                  style: TextStyle(
                                    color: colors.first,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        final labels = {
                          'Все': 'Все товары',
                          'Электроника': 'Электроника',
                          'Украшения': 'Украшения',
                          'Аксессуары': 'Аксессуары',
                          'Одежда': 'Одежда',
                        };
                        final isSelected = _selectedCategory == category;

                        return ChoiceChip(
                          label: Text(labels[category] ?? category),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    if (isMobile) {
                      final hasActiveFilters =
                          _minPrice != null ||
                          _maxPrice != null ||
                          _sortType != 'none';

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showMobileFilters,
                              icon: const Icon(Icons.tune),
                              label: Text(
                                hasActiveFilters ? 'Фильтры •' : 'Фильтры',
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Найдено: ${filteredList.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    // На больших экранах оставляем фильтры открытыми.
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('Сортировка:'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _sortType,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'none',
                                      child: Text('По умолчанию'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'lowToHigh',
                                      child: Text('Сначала дешевле'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'highToLow',
                                      child: Text('Сначала дороже'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setState(() {
                                      _sortType = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Цена товара, ₽',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _minPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'От',
                                    hintText: '0',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _maxPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'До',
                                    hintText: 'Без ограничений',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    final minText = _minPriceController.text
                                        .trim();
                                    final maxText = _maxPriceController.text
                                        .trim();

                                    final minPrice = minText.isEmpty
                                        ? null
                                        : int.tryParse(minText);
                                    final maxPrice = maxText.isEmpty
                                        ? null
                                        : int.tryParse(maxText);

                                    if ((minText.isNotEmpty &&
                                            minPrice == null) ||
                                        (maxText.isNotEmpty &&
                                            maxPrice == null)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Введите корректную цену.',
                                              ),
                                            ),
                                          );
                                      return;
                                    }

                                    if ((minPrice != null && minPrice < 0) ||
                                        (maxPrice != null && maxPrice < 0)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Цена не может быть отрицательной.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (minPrice != null &&
                                        maxPrice != null &&
                                        minPrice > maxPrice) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Минимальная цена не может быть больше максимальной.',
                                              ),
                                            ),
                                          );
                                      return;
                                    }

                                    setState(() {
                                      _minPrice = minPrice;
                                      _maxPrice = maxPrice;
                                    });
                                  },
                                  child: const Text('Применить'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  _minPriceController.clear();
                                  _maxPriceController.clear();

                                  setState(() {
                                    _minPrice = null;
                                    _maxPrice = null;
                                    _sortType = 'none';
                                  });
                                },
                                child: const Text('Сбросить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isRefreshingCatalog
                            ? null
                            : () async {
                                setState(() {
                                  _isRefreshingCatalog = true;
                                });

                                try {
                                  await _loadBackendData();
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isRefreshingCatalog = false;
                                    });
                                  }
                                }
                              },
                        icon: _isRefreshingCatalog
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _isRefreshingCatalog
                              ? 'Обновление...'
                              : 'Обновить каталог',
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Найдено товаров: ${filteredList.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ничего не найдено',
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Попробуйте изменить запрос или выбрать другую категорию.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedCategory = 'Все';
                                      _sortType = 'none';
                                    });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Сбросить фильтры'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;

                            final columns = width >= 1400
                                ? 5
                                : width >= 1100
                                ? 4
                                : width >= 700
                                ? 3
                                : width >= 400
                                ? 2
                                : 1;

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredList.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: columns == 1
                                        ? 340
                                        : columns == 2
                                        ? 320
                                        : columns == 3
                                        ? 340
                                        : 320,
                                  ),
                              itemBuilder: (context, index) {
                                final product = filteredList[index];

                                return ProductCard(
                                  product: product,
                                  onTap: () => context.go(
                                    '/product/${product.id}',
                                    extra: product,
                                  ),
                                  onAddToCart: () {
                                    _addProductToCart(cartProvider, product);
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
