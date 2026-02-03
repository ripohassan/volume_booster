import 'dart:math';
import 'package:flutter/material.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:untitled/configs/AppConfigs.dart';

class AppLovinAds {
  static final AppLovinAds _instance = AppLovinAds._internal();
  factory AppLovinAds() => _instance;
  AppLovinAds._internal();

  final String rewardedAdUnitId = AppConfigs.appLovinRewardedIdIOSProduction;
  final String bannerAdUnitId = AppConfigs.appLovinBannerIdIOSProduction;

  void Function(int amount)? onRewardCallback;

  Future<void> initialize(String sdkKey) async {
    MaxConfiguration? configuration = await AppLovinMAX.initialize(sdkKey);
    if (configuration != null) {
      _setupListeners();
      AppLovinMAX.loadRewardedAd(rewardedAdUnitId);
    }
  }

  void _setupListeners() {
    // Rewarded Listeners
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) => print("✅ Ad Loaded"),
      onAdLoadFailedCallback: (id, err) => print("❌ Load Failed: $err"),
      onAdDisplayedCallback: (ad) {},
      onAdDisplayFailedCallback: (ad, err) => AppLovinMAX.loadRewardedAd(rewardedAdUnitId),
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) => AppLovinMAX.loadRewardedAd(rewardedAdUnitId), // Preload next
      onAdReceivedRewardCallback: (ad, reward) {
        if (onRewardCallback != null) onRewardCallback!(reward.amount);
      },
    ));
  }

  Future<void> showRewardedAd() async {
    bool isReady = await AppLovinMAX.isRewardedAdReady(rewardedAdUnitId) ?? false;
    if (isReady) {
      AppLovinMAX.showRewardedAd(rewardedAdUnitId);
    } else {
      AppLovinMAX.loadRewardedAd(rewardedAdUnitId);
    }
  }

  void showBanner({AdViewPosition position = AdViewPosition.bottomCenter}) {
    AppLovinMAX.createBanner(bannerAdUnitId, position);
    AppLovinMAX.showBanner(bannerAdUnitId);
  }

  void removeBanner() {
    AppLovinMAX.destroyBanner(bannerAdUnitId);
  }
}