import 'package:google_maps_flutter/google_maps_flutter.dart';

class FarmMapSettings {
  FarmMapSettings._();

  static const mapType = MapType.satellite;
  static const initialCamera = CameraPosition(
    target: LatLng(15.87, 100.99),
    zoom: 6.5,
    tilt: 0,
  );
  static const enableMyLocation = true;
  static const enableMyLocationButton = true;
  static const enableCompass = true;
  static const enableRotateGestures = true;
  static const enableTiltGestures = true;
}
