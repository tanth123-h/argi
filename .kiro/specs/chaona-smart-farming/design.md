# Technical Design Document — ชาวนา (Chao Na) AI Smart Farming

**Version:** 1.0  
**Status:** Draft  
**Last Updated:** 2025  
**Based on:** requirements.md v1.0

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Flutter App Architecture](#2-flutter-app-architecture)
3. [Data Models](#3-data-models)
4. [State Management Design](#4-state-management-design)
5. [Navigation Design](#5-navigation-design)
6. [Repository Layer](#6-repository-layer)
7. [Soil Health Score Algorithm](#7-soil-health-score-algorithm)
8. [Demo Mode Architecture](#8-demo-mode-architecture)
9. [Offline / Cache Strategy](#9-offline--cache-strategy)
10. [IoT / MQTT Integration](#10-iot--mqtt-integration)
11. [AI Integration](#11-ai-integration)
12. [Security Design](#12-security-design)
13. [Database Design](#13-database-design)
14. [API Contract](#14-api-contract)
15. [Error Handling Strategy](#15-error-handling-strategy)

---

## 1. System Architecture

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FARMER'S DEVICE                              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Flutter App (Dart / flutter_riverpod)           │  │
│  │  ┌─────────┐ ┌──────────┐ ┌────────┐ ┌────────┐ ┌───────┐  │  │
│  │  │Dashboard│ │   Farm   │ │  AI   │ │ Market │ │ More  │  │  │
│  │  │  Screen │ │  Mgmt   │ │  Tab  │ │  Tab   │ │  Tab  │  │  │
│  │  └────┬────┘ └────┬─────┘ └───┬───┘ └───┬────┘ └───┬───┘  │  │
│  │       └───────────┴───────────┴──────────┴──────────┘       │  │
│  │                    Riverpod Provider Tree                    │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  Repository Layer (abstract interfaces)                │  │  │
│  │  └────────────────┬───────────────────────────────────────┘  │  │
│  │                   │                                           │  │
│  │  ┌────────────────┼───────────────────┐                      │  │
│  │  │ Supabase SDK   │ flutter_secure_   │                      │  │
│  │  │ (Auth/DB/RT)   │ storage (cache)   │                      │  │
│  │  └────────────────┴───────────────────┘                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
         │ HTTPS/TLS               │ HTTPS/TLS
         ▼                         ▼
┌────────────────┐       ┌──────────────────────┐
│   Supabase     │       │  Backend Functions   │
│  ┌──────────┐  │       │  (Supabase Edge /    │
│  │ Auth     │  │       │   Cloud Functions)   │
│  ├──────────┤  │       │  ┌────────────────┐  │
│  │PostgreSQL│  │       │  │ /ai/chat       │  │
│  ├──────────┤  │       │  │ /ai/fertilizer │  │
│  │ Realtime │  │       │  │ /ai/disease    │  │
│  ├──────────┤  │       │  │ /iot/soil      │  │
│  │ Storage  │  │       │  │ /market/prices │  │
│  └──────────┘  │       │  └───────┬────────┘  │
└───────┬────────┘       └──────────┼───────────┘
        │                           │ HTTPS
        │ Realtime WS               ▼
        │                  ┌──────────────────┐
        └──────────────────│  Google Gemini   │
                           │  1.5/2.0 Flash   │
                           └──────────────────┘

┌─────────────────────────────────────┐
│           IoT Layer                 │
│  ESP32 + RS485 NPK Sensor           │
│  → MQTT Publish (farm/{id}/soil_    │
│    telemetry)                       │
│  → MQTT Broker (Mosquitto/EMQX)     │
│  → Backend_Function /iot/soil       │
│  → Supabase soil_data table         │
│  → Supabase Realtime → Flutter App  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│       Push Notifications            │
│  Firebase Messaging (FCM) or        │
│  Supabase Webhooks → FCM            │
│  → Device push channel              │
└─────────────────────────────────────┘
```

### 1.2 Data Flow — Soil Monitoring (Real-time Path)

```
ESP32 Sensor
  │  RS485 read (N, P, K, moisture, pH, temp)
  │  every 5–60 min
  ▼
MQTT Broker  topic: farm/{farm_id}/soil_telemetry
  ▼
Backend Function: POST /api/v1/iot/soil
  │  1. Validate device_token (HTTP 401 on fail)
  │  2. Validate payload fields (HTTP 400 on fail)
  │  3. INSERT into soil_data
  │  4. Supabase Realtime broadcast on channel farm:{farm_id}
  ▼
Flutter App (RealtimeChannel.onPostgresChanges)
  │  SoilMonitoringNotifier.handleRealtimeEvent()
  │  Update gauge values within 5 s
  ▼
Dashboard Card + Soil Monitoring Screen refresh
```

### 1.3 Data Flow — AI Fertilizer Recommendation

```
Flutter App
  │  Farmer taps "ขอคำแนะนำ"
  │  Collect: latest soil_data, crop_type, DAP, farm_id
  ▼
Backend Function: POST /api/v1/ai/fertilizer-recommendation
  │  1. Load agronomic decision matrix for crop_type + DAP
  │  2. Build Gemini prompt (see §11)
  │  3. Call Gemini 1.5/2.0 Flash (server-side key)
  │  4. Parse structured JSON response
  │  5. Return recommendation (NO API key in response)
  ▼
Flutter App
  │  FertilizerRecommendationNotifier receives response
  │  Render Thai-language recommendation card
  │  Option to save → Farm_Record entry
```

### 1.4 Integration Points Summary

| Integration | Protocol | Auth Method | Direction |
|---|---|---|---|
| Supabase Auth | HTTPS REST | JWT (Bearer) | App ↔ Supabase |
| Supabase DB | HTTPS REST | JWT (Bearer) | App ↔ Supabase |
| Supabase Realtime | WebSocket | JWT (Bearer) | Supabase → App |
| Supabase Storage | HTTPS REST | JWT (Bearer) | App ↔ Supabase |
| Backend Functions | HTTPS REST | JWT (Bearer) | App → Functions |
| IoT Ingestion | HTTPS REST | Device Token | ESP32 → Functions |
| Gemini API | HTTPS REST | Server API Key | Functions → Google |
| MQTT Broker | MQTT/TLS | Device Token | ESP32 → Broker |
| FCM Push | HTTPS REST | Service Account | Functions → FCM |
| Weather API | HTTPS REST | API Key (server) | Functions → Weather |

---

## 2. Flutter App Architecture

### 2.1 Full Folder Structure

```
lib/
├── app/
│   ├── app.dart                    # MaterialApp + ProviderScope root
│   ├── router.dart                 # go_router route configuration
│   └── theme.dart                  # ThemeData (mint green / dark brown)
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart      # API base URL, timeout durations
│   │   ├── supabase_constants.dart # Table names, RLS channel names
│   │   └── storage_keys.dart      # flutter_secure_storage key constants
│   ├── error/
│   │   ├── failures.dart           # Sealed class hierarchy for failures
│   │   └── exceptions.dart        # Typed exceptions (NetworkException, etc.)
│   ├── network/
│   │   ├── network_info.dart       # Connectivity check abstraction
│   │   └── api_client.dart        # HTTP client wrapper (Dio/http)
│   └── utils/
│       ├── date_utils.dart         # Thai locale date formatting helpers
│       ├── validator_utils.dart    # Phone/email/form validators
│       └── soil_calculator.dart   # Soil Health Score pure functions
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── auth_remote_datasource.dart   # Supabase Auth calls
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── user_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── app_user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart          # Abstract interface
│   │   │   └── usecases/
│   │   │       ├── sign_in_usecase.dart
│   │   │       ├── sign_up_usecase.dart
│   │   │       ├── sign_out_usecase.dart
│   │   │       └── reset_password_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart             # AuthNotifier
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── register_screen.dart
│   │       │   └── demo_preset_screen.dart
│   │       └── widgets/
│   │           ├── phone_field.dart
│   │           └── password_field.dart
│   │
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── dashboard_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── dashboard_summary.dart
│   │   │   └── repositories/
│   │   │       └── dashboard_repository.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── dashboard_provider.dart        # DashboardNotifier
│   │       ├── screens/
│   │       │   └── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── soil_card.dart
│   │           ├── weather_card.dart
│   │           ├── recommendation_card.dart
│   │           └── demo_banner.dart
│   │
│   ├── farm_management/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── farm_remote_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── farm_repository_impl.dart
│   │   │   └── dtos/
│   │   │       ├── farm_dto.dart
│   │   │       └── plot_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── farm.dart
│   │   │   │   └── plot.dart
│   │   │   ├── repositories/
│   │   │   │   └── farm_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_farm_usecase.dart
│   │   │       ├── update_farm_usecase.dart
│   │   │       ├── delete_farm_usecase.dart
│   │   │       ├── create_plot_usecase.dart
│   │   │       ├── update_plot_usecase.dart
│   │   │       ├── delete_plot_usecase.dart
│   │   │       └── associate_sensor_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── farm_list_provider.dart
│   │       │   └── plot_detail_provider.dart
│   │       ├── screens/
│   │       │   ├── farm_list_screen.dart
│   │       │   ├── farm_detail_screen.dart
│   │       │   ├── create_farm_screen.dart
│   │       │   ├── create_plot_screen.dart
│   │       │   └── sensor_association_screen.dart
│   │       └── widgets/
│   │           ├── plot_card.dart
│   │           └── crop_type_picker.dart
│   │
│   ├── soil_monitoring/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── soil_remote_datasource.dart
│   │   │   │   └── soil_local_datasource.dart     # flutter_secure_storage
│   │   │   ├── repositories/
│   │   │   │   └── soil_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── soil_data_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── soil_data.dart
│   │   │   │   └── soil_health_score.dart
│   │   │   ├── repositories/
│   │   │   │   └── soil_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_latest_soil_usecase.dart
│   │   │       ├── get_soil_history_usecase.dart
│   │   │       └── calculate_soil_score_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── soil_monitoring_provider.dart  # SoilMonitoringNotifier
│   │       ├── screens/
│   │       │   └── soil_monitoring_screen.dart
│   │       └── widgets/
│   │           ├── npk_gauge.dart
│   │           ├── moisture_gauge.dart
│   │           ├── soil_trend_chart.dart          # fl_chart wrapper
│   │           └── health_score_indicator.dart
│   │
│   ├── fertilizer_recommendation/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── fertilizer_remote_datasource.dart
│   │   │   │   └── fertilizer_local_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── fertilizer_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── fertilizer_recommendation_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── fertilizer_recommendation.dart
│   │   │   ├── repositories/
│   │   │   │   └── fertilizer_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_recommendation_usecase.dart
│   │   │       ├── save_recommendation_usecase.dart
│   │   │       └── get_recommendation_history_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── fertilizer_provider.dart
│   │       ├── screens/
│   │       │   ├── recommendation_screen.dart
│   │       │   └── recommendation_history_screen.dart
│   │       └── widgets/
│   │           ├── recommendation_card.dart
│   │           └── cost_estimate_chip.dart
│   │
│   ├── ai_chat/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── chat_remote_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── chat_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── conversation_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── chat_message.dart
│   │   │   │   └── conversation.dart
│   │   │   ├── repositories/
│   │   │   │   └── chat_repository.dart
│   │   │   └── usecases/
│   │   │       ├── send_message_usecase.dart
│   │   │       └── clear_conversation_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── chat_provider.dart             # ChatNotifier
│   │       ├── screens/
│   │       │   └── chat_screen.dart
│   │       └── widgets/
│   │           ├── message_bubble.dart
│   │           ├── typing_indicator.dart
│   │           └── voice_input_button.dart
│   │
│   ├── disease_detection/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── disease_remote_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── disease_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── disease_result_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── disease_result.dart
│   │   │   ├── repositories/
│   │   │   │   └── disease_repository.dart
│   │   │   └── usecases/
│   │   │       ├── detect_disease_usecase.dart
│   │   │       └── save_disease_record_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── disease_provider.dart
│   │       ├── screens/
│   │       │   ├── disease_detection_screen.dart
│   │       │   └── disease_result_screen.dart
│   │       └── widgets/
│   │           ├── camera_capture_widget.dart
│   │           └── confidence_badge.dart
│   │
│   ├── farm_record/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── record_remote_datasource.dart
│   │   │   │   └── record_local_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── record_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── farm_record_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── farm_record.dart
│   │   │   ├── repositories/
│   │   │   │   └── record_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_record_usecase.dart
│   │   │       ├── update_record_usecase.dart
│   │   │       ├── delete_record_usecase.dart
│   │   │       ├── get_records_usecase.dart
│   │   │       └── export_pdf_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── record_provider.dart
│   │       ├── screens/
│   │       │   ├── record_list_screen.dart
│   │       │   ├── record_detail_screen.dart
│   │       │   └── create_record_screen.dart
│   │       └── widgets/
│   │           ├── record_list_item.dart
│   │           ├── income_expense_summary.dart
│   │           └── record_type_selector.dart
│   │
│   ├── market/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── market_remote_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── market_repository_impl.dart
│   │   │   └── dtos/
│   │   │       └── market_price_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── market_price.dart
│   │   │   ├── repositories/
│   │   │   │   └── market_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_market_prices_usecase.dart
│   │   │       ├── set_price_alert_usecase.dart
│   │   │       └── get_sell_suggestion_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── market_provider.dart
│   │       ├── screens/
│   │       │   └── market_dashboard_screen.dart
│   │       └── widgets/
│   │           ├── price_chart.dart
│   │           ├── price_change_badge.dart
│   │           └── sell_suggestion_card.dart
│   │
│   └── notifications/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── notification_datasource.dart
│       │   └── repositories/
│       │       └── notification_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── app_notification.dart
│       │   ├── repositories/
│       │   │   └── notification_repository.dart
│       │   └── usecases/
│       │       ├── get_notifications_usecase.dart
│       │       └── mark_read_usecase.dart
│       └── presentation/
│           ├── providers/
│           │   └── notification_provider.dart
│           ├── screens/
│           │   └── notification_center_screen.dart
│           └── widgets/
│               └── notification_list_item.dart
│
└── shared/
    ├── widgets/
    │   ├── offline_banner.dart         # Thai offline indicator
    │   ├── loading_overlay.dart        # Full-screen loading
    │   ├── error_display.dart          # Thai error message widget
    │   ├── confirm_dialog.dart         # Thai confirmation dialogs
    │   ├── bottom_nav_bar.dart         # 5-tab bottom navigation
    │   └── thai_date_text.dart         # Locale-formatted date display
    └── models/
        └── result.dart                 # Result<T, Failure> sealed type
```

### 2.2 Clean Architecture Layers

Each feature is organized into three layers with strict one-direction dependency:

```
Presentation  →  Domain  ←  Data
     │              │          │
 Providers      Entities    DTOs
 Screens        Use Cases   Remote DS
 Widgets        Repo Iface  Local DS
                            Repo Impl
```

**Rules:**
- Domain layer has zero external dependencies (pure Dart).
- Data layer implements domain repository interfaces.
- Presentation layer consumes use cases via Riverpod providers.
- DTOs are converted to domain entities at the repository boundary.
- Failures are represented as sealed classes, never raw exceptions in domain/presentation.

### 2.3 Riverpod Provider Tree (Top-Level)

```dart
// Dependency order: infrastructure → domain → presentation

// Infrastructure
supabaseClientProvider          // Supabase client singleton
secureStorageProvider           // FlutterSecureStorage singleton
networkInfoProvider             // Connectivity checker
demoModeProvider                // DemoModeNotifier (StateNotifier)

// Feature: Auth
authRepositoryProvider          // depends on supabaseClient
authNotifierProvider            // depends on authRepository, demoMode

// Feature: Farm
farmRepositoryProvider          // depends on supabase, secureStorage, networkInfo, demoMode
farmListNotifierProvider        // depends on farmRepository
selectedFarmProvider            // StateProvider<String?> (farm_id)

// Feature: Soil
soilRepositoryProvider          // depends on supabase, secureStorage, demoMode
soilMonitoringNotifierProvider  // family(plotId) — depends on soilRepository

// Feature: Fertilizer
fertilizerRepositoryProvider
fertilizerNotifierProvider      // family(plotId)

// Feature: AI Chat
chatRepositoryProvider
chatNotifierProvider            // family(farmId)

// Feature: Disease Detection
diseaseRepositoryProvider
diseaseNotifierProvider

// Feature: Farm Record
recordRepositoryProvider
recordNotifierProvider          // depends on recordRepository, networkInfo

// Feature: Market
marketRepositoryProvider
marketNotifierProvider

// Feature: Notifications
notificationRepositoryProvider
notificationNotifierProvider
```

---

## 3. Data Models

### 3.1 Core Domain Entities (Dart)

```dart
// lib/features/auth/domain/entities/app_user.dart
class AppUser {
  final String id;          // Supabase auth UUID
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final bool isDemo;
  const AppUser({required this.id, this.email, this.phone,
    required this.createdAt, this.isDemo = false});
}

// lib/features/farm_management/domain/entities/farm.dart
class Farm {
  final String id;
  final String userId;
  final String name;           // 1–100 chars
  final String? location;
  final double areaRai;        // > 0
  final String cropType;
  final DateTime createdAt;
  final List<Plot> plots;
  const Farm({required this.id, required this.userId, required this.name,
    this.location, required this.areaRai, required this.cropType,
    required this.createdAt, this.plots = const []});
}

// lib/features/farm_management/domain/entities/plot.dart
class Plot {
  final String id;
  final String farmId;
  final String name;           // 1–100 chars
  final double areaRai;        // 0 < areaRai <= 10000
  final String cropType;       // from predefined list
  final String? sensorDeviceToken;
  final bool isDeleted;        // soft-delete flag
  final DateTime createdAt;
  const Plot({required this.id, required this.farmId, required this.name,
    required this.areaRai, required this.cropType, this.sensorDeviceToken,
    this.isDeleted = false, required this.createdAt});
}

// lib/features/soil_monitoring/domain/entities/soil_data.dart
class SoilData {
  final String id;
  final String farmId;
  final double moisture;       // percentage
  final double nitrogen;       // mg/kg
  final double phosphorus;     // mg/kg
  final double potassium;      // mg/kg
  final double phLevel;        // default 6.5
  final double? temperature;
  final bool isDemoData;
  final DateTime createdAt;
  const SoilData({required this.id, required this.farmId,
    required this.moisture, required this.nitrogen,
    required this.phosphorus, required this.potassium,
    this.phLevel = 6.5, this.temperature, this.isDemoData = false,
    required this.createdAt});
}

// lib/features/soil_monitoring/domain/entities/soil_health_score.dart
class SoilHealthScore {
  final double composite;      // 0–100
  final double moistureScore;
  final double nScore;
  final double pScore;
  final double kScore;
  SoilHealthScoreBand get band {
    if (composite >= 70) return SoilHealthScoreBand.good;
    if (composite >= 40) return SoilHealthScoreBand.moderate;
    return SoilHealthScoreBand.poor;
  }
  const SoilHealthScore({required this.composite, required this.moistureScore,
    required this.nScore, required this.pScore, required this.kScore});
}

enum SoilHealthScoreBand { good, moderate, poor }

// lib/features/fertilizer_recommendation/domain/entities/fertilizer_recommendation.dart
class FertilizerRecommendation {
  final String id;
  final String plotId;
  final String cropType;
  final int dap;               // days after planting
  final List<FertilizerProduct> products;
  final String reasoningThai;  // Thai explanation
  final double? estimatedCostPerRai;
  final DateTime generatedAt;
  const FertilizerRecommendation({required this.id, required this.plotId,
    required this.cropType, required this.dap, required this.products,
    required this.reasoningThai, this.estimatedCostPerRai,
    required this.generatedAt});
}

class FertilizerProduct {
  final String nameThai;
  final String nameCommon;     // e.g. "16-20-0"
  final double rateKgPerRai;
  final String timingThai;
  const FertilizerProduct({required this.nameThai, required this.nameCommon,
    required this.rateKgPerRai, required this.timingThai});
}

// lib/features/ai_chat/domain/entities/chat_message.dart
class ChatMessage {
  final String id;
  final String content;
  final ChatRole role;         // user | assistant
  final DateTime timestamp;
  const ChatMessage({required this.id, required this.content,
    required this.role, required this.timestamp});
}

enum ChatRole { user, assistant }

// lib/features/ai_chat/domain/entities/conversation.dart
class Conversation {
  final String id;
  final String farmId;
  final List<ChatMessage> messages;  // max 20 turns for API
  final DateTime startedAt;
  const Conversation({required this.id, required this.farmId,
    this.messages = const [], required this.startedAt});
}

// lib/features/farm_record/domain/entities/farm_record.dart
enum RecordType { planting, fertilizing, expense, harvest, disease }

class FarmRecord {
  final String id;
  final String farmId;
  final String plotId;
  final RecordType recordType;
  final String title;
  final double? amount;         // kg or THB depending on type
  final double? cost;           // THB
  final double? quantityKg;     // harvest only
  final double? sellingPriceTHBPerKg;  // harvest only
  final DateTime recordDate;
  final String? notes;
  final String? imageUrl;       // Supabase Storage URL
  final bool isSynced;          // false = pending upload
  final DateTime createdAt;
  final DateTime updatedAt;
  const FarmRecord({required this.id, required this.farmId,
    required this.plotId, required this.recordType, required this.title,
    this.amount, this.cost, this.quantityKg, this.sellingPriceTHBPerKg,
    required this.recordDate, this.notes, this.imageUrl,
    this.isSynced = true, required this.createdAt, required this.updatedAt});
}

// lib/features/disease_detection/domain/entities/disease_result.dart
class DiseaseResult {
  final String id;
  final String? farmId;
  final String imageUrl;
  final String diseaseNameThai;
  final String diseaseNameEn;
  final double confidenceScore;  // 0.0–1.0
  final List<String> treatmentStepsThai;  // max 5 steps
  final DateTime detectedAt;
  const DiseaseResult({required this.id, this.farmId, required this.imageUrl,
    required this.diseaseNameThai, required this.diseaseNameEn,
    required this.confidenceScore, required this.treatmentStepsThai,
    required this.detectedAt});
}

// lib/features/market/domain/entities/market_price.dart
class MarketPrice {
  final String id;
  final String cropName;
  final double priceTHBPerKg;
  final double priceTHBPerTonne;  // computed: priceTHBPerKg * 1000
  final double? changePercent;    // day-over-day
  final DateTime priceDate;
  final DateTime lastUpdated;
  const MarketPrice({required this.id, required this.cropName,
    required this.priceTHBPerKg, required this.priceDate,
    this.changePercent, required this.lastUpdated})
      : priceTHBPerTonne = priceTHBPerKg * 1000;
}

// lib/features/notifications/domain/entities/app_notification.dart
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String titleThai;
  final String bodyThai;
  final String? targetRoute;   // go_router path for deep link
  final bool isRead;
  final DateTime createdAt;
  const AppNotification({required this.id, required this.userId,
    required this.type, required this.titleThai, required this.bodyThai,
    this.targetRoute, this.isRead = false, required this.createdAt});
}

enum NotificationType { soilAlert, marketAlert, aiSummary, system }
```

### 3.2 DTO → Entity Mapping Pattern

```dart
// Example: SoilDataDto → SoilData
class SoilDataDto {
  final String id;
  final String farmId;
  final double moisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double phLevel;
  final bool isDemoData;
  final String createdAt;       // ISO 8601 string from Supabase

  factory SoilDataDto.fromJson(Map<String, dynamic> json) => SoilDataDto(
    id: json['id'] as String,
    farmId: json['farm_id'] as String,
    moisture: (json['moisture'] as num).toDouble(),
    nitrogen: (json['nitrogen'] as num).toDouble(),
    phosphorus: (json['phosphorus'] as num).toDouble(),
    potassium: (json['potassium'] as num).toDouble(),
    phLevel: (json['ph_level'] as num?)?.toDouble() ?? 6.5,
    isDemoData: json['is_demo_data'] as bool? ?? false,
    createdAt: json['created_at'] as String,
  );

  SoilData toEntity() => SoilData(
    id: id, farmId: farmId, moisture: moisture,
    nitrogen: nitrogen, phosphorus: phosphorus, potassium: potassium,
    phLevel: phLevel, isDemoData: isDemoData,
    createdAt: DateTime.parse(createdAt),
  );
}
```

### 3.3 Result Type

```dart
// lib/shared/models/result.dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}
```

---

## 4. State Management Design

### 4.1 Provider Conventions

All providers use **Riverpod v2 code generation** (`@riverpod` annotations).

- `AsyncNotifierProvider` — for async data with loading/error/data states
- `NotifierProvider` — for synchronous state with mutations
- `StreamProvider` — for Supabase Realtime streams
- `Provider` — for dependency injection (repositories, clients)
- `StateProvider` — for simple selected-item state (e.g., selectedFarmId)

### 4.2 Auth Provider

```dart
// lib/features/auth/presentation/providers/auth_provider.dart

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Stream<AppUser?> build() {
    return ref.watch(authRepositoryProvider).authStateChanges();
  }

  Future<void> signIn(String identifier, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(identifier, password),
    );
  }

  Future<void> signUp(String identifier, String password) async { ... }
  Future<void> signOut() async { ... }
  Future<void> resetPassword(String identifier) async { ... }
}
```

### 4.3 Demo Mode Provider

```dart
// lib/features/auth/presentation/providers/demo_mode_provider.dart

enum DemoPreset { none, droughtLowN, optimal, highHumidityDisease }

@riverpod
class DemoModeNotifier extends _$DemoModeNotifier {
  @override
  DemoPreset build() => DemoPreset.none;

  void enterDemo(DemoPreset preset) => state = preset;
  void exitDemo() => state = DemoPreset.none;

  bool get isActive => state != DemoPreset.none;
}

// Repositories read this provider to decide data source
// Example pattern in repositories:
//   final isDemo = ref.read(demoModeNotifierProvider.notifier).isActive;
//   if (isDemo) return demoFixtures[preset];
//   return supabaseCall();
```

### 4.4 Soil Monitoring Notifier (with Realtime)

```dart
@riverpod
class SoilMonitoringNotifier extends _$SoilMonitoringNotifier {
  RealtimeChannel? _channel;

  @override
  FutureOr<SoilMonitoringState> build(String plotId) async {
    final soilData = await ref.read(soilRepositoryProvider)
        .getLatestSoilData(plotId);
    final history = await ref.read(soilRepositoryProvider)
        .getSoilHistory(plotId, days: 7);
    _subscribeRealtime(plotId);
    return SoilMonitoringState(latest: soilData, history: history);
  }

  void _subscribeRealtime(String plotId) {
    final farmId = ref.read(selectedFarmProvider);
    _channel = ref.read(supabaseClientProvider).channel('farm:$farmId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'soil_data',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'farm_id',
          value: farmId,
        ),
        callback: (payload) => _handleRealtimeEvent(payload),
      ).subscribe();

    ref.onDispose(() => _channel?.unsubscribe());
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    final newData = SoilDataDto.fromJson(payload.newRecord).toEntity();
    state = state.whenData((s) => s.copyWith(
      latest: newData,
      history: [newData, ...s.history],
      lastUpdated: DateTime.now(),
    ));
  }
}

class SoilMonitoringState {
  final SoilData? latest;
  final List<SoilData> history;
  final DateTime? lastUpdated;
  final bool isRealtimeConnected;
  const SoilMonitoringState({this.latest, this.history = const [],
    this.lastUpdated, this.isRealtimeConnected = true});
  SoilMonitoringState copyWith({...}) { ... }
}
```

### 4.5 Offline-Aware Farm Record Provider

```dart
@riverpod
class RecordNotifier extends _$RecordNotifier {
  @override
  FutureOr<List<FarmRecord>> build(String farmId) async {
    // Load from local cache first, then sync
    final cached = await ref.read(recordRepositoryProvider).getCachedRecords(farmId);
    if (ref.read(networkInfoProvider).isConnected) {
      final remote = await ref.read(recordRepositoryProvider).getRemoteRecords(farmId);
      return remote;
    }
    return cached;
  }

  Future<void> createRecord(FarmRecord record) async {
    final repo = ref.read(recordRepositoryProvider);
    // Optimistic update
    state = AsyncData([record, ...state.value ?? []]);
    final result = await repo.createRecord(record);
    if (result is Failure) {
      // Roll back, queue for sync
      await repo.queueForSync(record);
      state = AsyncData([
        record.copyWith(isSynced: false),
        ...state.value?.where((r) => r.id != record.id) ?? [],
      ]);
    }
  }
}
```

### 4.6 Chat Provider (History Window)

```dart
@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  ChatState build(String farmId) => ChatState(farmId: farmId);

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(
      id: const Uuid().v4(), content: text,
      role: ChatRole.user, timestamp: DateTime.now(),
    );
    state = state.addMessage(userMsg).copyWith(isLoading: true);

    // Send only last 20 turns
    final history = state.messages.takeLast(20).toList();
    final result = await ref.read(chatRepositoryProvider)
        .sendMessage(farmId: farmId, message: text, history: history);

    result.when(
      success: (response) => state = state
          .addMessage(ChatMessage(id: ..., content: response,
              role: ChatRole.assistant, timestamp: DateTime.now()))
          .copyWith(isLoading: false),
      failure: (f) => state = state.copyWith(isLoading: false, error: f),
    );
  }

  void clearConversation() => state = ChatState(farmId: farmId);
}

class ChatState {
  final String farmId;
  final List<ChatMessage> messages;  // full history (display only)
  final bool isLoading;
  final AppFailure? error;
}
```

---

## 5. Navigation Design

### 5.1 Route Tree (go_router)

```dart
// lib/app/router.dart

final router = GoRouter(
  initialLocation: '/login',
  redirect: _globalRedirect,
  routes: [
    // Auth routes
    GoRoute(path: '/login',            builder: (ctx, s) => LoginScreen()),
    GoRoute(path: '/register',         builder: (ctx, s) => RegisterScreen()),
    GoRoute(path: '/demo-preset',      builder: (ctx, s) => DemoPresetScreen()),
    GoRoute(path: '/reset-password',   builder: (ctx, s) => ResetPasswordScreen()),

    // Main shell with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (ctx, s, shell) => MainScaffold(shell: shell),
      branches: [
        // Tab 0: Home (หน้าหลัก)
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, s) => DashboardScreen(),
          ),
        ]),

        // Tab 1: Farm (ฟาร์ม)
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/farms',
            builder: (ctx, s) => FarmListScreen(),
            routes: [
              GoRoute(
                path: ':farmId',
                builder: (ctx, s) => FarmDetailScreen(
                    farmId: s.pathParameters['farmId']!),
                routes: [
                  GoRoute(
                    path: 'plots/:plotId',
                    builder: (ctx, s) => PlotDetailScreen(
                        plotId: s.pathParameters['plotId']!),
                    routes: [
                      GoRoute(path: 'soil',
                          builder: (ctx, s) => SoilMonitoringScreen(
                              plotId: s.pathParameters['plotId']!)),
                      GoRoute(path: 'records',
                          builder: (ctx, s) => RecordListScreen(
                              plotId: s.pathParameters['plotId']!)),
                      GoRoute(path: 'fertilizer',
                          builder: (ctx, s) => RecommendationScreen(
                              plotId: s.pathParameters['plotId']!)),
                      GoRoute(path: 'sensor',
                          builder: (ctx, s) => SensorAssociationScreen(
                              plotId: s.pathParameters['plotId']!)),
                    ],
                  ),
                  GoRoute(path: 'create-plot',
                      builder: (ctx, s) => CreatePlotScreen(
                          farmId: s.pathParameters['farmId']!)),
                ],
              ),
              GoRoute(path: 'create',
                  builder: (ctx, s) => CreateFarmScreen()),
            ],
          ),
        ]),

        // Tab 2: AI
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/ai',
            builder: (ctx, s) => AiTabScreen(),   // sub-navigation
            routes: [
              GoRoute(path: 'chat',
                  builder: (ctx, s) => ChatScreen()),
              GoRoute(path: 'disease',
                  builder: (ctx, s) => DiseaseDetectionScreen()),
              GoRoute(path: 'disease/result',
                  builder: (ctx, s) => DiseaseResultScreen()),
            ],
          ),
        ]),

        // Tab 3: Market (ตลาด)
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/market',
            builder: (ctx, s) => MarketDashboardScreen(),
          ),
        ]),

        // Tab 4: More (เพิ่มเติม)
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/more',
            builder: (ctx, s) => MoreScreen(),
            routes: [
              GoRoute(path: 'notifications',
                  builder: (ctx, s) => NotificationCenterScreen()),
              GoRoute(path: 'settings',
                  builder: (ctx, s) => SettingsScreen()),
              GoRoute(path: 'records',
                  builder: (ctx, s) => RecordListScreen()),
              GoRoute(path: 'privacy-policy',
                  builder: (ctx, s) => PrivacyPolicyScreen()),
            ],
          ),
        ]),
      ],
    ),
  ],
);
```

### 5.2 Navigation Guards

```dart
// Global redirect function — runs on every navigation event
String? _globalRedirect(BuildContext ctx, GoRouterState state) {
  final authState = ProviderScope.containerOf(ctx)
      .read(authNotifierProvider);
  final demoMode = ProviderScope.containerOf(ctx)
      .read(demoModeNotifierProvider);

  final isAuthenticated = authState.valueOrNull != null;
  final isDemo = demoMode.isActive;
  final isOnAuthRoute = ['/login', '/register', '/demo-preset',
      '/reset-password'].contains(state.matchedLocation);

  // Not authenticated and not demo → force to login
  if (!isAuthenticated && !isDemo && !isOnAuthRoute) return '/login';

  // Already authenticated → skip login
  if ((isAuthenticated || isDemo) && isOnAuthRoute &&
      state.matchedLocation != '/demo-preset') return '/home';

  return null; // no redirect
}
```

### 5.3 Demo Mode Write Guard

Screens that attempt write operations check demo mode and show a modal:

```dart
// Shared helper used in screens/widgets
void guardDemoWrite(BuildContext ctx, WidgetRef ref, VoidCallback action) {
  if (ref.read(demoModeNotifierProvider.notifier).isActive) {
    showDialog(ctx, builder: (_) => DemoWriteBlockedDialog());
    return;
  }
  action();
}
```

---

## 6. Repository Layer

### 6.1 Abstract Interfaces

```dart
// lib/features/auth/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<Result<AppUser>> signIn(String identifier, String password);
  Future<Result<AppUser>> signUp(String identifier, String password);
  Future<Result<void>> signOut();
  Future<Result<void>> resetPassword(String identifier);
}

