import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

void main() {
  testWidgets('responder login opens responder dashboard', (tester) async {
    final dependencies = await configureDependencies();

    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'responder123@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '12345678',
    );
    await tester.ensureVisible(find.byKey(const Key('sign_in_button')));
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();

    expect(find.text('Responder Console'), findsOneWidget);
    expect(find.text('Situation Overview'), findsOneWidget);

    await tester.tap(find.text('Incidents').last);
    await tester.pumpAndSettle();
    expect(find.text('Priority Incidents'), findsOneWidget);

    await tester.tap(find.text('Teams').last);
    await tester.pumpAndSettle();
    expect(find.text('Team Coordination'), findsOneWidget);

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logout').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('responder incident queue shows backend fetch state', (
    tester,
  ) async {
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

    await tester.tap(find.text('SOS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Emergency Request').last);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'responder123@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '12345678',
    );
    await tester.ensureVisible(find.byKey(const Key('sign_in_button')));
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Incidents').last);
    await tester.pumpAndSettle();

    expect(find.text('Could not load incidents'), findsOneWidget);
    expect(find.textContaining('API request failed'), findsWidgets);
  });
}
