import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/market/data/services/market_price_service.dart';
import 'package:chaona_app/features/market/data/services/nabc_index_service.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chaona_app/shared/widgets/mascot_loading.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final marketPricesProvider = FutureProvider<List<CropPrice>>((ref) async {
  return MarketPriceService().fetchFarmGatePrices();
});

final nabcIndexProvider = FutureProvider<NabcIndexSnapshot>((ref) async {
  return NabcIndexService().fetch();
});

// ── Screen ──────────────────────────────────────────────────────────────────

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  CropPrice? _selectedCrop;
  double _quantityKg = 1000;
  bool _loadingAI = false;
  String? _aiAdvice;

  @override
  Widget build(BuildContext ctx) {
    final pricesAsync = ref.watch(marketPricesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ราคาสินค้าเกษตร',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'ข้อมูลจาก OAE & MOC',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(marketPricesProvider),
          ),
        ],
      ),
      body: pricesAsync.when(
        loading: () => const MascotLoading(message: 'กำลังค้นหาราคาจากแหล่งข้อมูล...'),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.storefront_outlined, size: 48, color: AppTheme.secondaryBrown), const SizedBox(height: 12), Text('โหลดราคาไม่ได้', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 6), Text('ตรวจสอบการเชื่อมต่อแล้วลองใหม่', textAlign: TextAlign.center)]))),
        data: (prices) => _buildContent(ctx, prices),
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, List<CropPrice> prices) {
    final nabc = ref.watch(nabcIndexProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Source label ────────────────────────────────────────────────
        _SourceBadge(),
        const SizedBox(height: 14),
        nabc.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _NabcIndexCard(snapshot: NabcIndexSnapshot(price: const [], production: const [], fetchedAt: DateTime.now(), error: error.toString())),
          data: (snapshot) => _NabcIndexCard(snapshot: snapshot),
        ),
        const SizedBox(height: 14),

        // ── Price list ──────────────────────────────────────────────────
        const Text(
          'ราคา ณ ไร่นา (บาท/กก.)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ...prices.map(
          (p) => _PriceCard(
            price: p,
            isSelected: _selectedCrop?.nameThai == p.nameThai,
            onTap: () => setState(() {
              _selectedCrop = _selectedCrop?.nameThai == p.nameThai ? null : p;
              _aiAdvice = null;
            }),
          ),
        ),

        // ── Profit Calculator ───────────────────────────────────────────
        if (_selectedCrop != null) ...[
          const SizedBox(height: 20),
          _PriceDetail(price: _selectedCrop!),
          const SizedBox(height: 12),
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
        // ── Disclaimer ──────────────────────────────────────────────────
        const _DisclaimerCard(),
      ],
    );
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
        seasonalContext: _selectedCrop!.isReference
            ? 'ข้อมูลราคาอ้างอิงปี 2024 ไม่ใช่ราคาปัจจุบัน ห้ามแนะนำจังหวะขายจากราคานี้'
            : 'ราคาปัจจุบัน ${_selectedCrop!.pricePerKg} บาท/กก. เปลี่ยนแปลง ${_selectedCrop!.changePercent > 0 ? '+' : ''}${_selectedCrop!.changePercent.toStringAsFixed(1)}%',
      );
      if (mounted) setState(() => _aiAdvice = advice);
    } catch (e) {
      if (mounted) setState(() => _aiAdvice = 'ไม่สามารถขอคำแนะนำได้ในขณะนี้');
    } finally {
      if (mounted) setState(() => _loadingAI = false);
    }
  }
}

class _PriceDetail extends StatelessWidget {
  final CropPrice price;
  const _PriceDetail({required this.price});

