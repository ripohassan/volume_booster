import 'dart:math';

/// Strict, versioned JSON helpers shared by persisted audio models.
abstract final class AudioModelJson {
  static void version(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported audio document schema');
    }
  }

  static String text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Expected nonempty $key');
    }
    return value;
  }

  static int integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('Expected integer $key');
    return value;
  }

  static double number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('Expected finite $key');
    }
    return value.toDouble();
  }

  static bool boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('Expected boolean $key');
    return value;
  }

  static Map<String, dynamic> object(dynamic value) {
    if (value is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(value);
  }

  static T enumeration<T extends Enum>(List<T> values, dynamic value) =>
      values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw FormatException('Unknown enum value: $value'),
      );

  static void range(String name, double value, double min, double max) {
    if (!value.isFinite || value < min || value > max) {
      throw ArgumentError.value(value, name, 'Expected $min through $max');
    }
  }

  static String identifier(String value) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'id', 'Invalid identifier');
    }
    return value;
  }

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
