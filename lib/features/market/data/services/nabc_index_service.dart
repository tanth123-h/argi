import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class NabcIndexPoint {
  final String product;
  final double value;
  final double? changePercent;
  final int yearTh;
  final int month;
  final bool isPrice;

  const NabcIndexPoint({
    required this.product,
    required this.value,
    required this.changePercent,
    required this.yearTh,
    required this.month,
    required this.isPrice,
  });
}

class NabcIndexSnapshot {
  final List<NabcIndexPoint> price;
  final List<NabcIndexPoint> production;
  final DateTime fetchedAt;
  final String? error;

  const NabcIndexSnapshot({
    required this.price,
    required this.production,
    required this.fetchedAt,
    this.error,
  });

  bool get hasData => price.isNotEmpty || production.isNotEmpty;
}

class NabcIndexService {
  final SupabaseClient supabase;
  NabcIndexService({SupabaseClient? supabase})
      : supabase = supabase ?? Supabase.instance.client;

  Future<NabcIndexSnapshot> fetch({int months = 6}) async {
    final now = DateTime.now();
    final requests = <Future<List<NabcIndexPoint>>>[];
    for (var offset = months - 1; offset >= 0; offset--) {
      final date = DateTime(now.year, now.month - offset);
      final yearTh = date.year + 543;
      final month = date.month;
      requests.add(_fetchType('price-index-month', yearTh, month, true));
      requests.add(_fetchType('production-index-month', yearTh, month, false));
    }
    try {
      final results = await Future.wait(requests);
      final price = <NabcIndexPoint>[];
      final production = <NabcIndexPoint>[];
      for (final list in results) {
        for (final point in list) {
          (point.isPrice ? price : production).add(point);
        }
      }
      return NabcIndexSnapshot(
        price: price,
        production: production,
        fetchedAt: DateTime.now(),
        error: price.isEmpty && production.isEmpty ? 'ไม่พบข้อมูลจาก NABC' : null,
      );
    } catch (error) {
      return NabcIndexSnapshot(
        price: const [],
        production: const [],
        fetchedAt: DateTime.now(),
        error: 'เชื่อมต่อ NABC ไม่สำเร็จ: $error',
      );
    }
  }

  Future<List<NabcIndexPoint>> _fetchType(
    String endpoint,
    int yearTh,
    int month,
    bool isPrice,
  ) async {
    try {
      final response = await supabase.functions.invoke('nabc-proxy', body: {
        'endpoint': endpoint,
        'yearTh': yearTh,
        'month': month,
      });
      if (response.status != 200) return const [];
      final decoded = response.data is String ? jsonDecode(response.data as String) : response.data;
      final rows = _rows(decoded);
      return rows.map((row) {
        final value = _number(row, [
          'index_value', 'price_index', 'production_index', 'value', 'index', 'ค่าดัชนี',
        ]);
        if (value == null) return null;
        return NabcIndexPoint(
          product: _text(row, ['product_name', 'product', 'name', 'สินค้า', 'ชื่อสินค้า']) ?? 'พืชผลสำคัญ',
          value: value,
          changePercent: _number(row, ['percentage_change', 'percent_change', 'change_percent', 'change', 'การเปลี่ยนแปลง']),
          yearTh: yearTh,
          month: month,
          isPrice: isPrice,
        );
      }).whereType<NabcIndexPoint>().toList();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in ['data', 'items', 'results', 'records', 'result']) {
        final nested = value[key];
        final rows = _rows(nested);
        if (rows.isNotEmpty) return rows;
      }
      return [Map<String, dynamic>.from(value)];
    }
    return const [];
  }

  String? _text(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return null;
  }

  double? _number(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString().replaceAll(',', '') ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }
}
