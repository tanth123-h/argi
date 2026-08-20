import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_reading_record.dart';

void main() {
  test('serializes handheld reading with location and timestamp', () {
    final at = DateTime.utc(2026, 8, 12, 10, 30);
    final reading = SoilReadingRecord(
      farmId: 'farm-1',
      plotId: 'plot-1',
      source: SoilReadingSource.handheld,
      deviceId: 'handheld-01',
      latitude: 14.1,
      longitude: 100.2,
      moisture: 42,
      nitrogen: 18,
      recordedAt: at,
    );

    final row = reading.toRow();

    expect(row['source'], 'handheld');
    expect(row['client_reading_id'], isNotEmpty);
    expect(row['farm_id'], 'farm-1');
    expect(row['plot_id'], 'plot-1');
    expect(row['latitude'], 14.1);
    expect(row['recorded_at'], at.toIso8601String());
  });
}
