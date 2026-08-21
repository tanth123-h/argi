import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/device_calibration.dart';

class DeviceCalibrationRepository {
  final SupabaseClient client;
  const DeviceCalibrationRepository(this.client);

  Future<DeviceCalibration> latest(String farmId, String deviceId) async {
    try {
      final row = await client
          .from('device_calibrations')
          .select()
          .eq('farm_id', farmId)
          .eq('device_id', deviceId)
          .order('calibrated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return const DeviceCalibration();
      return DeviceCalibration(
        moistureOffset: (row['moisture_offset'] as num?)?.toDouble() ?? 0,
        phOffset: (row['ph_offset'] as num?)?.toDouble() ?? 0,
        ecMultiplier: (row['ec_multiplier'] as num?)?.toDouble() ?? 1,
      );
    } catch (_) {
      return const DeviceCalibration();
    }
  }

  Future<void> save({
    required String farmId,
    required String deviceId,
    required double moistureOffset,
    required double phOffset,
    required double ecMultiplier,
  }) => client.from('device_calibrations').insert({
    'farm_id': farmId,
    'device_id': deviceId,
    'moisture_offset': moistureOffset,
    'ph_offset': phOffset,
    'ec_multiplier': ecMultiplier,
  });
}
