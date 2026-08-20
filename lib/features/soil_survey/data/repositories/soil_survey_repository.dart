import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/persisted_sampling_point.dart';
import '../../domain/entities/sampling_point.dart';
import '../../domain/entities/soil_survey.dart';

class SoilSurveyRepository {
  final SupabaseClient client;

  const SoilSurveyRepository(this.client);

  Future<SoilSurvey> createSurvey({
    required String farmId,
    required List<SamplingPoint> points,
  }) async {
    final surveyRow = await client
        .from('soil_surveys')
        .insert({
          'farm_id': farmId,
          'point_count': points.length,
          'status': 'in_progress',
        })
        .select()
        .single();
    final surveyId = surveyRow['id'] as String;
    await client.from('soil_sampling_points').insert([
      for (final point in points)
        {
          'survey_id': surveyId,
          'farm_id': farmId,
          'sampling_key': point.id,
          'sequence': point.sequence,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'status': 'pending',
        },
    ]);
    return _surveyFromRow(Map<String, dynamic>.from(surveyRow));
  }

  Future<void> updatePointStatus({
    required String surveyId,
    required String samplingKey,
    required SamplingPointStatus status,
    DateTime? sampledAt,
  }) async {
    await client
        .from('soil_sampling_points')
        .update({
          'status': _statusName(status),
          'sampled_at': sampledAt?.toUtc().toIso8601String(),
        })
        .eq('survey_id', surveyId)
        .eq('sampling_key', samplingKey);
  }

  Future<void> completeSurvey(String surveyId) async {
    await client
        .from('soil_surveys')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', surveyId);
  }

  Future<List<Map<String, dynamic>>> listLatestForFarm(String farmId) async {
    final rows = await client
        .from('soil_surveys')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)
        .limit(10);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<PersistedSamplingPoint>> pointsForSurvey(String surveyId) async {
    final rows = await client
        .from('soil_sampling_points')
        .select()
        .eq('survey_id', surveyId)
        .order('sequence');
    return (rows as List)
        .map((row) => _pointFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  SoilSurvey _surveyFromRow(Map<String, dynamic> row) => SoilSurvey(
    id: row['id'] as String,
    farmId: row['farm_id'] as String,
    status: SoilSurveyStatus.values.firstWhere(
      (value) => _statusName(value) == row['status'],
      orElse: () => SoilSurveyStatus.inProgress,
    ),
    pointCount: (row['point_count'] as num?)?.toInt() ?? 5,
    startedAt: DateTime.parse(row['started_at'] as String),
    completedAt: row['completed_at'] == null
        ? null
        : DateTime.parse(row['completed_at'] as String),
  );

  PersistedSamplingPoint _pointFromRow(Map<String, dynamic> row) =>
      PersistedSamplingPoint(
        id: row['id'] as String,
        surveyId: row['survey_id'] as String,
        farmId: row['farm_id'] as String,
        samplingKey: row['sampling_key'] as String,
        sequence: (row['sequence'] as num).toInt(),
        location: LatLng(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
        ),
        status: SamplingPointStatus.values.firstWhere(
          (value) => _statusName(value) == row['status'],
          orElse: () => SamplingPointStatus.pending,
        ),
        sampledAt: row['sampled_at'] == null
            ? null
            : DateTime.parse(row['sampled_at'] as String),
      );

  String _statusName(Object value) => switch (value) {
    SoilSurveyStatus.inProgress => 'in_progress',
    SoilSurveyStatus.completed => 'completed',
    SoilSurveyStatus.cancelled => 'cancelled',
    SamplingPointStatus.pending => 'pending',
    SamplingPointStatus.sampled => 'sampled',
    SamplingPointStatus.skipped => 'skipped',
    _ => 'pending',
  };
}
