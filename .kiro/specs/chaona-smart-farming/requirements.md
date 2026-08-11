# Requirements Document

## Introduction

"ชาวนา" (Chao Na) คือแอปพลิเคชันมือถือ Flutter สำหรับเกษตรกรไทยที่ขับเคลื่อนด้วย AI ออกแบบมาเพื่อเกษตรกรที่มีความรู้ทางเทคโนโลยีระดับต่ำ แอปผสานข้อมูลเซนเซอร์ IoT (ESP32 + เซนเซอร์ NPK), AI/ML (Gemini AI) และองค์ความรู้การเกษตร เพื่อช่วยให้เกษตรกรตัดสินใจได้ดีขึ้น ครอบคลุมคุณสมบัติหลัก P0 ได้แก่ แดชบอร์ด, การจัดการแปลงนา, การตรวจสอบดิน, คำแนะนำปุ๋ย, แชทบอท AI และสมุดบันทึกฟาร์ม รวมถึงคุณสมบัติรอง P1 ได้แก่ การตรวจจับโรคพืชและแดชบอร์ดราคาตลาด

---

## Glossary

- **App**: แอปพลิเคชัน "ชาวนา" (Chao Na) บน Flutter
- **Farmer**: เกษตรกรผู้ใช้งานแอป ซึ่งอาจมีความรู้ทางเทคโนโลยีระดับต่ำ
- **Farm**: แปลงที่ดินทางการเกษตรหนึ่งแปลงที่เกษตรกรเป็นเจ้าของหรือจัดการ
- **Plot**: พื้นที่ย่อยภายในฟาร์มที่มีชื่อ ขนาด และประเภทพืชกำหนดไว้
- **Sensor_Device**: อุปกรณ์ ESP32 ที่ติดตั้งเซนเซอร์ NPK และความชื้น RS485 อยู่ในแปลง
- **Soil_Data**: ข้อมูลการวัดที่ส่งมาจาก Sensor_Device ประกอบด้วยค่า N (ไนโตรเจน), P (ฟอสฟอรัส), K (โพแทสเซียม), ความชื้น, อุณหภูมิ และ pH
- **Soil_Health_Score**: คะแนนสุขภาพดิน 0–100 คำนวณแบบ composite จากค่าย่อย moisture, N, P, K
- **AI_Assistant**: ระบบแชทบอทที่ขับเคลื่อนด้วย Gemini AI ตอบคำถามเกษตรกรรมเป็นภาษาไทย
- **Fertilizer_Recommendation**: ข้อเสนอแนะปริมาณและชนิดปุ๋ยที่คำนวณจากสภาพดินและระยะการเพาะปลูก
- **Farm_Record**: รายการบันทึกในสมุดบันทึกฟาร์ม เช่น การปลูก การใส่ปุ๋ย ค่าใช้จ่าย การเก็บเกี่ยว
- **Disease_Detection**: กระบวนการวิเคราะห์ภาพถ่ายพืชเพื่อระบุโรคและแมลงศัตรูพืช
- **Market_Price**: ราคาพืชผลในตลาดที่บันทึกพร้อมวันที่และแหล่งที่มา
- **Demo_Mode**: โหมดสาธิตที่ไม่ต้องเข้าสู่ระบบ ใช้ข้อมูลจำลอง 3 ชุด
- **Supabase**: แบ็กเอนด์สำหรับ Authentication, PostgreSQL, Realtime และ Storage
- **MQTT_Broker**: ระบบรับ-ส่งข้อความสำหรับรับข้อมูลจาก Sensor_Device
- **Backend_Function**: ฟังก์ชันฝั่งเซิร์ฟเวอร์ที่รับผิดชอบการส่งคำขอไปยัง Gemini API
- **Gemini_API**: Google Gemini 1.5/2.0 Flash API สำหรับประมวลผล AI
- **DAP**: จำนวนวันหลังการปลูก (Days After Planting) ใช้ในการตัดสินใจเกษตรกรรม
- **NPK**: ไนโตรเจน (N), ฟอสฟอรัส (P), โพแทสเซียม (K) — ธาตุอาหารหลักของพืช

---

## Requirements

### Requirement 1: User Authentication and Onboarding

