import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/weather_flood/data/weather_flood_service.dart';

void main() {
  test('uses only future 24-hour rain probabilities', () {
    final result = maxRainProbabilityNext24({
      'time': [
        '2026-08-17T09:00',
        '2026-08-17T11:00',
        '2026-08-18T10:00',
        '2026-08-18T12:00',
      ],
      'precipitation_probability': [99, 20, 70, 100],
    }, now: DateTime(2026, 8, 17, 10));

    expect(result, 70);
  });
}