// lib/features/farm_management/domain/repositories/farm_repository.dart
abstract class FarmRepository {
  Future<Result<List<Farm>>> getFarms();
  Future<Result<Farm>> getFarmById(String farmId);
  Future<Result<Farm>> createFarm(Farm farm);
  Future<Result<Farm>> updateFarm(Farm farm);
  Future<Result<void>> deleteFarm(String farmId);
  Future<Result<Plot>> createPlot(Plot plot);
  Future<Result<Plot>> updatePlot(Plot plot);
  Future<Result<void>> deletePlot(String plotId);         // soft delete
  Future<Result<void>> associateSensor(String plotId, String token);
}

// lib/features/soil_monitoring/domain/repositories/soil_repository.dart
abstract class SoilRepository {
  Future<Result<SoilData?>> getLatestSoilData(String farmId);
  Future<Result<List<SoilData>>> getSoilHistory(String farmId,
      {required int days});
  Stream<SoilData> soilDataStream(String farmId);   // Realtime
  Future<Result<void>> cacheSoilData(List<SoilData> data, String farmId);
}

// lib/features/fertilizer_recommendation/domain/repositories/fertilizer_repository.dart
abstract class FertilizerRepository {
  Future<Result<FertilizerRecommendation>> getRecommendation({
    required String plotId, required SoilData soilData,
    required String cropType, required int dap,
  });
  Future<Result<List<FertilizerRecommendation>>> getHistory(String plotId);
  Future<Result<void>> cacheLatestRecommendation(
      FertilizerRecommendation r, String plotId);
  Future<Result<FertilizerRecommendation?>> getCachedRecommendation(
      String plotId);
}

