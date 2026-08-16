import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thai agricultural market price data.
///
/// Primary source:
/// NABC Agricultural Data Service — daily agricultural prices.
/// The endpoints are public URLs, not secret API keys.
///
/// The app keeps a small in-code reference list as a last-resort fallback
/// so the market screen remains useful when the public API is unavailable.
class MarketPriceService {
  static final _instance = MarketPriceService._();
  factory MarketPriceService() => _instance;
  MarketPriceService._();

  static const _nabcBaseUrl =
      'https://agriapi.nabc.go.th/api/daily-prices/category';
  static const _nabcWeeklyBaseUrl =
      'https://agriapi.nabc.go.th/api/weekly-prices/commod';
  static const _weeklyCommodity = 'ข้าว';
  static const _weeklyYearTh = 2569;
  static const _weeklyMonths = <int>[1, 2, 3, 4, 5, 6, 7, 8];

  // Keep this list in one place so adding another public category does not
  // require changing the screen or its state management.
  static const _nabcCategories = <String>{
    'ข้าวโพดเลี้ยงสัตว์',
    'ข้าวหอมมะลิ',
    'ยางพารา',
    'มะพร้าว',
    'ปาล์มน้ำมัน',
    'ลำไย',
    'มันสำปะหลัง',
    'มะนาว',
  };

  static const _maxPagesPerCategory = 20;

  /// Fetch farm-gate prices with source metadata for display.
  Future<MarketPriceSnapshot> fetchFarmGatePrices() async {
    final fetchedAt = DateTime.now();

    try {
      final nabcPrices = await _fetchFromNabc();
      if (nabcPrices.isNotEmpty) {
        return MarketPriceSnapshot(
          prices: _sortByName(nabcPrices),
          fetchedAt: fetchedAt,
          mode: MarketPriceMode.liveApi,
          sourceName: 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
          sourceUrl: _nabcBaseUrl,
          note:
              'ข้อมูลราคาสินค้ารายวันจาก API ภาครัฐโดยตรง รวมหลายหมวดสินค้าและหลายหน้าแล้ว ควรตรวจสอบราคาท้องถิ่นก่อนขายจริง',
        );
      }
    } catch (_) {
      // Fall through to reference data. The UI clearly labels this state.
    }

    return MarketPriceSnapshot(
      prices: _sortByName(_staticPrices(fetchedAt)),
      fetchedAt: fetchedAt,
      mode: MarketPriceMode.referenceFallback,
      sourceName: 'NABC อ้างอิงในแอป',
      sourceUrl: _nabcBaseUrl,
      note:
          'ไม่สามารถดึง API สดได้ จึงแสดงราคาอ้างอิงในแอปสำหรับการสาธิตและประเมินคร่าว ๆ',
    );
  }

  /// Fetches all requested months of weekly rice prices and every API page.
  Future<WeeklyPriceSnapshot> fetchWeeklyPrices() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait(
      _weeklyMonths.map(_safeFetchWeeklyMonth),
    );
    final records = results.expand((items) => items).toList();

    if (records.isNotEmpty) {
      return WeeklyPriceSnapshot(
        records: _sortWeeklyRecords(records),
        fetchedAt: fetchedAt,
        mode: MarketPriceMode.liveApi,
        sourceName: 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
        sourceUrl: _nabcWeeklyBaseUrl,
        note:
            'ข้อมูลราคาข้าวรายสัปดาห์ ปี $_weeklyYearTh จาก API ภาครัฐ รวมเดือน 01–08 และทุกหน้าแล้ว',
      );
    }

