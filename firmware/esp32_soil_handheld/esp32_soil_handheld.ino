#include <Arduino.h>
#include <HardwareSerial.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <WiFiManager.h>

HardwareSerial RS485(2);
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

// Wiring used by the working serial-only sketch.
constexpr int RS485_RX = 16;
constexpr int RS485_TX = 17;
constexpr int RS485_DE_RE = 4;

const char* MQTT_HOST = "broker.emqx.io";
constexpr uint16_t MQTT_PORT = 1883;
const char* MQTT_TOPIC = "farm/esp32/sensors";
const char* DEVICE_ID = "grow-scout-01";

uint8_t sensorAddress = 1;
uint32_t sensorBaud = 4800;
uint16_t startRegister = 0x0004;
bool sensorFound = false;

bool lastModbusOk = false;
uint16_t lastNitrogen = 0;
uint16_t lastPhosphorus = 0;
uint16_t lastPotassium = 0;

unsigned long lastReadAt = 0;
unsigned long lastHeartbeatAt = 0;
constexpr unsigned long READ_INTERVAL_MS = 3000;
constexpr unsigned long HEARTBEAT_INTERVAL_MS = 10000;

uint16_t modbusCRC(const uint8_t* data, uint8_t length) {
  uint16_t crc = 0xFFFF;
  for (uint8_t i = 0; i < length; i++) {
    crc ^= data[i];
    for (uint8_t j = 0; j < 8; j++) {
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc;
}

void startRS485(uint32_t baud) {
  RS485.end();
  delay(20);
  RS485.begin(baud, SERIAL_8N1, RS485_RX, RS485_TX);
  sensorBaud = baud;
}

bool readNPK(
  uint8_t address,
  uint32_t baud,
  uint16_t reg,
  uint16_t& nitrogen,
  uint16_t& phosphorus,
  uint16_t& potassium
) {
  if (baud != sensorBaud) {
    startRS485(baud);
  }

  uint8_t request[8];
  request[0] = address;
  request[1] = 0x03;
  request[2] = reg >> 8;
  request[3] = reg & 0xFF;
  request[4] = 0x00;
  request[5] = 0x03;

  const uint16_t requestCRC = modbusCRC(request, 6);
  request[6] = requestCRC & 0xFF;
  request[7] = requestCRC >> 8;

  while (RS485.available()) {
    RS485.read();
  }

  digitalWrite(RS485_DE_RE, HIGH);
  delay(2);
  RS485.write(request, sizeof(request));
  RS485.flush();
  digitalWrite(RS485_DE_RE, LOW);

  uint8_t response[11];
  uint8_t received = 0;
  const unsigned long startedAt = millis();
  while (millis() - startedAt < 1000 && received < sizeof(response)) {
    if (RS485.available()) {
      response[received++] = RS485.read();
    }
  }

  if (received != sizeof(response)) {
    return false;
  }
  if (response[0] != address || response[1] != 0x03 || response[2] != 6) {
    return false;
  }

  const uint16_t receivedCRC = response[9] | (response[10] << 8);
  if (modbusCRC(response, 9) != receivedCRC) {
    return false;
  }

  nitrogen = (response[3] << 8) | response[4];
  phosphorus = (response[5] << 8) | response[6];
  potassium = (response[7] << 8) | response[8];
  return true;
}

bool findSensor() {
  const uint32_t baudRates[] = {4800, 9600, 2400};
  const uint16_t registers[] = {0x0004, 0x001E};
  const uint8_t addresses[] = {1, 2, 3};

  bool hasValidFallback = false;
  uint8_t fallbackAddress = 1;
  uint32_t fallbackBaud = 4800;
  uint16_t fallbackRegister = 0x0004;

  for (const uint32_t baud : baudRates) {
    for (const uint8_t address : addresses) {
      for (const uint16_t reg : registers) {
        uint16_t nitrogen = 0;
        uint16_t phosphorus = 0;
        uint16_t potassium = 0;

        if (!readNPK(address, baud, reg, nitrogen, phosphorus, potassium)) {
          continue;
        }

        if (!hasValidFallback) {
          hasValidFallback = true;
          fallbackAddress = address;
          fallbackBaud = baud;
          fallbackRegister = reg;
        }

        if (nitrogen != 0 || phosphorus != 0 || potassium != 0) {
          sensorAddress = address;
          sensorBaud = baud;
          startRegister = reg;
          return true;
        }
      }
    }
  }

  // A CRC-valid all-zero frame can still be a real reading.
  if (hasValidFallback) {
    sensorAddress = fallbackAddress;
    sensorBaud = fallbackBaud;
    startRegister = fallbackRegister;
    return true;
  }
  return false;
}

void printSensorConfiguration() {
  Serial.println("Sensor found");
  Serial.print("Address: ");
  Serial.println(sensorAddress);
  Serial.print("Baud rate: ");
  Serial.println(sensorBaud);
  Serial.print("Register: 0x");
  Serial.println(startRegister, HEX);
}

void connectMqtt() {
  if (WiFi.status() != WL_CONNECTED || mqtt.connected()) {
    return;
  }

  Serial.print("Connecting MQTT ");
  Serial.print(MQTT_HOST);
  Serial.print(":");
  Serial.println(MQTT_PORT);

  String clientId = String(DEVICE_ID) + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  if (mqtt.connect(clientId.c_str())) {
    Serial.println("MQTT connected");
  } else {
    Serial.print("MQTT failed, state: ");
    Serial.println(mqtt.state());
  }
}

bool publishPayload(const String& payload, const char* label) {
  connectMqtt();
  if (!mqtt.connected()) {
    Serial.println("MQTT publish skipped: broker is offline");
    return false;
  }

  const bool sent = mqtt.publish(MQTT_TOPIC, payload.c_str());
  Serial.print(label);
  Serial.print(sent ? ": " : " failed: ");
  Serial.println(payload);
  return sent;
}

void publishNpk(uint16_t nitrogen, uint16_t phosphorus, uint16_t potassium) {
  const String payload =
    String("{\"device_id\":\"") + DEVICE_ID +
    "\",\"source\":\"handheld\"" +
    ",\"nitrogen\":" + String(nitrogen) +
    ",\"phosphorus\":" + String(phosphorus) +
    ",\"potassium\":" + String(potassium) +
    ",\"modbus_ok\":true" +
    ",\"sensor_status\":\"read_ok\"" +
    ",\"rssi\":" + String(WiFi.RSSI()) + "}";

  publishPayload(payload, "MQTT NPK published");
}

void publishHeartbeat() {
  String payload =
    String("{\"device_id\":\"") + DEVICE_ID +
    "\",\"source\":\"handheld\"" +
    ",\"modbus_ok\":" + String(lastModbusOk ? "true" : "false") +
    ",\"sensor_status\":\"" + String(lastModbusOk ? "read_ok" : "not_read") + "\"" +
    ",\"rssi\":" + String(WiFi.RSSI());

  if (lastModbusOk) {
    payload += ",\"nitrogen\":" + String(lastNitrogen);
    payload += ",\"phosphorus\":" + String(lastPhosphorus);
    payload += ",\"potassium\":" + String(lastPotassium);
  }
  payload += "}";

  publishPayload(payload, "MQTT heartbeat published");
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(RS485_DE_RE, OUTPUT);
  digitalWrite(RS485_DE_RE, LOW);
  startRS485(4800);

  Serial.println();
  Serial.println("Grow Scout - ESP32 Soil NPK + MQTT");
  Serial.println("Serial Monitor: 115200 baud");

  WiFi.mode(WIFI_STA);
  WiFiManager wifiManager;
  wifiManager.setConfigPortalTimeout(180);
  if (!wifiManager.autoConnect("Grow-Scout-Setup")) {
    Serial.println("Wi-Fi setup failed; restarting");
    delay(3000);
    ESP.restart();
  }

  Serial.print("Wi-Fi connected, IP: ");
  Serial.println(WiFi.localIP());

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setBufferSize(512);
  connectMqtt();
  Serial.println("Searching for NPK sensor...");
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    connectMqtt();
    mqtt.loop();
  }

  const unsigned long now = millis();
  if (now - lastReadAt >= READ_INTERVAL_MS) {
    lastReadAt = now;

    if (!sensorFound) {
      sensorFound = findSensor();
      if (sensorFound) {
        printSensorConfiguration();
      }
    }

    if (sensorFound) {
      uint16_t nitrogen = 0;
      uint16_t phosphorus = 0;
      uint16_t potassium = 0;
      lastModbusOk = readNPK(
        sensorAddress,
        sensorBaud,
        startRegister,
        nitrogen,
        phosphorus,
        potassium
      );

      if (lastModbusOk) {
        lastNitrogen = nitrogen;
        lastPhosphorus = phosphorus;
        lastPotassium = potassium;

        Serial.println("----- SOIL NPK RESULT -----");
        Serial.print("Nitrogen (N): ");
        Serial.print(nitrogen);
        Serial.println(" ppm");
        Serial.print("Phosphorus (P): ");
        Serial.print(phosphorus);
        Serial.println(" ppm");
        Serial.print("Potassium (K): ");
        Serial.print(potassium);
        Serial.println(" ppm");
        Serial.println("---------------------------");

        publishNpk(nitrogen, phosphorus, potassium);
      } else {
        Serial.println("Modbus read failed; sensor scan will run again");
        sensorFound = false;
      }
    } else {
      lastModbusOk = false;
      Serial.println("Sensor not found: check 12V sensor power, A/B, and common GND");
    }
  }

  if (now - lastHeartbeatAt >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatAt = now;
    publishHeartbeat();
  }

  delay(10);
}
