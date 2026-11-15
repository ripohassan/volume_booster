import 'dart:io';
import 'dart:typed_data';
import 'package:untitled/features/models/audio_project.dart';
import 'package:untitled/features/models/processing_config.dart';

Future<File> writeWave(
  File file, {
  int frames = 480,
  int sampleRate = 48000,
  int seed = 1,
}) async {
  final bytes = Uint8List(44 + frames * 2);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (var frame = 0; frame < frames; frame++) {
    data.setInt16(44 + frame * 2, seed * (frame % 20), Endian.little);
  }
  await file.parent.create(recursive: true);
  return file.writeAsBytes(bytes, flush: true);
}

// An actual tiny PCM WAV decoder for repository tests; no native plugin mock
// invents imported duration/rate/channel metadata.
Future<AudioMetadata> probeWave(String path) async {
  final bytes = await File(path).readAsBytes();
  if (bytes.length < 44 ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw const FormatException('Invalid test WAV');
  }
  final data = ByteData.sublistView(bytes);
  final rate = data.getUint32(24, Endian.little);
  final channels = data.getUint16(22, Endian.little);
  final frames =
      data.getUint32(40, Endian.little) ~/ data.getUint16(32, Endian.little);
  return AudioMetadata(
    duration: Duration(microseconds: (frames * 1000000 / rate).round()),
    sampleRate: rate,
    channels: channels,
    codec: 'pcm_s16le',
  );
}

AudioProject sampleProject({int revision = 0, ProcessingConfig? config}) =>
    AudioProject(
      id: 'project_1',
      originalFilePath: '/original.wav',
      managedFilePath: '/managed.wav',
      fileName: 'sample.wav',
      metadata: AudioMetadata(
        duration: const Duration(seconds: 1),
        sampleRate: 48000,
        channels: 1,
        codec: 'pcm_s16le',
      ),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      revision: revision,
      sourceBytes: 96044,
      sourceFingerprint: 'abcdef01',
      config: config,
    );
