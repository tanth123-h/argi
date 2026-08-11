import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farm.dart';
import '../models/crop.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // Auth methods
  User? get currentUser => client.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Farm methods
  Future<List<Farm>> getFarms() async {
    final response = await client
        .from('farms')
        .select()
        .eq('user_id', currentUser!.id)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Farm.fromJson(json)).toList();
  }

  Future<Farm> getFarmById(String id) async {
    final response = await client.from('farms').select().eq('id', id).single();

    return Farm.fromJson(response);
  }

  Future<Farm> createFarm(String name, String location, double size) async {
    final response = await client
        .from('farms')
        .insert({
          'user_id': currentUser!.id,
          'name': name,
          'location': location,
          'size': size,
        })
        .select()
        .single();

    return Farm.fromJson(response);
  }

  Future<void> updateFarm(
    String id,
    String name,
    String location,
    double size,
  ) async {
    await client
        .from('farms')
        .update({'name': name, 'location': location, 'size': size})
        .eq('id', id);
  }

  Future<void> updateFarmPolygon(
    String farmId,
    List<Map<String, double>> coordinates,
    double area,
  ) async {
    await client
        .from('farms')
        .update({'polygon_coordinates': coordinates, 'size': area})
        .eq('id', farmId);
  }

  Future<void> deleteFarm(String id) async {
    await client.from('farms').delete().eq('id', id);
  }

  // Crop methods
  Future<List<Crop>> getCrops(String farmId) async {
    final response = await client
        .from('crops')
        .select()
        .eq('farm_id', farmId)
        .order('planted_at', ascending: false);

    return (response as List).map((json) => Crop.fromJson(json)).toList();
  }

  Future<Crop> createCrop({
    required String farmId,
    required String name,
    required String variety,
    required DateTime plantedAt,
    DateTime? expectedHarvest,
    String? notes,
  }) async {
    final response = await client
        .from('crops')
        .insert({
          'farm_id': farmId,
          'name': name,
          'variety': variety,
          'planted_at': plantedAt.toIso8601String(),
          'expected_harvest': expectedHarvest?.toIso8601String(),
          'notes': notes,
          'status': 'growing',
        })
        .select()
        .single();

    return Crop.fromJson(response);
  }

  Future<void> updateCrop({
    required String id,
    String? name,
    String? variety,
    DateTime? plantedAt,
    DateTime? expectedHarvest,
    DateTime? actualHarvest,
    String? status,
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {};

    if (name != null) updates['name'] = name;
    if (variety != null) updates['variety'] = variety;
    if (plantedAt != null) updates['planted_at'] = plantedAt.toIso8601String();
    if (expectedHarvest != null)
      updates['expected_harvest'] = expectedHarvest.toIso8601String();
    if (actualHarvest != null)
      updates['actual_harvest'] = actualHarvest.toIso8601String();
    if (status != null) updates['status'] = status;
    if (notes != null) updates['notes'] = notes;

    if (updates.isNotEmpty) {
      await client.from('crops').update(updates).eq('id', id);
    }
  }

  Future<void> deleteCrop(String id) async {
    await client.from('crops').delete().eq('id', id);
  }

  // Activity methods
  Future<void> logActivity({
    required String farmId,
    String? cropId,
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await client.from('activities').insert({
      'farm_id': farmId,
      'crop_id': cropId,
      'activity_type': activityType,
      'description': description,
      'metadata': metadata,
      'performed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivities(String farmId) async {
    final response = await client
        .from('activities')
        .select('*, crops(name)')
        .eq('farm_id', farmId)
        .order('performed_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }
}
