import '../domain/entities/source_reference.dart';

class SourceCatalog {
  SourceCatalog._();

  static final riceWaterRequirements = SourceReference(
    title: 'Crop Evapotranspiration: Guidelines for Computing Crop Water Requirements',
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
    url: Uri.parse('https://rkb.ricethailand.go.th/web/content_page.php?code=A-1GT2GJ7SD8'),
    topic: 'spacing',
    reviewedAt: DateTime(2026, 8, 12),
  );

  static List<SourceReference> get all => [
        riceWaterRequirements,
        riceCropWaterNeeds,
        riceSpacing,
      ];
}
