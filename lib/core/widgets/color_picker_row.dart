import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/themes/domain/button_theme_spec.dart';

const List<Color> _swatches = [
  Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF1E88E5), Color(0xFFD32F2F),
  Color(0xFF2E7D32), Color(0xFFF4511E), Color(0xFF7C4DFF), Color(0xFF00E5FF),
  Color(0xFFFFB020), Color(0xFF39FF14), Color(0xFFFF2079), Color(0xFF546E7A),
  Color(0xFF9E9E9E), Color(0xFF4F46E5), Color(0xFF00897B), Color(0xFFFFC94D),
];

/// Color setting row → M3 bottom sheet with swatches + hex entry (doc §8.6).
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(label),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      onTap: () async {
        final picked = await showModalBottomSheet<Color>(
          context: context,
          showDragHandle: true,
          builder: (context) => _ColorSheet(initial: color),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _ColorSheet extends StatefulWidget {
  const _ColorSheet({required this.initial});

  final Color initial;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late final TextEditingController hexController;

  @override
  void initState() {
    super.initState();
    hexController = TextEditingController(
        text: colorToHex(widget.initial).replaceFirst('#', ''));
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick a color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _swatches)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context, c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: c.toARGB32() == widget.initial.toARGB32()
                        ? const Icon(Icons.check, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: hexController,
            decoration: const InputDecoration(
              prefixText: '#',
              labelText: 'Hex',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
            ],
            onSubmitted: (value) {
              if (value.length == 6) {
                Navigator.pop(context, colorFromHex(value));
              }
            },
          ),
        ],
      ),
    );
  }
}
