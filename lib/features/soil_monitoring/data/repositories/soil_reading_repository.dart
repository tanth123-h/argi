import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_reading_record.dart';

class SoilReadingRepository {
  final SupabaseClient _client;

  const SoilReadingRepository(this._client);

  Future<void> insert(SoilReadingRecord record) async {
    await _client.from('soil_readings').insert(record.toMap());
  }
}
