import 'package:shared_preferences/shared_preferences.dart';

/// Centralized SharedPreferences service for managing app preferences
class SharedPreferencesService {
  static SharedPreferencesService? _instance;
  static SharedPreferences? _preferences;

  // Private constructor
  SharedPreferencesService._();

  // Singleton instance
  static Future<SharedPreferencesService> getInstance() async {
    _instance ??= SharedPreferencesService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Keys
  static const String _keyIsPremiumUser = 'is_premium_user';
  static const String _keyTempPremiumExpiry = 'temp_premium_expiry';
  static const String _keyVolumeButtonClickCount = 'volume_button_click_count';
  static const String _keyAudioUploadCount = 'audio_upload_count';

  // ============ Premium Status Methods ============

  /// Check if user has permanent premium
  Future<bool> isPermanentPremium() async {
    return _preferences?.getBool(_keyIsPremiumUser) ?? false;
  }

  /// Set permanent premium status
  Future<void> setPermanentPremium(bool isPremium) async {
    await _preferences?.setBool(_keyIsPremiumUser, isPremium);
    print('💾 Permanent premium status saved: ${isPremium ? "Premium" : "Free"}');
  }

  /// Check if user has temporary premium (not expired)
  Future<bool> hasTemporaryPremium() async {
    final expiryString = _preferences?.getString(_keyTempPremiumExpiry);

    if (expiryString != null) {
      final expiryTime = DateTime.parse(expiryString);
      final now = DateTime.now();

      if (now.isBefore(expiryTime)) {
        return true;
      } else {
        // Expired, clear it
        await clearTemporaryPremium();
        return false;
      }
    }

    return false;
  }

  /// Get temporary premium expiry time
  Future<DateTime?> getTemporaryPremiumExpiry() async {
    final expiryString = _preferences?.getString(_keyTempPremiumExpiry);

    if (expiryString != null) {
      return DateTime.parse(expiryString);
    }

    return null;
  }

  /// Set temporary premium with expiry time
  Future<void> setTemporaryPremium(Duration duration) async {
    final expiryTime = DateTime.now().add(duration);
    await _preferences?.setString(_keyTempPremiumExpiry, expiryTime.toIso8601String());
    print('💎 Temporary premium set until: ${expiryTime.toLocal()}');
  }

  /// Clear temporary premium
  Future<void> clearTemporaryPremium() async {
    await _preferences?.remove(_keyTempPremiumExpiry);
    print('🗑️ Temporary premium cleared');
  }

  /// Check if user is premium (permanent OR temporary)
  Future<bool> isPremiumUser() async {
    final isPermanent = await isPermanentPremium();
    if (isPermanent) return true;

    return await hasTemporaryPremium();
  }

  /// Get remaining time for temporary premium
  Future<Duration?> getRemainingPremiumTime() async {
    final expiry = await getTemporaryPremiumExpiry();

    if (expiry != null) {
      final remaining = expiry.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    }

    return null;
  }

  // ============ Ad Counter Methods ============

  /// Get volume button click count
  Future<int> getVolumeButtonClickCount() async {
    return _preferences?.getInt(_keyVolumeButtonClickCount) ?? 0;
  }

  /// Increment volume button click count
  Future<int> incrementVolumeButtonClickCount() async {
    final currentCount = await getVolumeButtonClickCount();
    final newCount = currentCount + 1;
    await _preferences?.setInt(_keyVolumeButtonClickCount, newCount);
    print('📊 Volume button click count: $newCount');
    return newCount;
  }

  /// Reset volume button click count
  Future<void> resetVolumeButtonClickCount() async {
    await _preferences?.setInt(_keyVolumeButtonClickCount, 0);
    print('🔄 Volume button click count reset');
  }

  /// Get audio upload count
  Future<int> getAudioUploadCount() async {
    return _preferences?.getInt(_keyAudioUploadCount) ?? 0;
  }

  /// Increment audio upload count
  Future<int> incrementAudioUploadCount() async {
    final currentCount = await getAudioUploadCount();
    final newCount = currentCount + 1;
    await _preferences?.setInt(_keyAudioUploadCount, newCount);
    print('📊 Audio upload count: $newCount');
    return newCount;
  }

  /// Reset audio upload count
  Future<void> resetAudioUploadCount() async {
    await _preferences?.setInt(_keyAudioUploadCount, 0);
    print('🔄 Audio upload count reset');
  }

  /// Reset all ad counters
  Future<void> resetAllAdCounters() async {
    await resetVolumeButtonClickCount();
    await resetAudioUploadCount();
    print('🔄 All ad counters reset');
  }

  // ============ Export Counter Methods ============

  static const String _keyDailyExportCount = 'daily_export_count';
  static const String _keyLastExportDate = 'last_export_date';

  /// Get daily export count (resets each day)
  Future<int> getDailyExportCount() async {
    final lastDate = _preferences?.getString(_keyLastExportDate);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDate != today) {
      // New day - reset counter
      await _preferences?.setInt(_keyDailyExportCount, 0);
      await _preferences?.setString(_keyLastExportDate, today);
      return 0;
    }
    return _preferences?.getInt(_keyDailyExportCount) ?? 0;
  }

  /// Increment daily export count
  Future<int> incrementDailyExportCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = _preferences?.getString(_keyLastExportDate);

    int currentCount = 0;
    if (lastDate == today) {
      currentCount = _preferences?.getInt(_keyDailyExportCount) ?? 0;
    } else {
      await _preferences?.setString(_keyLastExportDate, today);
    }

    final newCount = currentCount + 1;
    await _preferences?.setInt(_keyDailyExportCount, newCount);
    print('📊 Daily export count: $newCount');
    return newCount;
  }

  /// Check if user can export (free users limited to 3/day)
  Future<bool> canExport({bool isPremium = false}) async {
    if (isPremium) return true;
    final count = await getDailyExportCount();
    return count < 3;
  }

  // ============ Utility Methods ============

  /// Clear all app preferences (for testing/logout)
  Future<void> clearAll() async {
    await _preferences?.clear();
    print('🗑️ All preferences cleared');
  }

  /// Clear all premium data only
  Future<void> clearAllPremiumData() async {
    await _preferences?.remove(_keyIsPremiumUser);
    await _preferences?.remove(_keyTempPremiumExpiry);
    print('🗑️ All premium data cleared');
  }

  /// Get all stored keys (for debugging)
  Set<String> getAllKeys() {
    return _preferences?.getKeys() ?? {};
  }

  /// Print all preferences (for debugging)
  void printAllPreferences() {
    print('📋 All SharedPreferences:');
    final keys = getAllKeys();
    for (var key in keys) {
      final value = _preferences?.get(key);
      print('   $key: $value');
    }
  }
}
