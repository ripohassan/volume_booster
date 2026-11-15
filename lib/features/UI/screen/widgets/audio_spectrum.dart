import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../features/models/audio_analysis.dart';

class AudioSpectrum extends StatelessWidget {
  final AudioAnalysis analysis;
  const AudioSpectrum({super.key, required this.analysis});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Measured frequency spectrum',
    child: CustomPaint(
      size: const Size(double.infinity, 170),
      painter: _Spectrum(analysis),
    ),
  );
}

class _Spectrum extends CustomPainter {
  final AudioAnalysis a;
  _Spectrum(this.a);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 1;
    final max = a.spectrumPower.fold(0.0, math.max);
    if (max <= 0) return;
    for (var i = 0; i < a.spectrumPower.length; i++) {
      final x = i / (a.spectrumPower.length - 1) * s.width;
      final h = (a.spectrumPower[i] / max).clamp(0, 1) * s.height;
      c.drawLine(Offset(x, s.height), Offset(x, s.height - h), p);
    }
  }

  @override
  bool shouldRepaint(_Spectrum old) => old.a != a;
}