// lib/features/ai_chat/domain/repositories/chat_repository.dart
abstract class ChatRepository {
  Future<Result<String>> sendMessage({
    required String farmId,
    required String message,
    required List<ChatMessage> history,
  });
  Future<Result<void>> saveConversation(Conversation conversation);
}

// lib/features/farm_record/domain/repositories/record_repository.dart
abstract class RecordRepository {
  Future<Result<List<FarmRecord>>> getRecords(String farmId,
      {RecordType? type, String? plotId, DateRange? range});
  Future<Result<FarmRecord>> createRecord(FarmRecord record);
  Future<Result<FarmRecord>> updateRecord(FarmRecord record);
  Future<Result<void>> deleteRecord(String recordId);
  Future<Result<List<FarmRecord>>> getCachedRecords(String farmId);
  Future<Result<void>> queueForSync(FarmRecord record);
  Future<Result<void>> syncPendingRecords();
  Future<Result<String>> uploadImage(String recordId, File image);
  Future<Result<Uint8List>> exportPdf(String farmId, DateRange range);
}

// lib/features/disease_detection/domain/repositories/disease_repository.dart
abstract class DiseaseRepository {
  Future<Result<DiseaseResult>> detectDisease(File imageFile);
  Future<Result<void>> saveDiseaseRecord(DiseaseResult result, String plotId);
  Future<Result<List<DiseaseResult>>> getDiseaseHistory(String plotId);
}

