import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:chaona_app/features/market/data/services/market_price_service.dart';

final marketPricesProvider = FutureProvider<MarketPriceSnapshot>((ref) async {
  return MarketPriceService().fetchFarmGatePrices();
});

final weeklyPricesProvider = FutureProvider<WeeklyPriceSnapshot>((ref) async {
  return MarketPriceService().fetchWeeklyPrices();
});

final monthlyPricesProvider = FutureProvider<MonthlyPriceSnapshot>((ref) async {
  return MarketPriceService().fetchMonthlyPrices();
});

final productionProvider = FutureProvider<ProductionSnapshot>((ref) async {
  return MarketPriceService().fetchProduction();
});

final productionIndexProvider = FutureProvider<ProductionIndexSnapshot>((
  ref,
) async {
  return MarketPriceService().fetchProductionIndex();
});

final priceIndexProvider = FutureProvider<PriceIndexSnapshot>((ref) async {
  return MarketPriceService().fetchPriceIndex();
});

final quarterPriceIndexProvider = FutureProvider<QuarterPriceIndexSnapshot>((
  ref,
) async {
  return MarketPriceService().fetchQuarterPriceIndex();
});

final yearPriceIndexProvider = FutureProvider<YearPriceIndexSnapshot>((
  ref,
) async {
  return MarketPriceService().fetchYearPriceIndex();
});

