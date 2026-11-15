import 'package:applovin_max/applovin_max.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'configs/AppConfigs.dart';
import 'features/UI/screen/splash_screen.dart';
import 'features/UI/screen/utils/ThemeProvider.dart';
import 'features/UI/screen/utils/app_themes.dart';
import 'core/service/audio_processing_backend.dart';
import 'core/service/audio_project_repository.dart';
import 'core/service/audio_service.dart';
import 'core/service/audio_waveform_service.dart';
import 'core/service/audio_analysis_backend.dart';
import 'features/UI/controller/audio_project_controller.dart';
import 'features/UI/controller/audio_analyzer_controller.dart';
import 'features/UI/controller/purchase_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider(create: (_) => AudioProjectRepository()),
        Provider(create: (_) => AudioWaveformService()),
        Provider<AudioProcessingBackend>(
          create: (_) => FFmpegAudioProcessingBackend(),
        ),
        ChangeNotifierProvider(
          create: (context) => AudioProjectController(
            repository: context.read<AudioProjectRepository>(),
            backend: context.read<AudioProcessingBackend>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AudioAnalyzerController(
            projects: context.read<AudioProjectController>(),
            backend: PcmAudioAnalysisBackend(
              context.read<AudioWaveformService>(),
            ),
          ),
        ),
        ChangeNotifierProvider.value(value: AudioService()),
        ChangeNotifierProvider.value(value: PurchaseController.shared),
      ],
      child: const MyApp(),
    ),
  );

  // Third-party SDK initialization must not prevent Flutter from rendering.
  unawaited(_initializePlatformServices());
}

Future<void> _initializePlatformServices() async {
  // Initialize App Tracking Transparency for iOS
  if (Platform.isIOS) {
    await _initATT();
  }

  // Initialize Ad Network (AppLovin MAX)
  if (Platform.isAndroid || Platform.isIOS) {
    MaxConfiguration? configuration = await AppLovinMAX.initialize(
      AppConfigs.appLovinSdkKey,
    );
    if (configuration != null) {
      debugPrint('✅ AppLovin initialized successfully');
    }
  }
}

Future<void> _initATT() async {
  try {
    final TrackingStatus status =
        await AppTrackingTransparency.trackingAuthorizationStatus;
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
          darkTheme: appThemeData[AppTheme.blueDark],
          themeMode: themeProvider.mode,
          home: child,
        );
      },
      child: const SplashScreen(),
    );
  }
}
