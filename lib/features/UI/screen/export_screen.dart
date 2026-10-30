import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/service/ffmpeg_service.dart';
import '../../../core/service/shared_preferance/Shared_Preferences.dart';

class ExportScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;
  const ExportScreen({super.key, required this.isPremiumUser, required this.onShowSubscription});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  SharedPreferencesService? _prefs;

  String? _inputPath;
  String? _inputName;
  String? _outputPath;
  bool _isVideo = false;
  bool _isProcessing = false;
  double _progress = 0.0;
  double _boostGainDb = 6.0;
  ExportFormat _format = ExportFormat.aac;
  ExportQuality _quality = ExportQuality.standard;
  int _dailyExportCount = 0;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferencesService.getInstance();
    _dailyExportCount = await _prefs!.getDailyExportCount();
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'mp4', 'mov'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final ext = file.extension?.toLowerCase() ?? '';
      setState(() {
        _inputPath = file.path;
        _inputName = file.name;
        _isVideo = ext == 'mp4' || ext == 'mov';
        _outputPath = null;
        if (_isVideo) _format = ExportFormat.mp4;
      });
    }
  }

  Future<void> _processAndExport() async {
    if (_inputPath == null) return;

    if (!widget.isPremiumUser) {
      widget.onShowSubscription();
      return;
    }

    setState(() { _isProcessing = true; _progress = 0.0; _outputPath = null; });

    String? output;
    if (_isVideo) {
      output = await _ffmpeg.boostVideoAudio(
        inputPath: _inputPath!,
        gainDb: _boostGainDb,
        quality: _quality,
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
    } else {
      output = await _ffmpeg.boostAudioFile(
        inputPath: _inputPath!,
        gainDb: _boostGainDb,
        format: _format,
        quality: _quality,
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
    }

    if (output != null) {
      await _prefs?.incrementDailyExportCount();
      _dailyExportCount = await _prefs?.getDailyExportCount() ?? 0;
    }

    if (mounted) {
      setState(() { _isProcessing = false; _outputPath = output; _progress = 1.0; });
      if (output != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Export complete!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Export failed'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _shareFile() async {
    if (_outputPath == null) return;
    await Share.shareXFiles([XFile(_outputPath!)], text: 'Boosted with Volume Booster 🔊');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0D0D1A)])),
      child: SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Padding(padding: EdgeInsets.symmetric(horizontal: 20.w), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 16.h),
        _buildHeader(),
        SizedBox(height: 24.h),
        _buildImportSection(),
        SizedBox(height: 20.h),
        if (_inputPath != null) ...[
          _buildBoostControl(),
          SizedBox(height: 20.h),
          _buildFormatSelector(),
          SizedBox(height: 20.h),
          _buildQualitySelector(),
          SizedBox(height: 24.h),
          _buildExportButton(),
          SizedBox(height: 20.h),
        ],
        if (_outputPath != null) _buildShareSection(),
        SizedBox(height: 80.h),
      ])))),
    );
  }

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Export & Share', style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      SizedBox(height: 4.h),
      Text('Process and export boosted audio & video', style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
    ]);
  }

  Widget _buildImportSection() {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickFile,
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: _inputPath != null ? const Color(0xFF00D4FF).withOpacity(0.3) : Colors.white.withOpacity(0.1), width: 1.5),
        ),
        child: _inputPath == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: EdgeInsets.all(16.w), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00D4FF).withOpacity(0.1)),
                  child: Icon(Icons.upload_file_rounded, color: const Color(0xFF00D4FF), size: 36.sp)),
                SizedBox(height: 16.h),
                Text('Import Audio or Video', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 6.h),
                Text('MP3, WAV, M4A, AAC, MP4, MOV', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
              ])
            : Row(children: [
                Container(padding: EdgeInsets.all(12.w), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r), color: _isVideo ? Colors.purple.withOpacity(0.15) : const Color(0xFF00D4FF).withOpacity(0.15)),
                  child: Icon(_isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded, color: _isVideo ? Colors.purple : const Color(0xFF00D4FF), size: 24.sp)),
                SizedBox(width: 14.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_inputName ?? '', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_isVideo ? 'Video file' : 'Audio file', style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                ])),
                Icon(Icons.swap_horiz_rounded, color: Colors.white24, size: 24.sp),
              ]),
      ),
    );
  }

  Widget _buildBoostControl() {
    return Container(padding: EdgeInsets.all(16.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('VOLUME BOOST', style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h), decoration: BoxDecoration(color: const Color(0xFF00D4FF).withOpacity(0.15), borderRadius: BorderRadius.circular(20.r)),
            child: Text('+${_boostGainDb.toStringAsFixed(0)} dB', style: TextStyle(color: const Color(0xFF00D4FF), fontSize: 12.sp, fontWeight: FontWeight.w700))),
        ]),
        SizedBox(height: 12.h),
        SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: const Color(0xFF00D4FF), inactiveTrackColor: Colors.white.withOpacity(0.08), thumbColor: Colors.white, overlayColor: const Color(0xFF00D4FF).withOpacity(0.15), trackHeight: 6.h, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r)),
          child: Slider(value: _boostGainDb, min: 0, max: 20, divisions: 20, onChanged: (v) => setState(() => _boostGainDb = v))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0 dB', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
          Text('Soft', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
          Text('Medium', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
          Text('Loud', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
          Text('20 dB', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
        ]),
      ]));
  }

  Widget _buildFormatSelector() {
    if (_isVideo) return const SizedBox.shrink();
    final formats = [
      {'format': ExportFormat.aac, 'label': 'AAC', 'desc': 'Best compatibility'},
      {'format': ExportFormat.wav, 'label': 'WAV', 'desc': 'Lossless quality'},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('FORMAT', style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      SizedBox(height: 10.h),
      Row(children: formats.map((f) {
        final fmt = f['format'] as ExportFormat;
        final sel = _format == fmt;
        return Expanded(child: GestureDetector(onTap: () => setState(() => _format = fmt),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: EdgeInsets.only(right: 10.w), padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(color: sel ? const Color(0xFF00D4FF).withOpacity(0.12) : Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: sel ? const Color(0xFF00D4FF).withOpacity(0.5) : Colors.white.withOpacity(0.08))),
            child: Column(children: [
              Text(f['label'] as String, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 2.h),
              Text(f['desc'] as String, style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
            ]))));
      }).toList()),
    ]);
  }

  Widget _buildQualitySelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('QUALITY', style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      SizedBox(height: 10.h),
      Row(children: [
        _buildQualityOption(ExportQuality.standard, 'Standard', '192 kbps', false),
        SizedBox(width: 10.w),
        _buildQualityOption(ExportQuality.high, 'HD', '320 kbps', !widget.isPremiumUser),
      ]),
    ]);
  }

  Widget _buildQualityOption(ExportQuality q, String label, String desc, bool locked) {
    final sel = _quality == q;
    return Expanded(child: GestureDetector(
      onTap: () { if (locked) { widget.onShowSubscription(); } else { setState(() => _quality = q); } },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(color: sel ? const Color(0xFF00D4FF).withOpacity(0.12) : Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: sel ? const Color(0xFF00D4FF).withOpacity(0.5) : locked ? Colors.orange.withOpacity(0.2) : Colors.white.withOpacity(0.08))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (locked) ...[Icon(Icons.lock_rounded, color: Colors.orange, size: 14.sp), SizedBox(width: 4.w)],
            Text(label, style: TextStyle(color: locked ? Colors.orange : sel ? Colors.white : Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 2.h),
          Text(desc, style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
        ]))));
  }

  Widget _buildExportButton() {
    return Column(children: [
      if (_isProcessing) ...[
        Container(padding: EdgeInsets.all(20.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16.r)),
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 80.w, height: 80.w, child: CircularProgressIndicator(value: _progress, color: const Color(0xFF00D4FF), backgroundColor: Colors.white.withOpacity(0.08), strokeWidth: 6)),
              Text('${(_progress * 100).toInt()}%', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w800)),
            ]),
            SizedBox(height: 16.h),
            Text('Processing...', style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
            SizedBox(height: 12.h),
            GestureDetector(onTap: () async { await _ffmpeg.cancel(); setState(() => _isProcessing = false); },
              child: Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 13.sp, fontWeight: FontWeight.w600))),
          ])),
      ] else
        SizedBox(width: double.infinity, height: 56.h, child: ElevatedButton(
          onPressed: _processAndExport,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.white, elevation: 8, shadowColor: const Color(0xFF00D4FF).withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bolt_rounded, size: 22.sp),
            SizedBox(width: 8.w),
            Text('Export Boosted File', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800)),
          ]))),
    ]);
  }

  Widget _buildShareSection() {
    return Container(padding: EdgeInsets.all(16.w), decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.green.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Export Complete!', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
            Text('Saved to app documents', style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
          ])),
        ]),
        SizedBox(height: 16.h),
        SizedBox(width: double.infinity, height: 48.h, child: ElevatedButton.icon(
          onPressed: _shareFile,
          icon: Icon(Icons.share_rounded, size: 20.sp),
          label: Text('Share to Apps', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))))),
      ]));
  }

}