**User Story:** As a Farmer, I want to register and log in to the App with a simple process, so that my farm data is saved and accessible across devices.

#### Acceptance Criteria

1. THE App SHALL provide a registration screen accepting a Thai phone number (format: 0X-XXXX-XXXX) or email address, and a password of at least 8 characters containing at least one digit.
2. WHEN a Farmer submits a phone number or email address and a password that meets the minimum requirements, and the identifier is not already registered, THE App SHALL create a new account via Supabase Auth and navigate the Farmer to the main dashboard.
3. WHEN a Farmer submits registration credentials where the identifier is already registered, THE App SHALL display a Thai error message stating the identifier is already in use; WHEN the password does not meet minimum requirements, THE App SHALL display a Thai message specifying the unmet rule.
4. WHEN a Farmer submits a registered identifier and its matching password on the login screen, THE App SHALL authenticate via Supabase Auth and navigate to the main dashboard within 3 seconds.
5. WHEN a Farmer submits a login identifier that does not exist or a password that does not match the registered identifier, THE App SHALL display a generic Thai error message that does not reveal which field is incorrect.
6. WHEN a Farmer taps "ลืมรหัสผ่าน" on the login screen, THE App SHALL initiate a password reset flow by sending a reset link or OTP to the registered email or phone number.
7. WHEN a Farmer selects Demo Mode from the login screen, THE App SHALL bypass authentication, present a preset selection screen, and load the chosen demo dataset without creating a Supabase account; a Demo Mode session SHALL NOT persist across App restarts.
8. WHILE in Demo Mode, THE App SHALL display a persistent banner indicating that no data is being saved.
9. THE App SHALL persist the authenticated session across App restarts until the Farmer explicitly logs out.
10. WHEN a Farmer logs out, THE App SHALL clear all locally cached user data and navigate to the login screen.

---

### Requirement 2: Main Dashboard

**User Story:** As a Farmer, I want to see a summary of my farm's current status at a glance, so that I can quickly understand if anything needs my attention.

#### Acceptance Criteria

1. WHEN a Farmer successfully authenticates or enters Demo Mode, THE App SHALL display the main dashboard as the first screen, using large icons (minimum 32×32dp) and concise Thai text labels of no more than 4 words per element.
2. THE App SHALL display the current Soil_Health_Score for each Plot on the dashboard as a visual gauge or color-coded indicator using three bands: green for scores 70–100, yellow for 40–69, and red for 0–39.
3. THE App SHALL display the most recent Soil_Data values (N, P, K, moisture) for each Plot whose Sensor_Device has sent data within the past 24 hours.
4. THE App SHALL display current weather information (temperature, humidity, rainfall forecast) on the dashboard, sourced from an external weather provider; WHEN weather data is unavailable, THE App SHALL display a Thai-language unavailability message in the weather card.
5. IF a Fertilizer_Recommendation for a Plot was generated within the past 7 days, THEN THE App SHALL display the most recent recommendation card for that Plot on the dashboard; IF no such recommendation exists, THE App SHALL display a prompt in Thai inviting the Farmer to generate one.
6. WHEN a Sensor_Device has not sent data within 24 hours, THE App SHALL display a connectivity warning icon and Thai label next to the corresponding Plot card on the dashboard.
7. WHEN new Soil_Data arrives via Supabase Realtime, THE App SHALL update the affected dashboard card values within 5 seconds without requiring a manual refresh; WHEN the Realtime connection is interrupted, THE App SHALL display a paused-update indicator and the timestamp of the last received reading.
8. WHEN a Farmer taps a dashboard card, THE App SHALL navigate to the corresponding detail screen.
9. THE App SHALL provide bottom navigation with five tabs: Home (หน้าหลัก), Farm (ฟาร์ม), AI, Market (ตลาด), and More (เพิ่มเติม).
10. THE App SHALL display all labels, messages, and notifications throughout the dashboard in Thai.

---

### Requirement 3: Farm Management

**User Story:** As a Farmer, I want to create and manage my farm plots, so that I can track each area of my land separately.

#### Acceptance Criteria

