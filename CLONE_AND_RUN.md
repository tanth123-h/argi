# Clone and Run Grow a Garden

This repository is ready to run against the shared Grow a Garden Supabase
project. A new developer does not need to create a database or edit app keys.

## Run the app

```bash
git clone https://github.com/tanth123-h/argi.git
cd argi
flutter pub get
flutter run
```

Create an account in the app, then sign in. The shared database keeps each
user's farms, survey points, readings, and farm records separate with Supabase
Row Level Security (RLS).

The app uses OpenStreetMap for the active farm map, so no Google Maps API key
is needed for the normal workflow.

## Use a different Supabase project (optional)

Only use this when making an independent deployment. Create the schema and
Edge Function secrets in that project, then run:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-public-anon-key --dart-define=BACKEND_BASE_URL=https://your-project.supabase.co/functions/v1
```

Never put a Supabase `service_role` key or a Gemini API key in Flutter code.
Those keys stay in Supabase Edge Function secrets.

## ESP32 and MQTT note

The supplied ESP32 firmware currently publishes to the shared public demo
topic `farm/esp32/sensors` on `broker.emqx.io`. It is suitable for this team's
prototype and testing, but it is not private multi-user device infrastructure:
any subscriber to that topic can receive live values. Database records saved
by the app remain protected by RLS.

For a production installation, use an authenticated MQTT broker and give each
device a private topic tied to its owner before connecting other farms.

## Maintainer-only files

`SUPABASE_SETUP.md` and the `supabase/` directory are for changing the shared
backend schema. A person who only wants to run the app should not re-run that
SQL against the shared project.
