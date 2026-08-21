import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/soil_reading_record.dart';

class SoilReadingRepository {
  final SupabaseClient client;

  const SoilReadingRepository(this.client);

  Future<void> insert(SoilReadingRecord reading) async {
    await client
        .from('soil_readings')
        .upsert(
          reading.toRow(),
          onConflict: 'client_reading_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> insertRow(Map<String, dynamic> row) async {
    await client
        .from('soil_readings')
        .upsert(row, onConflict: 'client_reading_id', ignoreDuplicates: true);
  }

  Future<List<Map<String, dynamic>>> latestForFarm(String farmId) async {
    final rows = await client
        .from('soil_readings')
        .select()
        .eq('farm_id', farmId)
        .order('recorded_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
