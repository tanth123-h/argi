# ESP32 Handheld Soil Sensor Guide

> Read [CHAONA_HARDWARE_BUILD_GUIDE.md](CHAONA_HARDWARE_BUILD_GUIDE.md) first.
> It contains the current stationary and handheld power diagrams, protection
> requirements, and the important `ECNPKPH` versus `ECTHNPKPH` warning.

## Hardware

- ESP32 NodeMCU ESP-WROOM-32 with CH340 USB-C
- SN-3002-TR-ECNPKPH-N01 RS485 multi-parameter soil sensor
- MAX485 RS485-to-TTL module
- Battery holder and a regulated 5V supply/boost converter

## Important power decision

The SN-3002 sensor accepts DC 4.5-30V. A single 3.7V Li-ion cell is below the sensor minimum. Use either:

- 2-cell battery pack with a suitable regulator, or
- 1-cell battery plus 5V boost converter rated for the sensor current.

Do not power sensor from ESP32 3.3V. Tie sensor ground, MAX485 ground, and ESP32 ground together.

## Wiring

```text
                 regulated 5V
                    +--------------------> SN-3002 brown: V+
                    +--------------------> MAX485 VCC

Battery GND --------+--------------------> SN-3002 black: GND
                    +--------------------> MAX485 GND
                    +--------------------> ESP32 GND

SN-3002 yellow A -----------------------> MAX485 A
SN-3002 blue B -------------------------> MAX485 B

MAX485 DI <------------------------------ ESP32 GPIO17 (TX2)
MAX485 RO -- 2.2k --+------------------> ESP32 GPIO16 (RX2)
                    |
                   3.3k
                    |
                   GND
MAX485 DE + /RE ----+------------------> ESP32 GPIO4

```

The common MAX485 board is normally a 5V part. Its RO output can be 5V, so use the divider shown above before ESP32 RX. A 3.3V RS485 transceiver such as MAX3485 is electrically cleaner if you can change the module.

## Sensor defaults

From the SN-3002 manual:

- Protocol: Modbus RTU over RS485
- Default address: `0x01`
- Default serial: `4800 baud, 8 data bits, no parity, 1 stop bit`
- Configurable baud rates: `2400`, `4800`, `9600`
- The seven-register sequence moisture x10, temperature x10, EC, pH x10, N, P,
  K applies only when the exact probe is the temperature/moisture variant and
  its manual confirms this map. Do not use it automatically for
  `ECNPKPH-N01`.
- Sensor wires: brown V+, black GND, yellow RS485-A, blue RS485-B

NPK values are described by the manual as temporary/read-write values, so confirm your exact unit's calibration and register behavior before treating them as laboratory-grade live measurements.

## Field measurement

Insert all probes into soil. Avoid stones and hard impacts. For quick readings, soil moisture above about 20% gives more meaningful EC behavior; after watering/rain, wait for water to infiltrate. Shade the black sensor body in strong sun and allow the sensor to stabilize before recording.

## App connection

Firmware sends JSON over Wi-Fi to an HTTP endpoint:

```json
{
  "device_id": "handheld-01",
  "sample_id": "generated-on-device",
  "moisture": 32.4,
  "temperature": 28.1,
  "ec": 820,
  "ph": 6.7,
  "nitrogen": 42,
  "phosphorus": 28,
  "potassium": 51,
  "measured_at": "2026-08-12T12:00:00Z"
}
```

For first bring-up, leave `API_URL` empty and verify the NPK values in Serial Monitor first. Then point it at a small HTTPS API or Supabase Edge Function that validates `device_id`, stores the sample, and exposes it to Flutter. Do not put a Supabase service-role key in ESP32 firmware.

## Bring-up order

1. Test ESP32 boot and Serial Monitor only.
2. Test MAX485 direction and sensor power with a multimeter.
3. Read one Modbus frame in Serial Monitor.
4. Confirm values against the sensor vendor software or USB-RS485 adapter.
5. Add Wi-Fi upload.
6. Add the Flutter live sample screen.
