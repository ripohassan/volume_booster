import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/core/service/audio_project_repository.dart';
import 'package:untitled/features/models/export_record.dart';
import 'package:untitled/features/models/processing_config.dart';
import 'fixtures.dart';

void main() {
  late Directory sandbox;
  late File original;
  late AudioProjectRepository repository;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('studio_repository_');
    original = await writeWave(File('${sandbox.path}/external/original.wav'));
    repository = AudioProjectRepository(
      directory: Directory('${sandbox.path}/managed'),
      probe: probeWave,
    );
  });
  tearDown(() async {
    await sandbox.delete(recursive: true);
  });

  test(
    'Truncated managed audio can be restored without touching the original',
    () async {
      final project = await repository.importFile(original.path);
      final originalBytes = await original.readAsBytes();
      await File(project.managedFilePath).writeAsBytes([0]);
      expect(
        (await repository.loadProject(project.id))!.fileStatus,
        ProjectFileStatus.recoverable,
      );
      await repository.recoverProject(project.id);
      expect(await File(project.managedFilePath).readAsBytes(), originalBytes);
      expect(await original.readAsBytes(), originalBytes);
    },
  );

  test(
    'Import preserves original bytes and persists relocatable managed paths',
    () async {
      final bytes = await original.readAsBytes();
      final project = await repository.importFile(original.path);
      expect(await File(project.managedFilePath).readAsBytes(), bytes);
      expect(await original.readAsBytes(), bytes);
      expect(project.sampleRate, 48000);
      final manifest = File(
        '${(await repository.root).path}/projects/${project.id}/project.json',
      );
      final json = jsonDecode(await manifest.readAsString()) as Map;
      expect(json['managedFilePath'], 'source.wav');
      expect((await repository.listProjects()).single.id, project.id);
      final relocated = Directory('${sandbox.path}/relocated');
      await (await repository.root).rename(relocated.path);
      final reopened = AudioProjectRepository(
        directory: relocated,
        probe: probeWave,
      );
      final loaded = (await reopened.loadProject(project.id))!;
      expect(loaded.fileStatus, ProjectFileStatus.available);
      expect(loaded.project.managedFilePath, startsWith(relocated.path));
    },
  );

  test(
    'Revision conflicts preserve previous JSON and leave queue usable',
    () async {
      final project = await repository.importFile(original.path);
      final edit = project.copyWith(
        revision: 1,
        config: ProcessingConfig(gainDb: 3),
      );
      await repository.saveProject(edit, expectedRevision: 0);
      await expectLater(
        repository.saveProject(edit, expectedRevision: 0),
        throwsA(isA<ProjectRevisionConflict>()),
      );
      final loaded = (await repository.loadProject(project.id))!.project;
      expect(loaded.revision, 1);
      expect(loaded.config.gainDb, 3);
      final leftovers = await (await repository.root)
          .list(recursive: true)
          .where((e) => e.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test('Managed-file recovery copies only the matching original', () async {
    final project = await repository.importFile(original.path);
    await File(project.managedFilePath).delete();
    expect(
      (await repository.loadProject(project.id))!.fileStatus,
      ProjectFileStatus.recoverable,
    );
    final other = await writeWave(File('${sandbox.path}/other.wav'), seed: 2);
    await expectLater(
      repository.recoverProject(project.id, replacementPath: other.path),
      throwsFormatException,
    );
    expect(await File(project.managedFilePath).exists(), isFalse);
    final recovered = await repository.recoverProject(project.id);
    expect(recovered.revision, 1);
    expect(
      await File(recovered.managedFilePath).readAsBytes(),
      await original.readAsBytes(),
    );
  });

  test(
    'Missing original is explicit, replacement recovery preserves identity',
    () async {
      final project = await repository.importFile(original.path);
      final replacement = await original.copy('${sandbox.path}/selected.wav');
      await original.delete();
      await File(project.managedFilePath).delete();
      expect(
        (await repository.loadProject(project.id))!.fileStatus,
        ProjectFileStatus.missing,
      );
      await expectLater(
        repository.recoverProject(project.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await repository.recoverProject(
          project.id,
          replacementPath: replacement.path,
        )).originalFilePath,
        replacement.path,
      );
    },
  );

  test(
    'Failed probing removes partial project without changing original',
    () async {
      final failing = AudioProjectRepository(
        directory: Directory('${sandbox.path}/failed'),
        probe: (_) async => throw const FormatException('Unsupported audio'),
      );
      await expectLater(
        failing.importFile(original.path),
        throwsFormatException,
      );
      expect(await failing.listProjects(), isEmpty);
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'Malformed/traversing JSON fails rather than accessing external files',
    () async {
      final project = await repository.importFile(original.path);
      final manifest = File(
        '${(await repository.root).path}/projects/${project.id}/project.json',
      );
      final doc =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      await manifest.writeAsString(
        jsonEncode({...doc, 'managedFilePath': '../../external/original.wav'}),
      );
      await expectLater(
        repository.loadProject(project.id),
        throwsFormatException,
      );
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'History persists snapshots and retains missing output records',
    () async {
      final project = await repository.importFile(original.path);
      final path = await repository.allocateExportPath(ExportFormat.wav);
      await original.copy(path);
      final record = ExportRecord(
        id: 'export1',
        jobId: 'job1',
        projectId: project.id,
        projectRevision: 0,
        outputPath: path,
        bytes: await File(path).length(),
        metadata: await probeWave(path),
        config: project.config,
        createdAt: DateTime.now().toUtc(),
      );
      await repository.recordExport(record);
      expect(
        (await repository.loadExportHistory()).single.toJson(),
        record.toJson(),
      );
      await expectLater(repository.recordExport(record), throwsStateError);
      await File(path).delete();
      expect(await repository.isExportAvailable(record), isFalse);
      expect(await repository.loadExportHistory(), hasLength(1));
    },
  );
}
