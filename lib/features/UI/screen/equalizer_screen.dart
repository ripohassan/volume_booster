import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/service/audio_service.dart';
import '../../models/eq_presets.dart';

class EqualizerScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;
  const EqualizerScreen({super.key, required this.isPremiumUser, required this.onShowSubscription});
  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  late List<double> _bands;
  String _activePreset = 'Flat';
  late AnimationController _vizController;

  @override
  void initState() {
    super.initState();
    _bands = List.from(_audioService.eqBands);
    _activePreset = _audioService.activePreset;
    _vizController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() { _vizController.dispose(); super.dispose(); }

  void _onBandChanged(int i, double v) {
    if (!widget.isPremiumUser) { widget.onShowSubscription(); return; }
    setState(() { _bands[i] = v; _activePreset = 'Custom'; });
    _audioService.setEQBand(i, v);
  }

  void _onPresetSelected(EQPreset preset) {
    if (!widget.isPremiumUser && preset.name != 'Flat') { widget.onShowSubscription(); return; }
    setState(() { _bands = List.from(preset.bands.map((v) => v.toDouble())); _activePreset = preset.name; });
    _audioService.applyEQPreset(preset.name, preset.bands.map((v) => v.toDouble()).toList());
  }

  void _resetEQ() {
    setState(() { _bands = List.filled(10, 0.0); _activePreset = 'Flat'; });
    _audioService.resetEQ();
  }

  Color _presetColor() {
    final p = EQPreset.presets.where((p) => p.name == _activePreset);
    return p.isNotEmpty ? p.first.color : const Color(0xFF00D4FF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0D0D1A)])),
      child: SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Padding(padding: EdgeInsets.symmetric(horizontal: 20.w), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 16.h),
        _buildHeader(),
        SizedBox(height: 20.h),
        _buildVisualizer(),
        SizedBox(height: 24.h),
        _buildSliders(),
        SizedBox(height: 24.h),
        _buildPresets(),
        SizedBox(height: 16.h),
        _buildFileInfo(),
        SizedBox(height: 80.h),
      ])))),
    );
  }

  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        SizedBox(height: 4.h),
        Row(children: [
          Container(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h), decoration: BoxDecoration(color: _presetColor().withOpacity(0.15), borderRadius: BorderRadius.circular(8.r)),
            child: Text(_activePreset, style: TextStyle(color: _presetColor(), fontSize: 11.sp, fontWeight: FontWeight.w700))),
          if (!widget.isPremiumUser) ...[SizedBox(width: 8.w), Icon(Icons.lock_rounded, color: Colors.orange, size: 14.sp), SizedBox(width: 4.w), Text('Premium', style: TextStyle(color: Colors.orange, fontSize: 11.sp, fontWeight: FontWeight.w600))],
        ]),
      ]),
      GestureDetector(onTap: _resetEQ, child: Container(padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w600)))),
    ]);
  }

  Widget _buildVisualizer() {
    return AnimatedBuilder(animation: _vizController, builder: (context, _) {
      return Container(height: 80.h, padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(10, (i) {
          final eq = (_bands[i] + 15) / 30;
          double h = _audioService.isPlaying ? (eq * (sin(_vizController.value * 2 * pi + i * 0.8) * 0.3 + 0.7) * 60).clamp(4.0, 60.0) : (eq * 50).clamp(4.0, 60.0);
          final c = Color.lerp(const Color(0xFF00D4FF), const Color(0xFF9D50BB), i / 10.0)!;
          return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            AnimatedContainer(duration: const Duration(milliseconds: 150), width: 16.w, height: h.h, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.withOpacity(0.3), c]), borderRadius: BorderRadius.circular(4.r), boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)])),
            SizedBox(height: 4.h),
            Text(EQPreset.bandLabels[i], style: TextStyle(color: Colors.white30, fontSize: 7.sp, fontWeight: FontWeight.w600)),
          ]);
        })));
    });
  }

  Widget _buildSliders() {
    return Container(padding: EdgeInsets.all(16.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('+15', style: TextStyle(color: Colors.white24, fontSize: 9.sp)), const Spacer(), Text('-15', style: TextStyle(color: Colors.white24, fontSize: 9.sp))]),
        SizedBox(height: 8.h),
        SizedBox(height: 200.h, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(10, (i) => _buildBand(i)))),
        SizedBox(height: 8.h),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(10, (i) => SizedBox(width: 28.w, child: Text(EQPreset.bandLabels[i], textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 8.sp, fontWeight: FontWeight.w600))))),
      ]));
  }

  Widget _buildBand(int i) {
    final c = Color.lerp(const Color(0xFF00D4FF), const Color(0xFF9D50BB), i / 10.0)!;
    return SizedBox(width: 28.w, child: Column(children: [
      Text(_bands[i].toStringAsFixed(0), style: TextStyle(color: c.withOpacity(0.8), fontSize: 8.sp, fontWeight: FontWeight.w700)),
      SizedBox(height: 4.h),
      Expanded(child: RotatedBox(quarterTurns: 3, child: SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: c, inactiveTrackColor: Colors.white.withOpacity(0.06), thumbColor: Colors.white, overlayColor: c.withOpacity(0.15), trackHeight: 4.h, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r)),
        child: Slider(value: _bands[i], min: -15, max: 15, onChanged: (v) => _onBandChanged(i, v))))),
    ]));
  }

  Widget _buildPresets() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRESETS', style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      SizedBox(height: 12.h),
      Wrap(spacing: 10.w, runSpacing: 10.h, children: EQPreset.presets.map((p) {
        final sel = _activePreset == p.name;
        final locked = !widget.isPremiumUser && p.name != 'Flat';
        return GestureDetector(onTap: () => _onPresetSelected(p), child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(color: sel ? p.color.withOpacity(0.2) : Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: sel ? p.color.withOpacity(0.6) : locked ? Colors.orange.withOpacity(0.2) : Colors.white.withOpacity(0.08), width: sel ? 1.5 : 1),
            boxShadow: sel ? [BoxShadow(color: p.color.withOpacity(0.2), blurRadius: 10)] : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(locked ? Icons.lock_rounded : p.icon, color: locked ? Colors.orange : sel ? p.color : Colors.white38, size: 16.sp),
            SizedBox(width: 8.w),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: TextStyle(color: locked ? Colors.orange : sel ? Colors.white : Colors.white60, fontSize: 12.sp, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              Text(p.description, style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
            ]),
          ])));
      }).toList()),
    ]);
  }

  Widget _buildFileInfo() {
    final name = _audioService.currentFileName;
    if (name == null) return const SizedBox.shrink();
    return Container(padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Icon(Icons.music_note_rounded, color: const Color(0xFF00D4FF), size: 18.sp),
        SizedBox(width: 12.w),
        Expanded(child: Text(name, style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
        GestureDetector(onTap: () async { await _audioService.togglePlayback(); if (mounted) setState(() {}); },
          child: Container(width: 36.w, height: 36.w, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00D4FF).withOpacity(0.15)),
            child: Icon(_audioService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF00D4FF), size: 20.sp))),
      ]));
  }
}
