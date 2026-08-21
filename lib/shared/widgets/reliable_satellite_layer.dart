import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// ArcGIS tiles can close connections while a phone is changing networks.
/// Keep retry behavior in one place so every satellite map behaves consistently.
TileLayer reliableSatelliteLayer() {
  return TileLayer(
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'com.chaona.app',
    tileProvider: NetworkTileProvider(
      httpClient: RetryClient(
        http.Client(),
        retries: 5,
        when: (response) =>
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500,
        whenError: (_, __) => true,
        delay: (retryCount) => Duration(milliseconds: 500 * (retryCount + 1)),
      ),
    ),
  );
}
