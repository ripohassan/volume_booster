import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:untitled/features/UI/screen/home_screen.dart';

import '../../../configs/AppConfigs.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

// class SubscriptionScreen extends StatefulWidget {
//   const SubscriptionScreen({super.key});
//
//   @override
//   State<SubscriptionScreen> createState() => _SubscriptionScreenState();
// }
//
// class _SubscriptionScreenState extends State<SubscriptionScreen> {
//   // --- IAP State Variables ---
//   final InAppPurchase _inAppPurchase = InAppPurchase.instance;
//   late StreamSubscription<List<PurchaseDetails>> _subscription;
//   List<ProductDetails> _products = [];
//   bool _isAvailable = false;
//   bool _loading = true;
//   String? _queryError;
//
//   // PRODUCT CONFIGURATION (App Store Connect IDs)
//   static const String _kWeeklyId = 'npdf_pro_weekly';
//   static const String _kMonthlyId = 'npdf_pro_monthly';
//   static const String _kYearlyId = 'npdf_pro_yearly';
//
//   final Set<String> _productIds = {
//     _kWeeklyId,
//     _kMonthlyId,
//     _kYearlyId,
//   };
//
//   // 0 = Weekly, 1 = Monthly, 2 = Yearly
//   int _selectedIndex = 2;
//
//   // UI Configuration
//   final List<Map<String, dynamic>> _plansUiData = [
//     {
//       "id": _kWeeklyId,
//       "title": "Weekly",
//       "fallbackPrice": "\$4.99",
//       "subtitle": "3 days tail then",
//       "tag": null,
//     },
//     {
//       "id": _kMonthlyId,
//       "title": "Monthly",
//       "fallbackPrice": "\$12.99",
//       "subtitle": "3 days tail then",
//       "tag": "POPULAR",
//     },
//     {
//       "id": _kYearlyId,
//       "title": "Yearly",
//       "fallbackPrice": "\$49.99",
//       "subtitle": "3 days tail then",
//       "tag": "BEST VALUE",
//       "savings": "Save 60%",
//     },
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//
//     final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
//     _subscription = purchaseUpdated.listen((purchaseDetailsList) {
//       _listenToPurchaseUpdated(purchaseDetailsList);
//     }, onDone: () {
//       _subscription.cancel();
//     }, onError: (error) {
//       debugPrint('IAP Stream Error: $error');
//     });
//
//     _initializeIAP();
//   }
//
//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }
//
//   // --- IAP Logic Methods ---
//
//   Future<void> _initializeIAP() async {
//     final bool isAvailable = await _inAppPurchase.isAvailable();
//     setState(() {
//       _isAvailable = isAvailable;
//     });
//
//     if (!isAvailable) {
//       setState(() {
//         _loading = false;
//         _queryError = "Store not available";
//       });
//       return;
//     }
//
//     final ProductDetailsResponse response =
//     await _inAppPurchase.queryProductDetails(_productIds);
//
//     if (response.error != null) {
//       setState(() {
//         _loading = false;
//         _queryError = response.error!.message;
//       });
//       return;
//     }
//
//     if (response.productDetails.isEmpty) {
//       setState(() {
//         _loading = false;
//         _queryError = "No products found";
//       });
//       return;
//     }
//
//     setState(() {
//       _products = response.productDetails;
//       _loading = false;
//     });
//   }
//
//   void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
//     for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
//       if (purchaseDetails.status == PurchaseStatus.pending) {
//         _showLoadingDialog();
//       } else {
//         if (Navigator.canPop(context)) Navigator.pop(context);
//
//         if (purchaseDetails.status == PurchaseStatus.error) {
//           _showError(purchaseDetails.error!);
//         } else if (purchaseDetails.status == PurchaseStatus.purchased ||
//             purchaseDetails.status == PurchaseStatus.restored) {
//           _deliverProduct(purchaseDetails);
//         }
//
//         if (purchaseDetails.pendingCompletePurchase) {
//           _inAppPurchase.completePurchase(purchaseDetails);
//         }
//       }
//     }
//   }
//
//   void _deliverProduct(PurchaseDetails purchaseDetails) {
//     debugPrint('Product purchased/restored: ${purchaseDetails.productID}');
//
//     // Cupertino Dialog for success
//     showCupertinoDialog(
//       context: context,
//       builder: (context) => CupertinoAlertDialog(
//         title: const Text("Success"),
//         content: const Text("Subscription active! You are now a Pro user."),
//         actions: [
//           CupertinoDialogAction(
//             isDefaultAction: true,
//             child: const Text("OK"),
//             onPressed: () => Navigator.pop(context),
//           )
//         ],
//       ),
//     );
//   }
//
//   void _showError(IAPError error) {
//     showCupertinoDialog(
//       context: context,
//       builder: (context) => CupertinoAlertDialog(
//         title: const Text("Purchase Failed"),
//         content: Text(error.message),
//         actions: [
//           CupertinoDialogAction(
//             child: const Text("OK"),
//             onPressed: () => Navigator.pop(context),
//           )
//         ],
//       ),
//     );
//   }
//
//   Future<void> _buyProduct() async {
//     final String selectedProductId = _plansUiData[_selectedIndex]['id'];
//
//     final ProductDetails? productDetails = _products.firstWhere(
//           (prod) => prod.id == selectedProductId,
//       orElse: () => null as ProductDetails,
//     );
//
//     if (productDetails == null) {
//       if (!_isAvailable || _products.isEmpty) {
//         // Fallback simulation for UI testing
//         showCupertinoDialog(
//             context: context,
//             builder: (ctx) => CupertinoAlertDialog(
//               title: const Text("Simulation"),
//               content: Text("Simulating purchase for $selectedProductId (Store Unavailable)"),
//               actions: [
//                 CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))
//               ],
//             )
//         );
//         return;
//       }
//       return;
//     }
//
//     final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
//     _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
//   }
//
//   Future<void> _restorePurchases() async {
//     await _inAppPurchase.restorePurchases();
//   }
//
//   void _showLoadingDialog() {
//     showCupertinoDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return const Center(child: CupertinoActivityIndicator(radius: 15));
//       },
//     );
//   }
//
//   // --- UI Build Methods ---
//
//   @override
//   Widget build(BuildContext context) {
//     return CupertinoPageScaffold(
//       navigationBar: CupertinoNavigationBar(
//         border: null, // Remove bottom border for cleaner look
//         backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
//         leading: CupertinoButton(
//           padding: EdgeInsets.zero,
//           onPressed: () => Get.offAll(() => NavigationMenu()),
//           child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.systemGrey, size: 24),
//         ),
//         trailing: CupertinoButton(
//           padding: EdgeInsets.zero,
//           onPressed: _restorePurchases,
//           child: const Text("Restore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//         ),
//       ),
//       child: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     const SizedBox(height: 10),
//
//                     // App Icon / Header
//                     Container(
//                       height: 80,
//                       width: 80,
//                       decoration: BoxDecoration(
//                         color: CupertinoColors.activeBlue.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(20), // iOS style rounded square
//                       ),
//                       child: const Icon(CupertinoIcons.doc_text_fill, size: 40, color: CupertinoColors.activeBlue),
//                     ),
//                     const SizedBox(height: 20),
//
//                     const Text(
//                       "Unlock NPDF PDF Editor Pro",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.w700,
//                         color: CupertinoColors.label,
//                         letterSpacing: -0.5,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     const Text(
//                       "Get unlimited access to all features without restrictions.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: CupertinoColors.secondaryLabel,
//                         height: 1.4,
//                       ),
//                     ),
//                   //  const SizedBox(height: 30),
//
//                     // Features using Cupertino Icons
//                    // _buildFeatureRow(CupertinoIcons.pencil_outline, "Edit Text & Images"),
//                   //  _buildFeatureRow(CupertinoIcons.signature, "Sign & Fill Forms"),
//                    // _buildFeatureRow(CupertinoIcons.cloud_upload, "Cloud Storage & Sync"),
//                    // _buildFeatureRow(CupertinoIcons.viewfinder, "Advanced OCR Scanning"),
//
//                     const SizedBox(height: 40),
//
//                     ...List.generate(_plansUiData.length, (index) => Padding(
//                       padding: const EdgeInsets.only(bottom: 16.0),
//                       child: _buildPlanCard(index),
//                     )),
//                     // // Display Plans
//                     // if (_loading)
//                     //   const Padding(
//                     //     padding: EdgeInsets.all(20.0),
//                     //     child: CupertinoActivityIndicator(),
//                     //   )
//                     // else if (_queryError != null && _products.isEmpty)
//                     //   ...List.generate(_plansUiData.length, (index) => Padding(
//                     //     padding: const EdgeInsets.only(bottom: 16.0),
//                     //     child: _buildPlanCard(index),
//                     //   ))
//                     // else
//                     //   ...List.generate(_plansUiData.length, (index) => Padding(
//                     //     padding: const EdgeInsets.only(bottom: 16.0),
//                     //     child: _buildPlanCard(index),
//                     //   )),
//                   ],
//                 ),
//               ),
//             ),
//
//             // Bottom Action Area
//             Container(
//               padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
//               decoration: BoxDecoration(
//                 color: CupertinoColors.systemBackground,
//                 border: const Border(top: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5)),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: CupertinoButton.filled(
//                       onPressed: _buyProduct,
//                       borderRadius: BorderRadius.circular(14),
//                       child: const Text(
//                         "Purchase",
//                         style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     "Recurring billing, cancel anytime.",
//                     style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _buildFooterLink("Terms of Service"),
//                       Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 12, color: CupertinoColors.systemGrey3),
//                       _buildFooterLink("Privacy Policy"),
//                     ],
//                   )
//                 ],
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFeatureRow(IconData icon, String text) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         children: [
//           const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: CupertinoColors.activeBlue, size: 22),
//           const SizedBox(width: 12),
//           Text(
//             text,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//               color: CupertinoColors.label,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFooterLink(String text) {
//     return GestureDetector(
//       onTap: () {},
//       child: Text(
//         text,
//         style: const TextStyle(
//           fontSize: 11,
//           color: CupertinoColors.systemGrey,
//           decoration: TextDecoration.none, // No underline is common in iOS footer links
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPlanCard(int index) {
//     final uiData = _plansUiData[index];
//     final productId = uiData['id'];
//     final isSelected = _selectedIndex == index;
//     final isBestValue = uiData['tag'] == "BEST VALUE";
//
//     ProductDetails? product;
//     try {
//       product = _products.firstWhere((p) => p.id == productId);
//     } catch (e) {
//       product = null;
//     }
//
//     final String displayPrice = product?.price ?? uiData['fallbackPrice'];
//
//     // Color logic
//     final borderColor = isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5;
//     final backgroundColor = isSelected ? CupertinoColors.activeBlue.withOpacity(0.08) : CupertinoColors.systemBackground;
//
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedIndex = index;
//         });
//         HapticFeedback.selectionClick();
//       },
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: backgroundColor,
//               border: Border.all(
//                 color: borderColor,
//                 width: isSelected ? 2 : 1.5,
//               ),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Row(
//               children: [
//                 // iOS Selection Circle
//                 Container(
//                   width: 24,
//                   height: 24,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.transparent,
//                     border: Border.all(
//                         color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey3,
//                         width: 1.5
//                     ),
//                   ),
//                   child: isSelected
//                       ? const Icon(CupertinoIcons.checkmark, size: 14, color: CupertinoColors.white)
//                       : null,
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         uiData['title'],
//                         style: TextStyle(
//                           fontSize: 17,
//                           fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
//                           color: CupertinoColors.label,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         uiData['subtitle'],
//                         style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     Text(
//                       displayPrice,
//                       style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                           color: CupertinoColors.label,
//                           letterSpacing: -0.5
//                       ),
//                     ),
//                     if (isBestValue && uiData['savings'] != null)
//                       Text(
//                         uiData['savings'],
//                         style: const TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                           color: CupertinoColors.systemOrange,
//                         ),
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           if (uiData['tag'] != null)
//             Positioned(
//               top: -10,
//               right: 12,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: isBestValue ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   uiData['tag'],
//                   style: const TextStyle(
//                     color: CupertinoColors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isPremiumUser = false;
  bool _isLoading = true;

  String _premiumStatus = 'Free User';
  // 0 = Weekly, 1 = Monthly, 2 = Yearly
  int _selectedIndex = 1;
  bool showSkip = false;

  // Define your IDs here
  static const String _kWeeklyId = 'v.booster.weekly'; // 'npdf_pro_weekly'
  static const String _kMonthlyId = 'v.booster.monthly'; // 'npdf_pro_yearly'
  static const String _kYearlyId = 'v.booster.yearly'; // 'npdf_pro_yearly'
  late SharedPreferencesService _prefsService;
  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
    _listenForPurchaseUpdated();
    _initializeServices();
    // Show close button after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showSkip = true;
        });
      }
    });
  }


  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await _prefsService.isPremiumUser();
      final isPermanent = await _prefsService.isPermanentPremium();
      final hasTemp = await _prefsService.hasTemporaryPremium();

      String status = 'Free User';
      if (isPermanent) {
        status = 'Premium User (Permanent)';
      } else if (hasTemp) {
        final remaining = await _prefsService.getRemainingPremiumTime();
        if (remaining != null) {
          final minutes = remaining.inMinutes;
          status = 'Premium User ($minutes min left)';
        }
      }

      setState(() {
        _isPremiumUser = isPremium;
        _premiumStatus = status;
        _isLoading = false;
      });

      print('💎 Premium status: $status');
    } catch (e) {
      print('❌ Error checking premium status: $e');
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
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) return;

    const Set<String> kIds = {_kWeeklyId,_kMonthlyId,_kYearlyId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

    if (mounted) {
      setState(() {
        _products = response.productDetails;
      });
    }
  }

  Future<void> _buyProduct(String productId) async {
    try {
      final ProductDetails productDetails = _products.firstWhere(
            (product) => product.id == productId,
        orElse: () => throw Exception("Product not found in loaded list"),
      );

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

      // Use buyNonConsumable for subscriptions
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint("Error buying product: $e");
      // Fallback for testing if product not found (e.g. emulator)

    }
  }

  void _listenForPurchaseUpdated() {
    _subscription = _inAppPurchase.purchaseStream.listen((List<PurchaseDetails> purchaseDetailsList) {
      for (var purchaseDetails in purchaseDetailsList) {
        if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _navigateToHome();
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
        }
      }
    }, onError: (error) {
      debugPrint("Purchase Error: $error");
    });
  }

  Future<void> _navigateToHome() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
    await Future.delayed(const Duration(seconds: 2));

    await _prefsService.setPermanentPremium(true);
    await _checkPremiumStatus();
  }
  Future<void> _navigateToHomeSkip() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI Data for the 3 plans
    final List<Map<String, dynamic>> plans = [
      {
        "title": "Weekly",
        "price": "\$4.99",
        "period": "3 days trail then",
        "id": _kWeeklyId,
        "tag": null
      },{
        "title": "Monthly",
        "price": "\$24.99",
        "period": "3 days trail then",
        "id": _kMonthlyId,
        "tag": null
      },
      {
        "title": "Yearly",
        "price": "\$49.99",
        "period": "3 days trail then",
        "id": _kYearlyId,
        "tag": "BEST VALUE" // Save % calc could go here
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background Design (Subtle Gradient)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF000000)],
                ),
              ),
            ),
          ),

          // 2. Background Blobs for modern feel
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
                //borderRadius: BorderRadius.all(Radius.circular(2.0)),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // --- Header / Close Button ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Restore Button (Left)

                        // InkWell(
                        //   onTap: () => _inAppPurchase.restorePurchases(),
                        //   child: const Text(
                        //     "Restore",
                        //     style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                        //   ),
                        // ),
                     // Spacer

                      // Close Button (Right) - visible based on timer
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: showSkip ? 1.0 : 0.0,
                        child: InkWell(
                          onTap: showSkip ? _navigateToHomeSkip : null,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Hero Section ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Icon
                        Image.asset(
                          "assets/images/Volumix-png.png",
                          width: 150.4.w,
                          height: 40.h,
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          "Upgrade to Volume Booster Pro",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Remove ads and unlock advanced editing tools.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white60),
                        ),

                        const SizedBox(height: 30),

                        // Features List
                        _buildFeatureItem(Icons.edit_document, "Edit your audio volume directly"),
                        //_buildFeatureItem(Icons.draw, "Sign Documents & Fill Forms"),
                        //_buildFeatureItem(Icons.scanner, "Unlimited OCR Scanning"),
                        _buildFeatureItem(Icons.block, "100% Ad-Free Experience"),

                        const SizedBox(height: 20),

                        // --- Subscription Cards ---
                        ...[
                          // Weekly
                          _buildPlanCard(0, plans[0]),
                          const SizedBox(height: 12),
                          // // Monthly
                          _buildPlanCard(1, plans[1]),
                          const SizedBox(height: 12),
                          // Yearly
                          _buildPlanCard(2, plans[2]),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.0), Colors.black],
                                  stops: const [0.0, 0.3]
                              )
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Main CTA
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _buyProduct(plans[_selectedIndex]['id']);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 10,
                                    shadowColor: Colors.blueAccent.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    'Start Subscription',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () => _inAppPurchase.restorePurchases(),
                                child: const Text(
                                  "Restore Purchase",
                                  style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),

                              const SizedBox(height: 16),
                              // Legal Links
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFooterLink("Terms of Use", () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsCondition()));
                                  }),
                                  Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 12, color: Colors.white24),
                                  _buildFooterLink("Privacy Policy", () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyAndSettingScreen()));
                                  }),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                       // const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Sticky Bottom Button

        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _buildPlanCard(int index, Map<String, dynamic> plan) {
    final isSelected = _selectedIndex == index;
    final isBestValue = plan['tag'] == "BEST VALUE";

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Radio Indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.blueAccent : Colors.transparent,
                  border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey, width: 2)
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      if (plan['tag'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBestValue ? Colors.orangeAccent : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan['tag'],
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      ]
                    ],
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan['price'],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  plan['period'],
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            )
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
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(AppConfigs.privacyPolicy),
            )
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
      appBar: AppBar(
        title: const Text('Terms of Use'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(AppConfigs.eulaText),
            )
          ],
        ),
      ),
    );
  }

}