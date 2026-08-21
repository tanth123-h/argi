#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <PubSubClient.h>
#include <HardwareSerial.h>

// Grow Scout handheld: AF333 soil NPK sensor over RS485.
// The sensor must have its own 5-30 V supply. Do not power it from ESP32 3.3 V.

HardwareSerial RS485(2);
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

constexpr int RS485_RX = 16;
constexpr int RS485_TX = 17;
constexpr int RS485_DE_RE = 4;

constexpr uint32_t SENSOR_BAUD = 4800;
constexpr uint8_t SENSOR_ADDRESS = 1;
constexpr uint16_t NPK_REGISTER = 0x0004;

const char* MQTT_HOST = "broker.emqx.io";
constexpr uint16_t MQTT_PORT = 1883;
const char* MQTT_TOPIC = "farm/esp32/sensors";
const char* DEVICE_ID = "grow-scout-01";

uint16_t modbusCrc(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < length; i++) {
    crc ^= data[i];
    for (uint8_t bit = 0; bit < 8; bit++) {
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc;
}

bool readNpk(uint16_t& nitrogen, uint16_t& phosphorus, uint16_t& potassium) {
  uint8_t request[8] = {
      SENSOR_ADDRESS, 0x03,
      static_cast<uint8_t>(NPK_REGISTER >> 8),
      static_cast<uint8_t>(NPK_REGISTER & 0xFF),
      0x00, 0x03, 0x00, 0x00};

  const uint16_t crc = modbusCrc(request, 6);
  request[6] = static_cast<uint8_t>(crc & 0xFF);
  request[7] = static_cast<uint8_t>(crc >> 8);

  while (RS485.available()) RS485.read();

  digitalWrite(RS485_DE_RE, HIGH);
  delay(2);
  RS485.write(request, sizeof(request));
  RS485.flush();
  digitalWrite(RS485_DE_RE, LOW);

  uint8_t response[11] = {};
  size_t received = 0;
  const unsigned long deadline = millis() + 1000;
  while (millis() < deadline && received < sizeof(response)) {
    if (RS485.available()) response[received++] = RS485.read();
  }

  if (received != sizeof(response) || response[0] != SENSOR_ADDRESS ||
      response[1] != 0x03 || response[2] != 6) {
    return false;
  }

  const uint16_t receivedCrc = response[9] | (response[10] << 8);
  if (modbusCrc(response, 9) != receivedCrc) return false;

  nitrogen = (response[3] << 8) | response[4];
  phosphorus = (response[5] << 8) | response[6];
  potassium = (response[7] << 8) | response[8];
  return true;
}

void connectMqtt() {
  while (!mqtt.connected()) {
    String clientId = String(DEVICE_ID) + "-" +
                      String((uint32_t)ESP.getEfuseMac(), HEX);
    Serial.printf("Connecting MQTT broker %s:%u...\n", MQTT_HOST, MQTT_PORT);
    if (mqtt.connect(clientId.c_str())) {
      Serial.println("MQTT connected");
      return;
    }
    Serial.printf("MQTT failed, state=%d. Retrying...\n", mqtt.state());
    delay(3000);
  }
}

void publishHeartbeat() {
  String payload = "{\"device_id\":\"" + String(DEVICE_ID) +
                   "\",\"source\":\"handheld\",\"modbus_ok\":false" +
                   ",\"sensor_status\":\"not_read\",\"rssi\":" +
                   String(WiFi.RSSI()) + "}";
  mqtt.publish(MQTT_TOPIC, payload.c_str());
  Serial.println("MQTT heartbeat published: " + payload);
}

void publishNpk(uint16_t nitrogen, uint16_t phosphorus, uint16_t potassium) {
  String payload = "{\"device_id\":\"" + String(DEVICE_ID) +
                   "\",\"source\":\"handheld\",\"nitrogen\":" +
                   String(nitrogen) + ",\"phosphorus\":" + String(phosphorus) +
                   ",\"potassium\":" + String(potassium) +
                   ",\"modbus_ok\":true,\"sensor_status\":\"read_ok\",\"rssi\":" +
                   String(WiFi.RSSI()) + "}";
  mqtt.publish(MQTT_TOPIC, payload.c_str());
  Serial.println("MQTT published: " + payload);
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(RS485_DE_RE, OUTPUT);
  digitalWrite(RS485_DE_RE, LOW);
  RS485.begin(SENSOR_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);

  WiFi.mode(WIFI_STA);
  WiFiManager wifiManager;
  wifiManager.setConfigPortalTimeout(180);
  if (!wifiManager.autoConnect("Grow-Scout-Setup")) {
    Serial.println("Wi-Fi setup failed; restarting");
    delay(1000);
    ESP.restart();
  }

  Serial.print("Wi-Fi connected, IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("Wi-Fi RSSI: ");
  Serial.println(WiFi.RSSI());

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  connectMqtt();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi disconnected; restarting setup");
    delay(1000);
    ESP.restart();
  }
  if (!mqtt.connected()) connectMqtt();
  mqtt.loop();

  static unsigned long lastHeartbeat = 0;
  static unsigned long lastReading = 0;

  if (millis() - lastReading >= 3000) {
    lastReading = millis();
    uint16_t nitrogen = 0, phosphorus = 0, potassium = 0;
    if (readNpk(nitrogen, phosphorus, potassium)) {
      Serial.printf("N = %u mg/kg | P = %u mg/kg | K = %u mg/kg\n",
                    nitrogen, phosphorus, potassium);
      Serial.println("สถานะ: อ่านค่าได้");
      publishNpk(nitrogen, phosphorus, potassium);
    } else {
      Serial.println("ไม่มีเฟรม Modbus ที่ถูกต้อง: ตรวจไฟเซ็นเซอร์, A/B, address, baud และสาย MAX485");
    }
  }

  if (millis() - lastHeartbeat >= 10000) {
    lastHeartbeat = millis();
    publishHeartbeat();
  }
}

