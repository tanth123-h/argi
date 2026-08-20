# Farm-Centered Soil Intelligence Design

## Goal

Make the farm boundary the main working object. A farmer can draw a farm, start a soil survey, follow five automatically generated sampling points, capture real ESP32 readings with GPS and time, review the farm-level result, and receive recommendations whose numeric rules and source links are visible.

## Product Decisions

- A farm is required; plots are optional advanced organization and never block monitoring.
- The default survey contains five points inside the saved farm boundary.
- Handheld ESP32 readings are saved only when the farmer confirms a point reading.
- Stationary ESP32 readings arrive through MQTT and are persisted with throttling.
- The app stores the raw reading, device identity, GPS, timestamp, farm, optional plot, and sampling-point identity.
- Gemini explains structured facts and cites the source catalog. Gemini does not invent thresholds, fertilizer rates, crop suitability, prices, flood status, or drought status.
- Soil-sensor results are marked preliminary when the available measurements cannot establish a laboratory property such as texture, organic matter, drainage, or contamination.
- A recommendation is actionable only when it has a rule basis, a source reference, and a confidence label.

## Workflow

1. Create or edit a farm and draw its boundary on satellite imagery.
2. Open the farm and press `เริ่มตรวจดิน`.
3. Create a survey session and generate five points inside the polygon using the existing deterministic point generator.
4. Show one point at a time with coordinates, progress, and a locate/open-map action.
5. Connect the handheld ESP32 reading, capture current GPS, validate required fields, and save the reading.
6. After five points, calculate a farm summary from actual stored readings and show missing-data warnings.
7. Use the summary as context for fertilizer, crop, irrigation, flood, drought, price, and Gemini features.

## Evidence Policy

Source priority is: Thai government agencies and official APIs, FAO/IRRI or peer-reviewed research, then clearly labeled secondary sources. Each source record includes publisher, title, URL, applicability, and retrieval/review date. Numeric thresholds remain in deterministic Dart rules or verified API adapters. The UI must distinguish measured, calculated, forecast, and unavailable values.

Initial trusted source catalog:

- Thailand Department of Agriculture: https://www.doa.go.th/th/about/about-str_org/
- Department of Agriculture soil and fertilizer guidance: https://doa.go.th/share/showthread.php?tid=2446
- Office of Agricultural Economics data catalog: https://catalog.oae.go.th/
- Thai Meteorological Department: https://www.tmd.go.th/
- FAO Crop Evapotranspiration Paper 56: https://www.fao.org/4/f2430e/f2430e.pdf
- IRRI Rice Knowledge Bank: https://rkb.ricethailand.go.th/web/content_page.php?code=A-1GT2GJ7SD8

## Data Model

Keep the existing `farms`, optional `plots`, and `soil_readings` tables. Add durable `soil_surveys` and `soil_sampling_points` tables. Add `survey_id` to `soil_readings`; keep `sampling_point_id` as a human-readable stable key for compatibility.

- `soil_surveys`: farm, status, point count, started/completed timestamps.
- `soil_sampling_points`: survey, farm, sequence, latitude, longitude, status, sampled timestamp.
- `soil_readings`: survey and point foreign keys where available, source, device, measurements, GPS, raw payload, and recorded timestamp.

RLS must authorize every read/write through the owning farm. Index survey/farm/time and device/time access patterns. No service-role key is shipped in Flutter.

## Failure and Trust States

- No boundary: block survey start and explain how to draw one.
- GPS unavailable: allow a reading only when the user explicitly confirms the point location; mark GPS unavailable.
- Sensor offline or malformed payload: show the exact missing field and do not save a fake reading.
- Fewer than five valid readings: show a partial result and list what is still unknown.
- Gemini unavailable: keep deterministic recommendations and source links usable.
- API unavailable or stale: show `ไม่พร้อมใช้งาน`/stale state rather than a simulated value.

## Testing

- Unit-test point generation, boundary validation, payload normalization, stationary throttling, reading serialization, and evidence labeling.
- Widget-test the survey progress and save flow with no boundary, one point, and completed survey states.
- Run `dart format`, `flutter analyze`, and targeted `flutter test`; if the existing Flutter toolchain hangs, report that explicitly and still run static checks that complete.

