import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/main.dart';
import 'package:my_first_app/data/repositories/product_repository.dart';
import 'package:my_first_app/data/models/product_load_result.dart';

class FakeProductRepository extends ProductRepository {
  @override
  Future<ProductLoadResult> getProducts() async {
    return ProductLoadResult(
      products: ProductRepository.mockProducts,
      source: ProductDataSource.demo,
    );
  }

  @override
  Future<ProductLoadResult?> refreshProductsFromApi() async {
    return ProductLoadResult(
      products: ProductRepository.mockProducts,
      source: ProductDataSource.demo,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Полный сценарий покупки', (tester) async {
    await tester.pumpWidget(
      MyApp(initialDarkMode: false, productRepository: FakeProductRepository()),
    );

    // Здесь будем проверять процесс покупки.
  });
}