enum _MarketSort { name, priceHigh, priceLow, changeHigh }

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _searchCtrl = TextEditingController();

  CropPrice? _selectedCrop;
  double _quantityKg = 1000;
  bool _loadingAI = false;
  String? _aiAdvice;
  String _cropFilter = 'all';
  String _nameFilter = 'all';
  String _weeklyCommodity = 'ข้าว';
  int _weeklyYear = 2569;
  int _weeklyMonth = 1;
  String _monthlyCommodity = 'ข้าว';
  int _monthlyYear = 2569;
  int _monthlyMonth = 1;
  String _productionCommodity = 'ข้าว';
  int _productionYear = 2569;
  String _productionProvince = '';
  String _costCrop = 'ข้าว';
  final Map<String, TextEditingController> _costControllers = {
    'area': TextEditingController(text: '1'),
    'yield': TextEditingController(text: '1000'),
    'price': TextEditingController(text: '10'),
    'seed': TextEditingController(text: '500'),
    'fertilizer': TextEditingController(text: '1200'),
    'chemical': TextEditingController(text: '400'),
    'labor': TextEditingController(text: '1500'),
    'water': TextEditingController(text: '300'),
    'fuel': TextEditingController(text: '300'),
    'rent': TextEditingController(text: '800'),
    'transport': TextEditingController(text: '300'),
    'other': TextEditingController(text: '200'),
  };
  _MarketSort _sort = _MarketSort.name;

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final controller in _costControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final pricesAsync = ref.watch(marketPricesProvider);
    final weeklyAsync = ref.watch(weeklyPricesProvider);
    final monthlyAsync = ref.watch(monthlyPricesProvider);
    final productionAsync = ref.watch(productionProvider);
    final productionIndexAsync = ref.watch(productionIndexProvider);
    final priceIndexAsync = ref.watch(priceIndexProvider);
    final quarterPriceIndexAsync = ref.watch(quarterPriceIndexProvider);
    final yearPriceIndexAsync = ref.watch(yearPriceIndexProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ราคาสินค้าเกษตร'),
              Text(
                'ราคา ณ ไร่นา พร้อมแหล่งข้อมูล',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<_MarketSort>(
              icon: const Icon(Icons.sort),
              tooltip: 'เรียงราคา',
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _MarketSort.name,
                  child: Text('เรียงตามชื่อ'),
                ),
                PopupMenuItem(
                  value: _MarketSort.priceHigh,
                  child: Text('ราคาสูงสุดก่อน'),
                ),
                PopupMenuItem(
                  value: _MarketSort.priceLow,
                  child: Text('ราคาต่ำสุดก่อน'),
                ),
                PopupMenuItem(
                  value: _MarketSort.changeHigh,
                  child: Text('เปลี่ยนแปลงมากสุดก่อน'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'โหลดราคาใหม่',
              onPressed: () {
                MarketPriceService().clearCache();
                ref.invalidate(marketPricesProvider);
                ref.invalidate(weeklyPricesProvider);
                ref.invalidate(monthlyPricesProvider);
                ref.invalidate(productionProvider);
                ref.invalidate(productionIndexProvider);
                ref.invalidate(priceIndexProvider);
                ref.invalidate(quarterPriceIndexProvider);
                ref.invalidate(yearPriceIndexProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'รายวัน', icon: Icon(Icons.today_outlined)),
              Tab(text: 'รายสัปดาห์', icon: Icon(Icons.date_range_outlined)),
              Tab(text: 'รายเดือน', icon: Icon(Icons.calendar_month_outlined)),
              Tab(text: 'ผลผลิต', icon: Icon(Icons.agriculture_outlined)),
              Tab(text: 'ต้นทุน', icon: Icon(Icons.calculate_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            pricesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('โหลดราคาไม่ได้: $e')),
              data: _buildContent,
            ),
            weeklyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('โหลดราคารายสัปดาห์ไม่ได้: $e')),
              data: _buildWeeklyContent,
            ),
            monthlyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('โหลดราคารายเดือนไม่ได้: $e')),
              data: _buildMonthlyContent,
            ),
            productionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('โหลดข้อมูลผลผลิตไม่ได้: $e')),
              data: (snapshot) => _buildProductionContent(
                snapshot,
                productionIndexAsync,
                priceIndexAsync,
                quarterPriceIndexAsync,
                yearPriceIndexAsync,
              ),
            ),
            _buildCostContent(),
          ],
        ),
      ),
    );
  }

  double _costValue(String key) {
    return double.tryParse(_costControllers[key]!.text.replaceAll(',', '')) ??
        0;
  }

  Widget _costField(String key, String label, {String? suffix}) {
    return TextFormField(
      controller: _costControllers[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCostContent() {
    final area = _costValue('area');
    final yieldPerRai = _costValue('yield');
    final sellPrice = _costValue('price');
    final costPerRai = [
      'seed',
      'fertilizer',
      'chemical',
      'labor',
      'water',
      'fuel',
      'rent',
      'transport',
      'other',
    ].fold<double>(0, (sum, key) => sum + _costValue(key));
    final totalCost = costPerRai * area;
    final totalYield = yieldPerRai * area;
    final revenue = sellPrice * totalYield;
    final profit = revenue - totalCost;
    final breakEven = yieldPerRai > 0 ? costPerRai / yieldPerRai : 0.0;
    final profitPerRai = sellPrice * yieldPerRai - costPerRai;
    final number = NumberFormat('#,##0.00');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'คำนวณต้นทุนและกำไร',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'กรอกข้อมูลต่อไร่ ระบบจะคำนวณจุดคุ้มทุนและกำไรโดยประมาณให้ทันที',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _costCrop,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'ชนิดพืช',
          ),
          items: const [
            DropdownMenuItem(value: 'ข้าว', child: Text('ข้าว')),
            DropdownMenuItem(
              value: 'ข้าวโพดเลี้ยงสัตว์',
              child: Text('ข้าวโพดเลี้ยงสัตว์'),
            ),
            DropdownMenuItem(value: 'มันสำปะหลัง', child: Text('มันสำปะหลัง')),
            DropdownMenuItem(value: 'ยางพารา', child: Text('ยางพารา')),
            DropdownMenuItem(value: 'ปาล์มน้ำมัน', child: Text('ปาล์มน้ำมัน')),
            DropdownMenuItem(value: 'ทุเรียน', child: Text('ทุเรียน')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _costCrop = value);
          },
        ),
        const SizedBox(height: 14),
        _CostSection(
          title: 'ข้อมูลการผลิต',
          children: [
            _costField('area', 'พื้นที่เพาะปลูก', suffix: 'ไร่'),
            _costField(
              'yield',
              'ผลผลิตที่คาดว่าจะได้ต่อไร่',
              suffix: 'กก./ไร่',
            ),
            _costField('price', 'ราคาขายที่คาดว่าจะได้', suffix: 'บาท/กก.'),
          ],
        ),
        const SizedBox(height: 12),
        _CostSection(
          title: 'ต้นทุนต่อไร่',
          children: [
            _costField('seed', 'เมล็ดพันธุ์/ต้นพันธุ์', suffix: 'บาท'),
            _costField('fertilizer', 'ปุ๋ย', suffix: 'บาท'),
            _costField('chemical', 'สารเคมี/ยาป้องกันศัตรูพืช', suffix: 'บาท'),
            _costField('labor', 'ค่าแรง', suffix: 'บาท'),
            _costField('water', 'ค่าน้ำ/ไฟฟ้า', suffix: 'บาท'),
            _costField('fuel', 'น้ำมัน/เครื่องจักร', suffix: 'บาท'),
            _costField('rent', 'ค่าเช่าที่', suffix: 'บาท'),
            _costField('transport', 'ค่าขนส่ง', suffix: 'บาท'),
            _costField('other', 'ค่าใช้จ่ายอื่น ๆ', suffix: 'บาท'),
          ],
        ),
        const SizedBox(height: 14),
        _CostResultCard(
          crop: _costCrop,
          totalCost: totalCost,
          totalYield: totalYield,
          revenue: revenue,
          profit: profit,
          breakEven: breakEven,
          profitPerRai: profitPerRai,
          number: number,
        ),
        const SizedBox(height: 12),
        _CostScenarioCard(
          yieldPerRai: yieldPerRai,
          area: area,
          costPerRai: costPerRai,
          basePrice: sellPrice,
          number: number,
        ),
        const SizedBox(height: 14),
        const Text(
          'หมายเหตุ: ผลลัพธ์เป็นการประมาณจากข้อมูลที่กรอก ไม่รวมความเสียหายจากสภาพอากาศ โรคพืช และความผันผวนของราคาจริง',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyContent(WeeklyPriceSnapshot snapshot) {
    final records = snapshot.records
        .where(
          (record) =>
              record.year == _weeklyYear &&
              record.month == _weeklyMonth &&
              record.commodityCategory == _weeklyCommodity,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WeeklySourceBadge(snapshot: snapshot),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _weeklyCommodity,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'เลือกสินค้า',
          ),
          items: const [
            DropdownMenuItem(value: 'ข้าว', child: Text('ข้าว')),
            DropdownMenuItem(
              value: 'ข้าวโพดเลี้ยงสัตว์',
              child: Text('ข้าวโพดเลี้ยงสัตว์'),
            ),
            DropdownMenuItem(value: 'เงาะ', child: Text('เงาะ')),
            DropdownMenuItem(value: 'ทุเรียน', child: Text('ทุเรียน')),
            DropdownMenuItem(value: 'ปาล์มน้ำมัน', child: Text('ปาล์มน้ำมัน')),
            DropdownMenuItem(value: 'พริกไทย', child: Text('พริกไทย')),
            DropdownMenuItem(value: 'มะพร้าว', child: Text('มะพร้าว')),
            DropdownMenuItem(value: 'มันสำปะหลัง', child: Text('มันสำปะหลัง')),
            DropdownMenuItem(value: 'ยางพารา', child: Text('ยางพารา')),
            DropdownMenuItem(value: 'ลำไย', child: Text('ลำไย')),
            DropdownMenuItem(value: 'สับปะรด', child: Text('สับปะรด')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _weeklyCommodity = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _weeklyYear,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.history_outlined),
            labelText: 'เลือกปี',
          ),
          items: const [
            DropdownMenuItem(value: 2569, child: Text('ปี 2569')),
            DropdownMenuItem(value: 2568, child: Text('ปี 2568')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _weeklyYear = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _weeklyMonth,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month_outlined),
            labelText: 'เลือกเดือน',
          ),
          items: [
            for (var month = 1; month <= 8; month++)
              DropdownMenuItem(
                value: month,
                child: Text('เดือน ${month.toString().padLeft(2, '0')}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _weeklyMonth = value);
          },
        ),
        const SizedBox(height: 14),
        _WeeklySummary(
          count: records.length,
          month: _weeklyMonth,
          fetchedAt: snapshot.fetchedAt,
          isLive: snapshot.isLive,
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _EmptyWeeklyPrices()
        else
          ...records.map((record) => _WeeklyPriceCard(record: record)),
        const SizedBox(height: 20),
        Text(
          'หมายเหตุ: ราคาสัปดาห์ใช้เพื่อประเมินแนวโน้มเบื้องต้น ราคาจริงอาจแตกต่างตามคุณภาพผลผลิตและพื้นที่รับซื้อ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyContent(MonthlyPriceSnapshot snapshot) {
    final records = snapshot.records
        .where(
          (record) =>
              record.year == _monthlyYear &&
              record.month == _monthlyMonth &&
              record.commodityCategory == _monthlyCommodity,
        )
        .toList();

    const commodities = [
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MonthlySourceBadge(snapshot: snapshot),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _monthlyCommodity,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'เลือกสินค้า',
          ),
          items: [
            for (final commodity in commodities)
              DropdownMenuItem(value: commodity, child: Text(commodity)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _monthlyCommodity = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _monthlyYear,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.history_outlined),
            labelText: 'เลือกปี',
          ),
          items: const [
            DropdownMenuItem(value: 2569, child: Text('ปี 2569')),
            DropdownMenuItem(value: 2568, child: Text('ปี 2568')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _monthlyYear = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _monthlyMonth,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month_outlined),
            labelText: 'เลือกเดือน',
          ),
          items: [
            for (var month = 1; month <= 8; month++)
              DropdownMenuItem(
                value: month,
                child: Text('เดือน ${month.toString().padLeft(2, '0')}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _monthlyMonth = value);
          },
        ),
        const SizedBox(height: 10),
        _MonthlyAvailabilityStatus(
          records: snapshot.records,
          year: _monthlyYear,
          commodity: _monthlyCommodity,
        ),
        const SizedBox(height: 14),
        _MonthlySummary(
          count: records.length,
          month: _monthlyMonth,
          fetchedAt: snapshot.fetchedAt,
          isLive: snapshot.isLive,
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _EmptyMonthlyPrices()
        else
          ...records.map((record) => _MonthlyPriceCard(record: record)),
      ],
    );
  }

  Widget _buildProductionContent(
    ProductionSnapshot snapshot,
    AsyncValue<ProductionIndexSnapshot> indexAsync,
    AsyncValue<PriceIndexSnapshot> priceIndexAsync,
    AsyncValue<QuarterPriceIndexSnapshot> quarterPriceIndexAsync,
    AsyncValue<YearPriceIndexSnapshot> yearPriceIndexAsync,
  ) {
    final records = snapshot.records
        .where(
          (record) =>
              record.commodity == _productionCommodity &&
              record.year == '$_productionYear' &&
              record.province.toLowerCase().contains(
                _productionProvince.trim().toLowerCase(),
              ),
        )
        .toList();
    const commodities = [
      'ข้าว',
      'ข้าวโพดเลี้ยงสัตว์',
      'ถั่วเหลือง',
      'ทุเรียน',
      'ปาล์มน้ำมัน',
      'มันสำปะหลัง',
      'ยางพารา',
      'สับปะรด',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProductionSourceBadge(snapshot: snapshot),
        const SizedBox(height: 12),
        indexAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('โหลดดัชนีผลผลิตไม่ได้: $e'),
          data: (indexSnapshot) => _ProductionIndexPanel(
            snapshot: indexSnapshot,
            priceIndexAsync: priceIndexAsync,
            quarterPriceIndexAsync: quarterPriceIndexAsync,
            yearPriceIndexAsync: yearPriceIndexAsync,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _productionCommodity,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'เลือกสินค้า',
          ),
          items: [
            for (final commodity in commodities)
              DropdownMenuItem(value: commodity, child: Text(commodity)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _productionCommodity = value);
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: _productionYear,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.history_outlined),
            labelText: 'เลือกปี',
          ),
          items: const [
            DropdownMenuItem(value: 2569, child: Text('ปี 2569')),
            DropdownMenuItem(value: 2568, child: Text('ปี 2568')),
            DropdownMenuItem(value: 2567, child: Text('ปี 2567')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _productionYear = value);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'ค้นหาจังหวัด',
            hintText: 'เช่น เชียงใหม่ หรือ ประเทศไทย',
          ),
          onChanged: (value) => setState(() => _productionProvince = value),
        ),
        const SizedBox(height: 14),
        _ProductionSummary(records: records, isLive: snapshot.isLive),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _EmptyProduction()
        else
          ...records.map((record) => _ProductionCard(record: record)),
      ],
    );
  }

  Widget _buildContent(MarketPriceSnapshot snapshot) {
    final availableNames = _availableCropNames(snapshot.prices);
    final selectedName = availableNames.contains(_nameFilter)
        ? _nameFilter
        : 'all';
    final visiblePrices = _visiblePrices(
      snapshot.prices,
      nameFilter: selectedName,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SourceBadge(snapshot: snapshot),
        const SizedBox(height: 12),
        _SearchAndFilter(
          controller: _searchCtrl,
          cropFilter: _cropFilter,
          availableTypes: _availableCropTypes(snapshot.prices),
          availableNames: availableNames,
          nameFilter: selectedName,
          onSearchChanged: (_) => setState(() {}),
          onNameFilterChanged: (value) {
            setState(() {
              _nameFilter = value;
              _selectedCrop = null;
              _aiAdvice = null;
            });
          },
          onFilterChanged: (value) {
            setState(() {
              _cropFilter = value;
              _selectedCrop = null;
              _aiAdvice = null;
            });
          },
        ),
        const SizedBox(height: 14),
        _MarketSummary(
          count: visiblePrices.length,
          totalCount: snapshot.prices.length,
          fetchedAt: snapshot.fetchedAt,
          isLive: snapshot.isLive,
        ),
        const SizedBox(height: 10),
        if (visiblePrices.isEmpty)
          const _EmptyPrices()
        else
          ...visiblePrices.map(
            (p) => _PriceCard(
              price: p,
              isSelected: _selectedCrop?.nameThai == p.nameThai,
              onTap: () => setState(() {
                _selectedCrop = _selectedCrop?.nameThai == p.nameThai
                    ? null
                    : p;
                _aiAdvice = null;
              }),
            ),
          ),
        if (_selectedCrop != null) ...[
          const SizedBox(height: 20),
          _ProfitCalculator(
            crop: _selectedCrop!,
            quantityKg: _quantityKg,
            onQuantityChanged: (v) => setState(() => _quantityKg = v),
            onAskAI: _getAIAdvice,
            loadingAI: _loadingAI,
            aiAdvice: _aiAdvice,
          ),
        ],
        const SizedBox(height: 20),
        _DisclaimerCard(snapshot: snapshot),
      ],
    );
  }

  List<CropPrice> _visiblePrices(
    List<CropPrice> prices, {
    required String nameFilter,
  }) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = prices.where((price) {
      final matchesQuery =
          query.isEmpty ||
          price.nameThai.toLowerCase().contains(query) ||
          (price.cropType ?? '').toLowerCase().contains(query);
      final matchesType = _cropFilter == 'all' || price.cropType == _cropFilter;
      final matchesName = nameFilter == 'all' || price.nameThai == nameFilter;
      return matchesQuery && matchesType && matchesName;
    }).toList();

    switch (_sort) {
      case _MarketSort.name:
        filtered.sort((a, b) => a.nameThai.compareTo(b.nameThai));
        break;
      case _MarketSort.priceHigh:
        filtered.sort((a, b) => b.pricePerKg.compareTo(a.pricePerKg));
        break;
      case _MarketSort.priceLow:
        filtered.sort((a, b) => a.pricePerKg.compareTo(b.pricePerKg));
        break;
      case _MarketSort.changeHigh:
        filtered.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        break;
    }
    return filtered;
  }

  List<String> _availableCropTypes(List<CropPrice> prices) {
    final types = prices
        .map((price) => price.cropType)
        .whereType<String>()
        .toSet()
        .toList();
    types.sort((a, b) => _cropLabel(a).compareTo(_cropLabel(b)));
    return types;
  }

  List<String> _availableCropNames(List<CropPrice> prices) {
    final names = prices.map((price) => price.nameThai).toSet().toList();
    names.sort();
    return names;
  }

  Future<void> _getAIAdvice() async {
    if (_selectedCrop == null) return;
    setState(() {
      _loadingAI = true;
      _aiAdvice = null;
    });
    try {
      final advice = await GeminiService().getPriceForecast(
        cropType: _selectedCrop!.nameThai,
        currentPricePerKg: _selectedCrop!.pricePerKg,
        quantityKg: _quantityKg,
        seasonalContext:
            'แหล่งข้อมูล: ${_selectedCrop!.source}, '
            'วันที่ราคา: ${_selectedCrop!.priceDate}, '
            'สถานะข้อมูล: ${_selectedCrop!.confidenceLabel}, '
            'การเปลี่ยนแปลง: ${_selectedCrop!.changePercent.toStringAsFixed(1)}%',
      );
      if (mounted) setState(() => _aiAdvice = advice);
    } catch (_) {
      if (mounted) setState(() => _aiAdvice = 'ไม่สามารถขอคำแนะนำได้ในขณะนี้');
    } finally {
      if (mounted) setState(() => _loadingAI = false);
    }
  }
}

