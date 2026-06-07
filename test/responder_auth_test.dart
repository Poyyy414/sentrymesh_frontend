import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

void main() {
  testWidgets('responder login opens responder dashboard', (tester) async {
    final dependencies = await configureDependencies();

    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'responder123@gmail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '12345678',
    );
    await tester.tap(find.text('Sign In').last);
    await tester.pumpAndSettle();

    expect(find.text('SentryMesh Responder'), findsOneWidget);
    expect(find.text('Situation Overview'), findsOneWidget);

    await tester.tap(find.text('Incidents').last);
    await tester.pumpAndSettle();
    expect(find.text('Active Incidents'), findsOneWidget);

    await tester.tap(find.text('Teams').last);
    await tester.pumpAndSettle();
    expect(find.text('Teams & Communication'), findsOneWidget);

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logout').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('resident SOS appears in responder incident queue', (
    tester,
  ) async {
    final dependencies = await configureDependencies();

    await tester.pumpWidget(SentryMeshApp(dependencies: dependencies));
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

    await tester.tap(find.text('SOS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Emergency Request'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'responder123@gmail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '12345678',
    );
    await tester.tap(find.text('Sign In').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Incidents').last);
    await tester.pumpAndSettle();

    expect(find.text('Resident SOS'), findsOneWidget);
    expect(find.textContaining('Just now'), findsWidgets);
  });
}
