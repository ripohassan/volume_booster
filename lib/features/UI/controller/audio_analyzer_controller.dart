import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/service/processing_job.dart';
import '../../models/audio_analysis.dart';
import '../../models/audio_project.dart';
import 'audio_project_controller.dart';

/// A decoder/measurement implementation can be injected without UI or fake data.
abstract interface class AudioAnalysisBackend {
  Future<AudioAnalysis> analyze(
    AudioProject project,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  );
}

enum AudioAnalyzerState { unavailable, idle, analyzing, ready, error }

class AudioAnalyzerController extends ChangeNotifier {
  final AudioAnalysisBackend? backend;
  final AudioProjectController? projects;
  String? _boundProject;
  AudioAnalysis? _analysis;
  Object? _error;
  double _progress = 0;
  int _generation = 0;
  bool _disposed = false;
  ProcessingCancellation? _cancellation;
  late AudioAnalyzerState _state;

  AudioAnalyzerController({this.backend, this.projects}) {
    _state = backend == null
        ? AudioAnalyzerState.unavailable
        : AudioAnalyzerState.idle;
    projects?.addListener(_projectChanged);
    _projectChanged();
  }
  void _projectChanged() {
    final project = projects?.project;
    final key = project == null ? null : '${project.id}:${project.revision}';
    if (key == _boundProject) return;
    _boundProject = key;
    invalidate();
  }

  AudioAnalysis? get analysis => _analysis;
  AudioAnalyzerState get state => _state;
  Object? get error => _error;
  double get progress => _progress;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Called when the shared project's identity, source or revision changes.
  void invalidate() {
    _generation++;
    final previous = _cancellation;
    if (previous != null) {
      unawaited(previous.cancel().catchError((Object _) {}));
    }
    _cancellation = null;
    _analysis = null;
    _progress = 0;
    _error = null;
    _state = backend == null
        ? AudioAnalyzerState.unavailable
        : AudioAnalyzerState.idle;
    _notify();
  }

  Future<void> analyze(AudioProject project) async {
    if (_disposed) return;
    invalidate();
    if (backend == null) return;
    final generation = _generation;
    final cancellation = _cancellation = ProcessingCancellation();
    _state = AudioAnalyzerState.analyzing;
    _notify();
    try {
      final measured = await backend!.analyze(project, cancellation, (value) {
        if (_disposed || generation != _generation || !value.isFinite) return;
        _progress = value.clamp(_progress, 0.99);
        _notify();
      });
      if (_disposed || generation != _generation || cancellation.isRequested) {
        return;
      }
      if (measured.projectId != project.id ||
          measured.projectRevision != project.revision ||
          measured.sampleRate != project.sampleRate ||
          measured.rms.length != project.channels ||
          measured.rangeEnd > project.duration) {
        throw StateError(
          'Analysis belongs to a different audio source or revision',
        );
      }
      _analysis = measured;
      _progress = 1;
      _state = AudioAnalyzerState.ready;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
      _state = AudioAnalyzerState.error;
    } finally {
      if (generation == _generation) _cancellation = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    projects?.removeListener(_projectChanged);
    invalidate();
    super.dispose();
  }
}
