import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_analysis.dart';
import '../controller/audio_analyzer_controller.dart';
import '../controller/audio_project_controller.dart';
import 'widgets/audio_spectrum.dart';

class AudioAnalyzerScreen extends StatelessWidget {
  const AudioAnalyzerScreen({super.key});
  String _db(double value) =>
      value.isInfinite ? '−∞ dBFS' : '${value.toStringAsFixed(1)} dBFS';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050A16),
    appBar: AppBar(
      title: const Text('Audio Analyzer'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.query_stats_rounded, color: Color(0xFF20D5FF)),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071A2F), Color(0xFF050A16)],
        ),
      ),
      child: Consumer2<AudioAnalyzerController, AudioProjectController>(
        builder: (context, c, p, _) {
          final item = p.project;
          final a = c.analysis;
          if (item == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF20D5FF),
                      size: 56,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Import audio in Studio or Voice Lab first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD8E8FF), fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xCC071B31),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF17608F)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF0A3D61),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFFBCEFFF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.codec} • ${item.duration.inSeconds}s • ${item.sampleRate} Hz • ${item.channels} ch',
                            style: const TextStyle(color: Color(0xFFB7CBE6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (c.state == AudioAnalyzerState.analyzing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(value: c.progress),
                ),
              FilledButton.icon(
                onPressed: c.state == AudioAnalyzerState.analyzing
                    ? null
                    : () => c.analyze(item),
                icon: const Icon(Icons.insights_rounded),
                label: Text(
                  a == null ? 'Analyze decoded samples' : 'Reanalyze',
                ),
              ),
              if (a != null) ...[
                const SizedBox(height: 18),
                _measurements(a),
                const SizedBox(height: 18),
                const Text(
                  'Frequency spectrum',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                AudioSpectrum(analysis: a),
                const SizedBox(height: 8),
                const Text(
                  'Hann-windowed 1024-sample FFT; values are linear magnitudes from the first selected-region window.',
                  style: TextStyle(color: Color(0xFF9AB1CE), fontSize: 12),
                ),
              ],
              if (c.error != null)
                Text('$c.error', style: const TextStyle(color: Colors.red)),
            ],
          );
        },
      ),
    ),
  );
  Widget _measurements(AudioAnalysis a) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Measured audio',
            style: TextStyle(
              color: Color(0xFF20D5FF),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected scope: ${a.rangeStart.inMilliseconds / 1000}s – ${a.rangeEnd.inMilliseconds / 1000}s',
            style: const TextStyle(color: Color(0xFFDCEBFF)),
          ),
          for (var i = 0; i < a.rms.length; i++)
            Text(
              'Channel ${i + 1}: RMS ${_db(a.rmsDbfs[i])} • peak ${_db(a.peakDbfs[i])} • ≥${(a.clippingThreshold * 100).toStringAsFixed(1)}%: ${a.clippingCounts[i]} (${(100 * a.clippingCounts[i] / a.framesAnalyzed).toStringAsFixed(3)}%)',
              style: const TextStyle(color: Color(0xFFC0D3EC)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Near-full-scale samples indicate possible clipping; they do not prove clipping occurred in the original recording.',
            style: TextStyle(color: Color(0xFF93ACCA), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
