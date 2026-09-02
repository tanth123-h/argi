import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/core/utils/fertilizer_calculator.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class FertilizerScreen extends ConsumerStatefulWidget {
  const FertilizerScreen({super.key});

  @override
  ConsumerState<FertilizerScreen> createState() => _FertilizerScreenState();
}

class _FertilizerScreenState extends ConsumerState<FertilizerScreen> {
  // Inputs
  String _cropType = 'rice';
  double _areaRai = 5;
  double _soilN = 30;
  double _soilP = 20;
  double _soilK = 80;

  FertilizerResult? _result;
  bool _loadingAI = false;
  String? _aiAdvice;
  bool _loadingRealData = false;
  String _dataSource = 'ยังไม่มีผลตรวจจริง: กรุณากรอกค่าแล็บหรือเซ็นเซอร์';

  static const _crops = {
    'rice': '🌾 ข้าว',
    'cassava': '🥔 มันสำปะหลัง',
    'corn': '🌽 ข้าวโพด',
    'sugarcane': '🎋 อ้อย',
    'rubber': '🌳 ยางพารา',
    'palm': '🌴 ปาล์มน้ำมัน',
    'durian': '🍈 ทุเรียน',
  };

  @override
  void initState() {
    super.initState();
    // Pre-fill from demo soil data if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final demo = ref.read(demoModeNotifierProvider);
      if (demo != DemoPreset.none) {
        final soil = DemoFixtures.soilFor(demo);
        final farm = DemoFixtures.farmFor(demo);
        setState(() {
          _soilN = soil.nitrogen;
          _soilP = soil.phosphorus;
          _soilK = soil.potassium;
          if (farm != null) {
            _areaRai = farm.areaRai;
            _cropType = farm.cropType;
          }
        });
        _calculate();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestReading());
  }

  Future<void> _loadLatestReading() async {
    if (ref.read(demoModeNotifierProvider) != DemoPreset.none) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _loadingRealData = true);
    try {
      final farms = await Supabase.instance.client
          .from('farms')
          .select('id, size, crop_type')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);
      if (farms is! List || farms.isEmpty) return;
      final farm = Map<String, dynamic>.from(farms.first as Map);
      final rows = await SoilReadingRepository(Supabase.instance.client)
          .latestForFarm(farm['id'] as String);
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _areaRai = ((farm['size'] as num?)?.toDouble() ?? 8000) / 1600;
          _cropType = farm['crop_type'] as String? ?? _cropType;
          _dataSource = 'ยังไม่มีผลตรวจจริง: ค่า N/P/K ด้านล่างเป็นค่าที่กรอกเอง';
        });
        return;
      }
      final latest = rows.first;
      setState(() {
        _areaRai = ((farm['size'] as num?)?.toDouble() ?? 8000) / 1600;
        _cropType = farm['crop_type'] as String? ?? _cropType;
        _soilN = (latest['nitrogen'] as num?)?.toDouble() ?? _soilN;
        _soilP = (latest['phosphorus'] as num?)?.toDouble() ?? _soilP;
        _soilK = (latest['potassium'] as num?)?.toDouble() ?? _soilK;
        _dataSource = 'ค่าตรวจล่าสุดจากเซ็นเซอร์/บันทึกดิน';
      });
    } catch (_) {
      if (mounted) setState(() => _dataSource = 'อ่านผลตรวจจริงไม่สำเร็จ: กรุณาตรวจสอบข้อมูลก่อนคำนวณ');
    } finally {
      if (mounted) setState(() => _loadingRealData = false);
    }
  }

  void _calculate() {
    final req = FertilizerCalculator.lookupRequirement(
      cropType: _cropType,
      soilN: _soilN,
      soilP: _soilP,
      soilK: _soilK,
      areaRai: _areaRai,
    );
    setState(() {
      _result = FertilizerCalculator.calculate(
        nReq: req.n,
        pReq: req.p,
        kReq: req.k,
        areaRai: _areaRai,
      );
      _aiAdvice = null;
    });
  }

  Future<void> _askAI() async {
    setState(() {
      _loadingAI = true;
      _aiAdvice = null;
    });
    try {
      final advice = await GeminiService().getFertilizerRecommendation(
        cropType: _crops[_cropType] ?? _cropType,
        nitrogen: _soilN,
        phosphorus: _soilP,
        potassium: _soilK,
        // The current AF333 probe does not measure moisture or pH.
        moisture: null,
        phLevel: null,
        areaRai: _areaRai,
      );
      if (mounted) setState(() => _aiAdvice = advice);
    } catch (_) {
      if (mounted) setState(() => _aiAdvice = 'ไม่สามารถขอคำแนะนำได้ในขณะนี้');
    } finally {
      if (mounted) setState(() => _loadingAI = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คำนวณปุ๋ย', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'สูตรสั่งตัด DOA/DOAE',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InputCard(
            cropType: _cropType,
            areaRai: _areaRai,
            soilN: _soilN,
            soilP: _soilP,
            soilK: _soilK,
            crops: _crops,
            onCropChanged: (v) => setState(() => _cropType = v),
            onAreaChanged: (v) => setState(() => _areaRai = v),
            onNChanged: (v) => setState(() => _soilN = v),
            onPChanged: (v) => setState(() => _soilP = v),
            onKChanged: (v) => setState(() => _soilK = v),
            onCalculate: _calculate,
          ),
          const SizedBox(height: 10),
          _DataSourceBanner(loading: _loadingRealData, text: _dataSource),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              result: _result!,
              cropNote: FertilizerCalculator.lookupRequirement(
                cropType: _cropType,
                soilN: _soilN,
                soilP: _soilP,
                soilK: _soilK,
                areaRai: _areaRai,
              ).note,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingAI ? null : _askAI,
                icon: _loadingAI
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy_outlined),
                label: Text(
                  _loadingAI ? 'กำลังวิเคราะห์...' : '🤖 ขอคำแนะนำปุ๋ยจาก AI',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreenDark,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
            if (_aiAdvice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreenLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'AI แนะนำ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreenDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiAdvice!,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          _FormulaInfo(),
        ],
      ),
    );
  }
}

