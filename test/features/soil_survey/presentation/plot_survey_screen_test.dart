import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/soil_survey/presentation/screens/plot_survey_screen.dart';

void main() {
  testWidgets('plot survey shows pending sampling points and opens sample form', (tester) async {
    final farm = DemoFixtures.farmB;
    final plot = farm.plots.first;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PlotSurveyScreen(farm: farm, plot: plot)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('จุดเก็บตัวอย่าง'), findsOneWidget);
    await tester.tap(find.textContaining('บันทึกผล').first);
    await tester.pump();
    expect(find.textContaining('ไนโตรเจน'), findsOneWidget);
  });
}
