import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/core/service/audio_processing_backend.dart';
import 'package:untitled/core/service/audio_project_repository.dart';
import 'package:untitled/core/service/playback_ownership.dart';
import 'package:untitled/features/UI/controller/audio_project_controller.dart';
import 'package:untitled/features/UI/controller/audio_analyzer_controller.dart';
import 'package:untitled/features/models/audio_analysis.dart';
import 'package:untitled/features/models/audio_project.dart';
import 'package:untitled/features/models/processing_config.dart';
import 'fixtures.dart';

class ControlledProcessingBackend implements AudioProcessingBackend {
  final entered = Completer<void>();
  final finish = Completer<void>();
  ProcessingRequest? request;
  @override
  ProcessingJob start(ProcessingRequest request) {
    this.request = request;
    return ProcessingJob((cancellation, progress) async {
      await cancellation.attach(() async {
        if (!finish.isCompleted) finish.complete();
      });
      entered.complete();
      progress(0.5);
      await finish.future;
      cancellation.check();
      await writeWave(File(request.outputPath));
      return ProcessedAudio(
        outputPath: request.outputPath,
        metadata: await probeWave(request.outputPath),
        bytes: await File(request.outputPath).length(),
      );
    });
  }
}

// A faulty adapter must not trick controller cleanup into deleting its input.
class PassthroughBackend implements AudioProcessingBackend {
  @override
  ProcessingJob start(ProcessingRequest request) => ProcessingJob(
    (_, _) async => ProcessedAudio(
      outputPath: request.project.originalFilePath,
      metadata: request.project.metadata,
      bytes: request.project.sourceBytes,
    ),
  );
}

class ControlledAnalysisBackend implements AudioAnalysisBackend {
  final List<Completer<AudioAnalysis>> calls = [];
  @override
  Future<AudioAnalysis> analyze(
    AudioProject project,
    ProcessingCancellation cancellation,
    void Function(double) progress,
  ) {
    final result = Completer<AudioAnalysis>();
    calls.add(result);
    progress(0.5);
    return result.future;
  }
}

AudioAnalysis measurement(AudioProject project) => AudioAnalysis(
  projectId: project.id,
  projectRevision: project.revision,
  rangeStart: Duration.zero,
  rangeEnd: project.duration,
  sampleRate: project.sampleRate,
  framesAnalyzed: 480,
  measuredAt: DateTime.now().toUtc(),
  rms: [0.1],
  peaks: [0.2],
  clippingCounts: [0],
);

