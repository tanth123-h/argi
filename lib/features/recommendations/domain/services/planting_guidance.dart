import '../../data/source_catalog.dart';
import '../entities/source_reference.dart';

class PlantingGuidance {
  final String cropId;
  final String cropName;
  final String plantingMaterial;
  final double plantSpacingCm;
  final double rowSpacingCm;
  final String quantityUnit;
  final String note;
  final SourceReference source;

  const PlantingGuidance({
    required this.cropId,
    required this.cropName,
    required this.plantingMaterial,
    required this.plantSpacingCm,
    required this.rowSpacingCm,
    required this.quantityUnit,
    required this.note,
    required this.source,
  });

  int quantityForAreaM2(double areaM2) {
    final areaPerPlant = (plantSpacingCm / 100) * (rowSpacingCm / 100);
    return areaPerPlant <= 0 ? 0 : (areaM2 / areaPerPlant).floor();
  }

  static PlantingGuidance? forCrop(String cropId) => switch (cropId
      .toLowerCase()) {
    'rice' || 'ข้าว' => PlantingGuidance(
      cropId: 'rice',
      cropName: 'ข้าว',
      plantingMaterial: 'ต้นกล้า',
      plantSpacingCm: 20,
      rowSpacingCm: 20,
      quantityUnit: 'ต้นกล้า/กอ',
      note:
          'แนวทางสำหรับนาดำ: ระยะ 20 × 20 ซม. และใช้ประมาณ 3 ต้นกล้าต่อกอ ควรปรับตามพันธุ์และวิธีปลูกในพื้นที่',
      source: SourceCatalog.riceSpacing,
    ),
    'cassava' || 'มันสำปะหลัง' => PlantingGuidance(
      cropId: 'cassava',
      cropName: 'มันสำปะหลัง',
      plantingMaterial: 'ท่อนพันธุ์',
      plantSpacingCm: 80,
      rowSpacingCm: 80,
      quantityUnit: 'ท่อนพันธุ์',
      note:
          'ใช้เป็นค่าตั้งต้นจากงานทดลองของกรมวิชาการเกษตร ต้องเลือกท่อนพันธุ์สะอาด ปลอดโรค และปรับตามพันธุ์/ดิน/เครื่องจักร',
      source: SourceCatalog.cassavaSpacing,
    ),
    _ => null,
  };
}
