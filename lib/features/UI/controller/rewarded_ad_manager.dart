import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

/// Manager class for handling Rewarded Ads
class RewardedAdManager {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  /// Check if ad is ready to show
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

  /// Load a rewarded ad
  Future<void> loadRewardedAd({
    Function? onAdLoaded,
    Function(String)? onAdFailedToLoad,
  }) async {
    if (_isAdLoading) {
      print('⏳ Rewarded ad is already loading...');
      return;
    }

    if (_isAdLoaded) {
      print('✅ Rewarded ad is already loaded');
      return;
    }

    _isAdLoading = true;
    print('🔄 Loading rewarded ad...');

    await RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('✅ Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isAdLoading = false;

          // Set full screen content callback
          _setFullScreenContentCallback();

          if (onAdLoaded != null) {
            onAdLoaded();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Rewarded ad failed to load:');
          print('   Error code: ${error.code}');
          print('   Error domain: ${error.domain}');
          print('   Error message: ${error.message}');

          _rewardedAd = null;
          _isAdLoaded = false;
          _isAdLoading = false;

          // Handle specific error codes
          if (error.code == 0) {
            print('⚠️ JavascriptEngine error - WebView issue detected');
            print('💡 This usually resolves after app restart or device reboot');

            // Retry after delay for error code 0 (WebView issues)
            Future.delayed(const Duration(seconds: 5), () {
              print('🔄 Retrying ad load after WebView error...');
              loadRewardedAd(onAdFailedToLoad: onAdFailedToLoad);
            });
          }

          if (onAdFailedToLoad != null) {
            onAdFailedToLoad(error.message);
          }
        },
      ),
    );
  }

  /// Set full screen content callback for the loaded ad
  void _setFullScreenContentCallback() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('📺 Rewarded ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('🔒 Rewarded ad dismissed full screen content');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;

        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('❌ Rewarded ad failed to show full screen content:');
        print('   Error: $error');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
      },
      onAdImpression: (RewardedAd ad) {
        print('👁️ Rewarded ad impression recorded');
      },
    );
  }

  /// Show the rewarded ad
  Future<void> showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    Function? onAdDismissed,
  }) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      print('⚠️ Rewarded ad is not ready yet');
      return;
    }

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('🎁 User earned reward:');
        print('   Amount: ${reward.amount}');
        print('   Type: ${reward.type}');

        onUserEarnedReward(reward.amount.toInt(), reward.type);
      },
    );
  }

  /// Dispose the rewarded ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isAdLoading = false;
    print('🗑️ Rewarded ad manager disposed');
  }
}

