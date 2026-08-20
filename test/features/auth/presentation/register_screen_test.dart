import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/features/auth/presentation/screens/register_screen.dart';

void main() {
  testWidgets('registration screen explains email verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    expect(find.textContaining('ยืนยันอีเมล'), findsOneWidget);
  });
}
