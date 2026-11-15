import 'purchase_controller.dart';

/// Compatibility facade; legacy booleans cannot establish subscriptions.
class PremiumManager {
  static Future<bool> isPremiumUser() async {
    await PurchaseController.shared.initialize();
    return PurchaseController.shared.isPremium;
  }

  @Deprecated('Only verified store entitlements can establish paid access')
  static Future<void> setPremiumStatus(bool isPremium) async {
    await PurchaseController.shared.initialize();
    await PurchaseController.shared.refresh();
  }

  static Future<void> clearPremiumStatus() async {
    await PurchaseController.shared.setRewardExpiry(null);
    await PurchaseController.shared.refresh();
  }

  static Future<bool> activatePremium() => isPremiumUser();
  static Future<bool> deactivatePremium() async {
    await clearPremiumStatus();
    return !PurchaseController.shared.isPremium;
  }
}
