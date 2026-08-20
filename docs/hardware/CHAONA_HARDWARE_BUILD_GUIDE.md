# Chaona Hardware Build Guide

This guide covers the two devices in the current project:

1. A solar-powered stationary monitoring station.
2. A battery-powered handheld soil survey device.

## Current parts inventory and missing confirmations

| Device | You have | Status |
|---|---|---|
| Handheld | ESP32 NodeMCU, ESP32 base, 3-pin switch, AF333 soil NPK sensor, MAX485, 3-pin RS485 NPK probe, 2-cell holder, two 3.7 V cells | Usable after confirming both sensor register maps and adding a proper 2S BMS/charger |
| Stationary | L-CT910 enclosure, 20 W solar panel, 12 V/24 V PWM 30 A controller, 12 V/9 Ah sealed battery, ESP32/base, AF333 soil NPK sensor, rain sensor, 3-pin RS485 NPK probe | Needs a MAX485 or MAX3485 module for each RS485 sensor; the rain sensor type must be confirmed |

The stationary list is missing an RS485 transceiver. The soil probe cannot be
connected directly to ESP32 UART pins; add one MAX3485 or MAX485 module.

The power converter is still unnamed in the new list. Do not confuse it with
the AF333 sensor. Before connecting the converter, read its label/datasheet and
confirm `VIN range`, `VOUT range`, and maximum current. Set and measure its
output with no ESP32 attached: 5.0 V is the target for ESP32 VIN/5V and the
MAX485 module. If the converter is not rated for the source voltage, replace it
with a known buck converter.

If the AF333 sensor and the separate 3-pin NPK probe are both installed on one
station, they cannot share one UART without a bus design: each must have a
unique Modbus address, or use separate RS485 interfaces. Do not join two
unknown sensors with the same default address `0x01`.

## 0. Critical compatibility finding

### What the photographs confirm

The photographed probe is labelled `SOIL NPK STORAGE`, `POWER: 5-30V`, and
`OUTPUT: RS485`. It is therefore an NPK RS485 probe, not a 7-in-1 probe by
default. Do not show moisture, temperature, EC, or pH in the app unless the
seller confirms that this exact unit supports those measurements.

Its connector, label, and cable colours match the common 5-30 V RS485 NPK
probe profile documented by DFRobot: N, P, and K only, with values reported in
mg/kg (reference data, not a laboratory result). That profile uses Modbus RTU
address `0x01`, `9600 8N1`, and N/P/K registers `0x001E`, `0x001F`, and
`0x0020`. Because the sensor body does not show a confirmed model number, use
these as the first test profile and confirm them with the AF333 seller manual.

The cable visibly has four conductors (red/brown, black, yellow, and blue),
but wire colour is not a standard. Treat the following as a wiring hypothesis
only and verify it against the seller's pinout before applying power:

| Likely wire | Function to verify |
|---|---|
| red or brown | sensor V+ (5-30 V) |
| black | sensor GND |
| yellow | RS485 A/D+ |
| blue | RS485 B/D- |

If the sensor powers but gives no valid Modbus response, power it off before
swapping A and B. The UNO diagram supplied in the project is a reference for
the RS485 concept; it is not an ESP32 wiring diagram and its pin numbers must
not be copied.

The photographed ESP32 base board is only a breakout/power board. It does not
make 12 V safe for the ESP32. Feed its `VIN/5V` pin with a measured regulated
5.0 V only. The photographed adjustable buck converter must be set with a
multimeter before it is connected to the ESP32.

The project currently names the probe `SN-3002-TR-ECNPKPH-N01`. The vendor family
manual distinguishes these variants:

- `ECNPKPH`: EC + NPK + pH.
- `ECTHNPKPH`: EC + temperature + moisture + NPK + pH.

The current Arduino sketch reads seven consecutive registers as moisture,
temperature, EC, pH, N, P, K. That mapping is valid only when the exact probe
manual confirms the `ECTHNPKPH` register layout. Do **not** treat the first two
registers of an `ECNPKPH` probe as moisture and temperature until the seller's
manual confirms it.

The NPK registers in the vendor manual are temporary/read-write values. They are
not automatically laboratory measurements. The app must label them as sensor
values or configured values, and fertilizer decisions should be confirmed by a
laboratory soil test.

## 1. Recommended electrical architecture

### Stationary unit

```text
20 W solar panel
  PV+ / PV- 
       |
       v
12/24 V PWM solar controller
  PV terminals: panel only
  BAT terminals: 12 V battery
  LOAD terminals: protected DC load
       |
       +---- 12 V / 9 Ah sealed battery
       |
       +---- 1 A DC fuse ---- master switch ---- power distribution
                                             |
                                             +-- soil probe V+ (4.5-30 V)
                                             +-- DC-DC buck 12 V -> 5 V
                                                    |
                                                    +-- ESP32 VIN/5V
                                                    +-- MAX485 VCC
                                                    +-- optional LCD VCC
```

Use the controller's `BAT` terminals for the battery and `LOAD` terminals for
the switched load. Follow the controller's printed polarity. Do not connect a
panel or battery to a terminal marked `LOAD`.