    return WeeklyPriceSnapshot(
      records: _weeklyFallback(fetchedAt),
      fetchedAt: fetchedAt,
      mode: MarketPriceMode.referenceFallback,
      sourceName: 'NABC อ้างอิงในแอป',
      sourceUrl: _nabcWeeklyBaseUrl,
      note: 'ไม่สามารถดึงราคาสัปดาห์จาก API สดได้ จึงแสดงข้อมูลอ้างอิงในแอป',
    );
  }

  Future<List<WeeklyPriceRecord>> _safeFetchWeeklyMonth(int month) async {
    try {
      return await _fetchWeeklyMonth(month);
    } catch (_) {
      // A failed month should not hide the other months.
      return [];
    }
  }

  Future<List<WeeklyPriceRecord>> _fetchWeeklyMonth(int month) async {
    final records = <WeeklyPriceRecord>[];

    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcWeeklyBaseUrl).replace(
        queryParameters: {
          'commod': _weeklyCommodity,
          'page': '$page',
          'year_th': '$_weeklyYearTh',
          'month': month.toString().padLeft(2, '0'),
        },
      );
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) break;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = _extractRows(decoded);
      if (rows.isEmpty) break;

      for (final item in rows) {
        final map = item.cast<String, dynamic>();
        final price = _firstDouble(map, [
          'price',
          'average_price',
          'price_average',
          'avg_price',
          'price_avg',
          'weekly_price',
          'value',
          'ราคา',
          'ราคาเฉลี่ย',
        ]);
        if (price == null || price <= 0) continue;

        final unit = _firstString(map, [
              'unit',
              'price_unit',
              'unit_name',
              'หน่วย',
            ]) ??
            'บาท/กก.';
        final minPrice = _firstDouble(map, [
          'min_price',
          'price_min',
          'minimum_price',
          'ราคาต่ำสุด',
        ]);
        final maxPrice = _firstDouble(map, [
          'max_price',
          'price_max',
          'maximum_price',
          'ราคาสูงสุด',
        ]);
        final weekLabel = _firstString(map, [
              'week',
              'week_no',
              'week_number',
              'weekly',
              'สัปดาห์',
            ]) ??
            'สัปดาห์ในเดือน ${month.toString().padLeft(2, '0')}';
        final date = _firstString(map, [
          'date',
          'price_date',
          'week_date',
          'start_date',
          'วันที่',
        ]);
        final commodity = _firstString(map, [
              'commodity',
              'commod',
              'product_name',
              'name',
              'สินค้า',
            ]) ??
            _weeklyCommodity;

        records.add(
          WeeklyPriceRecord(
            commodity: commodity,
            weekLabel: weekLabel,
            pricePerKg: _normalizeToKg(price, unit),
            minPricePerKg: minPrice == null
                ? null
                : _normalizeToKg(minPrice, unit),
            maxPricePerKg: maxPrice == null
                ? null
                : _normalizeToKg(maxPrice, unit),
            unit: 'บาท/กก.',
            originalUnit: unit,
            date: date ?? 'ไม่ระบุวันที่',
            month: month,
            sourceUrl: uri.toString(),
          ),
        );
      }
    }

    return records;
  }

  List<WeeklyPriceRecord> _sortWeeklyRecords(
    List<WeeklyPriceRecord> records,
  ) {
    return [...records]
      ..sort((a, b) {
        final monthCompare = a.month.compareTo(b.month);
        if (monthCompare != 0) return monthCompare;
        return a.weekLabel.compareTo(b.weekLabel);
      });
  }

  List<WeeklyPriceRecord> _weeklyFallback(DateTime now) {
    return [
      WeeklyPriceRecord(
        commodity: _weeklyCommodity,
        weekLabel: 'ข้อมูลอ้างอิง',
        pricePerKg: 8.50,
        minPricePerKg: null,
        maxPricePerKg: null,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        date: '${now.day}/${now.month}/${now.year}',
        month: now.month,
        sourceUrl: _nabcWeeklyBaseUrl,
      ),
    ];
  }

  Future<List<CropPrice>> _fetchFromNabc() async {
    final results = await Future.wait(
      _nabcCategories.map(_safeFetchNabcCategory),
    );
    return results.expand((prices) => prices).toList();
  }

  Future<List<CropPrice>> _safeFetchNabcCategory(String category) async {
    try {
      return await _fetchNabcCategory(category);
    } catch (_) {
      // One unavailable category should not hide the other daily prices.
      return [];
    }
  }

  Future<List<CropPrice>> _fetchNabcCategory(String category) async {
    final prices = <CropPrice>[];

    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcBaseUrl).replace(
        queryParameters: {'product_category': category, 'page': '$page'},
      );
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) break;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = _extractRows(decoded);
      if (rows.isEmpty) break;

      for (final item in rows) {
        final map = item.cast<String, dynamic>();
        final name = _firstString(map, [
          'product_name',
          'product_name_th',
          'commodity_name',
          'name',
          'product',
          'สินค้า',
        ]);
        final priceRaw = _firstDouble(map, [
          'price',
          'average_price',
          'avg_price',
          'price_avg',
          'value',
          'ราคา',
        ]);
        final unit = _firstString(map, [
              'unit',
              'price_unit',
              'unit_name',
              'หน่วย',
            ]) ??
            'บาท/กก.';
        final date = _firstString(map, [
          'price_date',
          'date',
          'record_date',
          'updated_at',
          'วันที่',
        ]);
        final change = _firstDouble(map, [
          'change_percent',
          'percent_change',
          'change',
        ]);

        if (name == null || priceRaw == null) continue;
        final pricePerKg = _normalizeToKg(priceRaw, unit);
        if (pricePerKg <= 0) continue;

        prices.add(
          CropPrice(
            nameThai: name,
            pricePerKg: pricePerKg,
            unit: 'บาท/กก.',
            originalUnit: unit,
            priceDate: date ?? 'ไม่ระบุวันที่',
            changePercent: change ?? 0,
            source: 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
            sourceUrl: uri.toString(),
            sourceType: MarketPriceMode.liveApi,
            cropType: _inferCropType('$category $name'),
            confidenceLabel: 'สดจาก API',
          ),
        );
      }

      // Continue until the API returns an empty page. The hard cap above
      // prevents an accidental endless request sequence.
    }

    return prices;
  }

  List<Map> _extractRows(dynamic decoded) {
    if (decoded is List) return decoded.whereType<Map>().toList();
    if (decoded is! Map) return [];

    for (final key in ['data', 'results', 'items', 'records', 'rows']) {
      final value = decoded[key];
      if (value is List) return value.whereType<Map>().toList();
      if (value is Map) {
        final nested = _extractRows(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return [];
  }

  String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(
        value?.toString().replaceAll(',', '') ?? '',
      );
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Normalize prices to per-kg regardless of source unit.
  double _normalizeToKg(double price, String unit) {
    if (unit.contains('ตัน') || unit.contains('/t')) return price / 1000;
    if (unit.contains('100 กก') || unit.contains('/100kg')) return price / 100;
    return price;
  }

  String? _inferCropType(String nameThai) {
    if (nameThai.contains('ข้าว')) return 'rice';
    if (nameThai.contains('มันสำปะหลัง')) return 'cassava';
    if (nameThai.contains('ข้าวโพด')) return 'corn';
    if (nameThai.contains('อ้อย')) return 'sugarcane';
    if (nameThai.contains('ยาง')) return 'rubber';
    if (nameThai.contains('ปาล์ม')) return 'palm';
    if (nameThai.contains('ทุเรียน')) return 'durian';
    return null;
  }

  List<CropPrice> _sortByName(List<CropPrice> prices) {
    return [...prices]..sort((a, b) => a.nameThai.compareTo(b.nameThai));
  }

  /// Static reference prices for offline demo and API fallback.
  List<CropPrice> _staticPrices(DateTime now) {
    final dateStr = '${now.day}/${now.month}/${now.year} (ราคาอ้างอิง)';

    return [
      CropPrice(
        nameThai: 'ข้าวเปลือกเจ้า 5%',
        pricePerKg: 8.50,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: 0.8,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'rice',
        yieldPerRai: 400,
        season: 'นาปี / นาปรัง',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'มันสำปะหลัง (25% แป้ง)',
        pricePerKg: 2.80,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: -1.2,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'cassava',
        yieldPerRai: 3500,
        season: 'ปีละครั้ง',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'มันสำปะหลัง (30% แป้ง)',
        pricePerKg: 3.10,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: -0.5,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'cassava',
        yieldPerRai: 3200,
        season: 'ปีละครั้ง',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'ข้าวโพดเลี้ยงสัตว์ (14.5%)',
        pricePerKg: 8.80,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: 2.1,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'corn',
        yieldPerRai: 800,
        season: 'ปีละ 2 ครั้ง',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'อ้อยโรงงาน',
        pricePerKg: 1.10,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: 0.2,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'sugarcane',
        yieldPerRai: 10000,
        season: 'ปีละครั้ง',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'ยางพาราแผ่นดิบ',
        pricePerKg: 60.0,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: 1.5,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'rubber',
        yieldPerRai: 300,
        season: 'กรีด 8 เดือน/ปี',
        confidenceLabel: 'อ้างอิง',
      ),
      CropPrice(
        nameThai: 'ปาล์มน้ำมัน (ทะลายสด)',
        pricePerKg: 5.20,
        unit: 'บาท/กก.',
        originalUnit: 'บาท/กก.',
        priceDate: dateStr,
        changePercent: -0.8,
        source: 'NABC อ้างอิงในแอป',
        sourceUrl: _nabcBaseUrl,
        sourceType: MarketPriceMode.referenceFallback,
        cropType: 'palm',
        yieldPerRai: 2800,
        season: 'ทุก 15-20 วัน',
        confidenceLabel: 'อ้างอิง',
      ),
    ];
  }
}

enum MarketPriceMode { liveApi, referenceFallback }

class MarketPriceSnapshot {
  final List<CropPrice> prices;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const MarketPriceSnapshot({
    required this.prices,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class WeeklyPriceSnapshot {
  final List<WeeklyPriceRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const WeeklyPriceSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class WeeklyPriceRecord {
  final String commodity;
  final String weekLabel;
  final double pricePerKg;
  final double? minPricePerKg;
  final double? maxPricePerKg;
  final String unit;
  final String originalUnit;
  final String date;
  final int month;
  final String sourceUrl;

  const WeeklyPriceRecord({
    required this.commodity,
    required this.weekLabel,
    required this.pricePerKg,
    required this.minPricePerKg,
    required this.maxPricePerKg,
    required this.unit,
    required this.originalUnit,
    required this.date,
    required this.month,
    required this.sourceUrl,
  });
}

class CropPrice {
  final String nameThai;
  final double pricePerKg;
  final String unit;
  final String originalUnit;
  final String priceDate;
  final double changePercent;
  final String source;
  final String sourceUrl;
  final MarketPriceMode sourceType;
  final String? cropType;
  final double? yieldPerRai;
  final String? season;
  final String confidenceLabel;

  const CropPrice({
    required this.nameThai,
    required this.pricePerKg,
    required this.unit,
    required this.originalUnit,
    required this.priceDate,
    required this.changePercent,
    required this.source,
    required this.sourceUrl,
    required this.sourceType,
    required this.confidenceLabel,
    this.cropType,
    this.yieldPerRai,
    this.season,
  });

  double revenuePerRai() => (yieldPerRai ?? 0) * pricePerKg;
}
