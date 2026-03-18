//
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:untitled/features/UI/screen/PurchaseScreen.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';
import 'home_screen.dart';
//
//
//
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   final InAppPurchase _inAppPurchase = InAppPurchase.instance;
//   StreamSubscription<List<PurchaseDetails>>? _subscription;
//   bool _isPremiumUser = false;
//   late SharedPreferencesService _prefsService;
//
//   @override
//   void initState() {
//     super.initState();
//     _listenForPurchaseUpdated();
//
//   }
//   void _listenForPurchaseUpdated() {
//     _subscription =
//         _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
//           for (var purchaseDetails in purchaseDetailsList) {
//             _handlePurchase(purchaseDetails);
//           }
//         }, onDone: () {
//           _subscription?.cancel();
//         }, onError: (error) {
//           print("❌ Subscription stream error: $error");
//         });
//   }
//
//   /// This function handles the status of a subscription transaction
//   Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
//     if (purchaseDetails.status == PurchaseStatus.purchased ||
//         purchaseDetails.status == PurchaseStatus.restored) {
//       // This handles both a new subscription and a restored subscription
//       print("✅ Subscription active for: ${purchaseDetails.productID}");
//
//       // 1. Give the user premium access
//       await _grantPremiumAccess();
//
//
//       // 3. This is CRITICAL for Apple. You must complete the transaction.
//       if (purchaseDetails.pendingCompletePurchase) {
//         await _inAppPurchase.completePurchase(purchaseDetails);
//         print("✅ Subscription transaction completed.");
//       }
//     } else if (purchaseDetails.status == PurchaseStatus.error) {
//       print("❌ Subscription Error: ${purchaseDetails.error?.message}");
//       if (Navigator.canPop(context)) {
//         Navigator.of(context).pop();
//       }
//     } else if (purchaseDetails.status == PurchaseStatus.pending) {
//       print("⌛ Subscription purchase pending...");
//       // You can show a loading indicator here
//     }
//   }
//   Future<void> _grantPremiumAccess() async {
//     // Legacy AdMob cleanup if still active
//
//     setState(() {
//       _isPremiumUser = true;
//     });
//
//     // 2. Persist the state
//     await _prefsService.setPermanentPremium(true);
//     _goToNextPage();
//   }
//
//
//   Future<void> _goToNextPage() async {
//     // Show splash for 2 seconds
//     await Future.delayed(const Duration(seconds: 2));
//     // Navigate to HomeScreen using standard Flutter navigation
//     if (mounted) {
//
//       if (_isPremiumUser) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const HomeScreen()),
//         );
//       }else{
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const PurchaseScreen()),
//         );
//       }
//
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.white, Colors.blue],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child:  Center(
//           child: SizedBox(
//             width: 305.w,
//             height: 305.h,
//             child: Applogo(),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
//
//
// class Applogo extends StatelessWidget {
//   const Applogo({super.key, this.width, this.height});
//
//   final double? width;
//   final double? height;
//
//   @override
//   Widget build(BuildContext context) {
//     return Image.asset(
//       'assets/images/Volumix-png.png',
//       height: height ?? 120.h,
//       width: width ?? 120.w,
//       fit: BoxFit.contain,
//     );
//   }
// }

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

    // Restore old purchases/subscriptions
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (available) {
        await _inAppPurchase.restorePurchases();
      } else {
        debugPrint('⚠️ Store not available');
      }
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
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
        builder: (context) =>
        _isPremiumUser ? const HomeScreen() : const PurchaseScreen(),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 305.w,
            height: 305.h,
            child: const Applogo(),
          ),
        ),
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
      'assets/images/Volumix-png.png',
      height: height ?? 120.h,
      width: width ?? 120.w,
      fit: BoxFit.contain,
    );
  }
}