import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // This is the correct package for Subscriptions
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:untitled/features/UI/screen/PurchaseScreen.dart';
import 'package:untitled/features/UI/screen/vFixer/BassBoosterApp.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/AppLovinAds.dart';
import 'setting_screen.dart';
import 'All_song_Store_screen.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';
import '../../../configs/AppConfigs.dart';
import '../controller/ad_helper.dart';
import '../controller/rewarded_ad_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _volume = 50;
  bool _isPlaying = false;
  bool _isPremiumUser = false;
  BannerAd? _bannerAd;
  final RewardedAdManager _rewardedAdManager = RewardedAdManager();
  late SharedPreferencesService _prefsService;
// Replace the old AdMob RewardedAdManager with AppLovin
  final AppLovinAds _appLovinAds = AppLovinAds();
  // Audio player variables
  AudioPlayer? _audioPlayer;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _currentSongTitle = 'No Song Selected';
  String? _currentSongPath;
  bool _isRepeat = false;
  bool _isShuffle = false;

  // All songs list for skip next/previous
  List<Map<String, String>> _allSongs = [];
  int _currentSongIndex = -1;

  // Track action counts for rewarded ads (show every 3 times)
  int _volumeButtonClickCount = 0;
  int _audioUploadCount = 0;
  static const int _adTriggerFrequency = 2; // Show ad every 3 actions

  // Track actions for showing Remove Ads dialog (every 4 actions)
  int _actionCountForRemoveAds = 0;
  static const int _removeAdsDialogFrequency = 2; // Show Remove Ads dialog every 4 actions

  /// The In App Purchase plugin (handles Subscriptions)
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  bool isWeeklySelected = true; // default selected

  // --- NEW FEATURE: BASS BOOST ---
  bool _isBassBoostEnabled = false;

  // --- NEW FEATURE: SLEEP TIMER ---
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeInAppPurchase(); // Initializes Subscription logic
    _listenForPurchaseUpdated();
    // Listens for Subscription status changes

    _initAppLovin();
  }



  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // =======================================================================
  // == START: SUBSCRIPTION LOGIC (Fixes Apple Guideline 2.1)
  // =======================================================================

  /// This function initializes the subscription service
  Future<void> _initializeInAppPurchase() async {
    // Checks if the user can make payments
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (isAvailable) {
      print("✅ Subscription service is available. Checking for existing subscriptions...");
      // This checks for past purchases (like an active subscription) on app start.
      await _inAppPurchase.restorePurchases();
    } else {
      print("❌ Subscription service is not available.");
    }

    // Load your specific subscription product IDs from the App Store
    final ProductDetailsResponse response =
    await _inAppPurchase.queryProductDetails(
        <String>{'v.booster.weekly', 'v.booster.yearly'}); // Your subscription IDs

    if (response.error != null) {
      print("❌ Error loading subscription products: ${response.error!.message}");
    }
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
      });
      print("✅ Subscription products loaded: ${_products.map((p) => p.id).toList()}");
    } else {
      print("❌ No subscription products found.");
    }
  }

  /// This function is called when the user taps "Subscribe Now"
  Future<void> _buyProduct(String productId) async {
    final ProductDetails productDetails;
    try {
      // Find the subscription product from the list
      productDetails = _products.firstWhere((prod) => prod.id == productId);
    } catch (e) {
      print("❌ Subscription $productId not found in loaded list.");
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    // This is the correct way to buy a subscription.
    // `buyConsumable` was the bug. `buyNonConsumable` is correct for subscriptions.
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// This function listens for all subscription changes (new, restored, failed)
  void _listenForPurchaseUpdated() {
    _subscription =
        _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
          for (var purchaseDetails in purchaseDetailsList) {
            _handlePurchase(purchaseDetails);
          }
        }, onDone: () {
          _subscription?.cancel();
        }, onError: (error) {
          print("❌ Subscription stream error: $error");
        });
  }

  /// This function handles the status of a subscription transaction
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // This handles both a new subscription and a restored subscription
      print("✅ Subscription active for: ${purchaseDetails.productID}");

      // 1. Give the user premium access
      await _grantPremiumAccess();

      // 2. Close the subscription dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // 3. This is CRITICAL for Apple. You must complete the transaction.
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        print("✅ Subscription transaction completed.");
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print("❌ Subscription Error: ${purchaseDetails.error?.message}");
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      print("⌛ Subscription purchase pending...");
      // You can show a loading indicator here
    }
  }
  Future<void> _grantPremiumAccess() async {
    // 1. Immediately kill all ad instances
    _appLovinAds.removeBanner();
    _bannerAd?.dispose(); // Legacy AdMob cleanup if still active

    setState(() {
      _isPremiumUser = true;
      _bannerAd = null;
    });

    // 2. Persist the state
    await _prefsService.setPermanentPremium(true);

    // 3. UI Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.white),
              SizedBox(width: 10),
              Text('🎉 Premium features unlocked! Ads removed.'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
// --- FIX: Show ONLY if NOT premium ---
  void _loadBannerAd() {
    if (!_isPremiumUser) {
      print("📢 User is Free: Loading Banner");
      _appLovinAds.showBanner(position: AdViewPosition.bottomCenter);
    } else {
      print("💎 User is Premium: Killing Banner");
      _appLovinAds.removeBanner();
    }
  }

// --- FIX: Ensure Initialization respects status ---
  Future<void> _initAppLovin() async {
    // Request tracking for iOS// 1. Handle iOS Tracking Permission first
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // Small delay to ensure the app is fully visible before showing the native popup
          await Future.delayed(const Duration(milliseconds: 200));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }
    await _appLovinAds.initialize("rE7T1tT5kcQ9h5E8aNupaDlIiepC4dX6zBOom30HUZFX6ffRFyHB9ePcFZT4uMl2JRQ0ODm_WefC8zKmqkNHgt");

    // Check status immediately after init
    if (!_isPremiumUser) {
      _appLovinAds.showBanner(position: AdViewPosition.bottomCenter);
    } else {
      _appLovinAds.removeBanner();
    }
  }

  void _showRewardedAdForAction(String actionName, Function onComplete) async {
    // If premium, execute the function immediately and exit
    if (_isPremiumUser) {
      onComplete();
      return;
    }

    // Only free users reach this point
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Ad to proceed...'), duration: Duration(seconds: 1)),
    );

    // Show ad
    await _appLovinAds.showRewardedAd();

    // Execute the sensitive action (like volume boost or file pick)
    onComplete();
  }

  @override
  void dispose() {
    _appLovinAds.removeBanner(); // Clean up AppLovin banner
    _audioPlayer?.dispose();
    _subscription?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
  }

  // =======================================================================
  // == END: SUBSCRIPTION LOGIC
  // =======================================================================

  // Initialize all services
  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _loadPremiumStatus();
    await _loadAdCounters();
    await _initializeAudioPlayer();

    if (!_isPremiumUser) {
      _rewardedAdManager.loadRewardedAd(
        onAdLoaded: () {
          print('🎁 Rewarded ad ready to show');
        },
        onAdFailedToLoad: (error) {
          print('⚠️ Rewarded ad failed: $error');
        },
      );
    }
  }

  Future<void> _loadAdCounters() async {
    final volumeCount = await _prefsService.getVolumeButtonClickCount();
    final audioCount = await _prefsService.getAudioUploadCount();
    setState(() {
      _volumeButtonClickCount = volumeCount;
      _audioUploadCount = audioCount;
    });
    print('📊 Loaded counters - Volume: $volumeCount, Audio: $audioCount');
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final isPremium = await _prefsService.isPremiumUser();
      final isPermanent = await _prefsService.isPermanentPremium();
      final hasTemp = await _prefsService.hasTemporaryPremium();

      if (hasTemp) {
        final remaining = await _prefsService.getRemainingPremiumTime();
        if (remaining != null) {
          Future.delayed(remaining, () {
            _checkPremiumExpiry();
          });
          print('💎 Temporary premium expires in: ${remaining.inMinutes} minutes');
        }
      }

      setState(() {
        _isPremiumUser = isPremium;
      });

      if (isPermanent) {
        print('💎 Premium status loaded: Permanent Premium User');
      } else if (hasTemp) {
        print('💎 Premium status loaded: Temporary Premium User');
      } else {
        print('💎 Premium status loaded: Free User');
      }

      if (!_isPremiumUser) {
        _loadBannerAd();
      }
    } catch (e) {
      print('❌ Error loading premium status: $e');
      _loadBannerAd();
    }
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer!.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));

      // Listen to audio player states
      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer!.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });

          if (_isRepeat) {
            print('🔁 Repeat mode: Restarting audio');
            Future.delayed(const Duration(milliseconds: 300), () {
              _audioPlayer?.seek(Duration.zero);
              _audioPlayer?.resume();
            });
          } else {
            print('✅ Audio completed');
            _audioPlayer?.seek(Duration.zero);
          }
        }
      });

      await _applyVolumeBoost(_volume);
      print('Audio player initialized with volume: ${_volume.toInt()}%');
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Banner Ad (shown only for non-premium users)
              if (!_isPremiumUser && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.transparent,
                  child: AdWidget(ad: _bannerAd!),
                ),

              // Header
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18.r,
                      backgroundImage:
                      AssetImage('assets/images/Volumix-png.png'),
                    ),
                    const Spacer(),
                    Text(
                      AppConfigs.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        _showRewardedAdOrNavigate();
                      },
                      child: Icon(Icons.settings, color: Colors.white, size: 24),
                    )
                  ],
                ),
              ),

              // Navigation Tabs
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTab('Home', true),
                    _buildTab('All Song', false),
                    _buildTab('Bass Booster', false),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // Main Volume Control with Equalizer Bars
              SizedBox(
                height: 280.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildEqualizerBars(),
                    SizedBox(width: 40.w),
                    _buildVolumeKnob(),
                    SizedBox(width: 40.w),
                    _buildEqualizerBars(),
                  ],
                ),
              ),

              // Volume Slider
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Row(
                  children: [
                    Icon(Icons.volume_up, color: Colors.cyan, size: 24.sp),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purple,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.white,
                          overlayColor: Colors.purple.withAlpha(50),
                          trackHeight: 4.h,
                        ),
                        child: Slider(
                          value: _volume,
                          min: 0,
                          max: 500,
                          onChanged: (value) async {
                            setState(() {
                              _volume = value;
                            });
                            await _applyVolumeBoost(_volume);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // Volume Percentage Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPercentageButton('Mute', 0, isPremium: false),
                        _buildPercentageButton('30%', 30, isPremium: false),
                        _buildPercentageButton('60%', 60, isPremium: false),
                        _buildPercentageButton('100%', 100, isPremium: false),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPercentageButton('125%', 125, isPremium: true),
                        _buildPercentageButton('150%', 150, isPremium: true),
                        _buildPercentageButton('175%', 175, isPremium: true),
                        _buildPercentageButton('200%', 200, isPremium: true),
                      ],
                    ),

                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPercentageButton('250%', 250, isPremium: true),
                        _buildPercentageButton('300%', 300, isPremium: true),
                        _buildPercentageButton('400%', 400, isPremium: true),
                        _buildPercentageButton('Max', 500, isPremium: true),
                      ],
                    ),

                  ],
                ),
              ),
              //
              // SizedBox(height: 15.h), // Reduced spacing
              //
              // // --- NEW FEATURE: BASS BOOST ---
              // Padding(
              //   padding: EdgeInsets.symmetric(horizontal: 25.w),
              //   child: _buildBassBoostToggle(),
              // ),
              // // --- END: BASS BOOST ---

              SizedBox(height: 15.h), // Reduced spacing

              // Song Controls
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(15.r),
                ),
                child: Column(
                  children: [
                    // Song Title and Progress Bar
                    Row(
                      children: [
                        Icon(Icons.queue_music,
                            color: Colors.cyan, size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            _currentSongTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // --- NEW FEATURE: SLEEP TIMER BUTTON ---
                        IconButton(
                          icon: Icon(
                            _sleepTimerDuration == null
                                ? Icons.timer_outlined
                                : Icons.timer,
                            color: _sleepTimerDuration == null
                                ? Colors.white
                                : Colors.cyan,
                            size: 20,
                          ),
                          onPressed: _onSleepTimerTapped,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: 8.w), // Added spacing
                        IconButton(
                          icon: const Icon(Icons.folder_open,
                              color: Colors.white, size: 20),
                          onPressed: _pickAudioFile,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress Slider
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.cyan,
                              inactiveTrackColor: Colors.grey[800],
                              thumbColor: Colors.white,
                              overlayColor: Colors.cyan.withAlpha(50),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble().clamp(
                                0.0,
                                _duration.inSeconds.toDouble() > 0
                                    ? _duration.inSeconds.toDouble()
                                    : 1.0,
                              ),
                              min: 0,
                              max: _duration.inSeconds.toDouble() > 0
                                  ? _duration.inSeconds.toDouble()
                                  : 1,
                              onChanged: (value) async {
                                try {
                                  if (_currentSongPath != null &&
                                      _audioPlayer != null &&
                                      _duration.inSeconds > 0) {
                                    final clampedValue = value.clamp(0.0,
                                        _duration.inSeconds.toDouble());
                                    final position =
                                    Duration(seconds: clampedValue.toInt());
                                    if (position.inSeconds <
                                        _duration.inSeconds) {
                                      await _audioPlayer?.seek(position);
                                    }
                                  }
                                } catch (e) {
                                  print('❌ Error seeking: $e');
                                }
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Control Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: _isShuffle ? Colors.cyan : Colors.white,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              _isShuffle = !_isShuffle;
                            });
                          },
                        ),
                        // --- NEW FEATURE: EQUALIZER BUTTON ---
                        IconButton(
                          icon: Icon(
                            Icons.graphic_eq,
                            color: _isPremiumUser ? Colors.cyan : Colors.white,
                            size: 20.sp,
                          ),
                          onPressed: _onEqualizerTapped,
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_previous,
                              color: Colors.white, size: 28.sp),
                          onPressed: _skipToPrevious,
                        ),
                        Container(
                          width: 50.w,
                          height: 50.h,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00D9FF), Color(0xFF0066FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 28.sp,
                            ),
                            onPressed: _isPremiumUser ? _playPause : _goPremium,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next,
                              color: Colors.white, size: 28.sp),
                          onPressed: _skipToNext,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.repeat,
                            color: _isRepeat ? Colors.cyan : Colors.white,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              _isRepeat = !_isRepeat;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return GestureDetector(
      onTap: () async {
        if (title == 'All Song' && !isActive) {
          final selectedSong = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AllSongStoreScreen(),
            ),
          );
          if (selectedSong != null && selectedSong is Map<String, String>) {
            await _playSongFromStore(selectedSong);
          }
        }
        else if(title == 'Bass Booster'){
          if (!_isPremiumUser) {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseScreen(),
                ));
          }else{
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BassBoosterScreen(),
                ));
          }


        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.cyan : Colors.grey,
              fontSize: 14.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          SizedBox(height: 4.h),
          if (isActive)
            Container(
              height: 2.h,
              width: 30.w,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.cyan, Colors.blue],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVolumeKnob() {
    return SizedBox(
      width: 180.w,
      height: 180.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(180.w, 180.h),
            painter: VolumeRingPainter(_volume),
          ),
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(76),
                  blurRadius: 15.r,
                  spreadRadius: 3.r,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 70.w,
                height: 70.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(128),
                      blurRadius: 10.r,
                      spreadRadius: 2.r,
                      offset: Offset(0, 3.h),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildEqualizerColumn(0),
        const SizedBox(width: 4),
        _buildEqualizerColumn(1),
        const SizedBox(width: 4),
        _buildEqualizerColumn(2),
      ],
    );
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingScreen(),
      ),
    );
    await _refreshPremiumStatus();
  }

  void _showRewardedAdOrNavigate() async {
    if (_rewardedAdManager.isAdReady) {
      print("🎬 Showing AdMob ad before navigating to settings...");
      await _rewardedAdManager.showRewardedAd(
        onUserEarnedReward: (amount, type) async {
          print("🎉 User got reward: $amount $type. Navigating...");
          await _navigateToSettings();
        },
        onAdDismissed: () async {
          print("🔒 Ad dismissed. Navigating...");
          await _navigateToSettings();
        },
      );
    } else {
      print("⚠️ Ad not ready. Navigating directly to settings...");
      await _navigateToSettings();
    }
  }

  Widget _buildEqualizerColumn(int columnIndex) {
    final barHeights = [6.h, 8.h, 6.h][columnIndex];
    return SizedBox(
      height: 200.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            12,
                (barIndex) {
              Color barColor;
              if (barIndex < 4) {
                barColor = Colors.red;
              } else if (barIndex < 8) {
                barColor = Colors.yellow;
              } else {
                barColor = Colors.green;
              }

              final totalBars = 12;
              final activeBars = (_volume / 500 * totalBars).round();
              final isActive = (totalBars - barIndex) <= activeBars;

              return Container(
                margin: EdgeInsets.symmetric(vertical: 1.5.h),
                width: 8.w,
                height: barHeights,
                decoration: BoxDecoration(
                  color: isActive ? barColor : Colors.grey[850],
                  borderRadius: BorderRadius.circular(1.5.r),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageButton(String label, double value,
      {required bool isPremium}) {
    final isSelected = (_volume - value).abs() < 5;
    final isLocked = isPremium && !_isPremiumUser;

    return InkWell(
      onTap: () async {
        if (isLocked) {
          _showSubscriptionDialog();
        } else {
          if (!_isPremiumUser) {
            _volumeButtonClickCount++;
            _actionCountForRemoveAds++;

            if (_actionCountForRemoveAds % _removeAdsDialogFrequency == 2) {
              print(
                  '🎯 Showing Remove Ads dialog (every $_removeAdsDialogFrequency actions)');
              _showSubscriptionDialog();
              return;
            }

            if (_volumeButtonClickCount % _adTriggerFrequency == 0) {
              print(
                  '🎬 Triggering rewarded ad (every $_adTriggerFrequency clicks)');
              _showRewardedAdForAction('volume change', () async {
                setState(() {
                  _volume = value;
                });
                await _applyVolumeBoost(_volume);
              });
              return;
            }
          }

          setState(() {
            _volume = value;
          });
          await _applyVolumeBoost(_volume);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purple.withAlpha(76)
              : (isLocked ? Colors.grey[900] : Colors.grey[850]),
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected
              ? Border.all(color: Colors.purple, width: 1.w)
              : (isLocked
              ? Border.all(color: Colors.orange.withAlpha(76), width: 1.w)
              : null),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLocked) ...[
              Icon(
                Icons.lock,
                color: Colors.orange,
                size: 14.sp,
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isLocked
                    ? Colors.orange
                    : (isSelected ? Colors.white : Colors.grey[400]),
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // == NEW FEATURE: BASS BOOST
  // ===================================================================
  Widget _buildBassBoostToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.speaker,
                  color: _isBassBoostEnabled ? Colors.cyan : Colors.white),
              SizedBox(width: 12.w),
              Text(
                'Bass Boost',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_isPremiumUser)
            Switch(
              value: _isBassBoostEnabled,
              onChanged: (value) {
                setState(() {
                  _isBassBoostEnabled = value;
                });
                _applyAudioEffects();
              },
              activeColor: Colors.cyan,
            )
          else
            InkWell(
              onTap: _showSubscriptionDialog,
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Unlock',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600),
                  )
                ],
              ),
            )
        ],
      ),
    );
  }

  Future<void> _applyAudioEffects() async {
    // TODO: This requires a more advanced audio package like `just_audio`
    // to apply real audio effects like Bass Boost and Equalizer.
    // The `audioplayers` package does not support this.
    // For now, we just log that the state was changed.
    if (_isBassBoostEnabled) {

      print("🎧 Bass Boost Enabled");
    } else {

      print("🎧 Bass Boost Disabled");
    }

    setState(() {});
  }
  // ===================================================================

  // ===================================================================
  // == NEW FEATURE: SLEEP TIMER
  // ===================================================================
  void _onSleepTimerTapped() {
    // If timer is already running, show option to cancel
    if (_sleepTimer != null && _sleepTimerDuration != null) {
      _showCancelSleepTimerDialog();
    } else {
      _showSetSleepTimerDialog();
    }
  }

  void _showSetSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text('Sleep Timer',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp)),
          children: [
            _buildTimerOption(15),
            _buildTimerOption(30),
            _buildTimerOption(60),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimerOption(int minutes) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.of(context).pop();
        _startSleepTimer(Duration(minutes: minutes));
      },
      child: Text('$minutes minutes',
          style: TextStyle(color: Colors.white, fontSize: 14.sp)),
    );
  }

  void _showCancelSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text('Sleep Timer Active',
              style: TextStyle(color: Colors.white, fontSize: 18.sp)),
          content: Text(
              'A timer is set. Do you want to cancel it?',
              style: TextStyle(color: Colors.grey[300], fontSize: 14.sp)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelSleepTimer();
              },
              child: Text('Cancel Timer', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        );
      },
    );
  }

  void _startSleepTimer(Duration duration) {
    _sleepTimer?.cancel(); // Cancel any existing timer
    setState(() {
      _sleepTimerDuration = duration;
    });

    _sleepTimer = Timer(duration, _onSleepTimerFired);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ Sleep timer set for ${duration.inMinutes} minutes.'),
        backgroundColor: Colors.cyan,
      ),
    );
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerDuration = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sleep timer cancelled.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _onSleepTimerFired() {
    print("⏰ Sleep Timer Fired. Pausing audio.");
    _audioPlayer?.pause();
    setState(() {
      _sleepTimer = null;
      _sleepTimerDuration = null;
    });
  }
  // ===================================================================

  // ===================================================================
  // == NEW FEATURE: EQUALIZER FUNCTION
  // ===================================================================
  void _onEqualizerTapped() {
    if (_isPremiumUser) {
      print("✅ Premium user opening Equalizer.");
      // TODO: Build a new screen or dialog for your equalizer.
      _showInfoDialog(
        "Equalizer (Premium)",
        "This is where your new Graphic Equalizer feature will be. You can build this on a new screen with sliders for 60Hz, 230Hz, 910Hz, 3kHz, etc.",
      );
    } else {
      print("❌ Free user tapped Equalizer. Showing subscription dialog.");
      _showSubscriptionDialog();
    }
  }
  // ===================================================================

  // ===================================================================
  // == FIX FOR STACK TRACE
  // ===================================================================

  /// Helper function to safely get the product price or return a default.
  String _getProductPrice(String productId, String defaultPrice) {
    try {
      // Find the product in the list
      final product = _products.firstWhere((p) => p.id == productId);
      // If found, return its price
      return product.price;
    } catch (e) {
      // If not found (firstWhere throws an error), return the default price
      return defaultPrice;
    }
  }
  // ===================================================================

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF16213E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView( // Added for smaller screens
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Premium Features', // Updated Title
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      _buildFeatureItem('Boost volume up to 200%'),
                      _buildFeatureItem('Unlock Bass Boost'), // NEW
                      _buildFeatureItem('Unlock Equalizer'), // NEW
                      _buildFeatureItem('No Ads'),
                      const SizedBox(height: 10),

                      Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                isWeeklySelected = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              height: 65,
                              decoration: BoxDecoration(
                                color: isWeeklySelected
                                    ? Colors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border:
                                Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Weekly',
                                    style: TextStyle(
                                      color: isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    // --- FIXED ERROR HERE ---
                                    _getProductPrice('v.booster.weekly', '\$4.99'),
                                    style: TextStyle(
                                      color: isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '3 Days Trial',
                                    style: TextStyle(
                                      color: isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                isWeeklySelected = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              height: 65,
                              decoration: BoxDecoration(
                                color: !isWeeklySelected
                                    ? Colors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border:
                                Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Yearly',
                                    style: TextStyle(
                                      color: !isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    // --- FIXED ERROR HERE ---
                                    _getProductPrice('v.booster.yearly', '\$49.99'),
                                    style: TextStyle(
                                      color: !isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '3 Days Trial',
                                    style: TextStyle(
                                      color: !isWeeklySelected
                                          ? Colors.white
                                          : Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (isWeeklySelected) {
                            _buyProduct('v.booster.weekly');
                          } else {
                            _buyProduct('v.booster.yearly');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          // This calls the restore function
                          _inAppPurchase.restorePurchases();
                        },
                        child: Text(
                          'Restore Purchase',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 19),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              _openTermsAndConditions();
                            },
                            child: const Text("Terms of Use",
                                style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 5),
                          Container(height: 10, width: 1, color: Colors.white),
                          const SizedBox(width: 5),
                          InkWell(
                            onTap: () {
                              _openPrivacyPolicy();
                            },
                            child: const Text(
                              "Privacy Policy",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTermsAndConditions() async {
    final Uri url =
    Uri.parse('https://sites.google.com/view/imagefitterms/home');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showInfoDialog('Error', 'Could not open terms and conditions.');
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri url =
    Uri.parse('https://sites.google.com/view/volumebooster001/home');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showInfoDialog('Error', 'Could not open privacy policy.');
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding:
                    EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center features
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveAdsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                  ),
                  child: Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Remove Ads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Enjoy ad-free experience!\nChoose your premium option',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showSubscriptionDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding:
                    EdgeInsets.symmetric(horizontal: 30.w, vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium,
                          color: Colors.white, size: 20.sp),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          'Go Premium',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _watchAdForTemporaryPremium();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.cyan, width: 2.w),
                    padding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  icon: Icon(Icons.play_circle_outline,
                      color: Colors.cyan, size: 20.sp),
                  label: Flexible(
                    child: Text(
                      'Watch Ad (1 Hour Free)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.cyan,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _watchAdForTemporaryPremium() async {
    if (!_rewardedAdManager.isAdReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading ad, please wait...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      await _rewardedAdManager.loadRewardedAd(
        onAdLoaded: () {
          _watchAdForTemporaryPremium();
        },
        onAdFailedToLoad: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load ad: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
      return;
    }

    await _rewardedAdManager.showRewardedAd(
      onUserEarnedReward: (amount, type) async {
        print('🎁 User earned reward: $amount $type');
        await _prefsService.setTemporaryPremium(const Duration(hours: 1));

        _bannerAd?.dispose();
        setState(() {
          _isPremiumUser = true;
          _bannerAd = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('🎉 Premium unlocked for 1 hour! Enjoy ad-free experience.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        print('✅ Temporary premium granted for 1 hour');
      },
      onAdDismissed: () {
        _rewardedAdManager.loadRewardedAd();
      },
    );
  }


  void _showRewardedAd() async {
    if (!_rewardedAdManager.isAdReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Loading ad, please wait...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      await _rewardedAdManager.loadRewardedAd(
        onAdLoaded: () {
          print('✅ Rewarded ad loaded, showing now...');
          _showRewardedAd();
        },
        onAdFailedToLoad: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load ad: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
      return;
    }

    await _rewardedAdManager.showRewardedAd(
      onUserEarnedReward: (amount, type) async {
        print('🎁 User earned reward: $amount $type');

        final prefs = await SharedPreferences.getInstance();
        final expiryTime = DateTime.now().add(const Duration(hours: 1));
        await prefs.setString(
            'temp_premium_expiry', expiryTime.toIso8601String());

        _bannerAd?.dispose();
        setState(() {
          _isPremiumUser = true;
          _bannerAd = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.access_time, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 Premium unlocked for 1 hour! Enjoy ad-free experience.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        Future.delayed(const Duration(hours: 1), () {
          _checkPremiumExpiry();
        });
        print('✅ Temporary premium granted for 1 hour');
      },
      onAdDismissed: () {
        print('ℹ️ Rewarded ad dismissed');
        _rewardedAdManager.loadRewardedAd();
      },
    );
  }

  Future<void> _checkPremiumExpiry() async {
    try {
      final hasTemp = await _prefsService.hasTemporaryPremium();

      if (!hasTemp) {
        final isPermanent = await _prefsService.isPermanentPremium();
        if (!isPermanent) {
          setState(() {
            _isPremiumUser = false;
          });

          _loadBannerAd();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '⏰ Premium trial expired. Watch another ad to continue.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          print('⏰ Temporary premium expired');
        }
      }
    } catch (e) {
      print('❌ Error checking premium expiry: $e');
    }
  }

  Future<void> _refreshPremiumStatus() async {
    try {
      print('🔄 Refreshing premium status...');
      final isPremium = await _prefsService.isPremiumUser();
      final previousPremiumStatus = _isPremiumUser;

      setState(() {
        _isPremiumUser = isPremium;
      });

      if (await _prefsService.isPermanentPremium()) {
        print('💎 Premium status: Permanent Premium User');
      } else if (await _prefsService.hasTemporaryPremium()) {
        print('💎 Premium status: Temporary Premium User');
      } else {
        print('💎 Premium status: Free User');
      }

      if (previousPremiumStatus && !_isPremiumUser) {
        print('🔄 Subscription removed - Loading banner ad...');
        _loadBannerAd();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Subscription removed. You are now a free user.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (!previousPremiumStatus && _isPremiumUser) {
        print('🎉 Premium activated - Removing banner ad...');
        _bannerAd?.dispose();
        setState(() {
          _bannerAd = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Premium activated! Enjoy ad-free experience.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (!_isPremiumUser && _bannerAd == null) {
          print('🔄 Reloading banner ad...');
          _loadBannerAd();
        }
      }
      print('✅ Premium status refreshed');
    } catch (e) {
      print('❌ Error refreshing premium status: $e');
    }
  }

  Future<void> _applyVolumeBoost(double volumePercent) async {
    try {
      double audioVolume;
      if (volumePercent <= 100) {
        audioVolume = volumePercent / 100;
      } else {
        final boostFactor = (volumePercent - 100) / 100;
        audioVolume = 1.0 + (boostFactor * 1.0);
        audioVolume = audioVolume.clamp(0.0, 5.0);
      }

      await _audioPlayer?.setVolume(audioVolume);

      if (volumePercent > 100) {
        await _audioPlayer?.setPlaybackRate(1.0);
      }

      print(
          '✅ Volume applied: ${volumePercent.toInt()}% (audio level: ${audioVolume.toStringAsFixed(2)})');
    } catch (e) {
      print('❌ Error applying volume: $e');
    }
  }

  // Audio Player Methods
  Future<void> _pickAudioFile() async {
    try {
      if (!_isPremiumUser) {
        _audioUploadCount++;
        _actionCountForRemoveAds++;
        print('📊 Audio upload count: $_audioUploadCount');
        print('📊 Action count for Remove Ads: $_actionCountForRemoveAds');

        if (_actionCountForRemoveAds % _removeAdsDialogFrequency == 0) {
          print(
              '🎯 Showing Remove Ads dialog (every $_removeAdsDialogFrequency actions)');
          _showSubscriptionDialog();
          return;
        }

        if (_audioUploadCount % _adTriggerFrequency == 0) {
          print(
              '🎬 Triggering rewarded ad (every $_adTriggerFrequency uploads)');
          _showRewardedAdForAction('audio upload', () async {
            await _performAudioFilePick();
          });
          return;
        }
      }

      await _performAudioFilePick();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performAudioFilePick() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        String songTitle =
        fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac)$'), '');

        setState(() {
          _currentSongPath = filePath;
          _currentSongTitle = songTitle;
        });

        await _audioPlayer?.setSourceDeviceFile(filePath);
        await Future.delayed(const Duration(milliseconds: 100));
        await _applyVolumeBoost(_volume);
        await _saveSongToStorage(songTitle, filePath);
        await _loadAllSongs();
        _currentSongIndex = _allSongs.indexWhere((s) => s['path'] == filePath);

        print(
            '🎵 Audio loaded: $fileName with volume boost ${_volume.toInt()}%');
        print('📍 Current song index: $_currentSongIndex');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('✅ "$songTitle" saved to All Songs'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playPause() async {
    if (_currentSongPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a song first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer?.pause();
        print('⏸️ Audio paused');
      } else {
        if (_position.inSeconds >= _duration.inSeconds &&
            _duration.inSeconds > 0) {
          print('🔄 Audio at end, restarting from beginning');
          await _audioPlayer?.seek(Duration.zero);
        }
        await _audioPlayer?.resume();
        print('▶️ Audio resumed');
      }
    } catch (e) {
      print('❌ Error playing/pausing audio: $e');
    }
  }

  Future<void> _goPremium() async {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PurchaseScreen(),
        ));
  }

  Future<void> _skipToPrevious() async {
    try {
      await _loadAllSongs();
      if (_allSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No songs in library. Upload songs first!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_currentSongIndex == -1) {
        _currentSongIndex = _allSongs.length - 1;
      } else {
        _currentSongIndex--;
        if (_currentSongIndex < 0) {
          _currentSongIndex = _allSongs.length - 1;
        }
      }

      final previousSong = _allSongs[_currentSongIndex];
      await _playSongFromStore(previousSong);
      print(
          '⏮️ Playing previous song: ${previousSong['title']} (Index: $_currentSongIndex)');
    } catch (e) {
      print('❌ Error skipping to previous: $e');
    }
  }

  Future<void> _skipToNext() async {
    try {
      await _loadAllSongs();
      if (_allSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No songs in library. Upload songs first!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_currentSongIndex == -1) {
        _currentSongIndex = 0;
      } else {
        _currentSongIndex++;
        if (_currentSongIndex >= _allSongs.length) {
          _currentSongIndex = 0;
        }
      }

      final nextSong = _allSongs[_currentSongIndex];
      await _playSongFromStore(nextSong);
      print(
          '⏭️ Playing next song: ${nextSong['title']} (Index: $_currentSongIndex)');
    } catch (e) {
      print('❌ Error skipping to next: $e');
    }
  }

  Future<void> _loadAllSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString('stored_songs') ?? '[]';
      final List<dynamic> decodedSongs = json.decode(songsJson);
      _allSongs =
          decodedSongs.map((song) => Map<String, String>.from(song)).toList();

      if (_currentSongPath != null) {
        _currentSongIndex =
            _allSongs.indexWhere((song) => song['path'] == _currentSongPath);
      }
      print(
          '📚 Loaded ${_allSongs.length} songs, current index: $_currentSongIndex');
    } catch (e) {
      print('❌ Error loading songs: $e');
      _allSongs = [];
      _currentSongIndex = -1;
    }
  }

  Future<void> _saveSongToStorage(String title, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString('stored_songs') ?? '[]';
      final List<dynamic> songs = json.decode(songsJson);

      bool alreadyExists = songs.any((song) => song['path'] == path);
      if (!alreadyExists) {
        songs.add({
          'title': title,
          'path': path,
        });

        final updatedJson = json.encode(songs);
        await prefs.setString('stored_songs', updatedJson);
        print('💾 Song saved: $title (${songs.length} total songs)');
      } else {
        print('ℹ️ Song already exists in storage: $title');
      }
    } catch (e) {
      print('❌ Error saving song: $e');
    }
  }

  Future<void> _playSongFromStore(Map<String, String> song) async {
    try {
      final title = song['title'] ?? 'Unknown';
      final path = song['path'] ?? '';

      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Invalid song path'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _currentSongPath = path;
        _currentSongTitle = title;
      });

      await _audioPlayer?.setSourceDeviceFile(path);
      await Future.delayed(const Duration(milliseconds: 100));
      await _applyVolumeBoost(_volume);
      await _loadAllSongs();
      _currentSongIndex = _allSongs.indexWhere((s) => s['path'] == path);
      print('📍 Current song index updated to: $_currentSongIndex');

      await _audioPlayer?.resume();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.play_circle_filled,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('🎵 Now playing: $title'),
              ),
            ],
          ),
          backgroundColor: Colors.cyan,
          duration: const Duration(seconds: 2),
        ),
      );
      print('🎵 Playing from store: $title');
    } catch (e) {
      print('❌ Error playing song: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class VolumeRingPainter extends CustomPainter {
  final double volume;

  VolumeRingPainter(this.volume);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    final segmentCount = 48;
    final sweepAngle = (2 * math.pi) / segmentCount;

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = -math.pi / 2 + (i * sweepAngle);

      Color segmentColor;
      final ratio = i / segmentCount;

      if (ratio < 0.2) {
        segmentColor = const Color(0xFF00FF00); // Bright green
      } else if (ratio < 0.35) {
        segmentColor = const Color(0xFF7FFF00); // Lime green
      } else if (ratio < 0.5) {
        segmentColor = const Color(0xFFFFFF00); // Yellow
      } else if (ratio < 0.65) {
        segmentColor = const Color(0xFFFFD700); // Gold/Yellow-Orange
      } else if (ratio < 0.8) {
        segmentColor = const Color(0xFFFF8C00); // Orange
      } else {
        segmentColor = const Color(0xFFFF0000); // Red
      }

      final isActive = i < (volume / 200 * segmentCount);

      final paint = Paint()
        ..color = isActive ? segmentColor : Colors.grey[850]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle * 0.85, // Gap between segments
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VolumeRingPainter oldDelegate) {
    return oldDelegate.volume != volume;
  }
}