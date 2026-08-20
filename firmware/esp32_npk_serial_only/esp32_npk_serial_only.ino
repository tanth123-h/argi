// Grow a Garden - AF333 / SN-3002 NPK serial test
// ESP32 + MAX485, no Wi-Fi and no MQTT.
// Serial Monitor: 115200 baud

#include <Arduino.h>

HardwareSerial SensorSerial(2);

// ESP32 wiring
static const int SENSOR_RX = 16;  // MAX485 RO -> ESP32 RX2
static const int SENSOR_TX = 17;  // ESP32 TX2 -> MAX485 DI
static const int MAX485_DE_RE = 4; // DE and RE joined together

// AF333 values commonly use these Modbus settings.
static const uint8_t SENSOR_ADDRESS = 0x01;
static const uint32_t SENSOR_BAUD = 4800;
static const uint16_t NPK_REGISTER = 0x0004;

uint16_t modbusCrc(const uint8_t *data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < length; i++) {
    crc ^= data[i];
    for (uint8_t bit = 0; bit < 8; bit++) {
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : (crc >> 1);
    }
  }
  return crc;
}

bool readNpk(uint16_t &n, uint16_t &p, uint16_t &k) {
  // Modbus request: address, function, start register, quantity, CRC.
  uint8_t request[8] = {
      SENSOR_ADDRESS,
      0x03,
      static_cast<uint8_t>(NPK_REGISTER >> 8),
      static_cast<uint8_t>(NPK_REGISTER & 0xFF),
      0x00,
      0x03,
      0x00,
      0x00,
  };

  uint16_t requestCrc = modbusCrc(request, 6);
  request[6] = requestCrc & 0xFF;
  request[7] = requestCrc >> 8;

  while (SensorSerial.available()) {
    SensorSerial.read();
  }

  // Transmit mode.
  digitalWrite(MAX485_DE_RE, HIGH);
  delay(2);
  SensorSerial.write(request, sizeof(request));
  SensorSerial.flush();
  delay(2);
  // Receive mode.
  digitalWrite(MAX485_DE_RE, LOW);

  // Expected response: address + function + byte count + 6 data + CRC.
  uint8_t response[11] = {};
  size_t received = 0;
  const unsigned long deadline = millis() + 700;

  while (millis() < deadline && received < sizeof(response)) {
    if (SensorSerial.available()) {
      response[received++] = SensorSerial.read();
    }
  }

  if (received != sizeof(response)) {
    return false;
  }

  if (response[0] != SENSOR_ADDRESS || response[1] != 0x03 ||
      response[2] != 0x06) {
    return false;
  }

  uint16_t responseCrc = response[9] | (response[10] << 8);
  if (modbusCrc(response, 9) != responseCrc) {
    return false;
  }

  n = (response[3] << 8) | response[4];
  p = (response[5] << 8) | response[6];
  k = (response[7] << 8) | response[8];
  return true;
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(MAX485_DE_RE, OUTPUT);
  digitalWrite(MAX485_DE_RE, LOW); // receive mode

  SensorSerial.begin(SENSOR_BAUD, SERIAL_8N1, SENSOR_RX, SENSOR_TX);

  Serial.println();
  Serial.println("=== AF333 NPK SERIAL ONLY ===");
  Serial.println("115200 baud | sensor 4800 baud | address 1 | register 0x0004");
  Serial.println("เริ่มอ่านค่า...");
}

void loop() {
  uint16_t n = 0;
  uint16_t p = 0;
  uint16_t k = 0;

  if (readNpk(n, p, k)) {
    Serial.printf("N = %u mg/kg | P = %u mg/kg | K = %u mg/kg\n", n, p, k);
    Serial.println("สถานะ: Modbus อ่านได้");
  } else {
    Serial.println("อ่านไม่สำเร็จ: ตรวจไฟเซ็นเซอร์, A/B, address, baud และ MAX485");
  }

  Serial.println("--------------------------------------");
  delay(2000);
}
