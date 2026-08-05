import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('family safety profile keeps existing placeholder actions', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenProfile(tester);

    expect(find.text('Family Safety Check'), findsOneWidget);
    expect(find.byKey(const Key('family_status_card')), findsOneWidget);
    expect(find.byKey(const Key('family_member_maria')), findsOneWidget);
    expect(find.byKey(const Key('family_member_antonio')), findsOneWidget);
    expect(find.byKey(const Key('family_member_carmen')), findsOneWidget);
    expect(find.byKey(const Key('family_member_bea')), findsOneWidget);

    await tester.tap(find.byKey(const Key('update_family_status_button')));
    await tester.tap(find.byKey(const Key('family_member_maria')));
    await tester.ensureVisible(
      find.byKey(const Key('check_in_all_family_action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check_in_all_family_action')));
    await tester.ensureVisible(
      find.byKey(const Key('send_family_location_action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send_family_location_action')));
    await tester.ensureVisible(
      find.byKey(const Key('family_emergency_message_action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family_emergency_message_action')));
    await tester.pumpAndSettle();

    expect(find.text('Family Safety Check'), findsOneWidget);
    expect(find.text('You are Safe'), findsOneWidget);
  });

  testWidgets('family safety profile fits a compact phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenProfile(tester);

    expect(find.byTooltip('Logout'), findsOneWidget);
    expect(find.text('Family Safety Check'), findsOneWidget);
    expectNoFlutterError(tester);
  });

  testWidgets('family safety profile centers its wide content', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenProfile(tester);

    final status = tester.getRect(find.byKey(const Key('family_status_card')));
    final member = tester.getRect(find.byKey(const Key('family_member_maria')));

    expect((status.left - member.left).abs(), lessThan(1));
    expect((status.right - member.right).abs(), lessThan(1));
    expect(status.width, lessThanOrEqualTo(1280));
    expectNoFlutterError(tester);
  });

  testWidgets('profile logout keeps the existing authentication flow', (
    tester,
  ) async {
    final dependencies = await configureTestDependencies();
    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await _signInAndOpenProfile(tester);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}

Future<void> _signInAndOpenProfile(WidgetTester tester) async {
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
  await tester.tap(find.text('Profile').last);
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
