class FarmSoilSummary {
  final String farmId;
  final int readingCount;
  final int expectedPointCount;
  final Map<String, double> averages;
  final Set<String> missingFields;
  final bool isPreliminary;

  const FarmSoilSummary({
    required this.farmId,
    required this.readingCount,
    required this.expectedPointCount,
    required this.averages,
    required this.missingFields,
    required this.isPreliminary,
  });

  double? get moisture => averages['moisture'];
  double? get ph => averages['ph'];
  double? get nitrogen => averages['nitrogen'];
  double? get phosphorus => averages['phosphorus'];
  double? get potassium => averages['potassium'];
  double? get ec => averages['ec'];

  String get confidenceLabel {
    if (readingCount == 0) return 'ไม่มีข้อมูล';
    if (readingCount < expectedPointCount) return 'ข้อมูลบางส่วน';
    return isPreliminary
        ? 'เบื้องต้น ต้องยืนยันด้วยผลแล็บ'
        : 'จากการวัดภาคสนาม';
  }

  static FarmSoilSummary fromRows({
    required String farmId,
    required List<Map<String, dynamic>> rows,
    int expectedPointCount = 5,
  }) {
    const fields = [
      'moisture',
      'temperature',
      'humidity',
      'ec',
      'ph',
      'nitrogen',
      'phosphorus',
      'potassium',
    ];
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final row in rows) {
      for (final field in fields) {
        final value = row[field];
        if (value is num) {
          totals[field] = (totals[field] ?? 0) + value.toDouble();
          counts[field] = (counts[field] ?? 0) + 1;
        }
      }
    }
    final averages = <String, double>{
      for (final field in fields)
        if ((counts[field] ?? 0) > 0) field: totals[field]! / counts[field]!,
    };
    final missing = fields
        .where((field) => !averages.containsKey(field))
        .toSet();
    return FarmSoilSummary(
      farmId: farmId,
      readingCount: rows.length,
      expectedPointCount: expectedPointCount,
      averages: averages,
      missingFields: missing,
      isPreliminary: true,
    );
  }
}
