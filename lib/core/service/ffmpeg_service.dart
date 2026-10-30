import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Supported export formats
enum ExportFormat { aac, wav, mp4 }

/// Export quality levels
enum ExportQuality { standard, high }

/// Service for audio/video processing and export using FFmpeg.
class FFmpegService {
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal();

  bool _isCancelled = false;

  /// Get the export directory
  Future<String> get _exportDir async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/VolumeBooster_Exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  /// Boost audio file volume with limiter
  /// [gainDb] - Volume gain in dB (e.g., 6 = ~2x louder)
  /// Returns the output file path on success, null on failure
  Future<String?> boostAudioFile({
    required String inputPath,
    required double gainDb,
    required ExportFormat format,
    ExportQuality quality = ExportQuality.standard,
    Function(double progress)? onProgress,
  }) async {
    _isCancelled = false;

    final dir = await _exportDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getExtension(format);
    final outputPath = '$dir/boosted_$timestamp.$extension';

    // Clamp gain to safe range
    final safeGain = gainDb.clamp(-20.0, 20.0);

    // Build FFmpeg command with volume boost + limiter
    // The alimiter prevents clipping/distortion
    final codec = _getCodec(format, quality);
    final bitrate = quality == ExportQuality.high ? '320k' : '192k';
    final sampleRate = quality == ExportQuality.high ? '48000' : '44100';

    String command;
    if (format == ExportFormat.wav) {
      command =
          '-i "$inputPath" '
          '-af "volume=${safeGain}dB,alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50" '
          '-ar $sampleRate '
          '-y "$outputPath"';
    } else {
      command =
          '-i "$inputPath" '
          '-af "volume=${safeGain}dB,alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50" '
          '-c:a $codec -b:a $bitrate -ar $sampleRate '
          '-y "$outputPath"';
    }

    debugPrint('🎬 FFmpeg command: $command');

    // Get input duration for progress
    double? totalDuration;
    try {
      final probeSession = await FFmpegKit.execute('-i "$inputPath" 2>&1');
      final output = await probeSession.getOutput();
      totalDuration = _parseDuration(output ?? '');
    } catch (e) {
      debugPrint('⚠️ Could not determine input duration: $e');
    }

    // Enable statistics for progress tracking
    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      });
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('✅ FFmpeg: Audio boost complete → $outputPath');
      onProgress?.call(1.0);
      return outputPath;
    } else {
      final output = await session.getOutput();
      debugPrint('❌ FFmpeg: Audio boost failed → $output');
      return null;
    }
  }

  /// Enhance voice audio file
  Future<String?> enhanceVoiceFile({
    required String inputPath,
    required double speechClarity, // 0.0 to 1.0
    required double noiseReduction, // 0.0 to 1.0
    required double vocalBoost, // 0.0 to 1.0
    required bool volumeNorm,
    required ExportFormat format,
    ExportQuality quality = ExportQuality.standard,
    Function(double progress)? onProgress,
  }) async {
    _isCancelled = false;

    final dir = await _exportDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getExtension(format);
    final outputPath = '$dir/enhanced_$timestamp.$extension';

    final codec = _getCodec(format, quality);
    final bitrate = quality == ExportQuality.high ? '320k' : '192k';
    final sampleRate = quality == ExportQuality.high ? '48000' : '44100';

    List<String> filters = [];

    // Noise Reduction using afftdn
    if (noiseReduction > 0) {
      final nrValue = (noiseReduction * 30).clamp(0.0, 30.0); // 0 to 30 dB reduction
      filters.add('afftdn=nf=-$nrValue');
    }

    // Speech Clarity (Highpass & slight treble boost)
    if (speechClarity > 0) {
      final hpFreq = 80 + (speechClarity * 120); // 80Hz to 200Hz
      filters.add('highpass=f=$hpFreq');
      final trebleGain = speechClarity * 5; // 0 to 5 dB
      if (trebleGain > 0) {
        filters.add('treble=g=$trebleGain:f=4000:w=0.5h');
      }
    }

    // Vocal Boost (Midrange EQ)
    if (vocalBoost > 0) {
      final midGain = vocalBoost * 8; // 0 to 8 dB boost around 1kHz - 3kHz
      filters.add('equalizer=f=1500:width_type=h:width=1000:g=$midGain');
    }

    // Volume Normalization
    if (volumeNorm) {
      filters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
    } else {
      // Just a safety limiter
      filters.add('alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50');
    }

    final filterChain = filters.isNotEmpty ? filters.join(',') : 'anull';

    String command;
    if (format == ExportFormat.wav) {
      command =
          '-i "$inputPath" '
          '-af "$filterChain" '
          '-ar $sampleRate '
          '-y "$outputPath"';
    } else {
      command =
          '-i "$inputPath" '
          '-af "$filterChain" '
          '-c:a $codec -b:a $bitrate -ar $sampleRate '
          '-y "$outputPath"';
    }

    debugPrint('🎬 FFmpeg Enhance command: $command');

    double? totalDuration;
    try {
      final probeSession = await FFmpegKit.execute('-i "$inputPath" 2>&1');
      final output = await probeSession.getOutput();
      totalDuration = _parseDuration(output ?? '');
    } catch (e) {
      debugPrint('⚠️ Could not determine input duration: $e');
    }

    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      });
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('✅ FFmpeg: Voice Enhance complete → $outputPath');
      onProgress?.call(1.0);
      return outputPath;
    } else {
      final output = await session.getOutput();
      debugPrint('❌ FFmpeg: Voice Enhance failed → $output');
      return null;
    }
  }

  /// Boost audio track in a video file
  Future<String?> boostVideoAudio({
    required String inputPath,
    required double gainDb,
    ExportQuality quality = ExportQuality.standard,
    Function(double progress)? onProgress,
  }) async {
    _isCancelled = false;

    final dir = await _exportDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '$dir/boosted_video_$timestamp.mp4';

    final safeGain = gainDb.clamp(-20.0, 20.0);
    final audioBitrate = quality == ExportQuality.high ? '256k' : '128k';

    // Video copy, only re-encode audio with boost + limiter
    final command =
        '-i "$inputPath" '
        '-c:v copy '
        '-af "volume=${safeGain}dB,alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50" '
        '-c:a aac -b:a $audioBitrate '
        '-y "$outputPath"';

    debugPrint('🎬 FFmpeg video command: $command');

    double? totalDuration;
    try {
      final probeSession = await FFmpegKit.execute('-i "$inputPath" 2>&1');
      final output = await probeSession.getOutput();
      totalDuration = _parseDuration(output ?? '');
    } catch (e) {
      debugPrint('⚠️ Could not determine video duration: $e');
    }

    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      });
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('✅ FFmpeg: Video audio boost complete → $outputPath');
      onProgress?.call(1.0);
      return outputPath;
    } else {
      final output = await session.getOutput();
      debugPrint('❌ FFmpeg: Video audio boost failed → $output');
      return null;
    }
  }

  /// Apply EQ curve to file and export
  Future<String?> applyEQToFile({
    required String inputPath,
    required List<double> eqBands,
    required ExportFormat format,
    double gainDb = 0.0,
    ExportQuality quality = ExportQuality.standard,
    Function(double progress)? onProgress,
  }) async {
    _isCancelled = false;

    final dir = await _exportDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getExtension(format);
    final outputPath = '$dir/eq_export_$timestamp.$extension';

    // Build EQ filter string
    final frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    final eqFilters = <String>[];

    for (int i = 0; i < eqBands.length && i < frequencies.length; i++) {
      final gain = eqBands[i].clamp(-15.0, 15.0);
      if (gain.abs() > 0.5) {
        eqFilters.add(
            'equalizer=f=${frequencies[i]}:t=o:w=1:g=$gain');
      }
    }

    final safeGain = gainDb.clamp(-20.0, 20.0);
    String filterChain = 'volume=${safeGain}dB';
    if (eqFilters.isNotEmpty) {
      filterChain += ',${eqFilters.join(',')}';
    }
    filterChain += ',alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50';

    final codec = _getCodec(format, quality);
    final bitrate = quality == ExportQuality.high ? '320k' : '192k';
    final sampleRate = quality == ExportQuality.high ? '48000' : '44100';

    String command;
    if (format == ExportFormat.wav) {
      command =
          '-i "$inputPath" '
          '-af "$filterChain" '
          '-ar $sampleRate '
          '-y "$outputPath"';
    } else {
      command =
          '-i "$inputPath" '
          '-af "$filterChain" '
          '-c:a $codec -b:a $bitrate -ar $sampleRate '
          '-y "$outputPath"';
    }

    debugPrint('🎬 FFmpeg EQ command: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('✅ FFmpeg: EQ export complete → $outputPath');
      onProgress?.call(1.0);
      return outputPath;
    } else {
      final output = await session.getOutput();
      debugPrint('❌ FFmpeg: EQ export failed → $output');
      return null;
    }
  }

  /// Cancel ongoing FFmpeg operation
  Future<void> cancel() async {
    _isCancelled = true;
    await FFmpegKit.cancel();
    debugPrint('🛑 FFmpeg: Operation cancelled');
  }

  // Helpers
  String _getExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.aac:
        return 'm4a';
      case ExportFormat.wav:
        return 'wav';
      case ExportFormat.mp4:
        return 'mp4';
    }
  }

  String _getCodec(ExportFormat format, ExportQuality quality) {
    switch (format) {
      case ExportFormat.aac:
        return 'aac';
      case ExportFormat.wav:
        return 'pcm_s16le';
      case ExportFormat.mp4:
        return 'aac';
    }
  }

  double? _parseDuration(String output) {
    final regex = RegExp(r'Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})');
    final match = regex.firstMatch(output);
    if (match != null) {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final hundredths = int.parse(match.group(4)!);
      return hours * 3600.0 + minutes * 60.0 + seconds + hundredths / 100.0;
    }
    return null;
  }
}
