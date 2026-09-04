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

  final Map<String, Future<dynamic>> _snapshotCache = {};

  void clearCache() => _snapshotCache.clear();

  Future<T> _cached<T>(String key, Future<T> Function() loader) {
    final cached = _snapshotCache[key];
    if (cached != null) return cached.then((value) => value as T);
    final future = loader();
    _snapshotCache[key] = future;
    return future;
  }

  static const _nabcBaseUrl =
      'https://agriapi.nabc.go.th/api/daily-prices/category';
  static const _nabcWeeklyBaseUrl =
      'https://agriapi.nabc.go.th/api/weekly-prices/commod';
  static const _nabcWeeklyYearMonthBaseUrl =
      'https://agriapi.nabc.go.th/api/weekly-prices/year-month';
  static const _nabcMonthlyBaseUrl =
      'https://agriapi.nabc.go.th/api/monthly-prices/commod';
  static const _nabcProductionBaseUrl =
      'https://agriapi.nabc.go.th/api/production/search';
  static const _nabcProductionIndexBaseUrl =
      'https://agriapi.nabc.go.th/api/production-index-month/category';
  static const _nabcProductionIndexYearBaseUrl =
      'https://agriapi.nabc.go.th/api/production-index-year/category';
  static const _nabcProductionIndexQuarterBaseUrl =
      'https://agriapi.nabc.go.th/api/production-index-quarter/category';
  static const _nabcPriceIndexBaseUrl =
      'https://agriapi.nabc.go.th/api/price-index-month/category';
  static const _nabcQuarterPriceIndexBaseUrl =
      'https://agriapi.nabc.go.th/api/price-index-quarter/category';
  static const _nabcYearPriceIndexBaseUrl =
      'https://agriapi.nabc.go.th/api/price-index-year/category';
  static const _weeklyCommodities = <String>[
    'ข้าว',
    'ข้าวโพดเลี้ยงสัตว์',
    'เงาะ',
    'ทุเรียน',
    'ปาล์มน้ำมัน',
    'พริกไทย',
    'มะพร้าว',
    'มันสำปะหลัง',
    'ยางพารา',
    'ลำไย',
    'สับปะรด',
  ];
  static const _weeklyYearTh = 2569;
  static const _weeklyYears = <int>[2568, 2569];
  static const _weeklyMonths = <int>[1, 2, 3, 4, 5, 6, 7, 8];
  static const _monthlyCommodities = <String>[
    'ข้าว',
    'ข้าวโพดเลี้ยงสัตว์',
    'เงาะ',
    'ปาล์มน้ำมัน',
    'ทุเรียน',
    'พริกไทย',
    'มะพร้าว',
    'มันสำปะหลัง',
    'ลำไย',
    'สับปะรด',
  ];
  static const _monthlyYearTh = 2569;
  static const _monthlyYears = <int>[2568, 2569];
  static const _productionYearTh = 2569;
  static const _productionYears = <int>[2567, 2568, 2569];
  static const _productionCommodities = <String>[
    'ข้าว',
    'ข้าวโพดเลี้ยงสัตว์',
    'ถั่วเหลือง',
    'ทุเรียน',
    'ปาล์มน้ำมัน',
    'มันสำปะหลัง',
    'ยางพารา',
    'สับปะรด',
  ];
  static const _productionIndexYears = <int>[2568, 2569];
  static const _priceIndexYears = <int>[2568, 2569];
  static const _priceIndexQuarters = <int>[1, 2, 3, 4];
  static const _quarterPriceIndexYears = <int>[2568, 2569];
  static const _yearPriceIndexYears = <int>[2568, 2569];
  static const _productionIndexAnnualYears = <int>[2567, 2568];
  static const _productionIndexQuarterYears = <int>[2567, 2568, 2569];
  static const _productionIndexQuarters = <int>[1, 2, 3, 4];
  static const _productionIndexMonths = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
  ];

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

  // NABC returns pagination metadata, so requests stop as soon as the API
  // reports that all rows have been read. This cap prevents an unhealthy API
  // response from creating an unbounded request loop.
  static const _maxPagesPerCategory = 100;

  /// Fetch farm-gate prices with source metadata for display.
  Future<MarketPriceSnapshot> fetchFarmGatePrices() {
    return _cached('daily-prices', _fetchFarmGatePrices);
  }

  Future<MarketPriceSnapshot> _fetchFarmGatePrices() async {
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
  Future<WeeklyPriceSnapshot> fetchWeeklyPrices() {
    return _cached('weekly-prices-2568-2569', _fetchWeeklyPrices);
  }

  Future<WeeklyPriceSnapshot> _fetchWeeklyPrices() async {
    final fetchedAt = DateTime.now();
    final requests = [
      for (final year in _weeklyYears)
        for (final month in _weeklyMonths)
          _safeFetchWeeklyYearMonth(year, month),
    ];
    final results = await Future.wait(requests);
    final records = results.expand((items) => items).toList();

    if (records.isNotEmpty) {
      return WeeklyPriceSnapshot(
        records: _sortWeeklyRecords(records),
        fetchedAt: fetchedAt,
        mode: MarketPriceMode.liveApi,
        sourceName: 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
        sourceUrl: _nabcWeeklyBaseUrl,
        note:
            'ข้อมูลราคารายสัปดาห์ ปี 2568–2569 จาก API ภาครัฐ รวมเดือน 01–08 และทุกหน้าแล้ว',
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

  Future<List<WeeklyPriceRecord>> _safeFetchWeeklyYearMonth(
    int year,
    int month,
  ) async {
    try {
      return await _fetchWeeklyYearMonth(year, month);
    } catch (_) {
      return [];
    }
  }

  Future<List<WeeklyPriceRecord>> _fetchWeeklyYearMonth(
    int year,
    int month,
  ) async {
    final records = <WeeklyPriceRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcWeeklyYearMonthBaseUrl).replace(
        queryParameters: {
          'year_th': '$year',
          'month': month.toString().padLeft(2, '0'),
          'page': '$page',
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
        final price = _firstDouble(map, ['value', 'price', 'weekly_price']);
        if (price == null || price <= 0) continue;
        final unit =
            _firstString(map, ['unit', 'price_unit', 'หน่วย']) ?? 'บาท/กก.';
        final category = _firstString(map, ['commod', 'commodity']);
        if (category == null || !_weeklyCommodities.contains(category))
          continue;
        records.add(
          WeeklyPriceRecord(
            commodity:
                _firstString(map, [
                  'product_name',
                  'subcommod',
                  'name',
                  'สินค้า',
                ]) ??
                category,
            commodityCategory: category,
            weekLabel:
                'สัปดาห์ ${_firstString(map, ['week', 'week_no']) ?? '-'}',
            pricePerKg: _normalizeToKg(price, unit),
            minPricePerKg: null,
            maxPricePerKg: null,
            unit: 'บาท/กก.',
            originalUnit: unit,
            date: _firstString(map, ['date', 'data_date']) ?? 'ไม่ระบุวันที่',
            month: month,
            year: year,
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<MonthlyPriceSnapshot> fetchMonthlyPrices() {
    return _cached('monthly-prices-2568-2569', _fetchMonthlyPrices);
  }

  Future<MonthlyPriceSnapshot> _fetchMonthlyPrices() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait([
      for (final year in _monthlyYears)
        for (final commodity in _monthlyCommodities)
          _safeFetchMonthlyCommodity(commodity, year),
    ]);
    final records = results.expand((items) => items).toList();

    if (records.isNotEmpty) {
      return MonthlyPriceSnapshot(
        records: _sortMonthlyRecords(records),
        fetchedAt: fetchedAt,
        mode: MarketPriceMode.liveApi,
        sourceName: 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
        sourceUrl: _nabcMonthlyBaseUrl,
        note:
            'ข้อมูลราคาสินค้าเกษตรรายเดือน ปี $_monthlyYearTh จาก API ภาครัฐ รวมทุกหน้าแล้ว',
      );
    }

    return MonthlyPriceSnapshot(
      records: _monthlyFallback(),
      fetchedAt: fetchedAt,
      mode: MarketPriceMode.referenceFallback,
      sourceName: 'NABC อ้างอิงในแอป',
      sourceUrl: _nabcMonthlyBaseUrl,
      note: 'ไม่สามารถดึงราคารายเดือนจาก API สดได้ จึงแสดงข้อมูลอ้างอิงในแอป',
    );
  }

  Future<ProductionSnapshot> fetchProduction() {
    return _cached('production-2567-2569', _fetchProduction);
  }

  Future<ProductionSnapshot> _fetchProduction() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait([
      for (final year in _productionYears)
        for (final commodity in _productionCommodities)
          _safeFetchProductionCommodity(commodity, year),
    ]);
    final records = results.expand((items) => items).toList();
    return ProductionSnapshot(
      records: _sortProductionRecords(records),
      fetchedAt: fetchedAt,
      mode: records.isEmpty
          ? MarketPriceMode.referenceFallback
          : MarketPriceMode.liveApi,
      sourceName: records.isEmpty
          ? 'NABC ยังไม่มีข้อมูลปี $_productionYearTh'
          : 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
      sourceUrl: _nabcProductionBaseUrl,
      note: records.isEmpty
          ? 'API ยังไม่พบข้อมูลปริมาณการผลิตปี $_productionYearTh จึงยังไม่มีรายการให้แสดง'
          : 'ข้อมูลปริมาณการผลิตปี $_productionYearTh จาก API ภาครัฐ รวมทุกหน้าแล้ว',
    );
  }

  Future<ProductionIndexSnapshot> fetchProductionIndex() {
    return _cached('production-indexes', _fetchProductionIndex);
  }

  Future<ProductionIndexSnapshot> _fetchProductionIndex() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait([
      for (final year in _productionIndexYears)
        for (final month in _productionIndexMonths)
          _safeFetchProductionIndexMonth(year, month),
    ]);
    final records = results.expand((items) => items).toList();
    final annualResults = await Future.wait(
      _productionIndexAnnualYears.map(_safeFetchProductionIndexYear),
    );
    final annualRecords = annualResults.expand((items) => items).toList();
    final quarterResults = await Future.wait([
      for (final year in _productionIndexQuarterYears)
        for (final quarter in _productionIndexQuarters)
          _safeFetchProductionIndexQuarter(year, quarter),
    ]);
    final quarterlyRecords = quarterResults.expand((items) => items).toList();
    return ProductionIndexSnapshot(
      records: _sortProductionIndexRecords(records),
      annualRecords: _sortProductionIndexRecords(annualRecords),
      quarterlyRecords: [...quarterlyRecords]
        ..sort(
          (a, b) => a.year == b.year
              ? a.quarter.compareTo(b.quarter)
              : a.year.compareTo(b.year),
        ),
      fetchedAt: fetchedAt,
      mode: records.isEmpty
          ? MarketPriceMode.referenceFallback
          : MarketPriceMode.liveApi,
      sourceName: records.isEmpty
          ? 'NABC ยังไม่มีข้อมูลดัชนี'
          : 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
      sourceUrl: _nabcProductionIndexBaseUrl,
      note: records.isEmpty
          ? 'ยังไม่พบข้อมูลดัชนีผลผลิตในปี 2569'
          : 'ดัชนีผลผลิตสินค้าเกษตรรายเดือน ปี 2568–2569 จาก API ภาครัฐ รวมทุกหน้าแล้ว',
    );
  }

  Future<List<ProductionQuarterIndexRecord>> _safeFetchProductionIndexQuarter(
    int year,
    int quarter,
  ) async {
    try {
      return await _fetchProductionIndexQuarter(year, quarter);
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductionQuarterIndexRecord>> _fetchProductionIndexQuarter(
    int year,
    int quarter,
  ) async {
    final records = <ProductionQuarterIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcProductionIndexQuarterBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'quarter': '$quarter',
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, ['production_index', 'index', 'value']);
        if (index == null) continue;
        records.add(
          ProductionQuarterIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            quarter:
                int.tryParse(_firstString(map, ['quarter', 'ไตรมาส']) ?? '') ??
                quarter,
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<PriceIndexSnapshot> fetchPriceIndex() {
    return _cached('price-indexes-monthly', _fetchPriceIndex);
  }

  Future<PriceIndexSnapshot> _fetchPriceIndex() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait([
      for (final year in _priceIndexYears)
        for (final month in _productionIndexMonths)
          _safeFetchPriceIndexMonth(year, month),
    ]);
    final records = results.expand((items) => items).toList();
    return PriceIndexSnapshot(
      records: [...records]
        ..sort(
          (a, b) => a.year == b.year
              ? a.month.compareTo(b.month)
              : a.year.compareTo(b.year),
        ),
      fetchedAt: fetchedAt,
      mode: records.isEmpty
          ? MarketPriceMode.referenceFallback
          : MarketPriceMode.liveApi,
      sourceName: records.isEmpty
          ? 'NABC ยังไม่มีข้อมูลดัชนีราคา'
          : 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
      sourceUrl: _nabcPriceIndexBaseUrl,
      note: records.isEmpty
          ? 'ยังไม่พบข้อมูลดัชนีราคาสินค้าเกษตรในปี 2569'
          : 'ดัชนีราคาสินค้าเกษตรรายเดือน ปี 2568–2569 จาก API ภาครัฐ รวมทุกหน้าแล้ว',
    );
  }

  Future<QuarterPriceIndexSnapshot> fetchQuarterPriceIndex() {
    return _cached('price-indexes-quarterly', _loadQuarterPriceIndex);
  }

  Future<QuarterPriceIndexSnapshot> _loadQuarterPriceIndex() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait([
      for (final year in _quarterPriceIndexYears)
        for (final quarter in _priceIndexQuarters)
          _safeFetchQuarterPriceIndex(year, quarter),
    ]);
    final records = results.expand((items) => items).toList();
    return QuarterPriceIndexSnapshot(
      records: [...records]
        ..sort(
          (a, b) => a.year == b.year
              ? a.quarter.compareTo(b.quarter)
              : a.year.compareTo(b.year),
        ),
      fetchedAt: fetchedAt,
      mode: records.isEmpty
          ? MarketPriceMode.referenceFallback
          : MarketPriceMode.liveApi,
      sourceName: records.isEmpty
          ? 'NABC ยังไม่มีข้อมูลดัชนีราคารายไตรมาส'
          : 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
      sourceUrl: _nabcQuarterPriceIndexBaseUrl,
      note: records.isEmpty
          ? 'ยังไม่พบข้อมูลดัชนีราคารายไตรมาสปี 2568'
          : 'ดัชนีราคาสินค้าเกษตรรายไตรมาส ปี 2568–2569 จาก API ภาครัฐ รวมทุกหน้าแล้ว',
    );
  }

  Future<YearPriceIndexSnapshot> fetchYearPriceIndex() {
    return _cached('price-indexes-yearly', _loadYearPriceIndex);
  }

  Future<YearPriceIndexSnapshot> _loadYearPriceIndex() async {
    final fetchedAt = DateTime.now();
    final results = await Future.wait(
      _yearPriceIndexYears.map(_safeFetchYearPriceIndex),
    );
    final records = results.expand((items) => items).toList();
    return YearPriceIndexSnapshot(
      records: [...records]..sort((a, b) => a.year.compareTo(b.year)),
      fetchedAt: fetchedAt,
      mode: records.isEmpty
          ? MarketPriceMode.referenceFallback
          : MarketPriceMode.liveApi,
      sourceName: records.isEmpty
          ? 'NABC ยังไม่มีข้อมูลดัชนีราคารายปี'
          : 'NABC (ศูนย์ข้อมูลเกษตรแห่งชาติ)',
      sourceUrl: _nabcYearPriceIndexBaseUrl,
      note: records.isEmpty
          ? 'ยังไม่พบข้อมูลดัชนีราคารายปี'
          : 'ดัชนีราคาสินค้าเกษตรรายปี ปี 2568–2569 จาก API ภาครัฐ รวมทุกหน้าแล้ว',
    );
  }

  Future<List<YearPriceIndexRecord>> _safeFetchYearPriceIndex(int year) async {
    try {
      return await _fetchYearPriceIndex(year);
    } catch (_) {
      return [];
    }
  }

  Future<List<YearPriceIndexRecord>> _fetchYearPriceIndex(int year) async {
    final records = <YearPriceIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcYearPriceIndexBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, ['price_index', 'index', 'value']);
        if (index == null) continue;
        records.add(
          YearPriceIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<List<QuarterPriceIndexRecord>> _safeFetchQuarterPriceIndex(
    int year,
    int quarter,
  ) async {
    try {
      return await _fetchQuarterPriceIndex(year, quarter);
    } catch (_) {
      return [];
    }
  }

  Future<List<QuarterPriceIndexRecord>> _fetchQuarterPriceIndex(
    int year,
    int quarter,
  ) async {
    final records = <QuarterPriceIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcQuarterPriceIndexBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'quarter': '$quarter',
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, ['price_index', 'index', 'value']);
        if (index == null) continue;
        records.add(
          QuarterPriceIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            quarter:
                int.tryParse(_firstString(map, ['quarter', 'ไตรมาส']) ?? '') ??
                quarter,
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<List<PriceIndexRecord>> _safeFetchPriceIndexMonth(
    int year,
    int month,
  ) async {
    try {
      return await _fetchPriceIndexMonth(year, month);
    } catch (_) {
      return [];
    }
  }

  Future<List<PriceIndexRecord>> _fetchPriceIndexMonth(
    int year,
    int month,
  ) async {
    final records = <PriceIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcPriceIndexBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'month': month.toString().padLeft(2, '0'),
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, ['price_index', 'index', 'value']);
        if (index == null) continue;
        records.add(
          PriceIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            month:
                int.tryParse(_firstString(map, ['month', 'เดือน']) ?? '') ??
                month,
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<List<ProductionIndexRecord>> _safeFetchProductionIndexYear(
    int year,
  ) async {
    try {
      return await _fetchProductionIndexYear(year);
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductionIndexRecord>> _fetchProductionIndexYear(
    int year,
  ) async {
    final records = <ProductionIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcProductionIndexYearBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, ['production_index', 'index', 'value']);
        if (index == null) continue;
        records.add(
          ProductionIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            month: 0,
            category:
                _firstString(map, ['product_category', 'product_name']) ??
                'หมวดพืชผลสำคัญ',
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  Future<List<ProductionIndexRecord>> _safeFetchProductionIndexMonth(
    int year,
    int month,
  ) async {
    try {
      return await _fetchProductionIndexMonth(year, month);
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductionIndexRecord>> _fetchProductionIndexMonth(
    int year,
    int month,
  ) async {
    final records = <ProductionIndexRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcProductionIndexBaseUrl).replace(
        queryParameters: {
          'page': '$page',
          'year_th': '$year',
          'month': month.toString().padLeft(2, '0'),
          'product_category': 'หมวดพืชผลสำคัญ',
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
        final index = _firstDouble(map, [
          'production_index',
          'index',
          'value',
          'ดัชนีผลผลิต',
        ]);
        if (index == null) continue;
        records.add(
          ProductionIndexRecord(
            year:
                int.tryParse(_firstString(map, ['year_th', 'year']) ?? '') ??
                year,
            month:
                int.tryParse(_firstString(map, ['month', 'เดือน']) ?? '') ??
                month,
            category:
                _firstString(map, [
                  'product_category',
                  'product_group',
                  'product_name',
                ]) ??
                'หมวดพืชผลสำคัญ',
            index: index,
            date: _firstString(map, ['data_date', 'date']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  List<ProductionIndexRecord> _sortProductionIndexRecords(
    List<ProductionIndexRecord> records,
  ) {
    return [...records]..sort(
      (a, b) => a.year == b.year
          ? a.month.compareTo(b.month)
          : a.year.compareTo(b.year),
    );
  }

  Future<List<ProductionRecord>> _safeFetchProductionCommodity(
    String commodity,
    int year,
  ) async {
    try {
      return await _fetchProductionCommodity(commodity, year);
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductionRecord>> _fetchProductionCommodity(
    String commodity,
    int year,
  ) async {
    final records = <ProductionRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcProductionBaseUrl).replace(
        queryParameters: {
          'commod': commodity,
          'year': '$year',
          'api_type': '1',
          'page': '$page',
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
        records.add(
          ProductionRecord(
            commodity: _firstString(map, ['commod', 'commodity']) ?? commodity,
            subCommodity:
                _firstString(map, ['subcommod', 'variety', 'sub_commod']) ??
                '-',
            province:
                _firstString(map, ['province_name', 'province']) ??
                'ไม่ระบุพื้นที่',
            year:
                _firstString(map, ['year_th', 'year_crop', 'year']) ??
                '$_productionYearTh',
            areaPlant: _firstDouble(map, ['area_plant', 'plant_area']),
            areaHarvest: _firstDouble(map, ['area_harvest', 'harvest_area']),
            production: _firstDouble(map, [
              'production',
              'product_amount',
              'output',
            ]),
            yieldPlant: _firstDouble(map, ['yield_plant']),
            yieldHarvest: _firstDouble(map, ['yield_harvest']),
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  List<ProductionRecord> _sortProductionRecords(
    List<ProductionRecord> records,
  ) {
    return [...records]..sort(
      (a, b) => a.commodity == b.commodity
          ? a.province.compareTo(b.province)
          : a.commodity.compareTo(b.commodity),
    );
  }

  Future<List<MonthlyPriceRecord>> _safeFetchMonthlyCommodity(
    String commodity,
    int year,
  ) async {
    try {
      return await _fetchMonthlyCommodity(commodity, year);
    } catch (_) {
      return [];
    }
  }

  Future<List<MonthlyPriceRecord>> _fetchMonthlyCommodity(
    String commodity,
    int year,
  ) async {
    final records = <MonthlyPriceRecord>[];
    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcMonthlyBaseUrl).replace(
        queryParameters: {
          'commod': commodity,
          'page': '$page',
          'year_th': '$year',
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
        final price = _firstDouble(map, ['value', 'price', 'monthly_price']);
        if (price == null || price <= 0) continue;
        final unit =
            _firstString(map, ['unit', 'price_unit', 'หน่วย']) ?? 'บาท/กก.';
        final monthValue = _firstString(map, ['month', 'เดือน']);
        final month = int.tryParse(monthValue ?? '') ?? 0;
        if (month <= 0) continue;
        records.add(
          MonthlyPriceRecord(
            year: year,
            commodity:
                _firstString(map, [
                  'product_name',
                  'subcommod',
                  'name',
                  'สินค้า',
                ]) ??
                commodity,
            commodityCategory:
                _firstString(map, ['commod', 'commodity']) ?? commodity,
            month: month,
            pricePerKg: _normalizeToKg(price, unit),
            unit: 'บาท/กก.',
            originalUnit: unit,
            sourceUrl: uri.toString(),
          ),
        );
      }
      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }
    return records;
  }

  List<MonthlyPriceRecord> _sortMonthlyRecords(
    List<MonthlyPriceRecord> records,
  ) {
    return [...records]..sort(
      (a, b) => a.month == b.month
          ? a.commodity.compareTo(b.commodity)
          : a.month.compareTo(b.month),
    );
  }

  List<MonthlyPriceRecord> _monthlyFallback() {
    const prices = <String, double>{
      'ข้าว': 8.50,
      'ข้าวโพดเลี้ยงสัตว์': 8.80,
      'เงาะ': 28.00,
      'ปาล์มน้ำมัน': 5.20,
      'ทุเรียน': 120.00,
      'พริกไทย': 180.00,
      'มะพร้าว': 18.00,
      'มันสำปะหลัง': 2.80,
      'ลำไย': 35.00,
      'สับปะรด': 12.00,
    };
    return [
      for (final entry in prices.entries)
        for (var month = 1; month <= 8; month++)
          MonthlyPriceRecord(
            commodity: entry.key,
            commodityCategory: entry.key,
            month: month,
            pricePerKg: entry.value,
            unit: 'บาท/กก.',
            originalUnit: 'บาท/กก.',
            sourceUrl: _nabcMonthlyBaseUrl,
          ),
    ];
  }

  Future<List<WeeklyPriceRecord>> _safeFetchWeeklyMonth(
    String commodity,
    int month,
  ) async {
    try {
      return await _fetchWeeklyMonth(commodity, month);
    } catch (_) {
      // A failed month should not hide the other months.
      return [];
    }
  }

  Future<List<WeeklyPriceRecord>> _fetchWeeklyMonth(
    String commodity,
    int month,
  ) async {
    final records = <WeeklyPriceRecord>[];

    for (var page = 1; page <= _maxPagesPerCategory; page++) {
      final uri = Uri.parse(_nabcWeeklyBaseUrl).replace(
        queryParameters: {
          'commod': commodity,
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

        final unit =
            _firstString(map, ['unit', 'price_unit', 'unit_name', 'หน่วย']) ??
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
        final weekLabel =
            _firstString(map, [
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
        final category =
            _firstString(map, ['commod', 'commodity']) ?? commodity;
        final product =
            _firstString(map, [
              'product_name',
              'subcommod',
              'name',
              'สินค้า',
            ]) ??
            category;

        records.add(
          WeeklyPriceRecord(
            commodity: product,
            commodityCategory: category,
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

      if (!_weeklyHasMorePages(decoded, page, rows.length)) break;
    }

    return records;
  }

  bool _weeklyHasMorePages(dynamic decoded, int page, int rowCount) {
    if (decoded is Map && decoded['pagination'] is Map) {
      final pagination = (decoded['pagination'] as Map).cast<String, dynamic>();
      final total = _firstDouble(pagination, ['total']);
      final offset = _firstDouble(pagination, ['offset']);
      final count = _firstDouble(pagination, ['count']) ?? rowCount.toDouble();
      if (total != null) {
        final currentOffset = offset ?? ((page - 1) * 100).toDouble();
        return currentOffset + count < total;
      }
    }
    return rowCount > 0;
  }

  bool _hasMorePages(dynamic decoded, int page, int rowCount) {
    if (decoded is Map && decoded['pagination'] is Map) {
      final pagination = (decoded['pagination'] as Map).cast<String, dynamic>();
      final total = _firstDouble(pagination, ['total']);
      final offset = _firstDouble(pagination, ['offset']);
      final count = _firstDouble(pagination, ['count']) ?? rowCount.toDouble();
      if (total != null) {
        final currentOffset = offset ?? ((page - 1) * 100).toDouble();
        return currentOffset + count < total;
      }
    }
    return rowCount > 0;
  }

  List<WeeklyPriceRecord> _sortWeeklyRecords(List<WeeklyPriceRecord> records) {
    return [...records]..sort((a, b) {
      final monthCompare = a.month.compareTo(b.month);
      if (monthCompare != 0) return monthCompare;
      return a.weekLabel.compareTo(b.weekLabel);
    });
  }

  List<WeeklyPriceRecord> _weeklyFallback(DateTime now) {
    return [
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ข้าวเปลือกเจ้า',
          commodityCategory: 'ข้าว',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 8.50,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'เงาะ',
          commodityCategory: 'เงาะ',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 28.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ทุเรียน',
          commodityCategory: 'ทุเรียน',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 120.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ปาล์มน้ำมัน',
          commodityCategory: 'ปาล์มน้ำมัน',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 5.20,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'พริกไทย',
          commodityCategory: 'พริกไทย',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 180.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'มะพร้าว',
          commodityCategory: 'มะพร้าว',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 18.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'มันสำปะหลัง',
          commodityCategory: 'มันสำปะหลัง',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 2.80,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ยางพารา',
          commodityCategory: 'ยางพารา',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 60.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ลำไย',
          commodityCategory: 'ลำไย',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 35.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'สับปะรด',
          commodityCategory: 'สับปะรด',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 12.00,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
          sourceUrl: _nabcWeeklyBaseUrl,
        ),
      for (var month = 1; month <= 8; month++)
        WeeklyPriceRecord(
          commodity: 'ข้าวโพดเลี้ยงสัตว์',
          commodityCategory: 'ข้าวโพดเลี้ยงสัตว์',
          weekLabel: 'ข้อมูลอ้างอิง',
          pricePerKg: 8.80,
          minPricePerKg: null,
          maxPricePerKg: null,
          unit: 'บาท/กก.',
          originalUnit: 'บาท/กก.',
          date: '${now.day}/${now.month}/${now.year}',
          month: month,
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
          'day_price',
          'average_price',
          'avg_price',
          'price_avg',
          'value',
          'ราคา',
        ]);
        final unit =
            _firstString(map, ['unit', 'price_unit', 'unit_name', 'หน่วย']) ??
            'บาท/กก.';
        final date = _firstString(map, [
          'price_date',
          'data_date',
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

      if (!_hasMorePages(decoded, page, rows.length)) break;

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

class MonthlyPriceSnapshot {
  final List<MonthlyPriceRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const MonthlyPriceSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class MonthlyPriceRecord {
  final int year;
  final String commodity;
  final String commodityCategory;
  final int month;
  final double pricePerKg;
  final String unit;
  final String originalUnit;
  final String sourceUrl;

  const MonthlyPriceRecord({
    this.year = 2569,
    required this.commodity,
    required this.commodityCategory,
    required this.month,
    required this.pricePerKg,
    required this.unit,
    required this.originalUnit,
    required this.sourceUrl,
  });
}

class ProductionSnapshot {
  final List<ProductionRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const ProductionSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class ProductionRecord {
  final String commodity;
  final String subCommodity;
  final String province;
  final String year;
  final double? areaPlant;
  final double? areaHarvest;
  final double? production;
  final double? yieldPlant;
  final double? yieldHarvest;
  final String sourceUrl;

  const ProductionRecord({
    required this.commodity,
    required this.subCommodity,
    required this.province,
    required this.year,
    required this.areaPlant,
    required this.areaHarvest,
    required this.production,
    required this.yieldPlant,
    required this.yieldHarvest,
    required this.sourceUrl,
  });
}

class ProductionIndexSnapshot {
  final List<ProductionIndexRecord> records;
  final List<ProductionIndexRecord> annualRecords;
  final List<ProductionQuarterIndexRecord> quarterlyRecords;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const ProductionIndexSnapshot({
    required this.records,
    required this.annualRecords,
    required this.quarterlyRecords,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class ProductionIndexRecord {
  final int year;
  final int month;
  final String category;
  final double index;
  final String? date;
  final String sourceUrl;

  const ProductionIndexRecord({
    required this.year,
    required this.month,
    required this.category,
    required this.index,
    required this.date,
    required this.sourceUrl,
  });
}

class ProductionQuarterIndexRecord {
  final int year;
  final int quarter;
  final double index;
  final String? date;
  final String sourceUrl;

  const ProductionQuarterIndexRecord({
    required this.year,
    required this.quarter,
    required this.index,
    required this.date,
    required this.sourceUrl,
  });
}

class PriceIndexSnapshot {
  final List<PriceIndexRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const PriceIndexSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class PriceIndexRecord {
  final int year;
  final int month;
  final double index;
  final String? date;
  final String sourceUrl;

  const PriceIndexRecord({
    required this.year,
    required this.month,
    required this.index,
    required this.date,
    required this.sourceUrl,
  });
}

class QuarterPriceIndexSnapshot {
  final List<QuarterPriceIndexRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const QuarterPriceIndexSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class QuarterPriceIndexRecord {
  final int year;
  final int quarter;
  final double index;
  final String? date;
  final String sourceUrl;

  const QuarterPriceIndexRecord({
    required this.year,
    required this.quarter,
    required this.index,
    required this.date,
    required this.sourceUrl,
  });
}

class YearPriceIndexSnapshot {
  final List<YearPriceIndexRecord> records;
  final DateTime fetchedAt;
  final MarketPriceMode mode;
  final String sourceName;
  final String sourceUrl;
  final String note;

  const YearPriceIndexSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.mode,
    required this.sourceName,
    required this.sourceUrl,
    required this.note,
  });

  bool get isLive => mode == MarketPriceMode.liveApi;
}

class YearPriceIndexRecord {
  final int year;
  final double index;
  final String? date;
  final String sourceUrl;

  const YearPriceIndexRecord({
    required this.year,
    required this.index,
    required this.date,
    required this.sourceUrl,
  });
}

class WeeklyPriceRecord {
  final int year;
  final String commodity;
  final String commodityCategory;
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
    this.year = 2569,
    required this.commodity,
    required this.commodityCategory,
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
