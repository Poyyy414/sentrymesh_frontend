import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/app/theme.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('alert filters keep their existing selection behavior', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);

    await tester.tap(find.byKey(const Key('alert_filter_1')));
    await tester.pump();

    final underline = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('alert_filter_1')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = underline.decoration! as BoxDecoration;

    expect(decoration.color, AppTheme.signalBlue);
    expect(find.text('Flood Warning'), findsWidgets);
    expect(find.text('Landslide Alert'), findsWidgets);
    expect(find.text('Typhoon Alert'), findsWidgets);
  });

  testWidgets('tapping an alert card opens the alert details screen', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('view_details_Flood Warning')),
    );
    await tester.tap(find.byKey(const ValueKey('view_details_Flood Warning')));
    await tester.pumpAndSettle();

    expect(find.text('Alert Details'), findsOneWidget);
    expect(find.text('Potential Impact'), findsOneWidget);
    expect(find.text('Open Safe Route Map'), findsOneWidget);
    expect(find.text('Send Community Report'), findsOneWidget);
    expect(find.text('Get Updates'), findsOneWidget);
    expect(find.text('Emergency SOS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alert_details_back_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_filter_button')), findsOneWidget);
  });

  testWidgets('alerts and details fit a compact phone viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);
    expectNoFlutterError(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('view_details_Flood Warning')),
    );
    await tester.tap(find.byKey(const ValueKey('view_details_Flood Warning')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alert_summary_card')), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('alert details use horizontal metadata on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);
    await tester.tap(find.byKey(const ValueKey('view_details_Flood Warning')));
    await tester.pumpAndSettle();

    final locationWidget = find.textContaining('San Felipe, Naga City');
    final sourceWidget = find.textContaining('SentryMesh System');

    expect(
      (tester.getTopLeft(locationWidget).dy - tester.getTopLeft(sourceWidget).dy).abs(),
      lessThan(1),
    );
    expectNoFlutterError(tester);
  });
}

Future<void> _signInAndOpenAlerts(WidgetTester tester) async {
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
  await tester.tap(find.text('Alerts').last);
  await tester.pumpAndSettle();
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
