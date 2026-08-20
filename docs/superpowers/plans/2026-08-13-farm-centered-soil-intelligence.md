# Farm-Centered Soil Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect farm boundaries, five-point handheld surveys, stationary MQTT readings, persisted evidence, and source-backed recommendations into one working Flutter workflow.

**Architecture:** Keep farm and optional plot ownership in Supabase. Add persisted survey sessions and sampling points. Use deterministic domain services for point generation, measurement summaries, and evidence labels; Gemini receives only bounded structured context and source metadata.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase/Postgres with RLS, flutter_map satellite tiles, MQTT, geolocator, Gemini REST client.

## Global Constraints

- Farms are the primary object; plots are optional.
- The default survey has exactly five automatic points inside the farm boundary.
- Do not generate simulated sensor readings or unsupported numeric advice.
- Store farm, survey, point, device, GPS, timestamp, raw payload, and source metadata where applicable.
- Every recommendation must expose a trusted source link and a confidence/availability state.
- Do not ship a Supabase service-role key or Gemini key in source control.

---

### Task 1: Stabilize sensor data contracts

**Files:**
- Modify: `lib/features/soil_monitoring/domain/entities/sensor_data.dart`
- Modify: `lib/features/soil_monitoring/data/datasources/mqtt_datasource.dart`
- Modify: `lib/features/soil_monitoring/presentation/providers/soil_live_provider.dart`
- Test: `test/features/soil_monitoring/data/mqtt_payload_test.dart`

**Interfaces:**
- `MqttDataSource` accepts both app payload names (`soil`, `n`, `p`, `k`) and ESP32 firmware names (`moisture`, `nitrogen`, `phosphorus`, `potassium`, `ec`).
- `SensorData` exposes normalized `moisture`, `ec`, temperature, humidity, pH, and N-P-K.
- Stationary persistence stores at most one unchanged reading per device per 60 seconds.

- [ ] Write tests for firmware payload normalization, invalid numeric fields, and dedupe timing.
- [ ] Implement normalized parsing and `ec` propagation.
- [ ] Add injectable clock/last-write tracking for stationary persistence.
- [ ] Run the targeted tests and format the touched files.

### Task 2: Add durable survey schema and repository

**Files:**
- Modify: `docs/supabase/monitoring_setup.sql`
- Create: `lib/features/soil_survey/data/repositories/soil_survey_repository.dart`
- Create: `lib/features/soil_survey/domain/entities/soil_survey.dart`
- Create: `lib/features/soil_survey/domain/entities/persisted_sampling_point.dart`
- Test: `test/features/soil_survey/data/soil_survey_repository_test.dart`

**Interfaces:**
- `SoilSurveyRepository.createSurvey({farmId, points})` persists a survey and its five points.
- `SoilSurveyRepository.updatePointStatus({surveyId, pointId, status, sampledAt})` updates progress.
- `SoilSurveyRepository.listLatestForFarm(farmId)` returns recent surveys and points.

- [ ] Add tables, foreign keys, indexes, grants, and owner-based RLS policies.
- [ ] Add idempotent migration for existing `soil_readings` with nullable `survey_id`.
- [ ] Implement row mappers and repository methods.
- [ ] Add serialization tests and document running the SQL in `SUPABASE_SETUP.md`.

### Task 3: Build the farm survey workflow

**Files:**
- Modify: `lib/features/soil_survey/presentation/providers/soil_survey_provider.dart`
- Create: `lib/features/soil_survey/presentation/screens/farm_soil_survey_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/farm_management/presentation/screens/farm_management_screen.dart`
- Test: `test/features/soil_survey/presentation/farm_soil_survey_screen_test.dart`

**Interfaces:**
- Farm card action opens `FarmSoilSurveyScreen(farm: farm)`.
- The screen generates five points from `Farm.boundary`, persists them, shows one active point, and records completion.
- `SoilLiveNotifier.saveHandheld` accepts survey and sampling-point IDs plus optional GPS.

- [ ] Write widget tests for missing boundary, five-point progress, and no-live-reading validation.
- [ ] Add a farm-level survey state with five points and current index.
- [ ] Add location capture and point save action wired to the live sensor state.
- [ ] Show measured/calculated/unavailable labels and partial-survey warnings.
- [ ] Open survey from the farm card without requiring a plot.

### Task 4: Connect readings to farm context

**Files:**
- Modify: `lib/features/soil_monitoring/domain/entities/soil_reading_record.dart`
- Modify: `lib/features/soil_monitoring/data/repositories/soil_reading_repository.dart`
- Modify: `lib/features/soil_monitoring/presentation/providers/soil_live_provider.dart`
- Modify: `lib/features/soil_monitoring/presentation/screens/soil_monitoring_screen.dart`
- Test: `test/features/soil_monitoring/domain/soil_reading_record_test.dart`

**Interfaces:**
- Handheld save writes `source=handheld`, farm, survey, point, device, GPS, timestamp, and raw normalized values.
- Stationary mode writes `source=fixed_sensor`, selected farm, optional plot, device, and timestamp.

- [ ] Extend serialization with survey/point IDs and EC.
- [ ] Fix nullable plot dropdown typing and allow farm-only monitoring.
- [ ] Add explicit device/source status and last saved time.
- [ ] Verify no path writes readings without a selected farm.

### Task 5: Make recommendations and Gemini evidence-aware

**Files:**
- Modify: `lib/features/ai_chat/domain/ai_context_builder.dart`
- Modify: `lib/features/ai_chat/data/services/gemini_service.dart`
- Modify: `lib/features/ai_chat/presentation/screens/chat_screen.dart`
- Modify: `lib/features/recommendations/data/source_catalog.dart`
- Create: `lib/features/soil_survey/domain/services/farm_soil_summary.dart`
- Test: `test/features/soil_survey/domain/services/farm_soil_summary_test.dart`

**Interfaces:**
- `FarmSoilSummary.fromReadings` computes coverage, averages, min/max, missing fields, and trust flags.
- `AiContextBuilder` includes the summary, farm crop/area, data-state labels, and source catalog entries.

- [ ] Add deterministic summary tests including missing and partial readings.
- [ ] Ensure recommendation cards expose source and confidence.
- [ ] Remove any wording that presents simulated/default values as measurements.
- [ ] Update Gemini model fallback to a currently supported configurable model and keep API failures actionable.

### Task 6: End-to-end bug pass and verification

**Files:**
- Modify: any touched files required by analyzer/test output.
- Modify: `docs/hardware/ESP32_MONITORING_WORKFLOW.md`
- Modify: `docs/AI_AND_SENSOR_SETUP.md`

- [ ] Run `dart format` on changed Dart files.
- [ ] Run `flutter analyze`.
- [ ] Run targeted and full `flutter test` with bounded timeouts.
- [ ] Run `git diff --check` and inspect all changed files for demo data, unsafe credentials, malformed SQL, and missing source labels.
- [ ] Report exact remaining blockers, especially toolchain or Supabase-console steps that cannot be verified locally.

