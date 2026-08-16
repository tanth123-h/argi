# Phase 1 Farmer Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a farmer-first Today dashboard and complete demo/offline soil-survey workflow with plot sampling, trusted recommendations, and AI explanation context.

**Architecture:** Pure calculations and crop/source rules stay dependency-free. Riverpod composes demo data and survey state. Flutter screens render Today, plot survey, and recommendation states. Supabase persistence and live weather remain future adapters.

**Tech Stack:** Flutter, Dart 3.12+, Riverpod, GoRouter, flutter_map, latlong2, flutter_test, mocktail, existing Gemini client.

## Global Constraints

- Rice is first verified crop dataset; later crops plug into same crop-rule interface.
- Gemini explains structured rule results; it does not create numeric recommendations or sources.
- Demo scenarios work offline and visibly identify simulated data.
- Missing/stale inputs lower confidence; never output unlabeled precise-looking values.
- Recommendations expose publisher, title, URL, applicability, and review date.
- No production Supabase persistence in this plan.
- No API key remains committed in Dart source; runtime configuration supplies credentials.

---

### Task 1: Soil-survey and recommendation domain models

**Files:**
- Create: `lib/features/soil_survey/domain/entities/sampling_point.dart`
- Create: `lib/features/soil_survey/domain/entities/soil_sample.dart`
- Create: `lib/features/recommendations/domain/entities/source_reference.dart`
- Create: `lib/features/recommendations/domain/entities/recommendation.dart`
- Create: `lib/features/recommendations/domain/entities/risk_level.dart`
- Modify: `lib/features/farm_management/domain/entities/plot.dart`
- Test: `test/features/soil_survey/domain/entities/soil_sample_test.dart`
- Test: `test/features/recommendations/domain/entities/recommendation_test.dart`

**Interfaces:**
- `SamplingPoint({required String id, required String plotId, required int sequence, required double latitude, required double longitude, SamplingPointStatus status = pending})`.
- `SoilSample({required String id, required String plotId, required String samplingPointId, required double nitrogen, required double phosphorus, required double potassium, double? ph, double? moisture, double? temperature, DateTime? sampledAt, SampleSource source = handheld, String? note})`.
- `SourceReference({required String title, required String publisher, required Uri url, required String topic, required DateTime reviewedAt})`.
- `Recommendation({required String id, required String title, required String action, required RiskLevel level, required String value, required String calculation, required double confidence, required SourceReference source, required DateTime createdAt})`.
- Add optional `boundary` geometry and `samplingPointCount` to `Plot` without breaking existing constructors.

- [ ] Write failing equality/entity tests.
- [ ] Run `flutter test test/features/soil_survey/domain/entities test/features/recommendations/domain/entities`; expect missing-class failures.
- [ ] Implement immutable Equatable entities and enums. Keep optional instrument readings nullable.
- [ ] Re-run focused tests; expect PASS.
- [ ] Commit with `git add ...` and `git commit -m "feat: add soil survey and recommendation entities"`.

### Task 2: Sampling points and plot summary calculations

**Files:**
- Create: `lib/features/soil_survey/domain/services/sampling_point_generator.dart`
- Create: `lib/features/soil_survey/domain/services/soil_survey_calculator.dart`
- Create: `lib/features/soil_survey/domain/entities/soil_plot_summary.dart`
- Test: `test/features/soil_survey/domain/services/sampling_point_generator_test.dart`
- Test: `test/features/soil_survey/domain/services/soil_survey_calculator_test.dart`

**Interfaces:**
- `List<SamplingPoint> generate({required String plotId, required List<LatLng> boundary, required int count, SamplingPattern pattern = zigzag})`.
- `SoilPlotSummary summarize({required String plotId, required List<SoilSample> samples, required DateTime now})`.
- `double? median(Iterable<double> values)`.
- `SampleConfidence confidence({required int expectedCount, required int validCount, required DateTime? latestSampleAt, required DateTime now})`.

- [ ] Write failing test: five requested points inside rectangular boundary, deterministic order.
- [ ] Run focused test; expect generator missing failure.
- [ ] Implement bounding-box interpolation with alternating zigzag rows; reject outside polygon and move inward toward centroid; empty for invalid boundary/count.
- [ ] Write failing test: summary uses median, ignores missing optional readings, and reports sample count.
- [ ] Implement validation, median aggregation, and confidence: high at >=80% recent coverage, medium at >=50%, otherwise low.
- [ ] Run `flutter test test/features/soil_survey/domain/services`; expect PASS.
- [ ] Commit `feat: calculate soil survey summaries`.

### Task 3: Rice rules and source catalog

**Files:**
- Create: `lib/features/recommendations/domain/rules/crop_rule.dart`
- Create: `lib/features/recommendations/domain/rules/rice_rule.dart`
- Create: `lib/features/recommendations/domain/services/recommendation_engine.dart`
- Create: `lib/features/recommendations/data/source_catalog.dart`
- Test: `test/features/recommendations/domain/services/recommendation_engine_test.dart`
- Test: `test/features/recommendations/data/source_catalog_test.dart`

**Interfaces:**
- `abstract interface class CropRule { String get cropId; List<Recommendation> evaluate(RecommendationContext context); }`.
- `RecommendationContext({required SoilPlotSummary? soil, required double plotAreaRai, required String cropId, double? etoMm, double? kc, double? effectiveRainMm, required DateTime now})`.
- `RecommendationEngine({required List<CropRule> rules}).evaluate(RecommendationContext context)`.
- `SourceCatalog.riceWaterRequirements`, `SourceCatalog.riceSpacing`, and `SourceCatalog.all`.

