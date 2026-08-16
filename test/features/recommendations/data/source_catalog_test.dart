import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/recommendations/data/source_catalog.dart';

void main() {
  test('rice source catalog contains FAO water and Thai rice guidance', () {
    expect(SourceCatalog.riceWaterRequirements.publisher, 'FAO');
    expect(SourceCatalog.riceSpacing.publisher, contains('Rice Department'));
    expect(SourceCatalog.all, hasLength(3));
  });
}
