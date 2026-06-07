import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

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

    final dependencies = await configureDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expectNoFlutterError(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user123@gmail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '12345678',
    );
    await tester.tap(find.text('Sign In').last);
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