1. THE App SHALL allow a Farmer to create a new Farm by providing a name (1–100 characters), a location description (text or GPS-derived), and a total area in rai greater than 0.
2. THE App SHALL allow a Farmer to create one or more Plots within a Farm, each requiring a name (1–100 characters), area in rai greater than 0, and a crop type selected from a predefined list.
3. WHEN a Farmer saves a new Plot with valid inputs, THE App SHALL persist the Plot to the Supabase database and display it in the Farm list within 2 seconds.
4. THE App SHALL allow a Farmer to edit the name, area, and crop type of an existing Plot.
5. WHEN a Farmer saves edits to a Plot with valid inputs, THE App SHALL update the record in the Supabase database and reflect changes in the UI within 2 seconds.
6. WHEN a Farmer initiates Plot deletion, THE App SHALL present a Thai-language confirmation dialog before proceeding.
7. WHEN a Farmer confirms Plot deletion, THE App SHALL soft-delete the Plot record and remove it from all Farm lists immediately.
8. THE App SHALL allow a Farmer to associate a Sensor_Device with a Plot by entering the device's unique token on the Plot detail screen.
9. WHEN a Sensor_Device token is submitted, THE App SHALL validate the token against the Supabase database within 5 seconds and display a Thai-language success or failure message.
10. THE App SHALL display each Plot as a summary card showing name, crop type, area in rai, and current Soil_Health_Score.
11. IF a Farmer enters an area value of 0 or less, or greater than 10,000 rai, THEN THE App SHALL display a Thai-language validation error and prevent saving.
12. IF a Farmer attempts to save a Plot without a name or crop type, THEN THE App SHALL display a Thai-language validation error identifying the missing field and prevent saving.

---

### Requirement 4: Soil Monitoring

**User Story:** As a Farmer, I want to monitor the soil conditions of my plots in real time, so that I know when to add fertilizer or water.

#### Acceptance Criteria

1. THE App SHALL display a Soil Monitoring screen for each Plot showing current N, P, K, moisture, temperature, and pH values as visual gauges with Thai labels; WHEN no Soil_Data is available for a Plot, THE App SHALL display each gauge in a neutral state with a Thai message indicating no data has been received yet.
2. THE App SHALL calculate the Soil_Health_Score as a composite of four equally weighted subscores (moisture 25%, N 25%, P 25%, K 25%), each normalised to 0–100 relative to the optimal ranges defined in the agronomic decision matrix for the Plot's selected crop type.
3. THE App SHALL display the Soil_Health_Score with a color-coded indicator and Thai label: green (70–100 = ดี), yellow (40–69 = ปานกลาง), red (0–39 = ต้องดูแล).
4. WHEN a Farmer opens the Soil Monitoring screen, THE App SHALL display a trend chart using fl_chart with separate lines for N, P, K, and moisture for the past 7 days by default.
5. WHEN a Farmer selects a date range on the trend chart (maximum range: 90 days), THE App SHALL filter and redraw the chart within 2 seconds to show only data within that range.
6. WHEN a Soil_Data reading for moisture falls below 20%, THE App SHALL display a Thai-language warning on the monitoring screen; a duplicate warning SHALL NOT be displayed again until moisture rises above 20% and falls below it again.
7. WHEN a Soil_Data reading for any NPK value falls below the minimum threshold defined for the Plot's crop type, THE App SHALL display a Thai-language deficiency alert naming the specific nutrient; a duplicate alert for the same nutrient SHALL NOT be shown until the value recovers above the threshold and drops again.
8. WHEN new Soil_Data is received via Supabase Realtime for a Plot, THE App SHALL update the gauge values within 5 seconds.
9. THE App SHALL display the date and time of the most recent Soil_Data reading on the monitoring screen in Thai-locale format.
10. IF no Soil_Data has been received for a Plot within 24 hours, THEN THE App SHALL display a Thai-language sensor connectivity warning on the monitoring screen.
11. THE App SHALL allow a Farmer to view historical Soil_Data for up to 90 days on the trend chart.

---

### Requirement 5: Smart Fertilizer Recommendation

**User Story:** As a Farmer, I want AI-powered fertilizer recommendations based on my soil data, so that I know exactly what fertilizer to buy and how much to apply.

#### Acceptance Criteria

