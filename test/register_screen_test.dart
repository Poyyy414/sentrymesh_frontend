import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('registration keeps validation and backend error flow', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pump();

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('Last name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Address is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_first_name_field')),
      'New',
    );
    await tester.enterText(
      find.byKey(const Key('register_last_name_field')),
      'Resident',
    );
    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'new.resident.${DateTime.now().microsecondsSinceEpoch}@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_address_field')),
      'Naga City',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'test1234',
    );

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('API request failed'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('registration stacks fields on a compact phone', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    final firstName = tester.getRect(
      find.byKey(const Key('register_first_name_field')),
    );
    final lastName = tester.getRect(
      find.byKey(const Key('register_last_name_field')),
    );

    expect(lastName.top, greaterThan(firstName.top));
    expect(find.text('Create your account'), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('registration uses side-by-side names on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    final firstName = tester.getRect(
      find.byKey(const Key('register_first_name_field')),
    );
    final lastName = tester.getRect(
      find.byKey(const Key('register_last_name_field')),
    );

    expect((firstName.top - lastName.top).abs(), lessThan(1));
    expect(lastName.left, greaterThan(firstName.left));
    expect(find.text('Your security is our priority.'), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('back to sign in keeps existing navigation behavior', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('register_back_button')));
    await tester.tap(find.byKey(const Key('register_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}

void expectNoFlutterError(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }

  if (exception is FlutterError) {
    final details = exception.diagnostics
        .map((node) => node.toStringDeep())
        .join('\n');
    fail('${exception.message}\n$details');
  }

  fail(exception.toString());
}