class _DataSourceBanner extends StatelessWidget {
  final bool loading;
  final String text;
  const _DataSourceBanner({required this.loading, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.verified_outlined, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Input Card
// ─────────────────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final String cropType;
  final double areaRai, soilN, soilP, soilK;
  final Map<String, String> crops;
  final ValueChanged<String> onCropChanged;
  final ValueChanged<double> onAreaChanged, onNChanged, onPChanged, onKChanged;
  final VoidCallback onCalculate;

  const _InputCard({
    required this.cropType,
    required this.areaRai,
    required this.soilN,
    required this.soilP,
    required this.soilK,
    required this.crops,
    required this.onCropChanged,
    required this.onAreaChanged,
    required this.onNChanged,
    required this.onPChanged,
    required this.onKChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลฟาร์มและดิน',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 14),

            // Crop picker
            const Text(
              'ชนิดพืช',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: crops.entries
                  .map(
                    (e) => ChoiceChip(
                      label: Text(
                        e.value,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: cropType == e.key,
                      selectedColor: AppTheme.primaryGreenLight,
                      onSelected: (_) => onCropChanged(e.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Area
            _SliderRow(
              label: 'พื้นที่',
              value: areaRai,
              unit: 'ไร่',
              min: 0.5,
              max: 100,
              divisions: 199,
              onChanged: onAreaChanged,
            ),
            const SizedBox(height: 10),

            // Soil NPK — from sensor or manual
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sensors, size: 14, color: AppTheme.primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'ค่าดินจากเซ็นเซอร์หรือผลแล็บ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreenDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SliderRow(
              label: 'N (ไนโตรเจน)',
              value: soilN,
              unit: 'mg/kg',
              min: 0,
              max: 200,
              divisions: 200,
              onChanged: onNChanged,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 6),
            _SliderRow(
              label: 'P (ฟอสฟอรัส)',
              value: soilP,
              unit: 'mg/kg',
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: onPChanged,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 6),
            _SliderRow(
              label: 'K (โพแทสเซียม)',
              value: soilK,
              unit: 'mg/kg',
              min: 0,
              max: 300,
              divisions: 300,
              onChanged: onKChanged,
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCalculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('คำนวณปริมาณปุ๋ย'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label, unit;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final Color? color;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color ?? AppTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '${value.toStringAsFixed(1)} $unit',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? AppTheme.primaryGreenDark,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Result Card
// ─────────────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final FertilizerResult result;
  final String? cropNote;
  const _ResultCard({required this.result, this.cropNote});

  @override
  Widget build(BuildContext ctx) {
    return Card(
      color: AppTheme.primaryGreen.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_florist, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text(
                  'ผลการคำนวณปุ๋ยสั่งตัด',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.primaryGreenDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'สูตร: ยูเรีย (46-0-0) + DAP (18-46-0) + MOP (0-0-60)',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Divider(height: 20),

            // Per rai
            const Text(
              '▸ ปริมาณต่อไร่',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _fertRow(
              '🟡 ยูเรีย (46-0-0)',
              '${result.ureaPerRai.toStringAsFixed(1)} กก./ไร่',
              Colors.amber.shade700,
            ),
            _fertRow(
              '🔵 DAP (18-46-0)',
              '${result.dapPerRai.toStringAsFixed(1)} กก./ไร่',
              Colors.blue.shade700,
            ),
            _fertRow(
              '🔴 MOP (0-0-60)',
              '${result.mopPerRai.toStringAsFixed(1)} กก./ไร่',
              Colors.red.shade700,
            ),

            const Divider(height: 20),

            // Total bags
            Text(
              '▸ รวมทั้งฟาร์ม (${result.areaRai.toStringAsFixed(1)} ไร่)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _bagRow(
              'ยูเรีย',
              result.ureaBags,
              result.ureaTotal,
              Colors.amber.shade700,
            ),
            _bagRow(
              'DAP',
              result.dapBags,
              result.dapTotal,
              Colors.blue.shade700,
            ),
            _bagRow(
              'MOP',
              result.mopBags,
              result.mopTotal,
              Colors.red.shade700,
            ),

            const Divider(height: 20),

            // Cost
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ต้นทุนปุ๋ยรวม',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        '(ราคาอ้างอิงปี 2567)',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '฿${result.totalCost.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '฿${result.costPerRai.toStringAsFixed(0)}/ไร่',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (cropNote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBrownLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💡 $cropNote',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.secondaryBrown,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fertRow(String name, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _bagRow(String name, int bags, double kg, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
        Text(
          '$bags กระสอบ (${kg.toStringAsFixed(1)} กก.)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Formula Info
// ─────────────────────────────────────────────────────────────────────────────

class _FormulaInfo extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📐 สูตรคำนวณ (Soil-Test Crop Response)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            'Q_MOP  = K_req ÷ 0.60\n'
            'Q_DAP  = P_req ÷ 0.46\n'
            'N_DAP  = Q_DAP × 0.18\n'
            'Q_Urea = (N_req − N_DAP) ÷ 0.46',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.8,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ที่มา: กรมวิชาการเกษตร (DOA) & กรมส่งเสริมการเกษตร (DOAE)\n'
            'วิธีนี้ป้องกันการใส่ปุ๋ยเกินขนาดและลดต้นทุนการผลิต',
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
