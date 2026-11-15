import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../features/models/audio_project.dart';
import '../../features/models/audio_model_json.dart';
import 'ffmpeg_service.dart';
import 'processing_job.dart';

abstract interface class PcmDecoder {
  Future<void> decode(
    String input,
    String output,
    Duration duration,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  );
}

class FFmpegPcmDecoder implements PcmDecoder {
  @override
  Future<void> decode(
    String input,
    String output,
    Duration duration,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  ) => FFmpegService().decodePcm(
    input,
    output,
    duration,
    cancellation,
    progress,
  );
}

class WaveformEnvelope {
  final String referencePath;
  final int frames;
  final int sampleRate;
  final int channels;
  final List<double> minima;
  final List<double> maxima;
  Duration get duration =>
      Duration(microseconds: (frames * 1000000 / sampleRate).round());
  WaveformEnvelope({
    required this.referencePath,
    required this.frames,
    required this.sampleRate,
    required this.channels,
    required List<double> minima,
    required List<double> maxima,
  }) : minima = List.unmodifiable(minima),
       maxima = List.unmodifiable(maxima) {
    if (frames <= 0 ||
        sampleRate <= 0 ||
        channels <= 0 ||
        minima.isEmpty ||
        minima.length != maxima.length ||
        minima.length > 8192) {
      throw const FormatException('Invalid PCM waveform dimensions');
    }
    for (var i = 0; i < minima.length; i++) {
      if (!minima[i].isFinite || !maxima[i].isFinite || minima[i] > maxima[i]) {
        throw const FormatException('Invalid PCM waveform values');
      }
    }
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'frames': frames,
    'sampleRate': sampleRate,
    'channels': channels,
    'minima': minima,
    'maxima': maxima,
  };
}

/// Bounded RAM: at most 8192 envelopes and a 64 KiB PCM block. Every channel
/// contributes extrema; anti-phase stereo is not downmixed into false silence.
/// The seekable reference uses temporary disk space proportional to the input.
class AudioWaveformService {
  final Directory? directory;
  final PcmDecoder decoder;
  final int cacheBudgetBytes;
  AudioWaveformService({
    this.directory,
    PcmDecoder? decoder,
    this.cacheBudgetBytes = 256 * 1024 * 1024,
  }) : decoder = decoder ?? FFmpegPcmDecoder();

  Future<Directory> get _root async {
    final folder =
        directory ??
        Directory(
          '${(await getTemporaryDirectory()).path}/studio_waveforms_v1',
        );
    await folder.create(recursive: true);
    return folder;
  }

  Future<WaveformEnvelope> loadProject(
    AudioProject project,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  ) => loadFile(
    project.managedFilePath,
    project.metadata,
    'project_${project.id}_${project.sourceFingerprint}',
    cancellation,
    progress,
  );

  Future<WaveformEnvelope> loadFile(
    String source,
    AudioMetadata metadata,
    String identity,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  ) async {
    AudioModelJson.identifier(identity);
    cancellation.check();
    final stat = await File(source).stat();
    if (stat.type != FileSystemEntityType.file || stat.size == 0) {
      throw const AudioProcessingException(
        'source_missing',
        'The audio file is missing',
      );
    }
    final key =
        '${identity}_${stat.size}_${stat.modified.microsecondsSinceEpoch}';
    final root = await _root;
    final jsonFile = File('${root.path}/$key.json');
    final reference = File('${root.path}/$key.wav');
    if (await jsonFile.exists() && await reference.exists()) {
      try {
        final data =
            jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        if (data['version'] != 1 ||
            await reference.length() != data['referenceBytes']) {
          throw const FormatException('Stale waveform cache');
        }
        final result = WaveformEnvelope(
          referencePath: reference.path,
          frames: data['frames'] as int,
          sampleRate: data['sampleRate'] as int,
          channels: data['channels'] as int,
          minima: (data['minima'] as List)
              .map((v) => (v as num).toDouble())
              .toList(),
          maxima: (data['maxima'] as List)
              .map((v) => (v as num).toDouble())
              .toList(),
        );
        cancellation.check();
        await jsonFile.setLastModified(DateTime.now());
        progress(1);
        return result;
      } on FormatException {
        /* Rebuild corrupt cache from the source. */
      } on TypeError {
        /* Rebuild incompatible cache. */
      }
    }
    final part = File('${reference.path}.${AudioModelJson.newId()}.part');
    final jsonPart = File('${jsonFile.path}.${AudioModelJson.newId()}.part');
    var published = false;
    try {
      await decoder.decode(
        source,
        part.path,
        metadata.duration,
        cancellation,
        (value) => progress(value * 0.65),
      );
      cancellation.check();
      final envelope = await readPcmWave(
        part.path,
        cancellation,
        onProgress: (value) => progress(0.65 + value * 0.35),
      );
      if (envelope.channels != metadata.channels ||
          envelope.sampleRate != metadata.sampleRate) {
        throw const FormatException(
          'Decoded waveform does not match the audio source',
        );
      }
      cancellation.check();
      final document = {
        ...envelope.toJson(),
        'referenceBytes': await part.length(),
      };
      await jsonPart.writeAsString(jsonEncode(document), flush: true);
      await part.rename(reference.path);
      await jsonPart.rename(jsonFile.path);
      published = true;
      await _prune(key);
      progress(1);
      return WaveformEnvelope(
        referencePath: reference.path,
        frames: envelope.frames,
        sampleRate: envelope.sampleRate,
        channels: envelope.channels,
        minima: envelope.minima,
        maxima: envelope.maxima,
      );
    } finally {
      for (final file in [part, jsonPart]) {
        if (await file.exists()) await file.delete();
      }
      if (!published && await reference.exists()) await reference.delete();
    }
  }

