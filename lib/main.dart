import 'package:applovin_max/applovin_max.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'configs/AppConfigs.dart';
import 'features/UI/screen/splash_screen.dart';
import 'features/UI/screen/utils/ThemeProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize App Tracking Transparency for iOS
  if (Platform.isIOS) {
    await _initATT();
  }

  // Initialize Ad Network (AppLovin MAX)
  if (Platform.isAndroid || Platform.isIOS) {
    MaxConfiguration? configuration = await AppLovinMAX.initialize(AppConfigs.appLovinSdkKey);
    if (configuration != null) {
      debugPrint('✅ AppLovin initialized successfully');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _initATT() async {
  try {
    final TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // Show a custom explanation dialog here if needed before the official prompt
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('❌ ATT Error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: AppConfigs.appName,
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          home: child,
        );
      },
      child: const SplashScreen(),
    );
  }
}

