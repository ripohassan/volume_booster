import 'dart:math' as math;
import 'audio_model_json.dart';

/// Linear, per-channel measurements of a declared sample range.
/// dBFS getters return -infinity for silence; JSON stores finite amplitudes.
class AudioAnalysis {
  final String projectId;
  final int projectRevision;
  final Duration rangeStart;
  final Duration rangeEnd;
  final int sampleRate;
  final int framesAnalyzed;
  final DateTime measuredAt;
  final List<double> rms;
  final List<double> peaks;
  final List<int> clippingCounts;
  final double clippingThreshold;
  final List<double> waveformMin;
  final List<double> waveformMax;
  final List<double> spectrumHz;
  final List<double> spectrumPower;

  List<double> get rmsDbfs => List.unmodifiable(
    rms.map(
      (value) => value == 0
          ? double.negativeInfinity
          : 20 * math.log(value) / math.ln10,
    ),
  );
  List<double> get peakDbfs => List.unmodifiable(
    peaks.map(
      (value) => value == 0
          ? double.negativeInfinity
          : 20 * math.log(value) / math.ln10,
    ),
  );

  AudioAnalysis({
    required this.projectId,
    required this.projectRevision,
    required this.rangeStart,
    required this.rangeEnd,
    required this.sampleRate,
    required this.framesAnalyzed,
    required this.measuredAt,
    required List<double> rms,
    required List<double> peaks,
    required List<int> clippingCounts,
    this.clippingThreshold = 0.999,
    List<double> waveformMin = const [],
    List<double> waveformMax = const [],
    List<double> spectrumHz = const [],
    List<double> spectrumPower = const [],
  }) : rms = List.unmodifiable(rms),
       peaks = List.unmodifiable(peaks),
       clippingCounts = List.unmodifiable(clippingCounts),
       waveformMin = List.unmodifiable(waveformMin),
       waveformMax = List.unmodifiable(waveformMax),
       spectrumHz = List.unmodifiable(spectrumHz),
       spectrumPower = List.unmodifiable(spectrumPower) {
    AudioModelJson.identifier(projectId);
    if (projectRevision < 0 ||
        rangeStart < Duration.zero ||
        rangeEnd <= rangeStart ||
        sampleRate <= 0 ||
        framesAnalyzed <= 0 ||
        rms.isEmpty ||
        rms.length != peaks.length ||
        rms.length != clippingCounts.length ||
        waveformMin.length != waveformMax.length ||
        spectrumHz.length != spectrumPower.length) {
      throw ArgumentError('Inconsistent audio measurement dimensions');
    }
    AudioModelJson.range('clippingThreshold', clippingThreshold, 0.5, 1);
    for (var i = 0; i < rms.length; i++) {
      if (!rms[i].isFinite ||
          rms[i] < 0 ||
          !peaks[i].isFinite ||
          peaks[i] < rms[i] ||
          clippingCounts[i] < 0 ||
          clippingCounts[i] > framesAnalyzed) {
        throw ArgumentError('Invalid channel measurement');
      }
    }
    for (var i = 0; i < waveformMin.length; i++) {
      if (!waveformMin[i].isFinite ||
          !waveformMax[i].isFinite ||
          waveformMin[i] > waveformMax[i]) {
        throw ArgumentError('Invalid waveform envelope');
      }
    }
    for (var i = 0; i < spectrumHz.length; i++) {
      AudioModelJson.range('spectrumHz', spectrumHz[i], 0, sampleRate / 2);
      if (!spectrumPower[i].isFinite ||
          spectrumPower[i] < 0 ||
          (i > 0 && spectrumHz[i] <= spectrumHz[i - 1])) {
        throw ArgumentError('Invalid spectrum bins');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'projectId': projectId,
    'projectRevision': projectRevision,
    'rangeStartUs': rangeStart.inMicroseconds,
    'rangeEndUs': rangeEnd.inMicroseconds,
    'sampleRate': sampleRate,
    'framesAnalyzed': framesAnalyzed,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'rms': rms,
    'peaks': peaks,
    'clippingCounts': clippingCounts,
    'clippingThreshold': clippingThreshold,
    'waveformMin': waveformMin,
    'waveformMax': waveformMax,
    'spectrumHz': spectrumHz,
    'spectrumPower': spectrumPower,
  };

  factory AudioAnalysis.fromJson(Map<String, dynamic> json) {
    AudioModelJson.version(json);
    List<double> numbers(String key) =>
        (json[key] as List).map((v) => (v as num).toDouble()).toList();
    return AudioAnalysis(
      projectId: AudioModelJson.text(json, 'projectId'),
      projectRevision: AudioModelJson.integer(json, 'projectRevision'),
      rangeStart: Duration(
        microseconds: AudioModelJson.integer(json, 'rangeStartUs'),
      ),
      rangeEnd: Duration(
        microseconds: AudioModelJson.integer(json, 'rangeEndUs'),
      ),
      sampleRate: AudioModelJson.integer(json, 'sampleRate'),
      framesAnalyzed: AudioModelJson.integer(json, 'framesAnalyzed'),
      measuredAt: DateTime.parse(AudioModelJson.text(json, 'measuredAt')),
      rms: numbers('rms'),
      peaks: numbers('peaks'),
      clippingCounts: List<int>.from(json['clippingCounts']),
      clippingThreshold: AudioModelJson.number(json, 'clippingThreshold'),
      waveformMin: numbers('waveformMin'),
      waveformMax: numbers('waveformMax'),
      spectrumHz: numbers('spectrumHz'),
      spectrumPower: numbers('spectrumPower'),
    );
  }
}
