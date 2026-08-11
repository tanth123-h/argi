/// flutter_secure_storage key constants.
class StorageKeys {
  StorageKeys._();

  static const authSession = 'auth_session';
  static const userProfile = 'user_profile';
  static const consentTimestamp = 'consent_timestamp';
  static const syncQueue = 'sync_queue';
  static const cacheTimestamps = 'cache_timestamps';
  static const notifications = 'notifications';

  static String soilCache(String farmId) => 'soil_cache_$farmId';
  static String fertilizerRec(String plotId) => 'fertilizer_rec_$plotId';
  static String farmRecords(String farmId) => 'farm_records_$farmId';
  static String marketPrices(String crop) => 'market_prices_$crop';
}
