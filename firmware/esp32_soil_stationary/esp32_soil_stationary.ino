#include <Arduino.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <PubSubClient.h>

// Grow a Garden - Stationary ESP32 node
// AF333/SN-3002 NPK-only stationary node over Modbus RS485.

HardwareSerial RS485(2);
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

constexpr int RS485_RX = 16;
constexpr int RS485_TX = 17;
constexpr int RS485_DE_RE = 4;
constexpr char MQTT_HOST[] = "broker.emqx.io";
constexpr uint16_t MQTT_PORT = 1883;
constexpr char MQTT_TOPIC[] = "farm/esp32/sensors";
constexpr char DEVICE_ID[] = "grow-station-01";

constexpr uint8_t SENSOR_ADDRESS = 1;
constexpr uint32_t SENSOR_BAUD = 4800;
constexpr uint16_t SENSOR_REGISTER = 0x0004;

uint32_t lastSampleMs = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t lastMqttAttemptMs = 0;

uint16_t modbusCRC(const uint8_t *data, uint8_t length) {
  uint16_t crc = 0xFFFF;
  for (uint8_t i = 0; i < length; i++) {
    crc ^= data[i];
    for (uint8_t j = 0; j < 8; j++) {
      crc = (crc & 1) ? ((crc >> 1) ^ 0xA001) : (crc >> 1);
    }
  }
  return crc;
}

void startRS485() {
  RS485.end();
  delay(20);
  RS485.begin(SENSOR_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);
}

bool readNpk(uint16_t &nitrogen, uint16_t &phosphorus, uint16_t &potassium) {
  uint8_t request[8] = {
      SENSOR_ADDRESS, 0x03,
      static_cast<uint8_t>(SENSOR_REGISTER >> 8),
      static_cast<uint8_t>(SENSOR_REGISTER & 0xFF),
      0x00, 0x03, 0x00, 0x00};
  const uint16_t requestCrc = modbusCRC(request, 6);
  request[6] = requestCrc & 0xFF;
  request[7] = requestCrc >> 8;

  while (RS485.available()) RS485.read();
  digitalWrite(RS485_DE_RE, HIGH);
  delay(2);
  RS485.write(request, sizeof(request));
  RS485.flush();
  delay(2);
  digitalWrite(RS485_DE_RE, LOW);

  uint8_t response[11];
  uint8_t received = 0;
  const uint32_t deadline = millis() + 1000;
  while (millis() < deadline && received < sizeof(response)) {
    if (RS485.available()) response[received++] = RS485.read();
  }

  if (received != sizeof(response) || response[0] != SENSOR_ADDRESS ||
      response[1] != 0x03 || response[2] != 6) {
    return false;
  }
  const uint16_t responseCrc = response[9] | (response[10] << 8);
  if (modbusCRC(response, 9) != responseCrc) return false;

  nitrogen = (response[3] << 8) | response[4];
  phosphorus = (response[5] << 8) | response[6];
  potassium = (response[7] << 8) | response[8];
  return true;
}

void publishJson(bool modbusOk, uint16_t nitrogen = 0,
                 uint16_t phosphorus = 0, uint16_t potassium = 0) {
  char payload[300];
  int written = snprintf(
      payload, sizeof(payload),
      "{\"device_id\":\"%s\",\"source\":\"stationary\","
      "\"modbus_ok\":%s,\"sensor_status\":\"%s\","
      "\"rssi\":%d,"
      "\"uptime_s\":%lu",
      DEVICE_ID, modbusOk ? "true" : "false",
      modbusOk ? "read" : "not_read", WiFi.RSSI(),
      static_cast<unsigned long>(millis() / 1000));

  if (modbusOk && written > 0 && written < static_cast<int>(sizeof(payload))) {
    written += snprintf(payload + written, sizeof(payload) - written,
                        ",\"nitrogen\":%u,\"phosphorus\":%u,\"potassium\":%u",
                        nitrogen, phosphorus, potassium);
  }
  if (written > 0 && written < static_cast<int>(sizeof(payload) - 2)) {
    strncat(payload, "}", sizeof(payload) - strlen(payload) - 1);
    mqtt.publish(MQTT_TOPIC, payload, false);
    Serial.print("MQTT published: ");
    Serial.println(payload);
  }
}

void connectMqtt() {
  if (mqtt.connected()) return;
  if (millis() - lastMqttAttemptMs < 5000) return;
  lastMqttAttemptMs = millis();

  char clientId[48];
  snprintf(clientId, sizeof(clientId), "%s-%08lX", DEVICE_ID,
           static_cast<unsigned long>(ESP.getEfuseMac()));
  Serial.print("Connecting MQTT ");
  Serial.print(MQTT_HOST);
  Serial.print(":");
  Serial.println(MQTT_PORT);
  if (mqtt.connect(clientId)) {
    Serial.println("MQTT connected");
  } else {
    Serial.print("MQTT failed, state: ");
    Serial.println(mqtt.state());
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(RS485_DE_RE, OUTPUT);
  digitalWrite(RS485_DE_RE, LOW);
  startRS485();

  WiFi.mode(WIFI_STA);
  WiFiManager wifiManager;
  wifiManager.setConfigPortalTimeout(180);
  if (!wifiManager.autoConnect("Grow-Station-Setup")) {
    Serial.println("Wi-Fi setup failed; restarting");
    delay(1000);
    ESP.restart();
  }
  Serial.print("Wi-Fi connected, IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("Wi-Fi RSSI: ");
  Serial.println(WiFi.RSSI());

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  lastSampleMs = millis() - 10000;
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    delay(100);
    return;
  }
  connectMqtt();
  mqtt.loop();

  if (millis() - lastSampleMs >= 10000) {
    lastSampleMs = millis();
    uint16_t nitrogen, phosphorus, potassium;
    const bool ok = readNpk(nitrogen, phosphorus, potassium);
    if (ok) {
      Serial.printf("N = %u mg/kg | P = %u mg/kg | K = %u mg/kg\n",
                    nitrogen, phosphorus, potassium);
      publishJson(true, nitrogen, phosphorus, potassium);
    } else {
      Serial.println("Modbus read failed: check AF333 power, A/B, address, baud, CRC");
      publishJson(false);
    }
  }

  if (millis() - lastHeartbeatMs >= 30000) {
    lastHeartbeatMs = millis();
    if (mqtt.connected()) publishJson(false);
  }
  delay(10);
}
