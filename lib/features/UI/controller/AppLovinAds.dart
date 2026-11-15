import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:untitled/configs/AppConfigs.dart';

class AppLovinAds {
  static final AppLovinAds _instance = AppLovinAds._internal();
  factory AppLovinAds() => _instance;
  AppLovinAds._internal();

  bool _isInitialized = false;
  bool _isListenersAttached = false;
  bool _isShowingRewarded = false;
  bool _isShowingInterstitial = false;

  bool get _isShowingFullscreenAd =>
      _isShowingRewarded || _isShowingInterstitial;

  void Function(int amount)? onRewardCallback;
  VoidCallback? onRewardedAdDismissed;

  // Track tab switches for interstitial frequency
  int _tabSwitchCount = 0;
  static const int _tabSwitchThreshold =
      3; // Show interstitial every 3 tab switches

  // Platform-aware Ad Unit IDs
  String get rewardedAdUnitId {
    if (Platform.isIOS) {
      return AppConfigs.appLovinRewardedIdIOSProduction;
    } else if (Platform.isAndroid) {
      return AppConfigs.appLovinRewardedIdAndroidProduction.startsWith("YOUR_")
          ? AppConfigs.appLovinRewardedIdAndroid
          : AppConfigs.appLovinRewardedIdAndroidProduction;
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isIOS) {
      // Rewarded placements are user-initiated and use a different AppLovin
      // format from interstitial placements. Do not use a rewarded unit as an
      // interstitial or show it while a user changes tabs. iOS uses the
      // existing explicit reward actions instead.
      return '';
    } else if (Platform.isAndroid) {
      return AppConfigs.appLovinInterstitialIdAndroidProduction;
    }
    return '';
  }

  String get bannerAdUnitId {
    if (Platform.isIOS) {
      return AppConfigs.appLovinBannerIdIOSProduction;
    } else if (Platform.isAndroid) {
      return AppConfigs.appLovinBannerIdAndroidProduction.startsWith("YOUR_")
          ? AppConfigs.appLovinBannerIdAndroid
          : AppConfigs.appLovinBannerIdAndroidProduction;
    }
    return '';
  }

  bool _isValidAdId(String id) {
    return id.isNotEmpty && !id.startsWith("YOUR_");
  }

