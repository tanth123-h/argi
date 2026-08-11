/// Precision Fertilizer Calculation Engine
///
/// Based on: กรมวิชาการเกษตร (DOA) & กรมส่งเสริมการเกษตร (DOAE)
/// Formula source: Soil-Test Crop Response method
///
/// Converts required pure nutrients (N, P, K kg/rai) into exact commercial
/// fertilizer bag weights:
///   - Urea     46-0-0  (46% N)
///   - DAP      18-46-0 (18% N, 46% P₂O₅)
///   - MOP      0-0-60  (60% K₂O)
class FertilizerCalculator {
  FertilizerCalculator._();

  /// Calculate exact fertilizer bag amounts from soil test results.
  ///
  /// [nReq] = Nitrogen required   (kg/rai)
  /// [pReq] = Phosphorus required (kg/rai)
  /// [kReq] = Potassium required  (kg/rai)
  /// [areaRai] = Farm area in rai
  static FertilizerResult calculate({
    required double nReq,
    required double pReq,
    required double kReq,
    required double areaRai,
  }) {
    // Step 1: MOP (0-0-60) — sole K source
    // Q_MOP = K_req / 0.60
    final qMopPerRai = kReq / 0.60;

    // Step 2: DAP (18-46-0) — P source with N contribution
    // Q_DAP = P_req / 0.46
    final qDapPerRai = pReq / 0.46;

    // Step 3: N already supplied by DAP
    // N_DAP = Q_DAP × 0.18
    final nFromDap = qDapPerRai * 0.18;

    // Step 4: Remaining N from Urea (46-0-0)
    // Q_Urea = (N_req - N_DAP) / 0.46
    final remainingN = (nReq - nFromDap).clamp(0, double.infinity);
    final qUreaPerRai = remainingN / 0.46;

    return FertilizerResult(
      ureaPerRai: qUreaPerRai,
      dapPerRai: qDapPerRai,
      mopPerRai: qMopPerRai,
      ureaTotal: qUreaPerRai * areaRai,
      dapTotal: qDapPerRai * areaRai,
      mopTotal: qMopPerRai * areaRai,
      areaRai: areaRai,
      nReq: nReq,
      pReq: pReq,
      kReq: kReq,
    );
  }

  /// Lookup recommended N-P-K requirements from soil NPK sensor readings
  /// and crop type. Based on DOA recommendation tables.
  static NPKRequirement lookupRequirement({
    required String cropType,
    required double soilN,
    required double soilP,
    required double soilK,
    required double areaRai,
  }) {
    // Baseline requirements per rai (kg) from DOA tables
    final base = _baseRequirements[cropType] ?? _baseRequirements['rice']!;

    // Adjust based on current soil levels (subtract what's already there)
    // Typical optimal soil levels: N=50, P=30, K=100 mg/kg
    final nDeficit = (base.n - (soilN * 0.05)).clamp(0.0, base.n);
    final pDeficit = (base.p - (soilP * 0.03)).clamp(0.0, base.p);
    final kDeficit = (base.k - (soilK * 0.02)).clamp(0.0, base.k);

    return NPKRequirement(
      n: nDeficit,
      p: pDeficit,
      k: kDeficit,
      cropType: cropType,
    );
  }

  /// Base NPK requirements (kg/rai) by crop — DOA standard
  static const _baseRequirements = <String, NPKRequirement>{
    'rice': NPKRequirement(
      n: 12,
      p: 4,
      k: 4,
      cropType: 'rice',
      note: 'ข้าวนาปี/นาปรัง: สูตร 16-20-0 หรือ 16-16-8',
    ),
    'cassava': NPKRequirement(
      n: 10,
      p: 4,
      k: 10,
      cropType: 'cassava',
      note: 'มันสำปะหลัง: อายุ 1-3 เดือน ใช้ 30-0-0, อายุ 4-5 เดือน ใช้ 6-3-30',
    ),
    'corn': NPKRequirement(
      n: 20,
      p: 8,
      k: 8,
      cropType: 'corn',
      note: 'ข้าวโพด: รองพื้น 15-15-15, บำรุง 46-0-0 อายุ 25-30 วัน',
    ),
    'sugarcane': NPKRequirement(
      n: 15,
      p: 5,
      k: 15,
      cropType: 'sugarcane',
      note: 'อ้อย: สูตร 15-15-15 รองพื้น, 46-0-0 บำรุง',
    ),
    'rubber': NPKRequirement(
      n: 12,
      p: 5,
      k: 15,
      cropType: 'rubber',
      note: 'ยางพารา: 29-5-18 ก่อนเปิดกรีด, 15-7-18 หลังเปิดกรีด',
    ),
    'palm': NPKRequirement(
      n: 15,
      p: 8,
      k: 20,
      cropType: 'palm',
      note: 'ปาล์ม: 18-46-0 ระยะไม่ให้ผล, 18-46-0+46-0-0+0-0-60 ระยะให้ผล',
    ),
    'durian': NPKRequirement(
      n: 12,
      p: 10,
      k: 12,
      cropType: 'durian',
      note: 'ทุเรียน: 15-15-15+ยูเรีย บำรุงต้น, 8-24-24 ระยะพัฒนาผล',
    ),
  };
}

// ── Data classes ────────────────────────────────────────────────────────────

class NPKRequirement {
  final double n;
  final double p;
  final double k;
  final String cropType;
  final String? note;

  const NPKRequirement({
    required this.n,
    required this.p,
    required this.k,
    required this.cropType,
    this.note,
  });
}

class FertilizerResult {
  final double ureaPerRai; // kg Urea (46-0-0) per rai
  final double dapPerRai; // kg DAP  (18-46-0) per rai
  final double mopPerRai; // kg MOP  (0-0-60)  per rai
  final double ureaTotal; // total for whole farm
  final double dapTotal;
  final double mopTotal;
  final double areaRai;
  final double nReq, pReq, kReq;

  // Approx price per 50kg bag (THB, 2024 average)
  static const _ureaBagPrice = 650.0; // 46-0-0
  static const _dapBagPrice = 1100.0; // 18-46-0
  static const _mopBagPrice = 800.0; // 0-0-60
  static const _bagSize = 50.0; // kg

  const FertilizerResult({
    required this.ureaPerRai,
    required this.dapPerRai,
    required this.mopPerRai,
    required this.ureaTotal,
    required this.dapTotal,
    required this.mopTotal,
    required this.areaRai,
    required this.nReq,
    required this.pReq,
    required this.kReq,
  });

  int get ureaBags => (ureaTotal / _bagSize).ceil();
  int get dapBags => (dapTotal / _bagSize).ceil();
  int get mopBags => (mopTotal / _bagSize).ceil();

  double get totalCost =>
      (ureaBags * _ureaBagPrice) +
      (dapBags * _dapBagPrice) +
      (mopBags * _mopBagPrice);

  double get costPerRai => areaRai > 0 ? totalCost / areaRai : 0;
}
