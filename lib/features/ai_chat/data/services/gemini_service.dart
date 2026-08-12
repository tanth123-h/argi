import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:chaona_app/core/constants/app_constants.dart';

/// Wrapper around Google Gemini 2.0 Flash.
/// All prompts are in Thai context for Thai farmers.
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late final GenerativeModel _model;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    if (AppConstants.geminiApiKey.isEmpty) {
      throw StateError('Gemini API key is not configured');
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
      systemInstruction: Content.text('''
คุณคือ "ชาวนา AI" ผู้ช่วยอัจฉริยะสำหรับเกษตรกรไทย
คุณมีความเชี่ยวชาญด้าน:
- การปลูกพืช (ข้าว มันสำปะหลัง อ้อย ข้าวโพด และพืชไทยทั่วไป)
- การใช้ปุ๋ย (NPK) และการดูแลดิน
- การจัดการน้ำและระบบชลประทาน
- โรคพืชและการป้องกันกำจัด
- ราคาตลาดและการวางแผนขายผลผลิต
- การคำนวณต้นทุนและผลกำไร
- สภาพอากาศและการวางแผนการเพาะปลูก

กฎ:
- ตอบเป็นภาษาไทยเสมอ
- ให้คำตอบที่ชัดเจน เข้าใจง่าย เหมาะกับเกษตรกร
- ใช้หน่วยไร่ กิโลกรัม บาท ที่คุ้นเคยสำหรับเกษตรกรไทย
- หากมีข้อมูลดินหรือสภาพแวดล้อม ให้ใช้ข้อมูลนั้นในการตอบ
- ให้คำแนะนำที่ปฏิบัติได้จริงและประหยัดต้นทุน
'''),
    );
    _initialized = true;
  }

  /// General farming chat
  Future<String> chat({
    required String message,
    required List<Map<String, String>> history,
    String? soilContext,
    String? farmContext,
  }) async {
    init();

    // Build context prefix if soil/farm data available
    String contextPrefix = '';
    if (farmContext != null) contextPrefix += 'ข้อมูลฟาร์ม: $farmContext\n';
    if (soilContext != null) contextPrefix += 'ข้อมูลดินล่าสุด: $soilContext\n';
    if (contextPrefix.isNotEmpty) contextPrefix += '\n';

    final contents = <Content>[];
    for (final msg in history) {
      contents.add(
        Content(msg['role'] == 'user' ? 'user' : 'model', [
          TextPart(msg['content']!),
        ]),
      );
    }
    contents.add(Content.text('$contextPrefix$message'));

    final response = await _model.generateContent(contents);
    return response.text ?? 'ขออภัย ไม่สามารถตอบได้ในขณะนี้';
  }

  /// Fertilizer recommendation based on NPK + crop
  Future<String> getFertilizerRecommendation({
    required String cropType,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double moisture,
    required double phLevel,
    required double areaRai,
    int daysAfterPlanting = 0,
  }) async {
    init();

    final prompt =
        '''
วิเคราะห์ข้อมูลดินและแนะนำปุ๋ยสำหรับ:
- พืช: $cropType
- พื้นที่: $areaRai ไร่
- วันหลังปลูก: $daysAfterPlanting วัน
- ค่าดิน: N=$nitrogen, P=$phosphorus, K=$potassium mg/kg
- ความชื้น: $moisture%
- pH: $phLevel

กรุณาแนะนำ:
1. ปุ๋ยที่ควรใส่ (ชื่อสูตร เช่น 16-20-0)
2. ปริมาณต่อไร่ (กก.)
3. วิธีและเวลาที่เหมาะสม
4. ประมาณการต้นทุนปุ๋ย (บาทต่อไร่)
5. คำเตือนหากค่าดินผิดปกติ
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'ไม่สามารถวิเคราะห์ได้';
  }

  /// Planting strategy — spacing, quantity, timing
  Future<String> getPlantingStrategy({
    required String cropType,
    required double areaRai,
    String? soilData,
    String? locationRegion,
  }) async {
    init();

    final prompt =
        '''
วางแผนการปลูก$cropType สำหรับพื้นที่ $areaRai ไร่
${locationRegion != null ? "ภูมิภาค: $locationRegion" : ""}
${soilData != null ? "ข้อมูลดิน: $soilData" : ""}

คำนวณและแนะนำ:
1. จำนวนพันธุ์พืชที่ต้องการ (ต้น/ท่อน/กก.)
2. ระยะปลูกที่เหมาะสม (กว้าง × ยาว ซม.)
3. ปริมาณน้ำที่ต้องการ (ลบ.ม./ปี และต่อวัน)
4. ปุ๋ยที่ต้องการตลอดฤดูกาล (N, P, K กก.)
5. ระยะเวลาการเก็บเกี่ยว
6. ผลผลิตที่คาดหวัง (ตัน/ไร่)
7. ต้นทุนรวมโดยประมาณ (บาท)
8. ผลกำไรที่คาดหวัง (บาท) ที่ราคาตลาดปัจจุบัน
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'ไม่สามารถวางแผนได้';
  }

  /// Price forecast — should I sell now?
  Future<String> getPriceForecast({
    required String cropType,
    required double currentPricePerKg,
    required double quantityKg,
    String? seasonalContext,
  }) async {
    init();

    final prompt =
        '''
วิเคราะห์ราคาและให้คำแนะนำการขาย$cropType:
- ราคาปัจจุบัน: $currentPricePerKg บาท/กก.
- ปริมาณผลผลิต: $quantityKg กก. (${(quantityKg / 1000).toStringAsFixed(2)} ตัน)
- มูลค่ารวม: ${(currentPricePerKg * quantityKg).toStringAsFixed(0)} บาท
${seasonalContext != null ? "บริบทฤดูกาล: $seasonalContext" : ""}

กรุณาวิเคราะห์:
1. ควรขายตอนนี้หรือรอ? เพราะอะไร
2. แนวโน้มราคา$cropTypeในช่วงนี้
3. ปัจจัยที่ส่งผลต่อราคา
4. คำแนะนำเชิงกลยุทธ์
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'ไม่สามารถวิเคราะห์ได้';
  }

  /// Disease detection analysis from image description or symptoms
  Future<String> analyzeDiseaseSymptoms({
    required String cropType,
    required String symptoms,
  }) async {
    init();

    final prompt =
        '''
เกษตรกรรายงานอาการผิดปกติของ$cropType:
"$symptoms"

วินิจฉัยและแนะนำ:
1. โรคหรือแมลงที่น่าจะเป็น
2. สาเหตุและความรุนแรง
3. วิธีรักษาและป้องกัน (สารเคมีหรืออินทรีย์)
4. ขั้นตอนปฏิบัติ (3-5 ขั้น)
5. ค่าใช้จ่ายโดยประมาณ
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'ไม่สามารถวินิจฉัยได้';
  }
}
