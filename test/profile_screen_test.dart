import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;
  bool logoutCalled = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logoutCalled = false;

    router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => ProfilePage(
            onLogout: () {
              logoutCalled = true;
            },
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Каталог товаров')),
        ),
        GoRoute(
          path: '/profile/orders',
          builder: (context, state) =>
              const Scaffold(body: Text('История заказов')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
  });

  // Здесь ниже должны идти все testWidgets()

  testWidgets('Показывает демонстрационные данные профиля по умолчанию', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Профиль пользователя'), findsOneWidget);
    expect(find.text('Иванов Иван Иванович'), findsOneWidget);
    expect(find.text('+7 (900) 000-00-00'), findsOneWidget);
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(find.text('ИИ'), findsOneWidget);
  });

  testWidgets('Загружает сохранённые данные пользователя', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'user_name': 'Иванов Иван Иванович',
      'user_phone': '+79991234567',
      'user_email': 'ivanov@example.com',
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(find.text('Иванов Иван Иванович'), findsOneWidget);
    expect(find.text('+79991234567'), findsOneWidget);
    expect(find.text('ivanov@example.com'), findsOneWidget);
    expect(find.text('ИИ'), findsOneWidget);
  });

  testWidgets('Сохраняет изменённые данные пользователя', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя пользователя'),
      'Сидоров Сидор Сидорович',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон'),
      '+79998887766',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'sidorov@example.com',
    );

    final saveButton = find.text('Сохранить изменения');

    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Профиль успешно обновлен!'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('user_name'), 'Сидоров Сидор Сидорович');
    expect(prefs.getString('user_phone'), '+79998887766');
    expect(prefs.getString('user_email'), 'sidorov@example.com');
  });

  testWidgets('Открывает историю заказов', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    final ordersButton = find.text('Мои заказы');

    expect(ordersButton, findsOneWidget);

    await tester.ensureVisible(ordersButton);
    await tester.pumpAndSettle();
    await tester.tap(ordersButton);
    await tester.pumpAndSettle();

    expect(find.text('История заказов'), findsOneWidget);
  });

  testWidgets('Кнопка выхода вызывает onLogout', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    final logoutButton = find.text('Выйти из профиля');

    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
  });

  testWidgets('Возвращается в каталог по стрелке назад', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Назад в каталог'));
    await tester.pumpAndSettle();

    expect(find.text('Каталог товаров'), findsOneWidget);
  });
  testWidgets('Не сохраняет профиль, если имя пустое', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Подготавливаем ранее сохранённые данные.
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', 'Иванов Иван');
    await prefs.setString('user_phone', '+79991234567');
    await prefs.setString('user_email', 'ivanov@example.com');

    // Открываем профиль.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Очищаем поле имени.
    final nameField = find.widgetWithText(TextFormField, 'Имя пользователя');

    await tester.enterText(nameField, '');

    // Нажимаем кнопку сохранения.
    final saveButton = find.text('Сохранить изменения');

    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Проверяем появление ошибки.
    expect(find.text('Введите имя (минимум 2 символа)'), findsOneWidget);

    // Проверяем, что старое имя осталось в хранилище.
    expect(prefs.getString('user_name'), 'Иванов Иван');
  });
  testWidgets('Не сохраняет профиль, если имя содержит один символ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', 'Иванов Иван');
    await prefs.setString('user_phone', '+79991234567');
    await prefs.setString('user_email', 'ivanov@example.com');

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextFormField, 'Имя пользователя');

    await tester.enterText(nameField, 'А');

    final saveButton = find.text('Сохранить изменения');

    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Введите имя (минимум 2 символа)'), findsOneWidget);

    expect(prefs.getString('user_name'), 'Иванов Иван');
  });
  testWidgets('Не сохраняет профиль, если номер телефона некорректный', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', 'Иванов Иван');
    await prefs.setString('user_phone', '+79991234567');
    await prefs.setString('user_email', 'ivanov@example.com');

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final phoneField = find.widgetWithText(TextFormField, 'Телефон');

    await tester.enterText(phoneField, '12345');

    final saveButton = find.text('Сохранить изменения');

    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный номер телефона'), findsOneWidget);

    expect(prefs.getString('user_phone'), '+79991234567');
  });
  testWidgets('Не сохраняет профиль, если Email некорректный', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', 'Иванов Иван');
    await prefs.setString('user_phone', '+79991234567');
    await prefs.setString('user_email', 'ivanov@example.com');

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email');

    await tester.enterText(emailField, 'ivanov@');

    final saveButton = find.text('Сохранить изменения');

    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный Email'), findsOneWidget);

    expect(prefs.getString('user_email'), 'ivanov@example.com');
  });
}
