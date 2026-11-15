import 'package:flutter/material.dart';

enum AppTheme {
  greenLight,
  blueDark,
  sunset,
  // ────────────────────────────────────────────────
  purpleMidnight,
  tealOcean,
  amberWarm,
  indigoNight,
  redCrimson,
  cyanFrost,
  limeFresh,
  pinkCandy,
  deepPurpleAmethyst,
  emeraldForest,
  orangePumpkin,
  blueSapphire,
  greyMinimal,
  brownCoffee,
  cyanNeon,
  violetGalaxy,
  yellowSolar,
  roseRomantic,
  slateSteel,
  mintChill,
}

final appThemeData = {
  AppTheme.greenLight: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
  ),
  AppTheme.blueDark: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF18D0FF),
      onPrimary: Color(0xFF031D36),
      secondary: Color(0xFF5A9CFF),
      surface: Color(0xFF071B31),
      onSurface: Color(0xFFF4F8FF),
      error: Color(0xFFFF7891),
    ),
    scaffoldBackgroundColor: const Color(0xFF050A16),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF071A2F),
      foregroundColor: Color(0xFFF4F8FF),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xD9071B31),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF17608F)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xEE06182B),
      indicatorColor: const Color(0xFF0B587D),
      height: 78,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF20D5FF)
              : const Color(0xFFC2D3EB),
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF20D5FF)
              : const Color(0xFFC2D3EB),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF44D9FF),
      inactiveTrackColor: Color(0xFF183B59),
      thumbColor: Color(0xFFC4F4FF),
      overlayColor: Color(0x3316C7FF),
      trackHeight: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFB1C4DF),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF19CFFF)
            : const Color(0xFF274764),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF20CFFF),
        foregroundColor: const Color(0xFF031D36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    dividerColor: const Color(0xFF164468),
  ),
  AppTheme.sunset: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
    scaffoldBackgroundColor: Colors.orange[50],
  ),

  // ──────────────────────────────────────────────── New 20 themes
  AppTheme.purpleMidnight: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
      primary: Colors.deepPurple[300],
    ),
  ),

  AppTheme.tealOcean: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal[700]!),
  ),

  AppTheme.amberWarm: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.amber[800]!,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.grey[900],
  ),

  AppTheme.indigoNight: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo[700]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.redCrimson: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.red[700]!),
  ),

  AppTheme.cyanFrost: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.cyan[600]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.limeFresh: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.lime[700]!),
  ),

  AppTheme.pinkCandy: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink[400]!),
  ),

  AppTheme.deepPurpleAmethyst: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple[800]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.emeraldForest: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown[700]!),
  ),

  AppTheme.orangePumpkin: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange[600]!),
  ),

  AppTheme.blueSapphire: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue[800]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.greyMinimal: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey[600]!,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
  ),

  AppTheme.brownCoffee: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown[700]!),
  ),

  AppTheme.cyanNeon: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.cyan[400]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.violetGalaxy: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurpleAccent,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.yellowSolar: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber[700]!),
  ),

  AppTheme.roseRomantic: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink[600]!),
  ),

  AppTheme.slateSteel: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey[800]!,
      brightness: Brightness.dark,
    ),
  ),

  AppTheme.mintChill: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal[300]!),
  ),
};
