import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:untitled/configs/AppConfigs.dart';

class AdHelper {
  static bool get useAdMob => AppConfigs.adMobsAd;
  static bool get useAppLovin => !AppConfigs.adMobsAd;

  static String get bannerAdUnitId {
    if (useAdMob) {
      // AdMob Banner Ads
      if (Platform.isAndroid) {
        print('📱 Using REAL AdMob banner ad unit');
        return AppConfigs.adMobsBannerId;
      } else if (Platform.isIOS) {
        print('📱 Using REAL AdMob banner ad unit (iOS)');
        return AppConfigs.adMobsBannerIdIOS;
      }
    } else {
      // AppLovin Banner Ads
      if (Platform.isAndroid) {

        print('📱 Using REAL AppLovin banner ad unit (Android)');
        return AppConfigs.appLovinBannerIdAndroidProduction; // Production ID
      } else if (Platform.isIOS) {

        print('📱 Using REAL AppLovin banner ad unit (iOS)');
        return AppConfigs.appLovinBannerIdIOSProduction; // Production ID
      }
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (useAdMob) {
      // AdMob Rewarded Ads
      if (Platform.isAndroid) {

        print('📱 Using REAL AdMob rewarded ad unit');
        return AppConfigs.adMobsRewardsId;
      } else if (Platform.isIOS) {
        print('📱 Using REAL AdMob rewarded ad unit (iOS)');
        return AppConfigs.adMobsRewardsIdIOS;
      }
    } else {
      // AppLovin Rewarded Ads
      if (Platform.isAndroid) {

        print('📱 Using REAL AppLovin rewarded ad unit (Android)');
        return AppConfigs.appLovinRewardedIdAndroidProduction; // Production ID
      } else if (Platform.isIOS) {
        print('📱 Using REAL AppLovin rewarded ad unit (iOS)');
        return AppConfigs.appLovinRewardedIdIOSProduction; // Production ID
      }
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get ad network name for logging
  static String get adNetworkName => useAdMob ? 'AdMob' : 'AppLovin';
}