import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/service/audio_service.dart';
import '../../../core/service/audio_waveform_service.dart';
import '../../../core/service/studio_player.dart';
import '../../models/audio_project.dart';
import '../../models/processing_config.dart';
import '../controller/audio_project_controller.dart';
import '../controller/audio_studio_controller.dart';
import 'audio_analyzer_screen.dart';
import 'export_history_screen.dart';
import 'widgets/audio_transport.dart';
import 'widgets/audio_waveform.dart';

class AudioStudioScreen extends StatefulWidget {
  const AudioStudioScreen({
    super.key,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });

  final bool isPremiumUser;
  final VoidCallback onShowSubscription;

  @override
  State<AudioStudioScreen> createState() => _AudioStudioScreenState();
}

class _AudioStudioScreenState extends State<AudioStudioScreen> {
  final AudioService _audioService = AudioService();
  AudioStudioController? _studio;
  bool _eqOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _studio ??= AudioStudioController(
      projects: context.read<AudioProjectController>(),
      waveforms: context.read<AudioWaveformService>(),
      player: SoLoudStudioPlayer(_audioService, 'audio-studio'),
    );
  }

  @override
  void dispose() {
    _studio?.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      await _studio!.importFile(path, name: result!.files.single.name);
    }
  }

  void _config(ProcessingConfig config) {
    final project = _studio!.project;
    if (project != null) {
      _studio!.updateConfig(project.copyWith(config: config));
    }
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _studio!,
    child: Consumer2<AudioStudioController, AudioProjectController>(
      builder: (context, studio, projects, _) {
        final project = projects.project;
        return Scaffold(
          backgroundColor: const Color(0xFF050A16),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF071A2F),
                  Color(0xFF050A16),
                  Color(0xFF020712),
                ],
                stops: [0, .44, 1],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: project == null
                  ? _EmptyStudio(onImport: _import)
                  : _LoadedStudio(
                      project: project,
                      studio: studio,
                      projects: projects,
                      eqOpen: _eqOpen,
                      onImport: _import,
                      onToggleEq: () => setState(() => _eqOpen = !_eqOpen),
                      onConfig: _config,
                      isPremiumUser: widget.isPremiumUser,
                      onShowSubscription: widget.onShowSubscription,
                    ),
            ),
          ),
        );
      },
    ),
  );
}

class _EmptyStudio extends StatelessWidget {
  const _EmptyStudio({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
    child: Column(
      children: [
        _StudioHeader(onImport: onImport),
        const SizedBox(height: 48),
        _StudioCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20D5FF), Color(0xFF0879FA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16C7FF).withOpacity(.25),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.audio_file_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Start a new audio project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Import an audio file to trim, enhance, preview and export.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFAFC4E2), height: 1.45),
              ),
              const SizedBox(height: 26),
              _GradientButton(
                onPressed: onImport,
                icon: Icons.folder_open_rounded,
                label: 'Import audio',
              ),
              const SizedBox(height: 12),
              const Text(
                'MP3, WAV, M4A, AAC, OGG and FLAC',
                style: TextStyle(color: Color(0xFF7186A5), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoadedStudio extends StatelessWidget {
  const _LoadedStudio({
    required this.project,
    required this.studio,
    required this.projects,
    required this.eqOpen,
    required this.onImport,
    required this.onToggleEq,
    required this.onConfig,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });
  final AudioProject project;
  final AudioStudioController studio;
  final AudioProjectController projects;
  final bool eqOpen;
  final VoidCallback onImport;
  final VoidCallback onToggleEq;
  final ValueChanged<ProcessingConfig> onConfig;
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 150),
        sliver: SliverList(
          delegate: SliverChildListDelegate.fixed([
            _StudioHeader(onImport: onImport),
            const SizedBox(height: 22),
            _ProjectCard(project: project, onImport: onImport),
            const SizedBox(height: 18),
            _WaveformPanel(project: project, studio: studio),
            const SizedBox(height: 18),
            AudioTransport(
              position: studio.position,
              total: project.trimEnd,
              playing: studio.isPlaying,
              enabled: studio.waveform != null,
              onPlayPause: studio.playPause,
              onStop: studio.stop,
              onSeek: studio.seek,
            ),
            const SizedBox(height: 22),
            _TonePanel(project: project, onConfig: onConfig),
            const SizedBox(height: 16),
            _ProcessingPanel(
              project: project,
              open: eqOpen,
              onToggleEq: onToggleEq,
              onConfig: onConfig,
            ),
            const SizedBox(height: 16),
            _ExportPanel(
              project: project,
              studio: studio,
              projects: projects,
              isPremiumUser: isPremiumUser,
              onShowSubscription: onShowSubscription,
            ),
            if (studio.error != null || projects.error != null) ...[
              const SizedBox(height: 14),
              _ErrorPanel(message: '${studio.error ?? projects.error}'),
            ],
          ]),
        ),
      ),
    ],
  );
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({this.onImport});
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0A2947),
        ),
        child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF20D5FF)),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'Audio Studio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
      ),
      if (onImport != null)
        _HeaderIcon(
          tooltip: 'Import audio',
          icon: Icons.folder_open_rounded,
          onPressed: onImport!,
        ),
      if (onImport != null) const SizedBox(width: 8),
      _HeaderIcon(
        tooltip: 'Audio analyzer',
        icon: Icons.analytics_outlined,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioAnalyzerScreen()),
        ),
      ),
      const SizedBox(width: 8),
      _HeaderIcon(
        tooltip: 'Export history',
        icon: Icons.history_rounded,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExportHistoryScreen()),
        ),
      ),
    ],
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onImport});
  final AudioProject project;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => _StudioCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF28D8FF), Color(0xFF076CF6)],
            ),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 34,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_duration(project.duration)} • ${project.sampleRate} Hz • ${project.channels} ch • ${project.codec}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFADC2DE), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Import another audio file',
          onPressed: onImport,
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFC4D7EF)),
        ),
      ],
    ),
  );
}