// lib/features/market/domain/repositories/market_repository.dart
abstract class MarketRepository {
  Future<Result<List<MarketPrice>>> getMarketPrices(List<String> cropTypes);
  Future<Result<List<MarketPrice>>> getPriceHistory(String cropType,
      {required int days});
  Future<Result<String>> getSellSuggestion(String cropType,
      List<MarketPrice> recentPrices);
  Future<Result<void>> setPriceAlert(String cropType, double threshold,
      bool alertAbove);
}
```

### 6.2 Supabase Implementations (Key Patterns)

```dart
// lib/features/farm_management/data/repositories/farm_repository_impl.dart
class FarmRepositoryImpl implements FarmRepository {
  final SupabaseClient _client;
  final DemoModeNotifier _demo;

  @override
  Future<Result<List<Farm>>> getFarms() async {
    if (_demo.isActive) {
      return Success(DemoFixtures.farmsFor(_demo.state));
    }
    try {
      final data = await _client
          .from('farms')
          .select('*, plots(*)')
          .order('created_at', ascending: false);
      return Success(data.map((j) => FarmDto.fromJson(j).toEntity()).toList());
    } on PostgrestException catch (e) {
      return Failure(DatabaseFailure(e.message));
    } catch (e) {
      return Failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deletePlot(String plotId) async {
    // Soft delete — RLS ensures user can only delete own plots
    try {
      await _client.from('plots').update({'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', plotId);
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(DatabaseFailure(e.message));
    }
  }
}
```

---

## 7. Soil Health Score Algorithm

### 7.1 Dart Implementation

```dart
// lib/core/utils/soil_calculator.dart

/// Calculates the Soil Health Score for given soil readings.
/// All parameters are in their natural units:
///   moisture: percentage (0–100)
///   nitrogen, phosphorus, potassium: mg/kg (0–100+ range)
class SoilCalculator {

  /// Moisture score: optimal 30–70%
  /// Score = 100 if in range, else max(0, 100 - |M - 55| * 2.5)
  static double moistureScore(double moisture) {
    if (moisture >= 30 && moisture <= 70) return 100.0;
    final deviation = (moisture - 55).abs();
    return (100 - deviation * 2.5).clamp(0.0, 100.0);
  }

  /// NPK individual score: <30 = Low, 30–70 = Normal, >70 = High
  /// Score = 100 in normal range; linear decay outside
  /// Low: score = (value / 30) * 100
  /// High: score = max(0, 100 - (value - 70) * 2.5)
  static double npkScore(double value) {
    if (value >= 30 && value <= 70) return 100.0;
    if (value < 30) return (value / 30 * 100).clamp(0.0, 100.0);
    return (100 - (value - 70) * 2.5).clamp(0.0, 100.0);
  }

  /// Composite = (moistureScore + nScore + pScore + kScore) / 4
  static SoilHealthScore calculate(SoilData data) {
    final mScore = moistureScore(data.moisture);
    final nScore = npkScore(data.nitrogen);
    final pScore = npkScore(data.phosphorus);
    final kScore = npkScore(data.potassium);
    final composite = (mScore + nScore + pScore + kScore) / 4.0;
    return SoilHealthScore(
      composite: composite,
      moistureScore: mScore,
      nScore: nScore,
      pScore: pScore,
      kScore: kScore,
    );
  }

  /// Score band thresholds per requirements.md §2 (bands: 70+/40-69/0-39)
  /// Note: requirements §2 uses 70/40 thresholds; design spec uses 80/50
  /// Resolution: requirements.md takes precedence → 70/40 bands
  static SoilHealthScoreBand band(double score) {
    if (score >= 70) return SoilHealthScoreBand.good;
    if (score >= 40) return SoilHealthScoreBand.moderate;
    return SoilHealthScoreBand.poor;
  }
}
```

### 7.2 NPK Alert Thresholds (Rice)

```dart
// lib/core/constants/agronomy_constants.dart

const Map<String, NpkThresholds> cropThresholds = {
  'rice': NpkThresholds(nMin: 30, nMax: 70, pMin: 30, pMax: 70,
      kMin: 30, kMax: 70, moistureMin: 30, moistureMax: 70),
  // Additional crops added here as the product expands
};

class NpkThresholds {
  final double nMin, nMax, pMin, pMax, kMin, kMax;
  final double moistureMin, moistureMax;
  const NpkThresholds({required this.nMin, required this.nMax,
    required this.pMin, required this.pMax,
    required this.kMin, required this.kMax,
    required this.moistureMin, required this.moistureMax});
}
```

### 7.3 Agronomic Decision Matrix — Rice

```dart
// lib/core/constants/agronomy_constants.dart (continued)

class RiceFertilizerMatrix {
  static FertilizerProduct? getRecommendation(int dap,
      {required double n, required double p, required double k}) {
    if (dap <= 20) {
      if (p < 30) {
        return const FertilizerProduct(nameThai: 'ปุ๋ยสูตร 16-20-0',
            nameCommon: '16-20-0', rateKgPerRai: 15,
            timingThai: 'ใส่ครั้งแรกหลังปลูก 0–20 วัน');
      }
    } else if (dap <= 45) {
      if (n < 30) {
        return const FertilizerProduct(nameThai: 'ยูเรีย 46-0-0',
            nameCommon: '46-0-0', rateKgPerRai: 17.5,
            timingThai: 'ใส่ระยะแตกกอ 21–45 วัน');
      }
    } else if (dap <= 70) {
      if ((n < 30 || (n >= 30 && n <= 70)) &&
          (p >= 30 && p <= 70) && k < 30) {
        return const FertilizerProduct(nameThai: 'ปุ๋ยสูตร 15-15-15',
            nameCommon: '15-15-15', rateKgPerRai: 15,
            timingThai: 'ใส่ระยะกำเนิดช่อดอก 46–70 วัน');
      }
    } else { // 71+
      if (k < 30) {
        return const FertilizerProduct(nameThai: 'โพแทสเซียมคลอไรด์ 0-0-60',
            nameCommon: '0-0-60', rateKgPerRai: 10,
            timingThai: 'ใส่ระยะออกรวง 71+ วัน');
      }
    }
    return null; // No critical deficiency
  }
}
```

---

## 8. Demo Mode Architecture

### 8.1 Preset Fixture Data

```dart
// lib/features/auth/data/demo/demo_fixtures.dart

class DemoFixtures {
  static const _droughtFarm = Farm(id: 'demo-farm-a', userId: 'demo-user',
      name: 'แปลงนาทดสอบ A', location: 'จ.พระนครศรีอยุธยา',
      areaRai: 10.0, cropType: 'rice', createdAt: _epoch,
      plots: [_droughtPlot]);

  static const _droughtSoil = SoilData(
    id: 'demo-soil-a', farmId: 'demo-farm-a',
    moisture: 18.0,   // triggers warning (< 20%)
    nitrogen: 15.0,   // Low → triggers Urea recommendation
    phosphorus: 35.0, potassium: 45.0, phLevel: 6.2,
    isDemoData: true, createdAt: _epoch,
  );

  static const _optimalFarm = Farm(id: 'demo-farm-b', ...);
  static const _optimalSoil = SoilData(
    moisture: 55.0, nitrogen: 50.0, phosphorus: 45.0, potassium: 55.0,
    isDemoData: true, ...
  );

  static const _diseaseFarm = Farm(id: 'demo-farm-c', ...);
  static const _diseaseSoil = SoilData(
    moisture: 85.0,   // triggers high humidity warning
    nitrogen: 40.0, phosphorus: 30.0, potassium: 35.0,
    isDemoData: true, ...
  );

  static Map<DemoPreset, Farm> get farms => {
    DemoPreset.droughtLowN: _droughtFarm,
    DemoPreset.optimal: _optimalFarm,
    DemoPreset.highHumidityDisease: _diseaseFarm,
  };

  static Map<DemoPreset, SoilData> get soilData => { ... };
  static Map<DemoPreset, List<FarmRecord>> get records => { ... };
  static Map<DemoPreset, FertilizerRecommendation> get recommendations => { ... };
  static Map<DemoPreset, List<ChatMessage>> get chatHistory => { ... };
  static Map<DemoPreset, DiseaseResult?> get diseaseResult => {
    DemoPreset.highHumidityDisease: DiseaseResult(
      id: 'demo-disease-c', diseaseNameThai: 'โรคไหม้ข้าว (Leaf Blast)',
      diseaseNameEn: 'Rice Leaf Blast', confidenceScore: 0.82,
      treatmentStepsThai: ['หยุดการให้น้ำ 3–5 วัน',
        'ฉีดพ่นสารป้องกันกำจัดโรคพืชที่มีสารไตรฟลอกซีสโตรบิน',
        'ลดปริมาณไนโตรเจน', 'ตรวจสอบแปลงใกล้เคียง',
        'ปรึกษาเจ้าหน้าที่เกษตร'],
      ...),
    DemoPreset.droughtLowN: null,
    DemoPreset.optimal: null,
  };
}
```

### 8.2 Provider Switching Mechanism

The `DemoModeNotifier` is injected into every repository via Riverpod. Each repository implementation checks `_demo.isActive` before any Supabase call:

```dart
// Pattern used across all repository implementations
Future<Result<T>> _demoOrRemote<T>(
    DemoPreset preset,
    T Function(DemoPreset) demoFn,
    Future<Result<T>> Function() remoteFn,
) async {
  if (_demo.isActive) return Success(demoFn(_demo.state));
  return remoteFn();
}
```

### 8.3 Demo Banner and Write Block

```dart
// lib/features/dashboard/presentation/widgets/demo_banner.dart
class DemoBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final isDemo = ref.watch(demoModeNotifierProvider.notifier).isActive;
    if (!isDemo) return const SizedBox.shrink();
    return Container(
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.orange),
        const SizedBox(width: 8),
        const Text('โหมดสาธิต — ข้อมูลไม่ถูกบันทึก',
            style: TextStyle(color: Colors.orange, fontSize: 14)),
        const Spacer(),
        // Preset switcher
        TextButton(
          onPressed: () => context.push('/demo-preset'),
          child: const Text('เปลี่ยนชุดข้อมูล'),
        ),
      ]),
    );
  }
}
```

### 8.4 Pre-seeded AI Responses in Demo Mode

```dart
// lib/features/ai_chat/data/repositories/chat_repository_impl.dart
@override
Future<Result<String>> sendMessage({...}) async {
  if (_demo.isActive) {
    await Future.delayed(const Duration(seconds: 1)); // simulate latency
    return Success(DemoFixtures.chatHistory[_demo.state]!
        .firstWhere((m) => m.role == ChatRole.assistant,
            orElse: () => _defaultDemoResponse).content);
  }
  // ... real API call
}
```

---

## 9. Offline / Cache Strategy

### 9.1 Cached Data Inventory

| Data | Storage Key | Max Entries | TTL | Encryption |
|---|---|---|---|---|
| Soil readings per farm | `soil_cache_{farmId}` | 10 | 24h | Yes |
| Latest fertilizer rec per plot | `fertilizer_rec_{plotId}` | 1 | 7d | Yes |
| Farm records | `farm_records_{farmId}` | 500 | 90d | Yes |
| Auth session token | `auth_session` | 1 | Until logout | Yes |
| User profile | `user_profile` | 1 | 24h | Yes |
| Market prices | `market_prices_{crop}` | 30 days | 24h | No |
| Notification list | `notifications` | 100 | 30d | No |
| Sync queue | `sync_queue` | Unlimited | Until synced | Yes |

All entries stored in `flutter_secure_storage` with AES-256 encryption backed by Android Keystore / iOS Secure Enclave.

### 9.2 flutter_secure_storage Key Constants

```dart
// lib/core/constants/storage_keys.dart
class StorageKeys {
  static const authSession       = 'auth_session';
  static const userProfile       = 'user_profile';
  static String soilCache(String farmId) => 'soil_cache_$farmId';
  static String fertilizerRec(String plotId) => 'fertilizer_rec_$plotId';
  static String farmRecords(String farmId) => 'farm_records_$farmId';
  static String marketPrices(String crop) => 'market_prices_$crop';
  static const notifications     = 'notifications';
  static const syncQueue         = 'sync_queue';
  static const cacheTimestamps   = 'cache_timestamps';
  static const consentTimestamp  = 'consent_timestamp';

