import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/soil_survey/domain/services/farm_soil_summary.dart';

void main() {
  test('averages real rows and marks unavailable fields', () {
    final summary = FarmSoilSummary.fromRows(
      farmId: 'farm-1',
      rows: [
        {'moisture': 40, 'ph': 6},
        {'moisture': 60, 'ph': 7},
      ],
    );
    expect(summary.moisture, 50);
    expect(summary.ph, 6.5);
    expect(summary.missingFields, contains('nitrogen'));
    expect(summary.confidenceLabel, 'ข้อมูลบางส่วน');
  });
}