class _WaveformPanel extends StatelessWidget {
  const _WaveformPanel({required this.project, required this.studio});
  final AudioProject project;
  final AudioStudioController studio;

  @override
  Widget build(BuildContext context) => _StudioCard(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
    child: Column(
      children: [
        if (studio.loadingWaveform)
          const SizedBox(
            height: 190,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF16C7FF)),
            ),
          )
        else if (studio.waveform != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              height: 190,
              color: const Color(0xFF031A29),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AudioWaveform(
                envelope: studio.waveform!,
                trimStart: project.trimStart,
                trimEnd: project.trimEnd,
                position: studio.position,
                onSeek: studio.seek,
                onTrimChanged: studio.setTrim,
              ),
            ),
          )
        else
          const SizedBox(
            height: 190,
            child: Center(
              child: Text(
                'Waveform is unavailable',
                style: TextStyle(color: Color(0xFF9FB5D3)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Trim: ${_seconds(project.trimStart)} – ${_seconds(project.trimEnd)}',
              style: const TextStyle(
                color: Color(0xFFC0D5F2),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TonePanel extends StatelessWidget {
  const _TonePanel({required this.project, required this.onConfig});
  final AudioProject project;
  final ValueChanged<ProcessingConfig> onConfig;

  @override
  Widget build(BuildContext context) => _StudioCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        _ControlSlider(
          icon: Icons.volume_up_rounded,
          label: 'Volume',
          value: project.config.gainDb,
          min: -24,
          max: 12,
          onChanged: (value) =>
              onConfig(project.config.copyWith(gainDb: value)),
        ),
        const SizedBox(height: 22),
        _ControlSlider(
          icon: Icons.multitrack_audio_rounded,
          label: 'Bass',
          value: project.config.bassGainDb,
          min: -12,
          max: 12,
          onChanged: (value) =>
              onConfig(project.config.copyWith(bassGainDb: value)),
        ),
      ],
    ),
  );
}

class _ProcessingPanel extends StatelessWidget {
  const _ProcessingPanel({
    required this.project,
    required this.open,
    required this.onToggleEq,
    required this.onConfig,
  });
  final AudioProject project;
  final bool open;
  final VoidCallback onToggleEq;
  final ValueChanged<ProcessingConfig> onConfig;

  @override
  Widget build(BuildContext context) => _StudioCard(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
    child: Column(
      children: [
        _PanelRow(
          icon: Icons.tune_rounded,
          label: '10-band EQ',
          trailing: IconButton(
            tooltip: open ? 'Collapse equalizer' : 'Expand equalizer',
            onPressed: onToggleEq,
            icon: Icon(
              open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFFB9E8FF),
            ),
          ),
        ),
        if (open) ...[
          const Divider(color: Color(0xFF164468), height: 1),
          const SizedBox(height: 8),
          for (var i = 0; i < ProcessingConfig.frequencies.length; i++)
            _CompactBand(
              label: '${ProcessingConfig.frequencies[i]} Hz',
              value: project.config.eqBands[i],
              onChanged: (value) {
                final bands = [...project.config.eqBands];
                bands[i] = value;
                onConfig(project.config.copyWith(eqBands: bands));
              },
            ),
        ],
        const Divider(color: Color(0xFF164468), height: 1),
        _PanelRow(
          icon: Icons.auto_awesome_rounded,
          label: 'Normalize',
          trailing: Switch.adaptive(
            value: project.config.normalizationEnabled,
            activeColor: const Color(0xFF16C7FF),
            onChanged: (value) =>
                onConfig(project.config.copyWith(normalizationEnabled: value)),
          ),
        ),
        const Divider(color: Color(0xFF164468), height: 1),
        _PanelRow(
          icon: Icons.shield_rounded,
          label: 'Limiter',
          trailing: Switch.adaptive(
            value: project.config.limiterEnabled,
            activeColor: const Color(0xFF16C7FF),
            onChanged: (value) =>
                onConfig(project.config.copyWith(limiterEnabled: value)),
          ),
        ),
      ],
    ),
  );
}

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({
    required this.project,
    required this.studio,
    required this.projects,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });
  final AudioProject project;
  final AudioStudioController studio;
  final AudioProjectController projects;
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;

  @override
  Widget build(BuildContext context) {
    if (projects.isBusy) {
      return _StudioCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processing audio…',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: projects.progress,
                minHeight: 8,
                backgroundColor: const Color(0xFF143857),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF16C7FF)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: projects.cancelProcessing,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel processing'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudioCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ExportFormat>(
              isExpanded: true,
              value: project.config.exportFormat,
              dropdownColor: const Color(0xFF09213A),
              iconEnabledColor: const Color(0xFFB8E9FF),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              items: const [
                DropdownMenuItem(
                  value: ExportFormat.aac,
                  child: Text('AAC / M4A'),
                ),
                DropdownMenuItem(value: ExportFormat.wav, child: Text('WAV')),
              ],
              onChanged: (format) {
                if (format != null)
                  studio.updateConfig(
                    project.copyWith(
                      config: project.config.copyWith(exportFormat: format),
                    ),
                  );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _SoftAction(
              onPressed: () {
                if (!isPremiumUser) {
                  onShowSubscription();
                  return;
                }
                studio.renderPreview();
              },
              icon: Icons.auto_fix_high_rounded,
              label: studio.hasPreview ? 'Reprocess' : 'Preview',
            ),
            _SoftAction(
              onPressed: studio.hasPreview
                  ? () => studio.select(StudioSource.original)
                  : null,
              icon: Icons.hearing_rounded,
              label: 'Original',
              selected: studio.source == StudioSource.original,
            ),
            _SoftAction(
              onPressed: studio.hasPreview
                  ? () => studio.select(StudioSource.enhanced)
                  : null,
              icon: Icons.auto_awesome_rounded,
              label: 'Enhanced',
              selected: studio.source == StudioSource.enhanced,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GradientButton(
          onPressed: () async {
            if (!isPremiumUser) {
              onShowSubscription();
              return;
            }
            final export = await projects.export();
            if (context.mounted && export != null)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported ${export.displayName}')),
              );
          },
          icon: Icons.file_download_rounded,
          label: 'Export audio',
        ),
      ],
    );
  }
}

