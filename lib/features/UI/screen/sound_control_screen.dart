import 'package:flutter/material.dart';
import 'boost_screen.dart';
import 'equalizer_screen.dart';
import 'export_screen.dart';

/// Groups preserved legacy controls without removing their workflows.
class SoundControlScreen extends StatefulWidget {
  final bool isPremiumUser;
  final VoidCallback onShowSubscription;
  const SoundControlScreen({
    super.key,
    required this.isPremiumUser,
    required this.onShowSubscription,
  });
  @override
  State<SoundControlScreen> createState() => _SoundControlScreenState();
}

class _SoundControlScreenState extends State<SoundControlScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF071A2F), Color(0xFF050A16)],
      ),
    ),
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Semantics(
              label: 'Sound Control sections',
              child: SegmentedButton<int>(
                style: ButtonStyle(
                  side: const WidgetStatePropertyAll(
                    BorderSide(color: Color(0xFF2671A1)),
                  ),
                  foregroundColor: const WidgetStatePropertyAll(
                    Color(0xFFE6F5FF),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF0E6F9E)
                        : const Color(0xFF071D34),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.volume_up),
                    label: Text('Boost'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.graphic_eq),
                    label: Text('Equalizer'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.video_file),
                    label: Text('Video export'),
                  ),
                ],
                selected: {_index},
                onSelectionChanged: (value) =>
                    setState(() => _index = value.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              BoostScreen(
                isPremiumUser: widget.isPremiumUser,
                onShowSubscription: widget.onShowSubscription,
              ),
              EqualizerScreen(
                isPremiumUser: widget.isPremiumUser,
                onShowSubscription: widget.onShowSubscription,
              ),
              ExportScreen(
                isPremiumUser: widget.isPremiumUser,
                onShowSubscription: widget.onShowSubscription,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
