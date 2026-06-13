import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

void main() {
  testWidgets('resident dashboard uses the wide reference layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'user123@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '12345678',
    );
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();

    final backup = tester.getRect(
      find.byKey(const Key('emergency_backup_card')),
    );
    final sos = tester.getRect(find.byKey(const Key('home_sos_card')));
    final family = tester.getRect(
      find.byKey(const Key('family_check_in_card')),
    );
    final weather = tester.getRect(
      find.byKey(const Key('weather_hazard_card')),
    );
    final alerts = tester.getRect(find.byKey(const Key('nearby_alerts_card')));

    expect((backup.top - sos.top).abs(), lessThan(1));
    expect((sos.top - family.top).abs(), lessThan(1));
    expect(sos.left, greaterThan(backup.left));
    expect(family.left, greaterThan(sos.left));
    expect((weather.top - alerts.top).abs(), lessThan(1));
    expect(find.text('Network Health'), findsNothing);
    expect(find.text('AI Flood Forecast'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('resident dashboard stacks primary actions on phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'user123@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '12345678',
    );
    await tester.ensureVisible(find.byKey(const Key('sign_in_button')));
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();

    final backup = tester.getRect(
      find.byKey(const Key('emergency_backup_card')),
    );
    final sos = tester.getRect(find.byKey(const Key('home_sos_card')));
    final family = tester.getRect(
      find.byKey(const Key('family_check_in_card')),
    );

    expect(sos.top, greaterThan(backup.top));
    expect(family.top, greaterThan(sos.top));
    expect(find.text('Network Health'), findsNothing);
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
