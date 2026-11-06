import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/providers/favorites_provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final favorites = favoritesProvider.favorites;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: !favoritesProvider.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'В избранном пока пусто',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Нажмите на сердечко в карточке товара, '
                      'чтобы сохранить понравившиеся товары.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        context.go('/');
                      },
                      child: const Text('Перейти в каталог'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final product = favorites[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child:
                          product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  product.icon,
                                  color: product.iconColor,
                                );
                              },
                            )
                          : Icon(
                              product.icon,
                              color: product.iconColor,
                              size: 32,
                            ),
                    ),
                    title: Text(product.title),
                    subtitle: Text(product.price),
                    onTap: () {
                      context.go('/product/${product.id}', extra: product);
                    },
                    trailing: IconButton(
                      tooltip: 'Убрать из избранного',
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        favoritesProvider.toggleFavorite(product);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
