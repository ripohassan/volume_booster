import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../features/models/audio_model_json.dart';
import '../../features/models/audio_project.dart';
import '../../features/models/processing_config.dart';
import 'processing_filter_builder.dart';
import 'processing_job.dart';

export '../../features/models/processing_config.dart'
    show ExportFormat, ExportQuality;

/// Service for audio/video processing and export using FFmpeg.
class FFmpegService {
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal();

  bool _isCancelled = false;
  final Set<int> _legacySessions = {};

  /// Structured FFprobe metadata, from an actual readable audio stream.
  Future<AudioMetadata> probeFile(String path) async {
    if (!await File(path).exists()) {
      throw FileSystemException('Audio file is missing', path);
    }
    final session = await FFprobeKit.getMediaInformationFromCommandArguments([
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      '-i',
      path,
    ]);
    final info = session.getMediaInformation();
    if (info == null) {
      throw const AudioProcessingException(
        'invalid_media',
        'Unable to inspect audio file',
      );
    }
    final streams = info.getStreams().where((s) => s.getType() == 'audio');
    if (streams.isEmpty) {
      throw const AudioProcessingException(
        'no_audio',
        'No supported audio stream found',
      );
    }
    final stream = streams.first;
    final seconds =
        double.tryParse('${stream.getProperty('duration')}') ??
        double.tryParse(info.getDuration() ?? '');
    final rate = int.tryParse('${stream.getSampleRate()}');
    final channels = stream.getNumberProperty('channels')?.toInt();
    final codec = stream.getCodec();
    if (seconds == null ||
        !seconds.isFinite ||
        seconds <= 0 ||
        rate == null ||
        rate <= 0 ||
        channels == null ||
        channels <= 0 ||
        codec == null ||
        codec.isEmpty) {
      throw const AudioProcessingException(
        'invalid_metadata',
        'Audio duration, rate or layout is unavailable',
      );
    }
    return AudioMetadata(
      duration: Duration(microseconds: (seconds * 1000000).round()),
      sampleRate: rate,
      channels: channels,
      codec: codec,
    );
  }

