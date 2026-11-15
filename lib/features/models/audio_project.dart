import 'audio_model_json.dart';
import 'processing_config.dart';

class AudioMetadata {
  final Duration duration;
  final int sampleRate;
  final int channels;
  final String codec;

  AudioMetadata({
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.codec,
  }) {
    if (duration <= Duration.zero ||
        sampleRate <= 0 ||
        channels <= 0 ||
        codec.trim().isEmpty) {
      throw ArgumentError('Invalid audio metadata');
    }
  }

  Map<String, dynamic> toJson() => {
    'durationUs': duration.inMicroseconds,
    'sampleRate': sampleRate,
    'channels': channels,
    'codec': codec,
  };

  factory AudioMetadata.fromJson(Map<String, dynamic> json) => AudioMetadata(
    duration: Duration(
      microseconds: AudioModelJson.integer(json, 'durationUs'),
    ),
    sampleRate: AudioModelJson.integer(json, 'sampleRate'),
    channels: AudioModelJson.integer(json, 'channels'),
    codec: AudioModelJson.text(json, 'codec'),
  );
}

class AudioProject {
  final String id;
  final String originalFilePath;
  final String managedFilePath;
  final String fileName;
  final AudioMetadata metadata;
  final Duration trimStart;
  final Duration trimEnd;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sourceBytes;
  final String sourceFingerprint;
  final ProcessingConfig config;

  AudioProject({
    required this.id,
    required this.originalFilePath,
    required this.managedFilePath,
    required this.fileName,
    required this.metadata,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.revision = 0,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.sourceBytes,
    required this.sourceFingerprint,
    ProcessingConfig? config,
  }) : trimEnd = trimEnd ?? metadata.duration,
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       config = config ?? ProcessingConfig() {
    AudioModelJson.identifier(id);
    if ([
          originalFilePath,
          managedFilePath,
          fileName,
        ].any((v) => v.trim().isEmpty) ||
        revision < 0 ||
        sourceBytes <= 0 ||
        sourceFingerprint.isEmpty ||
        updatedAt.isBefore(createdAt) ||
        trimStart < Duration.zero ||
        this.trimEnd > metadata.duration ||
        trimStart >= this.trimEnd) {
      throw ArgumentError('Invalid audio project');
    }
  }

  Duration get duration => metadata.duration;
  int get sampleRate => metadata.sampleRate;
  int get channels => metadata.channels;
  String get codec => metadata.codec;
  Duration get trimmedDuration => trimEnd - trimStart;

  AudioProject copyWith({
    String? originalFilePath,
    String? managedFilePath,
    Duration? trimStart,
    Duration? trimEnd,
    int? revision,
    DateTime? updatedAt,
    ProcessingConfig? config,
  }) => AudioProject(
    id: id,
    originalFilePath: originalFilePath ?? this.originalFilePath,
    managedFilePath: managedFilePath ?? this.managedFilePath,
    fileName: fileName,
    metadata: metadata,
    trimStart: trimStart ?? this.trimStart,
    trimEnd: trimEnd ?? this.trimEnd,
    revision: revision ?? this.revision,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceBytes: sourceBytes,
    sourceFingerprint: sourceFingerprint,
    config: config ?? this.config,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'originalFilePath': originalFilePath,
    'managedFilePath': managedFilePath,
    'fileName': fileName,
    'metadata': metadata.toJson(),
    'trimStartUs': trimStart.inMicroseconds,
    'trimEndUs': trimEnd.inMicroseconds,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'sourceBytes': sourceBytes,
    'sourceFingerprint': sourceFingerprint,
    'config': config.toJson(),
  };

  factory AudioProject.fromJson(Map<String, dynamic> json) {
    AudioModelJson.version(json);
    return AudioProject(
      id: AudioModelJson.text(json, 'id'),
      originalFilePath: AudioModelJson.text(json, 'originalFilePath'),
      managedFilePath: AudioModelJson.text(json, 'managedFilePath'),
      fileName: AudioModelJson.text(json, 'fileName'),
      metadata: AudioMetadata.fromJson(AudioModelJson.object(json['metadata'])),
      trimStart: Duration(
        microseconds: AudioModelJson.integer(json, 'trimStartUs'),
      ),
      trimEnd: Duration(
        microseconds: AudioModelJson.integer(json, 'trimEndUs'),
      ),
      revision: AudioModelJson.integer(json, 'revision'),
      createdAt: DateTime.parse(AudioModelJson.text(json, 'createdAt')),
      updatedAt: DateTime.parse(AudioModelJson.text(json, 'updatedAt')),
      sourceBytes: AudioModelJson.integer(json, 'sourceBytes'),
      sourceFingerprint: AudioModelJson.text(json, 'sourceFingerprint'),
      config: ProcessingConfig.fromJson(AudioModelJson.object(json['config'])),
    );
  }
}
