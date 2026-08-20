// Chaona RS485 diagnostic for the photographed SOIL NPK STORAGE probe.
// This intentionally prints raw registers. It does not guess N/P/K scaling
// or pretend that this probe measures moisture, temperature, EC, or pH.

#include <Arduino.h>
#include <HardwareSerial.h>

constexpr int RS485_RX = 16;
constexpr int RS485_TX = 17;
constexpr int RS485_DIR = 4;
constexpr uint8_t SENSOR_ADDRESS = 0x01;
// Factory defaults from the SN-3002-TR family manual.
// NPK registers are 0x0004, 0x0005, and 0x0006 for the NPK profile.
constexpr uint32_t SENSOR_BAUD = 4800;
constexpr uint16_t START_REGISTER = 0x0004;
constexpr uint16_t REGISTER_COUNT = 3;

HardwareSerial SensorSerial(2);

uint16_t modbusCrc(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t pos = 0; pos < length; pos++) {
    crc ^= data[pos];
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc;
}

void sendReadRequest() {
  uint8_t request[8] = {
      SENSOR_ADDRESS, 0x03,
      static_cast<uint8_t>(START_REGISTER >> 8),
      static_cast<uint8_t>(START_REGISTER & 0xFF),
      static_cast<uint8_t>(REGISTER_COUNT >> 8),
      static_cast<uint8_t>(REGISTER_COUNT & 0xFF), 0, 0};
  const uint16_t crc = modbusCrc(request, 6);
  request[6] = crc & 0xFF;
  request[7] = crc >> 8;

  while (SensorSerial.available()) SensorSerial.read();
  digitalWrite(RS485_DIR, HIGH);
  delay(2);
  SensorSerial.write(request, sizeof(request));
  SensorSerial.flush();
  digitalWrite(RS485_DIR, LOW);

  Serial.print("TX:");
  for (uint8_t byte : request) {
    Serial.printf(" %02X", byte);
  }
  Serial.println();
}

void readResponse() {
  uint8_t response[64]{};
  size_t received = 0;
  const unsigned long deadline = millis() + 1200;
  while (millis() < deadline && received < sizeof(response)) {
    if (SensorSerial.available()) response[received++] = SensorSerial.read();
  }

  Serial.printf("RX (%u bytes):", static_cast<unsigned>(received));
  for (size_t i = 0; i < received; i++) Serial.printf(" %02X", response[i]);
  Serial.println();

  const size_t expected = 5 + REGISTER_COUNT * 2;
  if (received != expected) {
    Serial.println("No complete response. Check sensor power, A/B, address, and baud.");
    return;
  }
  const uint16_t receivedCrc = response[received - 2] |
                               (response[received - 1] << 8);
  if (modbusCrc(response, received - 2) != receivedCrc) {
    Serial.println("CRC mismatch. Check wiring, baud, and electrical noise.");
    return;
  }
  Serial.println("Raw registers (do not interpret until the exact manual is confirmed):");
  for (uint16_t i = 0; i < REGISTER_COUNT; i++) {
    const uint16_t value = (response[3 + i * 2] << 8) | response[4 + i * 2];
    Serial.printf("  0x%04X = %u (0x%04X)\n", START_REGISTER + i, value, value);
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(RS485_DIR, OUTPUT);
  digitalWrite(RS485_DIR, LOW);
  SensorSerial.begin(SENSOR_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);
  Serial.println("Chaona RS485 raw diagnostic");
  Serial.println("Probe profile: SOIL NPK STORAGE photo; register map unverified");
}

void loop() {
  sendReadRequest();
  readResponse();
  delay(3000);
}
