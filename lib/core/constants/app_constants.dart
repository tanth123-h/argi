/// Central constants for the ชาวนา app.
class AppConstants {
  AppConstants._();

  // Shared Grow a Garden backend. The anon key is a public client key; access
  // to farm data is enforced by Supabase Row Level Security.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xkuhehyjvyxpnfjmpkyg.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhrdWhlaHlqdnl4cG5mam1wa3lnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MTkzMDMsImV4cCI6MjEwMTk5NTMwM30.73QMjpI1yz65dUTsbwP-iVsjUDXue7XBYxTwhiuJxf4',
  );

  // Backend function base URL (Supabase Edge Functions)
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://xkuhehyjvyxpnfjmpkyg.supabase.co/functions/v1',
  );

  // Google Gemini API Key
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // MQTT — ESP32 stationary soil sensor
  static const mqttBroker = 'broker.emqx.io';
  static const mqttPort = 1883;
  static const mqttTopic = 'farm/esp32/sensors';
  static const mqttClientId = 'chaona_flutter_app';
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.6-flash',
  );

  // Timeouts
  static const aiRequestTimeoutSeconds = 30;
  static const diseaseDetectionTimeoutSeconds = 20;
  static const defaultTimeoutSeconds = 15;

  // Cache limits
  static const maxSoilCachePerFarm = 10;
  static const maxFarmRecordsCache = 500;
  static const maxNotificationsCache = 100;
  static const farmRecordsCacheDays = 90;

  // Chat history
  static const maxChatHistoryTurns = 20;
  static const chatMessageMaxChars = 1000;
  static const chatMessageCounterThreshold = 800;

  // Image limits
  static const imageMaxUploadBytes = 2 * 1024 * 1024;
  static const imageMaxInputBytes = 10 * 1024 * 1024;
  static const recordPhotoMaxBytes = 5 * 1024 * 1024;

  // Soil thresholds
  static const moistureOptimalMin = 30.0;
  static const moistureOptimalMax = 70.0;
  static const moistureWarningThreshold = 20.0;
  static const npkLowThreshold = 30.0;
  static const npkHighThreshold = 70.0;
  static const soilScoreGoodMin = 70.0;
  static const soilScoreModerateMin = 40.0;

  // Market
  static const marketRefreshHours = 24;
  static const marketPriceHistoryDays = 30;
  static const marketStaleDays = 3;
  static const notificationSuppressionHours = 24;
}
