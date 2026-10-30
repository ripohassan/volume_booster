import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/service/audio_service.dart';
import '../../../core/service/ffmpeg_service.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

class VoiceBoosterScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;

  const VoiceBoosterScreen({
    super.key,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });

  @override
  State<VoiceBoosterScreen> createState() => _VoiceBoosterScreenState();
}

class _VoiceBoosterScreenState extends State<VoiceBoosterScreen> {
  final AudioService _audioService = AudioService();
  final FFmpegService _ffmpegService = FFmpegService();

  String? _originalFilePath;
  String? _originalFileName;
  String? _enhancedFilePath;
  
  bool _isPlaying = false;
  bool _isPreviewingEnhanced = false;
  bool _isProcessing = false;
  double _processProgress = 0.0;

  // Enhancement parameters
  double _speechClarity = 0.5;
  double _noiseReduction = 0.5;
  double _vocalBoost = 0.5;
  bool _volumeNorm = true;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _audioService.addListener(_onAudioStateChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = _audioService.isPlaying;
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      setState(() {
        _originalFilePath = file.path;
        _originalFileName = file.name;
        _enhancedFilePath = null;
        _isPreviewingEnhanced = false;
      });
      await _audioService.loadFile(_originalFilePath!, _originalFileName!);
    }
  }

  Future<void> _togglePlayback() async {
    if (_audioService.hasAudioLoaded) {
      await _audioService.togglePlayback();
    }
  }

  Future<void> _togglePreviewMode(bool showEnhanced) async {
    if (showEnhanced && _enhancedFilePath == null) return;
    
    setState(() {
      _isPreviewingEnhanced = showEnhanced;
    });

    final wasPlaying = _audioService.isPlaying;
    
    if (showEnhanced) {
      await _audioService.loadFile(_enhancedFilePath!, "Enhanced_$_originalFileName");
    } else {
      await _audioService.loadFile(_originalFilePath!, _originalFileName ?? "Original");
    }
    
    if (wasPlaying) {
      await _audioService.play();
    }
  }

  Future<void> _enhanceVoice() async {
    if (_originalFilePath == null) return;
    
    // Stop playback before processing
    if (_audioService.isPlaying) {
      await _audioService.stop();
    }

    setState(() {
      _isProcessing = true;
      _processProgress = 0.0;
    });

    final outputPath = await _ffmpegService.enhanceVoiceFile(
      inputPath: _originalFilePath!,
      speechClarity: _speechClarity,
      noiseReduction: _noiseReduction,
      vocalBoost: _vocalBoost,
      volumeNorm: _volumeNorm,
      format: ExportFormat.aac,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _processProgress = progress;
          });
        }
      }
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (outputPath != null) {
          _enhancedFilePath = outputPath;
          _isPreviewingEnhanced = true;
        }
      });

      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Voice enhanced successfully!'), backgroundColor: Colors.green),
        );
        // Load the enhanced file
        await _audioService.loadFile(_enhancedFilePath!, "Enhanced_$_originalFileName");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Enhancement failed.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveExport() async {
    if (_enhancedFilePath == null) return;
    
    if (!widget.isPremiumUser) {
      widget.onShowSubscription();
      return;
    }
    
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.incrementDailyExportCount();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Saving file...'), backgroundColor: Colors.green)
      );
    }
    
    await Share.shareXFiles([XFile(_enhancedFilePath!)], text: 'Voice Enhanced with Volume Booster 🔊');
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                Text('Voice Booster', style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 4.h),
                Text('Enhance clarity and remove noise', style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
                SizedBox(height: 30.h),

                _buildFileCard(),
                SizedBox(height: 24.h),

                if (_originalFilePath != null) ...[
                  _buildControlsSection(),
                  SizedBox(height: 24.h),
                  
                  if (_isProcessing)
                    _buildProcessingIndicator()
                  else
                    _buildActionButtons(),
                  
                  SizedBox(height: 80.h),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard() {
    final hasFile = _originalFilePath != null;
    return GestureDetector(
      onTap: _isProcessing ? null : _pickFile,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasFile ? const Color(0xFF00D4FF).withOpacity(0.3) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: hasFile ? const Color(0xFF00D4FF).withOpacity(0.15) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.mic_rounded, color: hasFile ? const Color(0xFF00D4FF) : Colors.white38, size: 28.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? (_originalFileName ?? 'Audio File') : 'Import Audio',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    hasFile ? 'Tap to change file' : 'Select a recording to enhance',
                    style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: const Color(0xFF00D4FF), size: 20.sp),
              SizedBox(width: 8.w),
              Text('ENHANCEMENTS', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            ],
          ),
          SizedBox(height: 20.h),
          
          _buildSlider('Speech Clarity', _speechClarity, (v) => setState(() => _speechClarity = v)),
          SizedBox(height: 16.h),
          _buildSlider('Noise Reduction', _noiseReduction, (v) => setState(() => _noiseReduction = v)),
          SizedBox(height: 16.h),
          _buildSlider('Vocal Boost', _vocalBoost, (v) => setState(() => _vocalBoost = v)),
          
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Volume Normalization', style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w500)),
              Switch(
                value: _volumeNorm,
                onChanged: (v) => setState(() => _volumeNorm = v),
                activeColor: const Color(0xFF00D4FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%', style: TextStyle(color: const Color(0xFF00D4FF), fontSize: 12.sp, fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 8.h),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF00D4FF),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF00D4FF).withOpacity(0.15),
            trackHeight: 4.h,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_enhancedFilePath != null) ...[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPreviewTab(false, 'Original'),
                _buildPreviewTab(true, 'Enhanced'),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        Row(
          children: [
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
                ),
                child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF00D4FF), size: 32.sp),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: GestureDetector(
                onTap: _enhancedFilePath != null && _isPreviewingEnhanced ? _saveExport : _enhanceVoice,
                child: Container(
                  height: 60.w,
                  decoration: BoxDecoration(
                    color: _enhancedFilePath != null && _isPreviewingEnhanced ? Colors.green : const Color(0xFF00D4FF),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Text(
                      _enhancedFilePath != null && _isPreviewingEnhanced ? 'SAVE / EXPORT' : 'ENHANCE VOICE',
                      style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewTab(bool isEnhanced, String label) {
    final isSelected = _isPreviewingEnhanced == isEnhanced;
    return GestureDetector(
      onTap: () => _togglePreviewMode(isEnhanced),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D4FF).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00D4FF) : Colors.white54,
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: const Color(0xFF00D4FF), value: _processProgress > 0 ? _processProgress : null),
          SizedBox(height: 16.h),
          Text('Enhancing Voice...', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Text('${(_processProgress * 100).toInt()}%', style: TextStyle(color: const Color(0xFF00D4FF), fontSize: 14.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
