import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/device_calibration.dart';

void main() {
  test('applies offsets, multiplier, and safe ranges', () {
    const calibration = DeviceCalibration(
      moistureOffset: 5,
      phOffset: -0.2,
      ecMultiplier: 1.1,
    );
    expect(calibration.moisture(98), 100);
    expect(calibration.ph(7), 6.8);
    expect(calibration.ec(100), closeTo(110, 0.001));
  });
}
