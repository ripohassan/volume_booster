import 'audio_model_json.dart';

// Existing service callers continue receiving these names through its export.
enum ExportFormat { aac, wav, mp4 }

enum ExportQuality { standard, high }

/// Immutable offline-processing recipe. Gain values are dB, not percentages.
class ProcessingConfig {
  static const frequencies = [
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  final double gainDb;
  final double bassGainDb;
  final double bassFrequencyHz;
  final List<double> eqBands;
  final bool voiceEnabled;
  final double speechClarity;
  final double vocalBoost;
  final double noiseReduction;
  final double voiceIntensity;
  final bool normalizationEnabled;
  final double targetLufs;
  final bool limiterEnabled;
  final double limiterCeilingDb;
  final ExportFormat exportFormat;
  final ExportQuality exportQuality;

  ProcessingConfig({
    this.gainDb = 0,
    this.bassGainDb = 0,
    this.bassFrequencyHz = 100,
    List<double> eqBands = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.voiceEnabled = false,
    this.speechClarity = 0,
    this.vocalBoost = 0,
    this.noiseReduction = 0,
    this.voiceIntensity = 1,
    this.normalizationEnabled = false,
    this.targetLufs = -16,
    this.limiterEnabled = true,
    this.limiterCeilingDb = -1.5,
    this.exportFormat = ExportFormat.aac,
    this.exportQuality = ExportQuality.standard,
  }) : eqBands = List.unmodifiable(eqBands) {
    AudioModelJson.range('gainDb', gainDb, -60, 20);
    AudioModelJson.range('bassGainDb', bassGainDb, -15, 15);
    AudioModelJson.range('bassFrequencyHz', bassFrequencyHz, 30, 300);
    if (eqBands.length != 10) {
      throw ArgumentError('Exactly ten EQ bands required');
    }
    for (final band in eqBands) {
      AudioModelJson.range('eqBand', band, -15, 15);
    }
    for (final value in [
      speechClarity,
      vocalBoost,
      noiseReduction,
      voiceIntensity,
    ]) {
      AudioModelJson.range('voice intensity', value, 0, 1);
    }
    AudioModelJson.range('targetLufs', targetLufs, -36, -5);
    AudioModelJson.range('limiterCeilingDb', limiterCeilingDb, -12, -0.1);
    if (normalizationEnabled && limiterCeilingDb < -9) {
      throw ArgumentError(
        'Loudness normalization supports true-peak targets of -9 dB or higher',
      );
    }
  }

  ProcessingConfig copyWith({
    double? gainDb,
    double? bassGainDb,
    double? bassFrequencyHz,
    List<double>? eqBands,
    bool? voiceEnabled,
    double? speechClarity,
    double? vocalBoost,
    double? noiseReduction,
    double? voiceIntensity,
    bool? normalizationEnabled,
    double? targetLufs,
    bool? limiterEnabled,
    double? limiterCeilingDb,
    ExportFormat? exportFormat,
    ExportQuality? exportQuality,
  }) => ProcessingConfig(
    gainDb: gainDb ?? this.gainDb,
    bassGainDb: bassGainDb ?? this.bassGainDb,
    bassFrequencyHz: bassFrequencyHz ?? this.bassFrequencyHz,
    eqBands: eqBands ?? this.eqBands,
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    speechClarity: speechClarity ?? this.speechClarity,
    vocalBoost: vocalBoost ?? this.vocalBoost,
    noiseReduction: noiseReduction ?? this.noiseReduction,
    voiceIntensity: voiceIntensity ?? this.voiceIntensity,
    normalizationEnabled: normalizationEnabled ?? this.normalizationEnabled,
    targetLufs: targetLufs ?? this.targetLufs,
    limiterEnabled: limiterEnabled ?? this.limiterEnabled,
    limiterCeilingDb: limiterCeilingDb ?? this.limiterCeilingDb,
    exportFormat: exportFormat ?? this.exportFormat,
    exportQuality: exportQuality ?? this.exportQuality,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'gainDb': gainDb,
    'bassGainDb': bassGainDb,
    'bassFrequencyHz': bassFrequencyHz,
    'eqBands': eqBands,
    'voiceEnabled': voiceEnabled,
    'speechClarity': speechClarity,
    'vocalBoost': vocalBoost,
    'noiseReduction': noiseReduction,
    'voiceIntensity': voiceIntensity,
    'normalizationEnabled': normalizationEnabled,
    'targetLufs': targetLufs,
    'limiterEnabled': limiterEnabled,
    'limiterCeilingDb': limiterCeilingDb,
    'exportFormat': exportFormat.name,
    'exportQuality': exportQuality.name,
  };

  factory ProcessingConfig.fromJson(Map<String, dynamic> json) {
    AudioModelJson.version(json);
    final bands = json['eqBands'];
    if (bands is! List || bands.any((v) => v is! num || !v.isFinite)) {
      throw const FormatException('Invalid EQ bands');
    }
    return ProcessingConfig(
      gainDb: AudioModelJson.number(json, 'gainDb'),
      bassGainDb: AudioModelJson.number(json, 'bassGainDb'),
      bassFrequencyHz: AudioModelJson.number(json, 'bassFrequencyHz'),
      eqBands: bands.map((v) => (v as num).toDouble()).toList(),
      voiceEnabled: AudioModelJson.boolean(json, 'voiceEnabled'),
      speechClarity: AudioModelJson.number(json, 'speechClarity'),
      vocalBoost: AudioModelJson.number(json, 'vocalBoost'),
      noiseReduction: AudioModelJson.number(json, 'noiseReduction'),
      voiceIntensity: AudioModelJson.number(json, 'voiceIntensity'),
      normalizationEnabled: AudioModelJson.boolean(
        json,
        'normalizationEnabled',
      ),
      targetLufs: AudioModelJson.number(json, 'targetLufs'),
      limiterEnabled: AudioModelJson.boolean(json, 'limiterEnabled'),
      limiterCeilingDb: AudioModelJson.number(json, 'limiterCeilingDb'),
      exportFormat: AudioModelJson.enumeration(
        ExportFormat.values,
        json['exportFormat'],
      ),
      exportQuality: AudioModelJson.enumeration(
        ExportQuality.values,
        json['exportQuality'],
      ),
    );
  }
}
