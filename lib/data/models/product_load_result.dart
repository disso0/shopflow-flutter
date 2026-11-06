import 'product.dart';

enum ProductDataSource { api, cache, demo }

class ProductLoadResult {
  final List<Product> products;
  final ProductDataSource source;
  final DateTime? lastUpdated;

  const ProductLoadResult({
    required this.products,
    required this.source,
    this.lastUpdated,
  });
}