1. WHEN a Farmer taps "ขอคำแนะนำ" for a Plot, THE App SHALL send the Plot's most recent Soil_Data, crop type, and DAP to the Backend_Function and display a Thai-language loading indicator; IF the loading state exceeds 30 seconds, THE App SHALL display a timeout message and offer a retry.
2. THE Backend_Function SHALL request a Fertilizer_Recommendation from Gemini_API without including the Gemini API key in any response sent to the Flutter client.
3. WHEN the Backend_Function returns a Fertilizer_Recommendation, THE App SHALL display it in Thai, listing: fertilizer names (Thai names when available in the agronomic decision matrix, otherwise common name), application rate in kg per rai, and application timing relative to the current DAP stage.
4. IF the Plot's current N, P, or K value falls outside the optimal range for the current DAP stage as defined in the agronomic decision matrix, THEN THE App SHALL base the Fertilizer_Recommendation on that matrix, identifying each nutrient deviation as a reason for the recommendation.
5. WHEN the Backend_Function returns an error, THE App SHALL display a Thai-language error message specifying that the recommendation could not be generated and offer a retry button.
6. IF market price data for a recommended fertilizer product is available in the Supabase database, THEN THE App SHALL display an estimated cost per rai alongside the recommendation; otherwise, the cost field SHALL be hidden.
7. WHEN a Farmer taps the save button on a Fertilizer_Recommendation, THE App SHALL create a Farm_Record entry of type Fertilizing pre-populated with the recommendation details and display a Thai-language confirmation within 2 seconds.
8. THE App SHALL display the history of past Fertilizer_Recommendations for a Plot in descending order by generation date, showing recommendation summary and date for each entry.
9. WHEN a new Fertilizer_Recommendation is generated for a Plot, THE App SHALL update the recommendation card for that Plot on the main dashboard.
10. IF no Soil_Data exists for a Plot or the most recent reading is older than 24 hours at the time of request, THEN THE App SHALL display a Thai-language warning indicating stale or missing sensor data and require the Farmer to confirm before proceeding.

---

### Requirement 6: AI Farm Assistant (Chatbot)

**User Story:** As a Farmer, I want to ask farming questions in Thai and receive clear answers, so that I can get expert advice without needing to contact a specialist.

#### Acceptance Criteria

1. THE App SHALL provide a chat interface under the AI tab where a Farmer can type or use voice input to submit questions in Thai.
2. WHEN a Farmer submits a message, THE App SHALL send the message text and the 20 most recent turns of conversation history to the Backend_Function, which forwards the request to Gemini_API.
3. THE Backend_Function SHALL never embed the Gemini API key in the App bundle or include it in any response to the Flutter client.
4. WHEN the Backend_Function returns a response from Gemini_API, THE App SHALL display the response in Thai within the chat interface in under 15 seconds from message submission.
5. WHILE awaiting a response, THE App SHALL display a Thai typing indicator ("กำลังคิด...").
6. THE AI_Assistant SHALL respond to questions about: soil nutrition, fertilizer application, crop disease identification, planting schedules, pest management, and market timing.
7. IF a Farmer's question falls outside the topic list in criterion 6, THEN THE App SHALL display a Thai-language message advising the Farmer to consult a local agricultural extension officer.
8. THE App SHALL display conversation history in chronological order within the current session.
9. WHEN a Farmer taps "เริ่มบทสนทนาใหม่" (New Conversation), THE App SHALL display a Thai-language confirmation dialog; WHEN the Farmer confirms, THE App SHALL clear the session history and start a new conversation.
10. WHEN a Farmer activates voice input, THE App SHALL transcribe Thai speech to text and populate the message input field before sending.
11. THE App SHALL enforce a 1,000-character message limit; WHEN a message exceeds 800 characters, THE App SHALL display a character counter.
12. IF the Backend_Function does not respond within 15 seconds, THEN THE App SHALL display a Thai-language timeout error, preserve the unsent message text in the input field, and offer a retry button.
13. THE App SHALL include only the 20 most recent conversation turns when sending history to the Backend_Function to limit payload size.

---

### Requirement 7: Digital Farm Record (Ledger)

**User Story:** As a Farmer, I want to keep a digital record of my farming activities and expenses, so that I can track costs and review what I did each season.

#### Acceptance Criteria