  @override
  Widget build(BuildContext context) {
    final perTon = price.pricePerKg * 1000;
    final raiRevenue = price.revenuePerRai();
    return Card(
      color: const Color(0xFFFFFBF0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.analytics_outlined, color: AppTheme.secondaryBrown),
            const SizedBox(width: 8),
            Expanded(child: Text('รายละเอียด ${price.nameThai}', style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _detail('ราคาต่อกิโลกรัม', '${price.pricePerKg.toStringAsFixed(2)} บาท')),
            Expanded(child: _detail('ประมาณต่อตัน', '${NumberFormat('#,##0').format(perTon)} บาท')),
          ]),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: _detail('ฤดูกาล/รอบผลิต', price.season ?? 'ไม่ระบุ')),
            Expanded(child: _detail('ผลผลิตอ้างอิง', price.yieldPerRai == null ? 'ไม่ระบุ' : '${NumberFormat('#,##0').format(price.yieldPerRai)} กก./ไร่')),
          ]),
          if (price.yieldPerRai != null) ...[
            const SizedBox(height: 10),
            _detail('รายรับขั้นต้นประมาณต่อไร่', '${NumberFormat('#,##0').format(raiRevenue)} บาท/ไร่'),
          ],
          const SizedBox(height: 10),
          Text(price.isReference ? 'เป็นราคาอ้างอิงเก่า ใช้ดูแนวโน้มและทดลองคำนวณเท่านั้น' : 'ราคาแหล่งข้อมูลปัจจุบัน อาจต่างจากผู้รับซื้อในพื้นที่', style: TextStyle(color: price.isReference ? Colors.orange.shade800 : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('แหล่งข้อมูล: ${price.source} • วันที่: ${price.priceDate}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }



  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.only(right: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.fieldInk))]));
}

class _NabcIndexCard extends StatelessWidget {
  final NabcIndexSnapshot snapshot;
  const _NabcIndexCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final price = snapshot.price;
    final production = snapshot.production;
    final latestPrice = price.isEmpty ? null : price.last;
    final latestProduction = production.isEmpty ? null : production.last;
    final series = _monthlyAverage(price);
    return Card(
      color: const Color(0xFFEAF7F0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.query_stats_rounded, color: AppTheme.primaryGreenDark),
            const SizedBox(width: 8),
            const Expanded(child: Text('แนวโน้มตลาดจาก NABC', style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: () {}, tooltip: 'ข้อมูลจาก NABC', icon: const Icon(Icons.verified_outlined, size: 20, color: AppTheme.primaryGreenDark)),
          ]),
          const Text('ดัชนีช่วยดูทิศทางตลาด ไม่ใช่ราคาขายต่อกิโลกรัม', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (snapshot.error != null) ...[
            const SizedBox(height: 10),
            Text(snapshot.error!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ],
          if (latestPrice != null || latestProduction != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _indexMetric('ดัชนีราคา', latestPrice?.value, latestPrice?.changePercent, Colors.indigo)),
              const SizedBox(width: 10),
              Expanded(child: _indexMetric('ดัชนีผลผลิต', latestProduction?.value, latestProduction?.changePercent, AppTheme.secondaryBrown)),
            ]),
          ],
          if (series.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(height: 120, child: LineChart(LineChartData(
              minX: 0,
              maxX: (series.length - 1).toDouble(),
              minY: series.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 2,
              maxY: series.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 2,
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(spots: series, isCurved: true, color: AppTheme.primaryGreenDark, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppTheme.primaryGreenLight))],
            ))),
          ],
          const SizedBox(height: 8),
          Text('อัปเดตข้อมูล ${snapshot.fetchedAt.toLocal()}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const Text('ที่มา: ศูนย์ข้อมูลเกษตรแห่งชาติ (NABC) • ใช้ร่วมกับราคา OAE/MOC', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _indexMetric(String label, double? value, double? change, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      Text(value == null ? '--' : value.toStringAsFixed(2), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      if (change != null) Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, color: change >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
    ]),
  );

  List<FlSpot> _monthlyAverage(List<NabcIndexPoint> points) {
    final grouped = <String, List<double>>{};
    for (final point in points) {
      final key = '${point.yearTh}-${point.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(point.value);
    }
    final keys = grouped.keys.toList()..sort();
    return [for (var i = 0; i < keys.length; i++) FlSpot(i.toDouble(), grouped[keys[i]]!.reduce((a, b) => a + b) / grouped[keys[i]]!.length)];
  }
}

// ── Source Badge ─────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryGreenDark,
              ),
              SizedBox(width: 6),
              Text(
                'แหล่งข้อมูลราคา',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreenDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _sourceRow(
            '🏛',
            'OAE (สศก.)',
            'ราคา ณ หน้าฟาร์ม รายวัน',
            'https://oae.go.th',
          ),
          _sourceRow(
            '📊',
            'MOC (กระทรวงพาณิชย์)',
            'ราคาขายปลีก/ส่ง',
            'https://tradereport.moc.go.th',
          ),
          _sourceRow(
            '🌐',
            'Talaad Thai',
            'ราคาตลาดค้าส่ง',
            'https://talaadthai.com',
          ),
        ],
      ),
    );
  }

  Widget _sourceRow(String icon, String name, String desc, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$name — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: desc,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price Card ───────────────────────────────────────────────────────────────

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
    final changeColor = up ? Colors.green.shade600 : Colors.red.shade600;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                _cropEmoji(price.cropType),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price.nameThai,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price.season ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      price.priceDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: price.isReference
                            ? Colors.orange.shade800
                            : AppTheme.textSecondary,
                        fontWeight: price.isReference
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
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
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      price.isReference
                          ? 'อ้างอิง 2024'
                          : '${up ? '+' : ''}${price.changePercent.toStringAsFixed(1)}%',
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

  String _cropEmoji(String? type) => switch (type) {
    'rice' => '🌾',
    'cassava' => '🥔',
    'corn' => '🌽',
    'sugarcane' => '🎋',
    'rubber' => '🌳',
    'palm' => '🌴',
    'durian' => '🍈',
    _ => '🌱',
  };
}

// ── Profit Calculator ────────────────────────────────────────────────────────

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
                Text(
                  'คำนวณรายได้ — ${crop.nameThai}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primaryGreenDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quantity slider
            Row(
              children: [
                const Text(
                  'ปริมาณ:',
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

            // Result row
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

            // AI advice button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loadingAI || crop.isReference ? null : onAskAI,
                icon: loadingAI
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy_outlined),
                label: Text(
                  loadingAI
                      ? 'กำลังวิเคราะห์...'
                      : crop.isReference
                      ? 'ต้องมีราคาปัจจุบันก่อนวิเคราะห์การขาย'
                      : '🤖 ถาม AI: ควรขายตอนนี้ไหม?',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreenDark,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),

            // AI response
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

// ── Disclaimer ───────────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ หมายเหตุ',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'ราคาที่แสดงเป็นราคาอ้างอิงจาก OAE (สศก.) ราคาจริง ณ ตลาดท้องถิ่นอาจแตกต่างกัน '
            'ควรตรวจสอบกับผู้รับซื้อในพื้นที่ก่อนตัดสินใจขาย\n\n'
            'แหล่งข้อมูลหลัก: สำนักงานเศรษฐกิจการเกษตร (OAE) | oae.go.th\n'
            'ข้อมูลเสริม: ตลาดไท (talaadthai.com) | AllKaset (allkaset.com)',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
