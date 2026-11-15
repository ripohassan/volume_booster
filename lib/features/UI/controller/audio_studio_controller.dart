import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/service/audio_waveform_service.dart';
import '../../../core/service/processing_job.dart';
import '../../../core/service/studio_player.dart';
import '../../models/audio_project.dart';
import 'audio_project_controller.dart';

enum StudioSource { original, enhanced }

/// Coordinates the Studio's one playback voice. Keeping a single voice avoids
/// an original/enhanced overlap and makes A/B position mapping deterministic.
class AudioStudioController extends ChangeNotifier {
  final AudioProjectController projects;
  final AudioWaveformService waveforms;
  final StudioPlayer player;
  WaveformEnvelope? _waveform;
  String? _previewPath;
  int? _previewRevision;
  StudioSource _source = StudioSource.original;
  Duration _position = Duration.zero;
  bool _loadingWaveform = false;
  Object? _error;
  Timer? _ticker;
  bool _disposed = false;

  AudioStudioController({
    required this.projects,
    required this.waveforms,
    required this.player,
  });
  WaveformEnvelope? get waveform => _waveform;
  bool get loadingWaveform => _loadingWaveform;
  Object? get error => _error;
  StudioSource get source => _source;
  Duration get position => _position;
  bool get isPlaying => player.isPlaying;
  bool get hasPreview =>
      _previewPath != null && _previewRevision == projects.project?.revision;
  AudioProject? get project => projects.project;

  Future<void> prepare() async {
    final project = projects.project;
    if (project == null || _loadingWaveform) return;
    _loadingWaveform = true;
    _error = null;
    _notify();
    try {
      final envelope = await waveforms.loadProject(
        project,
        ProcessingCancellation(),
        (_) {},
      );
      if (_disposed || projects.project?.id != project.id) return;
      _waveform = envelope;
      await _loadOriginal(position: project.trimStart);
    } catch (error) {
      _error = error;
    } finally {
      _loadingWaveform = false;
      _notify();
    }
  }

  Future<void> importFile(String path, {String? name}) async {
    await player.release();
    _waveform = null;
    await _discardPreview();
    _position = Duration.zero;
    final ok = await projects.importFile(path, fileName: name);
    if (ok)
      await prepare();
    else {
      _error = projects.error;
      _notify();
    }
  }

  Future<void> setTrim(Duration start, Duration end) async {
    final item = project;
    if (item == null || start >= end) return;
    start = start < Duration.zero ? Duration.zero : start;
    end = end > item.duration ? item.duration : end;
    if (!await projects.updateConfiguration(
      item.config,
      trimStart: start,
      trimEnd: end,
    ))
      return;
    await _discardPreview();
    _position = start;
    await _loadOriginal(position: start);
    _notify();
  }

  Future<void> updateConfig(AudioProject next) async {
    if (!await projects.updateConfiguration(
      next.config,
      trimStart: next.trimStart,
      trimEnd: next.trimEnd,
    ))
      return;
    await _discardPreview();
    _notify();
  }

  Future<void> renderPreview() async {
    final item = project;
    if (item == null) return;
    _error = null;
    _notify();
    final rendered = await projects.preview();
    if (rendered == null) {
      _error = projects.error;
      _notify();
      return;
    }
    await _discardPreview();
    _previewPath = rendered.outputPath;
    _previewRevision = item.revision;
    await select(StudioSource.enhanced, at: _position);
    _notify();
  }

  Future<void> select(StudioSource requested, {Duration? at}) async {
    final item = project;
    if (item == null) return;
    if (requested == StudioSource.enhanced && !hasPreview) return;
    final wasPlaying = isPlaying;
    final logical = at ?? _logicalPosition(item);
    await player.pause();
    _source = requested;
    if (requested == StudioSource.original) {
      await _loadOriginal(position: logical);
    } else {
      final relative = _clamp(
        logical - item.trimStart,
        Duration.zero,
        item.trimmedDuration,
      );
      await player.load(_previewPath!, 'Enhanced preview');
      await player.seek(relative);
    }
    _position = _clamp(logical, item.trimStart, item.trimEnd);
    if (wasPlaying) await playPause();
    _notify();
  }

  Future<void> playPause() async {
    final item = project;
    if (item == null) return;
    try {
      if (isPlaying) {
        await player.pause();
      } else {
        final end = _source == StudioSource.original
            ? item.trimEnd
            : item.trimmedDuration;
        await player.playUntil(end);
        _startTicker();
      }
    } catch (error) {
      _error = error;
    }
    _notify();
  }

  Future<void> stop() async {
    final item = project;
    if (item == null) return;
    await player.pause();
    await seek(item.trimStart);
    _notify();
  }

  Future<void> seek(Duration logical) async {
    final item = project;
    if (item == null) return;
    _position = _clamp(logical, item.trimStart, item.trimEnd);
    final filePosition = _source == StudioSource.original
        ? _position
        : _position - item.trimStart;
    await player.seek(filePosition);
    _notify();
  }

  Duration _logicalPosition(AudioProject item) =>
      _source == StudioSource.original
      ? player.position
      : item.trimStart + player.position;
  Duration _clamp(Duration value, Duration low, Duration high) => value < low
      ? low
      : value > high
      ? high
      : value;
  Future<void> _loadOriginal({required Duration position}) async {
    final envelope = _waveform;
    final item = project;
    if (envelope == null || item == null) return;
    _source = StudioSource.original;
    await player.load(envelope.referencePath, item.fileName);
    await player.seek(_clamp(position, item.trimStart, item.trimEnd));
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 150), (_) async {
      final item = project;
      if (item == null || !player.ownsPlayback) return;
      final next = _logicalPosition(item);
      if (next >= item.trimEnd || !player.isPlaying) {
        _position = _clamp(next, item.trimStart, item.trimEnd);
        await player.pause();
        _ticker?.cancel();
        _ticker = null;
      } else {
        _position = next;
      }
      _notify();
    });
  }

  Future<void> _discardPreview() async {
    final old = _previewPath;
    _previewPath = null;
    _previewRevision = null;
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(player.release());
    unawaited(_discardPreview());
    super.dispose();
  }
}
