import 'dart:async';
import 'dart:io';

import '../../features/models/audio_model_json.dart';
import '../../features/models/audio_project.dart';

enum ProcessingJobState { queued, running, succeeded, failed, cancelled }

class AudioProcessingException implements Exception {
  final String code;
  final String message;
  const AudioProcessingException(this.code, this.message);
  @override
  String toString() => '$code: $message';
}

class ProcessingCancelled implements Exception {
  const ProcessingCancelled();
}

class ProcessingCancellation {
  bool _requested = false;
  Future<void> Function()? _stop;
  Future<void>? _stopFuture;
  bool get isRequested => _requested;

  Future<void> attach(Future<void> Function() stop) async {
    _stop = stop;
    if (_requested) await _stopOnce();
  }

  Future<void> _stopOnce() => _stopFuture ??= _stop!();

  Future<void> cancel() async {
    _requested = true;
    if (_stop != null) await _stopOnce();
  }

  void check() {
    if (_requested) throw const ProcessingCancelled();
  }
}

class ProcessingRequest {
  final AudioProject project;
  final String outputPath;
  ProcessingRequest({required this.project, required this.outputPath}) {
    String normalized(String value) =>
        File(value).absolute.uri.normalizePath().toFilePath();
    if (outputPath.isEmpty ||
        normalized(outputPath) == normalized(project.managedFilePath) ||
        normalized(outputPath) == normalized(project.originalFilePath)) {
      throw ArgumentError('Output must be separate from both source files');
    }
  }
}

class ProcessedAudio {
  final String outputPath;
  final AudioMetadata metadata;
  final int bytes;
  ProcessedAudio({
    required this.outputPath,
    required this.metadata,
    required this.bytes,
  }) {
    if (outputPath.isEmpty || bytes <= 0) {
      throw ArgumentError('Successful processing needs a nonempty output');
    }
  }
}

class ProcessingProgress {
  final String jobId;
  final double fraction;
  const ProcessingProgress(this.jobId, this.fraction);
}

class ProcessingResult {
  final String jobId;
  final ProcessingJobState state;
  final ProcessedAudio? audio;
  final AudioProcessingException? error;
  const ProcessingResult(this.jobId, this.state, {this.audio, this.error});
}

typedef ProcessingOperation =
    Future<ProcessedAudio> Function(
      ProcessingCancellation cancellation,
      void Function(double) progress,
    );

/// One immutable request, one terminal result, and one job-scoped cancel token.
class ProcessingJob {
  final String? ownedOutputPath;
  final String id = AudioModelJson.newId();
  final ProcessingCancellation _cancellation = ProcessingCancellation();
  final StreamController<ProcessingProgress> _progress =
      StreamController.broadcast();
  ProcessingJobState _state = ProcessingJobState.queued;
  double _fraction = 0;
  late final Future<ProcessingResult> result;

  ProcessingJob(ProcessingOperation operation, {this.ownedOutputPath}) {
    result = Future.microtask(() => _run(operation));
  }

  ProcessingJobState get state => _state;
  double get fraction => _fraction;
  bool get isTerminal => [
    ProcessingJobState.succeeded,
    ProcessingJobState.failed,
    ProcessingJobState.cancelled,
  ].contains(_state);
  Stream<ProcessingProgress> get progress => _progress.stream;

  Future<void> cancel() async {
    if (!isTerminal) await _cancellation.cancel();
  }

  void _report(double value) {
    if (_cancellation.isRequested || isTerminal || !value.isFinite) return;
    // Native processing never reports success before validation/finalization.
    _fraction = value.clamp(_fraction, 0.99);
    _progress.add(ProcessingProgress(id, _fraction));
  }

  Future<ProcessingResult> _run(ProcessingOperation operation) async {
    try {
      _cancellation.check();
      _state = ProcessingJobState.running;
      final audio = await operation(_cancellation, _report);
      if (_cancellation.isRequested) {
        // A backend-provided result cannot authorize deleting a source file.
        if (ownedOutputPath != null) {
          final file = File(ownedOutputPath!);
          if (await file.exists()) await file.delete();
        }
        throw const ProcessingCancelled();
      }
      _state = ProcessingJobState.succeeded;
      _fraction = 1;
      _progress.add(ProcessingProgress(id, 1));
      return ProcessingResult(id, _state, audio: audio);
    } catch (error) {
      if (_cancellation.isRequested || error is ProcessingCancelled) {
        _state = ProcessingJobState.cancelled;
        return ProcessingResult(id, _state);
      }
      _state = ProcessingJobState.failed;
      return ProcessingResult(
        id,
        _state,
        error: error is AudioProcessingException
            ? error
            : AudioProcessingException('processing_failed', error.toString()),
      );
    } finally {
      unawaited(_progress.close());
    }
  }
}
