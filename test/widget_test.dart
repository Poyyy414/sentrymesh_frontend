import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/app/app.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';

void main() {
  testWidgets('renders the SentryMesh mobile shell', (tester) async {
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

    expect(find.text('SentryMesh'), findsOneWidget);
    expect(find.text('SOS'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
