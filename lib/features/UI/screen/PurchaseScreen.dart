import '../controller/purchase_controller.dart';
import '../controller/AppLovinAds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:untitled/features/UI/screen/home_screen.dart';

import '../../../configs/AppConfigs.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final PurchaseController _purchases = PurchaseController.shared;
  final AppLovinAds _appLovinAds = AppLovinAds();

  bool _isPremiumUser = false;
  bool _isLoading = true;

  String _premiumStatus = 'Free User';
  // 0 = Weekly, 1 = Monthly, 2 = Yearly
  int _selectedIndex = 2;
  bool showSkip = true;
  bool _purchaseRequested = false;
  bool _isRewardAdStarting = false;

  // In-app purchase product IDs
  static const String _kWeeklyId = 'v.booster.weekly';
  static const String _kMonthlyId = 'v.booster.monthly';
  static const String _kYearlyId = 'v.booster.yearly';

  // Premium Colors
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color bgBlack = Color(0xFF050505);

  late SharedPreferencesService _prefsService;
  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
    _listenForPurchaseUpdated();
    _initializeServices();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await _prefsService.isPremiumUser();
      final isPermanent = await _prefsService.isPermanentPremium();
      final hasTemp = await _prefsService.hasTemporaryPremium();

      String status = 'Free User';
      if (isPermanent) {
        status = 'Premium User (Subscription)';
      } else if (hasTemp) {
        final remaining = await _prefsService.getRemainingPremiumTime();
        if (remaining != null) {
          final minutes = remaining.inMinutes;
          status = 'Premium User ($minutes min left)';
        }
      }

      if (!mounted) return;
      setState(() {
        _isPremiumUser = isPremium;
        _premiumStatus = status;
        _isLoading = false;
      });

      print('💎 Premium status: $status');
    } catch (e) {
      print('❌ Error checking premium status: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _checkPremiumStatus();
  }

  Future<void> _initializeInAppPurchase() async {
    try {
      await _purchases.loadProducts();
    } catch (error) {
      debugPrint('Store products unavailable: $error');
    }
  }

  Future<void> _buyProduct(String productId) async {
    try {
      _purchaseRequested = true;
      await _purchases.buy(productId);
    } catch (error) {
      _purchaseRequested = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase could not start: $error')),
        );
      }
    }
  }

  Future<void> _watchRewardedAd() async {
    if (_isRewardAdStarting || _isPremiumUser) return;
    setState(() => _isRewardAdStarting = true);
    _appLovinAds.onRewardedAdDismissed = () {
      if (mounted) setState(() => _isRewardAdStarting = false);
    };
    _appLovinAds.onRewardCallback = (amount) async {
      await _purchases.setRewardExpiry(
        DateTime.now().add(const Duration(hours: 1)),
      );
      if (!mounted) return;
      setState(() => _isRewardAdStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('One hour of temporary access unlocked.'),
          backgroundColor: Color(0xFF087D5D),
        ),
      );
    };

    final shown = await _appLovinAds.showRewardedAd();
    if (!mounted) return;
    if (!shown) {
      setState(() => _isRewardAdStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rewarded ad is not ready. Try again shortly.'),
        ),
      );
    }
  }

  bool _isRestoring = false;

  void _listenForPurchaseUpdated() {
    _purchases.addListener(_onPurchaseStateChanged);
  }

  void _onPurchaseStateChanged() {
    if (!mounted) return;
    setState(() {
      _isPremiumUser = _purchases.isPremium;
    });
    if (_purchaseRequested && _purchases.hasSubscription) {
      _purchaseRequested = false;
      _dismissScreen();
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;

    setState(() {
      _isRestoring = true;
    });

    _prefsService = await SharedPreferencesService.getInstance();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: neonCyan)),
      );
    }

    try {
      final bool available = _purchases.verifier.isConfigured;
      if (!available) {
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Store is not available right now. Please try again later.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await _purchases.restore();
      await Future.delayed(const Duration(seconds: 3));

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      final isPremium = await _prefsService.isPermanentPremium();
      if (!isPremium && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous active purchases found to restore.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error restoring purchases: $e");
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring purchases: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _dismissScreen() async {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchaseStateChanged);
    _appLovinAds.onRewardCallback = null;
    _appLovinAds.onRewardedAdDismissed = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> plans = [
      {
        "title": "Weekly",
        "price": "\$7.99",
        "period": "3 days free trial, then",
        "id": _kWeeklyId,
        "tag": null,
      },
      {
        "title": "Monthly",
        "price": "\$29.99",
        "period": "3 days free trial, then",
        "id": _kMonthlyId,
        "tag": null,
      },
      {
        "title": "Yearly",
        "price": "\$99.99",
        "period": "3 days free trial, then",
        "id": _kYearlyId,
        "tag": "BEST VALUE",
      },
    ];

    // Plans configuration moved inside build to access local variables if needed,
    // but neonCyan and bgBlack are now class-level constants.

    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. Subtle, Minimalist Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [neonCyan.withOpacity(0.12), backgroundColor],
                ),
              ),
            ),
          ),

          // 2. Main Layout
          SafeArea(
            child: Column(
              children: [
                // Header (Close Option)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _dismissScreen,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        // Golden Crown Icon
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: neonCyan,
                          size: 64.sp,
                        ),
                        SizedBox(height: 8.h),

                        // Title
                        Text(
                          "PRO ACCESS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 4.0,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        Text(
                          "Experience the true power of your audio.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Consolidated, core minimalist features
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPremiumFeature(
                              Icons.equalizer_rounded,
                              "Pro Graphic\nEqualizer & FX",
                            ),
                            SizedBox(width: 16.w),
                            _buildPremiumFeature(
                              Icons.bolt_rounded,
                              "Advanced Gain\n& Bass Boost",
                            ),
                            SizedBox(width: 16.w),
                            _buildPremiumFeature(
                              Icons.block_rounded,
                              "100%\nAd-Free",
                            ),
                          ],
                        ),

                        SizedBox(height: 24.h),

                        // Plans
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: plans.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 16.h),
                          itemBuilder: (context, index) =>
                              _buildPlanCard(index, plans[index], neonCyan),
                        ),

                        SizedBox(height: 260.h), // Spacing for sticky bottom
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Sticky Bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24.w, 80.h, 24.w, 30.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withOpacity(0.0),
                    backgroundColor.withOpacity(0.95),
                    backgroundColor,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main CTA Button
                  GestureDetector(
                    onTap: () {
                      _buyProduct(plans[_selectedIndex]['id']);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: neonCyan,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: neonCyan.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextButton.icon(
                    onPressed: _isRewardAdStarting || _isPremiumUser
                        ? null
                        : _watchRewardedAd,
                    icon: const Icon(Icons.ondemand_video_rounded),
                    label: Text(
                      _isRewardAdStarting
                          ? 'LOADING REWARDED AD…'
                          : 'WATCH AN AD FOR 1 HOUR ACCESS',
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Restore purchases
                  GestureDetector(
                    onTap: _isRestoring ? null : _restorePurchases,
                    child: Text(
                      "RESTORE PURCHASES",
                      style: TextStyle(
                        color: _isRestoring ? Colors.white24 : Colors.white54,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFooterLink("Terms of Use", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsCondition(),
                          ),
                        );
                      }),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 12.w),
                        width: 1,
                        height: 10.h,
                        color: Colors.white24,
                      ),
                      _buildFooterLink("Privacy Policy", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyAndSettingScreen(),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28.sp),
        SizedBox(height: 12.h),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 10.sp,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    int index,
    Map<String, dynamic> plan,
    Color goldAccent,
  ) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: isSelected ? neonCyan.withOpacity(0.04) : Colors.transparent,
          border: Border.all(
            color: isSelected ? neonCyan : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            // Radio Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? neonCyan : Colors.white30,
                  width: isSelected ? 6 : 1,
                ),
              ),
            ),
            SizedBox(width: 16.w),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan['title'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (plan['tag'] != null) ...[
                        SizedBox(width: 12.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: neonCyan,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            plan['tag'],
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    plan['period'],
                    style: TextStyle(
                      color: isSelected
                          ? neonCyan.withOpacity(0.8)
                          : Colors.white38,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              plan['price'],
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyAndSettingScreen extends StatelessWidget {
  const PrivacyAndSettingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(AppConfigs.privacyPolicy),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsCondition extends StatelessWidget {
  const TermsCondition({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(AppConfigs.eulaText),
            ),
          ],
        ),
      ),
    );
  }
}