1. THE App SHALL provide a Farm Record screen where a Farmer can create entries of four types: การปลูก (Planting) requiring crop name and area; การใส่ปุ๋ย (Fertilizing) requiring fertilizer name and amount in kg; ค่าใช้จ่าย (Expense) requiring category and amount in THB; and การเก็บเกี่ยว (Harvest) requiring quantity in kg and selling price in THB/kg.
2. WHEN a Farmer creates a new Farm_Record entry, THE App SHALL require: entry type, date, Plot name, and the type-specific fields defined in criterion 1; THE App SHALL prevent saving if any required field is empty.
3. WHEN a Farmer saves a valid Farm_Record entry, THE App SHALL persist it to the Supabase database and display it in the record list within 2 seconds.
4. THE App SHALL display Farm_Record entries in a chronological list view, grouped by Thai calendar month name, ordered newest-first within each month.
5. THE App SHALL allow a Farmer to filter Farm_Record entries by entry type, Plot, and a custom date range; filters SHALL be combinable.
6. THE App SHALL calculate and display total Expense entries (sum of THB amounts) and total Harvest income (sum of quantity × selling price) for the currently selected date range on the Farm Record screen.
7. THE App SHALL allow a Farmer to attach a single photo (JPEG or PNG, maximum 5 MB) to any Farm_Record entry, storing the image in Supabase Storage.
8. WHEN a Farmer taps a Farm_Record entry, THE App SHALL display all fields for that entry type in full and provide an Edit button.
9. WHEN a Farmer saves edits to a Farm_Record entry, THE App SHALL update the record in the Supabase database and refresh the list within 2 seconds.
10. WHEN a Farmer initiates deletion of a Farm_Record entry, THE App SHALL display a Thai-language confirmation dialog; WHEN the Farmer confirms, THE App SHALL delete the record and remove it from the list.
11. THE App SHALL allow a Farmer to export Farm_Record data for a selected date range as a PDF report in Thai, containing all entry fields and the income/expense summary from criterion 6.
12. WHEN a Fertilizer_Recommendation is saved from the recommendation screen, THE App SHALL automatically create a Farm_Record entry of type Fertilizing pre-populated with the fertilizer name, recommended rate, Plot name, and current date.

---

### Requirement 8: IoT Data Ingestion via MQTT

**User Story:** As a Farmer, I want my ESP32 soil sensors to automatically send data to the App, so that I can see real-time readings without manual entry.

#### Acceptance Criteria

1. THE Sensor_Device SHALL publish Soil_Data to the MQTT_Broker on the topic `farm/{farm_id}/soil_telemetry` at a configurable interval between 5 minutes and 60 minutes.
2. WHEN a Soil_Data message arrives on `farm/{farm_id}/soil_telemetry`, THE Backend_Function SHALL persist the payload to the Supabase `soil_data` table after passing validation.
3. WHEN a Soil_Data payload is received, THE Backend_Function SHALL verify that the fields N, P, K, moisture, and device_token are all present and non-null before persisting.
4. IF a Soil_Data payload is missing any required field, THEN THE Backend_Function SHALL reject the payload with an HTTP 400 response, log a validation error including the missing field name, and not write to the database.
5. WHEN a Soil_Data payload is received, THE Backend_Function SHALL verify the device_token against the Supabase devices table; IF the token is invalid or absent, THE Backend_Function SHALL reject the payload with an HTTP 401 response and not write to the database.
6. WHEN a valid Soil_Data record is persisted, THE Backend_Function SHALL emit a Supabase Realtime event so that the App receives the update within 5 seconds.
7. IF the Supabase Realtime emission fails after 3 attempts, THEN THE Backend_Function SHALL log the failure and not retry further, ensuring the data record is preserved in the database.
8. THE Backend_Function SHALL never include per-device tokens or the Gemini API key in any response payload returned to the Flutter client.
9. IF the MQTT_Broker is unreachable, THE Sensor_Device SHALL buffer up to 100 Soil_Data readings in local memory and retransmit them in chronological order at the configured interval once connectivity is restored.
10. THE Sensor_Device SHALL publish no more than one reading every 5 minutes to prevent broker flooding.

---

### Requirement 9: Plant Disease Detection (P1)

