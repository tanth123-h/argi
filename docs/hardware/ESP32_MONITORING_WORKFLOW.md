# ESP32 monitoring workflow

## Handheld mode

1. Create a farm and add a plot in **My Farm**.
2. Open **Monitor** and select **เครื่องพกพา**.
3. Select the farm and plot.
4. Place the ESP32 + MAX485 probe at the sampling point.
5. Wait until a current ESP32 reading appears.
6. Press **บันทึกค่าจุดนี้พร้อม GPS**.

The app saves the farm, plot, device ID, optional GPS, values, and timestamp to
`soil_readings` with `source = handheld`.

The current handheld firmware uploads to an HTTP endpoint when `API_URL` is set.
The Flutter save button is the app-side capture path; the next hardware slice can
replace it with a direct ESP32 local HTTP connection.

## Stationary mode

1. Install the ESP32 + MAX485 + sensor at a fixed point.
2. Publish JSON to `farm/esp32/sensors`.
3. Open **Monitor**, select **สถานีประจำแปลง**, and choose the farm/plot.

When a valid MQTT message arrives, the app saves it automatically with
`source = fixed_sensor`.

Example payload:

```json
{
  "device_id": "stationary-01",
  "moisture": 44.2,
  "temperature": 29.6,
  "humidity": 71.0,
  "ec": 322,
  "ph": 6.4,
  "nitrogen": 42,
  "phosphorus": 28,
  "potassium": 55,
  "modbus_ok": true,
  "rssi": -61
}
```

The public MQTT broker is suitable for a prototype only. Use authentication or a
private broker before a public release, and avoid sending sensitive farm data in
an unauthenticated topic.

The handheld firmware also publishes to `farm/esp32/sensors` when Wi-Fi is
available, so the Flutter app can receive the current ESP32 reading. Install the
Arduino `PubSubClient` library before compiling the firmware. HTTP upload remains
optional when `API_URL` is configured.
