import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:untitled/features/UI/screen/home_screen.dart';

import '../../../configs/AppConfigs.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';



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
                                    print(plans[_selectedIndex]['id'].toString());
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