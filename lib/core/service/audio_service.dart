import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:file_picker/file_picker.dart';
import '../../features/models/audio_project.dart';
import '../../features/models/processing_config.dart';
import 'playback_ownership.dart';

enum AudioPlaybackState { idle, loading, ready, playing, paused, ended, error }

/// Centralized audio service using SoLoud for real-time audio effects.
/// Preserves the existing live gain/EQ controls. Complete project recipes and
/// offline limiting are handled by FFmpeg rather than approximated here.
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  final PlaybackOwnership _ownership = PlaybackOwnership();
  AudioProject? _project;
  AudioPlaybackState _playbackState = AudioPlaybackState.idle;
  String? _lastError;
  bool _disposed = false;
  Future<void>? _initializing;
  Future<void> _operations = Future.value();
  StreamSubscription<StreamSoundEvent>? _sourceEvents;

  AudioPlaybackState get playbackState => _playbackState;
  String? get playbackOwnerId => _ownership.ownerId;
  AudioProject? get audioProject => _project;
  ProcessingConfig? get processingConfig => _project?.config;
  String? get lastError => _lastError;
  bool ownsPlayback(PlaybackLease lease) => _ownership.owns(lease);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final future = _operations.then((_) => action());
    _operations = future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return future;
  }

  Duration get position {
    try {
      return _handle == null ? Duration.zero : _soloud.getPosition(_handle!);
    } catch (_) {
      return Duration.zero;
    }
  }

  Duration get duration {
    try {
      return _source == null ? Duration.zero : _soloud.getLength(_source!);
    } catch (_) {
      return Duration.zero;
    }
  }

  // Playback state
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentFileName;
  String? _currentFilePath;
  double _boostLevel = 1.0; // 1.0 = 100%, 2.0 = 200%
  bool _isBoosted = false;

  // EQ state (10 bands)
  final List<double> _eqBands = List.filled(10, 0.0); // -15 to +15 dB each
  String _activePreset = 'Flat';

  // Filter flags
  bool _bassFilterActive = false;
  bool _limiterActive = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  String? get currentFileName => _currentFileName;
  String? get currentFilePath => _currentFilePath;
  double get boostLevel => _boostLevel;
  bool get isBoosted => _isBoosted;
  List<double> get eqBands => List.unmodifiable(_eqBands);
  String get activePreset => _activePreset;
  SoLoud get soloud => _soloud;
  bool get hasAudioLoaded => _source != null;

  /// Shared conversion used by the live gain control and FFmpeg export.
  /// Percent is an amplitude ratio, not a dB value.
  static double boostPercentToDb(double percent) {
    final ratio = (percent / 100).clamp(0.01, 3.0);
    return 20 * (math.log(ratio) / math.ln10);
  }

  /// Initialize SoLoud engine
  Future<void> initialize() => _initializing ??= _initializeEngine();

  Future<void> _initializeEngine() async {
    if (_disposed) return;
    if (_isInitialized) return;
    try {
      await _soloud.init();
      _isInitialized = true;
      debugPrint('✅ AudioService: SoLoud initialized');
    } catch (e) {
      _lastError = e.toString();
      _playbackState = AudioPlaybackState.error;
      _initializing = null;
      debugPrint('❌ AudioService: Failed to init SoLoud: $e');
    }
  }

  /// Load an audio file
  Future<bool> loadFile(String filePath, String fileName) =>
      _serial(() => _loadFile(filePath, fileName));

  Future<PlaybackLease?> loadProject(
    AudioProject project, {
    required String ownerId,
  }) => _serial(() async {
    if (!await _loadFile(
      project.managedFilePath,
      project.fileName,
      ownerId: ownerId,
    )) {
      return null;
    }
    _project = project;
    _notify();
    return _lease;
  });

  PlaybackLease? _lease;
  bool _neutralPlayback = false;
  double? _savedBass;

  Future<PlaybackLease?> loadStudioFile(
    String path,
    String name,
    String ownerId,
  ) => _serial(() async {
    if (!await _loadFile(path, name, ownerId: ownerId, neutral: true))
      return null;
    // A paused voice permits seeking before the first audible frame.
    _handle = await _soloud.play(_source!, paused: true, volume: 1);
    return _lease;
  });

  bool isPlayingOwned(PlaybackLease lease) {
    if (!_ownership.owns(lease) || _handle == null || !_isInitialized)
      return false;
    return _soloud.getIsValidVoiceHandle(_handle!) &&
        !_soloud.getPause(_handle!);
  }

  bool isCompletedOwned(PlaybackLease lease) =>
      _ownership.owns(lease) && _playbackState == AudioPlaybackState.ended;

  Future<bool> playOwnedUntil(PlaybackLease lease, Duration end) =>
      _serial(() async {
        if (!_ownership.owns(lease) || _disposed) return false;
        await _play();
        if (_handle == null || !_isPlaying) return false;
        final remaining = end - position;
        if (remaining <= Duration.zero) {
          await _pause();
          return false;
        }
        _soloud.schedulePause(_handle!, remaining);
        return true;
      });

  void _restoreLegacyBass() {
    if (_savedBass == null || !_isInitialized) return;
    _soloud.filters.bassBoostFilter.activate();
    _soloud.filters.bassBoostFilter.boost.value = _savedBass!;
    _bassFilterActive = true;
    _savedBass = null;
  }

  Future<bool> _loadFile(
    String filePath,
    String fileName, {
    String ownerId = 'legacy',
    bool neutral = false,
  }) async {
    if (_disposed) return false;
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return false;
    _playbackState = AudioPlaybackState.loading;
    _lastError = null;
    _project = null;
    _notify();

    try {
      // Stop current playback
      await _sourceEvents?.cancel();
      _sourceEvents = null;
      if (_handle != null) {
        await _soloud.stop(_handle!);
        _handle = null;
      }
      if (_source != null) {
        await _soloud.disposeSource(_source!);
        _source = null;
      }

      _currentFilePath = null;
      _currentFileName = null;
      _isPlaying = false;
      _ownership.clear();
      _lease = null;
      if (neutral && _bassFilterActive) {
        _savedBass ??= _soloud.filters.bassBoostFilter.boost.value;
        _soloud.filters.bassBoostFilter.deactivate();
        _bassFilterActive = false;
      } else if (!neutral) {
        _restoreLegacyBass();
      }
      _neutralPlayback = neutral;
      _source = await _soloud.loadFile(
        filePath,
        mode: neutral ? LoadMode.disk : LoadMode.memory,
      );
      _lease = _ownership.claim(ownerId);
      _sourceEvents = _source!.soundEvents.listen((event) {
        if (event.event == SoundEventType.handleIsNoMoreValid &&
            event.handle == _handle) {
          _handle = null;
          _isPlaying = false;
          _playbackState = AudioPlaybackState.ended;
          _notify();
        }
      });
      _currentFilePath = filePath;
      _currentFileName = fileName;
      _isPlaying = false;
      _playbackState = AudioPlaybackState.ready;
      _notify();
      debugPrint('✅ AudioService: Loaded $fileName');
      return true;
    } catch (e) {
      _isPlaying = false;
      _playbackState = AudioPlaybackState.error;
      _lastError = e.toString();
      _notify();
      debugPrint('❌ AudioService: Error loading file: $e');
      return false;
    }
  }

  /// Pick and load an audio file from device
  Future<bool> pickAndLoadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        return await loadFile(file.path!, file.name);
      }
      return false;
    } catch (e) {
      debugPrint('❌ AudioService: Error picking file: $e');
      return false;
    }
  }

  /// Play / Resume
  Future<void> play() => _serial(_play);

  Future<void> _play() async {
    if (_disposed) return;
    if (_source == null) return;

    try {
      if (_handle != null && _soloud.getIsValidVoiceHandle(_handle!)) {
        _soloud.setPause(_handle!, false);
      } else {
        _handle = await _soloud.play(_source!);
      }

      // Apply current boost level
      if (_handle != null) {
        _soloud.setVolume(_handle!, _neutralPlayback ? 1 : _boostLevel);
      }

      _isPlaying = true;
      _playbackState = AudioPlaybackState.playing;
      _notify();
      debugPrint('▶️ AudioService: Playing');
    } catch (e) {
      _lastError = e.toString();
      _playbackState = AudioPlaybackState.error;
      _notify();
      debugPrint('❌ AudioService: Error playing: $e');
    }
  }

  /// Stop playback
  Future<void> stop() => _serial(_stop);

  Future<void> _stop() async {
    if (_handle == null) return;

    try {
      final handle = _handle!;
      _handle = null;
      await _soloud.stop(handle);
      _isPlaying = false;
      _playbackState = AudioPlaybackState.ready;
      _notify();
      debugPrint('⏹️ AudioService: Stopped');
    } catch (e) {
      debugPrint('❌ AudioService: Error stopping: $e');
    }
  }

  /// Toggle pause/resume atomically, including rapid successive taps.
  Future<void> togglePlayback() => _serial(() async {
    if (_isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  });

  Future<void> pause() => _serial(_pause);

  Future<void> _pause() async {
    if (_handle == null || _disposed) return;
    _soloud.setPause(_handle!, true);
    _isPlaying = false;
    _playbackState = AudioPlaybackState.paused;
    _notify();
  }

  Future<void> seek(Duration target) => _serial(() => _seek(target));

  Future<void> _seek(Duration target) async {
    if (_handle == null || _disposed) return;
    final bounded = target < Duration.zero
        ? Duration.zero
        : target > duration
        ? duration
        : target;
    _soloud.seek(_handle!, bounded);
    _notify();
  }

  Future<bool> playOwned(PlaybackLease lease) => _serial(() async {
    if (!_ownership.owns(lease) || _disposed) return false;
    await _play();
    return _isPlaying;
  });

  Future<bool> releasePlayback(PlaybackLease lease) => _serial(() async {
    if (!_ownership.owns(lease)) return false;
    await _disposeAudio();
    return true;
  });

  Future<bool> pauseOwned(PlaybackLease lease) => _serial(() async {
    if (!_ownership.owns(lease) || _disposed || _handle == null) return false;
    await _pause();
    return true;
  });

  Future<bool> seekOwned(PlaybackLease lease, Duration target) => _serial(
    () async {
      if (!_ownership.owns(lease) || _disposed || _handle == null) return false;
      await _seek(target);
      return true;
    },
  );

  /// Apply the existing app-local playback gain.
  /// boostPercent: 0-200 (100 = normal, 200 = 2x)
  Future<void> applyBoost(double boostPercent) async {
    _boostLevel = (boostPercent / 100.0).clamp(0.0, 3.0);
    _isBoosted = boostPercent > 100;

    // Apply to current handle
    if (_handle != null && !_neutralPlayback) {
      _soloud.setVolume(_handle!, _boostLevel);
    }

    // A real output limiter protects live boosted playback. It is not a
    // hearing-safety guarantee; export uses the matching FFmpeg limiter.
    _configureLiveLimiter();
    // Activate bass boost filter for clarity enhancement
    _activateBassBoostFilter();

    _notify();
    debugPrint('🔊 AudioService: Boost applied at ${boostPercent.toInt()}%');
  }

  void _configureLiveLimiter() {
    if (_neutralPlayback || !_isInitialized) return;
    try {
      final limiter = _soloud.filters.limiterFilter;
      if (!_limiterActive) {
        limiter.activate();
        _limiterActive = true;
      }
      limiter.threshold.value = -6;
      limiter.outputCeiling.value = -1;
      limiter.attackTime.value = 1;
      limiter.releaseTime.value = 100;
    } catch (error) {
      debugPrint('Live limiter unavailable: $error');
    }
  }

  /// Apply One-Tap Super Boost (optimized preset)
  Future<void> applySuperBoost() async {
    // Preserve the existing 150% playback preset.
    await applyBoost(150);

    // Apply light EQ curve for clarity and bass enhancement
    _applyBoostEQCurve();

    _isBoosted = true;
    _notify();
    debugPrint('🚀 AudioService: Super Boost activated');
  }

  void _activateBassBoostFilter() {
    if (_neutralPlayback) return;
    try {
      if (!_bassFilterActive) {
        _soloud.filters.bassBoostFilter.activate();
        _bassFilterActive = true;
      }
      // Moderate bass boost for clarity
      _soloud.filters.bassBoostFilter.boost.value = _isBoosted ? 3.0 : 0.0;
    } catch (e) {
      debugPrint('⚠️ AudioService: Bass filter error: $e');
    }
  }

  void _applyBoostEQCurve() {
    try {
      // Apply a light clarity + bass curve:
      // Slight bass lift, flat mids, slight high-end sparkle
      setEQBand(0, 4.0); // 31Hz - sub bass lift
      setEQBand(1, 3.5); // 62Hz - bass lift
      setEQBand(2, 2.0); // 125Hz - low-mid warmth
      setEQBand(3, 0.0); // 250Hz - flat
      setEQBand(4, 0.0); // 500Hz - flat
      setEQBand(5, 1.0); // 1kHz - slight presence
      setEQBand(6, 1.5); // 2kHz - clarity
      setEQBand(7, 2.0); // 4kHz - brightness
      setEQBand(8, 2.5); // 8kHz - air
      setEQBand(9, 1.5); // 16kHz - sparkle
      _activePreset = 'Super Boost';
    } catch (e) {
      debugPrint('⚠️ AudioService: EQ curve error: $e');
    }
  }

  /// Set individual EQ band (0-9), value in dB (-15 to +15)
  void setEQBand(int bandIndex, double value) {
    if (bandIndex < 0 || bandIndex >= 10) return;
    _eqBands[bandIndex] = value.clamp(-15.0, 15.0);

    // SoLoud uses bassBoostFilter for bass and general gain.
    // For a full 10-band EQ, we simulate by adjusting the bass boost
    // filter combined with volume modulation.
    // In production, individual band filters would be chained.
    _updateEQFilters();
    _notify();
  }

  /// Apply a complete EQ preset
  void applyEQPreset(String presetName, List<double> values) {
    if (values.length != 10) return;
    for (int i = 0; i < 10; i++) {
      _eqBands[i] = values[i].clamp(-15.0, 15.0);
    }
    _activePreset = presetName;
    _updateEQFilters();
    _notify();
    debugPrint('🎛️ AudioService: EQ preset "$presetName" applied');
  }

  /// Reset EQ to flat
  void resetEQ() {
    for (int i = 0; i < 10; i++) {
      _eqBands[i] = 0.0;
    }
    _activePreset = 'Flat';
    _updateEQFilters();
    _notify();
  }

  void _updateEQFilters() {
    if (_neutralPlayback) return;
    try {
      // Calculate bass emphasis from low bands
      double bassValue = 0;
      for (int i = 0; i < 3; i++) {
        bassValue += _eqBands[i];
      }
      bassValue = (bassValue / 3.0).clamp(0.0, 10.0);

      if (!_bassFilterActive) {
        _soloud.filters.bassBoostFilter.activate();
        _bassFilterActive = true;
      }
      _soloud.filters.bassBoostFilter.boost.value = bassValue;

      // Overall volume adjustment for mid and high bands
      double overallGain = 0;
      for (int i = 3; i < 10; i++) {
        overallGain += _eqBands[i];
      }
      overallGain = overallGain / 70.0; // Normalize

      // Apply gain to handle
      if (_handle != null) {
        double adjustedVolume = _boostLevel + overallGain;
        adjustedVolume = adjustedVolume.clamp(0.0, 3.0);
        _soloud.setVolume(_handle!, adjustedVolume);
      }
    } catch (e) {
      debugPrint('⚠️ AudioService: EQ filter update error: $e');
    }
  }

  /// Dispose everything
  Future<void> disposeAudio() => _serial(_disposeAudio);

  Future<void> _disposeAudio() async {
    await _sourceEvents?.cancel();
    _sourceEvents = null;
    if (_handle != null) {
      await _soloud.stop(_handle!);
      _handle = null;
    }
    if (_source != null) {
      await _soloud.disposeSource(_source!);
      _source = null;
    }
    _isPlaying = false;
    _isBoosted = false;
    _currentFilePath = null;
    _currentFileName = null;
    _project = null;
    _neutralPlayback = false;
    _restoreLegacyBass();
    _ownership.clear();
    _lease = null;
    _playbackState = AudioPlaybackState.idle;
    _notify();
  }

  /// Full cleanup
  Future<void> shutdown() => _serial(() async {
    await _initializing;
    await _disposeAudio();
    if (_isInitialized) {
      _soloud.deinit();
      _isInitialized = false;
      _initializing = null;
      _bassFilterActive = false;
    }
  });

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      shutdown().catchError((Object error) {
        debugPrint('Audio shutdown failed: $error');
      }),
    );
    super.dispose();
  }
}
