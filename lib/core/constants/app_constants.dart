/// Central constants for the ชาวนา app.
class AppConstants {
  AppConstants._();

  // Supabase — replace with real project credentials
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  // Backend function base URL (Supabase Edge Functions)
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://your-project.supabase.co/functions/v1',
  );

  // Google Gemini API Key
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // MQTT — Arduino UNO R4 soil sensor
  static const mqttBroker = 'broker.emqx.io';
  static const mqttPort = 1883;
  static const mqttTopic = 'farm/uno_r4/sensors';
  static const mqttClientId = 'chaona_flutter_app';

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
