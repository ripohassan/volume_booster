import 'audio_service.dart';
import 'playback_ownership.dart';

abstract interface class StudioPlayer {
  bool get ownsPlayback;
  bool get isPlaying;
  bool get completed;
  Duration get position;
  Future<void> load(String path, String name);
  Future<void> playUntil(Duration fileEnd);
  Future<void> pause();
  Future<void> seek(Duration filePosition);
  Future<void> release();
}

class SoLoudStudioPlayer implements StudioPlayer {
  final AudioService audio;
  final String ownerId;
  PlaybackLease? _lease;
  SoLoudStudioPlayer(this.audio, this.ownerId);
  @override
  bool get ownsPlayback => _lease != null && audio.ownsPlayback(_lease!);
  @override
  bool get isPlaying => ownsPlayback && audio.isPlayingOwned(_lease!);
  @override
  bool get completed => ownsPlayback && audio.isCompletedOwned(_lease!);
  @override
  Duration get position => ownsPlayback ? audio.position : Duration.zero;
  @override
  Future<void> load(String path, String name) async {
    _lease = await audio.loadStudioFile(path, name, ownerId);
    if (_lease == null)
      throw StateError(audio.lastError ?? 'Audio playback is unavailable');
  }

  @override
  Future<void> playUntil(Duration fileEnd) async {
    if (!ownsPlayback || !await audio.playOwnedUntil(_lease!, fileEnd)) {
      throw StateError(audio.lastError ?? 'Select audio to play');
    }
  }

  @override
  Future<void> pause() async {
    if (ownsPlayback) await audio.pauseOwned(_lease!);
  }

  @override
  Future<void> seek(Duration filePosition) async {
    if (!ownsPlayback || !await audio.seekOwned(_lease!, filePosition))
      throw StateError('Playback changed to another tool');
  }

  @override
  Future<void> release() async {
    final lease = _lease;
    _lease = null;
    if (lease != null) await audio.releasePlayback(lease);
  }
}
