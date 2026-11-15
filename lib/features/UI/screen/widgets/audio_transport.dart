import 'package:flutter/material.dart';

class AudioTransport extends StatelessWidget {
  final Duration position, total;
  final bool playing, enabled;
  final VoidCallback onPlayPause, onStop;
  final ValueChanged<Duration> onSeek;
  const AudioTransport({
    super.key,
    required this.position,
    required this.total,
    required this.playing,
    required this.enabled,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
  });
  String _time(Duration value) =>
      '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final max = total.inMilliseconds
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();
    return Semantics(
      label: 'Audio transport',
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  _time(position),
                  style: const TextStyle(
                    color: Color(0xFFF2F7FF),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF61DFFF),
                      inactiveTrackColor: const Color(0xFF153752),
                      thumbColor: const Color(0xFFC9F3FF),
                      overlayColor: const Color(0xFF16C7FF).withOpacity(.16),
                      trackHeight: 7,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 13,
                      ),
                    ),
                    child: Slider(
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0, max)
                          .toDouble(),
                      max: max,
                      onChanged: enabled
                          ? (v) => onSeek(Duration(milliseconds: v.round()))
                          : null,
                    ),
                  ),
                ),
                Text(
                  _time(total),
                  style: const TextStyle(
                    color: Color(0xFFF2F7FF),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: const Color(0xFF0B2945),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Stop',
                    onPressed: enabled ? onStop : null,
                    icon: const Icon(
                      Icons.stop_rounded,
                      color: Color(0xFFEAF6FF),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF77DEFF), Color(0xFF53A7FF)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF06213D),
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(142, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: enabled ? onPlayPause : null,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(playing ? 'Pause' : 'Play'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
