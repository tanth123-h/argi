import '../domain/entities/source_reference.dart';

class SourceCatalog {
  SourceCatalog._();

  static final riceWaterRequirements = SourceReference(
    title:
        'Crop Evapotranspiration: Guidelines for Computing Crop Water Requirements',
    publisher: 'FAO',
    url: Uri.parse('https://www.fao.org/4/f2430e/f2430e.pdf'),
    topic: 'water',
    reviewedAt: DateTime(2026, 8, 12),
  );

  static final riceCropWaterNeeds = SourceReference(
    title: 'Crop water needs',
    publisher: 'FAO',
    url: Uri.parse('https://www.fao.org/4/s2022e/s2022e02.htm'),
    topic: 'water',
    reviewedAt: DateTime(2026, 8, 12),
  );

  static final riceSpacing = SourceReference(
    title: 'Rice transplanting guidance',
    publisher: 'Rice Department, Thailand',
    url: Uri.parse(
      'https://rkb.ricethailand.go.th/web/content_page.php?code=A-1GT2GJ7SD8',
    ),
    topic: 'spacing',
    reviewedAt: DateTime(2026, 8, 12),
  );

  static final departmentOfAgriculture = SourceReference(
    title: 'กรมวิชาการเกษตร: หน่วยงานและงานวิจัยด้านการเกษตร',
    publisher: 'กรมวิชาการเกษตร',
    url: Uri.parse('https://www.doa.go.th/th/about/about-str_org/'),
    topic: 'soil and crop guidance',
    reviewedAt: DateTime(2026, 8, 13),
  );

  static final officialSoilGuidance = SourceReference(
    title: 'คำแนะนำการวิเคราะห์ดินและการใช้ปุ๋ย',
    publisher: 'กรมวิชาการเกษตร',
    url: Uri.parse('https://doa.go.th/share/showthread.php?tid=2446'),
    topic: 'soil and fertilizer',
    reviewedAt: DateTime(2026, 8, 13),
  );

  static final agriculturalEconomics = SourceReference(
    title: 'คลังข้อมูลสำนักงานเศรษฐกิจการเกษตร',
    publisher: 'สำนักงานเศรษฐกิจการเกษตร',
    url: Uri.parse('https://catalog.oae.go.th/'),
    topic: 'agricultural prices',
    reviewedAt: DateTime(2026, 8, 13),
  );

  static final thaiMeteorologicalDepartment = SourceReference(
    title: 'ข้อมูลอุตุนิยมวิทยาประเทศไทย',
    publisher: 'กรมอุตุนิยมวิทยา',
    url: Uri.parse('https://www.tmd.go.th/'),
    topic: 'weather and drought risk',
    reviewedAt: DateTime(2026, 8, 13),
  );

  static List<SourceReference> get all => [
    riceWaterRequirements,
    riceCropWaterNeeds,
    riceSpacing,
    departmentOfAgriculture,
    officialSoilGuidance,
    agriculturalEconomics,
    thaiMeteorologicalDepartment,
  ];
}