- [ ] Write failing tests: low moisture emits `drought-risk`; missing ETo/Kc emits `watering-input-needed`; every result has source metadata.
- [ ] Run focused tests; expect missing engine/rule failure.
- [ ] Add FAO Paper 56, FAO crop-water-needs, and Thai Rice Department source records from approved spec.
- [ ] Implement rice screening thresholds, watering formula only when inputs exist, clearly labeled assumptions otherwise, and rice spacing recommendation.
- [ ] Run `flutter test test/features/recommendations`; expect PASS.
- [ ] Commit `feat: add source-backed rice recommendations`.

### Task 4: Riverpod survey state and plot survey UI

**Files:**
- Create: `lib/features/soil_survey/presentation/providers/soil_survey_provider.dart`
- Create: `lib/features/soil_survey/presentation/screens/plot_survey_screen.dart`
- Create: `lib/features/soil_survey/presentation/widgets/sampling_progress_card.dart`
- Create: `lib/features/soil_survey/presentation/widgets/soil_sample_form.dart`
- Modify: `lib/features/farm_management/presentation/screens/farm_management_screen.dart`
- Modify: `lib/features/farm_management/presentation/screens/farm_map_screen.dart`
- Test: `test/features/soil_survey/presentation/plot_survey_screen_test.dart`

**Interfaces:**
- `soilSurveyProvider` exposes `SoilSurveyState` with selected plot, points, samples, summary, and error.
- `SoilSurveyNotifier.start(plot)`, `recordSample(SoilSample sample)`, `skipPoint(String pointId, String reason)`, `reset()`.
- `PlotSurveyScreen({required Farm farm, required Plot plot})`.

- [ ] Write failing widget test: pending point list opens form; form shows Thai N/P/K fields.
- [ ] Run test; expect missing screen/provider failure.
- [ ] Implement in-memory provider, five deterministic points, and center fallback for manual-area demo plots.
- [ ] Implement required N/P/K validation, optional pH/moisture/temperature, decimal input, source label, and skipped-point reason.
- [ ] Implement progress, map/list point state, sample count, confidence, and summary.
- [ ] Run `flutter test test/features/soil_survey/presentation/plot_survey_screen_test.dart` and `flutter analyze`; expect PASS/no new errors.
- [ ] Commit `feat: add plot soil survey workflow`.

### Task 5: Today dashboard and navigation redesign

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Create: `lib/features/dashboard/presentation/widgets/risk_card.dart`
- Create: `lib/features/dashboard/presentation/widgets/action_recommendation_card.dart`
- Test: `test/features/dashboard/presentation/dashboard_screen_test.dart`

**Interfaces:**
- Dashboard consumes demo farm/soil plus recommendation-engine output through a provider.
- `RiskCard({required String title, required String detail, required RiskLevel level, required VoidCallback onTap})`.
- `ActionRecommendationCard({required Recommendation recommendation, required VoidCallback onSourceTap})`.

- [ ] Write failing widget test: drought demo shows drought card and source action.
- [ ] Run test; expect new-card/content failure.
- [ ] Compose demo fixture soil into `SoilPlotSummary` and feed rice rules; keep real empty state explicit.
- [ ] Replace placeholder weather/AI cards with selected farm, risk cards, next actions, soil freshness, source expansion, and survey/AI links.
- [ ] Reduce primary tabs to Today, My Farm, Monitor, Chaona AI. Preserve `/market`, `/soil`, `/fertilizer`, `/ai` deep links.
- [ ] Run dashboard/widget tests and `flutter analyze`; expect PASS/no new errors.
- [ ] Commit `feat: redesign farmer today dashboard`.

### Task 6: Ground AI explanations and remove committed key

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/features/ai_chat/data/services/gemini_service.dart`
- Modify: `lib/features/ai_chat/presentation/screens/chat_screen.dart`
- Create: `lib/features/ai_chat/domain/ai_context_builder.dart`
- Test: `test/features/ai_chat/domain/ai_context_builder_test.dart`
- Modify: `README.md`

**Interfaces:**
- `AiContextBuilder.build({required Farm farm, required List<Recommendation> recommendations, SoilPlotSummary? summary})` returns bounded Thai context containing structured facts and source metadata.
- `GeminiService` accepts runtime API-key/provider config; empty key yields unavailable state.

- [ ] Write failing test: context includes source URL and instruction not to invent numbers/sources.
- [ ] Run focused test; expect missing-builder failure.
- [ ] Remove hardcoded Gemini key; read `--dart-define=GEMINI_API_KEY=...` or existing secure runtime path; never print key.
- [ ] Pass selected recommendation context into chat; show rule output separately from AI explanation; provide local fallback when key absent.
- [ ] Run `flutter test`, `flutter analyze`, and `rg -n "AIza|GEMINI_API_KEY|SUPABASE_ANON_KEY" lib`; expect tests/analyzer pass and no literal key.
- [ ] Commit `feat: ground AI explanations in trusted recommendations`.

### Task 7: Full verification and handoff

**Files:**
- Modify: `IMPLEMENTATION_SUMMARY.md`
- Modify: `QUICK_START.md`

- [ ] Run `flutter test`, `flutter analyze`, and `flutter build web --no-pub`; record exact results.
- [ ] Manually verify all three demo presets offline: risk cards, plot survey, sample entry, source expansion, and AI fallback.
- [ ] Document routes, demo behavior, runtime Gemini configuration, source catalog, limitations, and next-phase Supabase/weather work.
- [ ] Review `git diff --stat` and commit `docs: document phase 1 farmer workflow`.

