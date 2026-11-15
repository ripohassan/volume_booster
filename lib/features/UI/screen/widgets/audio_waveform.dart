import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/service/audio_waveform_service.dart';

class AudioWaveform extends StatelessWidget {
  final WaveformEnvelope envelope;
  final Duration trimStart, trimEnd, position;
  final ValueChanged<Duration> onSeek;
  final void Function(Duration, Duration) onTrimChanged;
  const AudioWaveform({
    super.key,
    required this.envelope,
    required this.trimStart,
    required this.trimEnd,
    required this.position,
    required this.onSeek,
    required this.onTrimChanged,
  });
  Duration _fromX(double x, double width) => Duration(
    microseconds: (x / width * envelope.duration.inMicroseconds).round().clamp(
      0,
      envelope.duration.inMicroseconds,
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(
        constraints.maxWidth,
        envelope.minima.length * 3.0,
      );
      return Semantics(
        label: 'Audio waveform',
        child: SizedBox(
          height: 166,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: GestureDetector(
              onTapUp: (d) => onSeek(_fromX(d.localPosition.dx, width)),
              onLongPressMoveUpdate: (d) {
                final next = _fromX(d.localPosition.dx, width);
                final before =
                    (next - trimStart).abs() < (next - trimEnd).abs();
                if (before && next < trimEnd) onTrimChanged(next, trimEnd);
                if (!before && next > trimStart) onTrimChanged(trimStart, next);
              },
              child: CustomPaint(
                size: Size(width, 166),
                painter: _Painter(envelope, trimStart, trimEnd, position),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Painter extends CustomPainter {
  final WaveformEnvelope e;
  final Duration start, end, pos;
  _Painter(this.e, this.start, this.end, this.pos);
  @override
  void paint(Canvas c, Size s) {
    final d = e.duration.inMicroseconds.toDouble();
    final selected = Paint()..color = const Color(0xFF16C7FF).withOpacity(.16);
    c.drawRect(
      Rect.fromLTRB(
        start.inMicroseconds / d * s.width,
        0,
        end.inMicroseconds / d * s.width,
        s.height,
      ),
      selected,
    );
    final p = Paint()
      ..color = const Color(0xFF18CCFF)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final mid = s.height / 2;
    for (var i = 0; i < e.minima.length; i++) {
      final x = e.minima.length < 2
          ? s.width / 2
          : i / (e.minima.length - 1) * s.width;
      c.drawLine(
        Offset(x, mid - e.maxima[i].clamp(-1, 1) * mid * .9),
        Offset(x, mid - e.minima[i].clamp(-1, 1) * mid * .9),
        p,
      );
    }
    final marker = Paint()
      ..color = const Color(0xFFE9FBFF)
      ..strokeWidth = 3;
    final x = pos.inMicroseconds / d * s.width;
    c.drawLine(Offset(x, 0), Offset(x, s.height), marker);
    for (final x in [
      start.inMicroseconds / d * s.width,
      end.inMicroseconds / d * s.width,
    ])
      c.drawLine(
        Offset(x, 3),
        Offset(x, s.height - 3),
        Paint()
          ..color = const Color(0xFFE5FAFF)
          ..strokeWidth = 3,
      );
    c.drawCircle(Offset(x, 8), 7, Paint()..color = const Color(0xFFE5FAFF));
    c.drawCircle(
      Offset(x, s.height - 8),
      7,
      Paint()..color = const Color(0xFFE5FAFF),
    );
  }

  @override
  bool shouldRepaint(_Painter o) =>
      o.start != start || o.end != end || o.pos != pos || o.e != e;
}
