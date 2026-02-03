import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BassBoosterScreen extends StatefulWidget {
  const BassBoosterScreen({super.key});

  @override
  State<BassBoosterScreen> createState() => _BassBoosterScreenState();
}

class _BassBoosterScreenState extends State<BassBoosterScreen> with TickerProviderStateMixin {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  double _bassBoost = 0.0;
  bool _isPlaying = false;
  String? _currentAudioName;
  String? _currentFilePath; // Added to track the actual path
  bool _filterAdded = false;
  bool _isSaving = false; // To show loading state during save

  late AnimationController _visualizerController;

  @override
  void initState() {
    super.initState();
    initAudio();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  Future<void> initAudio() async {
    await _soloud.init();
    try {
      _soloud.filters.bassBoostFilter.activate();
      _filterAdded = true;
      _soloud.filters.bassBoostFilter.boost.value = _bassBoost;
    } catch (e) {
      debugPrint("Failed to add bassboost filter: $e");
    }
  }

  // ------------------------------------------------------------------------
  //  THE REQUESTED SAVE METHOD
  // ------------------------------------------------------------------------


  Future<void> _saveToStorage(String title, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString('stored_songs') ?? '[]';
      final List<dynamic> songs = json.decode(songsJson);

      bool alreadyExists = songs.any((song) => song['path'] == path);
      if (!alreadyExists) {
        songs.add({
          'title': title,
          'path': path,
        });

        final updatedJson = json.encode(songs);
        await prefs.setString('stored_songs', updatedJson);
        print('💾 Song saved: $title (${songs.length} total songs)');
      } else {
        print('ℹ️ Song already exists in storage: $title');
      }
    } catch (e) {
      print('❌ Error saving song: $e');
    }
  }


  Future<void> _saveSongToStorage(String songTitle, String filePath) async {
    setState(() => _isSaving = true);

    // Simulate a delay or processing time
    await Future.delayed(const Duration(seconds: 1));

    // TODO: Add your actual saving/processing logic here.
    // Note: SoLoud applies effects in real-time. If you want to save the
    // MODIFIED audio (with bass), you typically need to re-encode the file
    // using a tool like FFmpeg, passing the EQ settings.

    debugPrint("Saving $songTitle from $filePath");

    if (mounted) {
      setState(() => _isSaving = false);
      await _saveToStorage(songTitle, filePath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved '$songTitle' to storage!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }



  Future<void> pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path == null) return;

      if (_handle != null) {
        await _soloud.stop(_handle!);
      }

      try {
        if (_source != null) {
          await _soloud.disposeSource(_source!);
        }
        _source = await _soloud.loadFile(file.path!);
        if (mounted) {
          setState(() {
            _currentAudioName = file.name;
            _currentFilePath = file.path; // Store path for saving
            _isPlaying = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading: $e");
      }
    }
  }

  void setBass(double value) {
    setState(() => _bassBoost = value.clamp(0.0, 10.0));
    if (_filterAdded) {
      _soloud.filters.bassBoostFilter.boost.value = _bassBoost;
    }
  }

  Future<void> togglePlay() async {
    if (_source == null) return;

    if (_isPlaying && _handle != null) {
      await _soloud.stop(_handle!);
      if (mounted) setState(() => _isPlaying = false);
    } else {
      _handle = await _soloud.play(_source!);
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _visualizerController.dispose();
    if (_handle != null) _soloud.stop(_handle!);
    if (_source != null) _soloud.disposeSource(_source!);
    _soloud.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgStart = Color(0xFF0F0C29);
    const Color bgEnd = Color(0xFF302B63);
    const Color accentColor = Color(0xFF00D4FF);
    const Color accentSecondary = Color(0xFF9D50BB);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgStart, bgEnd, Colors.black],
              ),
            ),
          ),

          // 2. Ambient Blobs
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.2),
                boxShadow: [BoxShadow(color: accentColor, blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),

          // 3. Main UI
          SafeArea(
            child: Column(
              children: [
                // --- TOP NAVIGATION BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      _buildGlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),

                      // Save Button (Only active if file loaded)
                      _isSaving
                          ? const SizedBox(
                          width: 50, height: 50,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(color: accentColor),
                          )
                      )
                          : _buildGlassIconButton(
                        icon: Icons.save_alt_rounded,
                        color: _currentFilePath != null ? accentColor : Colors.grey,
                        onTap: () {
                          if (_currentFilePath != null && _currentAudioName != null) {
                            _saveSongToStorage(_currentAudioName!, _currentFilePath!);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header
                            Text(
                              "Bass Booster",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(color: accentColor.withOpacity(0.8), blurRadius: 20),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Glass Card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Column(
                                    children: [
                                      // Visualizer
                                      SizedBox(
                                        height: 60,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: List.generate(10, (index) {
                                            return AnimatedVisualizerBar(
                                              isPlaying: _isPlaying,
                                              animation: _visualizerController,
                                              index: index,
                                              color: index % 2 == 0 ? accentColor : accentSecondary,
                                            );
                                          }),
                                        ),
                                      ),
                                      const SizedBox(height: 30),

                                      // Song Title
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _currentAudioName ?? "No Audio Selected",
                                          style: TextStyle(
                                            color: _currentAudioName != null ? Colors.white : Colors.white38,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 40),

                                      // Slider
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text("INTENSITY", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                                              Text("${(_bassBoost * 10).toInt()}%", style: const TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: accentColor,
                                              inactiveTrackColor: Colors.white10,
                                              thumbColor: Colors.white,
                                              overlayColor: accentColor.withOpacity(0.2),
                                            ),
                                            child: Slider(
                                              value: _bassBoost,
                                              min: 0, max: 10,
                                              onChanged: setBass,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 30),

                                      // Presets
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildPresetBtn("SOFT", 2.0, accentColor),
                                          _buildPresetBtn("DEEP", 5.0, accentSecondary),
                                          _buildPresetBtn("EXTREME", 9.0, Colors.redAccent),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Controls Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCircleBtn(Icons.library_music_rounded, pickAudio),
                                const SizedBox(width: 30),
                                GestureDetector(
                                  onTap: _source == null ? null : togglePlay,
                                  child: Container(
                                    height: 80, width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _source == null
                                            ? [Colors.grey, Colors.grey.shade800]
                                            : [accentColor, Colors.blue.shade800],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                            color: (_source == null ? Colors.grey : accentColor).withOpacity(0.4),
                                            blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white, size: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 30),
                                _buildCircleBtn(Icons.stop_rounded, () async {
                                  if(_handle != null) {
                                    await _soloud.stop(_handle!);
                                    setState(() => _isPlaying = false);
                                  }
                                }),
                              ],
                            ),
                            const SizedBox(height: 40), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 50, width: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50, width: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildPresetBtn(String label, double value, Color activeColor) {
    bool isSelected = (_bassBoost - value).abs() < 0.5;
    return GestureDetector(
      onTap: () => setBass(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? activeColor : Colors.white24, width: 1.5),
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class AnimatedVisualizerBar extends StatelessWidget {
  final bool isPlaying;
  final AnimationController animation;
  final int index;
  final Color color;

  const AnimatedVisualizerBar({
    super.key, required this.isPlaying, required this.animation, required this.index, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        double height = 4.0;
        if (isPlaying) {
          final t = animation.value * 2 * pi;
          final wave = sin(t + index) + sin(t * 2 + index * 1.5) + 2.5;
          height = 10.0 + (wave * 8.0);
        }
        return Container(
          width: 6, height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isPlaying ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)] : [],
          ),
        );
      },
    );
  }
}