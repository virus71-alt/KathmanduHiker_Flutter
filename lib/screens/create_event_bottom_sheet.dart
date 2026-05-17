import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/feedback.dart';

class CreateEventBottomSheet extends StatefulWidget {
  final String trailName;
  final Future<void> Function(String dateText, int maxHikers) onCreate;
  const CreateEventBottomSheet({super.key, required this.trailName, required this.onCreate});

  @override
  State<CreateEventBottomSheet> createState() => _CreateEventBottomSheetState();
}

class _CreateEventBottomSheetState extends State<CreateEventBottomSheet> {
  DateTime? _date;
  final _maxCtl = TextEditingController(text: '10');

  @override
  void dispose() {
    _maxCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('📅 Plan a Group Hike',
              style: TextStyle(
                  color: colors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('🥾 Trail: ${widget.trailName}',
              style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              AppFeedback.tap();
              _pickDate();
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '🗓️ Date'),
              child: Builder(builder: (_) {
                final d = _date;
                return Text(d == null
                    ? 'Pick a date'
                    : DateFormat('EEE, MMM d, y').format(d));
              }),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxCtl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '👥 Max hikers'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final picked = _date;
              final max = int.tryParse(_maxCtl.text) ?? 0;
              if (picked == null || max <= 0) return;
              AppFeedback.success();
              await widget.onCreate(
                  DateFormat('EEE, MMM d, y').format(picked), max);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('🚀 Create Event',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
