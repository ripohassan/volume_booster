import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../features/models/audio_model_json.dart';
import '../../features/models/audio_project.dart';
import '../../features/models/export_record.dart';
import 'ffmpeg_service.dart';

typedef AudioMetadataProbe = Future<AudioMetadata> Function(String path);

enum ProjectFileStatus { available, recoverable, missing }

class LoadedAudioProject {
  final AudioProject project;
  final ProjectFileStatus fileStatus;
  const LoadedAudioProject(this.project, this.fileStatus);
}

class ProjectRevisionConflict implements Exception {
  final String projectId;
  const ProjectRevisionConflict(this.projectId);
  @override
  String toString() => 'Project $projectId was changed by another operation';
}

/// App-owned files + versioned JSON. A single instance serializes writes.
/// Store relative managed paths so an iOS sandbox relocation remains readable.
class AudioProjectRepository {
  final Directory? directory;
  final AudioMetadataProbe _probe;
  Future<Directory>? _rootFuture;
  Future<void> _tail = Future.value();

  AudioProjectRepository({this.directory, AudioMetadataProbe? probe})
    : _probe = probe ?? FFmpegService().probeFile;

  Future<Directory> get root => _rootFuture ??= _openRoot();

  Future<Directory> _openRoot() async {
    final dir =
        directory ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}/SmartAudioStudio',
        );
    await dir.create(recursive: true);
    return Directory(dir.absolute.path);
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<Directory> _projectDirectory(String id) async {
    AudioModelJson.identifier(id);
    return Directory('${(await root).path}/projects/$id');
  }

  String _relative(String base, String path) {
    final normalized = File(path).absolute.uri.normalizePath().toFilePath();
    final prefix = '${Directory(base).absolute.path}/';
    if (!normalized.startsWith(prefix)) {
      throw ArgumentError('File outside managed storage');
    }
    return normalized.substring(prefix.length);
  }

  String _resolve(String base, String relative) {
    if (relative.startsWith('/') ||
        relative.contains('\\') ||
        relative.split('/').any((s) => s == '..' || s.isEmpty)) {
      throw const FormatException('Unsafe managed path');
    }
    final path = '$base/$relative';
    _relative(base, path);
    return path;
  }

  Future<void> _atomicJson(File file, Object document) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${AudioModelJson.newId()}.tmp');
    try {
      await temp.writeAsString(jsonEncode(document), flush: true);
      // Same-directory rename atomically replaces on the supported iOS/Android
      // filesystems. Do not delete the old document before this succeeds.
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// Streaming FNV-1a is a recovery identity check, not a security signature.
  Future<String> _copy(File source, File destination) async {
    final sink = await destination.open(mode: FileMode.write);
    var checksum = 2166136261;
    try {
      await for (final chunk in source.openRead()) {
        await sink.writeFrom(chunk);
        for (final byte in chunk) {
          checksum = ((checksum ^ byte) * 16777619) & 0xffffffff;
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return checksum.toRadixString(16).padLeft(8, '0');
  }

  Future<AudioProject> importFile(String sourcePath, {String? fileName}) =>
      _locked(() async {
        final source = File(sourcePath).absolute;
        if (!await source.exists() || await source.length() == 0) {
          throw FileSystemException(
            'Audio source is missing or empty',
            sourcePath,
          );
        }
        final id = AudioModelJson.newId();
        final dir = await _projectDirectory(id);
        await dir.create(recursive: true);
        final name = fileName ?? source.uri.pathSegments.last;
        final extension = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : '';
        final safeExtension = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
            ? '.$extension'
            : '';
        final part = File('${dir.path}/source$safeExtension.part');
        final managed = File('${dir.path}/source$safeExtension');
        try {
          final fingerprint = await _copy(source, part);
          final metadata = await _probe(part.path);
          final bytes = await part.length();
          await part.rename(managed.path);
          final now = DateTime.now().toUtc();
          final project = AudioProject(
            id: id,
            originalFilePath: source.path,
            managedFilePath: managed.path,
            fileName: name,
            metadata: metadata,
            createdAt: now,
            updatedAt: now,
            sourceBytes: bytes,
            sourceFingerprint: fingerprint,
          );
          await _writeProject(project);
          return project;
        } catch (_) {
          await dir.delete(recursive: true);
          rethrow;
        }
      });

  Future<void> _writeProject(AudioProject project) async {
    final dir = await _projectDirectory(project.id);
    final data = project.toJson();
    data['managedFilePath'] = _relative(dir.path, project.managedFilePath);
    await _atomicJson(File('${dir.path}/project.json'), data);
  }

  Future<AudioProject?> _load(String id) async {
    final dir = await _projectDirectory(id);
    final file = File('${dir.path}/project.json');
    if (!await file.exists()) return null;
    final data = AudioModelJson.object(jsonDecode(await file.readAsString()));
    data['managedFilePath'] = _resolve(
      dir.path,
      AudioModelJson.text(data, 'managedFilePath'),
    );
    final project = AudioProject.fromJson(data);
    if (project.id != id) {
      throw const FormatException('Project identity mismatch');
    }
    return project;
  }

  Future<LoadedAudioProject?> loadProject(String id) => _locked(() async {
    final project = await _load(id);
    if (project == null) return null;
    final status = await _managedFileAvailable(project)
        ? ProjectFileStatus.available
        : await File(project.originalFilePath).exists()
        ? ProjectFileStatus.recoverable
        : ProjectFileStatus.missing;
    return LoadedAudioProject(project, status);
  });

  Future<bool> _managedFileAvailable(AudioProject project) async {
    final file = File(project.managedFilePath);
    return await file.exists() && await file.length() == project.sourceBytes;
  }

  Future<List<AudioProject>> listProjects() => _locked(() async {
    final dir = Directory('${(await root).path}/projects');
    if (!await dir.exists()) return [];
    final result = <AudioProject>[];
    await for (final entry in dir.list()) {
      if (entry is Directory &&
          await File('${entry.path}/project.json').exists()) {
        final project = await _load(
          entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
        );
        if (project != null) result.add(project);
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(result);
  });

  Future<void> saveProject(
    AudioProject project, {
    required int expectedRevision,
  }) => _locked(() async {
    final current = await _load(project.id);
    if (current == null ||
        current.revision != expectedRevision ||
        project.revision != expectedRevision + 1) {
      throw ProjectRevisionConflict(project.id);
    }
    if (current.managedFilePath != project.managedFilePath ||
        current.sourceFingerprint != project.sourceFingerprint ||
        current.sourceBytes != project.sourceBytes ||
        current.createdAt != project.createdAt ||
        jsonEncode(current.metadata.toJson()) !=
            jsonEncode(project.metadata.toJson())) {
      throw ArgumentError('Editing must preserve source identity');
    }
    await _writeProject(project);
  });

  Future<AudioProject> recoverProject(
    String id, {
    String? replacementPath,
  }) => _locked(() async {
    final current = await _load(id);
    if (current == null) throw FileSystemException('Unknown audio project', id);
    if (await _managedFileAvailable(current)) return current;
    final source = File(replacementPath ?? current.originalFilePath).absolute;
    if (!await source.exists()) {
      throw FileSystemException(
        'Choose the original file to recover',
        source.path,
      );
    }
    final part = File(
      '${current.managedFilePath}.${AudioModelJson.newId()}.part',
    );
    try {
      final fingerprint = await _copy(source, part);
      if (fingerprint != current.sourceFingerprint ||
          await part.length() != current.sourceBytes) {
        throw const FormatException(
          'Recovery file does not match the imported source',
        );
      }
      await _probe(part.path);
      await part.rename(current.managedFilePath);
      final restored = current.copyWith(
        originalFilePath: source.path,
        revision: current.revision + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await _writeProject(restored);
      return restored;
    } finally {
      if (await part.exists()) await part.delete();
    }
  });

  Future<String> allocateExportPath(ExportFormat format) async {
    final dir = Directory('${(await root).path}/exports');
    await dir.create(recursive: true);
    final extension = format == ExportFormat.aac ? 'm4a' : format.name;
    return '${dir.path}/${AudioModelJson.newId()}.$extension';
  }

  Future<String> allocatePreviewPath(ExportFormat format) async {
    final base = directory != null ? await root : await getTemporaryDirectory();
    final folder = Directory('${base.path}/SmartAudioStudio_previews');
    await folder.create(recursive: true);
    final extension = format == ExportFormat.aac ? 'm4a' : format.name;
    return '${folder.path}/${AudioModelJson.newId()}.$extension';
  }

  Future<List<ExportRecord>> _history() async {
    final dir = await root;
    final file = File('${dir.path}/exports.json');
    if (!await file.exists()) return [];
    final doc = AudioModelJson.object(jsonDecode(await file.readAsString()));
    AudioModelJson.version(doc);
    return (doc['records'] as List).map((value) {
      final data = AudioModelJson.object(value);
      data['outputPath'] = _resolve(
        dir.path,
        AudioModelJson.text(data, 'outputPath'),
      );
      return ExportRecord.fromJson(data);
    }).toList();
  }

  Future<void> recordExport(ExportRecord record) => _locked(() async {
    final project = await _load(record.projectId);
    if (project == null || record.projectRevision > project.revision) {
      throw ArgumentError('Unknown project revision');
    }
    final dir = await root;
    _relative('${dir.path}/exports', record.outputPath);
    final output = File(record.outputPath);
    if (!await output.exists() || await output.length() != record.bytes) {
      throw FileSystemException(
        'Export is missing or incomplete',
        record.outputPath,
      );
    }
    final records = await _history();
    if (records.any((r) => r.id == record.id || r.jobId == record.jobId)) {
      throw StateError('Export already recorded');
    }
    records.insert(0, record);
    await _atomicJson(File('${dir.path}/exports.json'), {
      'schemaVersion': 1,
      'records': records
          .map(
            (r) => {
              ...r.toJson(),
              'outputPath': _relative(dir.path, r.outputPath),
            },
          )
          .toList(),
    });
  });

  Future<List<ExportRecord>> loadExportHistory({String? projectId}) => _locked(
    () async => List.unmodifiable(
      (await _history()).where(
        (r) => projectId == null || r.projectId == projectId,
      ),
    ),
  );

  Future<bool> isExportAvailable(ExportRecord record) async {
    final file = File(record.outputPath);
    return await file.exists() && await file.length() == record.bytes;
  }

  Future<void> deleteExport(String id) => _locked(() async {
    final records = await _history();
    final matches = records.where((r) => r.id == id);
    if (matches.isEmpty) return;
    final record = matches.single;
    final dir = await root;
    _relative('${dir.path}/exports', record.outputPath);
    // Remove the durable entry first. A failed manifest write leaves the
    // existing history/audio intact; a failed unlink remains recoverable.
    final remaining = records.where((r) => r.id != id).toList();
    await _atomicJson(File('${dir.path}/exports.json'), {'schemaVersion': 1,
      'records': remaining.map((r) => {...r.toJson(),
        'outputPath': _relative(dir.path, r.outputPath)}).toList()});
    try {
      final file = File(record.outputPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      await _atomicJson(File('${dir.path}/exports.json'), {'schemaVersion': 1,
        'records': records.map((r) => {...r.toJson(),
          'outputPath': _relative(dir.path, r.outputPath)}).toList()});
      rethrow;
    }
  });
}
