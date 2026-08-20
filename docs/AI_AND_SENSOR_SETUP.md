# Chaona AI and ESP32 setup

## Gemini prototype

Never commit a Gemini key to this repository. The key previously pasted into chat
must be revoked and replaced in Google AI Studio.

In Android Studio, open the Flutter run configuration and add this to **Additional
run args**:

```text
--dart-define=GEMINI_API_KEY=YOUR_NEW_KEY
```

The model can be overridden without changing source code:

```text
--dart-define=GEMINI_MODEL=gemini-3.6-flash
```

The app uses `gemini-3.6-flash` by default. Override it only with a model that
appears in the model list for your API key.

The AI screen now reports missing-key, permission, quota, and network failures.
It also includes the latest ESP32 reading when one is available. It does not use
the old demo fixture as live farm data.

For a competition prototype, this runtime key approach is acceptable for local
testing. For a public release, move the Gemini call to a server or Supabase Edge
Function so the key is never shipped inside the Android application.

## Production AI

Keep Gemini secret on Supabase:

```bash
supabase secrets set GEMINI_API_KEY=YOUR_SERVER_KEY GEMINI_MODEL=gemini-3.6-flash
supabase functions deploy gemini-proxy
```

Build app without `GEMINI_API_KEY`. Authenticated AI requests then use
`supabase/functions/gemini-proxy/index.ts` automatically.

## Required database update

Run `docs/supabase/monitoring_setup.sql` again. It adds stable reading IDs,
preventing duplicate ESP32 records during offline retries.

Run `docs/supabase/farm_operations_setup.sql` for crop cycles and device
calibration. Farm Tools can then save moisture, pH, and EC calibration values.

## Sensor paths

The project has two real device paths:

1. **Handheld:** ESP32 + MAX485 + SN-3002 sensor. The farmer takes readings at
   several sampling points in a farm or plot.
2. **Stationary:** ESP32 + MAX485 + SN-3002 sensor installed at a fixed location.
   The Flutter monitor receives its normalized readings through MQTT.

The Flutter MQTT monitor now expects:

```text
farm/esp32/sensors
```

Payload fields accepted by the app include `device_id`, `moisture`,
`temperature`, `ph`, `nitrogen`, `phosphorus`, `potassium`, `modbus_ok`, and
`rssi`.

The handheld firmware currently reads the sensor and can upload JSON to an API
when `API_URL` is configured. It is not yet the same thing as the stationary MQTT
path; the next hardware step is to add the handheld sample workflow and save its
farm/plot/latitude/longitude metadata.
