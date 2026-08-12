import '../../farm_management/domain/entities/farm.dart';
import '../../recommendations/domain/entities/recommendation.dart';
import '../../soil_survey/domain/entities/soil_plot_summary.dart';

class AiContextBuilder {
  String build({
    required Farm farm,
    required List<Recommendation> recommendations,
    SoilPlotSummary? summary,
  }) {
    final lines = <String>[
      'ฟาร์ม: ${farm.name}',
      'พืช: ${farm.cropType}',
      'พื้นที่: ${farm.areaRai} ไร่',
      'คำสั่งความปลอดภัย: ห้ามสร้างตัวเลขหรือแหล่งอ้างอิงใหม่',
      'ให้อธิบายเฉพาะข้อมูลและคำแนะนำที่ระบบส่งให้ พร้อมระบุเมื่อข้อมูลไม่พอ',
    ];
    if (summary != null) {
      lines.add('ตัวอย่างดินที่ใช้สรุป: ${summary.validSampleCount} จุด; ความมั่นใจ ${summary.confidence.name}');
    }
    for (final recommendation in recommendations) {
      lines.add('คำแนะนำ: ${recommendation.title} | ${recommendation.value} | ${recommendation.action}');
      lines.add('การคำนวณ: ${recommendation.calculation}');
      lines.add('แหล่งอ้างอิง: ${recommendation.source.publisher} ${recommendation.source.url}');
    }
    return lines.join('\n');
  }
}
