// filepath: c:\Users\user\StudioProjects\untitled\lib\features\UI\screen\setting_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled/configs/AppConfigs.dart';
import 'package:untitled/features/UI/screen/PurchaseScreen.dart';
import 'package:untitled/features/UI/screen/utils/ThemeProvider.dart';
import 'package:untitled/features/UI/screen/utils/app_themes.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';
import '../controller/rewarded_ad_manager.dart';
import 'home_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  late SharedPreferencesService _prefsService;
  final RewardedAdManager _rewardedAdManager = RewardedAdManager();
  bool _isPremiumUser = false;
  bool _isLoading = true;
  String _premiumStatus = 'Free User';
  String _buildNumber = "Loading...";
  /// The In App Purchase plugin
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  // NOTE: You must also set up a StreamSubscription to listen to
  // InAppPurchase.instance.purchaseStream to handle purchase results.

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeInAppPurchase();
    _initPackageInfo();
  }

  Future<void> _initializeInAppPurchase() async {
    final ProductDetailsResponse response =
    await _inAppPurchase.queryProductDetails(
        <String>{ 'v.booster.weekly', 'v.booster.yearly'});
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
      });
      // NOTE: For robust App Review approval, ensure that if response.error is NOT null,
      // you show a non-freezing error message to the user.
    }
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _checkPremiumStatus();

    // Load rewarded ad for non-premium users
    if (!_isPremiumUser) {
      _rewardedAdManager.loadRewardedAd();
    }
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

  @override
  void dispose() {
    _rewardedAdManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Colors.cyan,
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Status Card (FIXED: Now responsive)
              _buildPremiumStatusCard(),
              SizedBox(height: 24.h),

              // Settings Section
              Text(
                'General',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12.h),

          // IconButton(
          //   icon: const Icon(Icons.palette_outlined),
          //   tooltip: 'Change Theme',
          //   onPressed: () => _showThemeBottomSheet(context),
          // ),
              // Restore Purchase
              _buildSettingTile(
                icon: Icons.restore,
                title: 'Restore Purchase',
                subtitle: 'Restore your premium access',
                iconColor: Colors.orange,
                onTap: _handleRestorePurchase,
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp),
              ),

              // Remove Subscription
              if (_isPremiumUser) _buildSettingTile(
                icon: Icons.unsubscribe,
                title: 'Remove Subscription',
                subtitle: 'Cancel your premium subscription',
                iconColor: Colors.redAccent,
                onTap: _handleRemoveSubscription,
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp),
              ),

              SizedBox(height: 24.h),

              // Information Section
              Text(
                'Information',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12.h),

              // Terms and Conditions
              _buildSettingTile(
                icon: Icons.description,
                title: 'Terms and Conditions',
                subtitle: 'Read our terms of service',
                iconColor: Colors.blue,
                onTap: _openTermsAndConditions,
                trailing: Icon(Icons.open_in_new, color: Colors.grey, size: 16.sp),
              ),

              // Privacy Policy
              _buildSettingTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                iconColor: Colors.green,
                onTap: _openPrivacyPolicy,
                trailing: Icon(Icons.open_in_new, color: Colors.grey, size: 16.sp),
              ),

              // About App
              _buildSettingTile(
                icon: Icons.info,
                title: 'About App',
                subtitle: 'Version $_buildNumber',
                iconColor: Colors.purple,
                onTap: _showAboutDialog,
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp),
              ),

              SizedBox(height: 24.h),

              // Support Section
              Text(
                'Support',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12.h),

              // Rate App
              _buildSettingTile(
                icon: Icons.star,
                title: 'Rate App',
                subtitle: 'Rate us on Play Store',
                iconColor: Colors.amber,
                onTap: _rateApp,
                trailing: Icon(Icons.open_in_new, color: Colors.grey, size: 16.sp),
              ),

              // Contact Us
              _buildSettingTile(
                icon: Icons.email,
                title: 'Contact Us',
                subtitle: 'Send us your feedback',
                iconColor: Colors.cyan,
                onTap: _contactUs,
                trailing: Icon(Icons.open_in_new, color: Colors.grey, size: 16.sp),
              ),

              // Share App
              _buildSettingTile(
                icon: Icons.share,
                title: 'Share App',
                subtitle: 'Share with friends',
                iconColor: Colors.pink,
                onTap: _shareApp,
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp),
              ),

              SizedBox(height: 40.h),

              // Made with love footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Made with Ripan Hossain',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '© 2025 Volume Booster',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStatusCard() {
    return GestureDetector( // <--- FIX: ADDED GESTUREDETECTOR
      onTap: _isPremiumUser ? null : _handleRemoveAds, // <--- FIX: CALLS THE DIALOG
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: _isPremiumUser
              ? const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : LinearGradient(
            colors: [Colors.grey[800]!, Colors.grey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: _isPremiumUser
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPremiumUser ? Icons.workspace_premium : Icons.person,
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _premiumStatus,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _isPremiumUser
                        ? 'All premium features unlocked'
                        : 'Upgrade to unlock all features',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 8.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isPremiumUser)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 14.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        leading: SizedBox(
          width: 40.w, // ensure square container
          height: 40.w,
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: 20.sp,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12.sp,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  // ============ Action Handlers ============

  void _handleRemoveAds() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PurchaseScreen()),
    );
    // showDialog(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return Dialog(
    //       backgroundColor: const Color(0xFF16213E),
    //       shape: RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(20.r),
    //       ),
    //       child: Padding(
    //         padding: EdgeInsets.all(24.w),
    //         child: Column(
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             // Premium Icon
    //             Container(
    //               padding: EdgeInsets.all(16.w),
    //               decoration: const BoxDecoration(
    //                 shape: BoxShape.circle,
    //                 gradient: LinearGradient(
    //                   colors: [Colors.orange, Colors.deepOrange],
    //                 ),
    //               ),
    //               child: Icon(
    //                 Icons.block,
    //                 color: Colors.white,
    //                 size: 40.sp,
    //               ),
    //             ),
    //             SizedBox(height: 20.h),
    //
    //             Text(
    //               'Remove Ads',
    //               style: TextStyle(
    //                 color: Colors.white,
    //                 fontSize: 22.sp,
    //                 fontWeight: FontWeight.bold,
    //               ),
    //             ),
    //             SizedBox(height: 12.h),
    //
    //             Text(
    //               'Choose your premium option',
    //               textAlign: TextAlign.center,
    //               style: TextStyle(
    //                 color: Colors.grey,
    //                 fontSize: 14.sp,
    //               ),
    //             ),
    //             SizedBox(height: 24.h),
    //
    //             // Permanent Premium Button
    //             ElevatedButton(
    //               onPressed: () {
    //                 Navigator.of(context).pop();
    //                 _purchasePermanentPremium();
    //               },
    //               style: ElevatedButton.styleFrom(
    //                 backgroundColor: Colors.orange,
    //                 padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 14.h),
    //                 shape: RoundedRectangleBorder(
    //                   borderRadius: BorderRadius.circular(25.r),
    //                 ),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Icon(Icons.workspace_premium, color: Colors.white, size: 20.sp),
    //                   SizedBox(width: 8.w),
    //                   Text(
    //                     // NOTE: Consider using productDetails[0].price here instead of hardcoded '$2.99'
    //                     'Premium - \$2.99',
    //                     style: TextStyle(
    //                       fontSize: 16.sp,
    //                       fontWeight: FontWeight.bold,
    //                       color: Colors.white,
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //             SizedBox(height: 12.h),
    //
    //             // Watch Ad for Temporary Premium
    //             OutlinedButton.icon(
    //               onPressed: () {
    //                 Navigator.of(context).pop();
    //                 _watchAdForPremium();
    //               },
    //               style: OutlinedButton.styleFrom(
    //                 side: BorderSide(color: Colors.cyan, width: 2.w),
    //                 padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
    //                 shape: RoundedRectangleBorder(
    //                   borderRadius: BorderRadius.circular(25.r),
    //                 ),
    //               ),
    //               icon: Icon(Icons.play_circle_outline, color: Colors.cyan, size: 20.sp),
    //               label: Text(
    //                 'Watch Ad (1 Hour Free)',
    //                 style: TextStyle(
    //                   fontSize: 14.sp,
    //                   fontWeight: FontWeight.w600,
    //                   color: Colors.cyan,
    //                 ),
    //               ),
    //             ),
    //             SizedBox(height: 12.h),
    //
    //             TextButton(
    //               onPressed: () => Navigator.of(context).pop(),
    //               child: Text(
    //                 'Cancel',
    //                 style: TextStyle(
    //                   color: Colors.grey,
    //                   fontSize: 14.sp,
    //                 ),
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     );
    //   },
    // );
  }

  Future<void> _purchasePermanentPremium() async {
    // ⚠️ CRITICAL: The code below is currently SIMULATING a purchase.
    // Replace this with actual IAP logic using InAppPurchase.instance.buyNonConsumable/buySubscription
    // and rely on the purchaseStream to finalize the premium status.

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      ),
    );

    // TODO: REPLACE this delay with actual IAP call and waiting for the purchase stream result
    await Future.delayed(const Duration(seconds: 2));

    await _prefsService.setPermanentPremium(true);
    await _checkPremiumStatus();

    Navigator.of(context).pop(); // Close loading dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
            SizedBox(width: 10.w),
            const Expanded(child: Text('🎉 Premium activated! Ads removed permanently.')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    print('✅ Permanent premium purchased (Simulated)');
  }

  Future<void> _watchAdForPremium() async {
    if (!_rewardedAdManager.isAdReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Loading ad, please wait...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

      await _rewardedAdManager.loadRewardedAd(
        onAdLoaded: () {
          _watchAdForPremium();
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
        await _checkPremiumStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Premium unlocked for 1 hour! Enjoy ad-free experience.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        print('✅ Temporary premium granted for 1 hour');
      },
      onAdDismissed: () {
        _rewardedAdManager.loadRewardedAd();
      },
    );
  }

  Future<void> _handleRestorePurchase() async {
    // ⚠️ CRITICAL: restorePurchases() is non-blocking.
    // The result comes via the purchaseStream, which should handle status updates.

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      ),
    );

    _inAppPurchase.restorePurchases();

    // TODO: REMOVE the synchronous check below after implementing the purchase stream listener
    // This synchronous logic must be removed after implementing the proper stream listener.
    await Future.delayed(const Duration(seconds: 2)); // Simulate waiting
    Navigator.of(context).pop(); // Close loading dialog

    final hasPermanent = await _prefsService.isPermanentPremium();

    if (hasPermanent) {
      await _checkPremiumStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 10.w),
              const Expanded(child: Text('✅ Premium purchase restored successfully!')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ℹ️ No previous purchase found.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // END TODO

    print('🔄 Restore purchase completed (Simulated)');
  }

  Future<void> _handleRemoveSubscription() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
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
                // Warning Icon
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                Text(
                  'Remove Subscription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                Text(
                  'Are you sure you want to cancel your premium subscription?\n\nYou will lose access to all premium features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 24.h),

                // Confirm Button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: Text(
                    'Yes, Remove',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
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

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      ),
    );

    // This simulation should be replaced by a call to manage/cancel the subscription
    // via a deep link to the App Store subscription management page.
    await Future.delayed(const Duration(seconds: 2));

    // Remove premium status
    await _prefsService.setPermanentPremium(false);
    await _prefsService.clearTemporaryPremium();
    await _checkPremiumStatus();

    if (mounted) Navigator.of(context).pop(); // Close loading dialog

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 10.w),
              const Expanded(child: Text('✅ Subscription removed successfully.')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    print('🔄 Subscription removed');
  }

  Future<void> _openTermsAndConditions() async {
    // TODO: Replace with your actual terms URL
    final Uri url = Uri.parse('https://sites.google.com/view/imagefitterms/home');

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showInfoDialog(
          'Terms and Conditions',
          'By using this app, you agree to our terms of service.\n\n'
              '1. Use the app responsibly\n'
              '2. Protect your hearing\n'
              '3. Follow local laws\n'
              '4. No warranty provided\n\n'
              'For full terms, visit: yourapp.com/terms',
        );
      }
    } catch (e) {
      _showInfoDialog(
        'Terms and Conditions',
        'By using this app, you agree to our terms of service.\n\n'
            '1. Use the app responsibly\n'
            '2. Protect your hearing\n'
            '3. Follow local laws\n'
            '4. No warranty provided\n\n'
            'For full terms, visit: yourapp.com/terms',
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // TODO: Replace with your actual privacy policy URL
    final Uri url = Uri.parse('https://sites.google.com/view/volumebooster001/home');

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showInfoDialog(
          'Privacy Policy',
          'We respect your privacy.\n\n'
              '• We don\'t collect personal data\n'
              '• We use ads for app support\n'
              '• Premium removes all ads\n'
              '• Audio files stay on your device\n\n'
              'For full policy, visit: yourapp.com/privacy',
        );
      }
    } catch (e) {
      _showInfoDialog(
        'Privacy Policy',
        'We respect your privacy.\n\n'
            '• We don\'t collect personal data\n'
            '• We use ads for app support\n'
            '• Premium removes all ads\n'
            '• Audio files stay on your device\n\n'
            'For full policy, visit: yourapp.com/privacy',
      );
    }
  }

  // Asynchronous function to get the package info
  Future<void> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();

    setState(() {
      // info.buildNumber gives you the version code (e.g., "1")
      _buildNumber = info.version;

      // You can also get other info:
      // String versionName = info.version; // e.g., "1.0.0"
      // String appName = info.appName;
      // String packageName = info.packageName;
    });
  }

  void _showAboutDialog() {
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
                // App Icon
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.cyan, Colors.blue],
                    ),
                  ),
                  child: Icon(
                    Icons.volume_up,
                    color: Colors.white,
                    size: 48.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                Text(
                  AppConfigs.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),

                Text(
                  'Version Code $_buildNumber',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                Text(
                  'Boost your audio volume up to 200%!\n\n'
                      'Features:\n'
                      '• Volume Booster (up to 200%)\n'
                      '• Equalizer Controls\n'
                      '• Custom Ringtones\n'
                      '• Audio File Support\n'
                      '• Ad-Free Premium Option',
                  textAlign: TextAlign.center,
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
                    padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
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
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ==== Newly Provided/Completed Helper Functions ====

  Future<void> _rateApp() async {
    // TODO: Implement actual store link for rating
    print('Rate App tapped - Launching Store Link...');
    final url = Uri.parse(Platform.isIOS ? 'https://apps.apple.com/app/id6754565249?action=write-review' : 'market://details?id=YOUR_PACKAGE_NAME');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showInfoDialog('Rate App Failed', 'Could not launch store link. Please try again later.');
    }
  }

  Future<void> _contactUs() async {
    // TODO: Replace with your actual support email
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'ripohassan5@gmail.com',
      query: encodeQueryParameters(<String, String>{
        'subject': 'Support Request: Volume Booster v$_buildNumber',
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showInfoDialog('Contact Failed', 'Could not launch email app. Please email us at support@yourappname.com');
    }
  }

  Future<void> _shareApp() async {
    // TODO: Replace with your app's actual share URL
    await Share.share(
      'Check out this awesome Volume Booster app! Download it here: [YOUR APP STORE LINK HERE]',
      subject: 'Share Volume Booster App',
    );
  }

  // Helper to encode parameters for the mailto URL
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  // Helper function for showing simple dialogs (used in URL error handling)
  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 18.sp)),
        content: Text(content, style: TextStyle(color: Colors.grey[300], fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.cyan, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

}
void _showThemeBottomSheet(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // better for long lists
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Theme',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Theme List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: AppTheme.values.length,
                  itemBuilder: (context, index) {
                    final theme = AppTheme.values[index];
                    final themeData = appThemeData[theme]!;
                    final isSelected = theme == themeProvider.currentTheme;

                    final primaryColor = themeData.colorScheme?.primary ?? Colors.grey;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor,
                        radius: 14,
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                      title: Text(
                        _beautifyThemeName(theme.name),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      onTap: () {
                        themeProvider.setTheme(theme);
                        Navigator.pop(context); // close bottom sheet
                        // Optional: show a small snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Theme changed to ${_beautifyThemeName(theme.name)}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

String _beautifyThemeName(String name) {
  // Convert camelCase to Title Case with spaces
  return name
      .replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ${match.group(0)}')
      .split(' ')
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