  Future<void> _prune(String keepKey) async {
    final root = await _root;
    final entries = await root
        .list()
        .where((file) => file is File && file.path.endsWith('.wav'))
        .cast<File>()
        .toList();
    final stats = <String, FileStat>{};
    for (final file in entries) {
      stats[file.path] = await file.stat();
    }
    entries.sort(
      (a, b) => stats[a.path]!.modified.compareTo(stats[b.path]!.modified),
    );
    var total = stats.values.fold<int>(0, (n, s) => n + s.size);
    var count = entries.length;
    for (final file in entries) {
      if (file.path.endsWith('/$keepKey.wav')) continue;
      if (count <= 3 && total <= cacheBudgetBytes) break;
      total -= stats[file.path]!.size;
      count--;
      await file.delete();
      final json = File(file.path.replaceFirst(RegExp(r'\.wav$'), '.json'));
      if (await json.exists()) await json.delete();
    }
  }

  /// Reads standard/RF64 WAV chunks rather than assuming a 44-byte header.
  static Future<WaveformEnvelope> readPcmWave(
    String path,
    ProcessingCancellation cancellation, {
    int maxBuckets = 8192,
    void Function(double)? onProgress,
  }) async {
    if (maxBuckets < 1 || maxBuckets > 8192)
      throw ArgumentError('Invalid waveform resolution');
    final input = await File(path).open();
    try {
      final length = await input.length();
      final header = await input.read(12);
      if (header.length != 12 ||
          ![
            'RIFF',
            'RF64',
          ].contains(String.fromCharCodes(header.sublist(0, 4))) ||
          String.fromCharCodes(header.sublist(8, 12)) != 'WAVE')
        throw const FormatException('Invalid PCM WAV header');
      int? rate, channels, bits, format, dataStart, dataBytes, rf64Bytes;
      var offset = 12;
      for (var chunks = 0; chunks < 128 && offset + 8 <= length; chunks++) {
        await input.setPosition(offset);
        final chunk = await input.read(8);
        final name = String.fromCharCodes(chunk.sublist(0, 4));
        final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
        if (name == 'ds64') {
          final data = await input.read(math.min(size, 28));
          if (data.length < 16)
            throw const FormatException('Invalid RF64 size');
          rf64Bytes = ByteData.sublistView(data).getUint64(8, Endian.little);
        } else if (name == 'fmt ') {
          final data = await input.read(math.min(size, 64));
          if (data.length < 16)
            throw const FormatException('Invalid PCM format');
          final values = ByteData.sublistView(data);
          format = values.getUint16(0, Endian.little);
          channels = values.getUint16(2, Endian.little);
          rate = values.getUint32(4, Endian.little);
          bits = values.getUint16(14, Endian.little);
          if (format == 65534 && data.length >= 40)
            format = values.getUint16(24, Endian.little);
        } else if (name == 'data') {
          dataStart = offset + 8;
          dataBytes = size == 0xffffffff ? rf64Bytes : size;
          break;
        }
        offset += 8 + size + size % 2;
      }
      if (dataStart == null ||
          dataBytes == null ||
          rate == null ||
          channels == null ||
          channels <= 0 ||
          rate <= 0 ||
          !((format == 3 && bits == 32) || (format == 1 && bits == 16)) ||
          dataStart + dataBytes > length)
        throw const FormatException('Unsupported or truncated PCM WAV');
      final frameBytes = channels * (bits! ~/ 8);
      if (dataBytes == 0 || dataBytes % frameBytes != 0)
        throw const FormatException('Invalid PCM frame size');
      final frames = dataBytes ~/ frameBytes;
      final bucketFrames = (frames / maxBuckets).ceil();
      final minima = <double>[];
      final maxima = <double>[];
      var low = double.infinity,
          high = double.negativeInfinity,
          inBucket = 0,
          consumed = 0;
      await input.setPosition(dataStart);
      while (consumed < frames) {
        cancellation.check();
        final blockFrames = math.min(
          math.max(1, 65536 ~/ frameBytes),
          frames - consumed,
        );
        final block = await input.read(blockFrames * frameBytes);
        if (block.length != blockFrames * frameBytes)
          throw const FormatException('Truncated PCM samples');
        final values = ByteData.sublistView(block);
        for (var frame = 0; frame < blockFrames; frame++) {
          for (var channel = 0; channel < channels; channel++) {
            final byte = frame * frameBytes + channel * (bits ~/ 8);
            final value = format == 3
                ? values.getFloat32(byte, Endian.little)
                : values.getInt16(byte, Endian.little) / 32768;
            if (!value.isFinite)
              throw const FormatException('Nonfinite PCM sample');
            low = math.min(low, value);
            high = math.max(high, value);
          }
          inBucket++;
          if (inBucket == bucketFrames || consumed + frame + 1 == frames) {
            minima.add(low);
            maxima.add(high);
            low = double.infinity;
            high = double.negativeInfinity;
            inBucket = 0;
          }
        }
        consumed += blockFrames;
        onProgress?.call(consumed / frames);
      }
      return WaveformEnvelope(
        referencePath: path,
        frames: frames,
        sampleRate: rate,
        channels: channels,
        minima: minima,
        maxima: maxima,
      );
    } finally {
      await input.close();
    }
  }
}
