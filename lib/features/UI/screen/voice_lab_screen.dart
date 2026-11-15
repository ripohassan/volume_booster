import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/service/audio_service.dart';
import '../../../core/service/audio_waveform_service.dart';
import '../../../core/service/studio_player.dart';
import '../../models/processing_config.dart';
import '../controller/audio_project_controller.dart';
import '../controller/audio_studio_controller.dart';
import 'export_history_screen.dart';
import 'audio_analyzer_screen.dart';
import 'widgets/audio_transport.dart';
import 'widgets/audio_waveform.dart';

/// Voice-specific, non-destructive FFmpeg workflow using the shared project.
class VoiceLabScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;
  const VoiceLabScreen({
    super.key,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });
  @override
  State<VoiceLabScreen> createState() => _VoiceLabScreenState();
}

class _VoiceLabScreenState extends State<VoiceLabScreen> {
  AudioStudioController? _lab;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lab ??= AudioStudioController(
      projects: context.read<AudioProjectController>(),
      waveforms: context.read<AudioWaveformService>(),
      player: SoLoudStudioPlayer(context.read<AudioService>(), 'voice-lab'),
    );
  }

  @override
  void dispose() {
    _lab?.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );

    //   if (result != null && result.files.single.path != null) {
    //     final file = result.files.single;
    //     return await loadFile(file.path!, file.name);
    //   }
    //   return false;
    // } catch (e) {
    //   debugPrint('❌ AudioService: Error picking file: $e');
    //   return false;
    // }

    // final r = await FilePicker.platform.pickFiles(
    //   type: FileType.audio,
    //   withData: false,
    // );
    final path = result?.files.single.path;
    if (path != null) {
      await _lab!.importFile(path, name: result!.files.single.name);
    }
    //
    // await _audioService.pickAndLoadFile();
    // if (mounted) setState(() {});
  }

  void _set(ProcessingConfig config) {
    final project = _lab!.project;
    if (project != null) _lab!.updateConfig(project.copyWith(config: config));
  }

  Widget _control(String name, double value, ValueChanged<double> change) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        decoration: BoxDecoration(
          color: const Color(0xCC071B31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF17608F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$name  ',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: '${(value * 100).round()}%',
                    style: const TextStyle(color: Color(0xFF20D5FF)),
                  ),
                ],
              ),
            ),
            Slider(value: value, onChanged: change),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _lab!,
    child: Consumer2<AudioStudioController, AudioProjectController>(
      builder: (context, lab, projects, _) {
        final project = projects.project;
        if (project == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF050A16),
            appBar: _toolbar(context),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF071A2F), Color(0xFF050A16)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: Color(0xFF00D4FF),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Voice Processing Lab',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Clean speech, remove noise & enhance vocals',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.mic),
                      label: const Text('Import recording'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final c = project.config;
        return Scaffold(
          backgroundColor: const Color(0xFF050A16),
          appBar: _toolbar(context),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF071A2F), Color(0xFF050A16)],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xCC071B31),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF17608F)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF20D5FF), Color(0xFF0879FA)],
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 33,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${project.duration.inSeconds}s • ${project.sampleRate} Hz • ${project.channels == 1 ? 'Mono' : 'Stereo'}',
                              style: const TextStyle(color: Color(0xFFB7CBE6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (lab.loadingWaveform)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (lab.waveform != null)
                  AudioWaveform(
                    envelope: lab.waveform!,
                    trimStart: project.trimStart,
                    trimEnd: project.trimEnd,
                    position: lab.position,
                    onSeek: lab.seek,
                    onTrimChanged: lab.setTrim,
                  ),
                AudioTransport(
                  position: lab.position,
                  total: project.duration,
                  playing: lab.isPlaying,
                  enabled: lab.waveform != null,
                  onPlayPause: lab.playPause,
                  onStop: lab.stop,
                  onSeek: lab.seek,
                ),
                const SizedBox(height: 18),
                const Text(
                  'VOICE PROCESSING',
                  style: TextStyle(
                    color: Color(0xFF20D5FF),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _control(
                  'Speech clarity',
                  c.speechClarity,
                  (v) => _set(c.copyWith(voiceEnabled: true, speechClarity: v)),
                ),
                _control(
                  'Background noise reduction',
                  c.noiseReduction,
                  (v) =>
                      _set(c.copyWith(voiceEnabled: true, noiseReduction: v)),
                ),
                _control(
                  'Vocal enhancement',
                  c.vocalBoost,
                  (v) => _set(c.copyWith(voiceEnabled: true, vocalBoost: v)),
                ),
                _control(
                  'Processing intensity',
                  c.voiceIntensity,
                  (v) =>
                      _set(c.copyWith(voiceEnabled: true, voiceIntensity: v)),
                ),
                _neonSwitch(
                  'Volume normalization',
                  value: c.normalizationEnabled,
                  onChanged: (v) => _set(
                    c.copyWith(voiceEnabled: true, normalizationEnabled: v),
                  ),
                ),
                _neonSwitch(
                  'Peak limiting',
                  value: c.limiterEnabled,
                  onChanged: (v) =>
                      _set(c.copyWith(voiceEnabled: true, limiterEnabled: v)),
                ),
                if (projects.isBusy)
                  Column(
                    children: [
                      LinearProgressIndicator(value: projects.progress),
                      TextButton(
                        onPressed: projects.cancelProcessing,
                        child: const Text('Cancel processing'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          if (!widget.isPremiumUser) {
                            widget.onShowSubscription();
                            return;
                          }
                          lab.renderPreview();
                        },
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(lab.hasPreview ? 'Reprocess' : 'Preview'),
                      ),
                      OutlinedButton(
                        onPressed: lab.hasPreview
                            ? () => lab.select(StudioSource.original)
                            : null,
                        child: const Text('Original'),
                      ),
                      OutlinedButton(
                        onPressed: lab.hasPreview
                            ? () => lab.select(StudioSource.enhanced)
                            : null,
                        child: const Text('Enhanced'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          if (!widget.isPremiumUser) {
                            widget.onShowSubscription();
                            return;
                          }
                          final record = await projects.export();
                          if (mounted && record != null)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Exported ${record.displayName}'),
                              ),
                            );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Export'),
                      ),
                    ],
                  ),
                if (lab.error != null || projects.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${lab.error ?? projects.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  PreferredSizeWidget _toolbar(BuildContext context) => AppBar(
    backgroundColor: const Color(0xFF071A2F),
    elevation: 0,
    title: const Row(
      children: [
        Icon(Icons.graphic_eq_rounded, color: Color(0xFF20D5FF)),
        SizedBox(width: 10),
        Text(
          'Voice Lab',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Import recording',
        onPressed: _import,
        icon: const Icon(Icons.audio_file_outlined),
      ),
      IconButton(
        tooltip: 'Audio analyzer',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioAnalyzerScreen()),
        ),
        icon: const Icon(Icons.analytics_outlined),
      ),
      IconButton(
        tooltip: 'Export history',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExportHistoryScreen()),
        ),
        icon: const Icon(Icons.history),
      ),
    ],
  );

  Widget _neonSwitch(
    String title, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xCC071B31),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF17608F)),
    ),
    child: SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      value: value,
      onChanged: onChanged,
    ),
  );
}