  /// New project API. Legacy screens retain their existing methods below.
  Future<ProcessedAudio> processProject(
    ProcessingRequest request,
    ProcessingCancellation cancellation, {
    required void Function(double) onProgress,
  }) async {
    cancellation.check();
    final project = request.project;
    final output = File(request.outputPath);
    if (await output.exists()) {
      throw const AudioProcessingException(
        'output_exists',
        'Choose a new export path',
      );
    }
    final source = File(project.managedFilePath);
    if (!await source.exists() ||
        await source.length() != project.sourceBytes) {
      throw const AudioProcessingException(
        'source_missing',
        'Recover the original project file before processing',
      );
    }
    final input = await probeFile(source.path);
    cancellation.check();
    if (input.sampleRate != project.sampleRate ||
        input.channels != project.channels ||
        (input.duration - project.duration).inMilliseconds.abs() > 20) {
      throw const AudioProcessingException(
        'source_changed',
        'Managed audio no longer matches the project',
      );
    }
    await output.parent.create(recursive: true);
    final part = File('${output.path}.${AudioModelJson.newId()}.part');
    final config = project.config;
    final sampleRate = config.exportQuality == ExportQuality.high
        ? 48000
        : 44100;
    final args = <String>[
      '-nostdin',
      '-i',
      source.path,
      '-map',
      '0:a:0',
      '-vn',
      '-af',
      'atrim=start=${project.trimStart.inMicroseconds / 1000000}:'
          'end=${project.trimEnd.inMicroseconds / 1000000},asetpts=PTS-STARTPTS,'
          '${ProcessingFilterBuilder.build(config, sampleRate: project.sampleRate)}',
      '-ar',
      '$sampleRate',
    ];
    if (config.exportFormat == ExportFormat.wav) {
      args.addAll(['-c:a', 'pcm_s16le', '-f', 'wav']);
    } else {
      args.addAll([
        '-c:a',
        'aac',
        '-b:a',
        config.exportQuality == ExportQuality.high ? '320k' : '192k',
        '-f',
        config.exportFormat == ExportFormat.mp4 ? 'mp4' : 'ipod',
      ]);
    }
    args.addAll(['-n', part.path]);
    final complete = Completer<FFmpegSession>();
    FFmpegSession? session;
    try {
      session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (value) {
          if (!complete.isCompleted) complete.complete(value);
        },
        null,
        (statistics) => onProgress(
          (statistics.getTime() * 1000 / project.trimmedDuration.inMicroseconds)
              .clamp(0, 0.99),
        ),
      );
      final sessionId = session.getSessionId();
      if (sessionId == null) {
        throw const AudioProcessingException(
          'invalid_session',
          'FFmpeg session was not created',
        );
      }
      await cancellation.attach(() => FFmpegKit.cancel(sessionId));
      final finished = await complete.future;
      cancellation.check();
      if (!ReturnCode.isSuccess(await finished.getReturnCode())) {
        throw const AudioProcessingException(
          'native_processing_failed',
          'FFmpeg could not render the audio configuration',
        );
      }
      final metadata = await probeFile(part.path);
      cancellation.check();
      final bytes = await part.length();
      if (bytes == 0 ||
          metadata.channels != project.channels ||
          metadata.sampleRate != sampleRate ||
          (metadata.duration - project.trimmedDuration).inMilliseconds.abs() >
              250) {
        throw const AudioProcessingException(
          'invalid_output',
          'Rendered audio failed metadata validation',
        );
      }
      if (await output.exists()) {
        throw const AudioProcessingException(
          'output_exists',
          'Export path is already in use',
        );
      }
      await part.rename(output.path);
      return ProcessedAudio(
        outputPath: output.path,
        metadata: metadata,
        bytes: bytes,
      );
    } finally {
      // Cancellation registration can itself fail. Never remove a partial file
      // while a successfully started native session is still writing to it.
      if (session != null && !complete.isCompleted) {
        final id = session.getSessionId();
        if (id != null) {
          await FFmpegKit.cancel(id);
          await complete.future;
        }
      }
      if (await part.exists()) await part.delete();
    }
  }

  /// Decode, without enhancement or downmixing, to a seekable float PCM WAV.
  Future<void> decodePcm(
    String inputPath,
    String outputPath,
    Duration duration,
    ProcessingCancellation cancellation,
    void Function(double) onProgress,
  ) async {
    cancellation.check();
    if (await File(outputPath).exists()) {
      throw const AudioProcessingException(
        'output_exists',
        'PCM output already exists',
      );
    }
    final done = Completer<FFmpegSession>();
    FFmpegSession? session;
    try {
      session = await FFmpegKit.executeWithArgumentsAsync(
        [
          '-nostdin',
          '-v',
          'error',
          '-i',
          inputPath,
          '-map',
          '0:a:0',
          '-vn',
          '-c:a',
          'pcm_f32le',
          '-rf64',
          'auto',
          '-f',
          'wav',
          '-n',
          outputPath,
        ],
        (value) {
          if (!done.isCompleted) done.complete(value);
        },
        null,
        (value) => onProgress(
          (value.getTime() * 1000 / duration.inMicroseconds).clamp(0, 0.99),
        ),
      );
      final id = session.getSessionId();
      if (id == null)
        throw const AudioProcessingException(
          'decode_session',
          'Unable to decode audio',
        );
      await cancellation.attach(() => FFmpegKit.cancel(id));
      final finished = await done.future;
      cancellation.check();
      if (!ReturnCode.isSuccess(await finished.getReturnCode())) {
        throw const AudioProcessingException(
          'decode_failed',
          'This file could not be decoded as audio',
        );
      }
      onProgress(1);
    } catch (_) {
      if (session != null && !done.isCompleted) {
        final id = session.getSessionId();
        if (id != null) {
          await FFmpegKit.cancel(id);
          await done.future;
        }
      }
      final output = File(outputPath);
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  Future<FFmpegSession> _executeLegacy(
    String command, {
    void Function(Statistics)? onStatistics,
  }) async {
    final complete = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeAsync(
      command,
      (value) {
        if (!complete.isCompleted) complete.complete(value);
      },
      null,
      onStatistics,
    );
    final id = session.getSessionId();
    if (id == null) throw StateError('FFmpeg session was not created');
    _legacySessions.add(id);
    try {
      if (_isCancelled) await FFmpegKit.cancel(id);
      return await complete.future;
    } finally {
      _legacySessions.remove(id);
    }
  }

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
          '-af "volume=${safeGain}dB,alimiter=limit=0.891251:level=0:attack=5:release=50:latency=1" '
          '-ar $sampleRate '
          '-y "$outputPath"';
    } else {
      command =
          '-i "$inputPath" '
          '-af "volume=${safeGain}dB,alimiter=limit=0.891251:level=0:attack=5:release=50:latency=1" '
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
    void Function(Statistics)? statisticsCallback;
    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      statisticsCallback = (Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      };
    }

    final session = await _executeLegacy(
      command,
      onStatistics: statisticsCallback,
    );
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

    // `nf` is a noise-floor value in dB and accepts only a negative range.
    // `nr` is the actual reduction control; a fixed speech-safe floor avoids
    // the former invalid `nf=-0` setting at low values.
    if (noiseReduction > 0) {
      final nrValue = (noiseReduction * 30).clamp(0.01, 30.0);
      filters.add('afftdn=nr=$nrValue:nf=-50');
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
      filters.add(
        'alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50',
      );
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

    void Function(Statistics)? statisticsCallback;
    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      statisticsCallback = (Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      };
    }

    final session = await _executeLegacy(
      command,
      onStatistics: statisticsCallback,
    );
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

    void Function(Statistics)? statisticsCallback;
    if (onProgress != null && totalDuration != null && totalDuration > 0) {
      statisticsCallback = (Statistics statistics) {
        if (_isCancelled) return;
        final time = statistics.getTime();
        if (time > 0 && totalDuration! > 0) {
          final progress = (time / (totalDuration * 1000)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      };
    }

    final session = await _executeLegacy(
      command,
      onStatistics: statisticsCallback,
    );
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
        eqFilters.add('equalizer=f=${frequencies[i]}:t=o:w=1:g=$gain');
      }
    }

    final safeGain = gainDb.clamp(-20.0, 20.0);
    String filterChain = 'volume=${safeGain}dB';
    if (eqFilters.isNotEmpty) {
      filterChain += ',${eqFilters.join(',')}';
    }
    filterChain +=
        ',alimiter=level_in=1:level_out=1:limit=0.95:attack=5:release=50';

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

    final session = await _executeLegacy(command);
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
    await Future.wait(
      _legacySessions.toList().map((id) => FFmpegKit.cancel(id)),
    );
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