class _CostSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CostSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostResultCard extends StatelessWidget {
  final String crop;
  final double totalCost;
  final double totalYield;
  final double revenue;
  final double profit;
  final double breakEven;
  final double profitPerRai;
  final NumberFormat number;

  const _CostResultCard({
    required this.crop,
    required this.totalCost,
    required this.totalYield,
    required this.revenue,
    required this.profit,
    required this.breakEven,
    required this.profitPerRai,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final profitable = profit >= 0;
    final color = profitable ? AppTheme.statusGood : AppTheme.statusPoor;
    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  profitable ? Icons.trending_up : Icons.trending_down,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$crop: ${profitable ? 'คาดว่ามีกำไร' : 'คาดว่าอาจขาดทุน'}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CostMetric(
              label: 'ต้นทุนรวม',
              value: '${number.format(totalCost)} บาท',
            ),
            _CostMetric(
              label: 'ผลผลิตรวม',
              value: '${number.format(totalYield)} กก.',
            ),
            _CostMetric(
              label: 'รายรับโดยประมาณ',
              value: '${number.format(revenue)} บาท',
            ),
            _CostMetric(
              label: 'กำไร/ขาดทุน',
              value: '${number.format(profit)} บาท',
              color: color,
            ),
            _CostMetric(
              label: 'ต้นทุนคุ้มทุน',
              value: '${number.format(breakEven)} บาท/กก.',
            ),
            _CostMetric(
              label: 'กำไรต่อไร่',
              value: '${number.format(profitPerRai)} บาท',
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _CostMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _CostMetric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _CostScenarioCard extends StatelessWidget {
  final double yieldPerRai;
  final double area;
  final double costPerRai;
  final double basePrice;
  final NumberFormat number;

  const _CostScenarioCard({
    required this.yieldPerRai,
    required this.area,
    required this.costPerRai,
    required this.basePrice,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'จำลองสถานการณ์ราคา',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'ช่วยดูความเสี่ยงเมื่อราคาตลาดเปลี่ยนแปลง',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final scenario in [
              ('ราคาต่ำ (-20%)', basePrice * 0.8, AppTheme.statusPoor),
              ('ราคาปัจจุบัน', basePrice, AppTheme.statusGood),
              ('ราคาสูง (+20%)', basePrice * 1.2, AppTheme.primaryGreenDark),
            ])
              _ScenarioRow(
                label: scenario.$1,
                price: scenario.$2,
                profit: (scenario.$2 * yieldPerRai - costPerRai) * area,
                number: number,
                color: scenario.$3,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  final String label;
  final double price;
  final double profit;
  final NumberFormat number;
  final Color color;

  const _ScenarioRow({
    required this.label,
    required this.price,
    required this.profit,
    required this.number,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('${number.format(price)} บาท/กก.'),
          const SizedBox(width: 10),
          Text(
            '${number.format(profit)} บาท',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: profit >= 0 ? AppTheme.statusGood : AppTheme.statusPoor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySourceBadge extends StatelessWidget {
  final WeeklyPriceSnapshot snapshot;

  const _WeeklySourceBadge({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final color = snapshot.isLive
        ? AppTheme.statusGood
        : AppTheme.statusModerate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.isLive ? Icons.verified_outlined : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.isLive
                      ? 'ข้อมูลรายสัปดาห์สดจาก API'
                      : 'ราคาอ้างอิงในแอป',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyAvailabilityStatus extends StatelessWidget {
  final List<MonthlyPriceRecord> records;
  final int year;
  final String commodity;

  const _MonthlyAvailabilityStatus({
    required this.records,
    required this.year,
    required this.commodity,
  });

  @override
  Widget build(BuildContext context) {
    final available = records
        .where(
          (record) =>
              record.year == year && record.commodityCategory == commodity,
        )
        .map((record) => record.month)
        .toSet();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            available.isEmpty
                ? 'ยังไม่มีข้อมูล $commodity ปี $year'
                : 'สถานะข้อมูล $commodity ปี $year',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var month = 1; month <= 12; month++)
                Chip(
                  label: Text(month.toString().padLeft(2, '0')),
                  backgroundColor: available.contains(month)
                      ? AppTheme.statusGood.withValues(alpha: 0.15)
                      : AppTheme.textSecondary.withValues(alpha: 0.10),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'สีเขียว = มีข้อมูล, สีเทา = ยังไม่มีข้อมูล',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MonthlySourceBadge extends StatelessWidget {
  final MonthlyPriceSnapshot snapshot;

  const _MonthlySourceBadge({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final color = snapshot.isLive
        ? AppTheme.statusGood
        : AppTheme.statusModerate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.isLive ? Icons.verified_outlined : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.isLive
                      ? 'ข้อมูลรายเดือนสดจาก API'
                      : 'ราคาอ้างอิงในแอป',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  final int count;
  final int month;
  final DateTime fetchedAt;
  final bool isLive;

  const _MonthlySummary({
    required this.count,
    required this.month,
    required this.fetchedAt,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.calendar_view_month_outlined,
            label: 'รายการรายเดือน',
            value: '$count รายการ',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            icon: isLive ? Icons.cloud_done_outlined : Icons.history,
            label: 'เดือน ${month.toString().padLeft(2, '0')}',
            value: DateFormat('d/M HH:mm').format(fetchedAt),
          ),
        ),
      ],
    );
  }
}

class _MonthlyPriceCard extends StatelessWidget {
  final MonthlyPriceRecord record;

  const _MonthlyPriceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.surface,
      child: ListTile(
        leading: const Icon(Icons.grass, color: AppTheme.primaryGreenDark),
        title: Text(record.commodity),
        subtitle: Text('เดือน ${record.month.toString().padLeft(2, '0')}'),
        trailing: Text(
          '${NumberFormat('#,##0.00').format(record.pricePerKg)} ${record.unit}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyMonthlyPrices extends StatelessWidget {
  const _EmptyMonthlyPrices();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('ไม่พบราคารายเดือนของเดือนนี้')),
    );
  }
}

class _ProductionSourceBadge extends StatelessWidget {
  final ProductionSnapshot snapshot;

  const _ProductionSourceBadge({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final color = snapshot.isLive
        ? AppTheme.statusGood
        : AppTheme.statusModerate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.isLive ? Icons.verified_outlined : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.isLive
                      ? 'ข้อมูลผลผลิตจาก API'
                      : 'ยังไม่มีข้อมูลผลผลิต',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionIndexPanel extends StatelessWidget {
  final ProductionIndexSnapshot snapshot;
  final AsyncValue<PriceIndexSnapshot> priceIndexAsync;
  final AsyncValue<QuarterPriceIndexSnapshot> quarterPriceIndexAsync;
  final AsyncValue<YearPriceIndexSnapshot> yearPriceIndexAsync;

  const _ProductionIndexPanel({
    required this.snapshot,
    required this.priceIndexAsync,
    required this.quarterPriceIndexAsync,
    required this.yearPriceIndexAsync,
  });

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.00');
    final currentRecords = snapshot.records
        .where((record) => record.year == 2569)
        .toList();
    final latest = currentRecords.isEmpty ? null : currentRecords.last;
    final previousRecords = latest == null
        ? <ProductionIndexRecord>[]
        : snapshot.records
              .where(
                (record) => record.year == 2568 && record.month == latest.month,
              )
              .toList();
    final previous = previousRecords.isEmpty ? null : previousRecords.first;
    final changePercent =
        latest != null && previous != null && previous.index != 0
        ? (latest.index - previous.index) / previous.index * 100
        : null;
    final color = snapshot.isLive
        ? AppTheme.statusGood
        : AppTheme.statusModerate;
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: color),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ดัชนีผลผลิตสินค้าเกษตรรายเดือน',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('ปี 2569', style: TextStyle(color: color)),
              ],
            ),
            const SizedBox(height: 8),
            if (latest == null)
              Text(snapshot.note)
            else ...[
              Text(
                'เดือน ${latest.month.toString().padLeft(2, '0')}  ปี 2569: ${number.format(latest.index)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (previous != null) ...[
                const SizedBox(height: 4),
                Text(
                  'เดือนเดียวกัน ปี 2568: ${number.format(previous.index)}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              if (changePercent != null) ...[
                const SizedBox(height: 4),
                Text(
                  'เปลี่ยนแปลงจากปีก่อน: ${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changePercent >= 0
                        ? AppTheme.statusGood
                        : AppTheme.statusPoor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final record in snapshot.records)
                    Chip(
                      label: Text(
                        '${record.year}/${record.month.toString().padLeft(2, '0')}: ${number.format(record.index)}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ค่า 100 คือระดับฐาน ใช้ดูแนวโน้มผลผลิต ไม่ใช่ปริมาณตันโดยตรง',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (snapshot.annualRecords.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'ดัชนีผลผลิตสินค้าเกษตรรายปี',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final record in snapshot.annualRecords)
                    Chip(
                      label: Text(
                        '${record.year}: ${number.format(record.index)}',
                      ),
                    ),
                ],
              ),
            ],
            if (snapshot.quarterlyRecords.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ProductionQuarterIndexSection(
                records: snapshot.quarterlyRecords,
              ),
            ],
            const SizedBox(height: 14),
            priceIndexAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('โหลดดัชนีราคาไม่ได้: $e'),
              data: (priceSnapshot) =>
                  _PriceIndexSection(snapshot: priceSnapshot),
            ),
            const SizedBox(height: 14),
            priceIndexAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (priceSnapshot) => _IndexComparisonChart(
                productionRecords: snapshot.records,
                priceRecords: priceSnapshot.records,
              ),
            ),
            const SizedBox(height: 14),
            quarterPriceIndexAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('โหลดดัชนีราคารายไตรมาสไม่ได้: $e'),
              data: (quarterSnapshot) =>
                  _QuarterPriceIndexSection(snapshot: quarterSnapshot),
            ),
            const SizedBox(height: 14),
            yearPriceIndexAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('โหลดดัชนีราคารายปีไม่ได้: $e'),
              data: (yearSnapshot) =>
                  _YearPriceIndexSection(snapshot: yearSnapshot),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexComparisonChart extends StatelessWidget {
  final List<ProductionIndexRecord> productionRecords;
  final List<PriceIndexRecord> priceRecords;

  const _IndexComparisonChart({
    required this.productionRecords,
    required this.priceRecords,
  });

  @override
  Widget build(BuildContext context) {
    final production = productionRecords
        .where((record) => record.year == 2569)
        .fold<Map<int, double>>({}, (map, record) {
          map[record.month] = record.index;
          return map;
        });
    final prices = priceRecords
        .where((record) => record.year == 2569)
        .fold<Map<int, double>>({}, (map, record) {
          map[record.month] = record.index;
          return map;
        });
    if (production.isEmpty || prices.isEmpty) return const SizedBox.shrink();

    final maxValue = [
      ...production.values,
      ...prices.values,
    ].reduce((a, b) => a > b ? a : b);
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เปรียบเทียบดัชนีราคาและดัชนีผลผลิต ปี 2569',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: 12,
                  minY: 0,
                  maxY: maxValue * 1.15,
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _line(production, AppTheme.primaryGreenDark),
                    _line(prices, AppTheme.statusGood),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 14,
              children: [
                _ChartLegend(color: AppTheme.primaryGreenDark, label: 'ผลผลิต'),
                _ChartLegend(color: AppTheme.statusGood, label: 'ราคา'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(Map<int, double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (final entry in values.entries)
          FlSpot(entry.key.toDouble(), entry.value),
      ],
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ProductionQuarterIndexSection extends StatelessWidget {
  final List<ProductionQuarterIndexRecord> records;

  const _ProductionQuarterIndexSection({required this.records});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.00');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ดัชนีผลผลิตสินค้าเกษตรรายไตรมาส',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final record in records)
              Chip(
                label: Text(
                  '${record.year} Q${record.quarter}: ${number.format(record.index)}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PriceIndexSection extends StatelessWidget {
  final PriceIndexSnapshot snapshot;

  const _PriceIndexSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.00');
    final currentRecords = snapshot.records
        .where((record) => record.year == 2569)
        .toList();
    final latest = currentRecords.isEmpty ? null : currentRecords.last;
    final previousRecords = latest == null
        ? <PriceIndexRecord>[]
        : snapshot.records
              .where(
                (record) => record.year == 2568 && record.month == latest.month,
              )
              .toList();
    final previous = previousRecords.isEmpty ? null : previousRecords.first;
    final changePercent =
        latest != null && previous != null && previous.index != 0
        ? (latest.index - previous.index) / previous.index * 100
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ดัชนีราคาสินค้าเกษตรรายเดือน',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (snapshot.records.isEmpty)
          Text(snapshot.note)
        else ...[
          if (latest != null)
            Text(
              'เดือน ${latest.month.toString().padLeft(2, '0')} ปี 2569: ${number.format(latest.index)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (previous != null)
            Text('เดือนเดียวกัน ปี 2568: ${number.format(previous.index)}'),
          if (changePercent != null)
            Text(
              'เปลี่ยนแปลงจากปีก่อน: ${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: changePercent >= 0
                    ? AppTheme.statusGood
                    : AppTheme.statusPoor,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final record in snapshot.records)
                Chip(
                  label: Text(
                    '${record.year}/${record.month.toString().padLeft(2, '0')}: ${number.format(record.index)}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuarterPriceIndexSection extends StatelessWidget {
  final QuarterPriceIndexSnapshot snapshot;

  const _QuarterPriceIndexSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.00');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ดัชนีราคาสินค้าเกษตรรายไตรมาส',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (snapshot.records.isEmpty)
          Text(snapshot.note)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final record in snapshot.records)
                Chip(
                  label: Text(
                    '${record.year} ไตรมาส ${record.quarter}: ${number.format(record.index)}',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _YearPriceIndexSection extends StatelessWidget {
  final YearPriceIndexSnapshot snapshot;

  const _YearPriceIndexSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.00');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ดัชนีราคาสินค้าเกษตรรายปี',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (snapshot.records.isEmpty)
          Text(snapshot.note)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final record in snapshot.records)
                Chip(
                  label: Text('${record.year}: ${number.format(record.index)}'),
                ),
            ],
          ),
      ],
    );
  }
}

class _ProductionSummary extends StatelessWidget {
  final List<ProductionRecord> records;
  final bool isLive;

  const _ProductionSummary({required this.records, required this.isLive});

  @override
  Widget build(BuildContext context) {
    final production = records.fold<double>(
      0,
      (sum, record) => sum + (record.production ?? 0),
    );
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.location_city_outlined,
            label: 'พื้นที่ข้อมูล',
            value: '${records.length} รายการ',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            icon: isLive ? Icons.cloud_done_outlined : Icons.history,
            label: 'ผลผลิตรวม (ตัน)',
            value: NumberFormat('#,##0.##').format(production),
          ),
        ),
      ],
    );
  }
}

class _ProductionCard extends StatelessWidget {
  final ProductionRecord record;

  const _ProductionCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0.##');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primaryGreenDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.province,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('ปี ${record.year}'),
              ],
            ),
            const SizedBox(height: 8),
            Text('ชนิด: ${record.subCommodity}'),
            Text(
              'พื้นที่เพาะปลูก: ${record.areaPlant == null ? '-' : '${number.format(record.areaPlant)} ไร่'}',
            ),
            Text(
              'พื้นที่เก็บเกี่ยว: ${record.areaHarvest == null ? '-' : '${number.format(record.areaHarvest)} ไร่'}',
            ),
            Text(
              'ผลผลิต: ${record.production == null ? '-' : '${number.format(record.production)} ตัน'}',
            ),
            Text(
              'ผลผลิตต่อไร่: ${record.yieldHarvest == null ? '-' : '${number.format(record.yieldHarvest)} กก./ไร่'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProduction extends StatelessWidget {
  const _EmptyProduction();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('ไม่พบข้อมูลผลผลิตของสินค้านี้ในปี 2569')),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  final int count;
  final int month;
  final DateTime fetchedAt;
  final bool isLive;

  const _WeeklySummary({
    required this.count,
    required this.month,
    required this.fetchedAt,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.view_week_outlined,
            label: 'รายการสัปดาห์',
            value: '$count รายการ',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            icon: isLive ? Icons.cloud_done_outlined : Icons.history,
            label: 'เดือน ${month.toString().padLeft(2, '0')}',
            value: DateFormat('d/M HH:mm').format(fetchedAt),
          ),
        ),
      ],
    );
  }
}

class _WeeklyPriceCard extends StatelessWidget {
  final WeeklyPriceRecord record;

  const _WeeklyPriceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.00');
    final range = record.minPricePerKg != null && record.maxPricePerKg != null
        ? 'ต่ำสุด ${numberFormat.format(record.minPricePerKg)} - สูงสุด ${numberFormat.format(record.maxPricePerKg)}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grass, color: AppTheme.primaryGreenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.commodity,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.weekLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (range != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      range,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    record.date,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  numberFormat.format(record.pricePerKg),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreenDark,
                  ),
                ),
                Text(
                  record.unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWeeklyPrices extends StatelessWidget {
  const _EmptyWeeklyPrices();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: AppTheme.textSecondary,
            size: 36,
          ),
          SizedBox(height: 8),
          Text(
            'ไม่พบราคาสัปดาห์ของเดือนนี้',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final MarketPriceSnapshot snapshot;

  const _SourceBadge({required this.snapshot});

  @override
  Widget build(BuildContext ctx) {
    final color = snapshot.isLive
        ? AppTheme.statusGood
        : AppTheme.statusModerate;
    final title = snapshot.isLive ? 'ข้อมูลสดจาก API' : 'ราคาอ้างอิงในแอป';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.isLive ? Icons.verified_outlined : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.sourceName} | ${snapshot.sourceUrl}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final String cropFilter;
  final String nameFilter;
  final List<String> availableTypes;
  final List<String> availableNames;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onNameFilterChanged;
  final ValueChanged<String> onFilterChanged;

  const _SearchAndFilter({
    required this.controller,
    required this.cropFilter,
    required this.nameFilter,
    required this.availableTypes,
    required this.availableNames,
    required this.onSearchChanged,
    required this.onNameFilterChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ค้นหาพืช เช่น ข้าว มันสำปะหลัง อ้อย',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: nameFilter,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'เลือกชื่อพืช',
          ),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('พืชทั้งหมด')),
            ...availableNames.map(
              (name) => DropdownMenuItem(value: name, child: Text(name)),
            ),
          ],
          onChanged: (value) {
            if (value != null) onNameFilterChanged(value);
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('ทั้งหมด'),
                  selected: cropFilter == 'all',
                  onSelected: (_) => onFilterChanged('all'),
                ),
              ),
              ...availableTypes.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_cropLabel(type)),
                    selected: cropFilter == type,
                    onSelected: (_) => onFilterChanged(type),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketSummary extends StatelessWidget {
  final int count;
  final int totalCount;
  final DateTime fetchedAt;
  final bool isLive;

  const _MarketSummary({
    required this.count,
    required this.totalCount,
    required this.fetchedAt,
    required this.isLive,
  });

  @override
  Widget build(BuildContext ctx) {
    final time = DateFormat('d/M/yyyy HH:mm').format(fetchedAt);

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.inventory_2_outlined,
            label: 'รายการ',
            value: '$count/$totalCount',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            icon: isLive ? Icons.cloud_done_outlined : Icons.history,
            label: isLive ? 'API สด' : 'Fallback',
            value: time,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final CropPrice price;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriceCard({
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext ctx) {
    final up = price.changePercent >= 0;
    final changeColor = up ? AppTheme.statusGood : AppTheme.statusPoor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? const BorderSide(color: AppTheme.primaryGreen, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? AppTheme.primaryGreenLight : AppTheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _cropIcon(price.cropType),
                  color: AppTheme.primaryGreenDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price.nameThai,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _SmallBadge(
                          text: price.confidenceLabel,
                          color: price.sourceType == MarketPriceMode.liveApi
                              ? AppTheme.statusGood
                              : AppTheme.statusModerate,
                        ),
                        _SmallBadge(
                          text: price.priceDate,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    if (price.season != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        price.season!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat('#,##0.00').format(price.pricePerKg),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryGreenDark,
                    ),
                  ),
                  Text(
                    price.unit,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${up ? '+' : ''}${price.changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: changeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfitCalculator extends StatelessWidget {
  final CropPrice crop;
  final double quantityKg;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onAskAI;
  final bool loadingAI;
  final String? aiAdvice;

  const _ProfitCalculator({
    required this.crop,
    required this.quantityKg,
    required this.onQuantityChanged,
    required this.onAskAI,
    required this.loadingAI,
    required this.aiAdvice,
  });

  @override
  Widget build(BuildContext ctx) {
    final revenue = crop.pricePerKg * quantityKg;
    final fmt = NumberFormat('#,##0');

    return Card(
      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.primaryGreen, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'คำนวณรายได้: ${crop.nameThai}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primaryGreenDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'ปริมาณ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${fmt.format(quantityKg)} กก. (${(quantityKg / 1000).toStringAsFixed(2)} ตัน)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryGreenDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: quantityKg,
              min: 100,
              max: 50000,
              divisions: 499,
              activeColor: AppTheme.primaryGreen,
              onChanged: onQuantityChanged,
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'รายได้รวม',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '฿${fmt.format(revenue)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (crop.yieldPerRai != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'พื้นที่ที่ต้องการ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${(quantityKg / crop.yieldPerRai!).toStringAsFixed(1)} ไร่',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loadingAI ? null : onAskAI,
                icon: loadingAI
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy_outlined),
                label: Text(
                  loadingAI ? 'กำลังวิเคราะห์...' : 'ถาม AI: ควรขายตอนนี้ไหม',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreenDark,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
            if (aiAdvice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryGreenLight),
                ),
                child: Text(
                  aiAdvice!,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final MarketPriceSnapshot snapshot;

  const _DisclaimerCard({required this.snapshot});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'หมายเหตุ: ราคาจาก ${snapshot.sourceName} ใช้เพื่อประเมินเบื้องต้น '
        'ราคาจริงอาจต่างตามคุณภาพผลผลิต ความชื้น ระยะขนส่ง และผู้รับซื้อในพื้นที่ '
        'ควรตรวจสอบกับตลาดหรือผู้รับซื้อก่อนตัดสินใจขาย',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _EmptyPrices extends StatelessWidget {
  const _EmptyPrices();

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, color: AppTheme.textSecondary, size: 36),
          SizedBox(height: 8),
          Text(
            'ไม่พบรายการราคาที่ตรงกับตัวกรอง',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _cropLabel(String type) => switch (type) {
  'rice' => 'ข้าว',
  'cassava' => 'มันสำปะหลัง',
  'corn' => 'ข้าวโพด',
  'sugarcane' => 'อ้อย',
  'rubber' => 'ยางพารา',
  'palm' => 'ปาล์มน้ำมัน',
  'durian' => 'ทุเรียน',
  _ => type,
};

IconData _cropIcon(String? type) => switch (type) {
  'rice' => Icons.grass,
  'cassava' => Icons.agriculture_outlined,
  'corn' => Icons.eco_outlined,
  'sugarcane' => Icons.park_outlined,
  'rubber' => Icons.forest_outlined,
  'palm' => Icons.spa_outlined,
  'durian' => Icons.local_florist_outlined,
  _ => Icons.eco_outlined,
};
