import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/data/repositories/product_repository.dart';
import 'package:my_first_app/data/models/product_load_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductRepository', () {
    late ProductRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'возвращает демоданные при недоступности API и отсутствии кэша',
      () async {
        repository = ProductRepository(
          client: MockClient((request) async {
            throw Exception('Нет подключения к интернету');
          }),
        );

        final result = await repository.getProducts();

        expect(result.source, ProductDataSource.demo);
        expect(result.products, isNotEmpty);
        expect(result.products.length, ProductRepository.mockProducts.length);
      },
    );

    test('возвращает товары из кэша без обращения к API', () async {
      final cachedProducts = [ProductRepository.mockProducts.first.toMap()];

      SharedPreferences.setMockInitialValues({
        'cached_products': jsonEncode(cachedProducts),
        'cached_products_date': '2026-10-30T12:00:00.000',
      });

      repository = ProductRepository(
        client: MockClient((request) async {
          fail('API не должен вызываться при наличии кэша');
        }),
      );

      final result = await repository.getProducts();

      expect(result.source, ProductDataSource.cache);
      expect(result.products.length, 1);
      expect(result.products.first.id, 'headphones_pro');
      expect(result.lastUpdated, isNotNull);
    });

    test('возвращает демоданные при повреждённом кэше и ошибке API', () async {
      SharedPreferences.setMockInitialValues({
        'cached_products': 'некорректный JSON',
      });

      repository = ProductRepository(
        client: MockClient((request) async {
          throw Exception('Нет подключения к интернету');
        }),
      );

      final result = await repository.getProducts();

      expect(result.source, ProductDataSource.demo);
      expect(result.products, isNotEmpty);
    });

    test('возвращает null, если обновление через API не удалось', () async {
      repository = ProductRepository(
        client: MockClient((request) async {
          return http.Response(
            'Ошибка сервера',
            500,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }),
      );

      final result = await repository.refreshProductsFromApi();

      expect(result, isNull);
    });

    test('успешно загружает товары из API', () async {
      repository = ProductRepository(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://fakestoreapi.com/products');

          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'title': 'Test product',
                'price': 100.0,
                'description': 'Test description',
                'category': 'electronics',
                'image': 'https://example.com/product.jpg',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await repository.getProducts();

      expect(result.source, ProductDataSource.api);
      expect(result.products.length, 1);
      expect(result.products.first.id, '1');
      expect(result.products.first.category, 'Электроника');
      expect(result.products.first.imageUrl, 'https://example.com/product.jpg');
      expect(result.lastUpdated, isNotNull);
    });

    test(
      'сохраняет товары и дату обновления в кэш после загрузки API',
      () async {
        repository = ProductRepository(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'title': 'Test product',
                  'price': 100.0,
                  'description': 'Test description',
                  'category': 'electronics',
                  'image': 'https://example.com/product.jpg',
                },
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

        await repository.getProducts();

        final prefs = await SharedPreferences.getInstance();

        final savedProducts = prefs.getString('cached_products');
        final savedDate = prefs.getString('cached_products_date');

        expect(savedProducts, isNotNull);
        expect(savedDate, isNotNull);

        final decoded = jsonDecode(savedProducts!) as List;

        expect(decoded.length, 1);
        expect(decoded.first['id'], '1');
        expect(DateTime.tryParse(savedDate!), isNotNull);
      },
    );

    test('успешно обновляет каталог через API', () async {
      repository = ProductRepository(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'id': 2,
                'title': 'Updated product',
                'price': 50.0,
                'description': 'Updated description',
                'category': 'jewelery',
                'image': 'https://example.com/updated.jpg',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await repository.refreshProductsFromApi();

      expect(result, isNotNull);
      expect(result!.source, ProductDataSource.api);
      expect(result.products.length, 1);
      expect(result.products.first.id, '2');
      expect(result.products.first.category, 'Украшения');
      expect(result.lastUpdated, isNotNull);
    });

    test('заменяет старый кэш новыми товарами после обновления API', () async {
      SharedPreferences.setMockInitialValues({
        'cached_products': jsonEncode([
          ProductRepository.mockProducts.first.toMap(),
        ]),
        'cached_products_date': '2026-01-01T10:00:00.000',
      });

      repository = ProductRepository(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'id': 2,
                'title': 'Updated product',
                'price': 50.0,
                'description': 'Updated description',
                'category': 'electronics',
                'image': 'https://example.com/updated.jpg',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await repository.refreshProductsFromApi();

      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('cached_products');

      expect(savedData, isNotNull);

      final decoded = jsonDecode(savedData!) as List;

      expect(decoded.length, 1);
      expect(decoded.first['id'], '2');
      expect(decoded.first['id'], isNot('headphones_pro'));
    });

    test(
      'сохраняет новую дату обновления после успешного обновления API',
      () async {
        SharedPreferences.setMockInitialValues({
          'cached_products_date': '2026-01-01T10:00:00.000',
        });

        repository = ProductRepository(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode([
                {
                  'id': 3,
                  'title': 'Date test product',
                  'price': 25.0,
                  'description': 'Date test',
                  'category': 'electronics',
                  'image': 'https://example.com/date-test.jpg',
                },
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

        final result = await repository.refreshProductsFromApi();

        expect(result, isNotNull);

        final prefs = await SharedPreferences.getInstance();
        final savedDate = prefs.getString('cached_products_date');

        expect(savedDate, isNotNull);
        expect(DateTime.tryParse(savedDate!), isNotNull);
        expect(DateTime.parse(savedDate).isAfter(DateTime(2026, 1, 1)), isTrue);
      },
    );

    test('возвращает демоданные при пустом ответе API', () async {
      repository = ProductRepository(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await repository.getProducts();

      expect(result.source, ProductDataSource.demo);
      expect(result.products.length, ProductRepository.mockProducts.length);
    });

    test('возвращает демоданные при некорректном JSON от API', () async {
      repository = ProductRepository(
        client: MockClient((request) async {
          return http.Response('это не JSON', 200);
        }),
      );

      final result = await repository.getProducts();

      expect(result.source, ProductDataSource.demo);
      expect(result.products.length, ProductRepository.mockProducts.length);
    });

    test(
      'возвращает демоданные при некорректной записи товара в API',
      () async {
        repository = ProductRepository(
          client: MockClient((request) async {
            return http.Response(jsonEncode([123]), 200);
          }),
        );

        final result = await repository.getProducts();

        expect(result.source, ProductDataSource.demo);
        expect(result.products.length, ProductRepository.mockProducts.length);
      },
    );
  });
}
