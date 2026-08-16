#include <Arduino.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// Fill these before Wi-Fi testing. Keep private credentials out of git.
const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* API_URL = ""; // Example: https://your-api.example.com/sensor/ingest
const char* DEVICE_ID = "handheld-01";
const char* MQTT_HOST = "broker.emqx.io";
constexpr uint16_t MQTT_PORT = 1883;
const char* MQTT_TOPIC = "farm/esp32/sensors";

constexpr int RS485_RX = 16;
constexpr int RS485_TX = 17;
constexpr int RS485_DIR = 4; // MAX485 DE and /RE tied together
constexpr uint8_t SENSOR_ADDRESS = 0x01;
constexpr uint32_t SENSOR_BAUD = 4800;

HardwareSerial SensorSerial(2);
LiquidCrystal_I2C lcd(0x27, 16, 2);
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

struct SoilReading {
  float moisture;
  float temperature;
  uint16_t ec;
  float ph;
  uint16_t nitrogen;
  uint16_t phosphorus;
  uint16_t potassium;
};

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

bool readRegisters(uint16_t start, uint16_t count, uint16_t* values) {
  uint8_t request[8] = {
      SENSOR_ADDRESS, 0x03,
      static_cast<uint8_t>(start >> 8), static_cast<uint8_t>(start & 0xFF),
      static_cast<uint8_t>(count >> 8), static_cast<uint8_t>(count & 0xFF),
      0, 0};
  const uint16_t crc = modbusCrc(request, 6);
  request[6] = crc & 0xFF;
  request[7] = crc >> 8;

  while (SensorSerial.available()) SensorSerial.read();
  digitalWrite(RS485_DIR, HIGH);
  delay(2);
  SensorSerial.write(request, sizeof(request));
  SensorSerial.flush();
  digitalWrite(RS485_DIR, LOW);

  const size_t expected = 5 + count * 2;
  uint8_t response[32];
  size_t received = 0;
  const unsigned long deadline = millis() + 1000;
  while (millis() < deadline && received < expected) {
    if (SensorSerial.available()) response[received++] = SensorSerial.read();
  }
  if (received != expected || response[0] != SENSOR_ADDRESS || response[1] != 0x03 ||
      response[2] != count * 2) return false;

  const uint16_t receivedCrc = response[received - 2] | (response[received - 1] << 8);
  if (modbusCrc(response, received - 2) != receivedCrc) return false;
  for (uint16_t i = 0; i < count; i++) {
    values[i] = (response[3 + i * 2] << 8) | response[4 + i * 2];
  }
  return true;
}

bool readSoil(SoilReading& reading) {
  uint16_t registers[7];
  if (!readRegisters(0x0000, 7, registers)) return false;
  reading.moisture = registers[0] / 10.0f;
  reading.temperature = static_cast<int16_t>(registers[1]) / 10.0f;
  reading.ec = registers[2];
  reading.ph = registers[3] / 10.0f;
  reading.nitrogen = registers[4];
  reading.phosphorus = registers[5];
  reading.potassium = registers[6];
  return true;
}

void showReading(const SoilReading& reading) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("M:");
  lcd.print(reading.moisture, 1);
  lcd.print(" pH:");
  lcd.print(reading.ph, 1);
  lcd.setCursor(0, 1);
  lcd.print("N:");
  lcd.print(reading.nitrogen);
  lcd.print(" P:");
  lcd.print(reading.phosphorus);
  lcd.print(" K:");
  lcd.print(reading.potassium);
}

void uploadReading(const SoilReading& reading) {
  if (strlen(API_URL) == 0 || WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  http.begin(API_URL);
  http.addHeader("Content-Type", "application/json");
  String json = "{\"device_id\":\"" + String(DEVICE_ID) +
                "\",\"moisture\":" + String(reading.moisture, 1) +
                ",\"temperature\":" + String(reading.temperature, 1) +
                ",\"ec\":" + String(reading.ec) +
                ",\"ph\":" + String(reading.ph, 1) +
                ",\"nitrogen\":" + String(reading.nitrogen) +
                ",\"phosphorus\":" + String(reading.phosphorus) +
                ",\"potassium\":" + String(reading.potassium) + "}";
  const int status = http.POST(json);
  Serial.printf("Upload status: %d\n", status);
  http.end();
}

void ensureMqtt() {
  if (WiFi.status() != WL_CONNECTED || mqtt.connected()) return;
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  const String clientId = String(DEVICE_ID) + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  mqtt.connect(clientId.c_str());
}

void publishReading(const SoilReading& reading) {
  ensureMqtt();
  if (!mqtt.connected()) return;
  String json = "{\"device_id\":\"" + String(DEVICE_ID) +
                "\",\"moisture\":" + String(reading.moisture, 1) +
                ",\"temperature\":" + String(reading.temperature, 1) +
                ",\"ec\":" + String(reading.ec) +
                ",\"ph\":" + String(reading.ph, 1) +
                ",\"nitrogen\":" + String(reading.nitrogen) +
                ",\"phosphorus\":" + String(reading.phosphorus) +
                ",\"potassium\":" + String(reading.potassium) +
                ",\"modbus_ok\":true}";
  mqtt.publish(MQTT_TOPIC, json.c_str());
  mqtt.loop();
}

void setup() {
  Serial.begin(115200);
  pinMode(RS485_DIR, OUTPUT);
  digitalWrite(RS485_DIR, LOW);
  SensorSerial.begin(SENSOR_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.print("Chaona sensor");

  if (strlen(WIFI_SSID) > 0) {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    const unsigned long deadline = millis() + 10000;
    while (WiFi.status() != WL_CONNECTED && millis() < deadline) delay(250);
  }
}

void loop() {
  SoilReading reading{};
  if (readSoil(reading)) {
    Serial.printf("M %.1f%% T %.1fC EC %u pH %.1f N %u P %u K %u\n",
                  reading.moisture, reading.temperature, reading.ec, reading.ph,
                  reading.nitrogen, reading.phosphorus, reading.potassium);
    showReading(reading);
    uploadReading(reading);
    publishReading(reading);
  } else {
    lcd.clear();
    lcd.print("Sensor read fail");
    Serial.println("Modbus read failed: check power, A/B, address, baud, CRC");
  }
  delay(3000);
}
