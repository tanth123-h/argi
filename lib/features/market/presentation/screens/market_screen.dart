import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  int _weeklyMonth = 1;
  _MarketSort _sort = _MarketSort.name;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final pricesAsync = ref.watch(marketPricesProvider);
    final weeklyAsync = ref.watch(weeklyPricesProvider);

    return DefaultTabController(
      length: 2,
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
                ref.invalidate(marketPricesProvider);
                ref.invalidate(weeklyPricesProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'รายวัน', icon: Icon(Icons.today_outlined)),
              Tab(text: 'รายสัปดาห์', icon: Icon(Icons.date_range_outlined)),
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
              error: (e, _) => Center(child: Text('โหลดราคารายสัปดาห์ไม่ได้: $e')),
              data: _buildWeeklyContent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyContent(WeeklyPriceSnapshot snapshot) {
    final records = snapshot.records
        .where((record) => record.month == _weeklyMonth)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WeeklySourceBadge(snapshot: snapshot),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _weeklyMonth,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month_outlined),
            labelText: 'เลือกเดือน ปี 2569',
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
      final matchesType =
          _cropFilter == 'all' || price.cropType == _cropFilter;
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
              child: const Icon(
                Icons.grass,
                color: AppTheme.primaryGreenDark,
              ),
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
          Icon(Icons.event_busy_outlined, color: AppTheme.textSecondary, size: 36),
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
    final color = snapshot.isLive ? AppTheme.statusGood : AppTheme.statusModerate;
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
          value: nameFilter,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.eco_outlined),
            labelText: 'เลือกชื่อพืช',
          ),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('พืชทั้งหมด'),
            ),
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
