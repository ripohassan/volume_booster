import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/models/audio_project.dart';
import 'package:untitled/features/models/processing_config.dart';
import 'package:untitled/features/models/audio_analysis.dart';
import 'package:untitled/features/models/export_record.dart';
import 'package:untitled/core/service/processing_filter_builder.dart';
import 'fixtures.dart';

void main() {
  test('Normalization rejects ceilings outside the native loudnorm range', () {
    expect(
      () => ProcessingConfig(normalizationEnabled: true, limiterCeilingDb: -12),
      throwsArgumentError,
    );
    expect(ProcessingConfig(limiterCeilingDb: -12).limiterCeilingDb, -12);
  });

  test('Project edits round-trip all source, timing and processing fields', () {
    final original = sampleProject(
      config: ProcessingConfig(
        gainDb: -3,
        bassGainDb: 4,
        voiceEnabled: true,
        speechClarity: 0.5,
        noiseReduction: 0.7,
        normalizationEnabled: true,
        exportFormat: ExportFormat.wav,
      ),
    );
    final edited = original.copyWith(
      trimStart: const Duration(milliseconds: 100),
      trimEnd: const Duration(milliseconds: 800),
      revision: 1,
    );
    final restored = AudioProject.fromJson(
      jsonDecode(jsonEncode(edited.toJson())),
    );
    expect(restored.toJson(), edited.toJson());
    expect(restored.trimmedDuration, const Duration(milliseconds: 700));
    expect(original.revision, 0);
  });

  test('Projects reject traversal IDs, inverted trims and future schemas', () {
    final json = sampleProject().toJson();
    expect(
      () => AudioProject.fromJson({...json, 'id': '../outside'}),
      throwsArgumentError,
    );
    expect(
      () => sampleProject().copyWith(trimStart: const Duration(seconds: 1)),
      throwsArgumentError,
    );
    expect(
      () => sampleProject().copyWith(trimEnd: const Duration(seconds: 2)),
      throwsArgumentError,
    );
    expect(
      () => AudioProject.fromJson({...json, 'schemaVersion': 2}),
      throwsFormatException,
    );
  });

  test(
    'Configuration is defensively immutable and validates all numeric bounds',
    () {
      final bands = List<double>.filled(10, 0);
      final config = ProcessingConfig(eqBands: bands);
      bands[0] = 15;
      expect(config.eqBands[0], 0);
      expect(() => config.eqBands[0] = 1, throwsUnsupportedError);
      expect(() => ProcessingConfig(gainDb: double.nan), throwsArgumentError);
      expect(() => ProcessingConfig(eqBands: [0]), throwsArgumentError);
      expect(() => ProcessingConfig(noiseReduction: 1.1), throwsArgumentError);
      expect(() => ProcessingConfig(limiterCeilingDb: 0), throwsArgumentError);
      expect(
        () => ProcessingConfig.fromJson({
          ...config.toJson(),
          'exportFormat': 'unknown',
        }),
        throwsFormatException,
      );
      expect(
        ProcessingConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())),
        ).toJson(),
        config.toJson(),
      );
    },
  );

  test('Filter recipe uses independent bands and valid DSP controls', () {
    final config = ProcessingConfig(
      eqBands: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      bassGainDb: 2,
      voiceEnabled: true,
      noiseReduction: 0.5,
      speechClarity: 0.5,
    );
    final filters = ProcessingFilterBuilder.build(config, sampleRate: 48000);
    for (final frequency in ProcessingConfig.frequencies) {
      expect(filters, contains('equalizer=f=$frequency:'));
    }
    expect(filters, contains('afftdn=nr=15.0:nf=-50'));
    expect(filters, contains('level=0'));
    expect(
      ProcessingFilterBuilder.build(config, sampleRate: 16000),
      isNot(contains('equalizer=f=16000:')),
    );
    expect(
      ProcessingFilterBuilder.build(
        config.copyWith(limiterEnabled: false),
        sampleRate: 48000,
      ),
      isNot(contains('alimiter')),
    );
  });

  test('Measured silence stays JSON-safe and has negative infinity dBFS', () {
    final measured = AudioAnalysis(
      projectId: 'p',
      projectRevision: 2,
      rangeStart: Duration.zero,
      rangeEnd: const Duration(seconds: 1),
      sampleRate: 48000,
      framesAnalyzed: 48000,
      measuredAt: DateTime.utc(2026),
      rms: [0],
      peaks: [0],
      clippingCounts: [0],
    );
    final decoded = AudioAnalysis.fromJson(
      jsonDecode(jsonEncode(measured.toJson())),
    );
    expect(decoded.rmsDbfs.single, double.negativeInfinity);
    expect(decoded.peakDbfs.single, double.negativeInfinity);
    expect(
      () => AudioAnalysis(
        projectId: 'p',
        projectRevision: 0,
        rangeStart: Duration.zero,
        rangeEnd: const Duration(seconds: 1),
        sampleRate: 48000,
        framesAnalyzed: 10,
        measuredAt: DateTime.utc(2026),
        rms: [1],
        peaks: [0.5],
        clippingCounts: [11],
      ),
      throwsArgumentError,
    );
  });

  test(
    'Export records retain exact configuration and measured output metadata',
    () {
      final project = sampleProject();
      final record = ExportRecord(
        id: 'export',
        jobId: 'job',
        projectId: project.id,
        projectRevision: 0,
        outputPath: '/output.wav',
        bytes: 96044,
        metadata: project.metadata,
        config: project.config,
        createdAt: DateTime.utc(2026),
      );
      expect(
        ExportRecord.fromJson(jsonDecode(jsonEncode(record.toJson()))).toJson(),
        record.toJson(),
      );
    },
  );
}
