import 'package:flutter/material.dart';

/// A single EQ preset with 10-band values
class EQPreset {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<double> bands; // 10 bands: 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz

  const EQPreset({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.bands,
  });

  /// All built-in presets
  static final List<EQPreset> presets = [
    flat,
    bassBoost,
    vocalBoost,
    rock,
    pop,
    nightMode,
  ];

  /// Flat / Reset
  static const EQPreset flat = EQPreset(
    name: 'Flat',
    description: 'No adjustments',
    icon: Icons.horizontal_rule_rounded,
    color: Color(0xFF78909C),
    bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  /// Bass Boost - Heavy low-end lift
  static const EQPreset bassBoost = EQPreset(
    name: 'Bass Boost',
    description: 'Deep, powerful bass',
    icon: Icons.speaker_rounded,
    color: Color(0xFFE53935),
    bands: [8, 7, 5, 3, 1, 0, 0, 0, 1, 1],
  );

  /// Vocal Boost - Mid-range emphasis
  static const EQPreset vocalBoost = EQPreset(
    name: 'Vocal Boost',
    description: 'Crystal clear vocals',
    icon: Icons.mic_rounded,
    color: Color(0xFF43A047),
    bands: [-2, -1, 0, 2, 5, 6, 5, 3, 1, 0],
  );

  /// Rock - Classic V-shaped curve
  static const EQPreset rock = EQPreset(
    name: 'Rock',
    description: 'Punchy rock sound',
    icon: Icons.music_note_rounded,
    color: Color(0xFFFF6F00),
    bands: [5, 4, 2, 0, -2, -1, 2, 4, 5, 5],
  );

  /// Pop - Slight mid-scoop with highs
  static const EQPreset pop = EQPreset(
    name: 'Pop',
    description: 'Bright, modern pop',
    icon: Icons.star_rounded,
    color: Color(0xFFE91E63),
    bands: [-1, 1, 3, 4, 3, 1, -1, 1, 3, 4],
  );

  /// Night Mode - Reduced highs, boosted mids  
  static const EQPreset nightMode = EQPreset(
    name: 'Night Mode',
    description: 'Comfortable late-night',
    icon: Icons.nightlight_round,
    color: Color(0xFF5C6BC0),
    bands: [0, 0, 1, 2, 3, 3, 2, 0, -2, -4],
  );

  /// Frequency labels for the 10 bands
  static const List<String> bandLabels = [
    '31', '62', '125', '250', '500',
    '1K', '2K', '4K', '8K', '16K',
  ];

  /// Full frequency names
  static const List<String> bandFullLabels = [
    '31 Hz', '62 Hz', '125 Hz', '250 Hz', '500 Hz',
    '1 kHz', '2 kHz', '4 kHz', '8 kHz', '16 kHz',
  ];
}
