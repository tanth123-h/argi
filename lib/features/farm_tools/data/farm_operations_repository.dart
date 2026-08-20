import 'package:supabase_flutter/supabase_flutter.dart';

class FarmOperationsRepository {
  final SupabaseClient client;
  const FarmOperationsRepository(this.client);

  Future<List<Map<String, dynamic>>> cycles(String farmId) async {
    final rows = await client
        .from('farm_cycles')
        .select()
        .eq('farm_id', farmId)
        .order('planted_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> actions(String farmId) async {
    final rows = await client
        .from('farm_actions')
        .select()
        .eq('farm_id', farmId)
        .order('occurred_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> createCycle({
    required String farmId,
    required String cropType,
    required String variety,
    required DateTime plantedAt,
    DateTime? expectedHarvestAt,
  }) => client.from('farm_cycles').insert({
    'farm_id': farmId,
    'crop_type': cropType,
    'variety': variety.trim().isEmpty ? null : variety.trim(),
    'planted_at': _date(plantedAt),
    'expected_harvest_at': expectedHarvestAt == null
        ? null
        : _date(expectedHarvestAt),
    'status': 'active',
  });

  Future<void> addAction({
    required String farmId,
    String? cycleId,
    required String actionType,
    double? amount,
    String? unit,
    String? note,
    DateTime? occurredAt,
  }) => client.from('farm_actions').insert({
    'farm_id': farmId,
    'cycle_id': cycleId,
    'action_type': actionType,
    'amount': amount,
    'unit': unit,
    'note': note,
    'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
  });

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
