import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/market/data/services/market_price_service.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:intl/intl.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final marketPricesProvider = FutureProvider<List<CropPrice>>((ref) async {
  return MarketPriceService().fetchFarmGatePrices();
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('โหลดราคาไม่ได้: $e')),
        data: (prices) => _buildContent(ctx, prices),
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, List<CropPrice> prices) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Source label ────────────────────────────────────────────────
        _SourceBadge(),
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
        seasonalContext:
            'ราคาปัจจุบัน ${_selectedCrop!.pricePerKg} บาท/กก. '
            'เปลี่ยนแปลง ${_selectedCrop!.changePercent > 0 ? '+' : ''}'
            '${_selectedCrop!.changePercent.toStringAsFixed(1)}%',
      );
      setState(() => _aiAdvice = advice);
    } catch (e) {
      setState(() => _aiAdvice = 'ไม่สามารถขอคำแนะนำได้ในขณะนี้');
    } finally {
      setState(() => _loadingAI = false);
    }
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
                onPressed: loadingAI ? null : onAskAI,
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
