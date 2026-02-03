import 'package:shared_preferences/shared_preferences.dart';

/// Manager class for handling premium user status
class PremiumManager {
  static const String _premiumKey = 'is_premium_user';

  /// Check if user has premium subscription
  static Future<bool> isPremiumUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_premiumKey) ?? false;
    } catch (e) {
      print('❌ Error checking premium status: $e');
      return false;
    }
  }

  /// Set premium status
  static Future<void> setPremiumStatus(bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, isPremium);
      print('💾 Premium status saved: ${isPremium ? "Premium" : "Free"}');
    } catch (e) {
      print('❌ Error saving premium status: $e');
    }
  }

  /// Clear premium status (for testing/logout)
  static Future<void> clearPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_premiumKey);
      print('🗑️ Premium status cleared');
    } catch (e) {
      print('❌ Error clearing premium status: $e');
    }
  }

  /// Activate premium subscription
  static Future<bool> activatePremium() async {
    await setPremiumStatus(true);
    return true;
  }

  /// Deactivate premium subscription
  static Future<bool> deactivatePremium() async {
    await setPremiumStatus(false);
    return true;
  }
}

