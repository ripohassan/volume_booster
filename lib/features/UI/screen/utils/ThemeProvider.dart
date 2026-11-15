import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/UI/screen/utils/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = appThemeData[AppTheme.blueDark]!;
  ThemeMode _mode = ThemeMode.system;

  ThemeProvider() {
    _restore();
  }

  ThemeData get currentTheme => _currentTheme;
  ThemeMode get mode => _mode;
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('app_theme');
    final mode = prefs.getString('theme_mode');
    if (theme != null)
      _currentTheme =
          appThemeData[AppTheme.values.byName(theme)] ?? _currentTheme;
    if (mode != null) _mode = ThemeMode.values.byName(mode);
    notifyListeners();
  }

  void setTheme(AppTheme theme) {
    _currentTheme = appThemeData[theme]!;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('app_theme', theme.name),
    );
    notifyListeners(); // This triggers the UI to rebuild
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('theme_mode', mode.name),
    );
    notifyListeners();
  }
}
