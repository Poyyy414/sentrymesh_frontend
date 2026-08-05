import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('main screens fit on a compact phone viewport', (tester) async {
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
    expectNoFlutterError(tester);

    expect(find.text('Sign In'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'user@test.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'test1234',
    );
    await tester.ensureVisible(find.byKey(const Key('sign_in_button')));
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);

    await tester.tap(find.text('Alerts').last);
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);

    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS').last);
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);
  });

  testWidgets('login uses the desktop split-card arrangement', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your security is our priority.'), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('login shortcuts and account creation keep their behavior', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('login_password_field')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );

    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('Resident profile'), findsOneWidget);
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
