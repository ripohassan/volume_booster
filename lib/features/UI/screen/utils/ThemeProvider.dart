import 'package:flutter/material.dart';
import 'package:untitled/features/UI/screen/utils/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = appThemeData[AppTheme.blueDark]!;

  ThemeData get currentTheme => _currentTheme;

  void setTheme(AppTheme theme) {
    _currentTheme = appThemeData[theme]!;
    notifyListeners(); // This triggers the UI to rebuild
  }
}