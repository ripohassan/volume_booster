import '../controller/purchase_controller.dart';
//

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PurchaseController _purchases = PurchaseController.shared;


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
    if (!mounted) return;

    // Start listening before restorePurchases
    _listenForPurchaseUpdated();
    await _purchases.initialize();
    if (!mounted) return;

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

    if (!mounted) return;

    // Small splash delay
    await Future.delayed(const Duration(seconds: 2));

    if (!_navigationDone) {
      _goToNextPage();
    }
  }

  void _listenForPurchaseUpdated() {
    _purchases.addListener(_onPurchaseStateChanged);
  }

  void _onPurchaseStateChanged() {
    if (mounted) setState(() => _isPremiumUser = _purchases.isPremium);
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
    _purchases.removeListener(_onPurchaseStateChanged);
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