import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/configs/AppConfigs.dart';
import 'package:untitled/features/UI/screen/splash_screen.dart';
import 'package:untitled/features/UI/screen/utils/ThemeProvider.dart';
import 'package:untitled/features/UI/screen/utils/app_themes.dart';
import 'package:untitled/main.dart';

void main() {
  testWidgets('App opens its themed splash while the store connects', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    // A widget smoke test has no native billing service. Keep its connection
    // pending; purchase behavior belongs in device/store integration tests.
    const billingChannel =
        'dev.flutter.pigeon.in_app_purchase_android.InAppPurchaseApi.startConnection';
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      billingChannel,
      (_) => Completer<ByteData?>().future,
    );
    addTearDown(() => messenger.setMockMessageHandler(billingChannel, null));

    final themeProvider = ThemeProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: themeProvider, child: const MyApp()),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Applogo), findsOneWidget);
    expect(find.text(AppConfigs.appName), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
      themeProvider.currentTheme,
    );
    expect(tester.takeException(), isNull);

    themeProvider.setTheme(AppTheme.greenLight);
    await tester.pump();
    await tester.pump(kThemeAnimationDuration);
    expect(
      Theme.of(tester.element(find.byType(SplashScreen))).brightness,
      Brightness.light,
    );

    // Dispose the splash and drain its existing two-second navigation delay
    // without starting the native audio, advertising, or store workflows.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    themeProvider.dispose();
    expect(tester.takeException(), isNull);
  });
}
