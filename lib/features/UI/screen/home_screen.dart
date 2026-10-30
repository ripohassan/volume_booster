import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:untitled/features/UI/screen/boost_screen.dart';
import 'package:untitled/features/UI/screen/equalizer_screen.dart';
import 'package:untitled/features/UI/screen/export_screen.dart';
import 'package:untitled/features/UI/screen/voice_booster_screen.dart';
import '../controller/AppLovinAds.dart';
import '../../../configs/AppConfigs.dart';
import 'setting_screen.dart';
import 'PurchaseScreen.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isPremiumUser = false;
  late SharedPreferencesService _prefsService;
  final AppLovinAds _appLovinAds = AppLovinAds();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String _selectedPlanId = 'v.booster.monthly';

  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color bgBlack = Color(0xFF050505);

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeInAppPurchase();
    _listenForPurchaseUpdated();
    _initAppLovin();
  }

  // ========== IAP ==========
  Future<void> _initializeInAppPurchase() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    // Do not automatically restore purchases on init, it causes hang on some platforms
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(<String>{'v.booster.weekly','v.booster.monthly', 'v.booster.yearly'});
    if (response.productDetails.isNotEmpty) {
      setState(() { _products = response.productDetails; });
    }
  }

  Future<void> _buyProduct(String productId) async {
    try {
      final productDetails = _products.firstWhere((prod) => prod.id == productId);
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) { debugPrint("❌ Subscription $productId not found."); }
  }

  void _listenForPurchaseUpdated() {
    _subscription = _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      for (var pd in purchaseDetailsList) { _handlePurchase(pd); }
    }, onDone: () { _subscription?.cancel(); }, onError: (error) { debugPrint("❌ Subscription stream error: $error"); });
  }

  Future<void> _handlePurchase(PurchaseDetails pd) async {
    if (pd.status == PurchaseStatus.purchased || pd.status == PurchaseStatus.restored) {
      await _grantPremiumAccess();
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      if (pd.pendingCompletePurchase) await _inAppPurchase.completePurchase(pd);
    } else if (pd.status == PurchaseStatus.error) {
      debugPrint("❌ Subscription Error: ${pd.error?.message}");
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    }
  }

  Future<void> _grantPremiumAccess() async {
    setState(() { _isPremiumUser = true; });
    await _prefsService.setPermanentPremium(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.workspace_premium, color: Colors.white), SizedBox(width: 10), Text('🎉 Premium features unlocked! Ads removed.')]), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
    }
  }

  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;
    setState(() { _isRestoring = true; });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
      ),
    );

    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Store is not available right now. Please try again later.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await _inAppPurchase.restorePurchases();
      await Future.delayed(const Duration(seconds: 3));

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      final isPremium = await _prefsService.isPermanentPremium();
      if (!isPremium && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ No previous purchase found to restore.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
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
        setState(() { _isRestoring = false; });
      }
    }
  }


  Future<void> _initAppLovin() async {
    // Already initialized in main.dart, just need to set up listeners and load ads
    await _appLovinAds.initialize(AppConfigs.appLovinSdkKey);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final isPremium = await _prefsService.isPremiumUser();
      setState(() { _isPremiumUser = isPremium; });
    } catch (e) { /* noop */ }
  }

  void _showSubscriptionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PurchaseScreen()),
    ).then((_) => _loadPremiumStatus());
  }

  Widget _buildSubOption(StateSetter setDialogState, String planId, String title, String price, Color neonCyan) {
    final selected = _selectedPlanId == planId;
    return InkWell(
      onTap: () { setDialogState(() { _selectedPlanId = planId; }); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? neonCyan.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? neonCyan : Colors.white12, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18.w, height: 18.w,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? neonCyan : Colors.white30, width: selected ? 5 : 1)),
            ),
            SizedBox(width: 12.w),
            Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            const Spacer(),
            Text(price, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  String _getProductPrice(String productId, String defaultPrice) {
    try { return _products.firstWhere((p) => p.id == productId).price; } catch (e) { return defaultPrice; }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle, color: Colors.orange, size: 18),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BoostScreen(isPremiumUser: _isPremiumUser, onShowSubscription: _showSubscriptionDialog),
          EqualizerScreen(isPremiumUser: _isPremiumUser, onShowSubscription: _showSubscriptionDialog),
          VoiceBoosterScreen(isPremiumUser: _isPremiumUser, onShowSubscription: _showSubscriptionDialog),
          ExportScreen(isPremiumUser: _isPremiumUser, onShowSubscription: _showSubscriptionDialog),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _appLovinAds.buildBannerAd(isPremium: _isPremiumUser),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildNavItem(0, Icons.bolt_rounded, 'Boost'),
            _buildNavItem(1, Icons.graphic_eq_rounded, 'Equalizer'),
            _buildNavItem(2, Icons.record_voice_over_rounded, 'Voice'),
            _buildNavItem(3, Icons.upload_rounded, 'Export'),
            _buildSettingsButton(),
          ]),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
          // Show interstitial ad on tab switches for non-premium users
          if (!_isPremiumUser) {
            _appLovinAds.onTabSwitch();
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00D4FF).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? const Color(0xFF00D4FF) : Colors.white30, size: 24.sp),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(color: selected ? const Color(0xFF00D4FF) : Colors.white30, fontSize: 10.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingScreen()));
        await _loadPremiumStatus();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.settings_rounded, color: Colors.white30, size: 24.sp),
          SizedBox(height: 4.h),
          Text('Settings', style: TextStyle(color: Colors.white30, fontSize: 10.sp, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}