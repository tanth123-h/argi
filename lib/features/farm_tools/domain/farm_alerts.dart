class FarmAlert {
  final String title;
  final String detail;
  final bool urgent;
  const FarmAlert({
    required this.title,
    required this.detail,
    this.urgent = false,
  });
}

class FarmAlertRules {
  const FarmAlertRules();

  List<FarmAlert> evaluate({
    required double? moisture,
    required DateTime? lastReading,
    required int rainProbability24h,
  }) {
    final alerts = <FarmAlert>[];
    if (moisture != null && moisture < 20) {
      alerts.add(
        const FarmAlert(
          title: 'ดินแห้งมาก',
          detail: 'ตรวจระบบน้ำและตรวจซ้ำในจุดเดิมก่อนตัดสินใจให้น้ำ',
          urgent: true,
        ),
      );
    } else if (moisture != null && moisture < 30) {
      alerts.add(
        const FarmAlert(
          title: 'เฝ้าระวังดินแห้ง',
          detail: 'ติดตามความชื้นและวางแผนให้น้ำตามชนิดพืช',
        ),
      );
    }
    if (rainProbability24h >= 70)
      alerts.add(
        const FarmAlert(
          title: 'โอกาสฝนสูง',
          detail: 'ชะลอการให้น้ำและติดตามประกาศฝนหนักจากหน่วยงานรัฐ',
        ),
      );
    if (lastReading == null ||
        DateTime.now().difference(lastReading).inMinutes > 30) {
      alerts.add(
        const FarmAlert(
          title: 'ESP32 ไม่ได้ส่งข้อมูลล่าสุด',
          detail: 'ตรวจไฟเลี้ยง Wi-Fi และ MQTT broker',
        ),
      );
    }
    return alerts;
  }
}
