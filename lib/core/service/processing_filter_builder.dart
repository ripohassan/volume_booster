import 'dart:math' as math;
import '../../features/models/processing_config.dart';

/// Deterministic DSP recipe reused by future Studio previews and exports.
/// Does not change the legacy screen/service processing recipes.
abstract final class ProcessingFilterBuilder {
  static String build(ProcessingConfig config, {required int sampleRate}) {
    final filters = <String>['volume=${config.gainDb}dB'];
    if (config.bassGainDb != 0) {
      filters.add('bass=g=${config.bassGainDb}:f=${config.bassFrequencyHz}');
    }
    for (var i = 0; i < config.eqBands.length; i++) {
      // A filter above Nyquist cannot represent this source's frequency band.
      if (config.eqBands[i] != 0 &&
          ProcessingConfig.frequencies[i] < sampleRate / 2) {
        filters.add(
          'equalizer=f=${ProcessingConfig.frequencies[i]}:t=o:w=1:g=${config.eqBands[i]}',
        );
      }
    }
    if (config.voiceEnabled) {
      final intensity = config.voiceIntensity;
      final noise = config.noiseReduction * intensity;
      if (noise > 0) {
        filters.add('afftdn=nr=${(noise * 30).clamp(0.01, 30)}:nf=-50');
      }
      final clarity = config.speechClarity * intensity;
      if (clarity > 0) {
        filters.add('highpass=f=${80 + clarity * 120}');
        filters.add(
          'treble=g=${clarity * 5}:f=${math.min(4000, sampleRate / 4)}:t=h:w=1000',
        );
      }
      final vocal = config.vocalBoost * intensity;
      if (vocal > 0) {
        filters.add(
          'equalizer=f=${math.min(1500, sampleRate / 4)}:t=h:w=1000:g=${vocal * 8}',
        );
      }
    }
    if (config.normalizationEnabled) {
      // Genuine single-pass EBU R128 processing, not a two-pass mastering claim.
      filters.add(
        'loudnorm=I=${config.targetLufs}:TP=${config.limiterCeilingDb}:LRA=11',
      );
    }
    if (config.limiterEnabled) {
      final ceiling = math.pow(10, config.limiterCeilingDb / 20);
      filters.add(
        'alimiter=limit=$ceiling:level=0:attack=5:release=50:latency=1',
      );
    }
    return filters.join(',');
  }
}
