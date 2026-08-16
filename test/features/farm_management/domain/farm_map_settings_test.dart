import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:chaona_app/features/farm_management/domain/farm_map_settings.dart';

void main() {
  test('farm map defaults to satellite mode with Thai location', () {
    expect(FarmMapSettings.mapType, MapType.satellite);
    expect(FarmMapSettings.initialCamera.target.latitude, closeTo(15.87, 0.01));
    expect(FarmMapSettings.initialCamera.target.longitude, closeTo(100.99, 0.01));
    expect(FarmMapSettings.enableMyLocation, isTrue);
  });
}