**User Story:** As a Farmer, I want to photograph a sick plant and get a diagnosis, so that I can treat the disease before it spreads to my whole crop.

#### Acceptance Criteria

1. THE App SHALL provide a Disease Detection screen accessible from the AI tab where a Farmer can capture a photo using the device camera or select a JPEG or PNG image (maximum 10 MB) from the gallery.
2. WHEN a Farmer submits an image, THE App SHALL compress it to a maximum of 2 MB before sending to the Backend_Function, which forwards the compressed image to the computer vision model.
3. WHEN the Backend_Function returns a classification result, THE App SHALL display in Thai: the disease or pest name, a confidence percentage rounded to the nearest whole number, and up to 5 recommended treatment steps.
4. WHEN the confidence score is below 60%, THE App SHALL display the result with a Thai-language caveat advising the Farmer to consult an agricultural extension officer.
5. WHEN a Farmer taps "บันทึกผล" (Save Result), THE App SHALL require the Farmer to select a Plot before saving the Disease Detection result as a Farm_Record entry of type Disease linked to the selected Plot.
6. THE App SHALL display the history of past Disease Detection results for a Plot on the Plot detail screen, ordered newest-first.
7. IF the Backend_Function does not respond within 20 seconds, THEN THE App SHALL display a Thai-language timeout error and offer a retry option.
8. THE App SHALL allow the Farmer to choose between the front and rear camera before capture.
9. THE App SHALL allow the Farmer to crop the captured or selected image before submission.
10. IF the submitted image cannot be processed (unrecognisable content, corrupted file, or unsupported format), THEN THE Backend_Function SHALL return an error and THE App SHALL display a Thai-language message advising the Farmer to retake the photo.
11. WHEN a disease is identified with confidence above 75%, THE App SHALL display a Thai-language prompt asking the Farmer whether to pre-seed the AI_Assistant with the identified disease; WHEN the Farmer confirms, THE App SHALL add the disease name and recommended treatment to the AI_Assistant context for the next conversation.

---

### Requirement 10: Market Price Dashboard (P1)

**User Story:** As a Farmer, I want to monitor crop prices and get advice on when to sell, so that I can maximise my income.

#### Acceptance Criteria

1. THE App SHALL display a Market Dashboard under the Market tab showing current and historical Market_Price data for each crop type registered to the Farmer's Plots.
2. THE App SHALL display a price trend chart using fl_chart showing the past 30 days of Market_Price history per registered crop type, with prices in THB/kg on the y-axis.
3. THE App SHALL refresh Market_Price data at least once every 24 hours and display the date and time of the last update in Thai-locale format.
4. WHEN new Market_Price data is available, THE App SHALL display the day-over-day price change as a percentage with one decimal place and a directional arrow (up/down) next to the current price.
5. WHEN a Farmer opens the Market Dashboard, THE App SHALL send the current 30-day Market_Price trend for the Farmer's registered crop types to the Backend_Function and display the returned AI-generated sell-timing suggestion in Thai; IF the Backend_Function returns an error, THE App SHALL display a Thai-language error message in the suggestion card and not hide the price chart.
6. WHEN a Market_Price crosses a Farmer-defined alert threshold (above or below), THE App SHALL send a push notification in Thai stating the crop type, current price in THB/kg, and the breached threshold; notifications for the same crop SHALL be suppressed for 24 hours after each trigger.
7. THE App SHALL allow a Farmer to set a numeric price alert threshold in THB/kg for each registered crop type and specify whether the alert fires when price rises above or falls below the threshold.
8. WHEN a Farmer taps the sell-timing suggestion card, THE App SHALL open the AI_Assistant pre-seeded with the crop type, current price, 7-day price trend summary, and the suggestion text as initial context.
9. THE App SHALL display Market_Price values in both THB per kilogram (บาท/กก.) and THB per tonne (บาท/ตัน), with two decimal places.
10. IF Market_Price data for a registered crop type has not been updated for more than 3 consecutive days, THEN THE App SHALL display a Thai-language data unavailability notice in place of the price chart for that crop.

---

### Requirement 11: Offline Support and Data Resilience

**User Story:** As a Farmer, I want the App to work in areas with poor internet connectivity, so that I can still view my farm data and records when I am in the field.

