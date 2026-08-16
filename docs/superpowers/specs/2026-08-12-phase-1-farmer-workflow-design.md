# Phase 1 Farmer Workflow Design

## Goal

Make Chaona useful for a real Thai farmer while remaining easy to demonstrate in a competition: the farmer can see what needs attention today, organize a farm into plots, collect structured handheld soil samples, and understand recommendations with visible research sources.

## Scope

Phase 1 covers one complete, testable workflow:

1. Farmer opens Today dashboard.
2. Farmer selects or creates a farm.
3. Farmer divides the farm into named plots.
4. App generates practical soil sampling points for a selected plot.
5. Farmer records handheld NPK/pH/moisture readings at each point, including optional GPS, photo, and note.
6. App summarizes plot soil condition and displays risks/recommendations.
7. Farmer can open the calculation and source behind each recommendation.
8. Competition demo mode can switch between healthy, drought/low-nitrogen, and wet/disease-risk scenarios.

Rice is the first verified crop dataset. Crop rules use an extensible interface so later datasets can add vegetables, cassava, sugarcane, and fruit without rewriting the workflow.

Out of scope for this slice: automatic irrigation hardware control, disease image diagnosis, live weather provider integration, production Supabase persistence, market forecasting, and fully automated fertilizer prescriptions. These remain later phases because they need provider credentials, calibration, or agronomist-reviewed data.

## Product Structure

Use four primary destinations:

- **Today**: current farm status, risk cards, next actions, and AI explanation entry point.
- **My Farm**: farms, plot boundaries, plot details, crops, and sampling workflow.
- **Monitor**: soil readings, sensor status, sample history, and soil-health summary.
- **Chaona AI**: chat that explains app-generated results in Thai and links back to evidence.

Market and fertilizer details open from relevant farm/plot context instead of occupying primary navigation. This reduces navigation load for farmers while keeping competition features discoverable.

## User Flow

### Today

Today uses a farmer-first question: “What should I do today?” The first viewport shows:

- selected farm and plot context;
- urgent risks: flood, drought, heat, heavy rain, pest/disease, soil nutrient;
- a short action list;
- latest soil reading timestamp and freshness;
- source-backed recommendation cards;
- an explicit demo indicator when data is simulated.

No risk card claims certainty when required input is missing. Missing weather, crop stage, or soil data produces “ข้อมูลยังไม่พอ” with the next data-collection action.

### Farm and plot setup

Farm setup keeps the existing map screen and adds a clear plot workflow:

- create farm with name, location, area, and crop;
- draw or edit farm boundary;
- divide boundary into plots using a simple equal split or manually named plot records;
- open each plot to see area, crop, sampling status, and latest recommendation.

Each plot must have stable identity, area, crop, and optional boundary geometry. Plot area is calculated from geometry when available; manual area remains available for demo/offline setup.

### Soil survey

The survey starts from a selected plot, not from a generic sensor screen. App proposes 5 sampling points for small plots using a zigzag pattern, with a grid option for larger plots. Point generation is deterministic from plot boundary and point count so the same plot can be revisited.

Each point record contains:

- point number and status: pending, sampled, skipped;
- latitude/longitude when permission and device location are available;
- sampled-at time;
- N, P, K values and units;
- pH, moisture, and temperature when available;
- optional photo and note;
- source: handheld, fixed sensor, or demo.

UI shows a short field checklist: avoid boundary edges, fertilizer piles, roads, water channels, and visibly abnormal spots unless intentionally recording an anomaly. The farmer can skip a point with a reason.

Plot summary aggregates valid readings by median per metric, shows sample count and freshness, and labels confidence as high/medium/low based on coverage and recency. It does not silently average missing values.

### Recommendations

Every recommendation is a structured result, not free-form AI text:

- title and action;
- severity: info, watch, urgent;
- value and unit;
- calculation inputs and formula summary;
- crop, growth-stage, and region applicability;
- confidence and last-updated timestamp;
- source title, publisher, URL, and citation note.

Initial rule examples:

- watering estimate uses `ETc = ETo x Kc`, then adjusts for effective rainfall and available soil moisture when those inputs exist;
- planting quantity uses `plant count = area / (row spacing x plant spacing)`, then adjusts for expected survival rate;
- rice spacing dataset displays the verified reference range rather than pretending one number fits every method;
- drought/flood cards use explicit thresholds and input freshness, never Gemini judgment alone.

The UI clearly separates “คำแนะนำจากกฎเกษตร” from “คำอธิบายโดย AI”. Gemini may translate, summarize, compare options, and answer follow-up questions using supplied structured facts. Gemini must not invent numeric thresholds, sources, or measurements.

## Architecture

Keep feature boundaries aligned with the existing Flutter/Riverpod structure:

- `features/farm_management`: farm, plot, boundary, and plot selection state;
- `features/soil_survey`: sampling-point generation, sample entry, aggregation, and survey UI;
- `features/recommendations`: source records, crop rules, risk evaluation, and calculators;
- `features/dashboard`: Today cards composed from recommendation outputs;
- existing `features/ai_chat`: explanation layer consuming structured recommendation context;
- existing demo fixtures: deterministic scenarios implementing the same interfaces as real data.

Pure domain calculations must remain dependency-free and unit-testable. UI reads providers and renders states: loading, empty, offline/demo, ready, and error. Persistence adapters can later implement Supabase without changing domain calculators or survey screens.

## Error Handling and Trust

- Location denied: keep survey usable; mark location unavailable and allow manual point confirmation.
- Invalid reading: show field-level validation and preserve other entered values.
- Missing input: show what is missing and lower confidence; never output a precise-looking number from defaults without labeling the assumption.
- Stale sensor data: show timestamp and stale badge.
- Offline/demo: allow local session data and visibly label simulated values.
- Source unavailable: retain cached source metadata and show source publisher/title; do not fabricate a URL.
- AI unavailable or rate-limited: structured recommendations remain usable and chat shows retry/offline state.

## Visual Direction

Use calm agricultural utility design: high-contrast Thai text, large tap targets, compact information hierarchy, restrained green plus neutral/alert colors, and map-first plot interactions. Avoid dashboard decoration that competes with action cards. Risk severity uses consistent icon, label, and color, never color alone.

## Testing

Before implementation is considered complete for this slice:

- unit tests cover sampling-point generation, boundary-safe point behavior, sample validation, median aggregation, confidence scoring, watering inputs, planting quantity, and risk threshold states;
- widget tests cover Today empty state, demo state, plot selection, adding a sample, and source expansion;
- existing tests and `flutter analyze` pass;
- demo scenarios render without network access;
- no API key is committed in source; Gemini and Supabase configuration come from runtime configuration.

## Trusted Source Seed

Initial source metadata is curated from authoritative agricultural references and shown in-app:

- FAO, *Crop Evapotranspiration: Guidelines for Computing Crop Water Requirements*, Irrigation and Drainage Paper 56: `https://www.fao.org/4/f2430e/f2430e.pdf`;
- FAO, *Crop water needs*: `https://www.fao.org/4/s2022e/s2022e02.htm`;
- Rice Knowledge Bank, Rice Department, Thailand, rice transplanting guidance: `https://rkb.ricethailand.go.th/web/content_page.php?code=A-1GT2GJ7SD8`.

Source records include publisher, title, URL, applicable topic, and review date. Numeric recommendations remain marked as examples until crop, soil, weather, and local practice inputs are available.

