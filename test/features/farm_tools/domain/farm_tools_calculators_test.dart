import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/farm_tools/domain/farm_alerts.dart';
import 'package:chaona_app/features/farm_tools/domain/farm_tools_calculators.dart';

void main() {
  test('ET0 x Kc converts net millimeters to cubic meters per rai', () {
    final result = const FarmWaterCalculator().calculate(
      etoMmPerDay: 5,
      kc: 1.2,
      effectiveRainMm: 1,
      areaRai: 1,
    );
    expect(result.etcMmPerDay, 6);
    expect(result.netMmPerDay, 5);
    expect(result.volumeM3PerDay, 8);
  });

  test('economics computes revenue minus cost', () {
    final result = const FarmEconomics().profit(
      yieldTonsPerRai: 0.5,
      areaRai: 2,
      pricePerKg: 8,
      costPerRai: 3000,
    );
    expect(result, 2000);
  });

  test('alerts stale sensor and dry soil', () {
    final alerts = const FarmAlertRules().evaluate(
      moisture: 18,
      lastReading: DateTime.now().subtract(const Duration(hours: 1)),
      rainProbability24h: 80,
    );
    expect(
      alerts.map((a) => a.title),
      containsAll(['ดินแห้งมาก', 'โอกาสฝนสูง', 'ESP32 ไม่ได้ส่งข้อมูลล่าสุด']),
    );
  });
}
