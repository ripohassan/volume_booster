import '../controller/purchase_controller.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:untitled/features/UI/screen/boost_screen.dart';
import 'package:untitled/features/UI/screen/equalizer_screen.dart';
import 'package:untitled/features/UI/screen/export_screen.dart';
import 'package:untitled/features/UI/screen/voice_lab_screen.dart';
import 'package:untitled/features/UI/screen/audio_studio_screen.dart';
import 'package:untitled/features/UI/screen/audio_analyzer_screen.dart';
import 'package:untitled/features/UI/screen/sound_control_screen.dart';
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
  int _soundNavigationVersion = 0;
  bool _isPremiumUser = false;
  late SharedPreferencesService _prefsService;
  final AppLovinAds _appLovinAds = AppLovinAds();

  final PurchaseController _purchases = PurchaseController.shared;
  List<ProductDetails> _products = [];

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
    try {
      final products = await _purchases.loadProducts();
      if (mounted) setState(() => _products = products);
    } catch (error) {
      debugPrint('Store products unavailable: $error');
    }
  }

  Future<void> _buyProduct(String productId) async {
    try {
      await _purchases.buy(productId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase could not start: $error')),
        );
      }
    }
  }

  void _listenForPurchaseUpdated() {
    _purchases.addListener(_onPurchaseStateChanged);
  }

  void _onPurchaseStateChanged() {
    if (!mounted) return;
    setState(() {
      _isPremiumUser = _purchases.isPremium;
    });
  }

  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
      ),
    );

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
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _initAppLovin() async {
    // Already initialized in main.dart, just need to set up listeners and load ads
    await _appLovinAds.initialize(AppConfigs.appLovinSdkKey);
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchaseStateChanged);
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final isPremium = await _prefsService.isPremiumUser();
      if (mounted)
        setState(() {
          _isPremiumUser = isPremium;
        });
    } catch (e) {
      /* noop */
    }
  }

  void _showSubscriptionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PurchaseScreen()),
    ).then((_) => _loadPremiumStatus());
  }

  Widget _buildSubOption(
    StateSetter setDialogState,
    String planId,
    String title,
    String price,
    Color neonCyan,
  ) {
    final selected = _selectedPlanId == planId;
    return InkWell(
      onTap: () {
        setDialogState(() {
          _selectedPlanId = planId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? neonCyan.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? neonCyan : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? neonCyan : Colors.white30,
                  width: selected ? 5 : 1,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              price,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductPrice(String productId, String defaultPrice) {
    try {
      return _products.firstWhere((p) => p.id == productId).price;
    } catch (e) {
      return defaultPrice;
    }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = [
          SoundControlScreen(
            key: ValueKey(_soundNavigationVersion),
            isPremiumUser: _isPremiumUser,
            onShowSubscription: _showSubscriptionDialog,
          ),
          AudioStudioScreen(
            isPremiumUser: _isPremiumUser,
            onShowSubscription: _showSubscriptionDialog,
          ),
          VoiceLabScreen(
            isPremiumUser: _isPremiumUser,
            onShowSubscription: _showSubscriptionDialog,
          ),
          const AudioAnalyzerScreen(),
        ];
        final destinations = const [
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Sound',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over),
            label: 'Voice Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analyzer',
          ),
        ];
        final select = (int index) {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
              if (index == 0) _soundNavigationVersion++;
            });
            if (!_isPremiumUser) {
              _appLovinAds.onTabSwitch();
            }
          }
        };
        final compact = constraints.maxWidth < 700;
        final content = IndexedStack(index: _currentIndex, children: pages);
        return Scaffold(
          backgroundColor: const Color(0xFF050A16),
          extendBody: compact,
          body: compact
              ? content
              : Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.all,
                      leading: IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingScreen(),
                          ),
                        ),
                      ),
                      destinations: destinations
                          .map(
                            (d) => NavigationRailDestination(
                              icon: d.icon,
                              selectedIcon: d.selectedIcon,
                              label: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                ),
          floatingActionButton: compact
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DD1FF), Color(0xFF177CE8)],
                    ),
                  ),
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF04233F),
                    elevation: 0,
                    tooltip: 'Settings',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingScreen()),
                    ),
                    child: const Icon(Icons.settings_rounded),
                  ),
                )
              : null,
          bottomNavigationBar: compact
              ? Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF17608F))),
                    gradient: LinearGradient(
                      colors: [Color(0xFF081F36), Color(0xFF041222)],
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: select,
                    destinations: destinations,
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.library_music_rounded, 'Studio'),
              _buildNavItem(1, Icons.bolt_rounded, 'Boost'),
              _buildNavItem(2, Icons.graphic_eq_rounded, 'Equalizer'),
              _buildNavItem(3, Icons.record_voice_over_rounded, 'Voice'),
              _buildNavItem(4, Icons.upload_rounded, 'Export'),
              _buildSettingsButton(),
            ],
          ),
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
        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00D4FF).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF00D4FF) : Colors.white30,
              size: 24.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF00D4FF) : Colors.white30,
                fontSize: 10.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingScreen()),
        );
        await _loadPremiumStatus();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded, color: Colors.white30, size: 24.sp),
            SizedBox(height: 4.h),
            Text(
              'Settings',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
