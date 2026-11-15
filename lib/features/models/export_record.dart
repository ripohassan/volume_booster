import 'audio_model_json.dart';
import 'audio_project.dart';
import 'processing_config.dart';

/// Only successful, probed files belong in durable export history.
class ExportRecord {
  final String id;
  final String jobId;
  final String projectId;
  final int projectRevision;
  final String outputPath;
  final int bytes;
  final AudioMetadata metadata;
  final ProcessingConfig config;
  final DateTime createdAt;
  final String? fileName;
  String get displayName => fileName ?? outputPath.split('/').last;

  ExportRecord({
    required this.id,
    required this.jobId,
    required this.projectId,
    required this.projectRevision,
    required this.outputPath,
    required this.bytes,
    required this.metadata,
    required this.config,
    required this.createdAt,
    this.fileName,
  }) {
    for (final value in [id, jobId, projectId]) {
      AudioModelJson.identifier(value);
    }
    if (projectRevision < 0 || bytes <= 0 || outputPath.isEmpty) {
      throw ArgumentError('Invalid export record');
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'jobId': jobId,
    'projectId': projectId,
    'projectRevision': projectRevision,
    'outputPath': outputPath,
    'bytes': bytes,
    'metadata': metadata.toJson(),
    'config': config.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (fileName != null) 'fileName': fileName,
  };

  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    AudioModelJson.version(json);
    return ExportRecord(
      id: AudioModelJson.text(json, 'id'),
      jobId: AudioModelJson.text(json, 'jobId'),
      projectId: AudioModelJson.text(json, 'projectId'),
      projectRevision: AudioModelJson.integer(json, 'projectRevision'),
      outputPath: AudioModelJson.text(json, 'outputPath'),
      bytes: AudioModelJson.integer(json, 'bytes'),
      metadata: AudioMetadata.fromJson(AudioModelJson.object(json['metadata'])),
      config: ProcessingConfig.fromJson(AudioModelJson.object(json['config'])),
      createdAt: DateTime.parse(AudioModelJson.text(json, 'createdAt')),
      fileName: json['fileName'] as String?,
    );
  }
}
