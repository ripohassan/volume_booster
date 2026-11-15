import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../features/UI/controller/audio_analyzer_controller.dart';
import '../../features/models/audio_analysis.dart';
import '../../features/models/audio_project.dart';
import 'audio_waveform_service.dart';
import 'processing_job.dart';

/// Sample-based measurements from the cached float PCM reference. The worker
/// reads fixed-size blocks only; it never materializes the source in memory.
class PcmAudioAnalysisBackend implements AudioAnalysisBackend {
  final AudioWaveformService waveforms;
  final Map<String, AudioAnalysis> _cache = {};
  PcmAudioAnalysisBackend(this.waveforms);
  @override
  Future<AudioAnalysis> analyze(
    AudioProject project,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  ) async {
    final key =
        '${project.id}:${project.revision}:${project.sourceFingerprint}';
    final old = _cache[key];
    if (old != null) {
      progress(1);
      return old;
    }
    final envelope = await waveforms.loadProject(
      project,
      cancellation,
      (v) => progress(v * .35),
    );
    cancellation.check();
    final raw = await Isolate.run(
      () => _measure({
        'path': envelope.referencePath,
        'start': project.trimStart.inMicroseconds,
        'end': project.trimEnd.inMicroseconds,
      }),
    );
    cancellation.check();
    progress(0.95);
    final result = AudioAnalysis(
      projectId: project.id,
      projectRevision: project.revision,
      rangeStart: project.trimStart,
      rangeEnd: project.trimEnd,
      sampleRate: raw['rate'] as int,
      framesAnalyzed: raw['frames'] as int,
      measuredAt: DateTime.now().toUtc(),
      rms: List<double>.from(raw['rms'] as List),
      peaks: List<double>.from(raw['peaks'] as List),
      clippingCounts: List<int>.from(raw['clips'] as List),
      waveformMin: envelope.minima,
      waveformMax: envelope.maxima,
      spectrumHz: List<double>.from(raw['hz'] as List),
      spectrumPower: List<double>.from(raw['power'] as List),
    );
    _cache[key] = result;
    progress(1);
    return result;
  }
}

Map<String, Object> _measure(Map<String, Object> args) {
  final path = args['path']! as String, file = File(path);
  final raf = file.openSync();
  try {
    final length = raf.lengthSync();
    final header = raf.readSync(12);
    if (header.length != 12 ||
        ![
          'RIFF',
          'RF64',
        ].contains(String.fromCharCodes(header.sublist(0, 4))) ||
        String.fromCharCodes(header.sublist(8, 12)) != 'WAVE') {
      throw const FormatException('Expected float PCM WAV');
    }

    int? channels, rate, bits, format, dataStart, dataBytes, rf64DataBytes;
    var offset = 12;
    for (var chunks = 0; chunks < 128 && offset + 8 <= length; chunks++) {
      raf.setPositionSync(offset);
      final chunk = raf.readSync(8);
      final name = String.fromCharCodes(chunk.sublist(0, 4));
      final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
      if (name == 'ds64') {
        final bytes = raf.readSync(math.min(size, 28));
        if (bytes.length >= 16) {
          rf64DataBytes = ByteData.sublistView(
            bytes,
          ).getUint64(8, Endian.little);
        }
      } else if (name == 'fmt ') {
        final bytes = raf.readSync(math.min(size, 64));
        if (bytes.length < 16)
          throw const FormatException('Invalid PCM format');
        final values = ByteData.sublistView(bytes);
        format = values.getUint16(0, Endian.little);
        channels = values.getUint16(2, Endian.little);
        rate = values.getUint32(4, Endian.little);
        bits = values.getUint16(14, Endian.little);
        if (format == 65534 && bytes.length >= 40) {
          format = values.getUint16(24, Endian.little);
        }
      } else if (name == 'data') {
        dataStart = offset + 8;
        dataBytes = size == 0xffffffff ? rf64DataBytes : size;
        break;
      }
      offset += 8 + size + size % 2;
    }
    if (channels == null ||
        rate == null ||
        bits != 32 ||
        format != 3 ||
        dataStart == null ||
        dataBytes == null ||
        dataBytes <= 0 ||
        dataStart + dataBytes > length) {
      throw const FormatException('Expected float PCM WAV');
    }

    final total = dataBytes ~/ (channels * 4);
    final start = ((args['start']! as int) * rate ~/ 1000000)
        .clamp(0, total)
        .toInt();
    final end = ((args['end']! as int) * rate ~/ 1000000)
        .clamp(start + 1, total)
        .toInt();
    raf.setPositionSync(dataStart + start * channels * 4);
    final sum = List<double>.filled(channels, 0),
        peak = List<double>.filled(channels, 0),
        clips = List<int>.filled(channels, 0);
    final fft = <double>[];
    var frames = 0;
    while (frames < end - start) {
      final count = math.min(4096, end - start - frames);
      final b = raf.readSync(count * channels * 4);
      final v = ByteData.sublistView(b);
      for (var f = 0; f < count; f++) {
        for (var c = 0; c < channels; c++) {
          final x = v.getFloat32((f * channels + c) * 4, Endian.little);
          sum[c] += x * x;
          peak[c] = math.max(peak[c], x.abs());
          if (x.abs() >= .999) clips[c]++;
          if (c == 0 && fft.length < 1024) fft.add(x);
        }
      }
      frames += count;
    }
    while (fft.length < 1024) fft.add(0);
    final hz = <double>[], power = <double>[];
    for (var k = 1; k <= 512; k++) {
      var re = 0.0, im = 0.0;
      for (var n = 0; n < 1024; n++) {
        final x = fft[n] * (.5 - .5 * math.cos(2 * math.pi * n / 1023));
        final a = 2 * math.pi * k * n / 1024;
        re += x * math.cos(a);
        im -= x * math.sin(a);
      }
      hz.add(k * rate / 1024);
      power.add(math.sqrt(re * re + im * im) / 512);
    }
    return {
      'rate': rate,
      'frames': frames,
      'rms': sum.map((x) => math.sqrt(x / frames)).toList(),
      'peaks': peak,
      'clips': clips,
      'hz': hz,
      'power': power,
    };
  } finally {
    raf.closeSync();
  }
}