Recommended order:

1. Connect the battery to the controller first.
2. Connect the solar panel.
3. Connect the fused load and switch.

Keep the sensor on the fused battery/load rail only if its measured supply is
within 4.5-30 V. A regulated 12 V sensor branch is preferred. The ESP32 must
receive 5 V through `VIN/5V` or regulated 3.3 V through `3V3`, never 12 V.

### Handheld unit

Use the two cells as a **2S protected pack only if both cells are matched**:

```text
cell 1 + ---- cell 2 -       2S pack: 7.4 V nominal, 8.4 V full
       |                         |
       +---- 2S BMS ------------+
                         |
                    2S charger 8.4 V
                         |
                    2S power switch
                         |
                 +-------+--------+
                 |                |
          soil probe V+     buck regulator 7.4/8.4 V -> 5 V
                                     |
                              ESP32 VIN/5V
                              MAX485 VCC
```

Do not put two loose 3.7 V cells in a holder and connect them to a charger
without a 2S BMS and an 8.4 V CC/CV charger. Do not connect a bare Li-ion cell
directly to the soil sensor: 3.7 V is below the probe's stated 4.5 V minimum.
If the holder is wired in parallel, voltage remains about 3.7 V and a regulated
5 V boost converter is required for the probe. For safety and simplicity, use a
certified protected 2S pack instead of loose cells.

## 2. ESP32 and RS485 wiring

The preferred transceiver is a 3.3 V `MAX3485` module. If using the common
`MAX485` module, power it at 5 V and protect its receiver output with the
divider below because ESP32 GPIO input tolerance is about 3.6 V.

```text
ESP32 GPIO17 (TX2) ---------------- MAX485 DI
ESP32 GPIO16 (RX2) <--------------- divider <--- MAX485 RO
ESP32 GPIO4 ----------------------- MAX485 DE and /RE tied together
ESP32 GND ------------------------- MAX485 GND
regulated 5 V --------------------- MAX485 VCC

MAX485 A -------------------------- probe RS485-A (photo: likely yellow)
MAX485 B -------------------------- probe RS485-B (photo: likely blue)
fused 5-12 V ---------------------- probe V+ (photo: likely red/brown)
common GND ------------------------ probe GND (photo: likely black)
```

For the **stationary** unit, add a MAX485 or, preferably, a 3.3 V MAX3485.
The large-unit parts list contains the probe but no RS485 transceiver. Without
that module the stationary ESP32 cannot read the probe.

For the **handheld** unit, a 2-cell holder must be wired as a protected 2S
pack only with a 2S BMS and an 8.4 V CC/CV charger. If the holder is parallel,
the output is only about 3.7 V and is below the probe's 5 V minimum; use a
5 V boost converter instead. Never charge loose cells directly from the solar
controller.

### MAX485 receiver divider

```text
MAX485 RO ---- 2.2 kOhm ----+---- ESP32 GPIO16
                            |
                         3.3 kOhm
                            |
                           GND
```

This produces about 3.0 V from a 5 V high signal. A MAX3485 avoids this divider
and is the preferred replacement.

### LCD, if fitted

```text
LCD SDA -> ESP32 GPIO21
LCD SCL -> ESP32 GPIO22
LCD GND -> common GND
LCD VCC -> 3.3 V unless the backpack has confirmed 3.3 V-safe pull-ups
```

Many 16x2 I2C backpacks pull SDA/SCL to their supply voltage. If powered at
5 V, add a bidirectional I2C level shifter. ESP32 GPIO pins are not 5 V tolerant.

## 3. Stationary rain sensor

The phrase "rain sensor" is ambiguous:

- A resistive rain-board gives wet/dry or an analog wetness value. It cannot
  produce trustworthy millimetres of rain.
- A tipping-bucket gauge gives rainfall amount and rate in mm and mm/hour and is
  the correct choice for agricultural rainfall history.
- An optical sensor may report rain events but must be calibrated before using
  it as a rain gauge.

For the current app, a simple rain board must be stored as `rain_detected`, not
as `rain_mm`. Use a tipping bucket for flood/drought calculations.

Example digital input for a tipping bucket:

```text
tipping bucket VCC -> 3.3 V or its specified supply
tipping bucket GND -> ESP32 GND
tipping bucket pulse -> ESP32 GPIO27 with pull-up/input conditioning
```

The exact GPIO and pull-up depend on the purchased module. Add debounce and
count pulses with an interrupt. One pulse must be converted to millimetres
using the gauge's calibration constant.

## 4. Pin table

| ESP32 pin | Function | Connect to | Notes |
|---|---|---|---|
| GPIO16 | UART2 RX | MAX485 RO through divider, or MAX3485 RO | Never feed 5 V directly |
| GPIO17 | UART2 TX | MAX485 DI, or MAX3485 DI | 3.3 V UART output is accepted by MAX485 |
| GPIO4 | RS485 direction | MAX485 DE + /RE | HIGH transmit, LOW receive |
| GPIO21 | I2C SDA | LCD SDA | Use level shifting if LCD pull-up is 5 V |
| GPIO22 | I2C SCL | LCD SCL | Use level shifting if LCD pull-up is 5 V |
| GPIO27 | rain pulse | tipping-bucket output | Only if the purchased gauge supports it |
| VIN/5V | board supply | regulated 5 V buck output | Do not connect 12 V |
| 3V3 | regulated output | 3.3 V-only peripherals | Do not power the soil probe here |
| GND | reference | all low-voltage grounds | Common ground is required |

