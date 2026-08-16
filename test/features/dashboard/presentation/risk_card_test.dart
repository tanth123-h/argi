import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/dashboard/presentation/widgets/risk_card.dart';
import 'package:chaona_app/features/recommendations/domain/entities/risk_level.dart';

void main() {
  testWidgets('risk card shows action label and detail', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RiskCard(
          title: 'Drought risk',
          detail: 'Check water access',
          level: RiskLevel.urgent,
          onTap: () {},
        ),
      ),
    ));

    expect(find.text('Drought risk'), findsOneWidget);
    expect(find.text('Check water access'), findsOneWidget);
  });
}
