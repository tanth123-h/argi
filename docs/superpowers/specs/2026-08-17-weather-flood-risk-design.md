# Weather and Farm Flood Risk Design

## Goal

Give each mapped farm a current weather and flood-risk view using measured or published data, with source URLs, retrieval time, and an explicit unavailable state.

## Data Sources

- Open-Meteo forecast endpoint for coordinate-based weather forecast; no API key is required for non-commercial use.
- GISTDA Disaster Platform ArcGIS flood layer for observed flood features near the farm. The app treats an empty response as “no recorded feature returned nearby”, not proof that flooding is impossible.
- Farm drought/water-stress indicator from the latest stored soil moisture reading and the next-24-hour precipitation probability. This is a farm-level screening signal, not an official drought declaration.
- ThaiWater/HII and Department of Water Resources remain the authoritative adapters for the next server-side phase because their rainfall, runoff, water-level, and warning APIs need station/area mapping and should not be called directly from a public mobile client.

## User Experience

- Home shortcut opens `สภาพอากาศและน้ำท่วม`.
- The screen loads the first farm with a boundary center, then allows refresh.
- Show temperature, rain now, next-24-hour rain probability, and a plain-language weather advisory.
- Show flood status as `มีพื้นที่น้ำท่วมที่ตรวจพบ`, `ยังไม่พบพื้นที่น้ำท่วมในข้อมูลล่าสุด`, or `ข้อมูลน้ำท่วมไม่พร้อม`.
- Show drought status as `ดินกำลังขาดน้ำ`, `เฝ้าระวังภาวะขาดน้ำ`, or `ยังประเมินภาวะแล้งไม่ได้`, including the latest soil reading when available.
- Always show source and update time. Never claim an emergency prediction from weather alone.

## Implementation Boundary

This slice is a client-side read-only adapter. It does not create emergency alerts, promise flood prediction, or replace official warnings. A production alert system should move API calls and scheduled snapshots to a Supabase Edge Function with caching and authenticated provider credentials.
