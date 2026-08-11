import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/farm_management/domain/entities/plot.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_data.dart';

/// Static fixture data for all three Demo Mode presets.
/// No network calls — loaded synchronously.
class DemoFixtures {
  DemoFixtures._();

  static final _epoch = DateTime(2026, 7, 21, 8, 0);

  // ---------------------------------------------------------------------------
  // Preset A — Drought / Low N
  // ---------------------------------------------------------------------------
  static final _plotA = Plot(
    id: 'demo-plot-a',
    farmId: 'demo-farm-a',
    name: 'แปลงย่อย A',
    areaRai: 5.0,
    cropType: 'rice',
    createdAt: _epoch,
  );

  static final farmA = Farm(
    id: 'demo-farm-a',
    userId: 'demo-user',
    name: 'แปลงนาทดสอบ A',
    location: 'จ.พระนครศรีอยุธยา',
    areaRai: 10.0,
    cropType: 'rice',
    createdAt: _epoch,
    plots: [_plotA],
  );

  static final soilA = SoilData(
    id: 'demo-soil-a',
    farmId: 'demo-farm-a',
    moisture: 18.0,    // < 20% → drought warning
    nitrogen: 15.0,    // Low → Urea recommendation
    phosphorus: 35.0,
    potassium: 45.0,
    phLevel: 6.2,
    temperature: 32.0,
    isDemoData: true,
    createdAt: _epoch,
  );

  // ---------------------------------------------------------------------------
  // Preset B — Optimal
  // ---------------------------------------------------------------------------
  static final _plotB = Plot(
    id: 'demo-plot-b',
    farmId: 'demo-farm-b',
    name: 'แปลงย่อย B',
    areaRai: 8.0,
    cropType: 'rice',
    createdAt: _epoch,
  );

  static final farmB = Farm(
    id: 'demo-farm-b',
    userId: 'demo-user',
    name: 'แปลงนาสมบูรณ์',
    location: 'จ.สุพรรณบุรี',
    areaRai: 8.0,
    cropType: 'rice',
    createdAt: _epoch,
    plots: [_plotB],
  );

  static final soilB = SoilData(
    id: 'demo-soil-b',
    farmId: 'demo-farm-b',
    moisture: 55.0,    // optimal
    nitrogen: 50.0,    // normal
    phosphorus: 45.0,  // normal
    potassium: 55.0,   // normal
    phLevel: 6.8,
    temperature: 28.0,
    isDemoData: true,
    createdAt: _epoch,
  );

  // ---------------------------------------------------------------------------
  // Preset C — High Humidity / Disease
  // ---------------------------------------------------------------------------
  static final _plotC = Plot(
    id: 'demo-plot-c',
    farmId: 'demo-farm-c',
    name: 'แปลงย่อย C',
    areaRai: 6.0,
    cropType: 'rice',
    createdAt: _epoch,
  );

  static final farmC = Farm(
    id: 'demo-farm-c',
    userId: 'demo-user',
    name: 'แปลงนาความชื้นสูง',
    location: 'จ.ชัยนาท',
    areaRai: 6.0,
    cropType: 'rice',
    createdAt: _epoch,
    plots: [_plotC],
  );

  static final soilC = SoilData(
    id: 'demo-soil-c',
    farmId: 'demo-farm-c',
    moisture: 85.0,    // > 70% → high humidity warning
    nitrogen: 40.0,
    phosphorus: 30.0,
    potassium: 35.0,
    phLevel: 7.1,
    temperature: 29.0,
    isDemoData: true,
    createdAt: _epoch,
  );

  // ---------------------------------------------------------------------------
  // Lookup maps
  // ---------------------------------------------------------------------------
  static Farm farmFor(DemoPreset preset) => switch (preset) {
        DemoPreset.droughtLowN => farmA,
        DemoPreset.optimal => farmB,
        DemoPreset.highHumidityDisease => farmC,
        DemoPreset.none => farmB,
      };

  static SoilData soilFor(DemoPreset preset) => switch (preset) {
        DemoPreset.droughtLowN => soilA,
        DemoPreset.optimal => soilB,
        DemoPreset.highHumidityDisease => soilC,
        DemoPreset.none => soilB,
      };

  static String presetNameThai(DemoPreset preset) => switch (preset) {
        DemoPreset.droughtLowN => 'ภัยแล้ง / ไนโตรเจนต่ำ',
        DemoPreset.optimal => 'สภาพดินสมบูรณ์',
        DemoPreset.highHumidityDisease => 'ความชื้นสูง / เสี่ยงโรคพืช',
        DemoPreset.none => '',
      };

  static String presetDescriptionThai(DemoPreset preset) => switch (preset) {
        DemoPreset.droughtLowN =>
          'ดินแห้ง ความชื้น 18% ไนโตรเจนต่ำ — ระบบจะแนะนำใส่ยูเรีย',
        DemoPreset.optimal =>
          'ดินสมบูรณ์ทุกค่า — ตัวอย่างฟาร์มที่มีสุขภาพดี',
        DemoPreset.highHumidityDisease =>
          'ความชื้นสูง 85% เสี่ยงโรคไหม้ข้าว — ระบบจะแจ้งเตือน',
        DemoPreset.none => '',
      };
}