#### Acceptance Criteria

1. THE App SHALL cache the 10 most recent Soil_Data readings per Plot in encrypted local storage so that readings are viewable without an internet connection.
2. THE App SHALL cache the most recent Fertilizer_Recommendation per Plot in encrypted local storage so that it is viewable offline.
3. THE App SHALL cache up to 500 Farm_Record entries from the past 90 days in encrypted local storage.
4. WHILE the device has no internet connection, THE App SHALL display a Thai-language offline banner; features requiring network access (AI Assistant, Realtime updates, Market Prices) SHALL be visually disabled and non-interactive, and SHALL display a Thai tooltip on tap explaining they require connectivity.
5. WHEN internet connectivity is restored, THE App SHALL attempt to synchronise locally created or edited Farm_Record entries to Supabase within 30 seconds, using last-modified timestamp as the conflict resolution rule (last write wins).
6. IF synchronisation fails after 3 attempts, THE App SHALL display a Thai-language sync error notification; locally saved data SHALL be preserved and retried on the next connectivity restoration.
7. THE App SHALL display the age of cached data on each screen when offline, refreshed every 60 seconds, using Thai-language relative timestamps (e.g., "อัปเดตเมื่อ 2 ชั่วโมงที่แล้ว").
8. THE App SHALL store all cached data in encrypted local storage accessible only to the App process, using the device's secure enclave or equivalent platform mechanism.

---

### Requirement 12: Notifications and Alerts

**User Story:** As a Farmer, I want to receive timely alerts about my soil conditions and market prices, so that I can act quickly when something needs attention.

#### Acceptance Criteria

1. THE App SHALL deliver push notifications to the Farmer's device within 5 minutes of the triggering event.
2. WHEN a Soil_Health_Score for a Plot drops below 40, THE App SHALL send a push notification in Thai identifying the Plot name and the specific sensor parameters (N, P, K, moisture) that are below their recommended thresholds; a second notification for the same drop event on the same Plot SHALL NOT be sent until the score recovers above 40 and drops below it again.
3. WHEN a Market_Price crosses a Farmer-defined alert threshold for a registered crop type, THE App SHALL send a push notification in Thai stating the crop type, current price in THB/kg, and the threshold that was breached; subsequent notifications for the same crop SHALL be suppressed for 24 hours after each trigger.
4. THE App SHALL allow a Farmer to enable or disable each notification category (soil alerts, market alerts, AI summaries) and set numeric thresholds where applicable from the More tab settings screen.
5. WHEN a Farmer disables a notification category, THE App SHALL immediately discard any pending notifications in that category and not deliver them.
6. THE App SHALL display received notifications in an in-app notification centre accessible from the More tab, ordered newest-first, retaining up to 100 notifications, with unread notifications visually distinguished from read ones.
7. WHEN a Farmer taps an in-app notification, THE App SHALL navigate to the relevant screen; IF the target screen or resource no longer exists, THE App SHALL navigate to the closest parent screen and display a Thai-language message explaining the target is unavailable.

---

### Requirement 13: Security and Data Privacy

**User Story:** As a Farmer, I want my data to be secure and private, so that my farm information is not accessible to unauthorised parties.

#### Acceptance Criteria

1. THE Backend_Function SHALL store and use the Gemini API key exclusively server-side; the Gemini API key SHALL NOT be present in the Flutter client bundle or transmitted in any network response to the client.
2. WHEN the Backend_Function receives an IoT ingestion request with an invalid or missing per-device token, THE Backend_Function SHALL reject it with an HTTP 401 response and not process the payload; the invalid token SHALL NOT appear in any response to the client.
3. THE Supabase database SHALL enforce Row Level Security (RLS) policies restricting each authenticated Farmer to read and write only their own Farm, Plot, Soil_Data, Farm_Record, and conversation records; an unauthorized access attempt SHALL return a not-found or permission-denied response that does not leak the existence of another Farmer's data.
4. THE App SHALL transmit all data exclusively over HTTPS/TLS; any unencrypted HTTP request SHALL be rejected by the App before transmission.
5. THE App SHALL store session tokens, authentication credentials, and PII cached locally in encrypted storage using the platform's secure storage mechanism.
6. WHEN a session token expires during an in-progress operation, THE App SHALL discard the protected operation, preserve any unsaved form data in memory, prompt the Farmer to re-authenticate, and resume the operation after successful re-authentication.
7. WHEN a Farmer registers, THE App SHALL display the privacy policy and require an affirmative, unchecked consent action in Thai before creating the account; the App SHALL record the timestamp of consent and SHALL NOT create the account if consent is not given.