class _ControlSlider extends StatelessWidget {
  const _ControlSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _RoundIcon(icon: icon),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: '${value.toStringAsFixed(1)} dB',
                    style: const TextStyle(color: Color(0xFF29D3FF)),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF5DDCFF),
                inactiveTrackColor: const Color(0xFF173E61),
                thumbColor: const Color(0xFFC4F2FF),
                overlayColor: const Color(0xFF16C7FF).withOpacity(.16),
                trackHeight: 6,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CompactBand extends StatelessWidget {
  const _CompactBand({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 54,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFAEC5E3), fontSize: 12),
        ),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: -15,
          max: 15,
          activeColor: const Color(0xFF36D7FF),
          inactiveColor: const Color(0xFF173E61),
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 38,
        child: Text(
          value.toStringAsFixed(0),
          textAlign: TextAlign.end,
          style: const TextStyle(color: Color(0xFF38D7FF), fontSize: 12),
        ),
      ),
    ],
  );
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });
  final IconData icon;
  final String label;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      children: [
        _RoundIcon(icon: icon, small: true),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF2F7FF),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xFF0A2641),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onPressed,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, color: const Color(0xFFB9E7FF)),
        ),
      ),
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.small = false});
  final IconData icon;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
    height: small ? 42 : 52,
    width: small ? 42 : 52,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF083153),
      border: Border.all(color: const Color(0xFF1A5A86)),
    ),
    child: Icon(icon, color: const Color(0xFFC4EFFF), size: small ? 22 : 27),
  );
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xCC071B31),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF17608F)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.20),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF1DD1FF), Color(0xFF338CFF)],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1CCAFF).withOpacity(.25),
          blurRadius: 18,
        ),
      ],
    ),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF03213D),
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.selected = false,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: selected
          ? const Color(0xFF17D0FF)
          : const Color(0xFFDBE9FF),
      disabledForegroundColor: const Color(0xFF617894),
      backgroundColor: selected
          ? const Color(0xFF0D456C)
          : const Color(0xFF082039),
      side: BorderSide(
        color: selected ? const Color(0xFF20D5FF) : const Color(0xFF245678),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF4B1722),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE56B7C)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFFA7B3)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFDCE1)),
          ),
        ),
      ],
    ),
  );
}

String _duration(Duration duration) =>
    '${duration.inMinutes.remainder(60)}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
String _seconds(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