  Future<void> initialize(String sdkKey) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint("ℹ️ AppLovin: Supported on Android & iOS only.");
      return;
    }

    if (_isInitialized) return;

    try {
      bool isSdkInit = await AppLovinMAX.isInitialized() ?? false;
      if (!isSdkInit) {
        MaxConfiguration? configuration = await AppLovinMAX.initialize(sdkKey);
        if (configuration == null) {
          debugPrint("❌ AppLovin SDK initialization returned null");
          return;
        }
      }

      _isInitialized = true;
      debugPrint("✅ AppLovin MAX initialized successfully");

      _setupListeners();
      loadRewardedAd();
      loadInterstitialAd();
    } catch (e) {
      debugPrint("❌ AppLovin initialization error: $e");
    }
  }

  void _setupListeners() {
    if (_isListenersAttached) return;
    _isListenersAttached = true;

    // Rewarded Listeners
    AppLovinMAX.setRewardedAdListener(
      RewardedAdListener(
        onAdLoadedCallback: (ad) =>
            debugPrint("✅ AppLovin Rewarded Ad Loaded: ${ad.adUnitId}"),
        onAdLoadFailedCallback: (id, err) => debugPrint(
          "❌ AppLovin Rewarded Load Failed ($id): ${err.message} (code ${err.code})",
        ),
        onAdDisplayedCallback: (ad) =>
            debugPrint("👁️ AppLovin Rewarded Ad Displayed"),
        onAdDisplayFailedCallback: (ad, err) {
          debugPrint("❌ AppLovin Rewarded Display Failed: ${err.message}");
          _isShowingRewarded = false;
          onRewardedAdDismissed?.call();
          loadRewardedAd();
        },
        onAdClickedCallback: (ad) =>
            debugPrint("👉 AppLovin Rewarded Ad Clicked"),
        onAdHiddenCallback: (ad) {
          debugPrint("ℹ️ AppLovin Rewarded Ad Closed, preloading next ad...");
          _isShowingRewarded = false;
          onRewardedAdDismissed?.call();
          loadRewardedAd();
        },
        onAdReceivedRewardCallback: (ad, reward) {
          debugPrint(
            "🎁 AppLovin Reward Received: ${reward.amount} ${reward.label}",
          );
          if (onRewardCallback != null) onRewardCallback!(reward.amount);
        },
      ),
    );

    // Interstitial Listeners
    AppLovinMAX.setInterstitialListener(
      InterstitialListener(
        onAdLoadedCallback: (ad) =>
            debugPrint("✅ AppLovin Interstitial Ad Loaded: ${ad.adUnitId}"),
        onAdLoadFailedCallback: (id, err) => debugPrint(
          "❌ AppLovin Interstitial Load Failed ($id): ${err.message} (code ${err.code})",
        ),
        onAdDisplayedCallback: (ad) =>
            debugPrint("👁️ AppLovin Interstitial Ad Displayed"),
        onAdDisplayFailedCallback: (ad, err) {
          debugPrint("❌ AppLovin Interstitial Display Failed: ${err.message}");
          _isShowingInterstitial = false;
          loadInterstitialAd();
        },
        onAdClickedCallback: (ad) =>
            debugPrint("👉 AppLovin Interstitial Ad Clicked"),
        onAdHiddenCallback: (ad) {
          debugPrint(
            "ℹ️ AppLovin Interstitial Ad Closed, preloading next ad...",
          );
          _isShowingInterstitial = false;
          loadInterstitialAd();
        },
      ),
    );
  }

  void loadRewardedAd() {
    final adId = rewardedAdUnitId;
    if (!_isValidAdId(adId)) {
      debugPrint("⚠️ AppLovin: Rewarded Ad Unit ID is not configured ($adId)");
      return;
    }
    AppLovinMAX.loadRewardedAd(adId);
  }

  void loadInterstitialAd() {
    final adId = interstitialAdUnitId;
    if (!_isValidAdId(adId)) {
      return;
    }
    AppLovinMAX.loadInterstitial(adId);
  }

  Future<bool> showRewardedAd() async {
    if (_isShowingFullscreenAd) return false;
    final adId = rewardedAdUnitId;
    if (!_isValidAdId(adId)) {
      debugPrint("⚠️ AppLovin: Rewarded ad ID is invalid or placeholder");
      return false;
    }

    bool isReady = await AppLovinMAX.isRewardedAdReady(adId) ?? false;
    if (isReady) {
      _isShowingRewarded = true;
      AppLovinMAX.showRewardedAd(adId);
      return true;
    } else {
      debugPrint("⏳ AppLovin: Rewarded ad not ready yet, requesting load...");
      AppLovinMAX.loadRewardedAd(adId);
      return false;
    }
  }

  Future<bool> showInterstitialAd() async {
    if (_isShowingFullscreenAd) return false;
    final adId = interstitialAdUnitId;
    if (!_isValidAdId(adId)) {
      return false;
    }

    bool isReady = await AppLovinMAX.isInterstitialReady(adId) ?? false;
    if (isReady) {
      _isShowingInterstitial = true;
      AppLovinMAX.showInterstitial(adId);
      return true;
    } else {
      AppLovinMAX.loadInterstitial(adId);
      return false;
    }
  }

  /// Call this on tab switch; shows interstitial every N tab switches
  Future<void> onTabSwitch() async {
    final adId = interstitialAdUnitId;
    if (!_isValidAdId(adId)) return;

    _tabSwitchCount++;
    if (_tabSwitchCount >= _tabSwitchThreshold) {
      _tabSwitchCount = 0;
      await showInterstitialAd();
    }
  }

  /// Reusable banner widget that displays AppLovin MAX Banner for non-premium users
  Widget buildBannerAd({required bool isPremium}) {
    if (isPremium) return const SizedBox.shrink();
    if (!Platform.isAndroid && !Platform.isIOS) return const SizedBox.shrink();

    final adId = bannerAdUnitId;
    if (!_isValidAdId(adId)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 50,
      color: const Color(0xFF0D0D1A),
      alignment: Alignment.center,
      child: MaxAdView(
        adUnitId: adId,
        adFormat: AdFormat.banner,
        listener: AdViewAdListener(
          onAdLoadedCallback: (ad) =>
              debugPrint("✅ AppLovin Banner Loaded: ${ad.adUnitId}"),
          onAdLoadFailedCallback: (ad, err) => debugPrint(
            "❌ AppLovin Banner Load Failed: ${err.message} (code ${err.code})",
          ),
          onAdClickedCallback: (ad) => debugPrint("👉 AppLovin Banner Clicked"),
          onAdExpandedCallback: (ad) {},
          onAdCollapsedCallback: (ad) {},
        ),
      ),
    );
  }
}