  // Private constructor — static use only
  StorageKeys._();
}
```

### 9.3 Cache Read Strategy (Offline-First)

```dart
// Pattern for read operations:
// 1. Check connectivity
// 2. If online: fetch remote, update cache, return remote
// 3. If offline: return cached data (with age annotation)
// 4. If cache miss offline: return Failure(OfflineFailure)

Future<Result<List<FarmRecord>>> getRecords(String farmId) async {
  if (await _network.isConnected) {
    final result = await _fetchRemote(farmId);
    if (result is Success) {
      await _cacheRecords(farmId, result.data);
    }
    return result;
  } else {
    final cached = await _readCache(farmId);
    if (cached.isEmpty) return Failure(OfflineFailure());
    return Success(cached);
  }
}
```

### 9.4 Sync Queue (Write Operations Offline)

```dart
// lib/features/farm_record/data/datasources/record_local_datasource.dart

class SyncQueueItem {
  final String id;
  final String operation;  // 'create' | 'update' | 'delete'
  final String tableName;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  int retryCount;
}

// Sync execution on connectivity restore
class SyncService {
  static Future<void> syncAll(WidgetRef ref) async {
    final queue = await _loadQueue();
    for (final item in queue) {
      try {
        await _executeItem(item);
        await _removeFromQueue(item.id);
      } catch (e) {
        item.retryCount++;
        if (item.retryCount >= 3) {
          await _markFailed(item);
          ref.read(notificationRepositoryProvider)
              .showSyncErrorNotification(item);
        }
      }
    }
  }
}
```

### 9.5 Cache Invalidation

- **Explicit invalidation**: On successful write (create/update/delete), invalidate the relevant cache key.
- **TTL expiry**: On cache read, compare `cacheTimestamps[key]` with current time; if expired, treat as miss.
- **Logout**: `signOut()` clears ALL secure storage entries except `consentTimestamp`.

### 9.6 Offline Indicator

```dart
// Shown on every screen when offline
// Provided by StreamProvider watching connectivity
@riverpod
Stream<bool> isOnline(IsOnlineRef ref) =>
    Connectivity().onConnectivityChanged.map((result) =>
        result != ConnectivityResult.none);
```

---

## 10. IoT / MQTT Integration

### 10.1 Data Flow

```
ESP32 Device
  │
  │  1. Reads RS485 NPK sensor (N, P, K, moisture, temperature, pH)
  │  2. Formats JSON payload
  │  3. Publishes to MQTT topic: farm/{farm_id}/soil_telemetry
  │     (at configurable interval 5–60 min, max 1 msg / 5 min)
  │
  ▼
MQTT Broker (Mosquitto or EMQX)
  │  TLS/SSL connection
  │  Per-device client credentials
  │
  ▼
MQTT Bridge / Supabase Edge Function (IoT Ingestion Handler)
  │  Subscribed to: farm/+/soil_telemetry (wildcard)
  │
  ▼  POST /api/v1/iot/soil
Backend Function: IoT Ingestion
  │  1. Extract device_token from payload
  │  2. Validate device_token against devices table (HTTP 401 if invalid)
  │  3. Validate required fields: N, P, K, moisture, device_token
  │     (HTTP 400 with field name if missing)
  │  4. Resolve farm_id from device_token
  │  5. INSERT into soil_data
  │  6. Emit Supabase Realtime event on channel farm:{farm_id}
  │     (retry up to 3 times on failure; log and abandon after 3)
  │
  ▼
Supabase Realtime → Flutter App
  │  RealtimeChannel: farm:{farm_id}
  │  Event: postgres_changes INSERT on soil_data
  │
  ▼
SoilMonitoringNotifier.handleRealtimeEvent()
  │  Update gauge values, append to history
  │  Trigger cache update
  │  Trigger alert check (moisture < 20%, NPK below threshold)
  ▼
UI updates within 5 seconds of sensor reading
```

### 10.2 MQTT Payload Format

```json
{
  "device_token": "esp32-token-abc123",
  "farm_id": "uuid-of-farm",
  "timestamp": "2025-01-15T08:30:00Z",
  "nitrogen": 42.5,
  "phosphorus": 38.0,
  "potassium": 55.3,
  "moisture": 48.2,
  "temperature": 28.5,
  "ph": 6.4
}
```

### 10.3 ESP32 Offline Buffering

When MQTT broker is unreachable:
- Buffer up to 100 readings in ESP32 flash/SRAM (FIFO queue)
- On reconnection, transmit in chronological order at configured interval
- Each buffered message retains original timestamp

### 10.4 IoT Security

- Each device gets a unique `device_token` stored in Supabase `devices` table
- Token is provisioned server-side and flashed to ESP32 firmware at setup
- Token is never returned to Flutter client in any API response
- MQTT connection uses TLS + username/password (device_token as password)
- HTTP 401 on any invalid token; token not echoed in error response

### 10.5 Supabase `devices` Table

```sql
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE,
    device_token VARCHAR(255) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    last_seen TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS: only the backend service role can read devices
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON devices
    USING (auth.role() = 'service_role');
