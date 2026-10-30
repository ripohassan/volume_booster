import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/service/audio_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/service/ffmpeg_service.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

class BoostScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;

  const BoostScreen({
    super.key,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();

  double _boostPercent = 100;
  bool _isBoosting = false;
  bool _showBoostEffect = false;
  bool _isSaving = false;
  double _saveProgress = 0.0;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _boostFlashController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _boostFlashAnimation;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _boostFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _boostFlashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _boostFlashController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _boostFlashController.dispose();
    super.dispose();
  }

  Future<void> _onBoostTapped() async {
    // If no audio loaded, pick one first
    if (!_audioService.hasAudioLoaded) {
      final loaded = await _audioService.pickAndLoadFile();
      if (!loaded) return;
    }

    setState(() {
      _isBoosting = true;
      _showBoostEffect = true;
    });

    // Play the boost flash animation
    _boostFlashController.forward(from: 0.0);

    // Apply the super boost
    await _audioService.applySuperBoost();

    // Start playback if not playing
    if (!_audioService.isPlaying) {
      await _audioService.play();
    }

    // Short delay for visual effect
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isBoosting = false;
        _boostPercent = 150;
      });
    }
  }

  void _onBoostLevelChanged(double value) {
    setState(() {
      _boostPercent = value;
    });
    _audioService.applyBoost(value);
  }

  void _onPresetTapped(String label, double percent) {
    setState(() {
      _boostPercent = percent;
    });
    _audioService.applyBoost(percent);
  }

  Future<void> _onSaveTapped() async {
    if (!_audioService.hasAudioLoaded || _audioService.currentFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please load an audio file first.')));
      return;
    }
    
    if (!widget.isPremiumUser) {
        widget.onShowSubscription();
        return;
    }
    
    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
    });
    
    final gainDb = (_boostPercent - 100) / 10.0;
    final ffmpeg = FFmpegService();
    
    final outputPath = await ffmpeg.boostAudioFile(
      inputPath: _audioService.currentFilePath!,
      gainDb: gainDb > 0 ? gainDb : 0.0,
      format: ExportFormat.aac,
      quality: ExportQuality.standard,
      onProgress: (p) {
        if (mounted) setState(() => _saveProgress = p);
      }
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (outputPath != null) {
        final prefs = await SharedPreferencesService.getInstance();
        await prefs.incrementDailyExportCount();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Saved successfully! Sharing file...'), backgroundColor: Colors.green));
        await Share.shareXFiles([XFile(outputPath)], text: 'Boosted with Volume Booster 🔊');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Failed to save file'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),

                // Current file display
                _buildCurrentFileCard(),

                SizedBox(height: 30.h),

                // Main BOOST button
                _buildBoostButton(),

                SizedBox(height: 30.h),

                // Visualizer bars
                if (_showBoostEffect || _audioService.isPlaying)
                  _buildVisualizerBars(),

                SizedBox(height: 24.h),

                // Boost level slider
                _buildBoostSlider(),

                SizedBox(height: 24.h),

                // Quick preset buttons
                _buildPresetButtons(),

                SizedBox(height: 20.h),

                // Mini playback controls
                _buildPlaybackControls(),

                SizedBox(height: 80.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentFileCard() {
    final fileName = _audioService.currentFileName ?? 'No Audio Selected';
    final hasFile = _audioService.hasAudioLoaded;

    return GestureDetector(
      onTap: () async {
        await _audioService.pickAndLoadFile();
        if (mounted) setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF00D4FF).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: hasFile
                    ? const Color(0xFF00D4FF).withOpacity(0.15)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                hasFile ? Icons.music_note_rounded : Icons.folder_open_rounded,
                color: hasFile ? const Color(0xFF00D4FF) : Colors.white38,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? fileName : 'Tap to select audio file',
                    style: TextStyle(
                      color: hasFile ? Colors.white : Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasFile)
                    Text(
                      'Ready to boost',
                      style: TextStyle(
                        color: const Color(0xFF00D4FF).withOpacity(0.7),
                        fontSize: 11.sp,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoostButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _audioService.isPlaying ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow rings
          if (_showBoostEffect) ...[
            AnimatedBuilder(
              animation: _boostFlashAnimation,
              builder: (context, _) {
                return Container(
                  width: (220 + _boostFlashAnimation.value * 40).w,
                  height: (220 + _boostFlashAnimation.value * 40).w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00D4FF)
                          .withOpacity(0.3 * (1 - _boostFlashAnimation.value)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          ],

          // Glow background
          Container(
            width: 200.w,
            height: 200.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isBoosting || _audioService.isBoosted)
                      ? const Color(0xFF00D4FF).withOpacity(0.4)
                      : const Color(0xFF6C63FF).withOpacity(0.2),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // Main button
          GestureDetector(
            onTap: _isBoosting ? null : _onBoostTapped,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 180.w,
              height: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isBoosting
                      ? [const Color(0xFF00D4FF), const Color(0xFF0066FF)]
                      : _audioService.isBoosted
                          ? [const Color(0xFF00D4FF), const Color(0xFF6C63FF)]
                          : [const Color(0xFF2D2D5F), const Color(0xFF1A1A3E)],
                ),
                border: Border.all(
                  color: _isBoosting
                      ? const Color(0xFF00D4FF)
                      : Colors.white.withOpacity(0.15),
                  width: 2,
                ),
                boxShadow: [
                  if (_isBoosting || _audioService.isBoosted)
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isBoosting)
                    SizedBox(
                      width: 40.w,
                      height: 40.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  else ...[
                    Text(
                      'BOOST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'NOW 🔊',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${_boostPercent.toInt()}%',
                      style: TextStyle(
                        color: const Color(0xFF00D4FF),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerBars() {
    return SizedBox(
      height: 50.h,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(20, (index) {
              double height;
              if (_audioService.isPlaying) {
                final t = _waveController.value * 2 * pi;
                final wave =
                    sin(t + index * 0.5) + sin(t * 1.5 + index) + 2;
                height = 8 + (wave * 8.0);
              } else {
                height = 4.0;
              }

              final gradient = index / 20.0;
              final color = Color.lerp(
                const Color(0xFF00D4FF),
                const Color(0xFF6C63FF),
                gradient,
              )!;

              return Container(
                width: 4.w,
                height: height.h,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.r),
                  boxShadow: _audioService.isPlaying
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildBoostSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BOOST INTENSITY',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '${_boostPercent.toInt()}%',
                style: TextStyle(
                  color: const Color(0xFF00D4FF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF00D4FF),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF00D4FF).withOpacity(0.15),
            trackHeight: 6.h,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
          ),
          child: Slider(
            value: _boostPercent,
            min: 0,
            max: 200,
            onChanged: _onBoostLevelChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%',
                style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
            Text('100%',
                style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
            Text('200%',
                style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetButtons() {
    final presets = [
      {'label': 'Light', 'value': 125.0, 'icon': Icons.wb_sunny_outlined},
      {'label': 'Medium', 'value': 150.0, 'icon': Icons.equalizer_rounded},
      {'label': 'Max Safe', 'value': 180.0, 'icon': Icons.flash_on_rounded},
      {'label': 'Ultra', 'value': 200.0, 'icon': Icons.bolt_rounded},
    ];

    return Row(
      children: presets.map((preset) {
        final label = preset['label'] as String;
        final value = preset['value'] as double;
        final icon = preset['icon'] as IconData;
        final isSelected = (_boostPercent - value).abs() < 10;
        final isLocked = value > 150 && !widget.isPremiumUser;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isLocked) {
                widget.onShowSubscription();
              } else {
                _onPresetTapped(label, value);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00D4FF).withOpacity(0.15)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00D4FF).withOpacity(0.5)
                      : isLocked
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isLocked ? Icons.lock_rounded : icon,
                    color: isLocked
                        ? Colors.orange
                        : isSelected
                            ? const Color(0xFF00D4FF)
                            : Colors.white38,
                    size: 18.sp,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    label,
                    style: TextStyle(
                      color: isLocked
                          ? Colors.orange
                          : isSelected
                              ? Colors.white
                              : Colors.white54,
                      fontSize: 10.sp,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pick file
          _buildControlButton(
            icon: Icons.folder_open_rounded,
            onTap: () async {
              await _audioService.pickAndLoadFile();
              if (mounted) setState(() {});
            },
          ),
          SizedBox(width: 24.w),
          // Play/Stop
          GestureDetector(
            onTap: () async {
              if (!_audioService.hasAudioLoaded) {
                final loaded = await _audioService.pickAndLoadFile();
                if (!loaded) return;
              }
              await _audioService.togglePlayback();
              if (mounted) setState(() {});
            },
            child: Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _audioService.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30.sp,
              ),
            ),
          ),
          SizedBox(width: 24.w),
          // Stop
          _buildControlButton(
            icon: Icons.stop_rounded,
            onTap: () async {
              await _audioService.stop();
              if (mounted) setState(() {});
            },
          ),
          SizedBox(width: 24.w),
          // Save
          _isSaving ? SizedBox(
              width: 44.w, height: 44.w, 
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: _saveProgress, color: const Color(0xFF00D4FF)),
                  Text('${(_saveProgress*100).toInt()}%', style: TextStyle(color: Colors.white, fontSize: 10.sp))
                ],
              )
          ) : _buildControlButton(
            icon: Icons.save_alt_rounded,
            onTap: _onSaveTapped,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white60, size: 22.sp),
      ),
    );
  }
}
