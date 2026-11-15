import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/service/audio_processing_backend.dart';
import '../../../core/service/audio_project_repository.dart';
import '../../models/audio_model_json.dart';
import '../../models/audio_project.dart';
import '../../models/export_record.dart';
import '../../models/processing_config.dart';

enum AudioProjectState { empty, loading, ready, missingFile, processing, error }

class AudioProjectController extends ChangeNotifier {
  final AudioProjectRepository repository;
  final AudioProcessingBackend backend;
  AudioProject? _project;
  AudioProjectState _state = AudioProjectState.empty;
  List<ExportRecord> _history = const [];
  Object? _error;
  ProcessingJob? _job;
  StreamSubscription<ProcessingProgress>? _progressSubscription;
  double _progress = 0;
  bool _disposed = false;
  bool _cancelRequested = false;

  AudioProjectController({required this.repository, required this.backend});
  AudioProject? get project => _project;
  AudioProjectState get state => _state;
  List<ExportRecord> get history => _history;
  Object? get error => _error;
  String? get activeJobId => _job?.id;
  double get progress => _progress;
  bool get isBusy =>
      _state == AudioProjectState.loading ||
      _state == AudioProjectState.processing;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _change(Future<LoadedAudioProject> Function() action) async {
    if (_disposed || isBusy) return false;
    _state = AudioProjectState.loading;
    _error = null;
    _notify();
    try {
      final loaded = await action();
      final history = await repository.loadExportHistory(
        projectId: loaded.project.id,
      );
      if (_disposed) return false;
      _project = loaded.project;
      _history = history;
      _state = loaded.fileStatus == ProjectFileStatus.available
          ? AudioProjectState.ready
          : AudioProjectState.missingFile;
      return true;
    } catch (error) {
      if (!_disposed) {
        _error = error;
        _state = AudioProjectState.error;
      }
      return false;
    } finally {
      _notify();
    }
  }

  Future<bool> importFile(String path, {String? fileName}) => _change(
    () async => LoadedAudioProject(
      await repository.importFile(path, fileName: fileName),
      ProjectFileStatus.available,
    ),
  );

  Future<bool> loadProject(String id) => _change(() async {
    final loaded = await repository.loadProject(id);
    if (loaded == null) throw FileSystemException('Unknown project', id);
    return loaded;
  });

  Future<bool> recoverFile({String? replacementPath}) {
    final current = _project;
    if (current == null) return Future.value(false);
    return _change(
      () async => LoadedAudioProject(
        await repository.recoverProject(
          current.id,
          replacementPath: replacementPath,
        ),
        ProjectFileStatus.available,
      ),
    );
  }

  Future<bool> updateConfiguration(
    ProcessingConfig config, {
    Duration? trimStart,
    Duration? trimEnd,
  }) {
    final current = _project;
    if (current == null || _state != AudioProjectState.ready) {
      return Future.value(false);
    }
    return _change(() async {
      final next = current.copyWith(
        config: config,
        trimStart: trimStart,
        trimEnd: trimEnd,
        revision: current.revision + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await repository.saveProject(next, expectedRevision: current.revision);
      return LoadedAudioProject(next, ProjectFileStatus.available);
    });
  }

  Future<ExportRecord?> export() async {
    final output = await _render(recordHistory: true);
    return output as ExportRecord?;
  }

  /// Renders the exact project recipe to a temporary WAV for A/B playback.
  /// WAV is intentionally used only as a seekable preview container; DSP and
  /// trim settings are identical to the final export.
  Future<ProcessedAudio?> preview() async {
    final output = await _render(recordHistory: false);
    return output as ProcessedAudio?;
  }

  Future<Object?> _render({required bool recordHistory}) async {
    final current = _project;
    if (_disposed || current == null || _state != AudioProjectState.ready) {
      return null;
    }
    _state = AudioProjectState.processing;
    _error = null;
    _progress = 0;
    _cancelRequested = false;
    _notify();
    String? allocatedPath;
    var committed = false;
    try {
      final path = recordHistory
          ? await repository.allocateExportPath(current.config.exportFormat)
          : await repository.allocatePreviewPath(ExportFormat.wav);
      allocatedPath = path;
      if (_disposed || _cancelRequested) return null;
      final renderedProject = recordHistory
          ? current
          : current.copyWith(
              config: current.config.copyWith(exportFormat: ExportFormat.wav),
            );
      final job = _job = backend.start(
        ProcessingRequest(project: renderedProject, outputPath: path),
      );
      _progressSubscription = job.progress.listen((value) {
        if (_job?.id != value.jobId || _disposed) return;
        _progress = value.fraction;
        _notify();
      });
      final result = await job.result;
      if (result.state != ProcessingJobState.succeeded) {
        _error = result.error;
        return null;
      }
      final audio = result.audio!;
      if (File(audio.outputPath).absolute.uri.normalizePath() !=
          File(path).absolute.uri.normalizePath()) {
        throw const AudioProcessingException(
          'invalid_output_path',
          'Processing backend returned an unexpected output file',
        );
      }
      if (_disposed || _cancelRequested) return null;
      if (!recordHistory) {
        committed = true;
        return audio;
      }
      final extension = current.config.exportFormat == ExportFormat.aac
          ? 'm4a'
          : current.config.exportFormat.name;
      final base = current.fileName.replaceFirst(RegExp(r'\.[^.]*$'), '');
      final record = ExportRecord(
        id: AudioModelJson.newId(),
        jobId: job.id,
        projectId: current.id,
        projectRevision: current.revision,
        outputPath: audio.outputPath,
        bytes: audio.bytes,
        metadata: audio.metadata,
        config: current.config,
        createdAt: DateTime.now().toUtc(),
        fileName: '${base}_enhanced.$extension',
      );
      await repository.recordExport(record);
      committed = true;
      _history = await repository.loadExportHistory(projectId: current.id);
      return record;
    } catch (error) {
      _error = error;
      return null;
    } finally {
      // No hidden successful-looking file when history persistence failed.
      try {
        if (!committed &&
            allocatedPath != null &&
            await File(allocatedPath).exists()) {
          await File(allocatedPath).delete();
        }
      } catch (cleanupError) {
        _error ??= cleanupError;
      }
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      _job = null;
      if (!_disposed) _state = AudioProjectState.ready;
      _notify();
    }
  }

  Future<void> refreshHistory() async {
    final current = _project;
    if (current == null) return;
    _history = await repository.loadExportHistory(projectId: current.id);
    _notify();
  }

  Future<void> deleteExport(String id) async {
    await repository.deleteExport(id);
    await refreshHistory();
  }

  Future<void> cancelProcessing() async {
    if (_state == AudioProjectState.processing) _cancelRequested = true;
    try {
      await _job?.cancel();
    } catch (error) {
      _error = error;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancelProcessing());
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }
}