```

---

## 11. AI Integration

### 11.1 Architecture Constraint

**The Gemini API key is NEVER present in the Flutter bundle.** All Gemini calls are proxied through Backend Functions (Supabase Edge Functions or Cloud Functions). The Flutter app sends requests to `/api/v1/ai/*` endpoints authenticated with the user's Supabase JWT.

### 11.2 Fertilizer Recommendation — Request/Response Contract

**Request (Flutter → Backend):**
```json
POST /api/v1/ai/fertilizer-recommendation
Authorization: Bearer {supabase_jwt}
Content-Type: application/json

{
  "farm_id": "uuid",
  "plot_id": "uuid",
  "crop_type": "rice",
  "dap": 35,
  "soil_data": {
    "nitrogen": 20.0,
    "phosphorus": 45.0,
    "potassium": 50.0,
    "moisture": 55.0,
    "ph_level": 6.5
  }
}
```

**Gemini Prompt (constructed server-side):**
```
คุณเป็นผู้เชี่ยวชาญด้านการเกษตรไทย ให้คำแนะนำปุ๋ยสำหรับการปลูกข้าว

ข้อมูลดิน:
- ไนโตรเจน (N): 20 mg/kg (ต่ำ — ต่ำกว่าเกณฑ์ที่แนะนำ 30 mg/kg)
- ฟอสฟอรัส (P): 45 mg/kg (ปกติ)
- โพแทสเซียม (K): 50 mg/kg (ปกติ)
- ความชื้น: 55% (เหมาะสม)
- pH: 6.5 (เหมาะสม)

ระยะการปลูก: DAP 35 (ระยะแตกกอ)
ประเภทพืช: ข้าว

ตาม Decision Matrix สำหรับข้าว DAP 21–45, N ต่ำ: แนะนำปุ๋ยยูเรีย 46-0-0 อัตรา 15–20 กก./ไร่

ให้ผลลัพธ์เป็น JSON ในรูปแบบต่อไปนี้ (ตอบเป็นภาษาไทย):
{
  "products": [
    {
      "name_thai": "ชื่อปุ๋ยภาษาไทย",
      "name_common": "สูตรปุ๋ย",
      "rate_kg_per_rai": 0.0,
      "timing_thai": "ช่วงเวลาใส่ปุ๋ย"
    }
  ],
  "reasoning_thai": "เหตุผลอธิบายเป็นภาษาไทยเข้าใจง่าย ไม่เกิน 3 ประโยค",
  "nutrient_deficiencies": ["N"],
  "warnings_thai": []
}
```

**Response (Backend → Flutter):**
```json
{
  "id": "rec-uuid",
  "plot_id": "uuid",
  "crop_type": "rice",
  "dap": 35,
  "products": [
    {
      "name_thai": "ยูเรีย",
      "name_common": "46-0-0",
      "rate_kg_per_rai": 17.5,
      "timing_thai": "ใส่ระยะแตกกอ 21–45 วันหลังปลูก"
    }
  ],
  "reasoning_thai": "ดินมีไนโตรเจนต่ำในช่วงระยะแตกกอ การใส่ยูเรียจะช่วยเสริมการเจริญเติบโตของต้นข้าว ควรใส่ในช่วงเช้าหลังจากมีน้ำในแปลง",
  "estimated_cost_per_rai": 245.0,
  "generated_at": "2025-01-15T09:00:00Z"
}
```

### 11.3 AI Chat — Request/Response Contract

**Request:**
```json
POST /api/v1/ai/chat
Authorization: Bearer {supabase_jwt}
Content-Type: application/json

{
  "farm_id": "uuid",
  "message": "ข้าวของผมใบเหลือง ควรทำอย่างไร",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
    // max 20 turns
  ],
  "context": {
    "crop_type": "rice",
    "current_soil": { "n": 20, "p": 45, "k": 50, "moisture": 55 },
    "disease_seed": null   // optional: pre-seeded disease name
  }
}
```

**System Prompt (server-side):**
```
คุณคือผู้ช่วยเกษตรกรรม AI สำหรับเกษตรกรชาวไทย ชื่อ "ชาวนา AI"
ตอบคำถามเกี่ยวกับ: โภชนาการดิน, การใส่ปุ๋ย, โรคพืช, ตารางการปลูก,
การจัดการแมลงศัตรูพืช และการตลาดพืชผล
ตอบเป็นภาษาไทยเสมอ ใช้ภาษาเรียบง่าย เหมาะกับเกษตรกรทั่วไป
หากคำถามไม่เกี่ยวข้องกับการเกษตร ให้ตอบว่า:
"ขออภัย คำถามนี้อยู่นอกขอบเขตความเชี่ยวชาญของผม
กรุณาติดต่อเจ้าหน้าที่เกษตรตำบลในพื้นที่ของคุณ"
```

**Response:**
```json
{
  "response": "ใบข้าวเหลืองอาจเกิดจากหลายสาเหตุ...",
  "conversation_id": "uuid"
}
```

### 11.4 Disease Detection — Request/Response Contract

**Request:** `multipart/form-data`
```
POST /api/v1/ai/disease-detection
Authorization: Bearer {supabase_jwt}

Field: image (binary, JPEG/PNG, max 2MB after client compression)
Field: farm_id (string, UUID)
Field: crop_type (string)
```

**Response:**
```json
{
  "id": "uuid",
  "disease_name_thai": "โรคไหม้ข้าว",
  "disease_name_en": "Rice Blast",
  "confidence_score": 0.82,
  "treatment_steps_thai": [
    "หยุดการให้น้ำ 3–5 วัน",
    "ฉีดพ่นสารไตรฟลอกซีสโตรบิน",
    "ลดอัตราการใส่ไนโตรเจน",
    "ตรวจสอบแปลงใกล้เคียง",
    "ปรึกษาเจ้าหน้าที่เกษตร"
  ],
  "low_confidence_warning": false,
  "detected_at": "2025-01-15T09:00:00Z"
}
```

### 11.5 Market Sell Suggestion — Request/Response Contract

**Request:**
```json
POST /api/v1/ai/market-suggestion
Authorization: Bearer {supabase_jwt}

{
  "crop_type": "rice",
  "current_price_thb_per_kg": 12.50,
  "price_history_30d": [
    {"date": "2025-01-01", "price": 11.80},
    ...
  ]
}
```

**Response:**
```json
{
  "suggestion_thai": "ราคาข้าวมีแนวโน้มเพิ่มขึ้นในสัปดาห์นี้...",
  "recommendation": "hold",   // "sell" | "hold" | "watch"
  "generated_at": "2025-01-15T09:00:00Z"
}
```

---

## 12. Security Design

### 12.1 Authentication Flow

```
1. Register / Login
   Flutter → POST /auth/v1/signup or /auth/v1/token (Supabase Auth)
   Response: { access_token, refresh_token, user }
   Store in flutter_secure_storage (key: auth_session)

2. Authenticated API Calls
   Flutter sends: Authorization: Bearer {access_token}
   Supabase validates JWT → exposes auth.uid() in RLS

3. Token Refresh
   access_token lifetime: 1 hour
   refresh_token lifetime: 30 days
   Supabase SDK auto-refreshes on expiry
   On mid-operation expiry:
     - Discard the operation
     - Preserve form data in memory
     - Show Thai re-auth dialog
     - Resume after re-authentication

4. Sign Out
   Flutter calls signOut()
   Supabase invalidates refresh_token server-side
   Flutter clears all flutter_secure_storage keys
   Navigate to /login
```

### 12.2 RLS Policies (SQL)

```sql
-- ============================
-- farms table
-- ============================
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "farms_select_own" ON farms
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "farms_insert_own" ON farms
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "farms_update_own" ON farms
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "farms_delete_own" ON farms
    FOR DELETE USING (auth.uid() = user_id);

-- ============================
-- plots table (via farm ownership)
-- ============================
ALTER TABLE plots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plots_select_own" ON plots
    FOR SELECT USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "plots_insert_own" ON plots
    FOR INSERT WITH CHECK (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "plots_update_own" ON plots
    FOR UPDATE USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "plots_delete_own" ON plots
    FOR DELETE USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

-- ============================
-- soil_data table
-- ============================
ALTER TABLE soil_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "soil_data_select_own" ON soil_data
    FOR SELECT USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

-- INSERT only via service_role (Backend Function / IoT ingestion)
CREATE POLICY "soil_data_insert_service" ON soil_data
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ============================
-- crop_records table
-- ============================
ALTER TABLE crop_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crop_records_select_own" ON crop_records
    FOR SELECT USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "crop_records_insert_own" ON crop_records
    FOR INSERT WITH CHECK (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "crop_records_update_own" ON crop_records
    FOR UPDATE USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

CREATE POLICY "crop_records_delete_own" ON crop_records
    FOR DELETE USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

-- ============================
-- disease_records table
-- ============================
ALTER TABLE disease_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "disease_records_own" ON disease_records
    FOR ALL USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

-- ============================
-- ai_conversations table
-- ============================
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_conversations_own" ON ai_conversations
    FOR ALL USING (
        farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    );

-- ============================
-- market_prices table (public read)
-- ============================
ALTER TABLE market_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "market_prices_public_read" ON market_prices
    FOR SELECT USING (TRUE);

-- Only service_role can write market prices
CREATE POLICY "market_prices_service_write" ON market_prices
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
```

### 12.3 Supabase Storage Security

```
Bucket: farm-images (private)
  Path pattern: {user_id}/{farm_id}/{record_id}/{filename}

RLS Policy (Storage):
  SELECT: auth.uid()::text = (storage.foldername(name))[1]
  INSERT: auth.uid()::text = (storage.foldername(name))[1]
  DELETE: auth.uid()::text = (storage.foldername(name))[1]
```

### 12.4 HTTPS Enforcement (Flutter)

```dart
// lib/core/network/api_client.dart
// All Supabase URLs start with https:// — enforced by SDK
// For any custom HTTP calls:
class ApiClient {
  static void validateUrl(String url) {
    final uri = Uri.parse(url);
    assert(uri.scheme == 'https',
        'Unencrypted HTTP requests are forbidden. URL: $url');
  }
}
```

### 12.5 Privacy Consent

```dart
// On registration — consent must be given before account creation
// Timestamp stored in Supabase user metadata + local secure storage
// Flutter: unchecked checkbox (opt-in required, not pre-checked)
await _client.auth.signUp(
  email: email,
  password: password,
  data: {'consent_given_at': DateTime.now().toIso8601String()},
);
```

---

## 13. Database Design

### 13.1 Final Schema with All Tables

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================
-- farms
-- ============================
CREATE TABLE farms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL CHECK (char_length(name) BETWEEN 1 AND 255),
    location TEXT,
    area_rai FLOAT NOT NULL CHECK (area_rai > 0 AND area_rai <= 10000),
    crop_type VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- plots (sub-areas within farms)
-- ============================
CREATE TABLE plots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL CHECK (char_length(name) BETWEEN 1 AND 255),
    area_rai FLOAT NOT NULL CHECK (area_rai > 0 AND area_rai <= 10000),
    crop_type VARCHAR(100) NOT NULL,
    sensor_device_token VARCHAR(255),   -- FK to devices.device_token (nullable)
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- devices (IoT sensors)
-- ============================
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    device_token VARCHAR(255) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    last_seen TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- soil_data
-- ============================
CREATE TABLE soil_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    moisture FLOAT NOT NULL CHECK (moisture >= 0 AND moisture <= 100),
    nitrogen FLOAT NOT NULL CHECK (nitrogen >= 0),
    phosphorus FLOAT NOT NULL CHECK (phosphorus >= 0),
    potassium FLOAT NOT NULL CHECK (potassium >= 0),
    ph_level FLOAT DEFAULT 6.5 CHECK (ph_level >= 0 AND ph_level <= 14),
    temperature FLOAT,
    is_demo_data BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- crop_records (Farm Ledger)
-- ============================
CREATE TABLE crop_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    plot_id UUID REFERENCES plots(id) ON DELETE SET NULL,
    record_type VARCHAR(50) NOT NULL
        CHECK (record_type IN ('planting','fertilizing','expense','harvest','disease')),
    title TEXT NOT NULL,
    amount NUMERIC(10, 2),               -- kg (fertilizer) or THB (expense)
    cost NUMERIC(10, 2),                 -- THB
    quantity_kg NUMERIC(10, 2),          -- harvest: kg produced
    selling_price_thb_per_kg NUMERIC(10, 4),  -- harvest: price per kg
    record_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    image_url TEXT,                      -- Supabase Storage URL
    is_synced BOOLEAN DEFAULT TRUE,      -- false = pending offline sync
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- disease_records
-- ============================
CREATE TABLE disease_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    plot_id UUID REFERENCES plots(id) ON DELETE SET NULL,
    image_url TEXT NOT NULL,
    disease_name_thai VARCHAR(255) NOT NULL,
    disease_name_en VARCHAR(255),
    confidence_score FLOAT NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 1),
    treatment_steps_thai JSONB,          -- array of strings
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- market_prices
-- ============================
CREATE TABLE market_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crop_name VARCHAR(100) NOT NULL,
    price_thb_per_kg NUMERIC(10, 4) NOT NULL CHECK (price_thb_per_kg > 0),
    change_percent NUMERIC(6, 2),        -- day-over-day %
    price_date DATE NOT NULL DEFAULT CURRENT_DATE,
    source VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(crop_name, price_date)
);

-- ============================
-- price_alerts (user-defined thresholds)
-- ============================
CREATE TABLE price_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    crop_name VARCHAR(100) NOT NULL,
    threshold_thb_per_kg NUMERIC(10, 4) NOT NULL,
    alert_above BOOLEAN NOT NULL,        -- true = alert when price > threshold
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, crop_name)
);

-- ============================
-- ai_conversations
-- ============================
CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
    message TEXT NOT NULL,
    response TEXT NOT NULL,
    context_json JSONB,                  -- disease seed, soil snapshot
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- notification_log
-- ============================
CREATE TABLE notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    notification_type VARCHAR(50) NOT NULL
        CHECK (notification_type IN ('soil_alert','market_alert','ai_summary','system')),
    title_thai TEXT NOT NULL,
    body_thai TEXT NOT NULL,
    target_route TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 13.2 Indexes

```sql
-- Performance indexes
CREATE INDEX idx_soil_data_farm_created  ON soil_data(farm_id, created_at DESC);
CREATE INDEX idx_soil_data_device        ON soil_data(device_id, created_at DESC);
CREATE INDEX idx_crop_records_farm       ON crop_records(farm_id, record_date DESC);
CREATE INDEX idx_crop_records_plot       ON crop_records(plot_id, record_date DESC);
CREATE INDEX idx_crop_records_type       ON crop_records(farm_id, record_type);
CREATE INDEX idx_plots_farm              ON plots(farm_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_disease_records_farm    ON disease_records(farm_id, created_at DESC);
CREATE INDEX idx_market_prices_crop_date ON market_prices(crop_name, price_date DESC);
CREATE INDEX idx_price_alerts_user       ON price_alerts(user_id);
CREATE INDEX idx_notifications_user      ON notification_log(user_id, created_at DESC);
CREATE INDEX idx_ai_conversations_farm   ON ai_conversations(farm_id, created_at DESC);
```

### 13.3 Triggers

```sql
-- Auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER farms_updated_at
    BEFORE UPDATE ON farms FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER plots_updated_at
    BEFORE UPDATE ON plots FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER crop_records_updated_at
    BEFORE UPDATE ON crop_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### 13.4 Migration Notes

- All UUIDs use `uuid_generate_v4()` (requires `uuid-ossp` extension).
- `plots` table is an extension of the original schema — the original `farms` table had crop_type and area; these remain but plots provide finer granularity.
- `soil_data.farm_id` references farm (not plot) to match the IoT topic pattern `farm/{farm_id}/soil_telemetry`.
- If per-plot soil readings are needed in future, add `plot_id` column as a nullable FK to plots.
- `crop_records.is_synced` enables offline-first sync without a separate sync table.
- Market prices use `UNIQUE(crop_name, price_date)` to prevent duplicate daily entries.

---

## 14. API Contract

All API endpoints require `Authorization: Bearer {supabase_jwt}` unless noted.  
Base URL: `https://{project}.supabase.co/functions/v1`  
Content-Type: `application/json` (unless multipart noted)

---

### 14.1 Farm Endpoints

#### GET /api/v1/farms/{farm_id}
```
Response 200:
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "แปลงนาใหญ่",
  "location": "จ.พระนครศรีอยุธยา",
  "area_rai": 15.5,
  "crop_type": "rice",
  "created_at": "2025-01-01T00:00:00Z",
  "plots": [
    {
      "id": "uuid",
      "name": "แปลงย่อย A",
      "area_rai": 5.0,
      "crop_type": "rice",
      "sensor_device_token": null,
      "is_deleted": false
    }
  ]
}

Response 404: { "error": "ไม่พบข้อมูลฟาร์ม" }
Response 403: { "error": "ไม่มีสิทธิ์เข้าถึงข้อมูลนี้" }
```

#### POST /api/v1/farms
```
Request:
{
  "name": "ฟาร์มใหม่",
  "location": "จ.สุพรรณบุรี",
  "area_rai": 20.0,
  "crop_type": "rice"
}

Response 201: { farm object }
Response 400: { "error": "validation message", "field": "area_rai" }
```

---

### 14.2 Soil Endpoints

#### GET /api/v1/farms/{farm_id}/soil/latest
```
Response 200:
{
  "id": "uuid",
  "farm_id": "uuid",
  "moisture": 48.2,
  "nitrogen": 42.5,
  "phosphorus": 38.0,
  "potassium": 55.3,
  "ph_level": 6.4,
  "temperature": 28.5,
  "is_demo_data": false,
  "created_at": "2025-01-15T08:30:00Z"
}

Response 204: (no data yet — empty body)
```

#### GET /api/v1/farms/{farm_id}/soil/history?period=7days
```
Query params: period = 7days | 30days | 90days
Response 200:
{
  "data": [
    { soil_data object },
    ...
  ],
  "count": 42
}
```

---

### 14.3 AI Endpoints

#### POST /api/v1/ai/fertilizer-recommendation
```
Request: (see §11.2)
Response 200: (see §11.2)
Response 400: { "error": "ข้อมูลดินไม่ครบถ้วน", "missing_fields": ["nitrogen"] }
Response 408: { "error": "ไม่สามารถสร้างคำแนะนำได้ในขณะนี้ กรุณาลองใหม่" }
Response 500: { "error": "เกิดข้อผิดพลาดในระบบ AI กรุณาลองอีกครั้ง" }
```

#### POST /api/v1/ai/chat
```
Request: (see §11.3)
Response 200: (see §11.3)
Response 408: { "error": "ระบบไม่ตอบสนอง กรุณาลองใหม่", "preserve_message": true }
```

#### POST /api/v1/ai/disease-detection
```
Content-Type: multipart/form-data
Request: image (binary), farm_id, crop_type
Response 200: (see §11.4)
Response 400: { "error": "ไม่สามารถวิเคราะห์ภาพได้ กรุณาถ่ายภาพใหม่" }
Response 408: { "error": "การวิเคราะห์ใช้เวลานานเกินไป กรุณาลองอีกครั้ง" }
```

#### POST /api/v1/ai/market-suggestion
```
Request: (see §11.5)
Response 200: (see §11.5)
Response 500: { "error": "ไม่สามารถสร้างคำแนะนำได้ในขณะนี้" }
```

---

### 14.4 Market Endpoint

#### GET /api/v1/market/{crop}
```
Path param: crop = rice | maize | cassava | sugarcane
Query: days=30 (optional, default 30, max 90)

Response 200:
{
  "crop_name": "rice",
  "current_price_thb_per_kg": 12.50,
  "current_price_thb_per_tonne": 12500.00,
  "change_percent": 2.3,
  "last_updated": "2025-01-15T06:00:00Z",
  "history": [
    { "date": "2025-01-14", "price_thb_per_kg": 12.22 },
    ...
  ]
}

Response 503: { "error": "ข้อมูลราคาตลาดไม่พร้อมใช้งานในขณะนี้" }
```

---

### 14.5 IoT Ingestion Endpoint

#### POST /api/v1/iot/soil
```
Auth: Device-Token header (NOT Bearer JWT)

Request:
{
  "device_token": "esp32-token-abc123",
  "farm_id": "uuid",
  "timestamp": "2025-01-15T08:30:00Z",
  "nitrogen": 42.5,
  "phosphorus": 38.0,
  "potassium": 55.3,
  "moisture": 48.2,
  "temperature": 28.5,
  "ph": 6.4
}

Response 201: { "id": "uuid", "created_at": "..." }
Response 400: { "error": "ข้อมูลไม่ครบถ้วน", "missing_fields": ["moisture"] }
Response 401: { "error": "Unauthorized" }
                (device_token NOT echoed in response)
```

---

### 14.6 Farm Record Endpoints

#### GET /api/v1/farms/{farm_id}/records
```
Query: type=planting|fertilizing|expense|harvest|disease
       plot_id=uuid
       from=2025-01-01&to=2025-01-31

Response 200:
{
  "records": [ { farm_record objects } ],
  "summary": {
    "total_expense_thb": 4500.00,
    "total_harvest_income_thb": 28000.00
  }
}
```

#### POST /api/v1/farms/{farm_id}/records
```
Request: { farm_record fields }
Response 201: { created farm_record }
Response 400: { "error": "กรุณากรอกข้อมูลที่จำเป็น", "missing_fields": ["title"] }
```

#### DELETE /api/v1/farms/{farm_id}/records/{record_id}
```
Response 204: (no body)
Response 404: { "error": "ไม่พบรายการบันทึก" }
```

#### GET /api/v1/farms/{farm_id}/records/export-pdf
```
Query: from=2025-01-01&to=2025-12-31
Response 200: Content-Type: application/pdf (binary PDF)
Response 400: { "error": "ช่วงวันที่ไม่ถูกต้อง" }
```

---

## 15. Error Handling Strategy

### 15.1 Failure Type Hierarchy

```dart
// lib/core/error/failures.dart

sealed class AppFailure {
  final String messageEn;
  final String messageThai;
  const AppFailure({required this.messageEn, required this.messageThai});
}

// Network failures
class NetworkFailure extends AppFailure {
  const NetworkFailure() : super(
    messageEn: 'No internet connection',
    messageThai: 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',
  );
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure() : super(
    messageEn: 'Request timed out',
    messageThai: 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่',
  );
}

// Auth failures
class AuthFailure extends AppFailure {
  const AuthFailure.invalidCredentials() : super(
    messageEn: 'Invalid credentials',
    messageThai: 'อีเมล/เบอร์โทร หรือรหัสผ่านไม่ถูกต้อง',
  );
  const AuthFailure.identifierAlreadyExists() : super(
    messageEn: 'Identifier already registered',
    messageThai: 'อีเมลหรือเบอร์โทรศัพท์นี้ถูกใช้งานแล้ว',
  );
  const AuthFailure.weakPassword() : super(
    messageEn: 'Password too weak',
    messageThai: 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษรและมีตัวเลขอย่างน้อย 1 ตัว',
  );
  const AuthFailure.sessionExpired() : super(
    messageEn: 'Session expired',
    messageThai: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
  );
}

// Database failures
class DatabaseFailure extends AppFailure {
  final String? detail;
  const DatabaseFailure(this.detail) : super(
    messageEn: 'Database error',
    messageThai: 'เกิดข้อผิดพลาดในการบันทึกข้อมูล กรุณาลองใหม่',
  );
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure() : super(
    messageEn: 'Resource not found',
    messageThai: 'ไม่พบข้อมูลที่ต้องการ',
  );
}

// AI/Backend failures
class AiRecommendationFailure extends AppFailure {
  const AiRecommendationFailure() : super(
    messageEn: 'Could not generate recommendation',
    messageThai: 'ไม่สามารถสร้างคำแนะนำได้ในขณะนี้ กรุณาลองใหม่',
  );
}

class AiChatFailure extends AppFailure {
  const AiChatFailure() : super(
    messageEn: 'AI assistant did not respond',
    messageThai: 'ผู้ช่วย AI ไม่ตอบสนอง กรุณาลองส่งข้อความอีกครั้ง',
  );
}

class DiseaseDetectionFailure extends AppFailure {
  const DiseaseDetectionFailure() : super(
    messageEn: 'Could not analyse image',
    messageThai: 'ไม่สามารถวิเคราะห์ภาพได้ กรุณาถ่ายภาพใหม่ในที่ที่มีแสงสว่างเพียงพอ',
  );
}

// Offline/Sync failures
class OfflineFailure extends AppFailure {
  const OfflineFailure() : super(
    messageEn: 'Device is offline',
    messageThai: 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ฟีเจอร์นี้ต้องการเครือข่าย',
  );
}

class SyncFailure extends AppFailure {
  const SyncFailure() : super(
    messageEn: 'Sync failed',
    messageThai: 'ไม่สามารถซิงค์ข้อมูลได้ ข้อมูลจะถูกส่งเมื่อมีการเชื่อมต่ออีกครั้ง',
  );
}

// Validation failures
class ValidationFailure extends AppFailure {
  final String field;
  const ValidationFailure.required(this.field) : super(
    messageEn: 'Required field missing',
    messageThai: 'กรุณากรอกข้อมูล',
  );
  const ValidationFailure.areaOutOfRange(this.field) : super(
    messageEn: 'Area must be between 0 and 10,000 rai',
    messageThai: 'ขนาดพื้นที่ต้องอยู่ระหว่าง 0 ถึง 10,000 ไร่',
  );
}

// IoT failures
class SensorNotFoundFailure extends AppFailure {
  const SensorNotFoundFailure() : super(
    messageEn: 'Sensor device token not found',
    messageThai: 'ไม่พบอุปกรณ์เซนเซอร์ กรุณาตรวจสอบรหัสอุปกรณ์',
  );
}

class SensorOfflineFailure extends AppFailure {
  const SensorOfflineFailure() : super(
    messageEn: 'Sensor has not sent data in 24h',
    messageThai: 'เซนเซอร์ไม่ได้ส่งข้อมูลในช่วง 24 ชั่วโมงที่ผ่านมา',
  );
}

// Demo mode
class DemoWriteBlockedFailure extends AppFailure {
  const DemoWriteBlockedFailure() : super(
    messageEn: 'Write operations are disabled in Demo Mode',
    messageThai: 'ฟีเจอร์นี้ไม่พร้อมใช้งานในโหมดสาธิต กรุณาสมัครสมาชิก',
  );
}

// Catch-all
class UnexpectedFailure extends AppFailure {
  final String? detail;
  const UnexpectedFailure([this.detail]) : super(
    messageEn: 'Unexpected error',
    messageThai: 'เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ',
  );
}
```

### 15.2 Thai Error Messages Per Scenario

| Scenario | Thai Error Message |
|---|---|
| No internet | ไม่มีการเชื่อมต่ออินเทอร์เน็ต |
| Login: wrong credentials | อีเมล/เบอร์โทร หรือรหัสผ่านไม่ถูกต้อง |
| Register: identifier taken | อีเมลหรือเบอร์โทรศัพท์นี้ถูกใช้งานแล้ว |
| Register: weak password | รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษรและมีตัวเลขอย่างน้อย 1 ตัว |
| Session expired | เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่ |
| Save farm: area = 0 | ขนาดพื้นที่ต้องมากกว่า 0 ไร่ |
| Save farm: area > 10,000 | ขนาดพื้นที่ต้องไม่เกิน 10,000 ไร่ |
| Save farm: name missing | กรุณากรอกชื่อฟาร์ม |
| Save plot: crop type missing | กรุณาเลือกประเภทพืช |
| Sensor token not found | ไม่พบอุปกรณ์เซนเซอร์ กรุณาตรวจสอบรหัสอุปกรณ์ |
| Sensor offline (24h) | เซนเซอร์ไม่ได้ส่งข้อมูลในช่วง 24 ชั่วโมงที่ผ่านมา |
| Moisture alert (< 20%) | ⚠️ ความชื้นในดินต่ำมาก ({value}%) กรุณาให้น้ำ |
| N deficiency alert | ⚠️ ไนโตรเจน (N) ในดินต่ำกว่าเกณฑ์ ควรพิจารณาใส่ปุ๋ย |
| P deficiency alert | ⚠️ ฟอสฟอรัส (P) ในดินต่ำกว่าเกณฑ์ ควรพิจารณาใส่ปุ๋ย |
| K deficiency alert | ⚠️ โพแทสเซียม (K) ในดินต่ำกว่าเกณฑ์ ควรพิจารณาใส่ปุ๋ย |
| AI recommendation timeout | ไม่สามารถสร้างคำแนะนำได้ในขณะนี้ กรุณาลองใหม่ |
| AI recommendation error | เกิดข้อผิดพลาดในระบบ AI กรุณาลองอีกครั้ง |
| Stale soil data | ข้อมูลเซนเซอร์อาจไม่เป็นปัจจุบัน (อายุมากกว่า 24 ชั่วโมง) ต้องการดำเนินการต่อหรือไม่? |
| AI chat timeout | ผู้ช่วย AI ไม่ตอบสนอง กรุณาลองส่งข้อความอีกครั้ง |
| AI chat out-of-scope | ขออภัย คำถามนี้อยู่นอกขอบเขตความเชี่ยวชาญของผม กรุณาติดต่อเจ้าหน้าที่เกษตรตำบลในพื้นที่ของคุณ |
| Disease detection timeout | การวิเคราะห์ใช้เวลานานเกินไป กรุณาลองอีกครั้ง |
| Disease detection: unreadable | ไม่สามารถวิเคราะห์ภาพได้ กรุณาถ่ายภาพใหม่ในที่ที่มีแสงสว่างเพียงพอ |
| Disease: low confidence | ผลการวิเคราะห์ไม่แน่ชัด (ความมั่นใจ {n}%) แนะนำให้ปรึกษาเจ้าหน้าที่เกษตร |
| Record: required field | กรุณากรอก{fieldName} |
| Record: image too large | ไฟล์รูปภาพต้องมีขนาดไม่เกิน 5 MB |
| Offline banner | 📵 ไม่มีการเชื่อมต่ออินเทอร์เน็ต ข้อมูลที่แสดงอาจไม่เป็นปัจจุบัน |
| Offline feature disabled | ฟีเจอร์นี้ต้องการการเชื่อมต่ออินเทอร์เน็ต |
| Sync failed | ไม่สามารถซิงค์ข้อมูลได้ ข้อมูลจะถูกส่งเมื่อมีการเชื่อมต่ออีกครั้ง |
| Market data stale (3+ days) | ข้อมูลราคาตลาดไม่ได้รับการอัปเดตมากกว่า 3 วัน |
| Market data unavailable | ข้อมูลราคาตลาดไม่พร้อมใช้งานในขณะนี้ |
| Voice input unsupported | อุปกรณ์ของคุณไม่รองรับการป้อนข้อมูลด้วยเสียง กรุณาพิมพ์ข้อความแทน |
| Delete plot: confirm | ต้องการลบแปลง "{plotName}" ใช่หรือไม่? การลบจะไม่สามารถกู้คืนได้ |
| Delete record: confirm | ต้องการลบรายการบันทึกนี้ใช่หรือไม่? |
| New conversation: confirm | ต้องการเริ่มบทสนทนาใหม่ใช่หรือไม่? ประวัติการสนทนาจะถูกล้าง |
| Demo: write blocked | ฟีเจอร์นี้ไม่พร้อมใช้งานในโหมดสาธิต กรุณาสมัครสมาชิกเพื่อใช้งาน |
| Demo preset load failed | ไม่สามารถโหลดชุดข้อมูลสาธิตได้ กรุณาลองใหม่ |
| Weather unavailable | ไม่สามารถดึงข้อมูลสภาพอากาศได้ในขณะนี้ |
| Notification target missing | ไม่พบหน้าที่เกี่ยวข้อง |
| Chart range too wide | ช่วงวันที่สูงสุดที่รองรับคือ 90 วัน |
| Message too long | ข้อความเกิน 1,000 ตัวอักษร |
| PDF export error | ไม่สามารถสร้างไฟล์ PDF ได้ กรุณาลองใหม่ |
| Generic server error | เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ |

### 15.3 Error Display Pattern in UI

```dart
// lib/shared/widgets/error_display.dart
class ErrorDisplay extends StatelessWidget {
  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext ctx) {
    return Column(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 48),
      const SizedBox(height: 8),
      Text(failure.messageThai,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16)),
      if (onRetry != null) ...[
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
      ],
    ]);
  }
}
```

### 15.4 Global Error Boundary (Riverpod)

```dart
// In app.dart — catch unhandled AsyncValue errors
ProviderScope(
  observers: [AppProviderObserver()],
  child: ...
);

class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? prev,
      Object? next, ProviderContainer container) {
    if (next is AsyncError) {
      // Log to crash reporter (non-PII fields only)
      debugPrint('[ProviderError] ${provider.name}: ${next.error}');
    }
  }
}
```

---

## Appendix A: Design System Reference

| Token | Value | Usage |
|---|---|---|
| Primary color | `#10B981` (Mint Green) | Action buttons, positive indicators, score = Good |
| Secondary color | `#78350F` (Dark Brown) | Headers, secondary text |
| Warning color | `#F59E0B` (Amber) | Score = Moderate, warnings |
| Error color | `#EF4444` (Red) | Score = Poor, errors, critical alerts |
| Background | `#F9FAFB` | App background |
| Surface | `#FFFFFF` | Cards |
| Body text size | `16sp` minimum | All body text |
| Numeric display | `24sp` bold | NPK values, scores, prices |
| Touch target | `48×48dp` minimum | All interactive elements |
| Bottom nav tabs | 5 (Home, Farm, AI, Market, More) | Main navigation |

## Appendix B: Package Versions (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.0
  supabase_flutter: ^2.5.0
  fl_chart: ^0.68.0
  flutter_secure_storage: ^9.2.2
  pdf: ^3.11.1
  firebase_messaging: ^15.1.3
  speech_to_text: ^6.6.2
  connectivity_plus: ^6.0.3
  image_picker: ^1.1.2
  image_cropper: ^8.0.2
  uuid: ^4.4.0
  intl: ^0.19.0
  cached_network_image: ^3.4.1
  image: ^4.2.0     # for client-side image compression
  path_provider: ^2.1.3
  share_plus: ^9.0.0

dev_dependencies:
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

## Appendix C: Demo Preset Summary

| Preset | Name (Thai) | Moisture | N | P | K | Expected Behaviours |
|---|---|---|---|---|---|---|
| A | ภัยแล้ง / ไนโตรเจนต่ำ | 18% | 15 | 35 | 45 | Drought warning + Urea recommendation + Score = Poor |
| B | สภาพดินสมบูรณ์ | 55% | 50 | 45 | 55 | All gauges green + Score = Good |
| C | ความชื้นสูง / เสี่ยงโรคพืช | 85% | 40 | 30 | 35 | High humidity alert + Leaf blast disease shown |
