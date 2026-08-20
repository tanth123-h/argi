import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets(
    'home presents a farmer command center without simulated readings',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DashboardScreen())),
      );

      expect(find.text('สร้างแปลงแรกเพื่อเริ่มใช้งาน'), findsOneWidget);
      expect(find.text('สวัสดี, เกษตรกร'), findsOneWidget);
      expect(find.textContaining('Demo'), findsNothing);
      expect(find.text('55%'), findsNothing);
    },
  );
}
