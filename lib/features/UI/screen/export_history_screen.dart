import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/service/audio_project_repository.dart';
import '../../models/export_record.dart';
import '../controller/audio_project_controller.dart';

class ExportHistoryScreen extends StatelessWidget {
  const ExportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050A16),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071A2F), Color(0xFF050A16), Color(0xFF020712)],
        ),
      ),
      child: SafeArea(
        child: Consumer<AudioProjectController>(
          builder: (context, controller, _) {
            final records = controller.history;
            return records.isEmpty
                ? _EmptyHistory(onBack: () => Navigator.pop(context))
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 42),
                    itemCount: records.length + 1,
                    separatorBuilder: (_, index) =>
                        SizedBox(height: index == 0 ? 20 : 12),
                    itemBuilder: (context, index) => index == 0
                        ? _HistoryHeader(onBack: () => Navigator.pop(context))
                        : _ExportCard(
                            controller: controller,
                            record: records[index - 1],
                          ),
                  );
          },
        ),
      ),
    ),
  );
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _HeaderButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onTap: onBack,
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Text(
          'Export history',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
      ),
      const _HeaderButton(
        icon: Icons.history_rounded,
        tooltip: 'Export history',
      ),
    ],
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 42),
    child: Column(
      children: [
        _HistoryHeader(onBack: onBack),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: const Color(0xCC071B31),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF17608F)),
            boxShadow: const [
              BoxShadow(color: Color(0x3300BFEF), blurRadius: 28),
            ],
          ),
          child: const Column(
            children: [
              _HistoryIcon(),
              SizedBox(height: 20),
              Text(
                'No exports yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Export a processed audio file from Studio or Voice Lab and it will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFAFC4E2), height: 1.45),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    ),
  );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.controller, required this.record});
  final AudioProjectController controller;
  final ExportRecord record;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: context.read<AudioProjectRepository>().isExportAvailable(record),
    builder: (context, snapshot) {
      final available = snapshot.data == true;
      return InkWell(
        onTap: () => controller.loadProject(record.projectId),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xCC071B31),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: available
                  ? const Color(0xFF17608F)
                  : const Color(0xFFFF9C55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: available
                        ? const [Color(0xFF20D5FF), Color(0xFF0879FA)]
                        : const [Color(0xFF6A4A32), Color(0xFF332116)],
                  ),
                ),
                child: Icon(
                  available
                      ? Icons.audio_file_rounded
                      : Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${record.config.exportFormat.name.toUpperCase()} • ${record.metadata.duration.inSeconds}s • ${_date(record.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFAFC4E2),
                        fontSize: 12,
                      ),
                    ),
                    if (!available) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'Export file is missing',
                        style: TextStyle(
                          color: Color(0xFFFFAE77),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: available ? 'Share export' : 'File unavailable',
                onPressed: available
                    ? () => Share.shareXFiles([
                        XFile(record.outputPath),
                      ], text: record.displayName)
                    : null,
                icon: const Icon(Icons.share_rounded),
                color: const Color(0xFFBCEFFF),
              ),
              IconButton(
                tooltip: 'Delete export record',
                onPressed: () => controller.deleteExport(record.id),
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFFF9AA9),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HistoryIcon extends StatelessWidget {
  const _HistoryIcon();
  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    width: 76,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Color(0xFF20D5FF), Color(0xFF0879FA)]),
    ),
    child: const Icon(Icons.history_rounded, color: Colors.white, size: 38),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xFF0A2947),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFFBCEFFF)),
        ),
      ),
    ),
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
