//
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:untitled/features/UI/screen/PurchaseScreen.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  late SharedPreferencesService _prefsService;

  bool _isPremiumUser = false;
  bool _navigationDone = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Initialize SharedPreferences service properly
    _prefsService = await SharedPreferencesService.getInstance();

    // Start listening before restorePurchases
    _listenForPurchaseUpdated();

    // Check locally saved premium status
    try {
      final bool savedPremium = await _prefsService.isPremiumUser();
      if (mounted) {
        setState(() {
          _isPremiumUser = savedPremium;
        });
      }
    } catch (e) {
      debugPrint('❌ Error reading premium status: $e');
    }

    // Small splash delay
    await Future.delayed(const Duration(seconds: 2));

    if (!_navigationDone) {
      _goToNextPage();
    }
  }

  void _listenForPurchaseUpdated() {
    _subscription = _inAppPurchase.purchaseStream.listen(
          (List<PurchaseDetails> purchaseDetailsList) {
        if (purchaseDetailsList.isEmpty) {
          debugPrint('ℹ️ No purchase updates found');
        }

        for (final purchaseDetails in purchaseDetailsList) {
          _handlePurchase(purchaseDetails);
        }
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint("❌ Purchase stream error: $error");
      },
    );
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    switch (purchaseDetails.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        debugPrint("✅ Subscription active for: ${purchaseDetails.productID}");

        // In production, verify purchase here before unlocking premium
        await _grantPremiumAccess();

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
          debugPrint("✅ Purchase completed");
        }
        break;

      case PurchaseStatus.error:
        debugPrint("❌ Purchase error: ${purchaseDetails.error?.message}");
        break;

      case PurchaseStatus.pending:
        debugPrint("⌛ Purchase pending...");
        break;

      case PurchaseStatus.canceled:
        debugPrint("⚠️ Purchase canceled by user");
        break;
    }
  }

  Future<void> _grantPremiumAccess() async {
    if (mounted) {
      setState(() {
        _isPremiumUser = true;
      });
    }

    await _prefsService.setPermanentPremium(true);

    if (!_navigationDone) {
      _goToNextPage();
    }
  }

  void _goToNextPage() {
    if (!mounted || _navigationDone) return;

    _navigationDone = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0),
                  radius: 1.2,
                  colors: [
                    primaryColor.withOpacity(0.08),
                    backgroundColor,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    width: 180.w,
                    height: 180.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Applogo(),
                  ),
                ),
                SizedBox(height: 48.h),
                // Premium Brand text
                Text(
                  "Volume Booster",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8.0,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "ALGORITHMIC AUDIO BOOST",
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 80.h),
                // Minimalist loading indicator
                SizedBox(
                  width: 40.w,
                  height: 2.h,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Applogo extends StatelessWidget {
  const Applogo({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_icon.png',
      height: height ?? 120.h,
      width: width ?? 120.w,
      fit: BoxFit.contain,
    );
  }
}