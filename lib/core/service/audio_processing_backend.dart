import 'ffmpeg_service.dart';
import 'processing_job.dart';

export 'processing_job.dart';

abstract interface class AudioProcessingBackend {
  ProcessingJob start(ProcessingRequest request);
}

/// Adds lifecycle/serialization around the existing native FFmpeg service.
class FFmpegAudioProcessingBackend implements AudioProcessingBackend {
  final FFmpegService _service;
  ProcessingJob? _active;
  FFmpegAudioProcessingBackend({FFmpegService? service})
    : _service = service ?? FFmpegService();

  @override
  ProcessingJob start(ProcessingRequest request) {
    if (_active != null && !_active!.isTerminal) {
      return ProcessingJob(
        (_, _) async => throw const AudioProcessingException(
          'busy',
          'An offline processing job is already running',
        ),
      );
    }
    return _active = ProcessingJob(
      (cancellation, progress) =>
          _service.processProject(request, cancellation, onProgress: progress),
      ownedOutputPath: request.outputPath,
    );
  }
}
