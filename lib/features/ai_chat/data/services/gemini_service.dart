import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:chaona_app/core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around the configured Gemini model.
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
      _initialized = true;
      return;
    }
    _model = GenerativeModel(
      model: AppConstants.geminiModel,
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
- จัดรูปแบบให้อ่านง่ายสำหรับคนทั่วไป ใช้หัวข้อสั้นและรายการคำแนะนำ
- ห้ามใช้ Markdown เช่น ###, **, __ หรือ --- และห้ามใส่รหัสสถานะภาษาอังกฤษในคำตอบที่ผู้ใช้เห็น
'''),
    );
    _initialized = true;
  }

  Future<String> _proxy({
    required String prompt,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'gemini-proxy',
          body: {
            'prompt': prompt,
            if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
            if (mimeType != null) 'mimeType': mimeType,
          },
        );
        final data = response.data;
        if (data is Map && data['text'] is String) return data['text'] as String;
        throw StateError('Gemini proxy returned invalid data');
      } catch (error) {
        final raw = error.toString().toLowerCase();
        final transient = raw.contains('status: 0') ||
            raw.contains('connection') ||
            raw.contains('socket') ||
            raw.contains('aborted') ||
            raw.contains('timeout');
        if (!transient || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
      }
    }
    throw StateError('Gemini proxy unavailable');
  }

  Future<String> _generateText(String prompt) async {
    init();
    if (AppConstants.geminiApiKey.isEmpty) return _proxy(prompt: prompt);
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'ไม่สามารถวิเคราะห์ได้';
  }

  static String readableError(Object error) {
    final raw = error.toString();
    if (raw.contains('API key is not configured')) {
      return 'ยังไม่ได้ตั้งค่า AI: deploy Supabase Function gemini-proxy หรือเพิ่ม GEMINI_API_KEY สำหรับการพัฒนา';
    }
    if (raw.contains('403') || raw.toLowerCase().contains('permission')) {
      return 'Gemini ปฏิเสธ API key นี้ กรุณาตรวจสอบว่า key ยังใช้งานได้และเปิด Gemini API แล้ว';
    }
    if (raw.contains('429')) {
      return 'Gemini ใช้งานเกินโควตาชั่วคราว กรุณารอสักครู่แล้วลองใหม่';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('network') ||
        raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('aborted') ||
        raw.contains('status: 0')) {
      return 'เชื่อมต่อ Gemini ไม่ได้ชั่วคราว ระบบลองใหม่อัตโนมัติแล้ว กรุณาตรวจสอบอินเทอร์เน็ตหรือกดวิเคราะห์ใหม่';
    }
    return 'Gemini ทำงานไม่สำเร็จ: ${raw.replaceFirst('Exception: ', '')}';
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
    contextPrefix += '''
แหล่งอ้างอิงที่ระบบอนุญาตให้ใช้:
- FAO, Crop Evapotranspiration (ข้อมูลความต้องการน้ำ): https://www.fao.org/4/f2430e/f2430e.pdf
- FAO, Crop water needs: https://www.fao.org/4/s2022e/s2022e02.htm
- Rice Knowledge Bank, Rice Department Thailand: https://rkb.ricethailand.go.th/web/content_page.php?code=A-1GT2GJ7SD8
ห้ามสร้างตัวเลข เกณฑ์ หรือ URL ใหม่เอง หากข้อมูลไม่พอให้บอกว่าต้องเก็บข้อมูลเพิ่ม และแยกให้ชัดว่าเป็นคำอธิบายโดย AI ไม่ใช่ผลวินิจฉัยจากเซนเซอร์

''';

    final contents = <Content>[];
    for (final msg in history) {
      contents.add(
        Content(msg['role'] == 'user' ? 'user' : 'model', [
          TextPart(msg['content']!),
        ]),
      );
    }
    contents.add(Content.text('$contextPrefix$message'));

    if (AppConstants.geminiApiKey.isEmpty) {
      final historyText = history
          .map((item) => '${item['role']}: ${item['content']}')
          .join('\n');
      return _proxy(prompt: '$historyText\n$contextPrefix$message');
    }
    final response = await _model.generateContent(contents);
    return response.text ?? 'ขออภัย ไม่สามารถตอบได้ในขณะนี้';
  }

  /// Fertilizer recommendation based on NPK + crop
  Future<String> getFertilizerRecommendation({
    required String cropType,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    double? moisture,
    double? phLevel,
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
${moisture == null ? '- ความชื้น: ไม่มีเซนเซอร์วัดความชื้น' : '- ความชื้น: $moisture%'}
${phLevel == null ? '- pH: ไม่มีเซนเซอร์วัด pH' : '- pH: $phLevel'}

กรุณาแนะนำ:
1. ปุ๋ยที่ควรพิจารณา โดยอธิบายว่าเป็นคำแนะนำเบื้องต้นจาก N/P/K
2. ปริมาณต่อไร่ (กก.) เฉพาะเมื่อมีข้อมูลอ้างอิงเพียงพอ
3. วิธีและเวลาที่เหมาะสม
4. ประมาณการต้นทุนปุ๋ย (บาทต่อไร่)
5. คำเตือนหากค่าดินผิดปกติ
''';

    return _generateText(prompt);
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

    return _generateText(prompt);
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

    return _generateText(prompt);
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

    return _generateText(prompt);
  }

  Future<String> analyzeLeafImage({
    required String cropType,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    init();
    final prompt = '''วิเคราะห์ภาพใบพืชชนิด $cropType นี้แบบคัดกรองเบื้องต้น
ตอบเป็นภาษาไทยและแยกหัวข้อ: สิ่งที่สังเกตได้, โรค/แมลงที่เป็นไปได้, ความมั่นใจ, ขั้นตอนตรวจยืนยัน, การปฏิบัติที่ปลอดภัย
ห้ามยืนยันโรคจากภาพเพียงอย่างเดียว ห้ามสร้างชื่อสารเคมี อัตราใช้ หรือแหล่งอ้างอิงใหม่ หากไม่มีข้อมูลยืนยันให้บอกว่าต้องส่งตรวจ''';
    if (AppConstants.geminiApiKey.isEmpty) {
      return _proxy(prompt: prompt, imageBytes: imageBytes, mimeType: mimeType);
    }
    final response = await _model.generateContent([
      Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
    ]);
    return response.text ?? 'ไม่สามารถวิเคราะห์ภาพได้';
  }
}