## 5. Protection and enclosure

- Put a 1 A inline fuse close to the 12 V battery positive terminal for this
  prototype. Select the final fuse after measuring startup/current draw.
- Add reverse-polarity protection or a correctly rated inline diode/MOSFET.
- Add a 100-470 uF capacitor across the 5 V buck output near the ESP32 and a
  0.1 uF ceramic capacitor near each digital module.
- Use cable glands for every cable entering the L-CT910 enclosure.
- Put the antenna side of the ESP32 away from metal and the battery/controller.
- Keep the enclosure shaded, leave a small condensation-control vent or use a
  proper breathable membrane, and do not place the controller directly below a
  gland where water can drip onto it.
- Do not bury the ESP32 enclosure. Only the probe and outdoor-rated cables go
  into soil.

## 6. Modbus bring-up

For the NPK-only profile matching the photograph, start with `9600 baud, 8N1`,
slave address `0x01`, function `0x03`, and Modbus CRC16. Some similar probes
use `4800 baud` and different register addresses, so verify the exact AF333
manual if the first test returns no response.

Test in this order:

1. Power only the controller and measure the battery/load voltage.
2. Set the buck output to 5.0 V with a multimeter before connecting ESP32.
3. Power the probe from the fused 5-12 V branch and verify polarity.
4. Connect A-to-A and B-to-B. If there is no valid frame, try swapping A/B once
   with power removed; vendors sometimes label polarity differently.
5. Test the probe with a USB-RS485 adapter and the vendor configuration tool.
6. Confirm address and baud rate. For the common NPK-only profile, read three
   registers starting at `0x001E`; do not read the seven-register 7-in-1 block.
7. Only then connect the ESP32 UART.
8. Confirm the response address, function code, byte count, and CRC before
   decoding N/P/K values.

You have two identical probes, so use one complete RS485 interface per device:

```text
Handheld probe 1 -> MAX485/MAX3485 -> Handheld ESP32 -> BLE -> phone
Stationary probe 2 -> MAX485/MAX3485 -> Stationary ESP32 -> Wi-Fi/MQTT -> app
```

Do not connect both probes to the same MAX485 unless you deliberately configure
unique Modbus addresses and design a proper RS485 bus. The simplest reliable
design is one probe and one transceiver per ESP32.

The application must not silently decode an unverified register map. Record the
exact probe variant, address, baud, register map, and calibration date in the
device record.

## 7. App connection design

### Stationary

```text
probe -> RS485 -> ESP32 -> Wi-Fi -> authenticated MQTT/TLS -> Flutter monitor
                                                    |
                                                    +-> soil_readings
```

Use a unique topic such as `chaona/{farmId}/{deviceId}/soil` after the broker
has authentication. The current shared topic is prototype-only.

### Handheld

Use BLE for the field workflow because the farmer's phone can receive readings
without internet. The phone supplies GPS and Supabase stores the sample when
online. Wi-Fi HTTP is useful for bench testing but is less convenient in a
field. MQTT is better for stationary devices, not handheld capture.

```text
probe -> RS485 -> handheld ESP32 -> BLE -> Flutter phone GPS -> Supabase
```

Every saved sample should include `farm_id`, optional `plot_id`, `survey_id`,
`sampling_point_id`, `device_id`, source, timestamp, GPS, raw values, and a
`modbus_ok`/quality flag.

## 8. Power estimate

Assumptions: ESP32 averages 0.4-1.0 W with Wi-Fi duty cycling, probe up to
about 0.5 W, and converter losses included.

- Stationary average: roughly 1-2 W depending on sampling interval and Wi-Fi.
- Daily use: roughly 24-48 Wh/day.
- 12 V 9 Ah nominal energy: about 108 Wh.
- Practical usable energy after reserve/aging: about 55-75 Wh.
- No-sun autonomy: roughly 1-3 days at the above load.
- A 20 W panel can be reasonable in sunny conditions, but shade, rain, battery
  age, and continuous Wi-Fi can make it insufficient.

Reduce risk by reading every 1-5 minutes, publishing only changed/summary data,
and using deep sleep if the product requirements allow it.

## 9. What is safe to upload now

The current firmware is a prototype for the `ECTHNPKPH`-style seven-register
layout and shared MQTT topic. Before uploading it to the exact `ECNPKPH` probe:

1. Obtain the seller's exact register table or test the probe with USB-RS485.
2. Confirm which registers are EC, pH, N, P, K and their scaling.
3. Change the firmware decoder and app field availability together.
4. Mark unavailable moisture/temperature as null, not zero.
5. Mark NPK as temporary/configured values unless independently calibrated.

Do not connect the battery to the ESP32 before measuring the buck output, and do
not leave the solar controller and lithium cells unattended while charging.
