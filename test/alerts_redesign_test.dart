import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/app/theme.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

void main() {
  testWidgets('alert filters keep their existing selection behavior', (
    tester,
  ) async {
    final dependencies = await configureDependencies();
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
    expect(find.byKey(const Key('flood_alert_card')), findsOneWidget);
    expect(find.byKey(const Key('landslide_alert_card')), findsOneWidget);
    expect(find.byKey(const Key('typhoon_alert_card')), findsOneWidget);
  });

  testWidgets('only the existing flood action opens alert details', (
    tester,
  ) async {
    final dependencies = await configureDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('view_details_Landslide Alert')),
    );
    await tester.tap(
      find.byKey(const ValueKey('view_details_Landslide Alert')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_filter_button')), findsOneWidget);

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

    final dependencies = await configureDependencies();
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

    final dependencies = await configureDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenAlerts(tester);
    await tester.tap(find.byKey(const ValueKey('view_details_Flood Warning')));
    await tester.pumpAndSettle();

    final locations = find.textContaining('San Felipe, Naga City');
    final date = find.textContaining('Today, 6:30 AM');
    final source = find.textContaining('SentryMesh System');

    expect(
      (tester.getTopLeft(locations).dy - tester.getTopLeft(date).dy).abs(),
      lessThan(1),
    );
    expect(
      (tester.getTopLeft(date).dy - tester.getTopLeft(source).dy).abs(),
      lessThan(1),
    );
    expectNoFlutterError(tester);
  });
}

Future<void> _signInAndOpenAlerts(WidgetTester tester) async {
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
