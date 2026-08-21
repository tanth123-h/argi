#include <Arduino.h>
#include <HardwareSerial.h>

HardwareSerial RS485(2);

// ESP32 pins
#define RS485_RX 16
#define RS485_TX 17
#define RS485_DE_RE 4

uint8_t sensorAddress = 1;
uint32_t sensorBaud = 4800;
uint16_t startRegister = 0x0004;
bool sensorFound = false;

uint16_t modbusCRC(uint8_t *data, uint8_t length) {
  uint16_t crc = 0xFFFF;

  for (uint8_t i = 0; i < length; i++) {
    crc ^= data[i];

    for (uint8_t j = 0; j < 8; j++) {
      if (crc & 1)
        crc = (crc >> 1) ^ 0xA001;
      else
        crc >>= 1;
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

bool readNPK(uint8_t address, uint32_t baud, uint16_t reg,
             uint16_t &nitrogen,
             uint16_t &phosphorus,
             uint16_t &potassium) {
  if (baud != sensorBaud) {
    startRS485(baud);
  }

  uint8_t request[8];

  request[0] = address;
  request[1] = 0x03;              // Read holding registers
  request[2] = reg >> 8;
  request[3] = reg & 0xFF;
  request[4] = 0x00;
  request[5] = 0x03;              // Read 3 registers

  uint16_t crc = modbusCRC(request, 6);
  request[6] = crc & 0xFF;
  request[7] = crc >> 8;

  while (RS485.available()) {
    RS485.read();
  }

  digitalWrite(RS485_DE_RE, HIGH);
  delay(2);

  RS485.write(request, 8);
  RS485.flush();

  digitalWrite(RS485_DE_RE, LOW);

  uint8_t response[11];
  uint8_t received = 0;

  unsigned long timeout = millis() + 1000;

  while (millis() < timeout && received < 11) {
    if (RS485.available()) {
      response[received++] = RS485.read();
    }
  }

  if (received != 11) {
    return false;
  }

  if (response[0] != address || response[1] != 0x03 ||
      response[2] != 6) {
    return false;
  }

  uint16_t receivedCRC =
      response[9] | (response[10] << 8);

  if (modbusCRC(response, 9) != receivedCRC) {
    return false;
  }

  nitrogen =
      (response[3] << 8) | response[4];

  phosphorus =
      (response[5] << 8) | response[6];

  potassium =
      (response[7] << 8) | response[8];

  return true;
}

bool findSensor() {
  uint32_t baudRates[] = {4800, 9600, 2400};
  uint16_t registers[] = {0x0004, 0x001E};
  uint8_t addresses[] = {1, 2, 3};

  for (uint8_t b = 0; b < 3; b++) {
    for (uint8_t a = 0; a < 3; a++) {
      for (uint8_t r = 0; r < 2; r++) {
        uint16_t n, p, k;

        if (readNPK(addresses[a], baudRates[b],
                    registers[r], n, p, k)) {
          if (n != 0 || p != 0 || k != 0) {
            sensorAddress = addresses[a];
            sensorBaud = baudRates[b];
            startRegister = registers[r];

            Serial.println("Sensor found!");
            Serial.print("Address: ");
            Serial.println(sensorAddress);

            Serial.print("Baud rate: ");
            Serial.println(sensorBaud);

            Serial.print("Register: 0x");
            Serial.println(startRegister, HEX);

            return true;
          }
        }
      }
    }
  }

  return false;
}

void setup() {
  Serial.begin(115200);

  pinMode(RS485_DE_RE, OUTPUT);
  digitalWrite(RS485_DE_RE, LOW);

  startRS485(4800);

  Serial.println();
  Serial.println("ESP32 Soil NPK Sensor");
  Serial.println("Serial Monitor: 115200 baud");
  Serial.println("Searching for sensor...");
}

void loop() {
  if (!sensorFound) {
    sensorFound = findSensor();

    if (!sensorFound) {
      Serial.println("Sensor not found.");
      Serial.println("Check power, A/B wires, address, and baud rate.");
      delay(3000);
      return;
    }
  }

  uint16_t nitrogen;
  uint16_t phosphorus;
  uint16_t potassium;

  bool success = readNPK(
      sensorAddress,
      sensorBaud,
      startRegister,
      nitrogen,
      phosphorus,
      potassium
  );

  if (success) {
    Serial.println();
    Serial.println("----- SOIL NPK RESULT -----");

    Serial.print("Nitrogen (N): ");
    Serial.print(nitrogen);
    Serial.println(" mg/kg");

    Serial.print("Phosphorus (P): ");
    Serial.print(phosphorus);
    Serial.println(" mg/kg");

    Serial.print("Potassium (K): ");
    Serial.print(potassium);
    Serial.println(" mg/kg");

    Serial.println("---------------------------");
  } else {
    Serial.println("Reading failed. Checking sensor again...");
    sensorFound = false;
  }

  delay(3000);
}