---

### Requirement 14: Accessibility and Usability for Low-Literacy Users

**User Story:** As a Farmer with limited reading ability, I want the App to use icons and simple language, so that I can use it without difficulty.

#### Acceptance Criteria

1. THE App SHALL use a minimum body text size of 16sp and a minimum touch target size of 48×48dp for all interactive elements.
2. THE App SHALL use icon-first design on all primary navigation and action buttons, pairing each icon with a short Thai label of no more than 3 words.
3. THE App SHALL use color-coded status indicators using three visually distinct colors representing positive, warning, and critical states for soil health and alerts.
4. THE App SHALL provide Thai-language voice input support on all screens that require data entry, including the AI_Assistant chat screen and Farm Record entry forms.
5. THE App SHALL display all numeric readings (NPK values, soil scores, market prices) using large, bold typography of at least 24sp.
6. THE App SHALL apply a designated mint-green color for positive states and primary action buttons, and a designated dark-brown color for headers and secondary text consistently across all screens.
7. THE App SHALL maintain a minimum contrast ratio of 4.5:1 for all body text against its background, and 3:1 for large text (18sp or 14sp bold), in accordance with WCAG 2.1 AA.
8. THE App SHALL not rely on color alone to convey meaning; each color-coded indicator SHALL also include a Thai text label or a supplementary icon that distinguishes its state independently of color.
9. WHEN the App displays a confirmation or destructive action dialog, THE App SHALL render each action button with a minimum height of 48dp, a minimum width of 120dp, and a Thai label that clearly identifies the action.
10. IF Thai-language voice input is unavailable on the user's device, THEN THE App SHALL display a Thai-language message indicating voice input is not supported and ensure the same action can be completed via text input.

---

### Requirement 15: Demo Mode

**User Story:** As a prospective Farmer user, I want to explore the App without registering, so that I can understand its features before committing.

#### Acceptance Criteria

1. THE App SHALL display a "ทดลองใช้งาน" (Try Demo) button on the login screen as a clearly visible secondary action.
2. WHEN a user taps "ทดลองใช้งาน", THE App SHALL display a preset selection screen listing all three demo datasets by name in Thai: ภัยแล้ง / ไนโตรเจนต่ำ (Drought/Low N), สภาพดินสมบูรณ์ (Optimal), and ความชื้นสูง / เสี่ยงโรคพืช (High Humidity/Disease); THE App SHALL load the selected preset and navigate to the dashboard only after the user explicitly chooses one.
3. WHEN a user switches between demo presets from within Demo Mode, THE App SHALL reset all screen states and reload the dashboard with the newly selected preset's data without navigating to the login screen.
4. WHILE in Demo Mode, THE App SHALL disable all write operations to the Supabase database and display a persistent Thai-language banner at the top of every screen: "โหมดสาธิต — ข้อมูลไม่ถูกบันทึก".
5. WHILE in Demo Mode, THE App SHALL use preloaded example AI responses for the AI_Assistant and Fertilizer_Recommendation features without making live Gemini_API calls.
6. WHEN a user attempts to access a feature in Demo Mode that requires a real account — including saving a Farm_Record, associating a Sensor_Device, setting a price alert, or configuring notifications — THE App SHALL display a Thai-language modal that states the feature is unavailable in Demo Mode and provides a "สมัครใช้งาน" (Register) call-to-action button.
7. THE App SHALL provide the following P0 screens in Demo Mode with fully populated preloaded data such that every field, chart data point, and list item displays a non-empty value: Dashboard, Soil Monitoring, Fertilizer Recommendation, AI Assistant, Farm Record list, and Farm detail.
8. IF a demo preset fails to load, THEN THE App SHALL remain on the preset selection screen and display a Thai-language error message; THE App SHALL NOT navigate to the dashboard with empty or partially loaded data.
