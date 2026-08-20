import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'soil_reading_repository.dart';

class OfflineReadingQueue {
  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}pending_soil_readings.json',
    );
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueue(Map<String, dynamic> row) async {
    final rows = await pending();
    rows.add(row);
    await (await _file()).writeAsString(jsonEncode(rows), flush: true);
  }

  Future<int> flush(SoilReadingRepository repository) async {
    final rows = await pending();
    if (rows.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    var saved = 0;
    for (final row in rows) {
      try {
        await repository.insertRow(row);
        saved++;
      } catch (_) {
        remaining.add(row);
      }
    }
    await (await _file()).writeAsString(jsonEncode(remaining), flush: true);
    return saved;
  }
}
