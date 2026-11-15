class PlaybackLease {
  final String ownerId;
  final int generation;
  const PlaybackLease._(this.ownerId, this.generation);
}

/// Generations stop stale async owners from stopping a newer project's audio.
class PlaybackOwnership {
  int _generation = 0;
  PlaybackLease? _lease;
  String? get ownerId => _lease?.ownerId;

  PlaybackLease claim(String ownerId) {
    if (ownerId.isEmpty) throw ArgumentError('Playback owner is required');
    return _lease = PlaybackLease._(ownerId, ++_generation);
  }

  bool owns(PlaybackLease lease) => identical(_lease, lease);
  bool release(PlaybackLease lease) {
    if (!owns(lease)) return false;
    _lease = null;
    return true;
  }

  void clear() {
    _lease = null;
    _generation++;
  }
}
