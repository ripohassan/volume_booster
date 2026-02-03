import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:applovin_max/applovin_max.dart'; // Uncomment when AppLovin SDK is added
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';
import 'core/service/shared_preferance/Shared_Preferences.dart';
import 'features/UI/screen/home_screen.dart';
import 'configs/AppConfigs.dart';
import 'features/UI/screen/splash_screen.dart';
import 'features/UI/screen/utils/ThemeProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ad network based on AppConfigs.adMobsAd flag


  //await AppLovinMAX.initialize(AppConfigs.appLovinSdkKey);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
  // runApp(const MyApp());
  // DevicePreview(
  //   enabled: !kReleaseMode,
  //   builder: (context) => MyApp(),
  // ));
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

