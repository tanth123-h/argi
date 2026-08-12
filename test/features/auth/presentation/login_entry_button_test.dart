import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('login screen exposes one clear primary demo entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('เริ่มใช้งาน Demo'), findsOneWidget);
  });
}