void main() {
  test(
    'FFmpeg adapter rejects concurrent jobs and permits a retry after failure',
    () async {
      final backend = FFmpegAudioProcessingBackend();
      final request = ProcessingRequest(
        project: sampleProject(),
        outputPath: '/uncreated-output.wav',
      );
      final first = backend.start(request);
      final busy = backend.start(request);
      expect((await busy.result).error?.code, 'busy');
      expect((await first.result).error?.code, 'source_missing');
      expect(
        (await backend.start(request).result).error?.code,
        'source_missing',
      );
    },
  );

  test(
    'Ownership generation prevents an old owner releasing newer playback',
    () {
      final ownership = PlaybackOwnership();
      final old = ownership.claim('voice');
      final current = ownership.claim('studio');
      expect(ownership.release(old), isFalse);
      expect(ownership.owns(current), isTrue);
      expect(ownership.release(current), isTrue);
      expect(ownership.ownerId, isNull);
    },
  );

  test(
    'Jobs report monotonic scoped progress and exactly one success',
    () async {
      final project = sampleProject();
      final job = ProcessingJob((_, progress) async {
        progress(0.6);
        progress(0.2);
        progress(double.nan);
        progress(2);
        return ProcessedAudio(
          outputPath: '/not-created.wav',
          metadata: project.metadata,
          bytes: 1,
        );
      });
      final updates = <ProcessingProgress>[];
      job.progress.listen(updates.add);
      final result = await job.result;
      await Future<void>.delayed(Duration.zero);
      expect(result.state, ProcessingJobState.succeeded);
      expect(updates.map((p) => p.fraction), [0.6, 0.6, 0.99, 1]);
      expect(updates.every((p) => p.jobId == job.id), isTrue);
      await job.cancel();
      expect(job.state, ProcessingJobState.succeeded);
    },
  );

  test('Cancellation before startup does not invoke the processor', () async {
    var invoked = false;
    final job = ProcessingJob((_, _) async {
      invoked = true;
      throw StateError('Must not run');
    });
    await job.cancel();
    expect((await job.result).state, ProcessingJobState.cancelled);
    expect(invoked, isFalse);
  });

  test(
    'Late native cancellation attaches once and waits for operation cleanup',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      var cancellations = 0;
      var cleaned = false;
      final job = ProcessingJob((cancellation, _) async {
        entered.complete();
        await finish.future;
        await cancellation.attach(() async {
          cancellations++;
        });
        cleaned = true;
        cancellation.check();
        throw StateError('Unreachable');
      });
      await entered.future;
      await job.cancel();
      finish.complete();
      expect((await job.result).state, ProcessingJobState.cancelled);
      expect(cancellations, 1);
      expect(cleaned, isTrue);
    },
  );

  test(
    'Processing failures are typed and a paused observer cannot block completion',
    () async {
      final job = ProcessingJob((_, progress) async {
        progress(0.5);
        throw const AudioProcessingException('codec', 'Unsupported codec');
      });
      final subscription = job.progress.listen((_) {})..pause();
      final result = await job.result.timeout(const Duration(seconds: 1));
      expect(result.error?.code, 'codec');
      expect(result.state, ProcessingJobState.failed);
      await subscription.cancel();
    },
  );

  test('Request cannot overwrite either original or managed audio', () {
    final project = sampleProject();
    expect(
      () => ProcessingRequest(
        project: project,
        outputPath: project.originalFilePath,
      ),
      throwsArgumentError,
    );
    expect(
      () => ProcessingRequest(
        project: project,
        outputPath: project.managedFilePath,
      ),
      throwsArgumentError,
    );
  });

  group('Project controller', () {
    late Directory sandbox;
    late File original;
    late AudioProjectRepository repository;
    late ControlledProcessingBackend backend;
    late AudioProjectController controller;
    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('studio_controller_');
      original = await writeWave(File('${sandbox.path}/source.wav'));
      repository = AudioProjectRepository(
        directory: Directory('${sandbox.path}/managed'),
        probe: probeWave,
      );
      backend = ControlledProcessingBackend();
      controller = AudioProjectController(
        repository: repository,
        backend: backend,
      );
    });
    tearDown(() async {
      controller.dispose();
      await sandbox.delete(recursive: true);
    });

    test(
      'Unexpected backend output cannot cause deletion of the original',
      () async {
        controller.dispose();
        controller = AudioProjectController(
          repository: repository,
          backend: PassthroughBackend(),
        );
        await controller.importFile(original.path);
        final originalBytes = await original.readAsBytes();
        expect(await controller.export(), isNull);
        expect(
          (controller.error as AudioProcessingException).code,
          'invalid_output_path',
        );
        expect(await original.readAsBytes(), originalBytes);
        expect(await repository.loadExportHistory(), isEmpty);
      },
    );

    test(
      'Import, revision edit and export commit an immutable history snapshot',
      () async {
        expect(await controller.importFile(original.path), isTrue);
        expect(
          await controller.updateConfiguration(
            ProcessingConfig(exportFormat: ExportFormat.wav),
          ),
          isTrue,
        );
        final revision = controller.project!.revision;
        final exporting = controller.export();
        await backend.entered.future;
        expect(controller.state, AudioProjectState.processing);
        expect(await controller.importFile(original.path), isFalse);
        expect(
          await controller.updateConfiguration(ProcessingConfig(gainDb: 10)),
          isFalse,
        );
        backend.finish.complete();
        final record = await exporting;
        expect(record?.projectRevision, revision);
        expect(controller.state, AudioProjectState.ready);
        expect(controller.history.single.id, record!.id);
        expect(record.config.exportFormat, ExportFormat.wav);
        expect(await original.exists(), isTrue);
      },
    );

    test('Cancellation commits neither output nor history', () async {
      await controller.importFile(original.path);
      final exporting = controller.export();
      await backend.entered.future;
      await controller.cancelProcessing();
      expect(await exporting, isNull);
      expect(await repository.loadExportHistory(), isEmpty);
      expect(await File(backend.request!.outputPath).exists(), isFalse);
      expect(controller.state, AudioProjectState.ready);
    });

    test(
      'Missing file state is recoverable and advances the project revision',
      () async {
        await controller.importFile(original.path);
        final id = controller.project!.id;
        await File(controller.project!.managedFilePath).delete();
        await controller.loadProject(id);
        expect(controller.state, AudioProjectState.missingFile);
        expect(await controller.export(), isNull);
        expect(await controller.recoverFile(), isTrue);
        expect(controller.state, AudioProjectState.ready);
        expect(controller.project!.revision, 1);
      },
    );

    test(
      'Disposal during a native job cancels without notifying a disposed notifier',
      () async {
        await controller.importFile(original.path);
        final exporting = controller.export();
        await backend.entered.future;
        controller.dispose();
        expect(await exporting, isNull);
        expect(await repository.loadExportHistory(), isEmpty);
        // Use another controller so group teardown does not dispose twice.
        controller = AudioProjectController(
          repository: repository,
          backend: backend,
        );
      },
    );

    test(
      'Analyzer invalidates old revision results when the project changes',
      () async {
        await controller.importFile(original.path);
        final measurements = ControlledAnalysisBackend();
        final analyzer = AudioAnalyzerController(
          backend: measurements,
          projects: controller,
        );
        addTearDown(analyzer.dispose);
        final source = controller.project!;
        final pending = analyzer.analyze(source);
        await controller.updateConfiguration(ProcessingConfig(gainDb: 2));
        measurements.calls.single.complete(measurement(source));
        await pending;
        expect(analyzer.analysis, isNull);
        expect(analyzer.state, AudioAnalyzerState.idle);
        final current = controller.project!;
        final next = analyzer.analyze(current);
        measurements.calls.last.complete(measurement(current));
        await next;
        expect(analyzer.analysis!.projectRevision, current.revision);
      },
    );
  });

  test(
    'Analyzer is explicitly unavailable without a real measurement backend',
    () async {
      final analyzer = AudioAnalyzerController();
      addTearDown(analyzer.dispose);
      await analyzer.analyze(sampleProject());
      expect(analyzer.state, AudioAnalyzerState.unavailable);
      expect(analyzer.analysis, isNull);
    },
  );
}
