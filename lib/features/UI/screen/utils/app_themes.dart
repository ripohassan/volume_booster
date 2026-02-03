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
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
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