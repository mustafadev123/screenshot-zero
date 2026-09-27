import 'package:flutter/material.dart';

import '../../domain/models/screenshot_item.dart';
import 'action_date_parser.dart';

Future<DateTime?> confirmActionTime(
  BuildContext context,
  ScreenshotItem item,
) => showDialog<DateTime>(
  context: context,
  builder: (_) => _ActionTimeDialog(item: item),
);

class _ActionTimeDialog extends StatefulWidget {
  const _ActionTimeDialog({required this.item});
  final ScreenshotItem item;
  @override
  State<_ActionTimeDialog> createState() => _ActionTimeDialogState();
}

class _ActionTimeDialogState extends State<_ActionTimeDialog> {
  DateTime? _date;
  TimeOfDay? _time;
  bool get reminder => widget.item.intent.name == 'task';
  @override
  void initState() {
    super.initState();
    final fields = widget.item.extractedFields;
    final parsed = parseActionDate(
      fields[reminder ? 'due_date' : 'date'],
      fields[reminder ? 'due_time' : 'time'],
    );
    _date = parsed;
    _time = parsed == null ? null : TimeOfDay.fromDateTime(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final time = _time;
    final selected = date == null || time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final valid =
        selected != null &&
        selected.hour == time!.hour &&
        selected.minute == time.minute &&
        (!reminder || selected.isAfter(DateTime.now()));
    final fields = widget.item.extractedFields;
    return AlertDialog(
      title: Text(reminder ? 'Create reminder' : 'Add to calendar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (fields['venue'] != null && !reminder) Text(fields['venue']!),
            const SizedBox(height: 12),
            if (selected == null)
              Text(
                'Recognized: ${fields[reminder ? 'due_date' : 'date'] ?? 'No date'} · ${fields[reminder ? 'due_time' : 'time'] ?? 'No time'}\nChoose a complete date and time.',
              ),
            TextButton(
              onPressed: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(9999, 12, 31),
                );
                if (chosen != null && mounted) setState(() => _date = chosen);
              },
              child: Text(
                date == null
                    ? 'Choose date'
                    : MaterialLocalizations.of(context).formatMediumDate(date),
              ),
            ),
            TextButton(
              onPressed: () async {
                final chosen = await showTimePicker(
                  context: context,
                  initialTime: time ?? TimeOfDay.now(),
                );
                if (chosen != null && mounted) setState(() => _time = chosen);
              },
              child: Text(time == null ? 'Choose time' : time.format(context)),
            ),
            Text(
              'Device local time (${(selected ?? DateTime.now()).timeZoneName})',
            ),
            if (reminder)
              const Text(
                'Delivery may be delayed by Android battery settings.',
              ),
            if (selected != null && !valid)
              const Text('Choose a valid future time.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, selected) : null,
          child: Text(reminder ? 'Create reminder' : 'Open Calendar'),
        ),
      ],
    );
  }
}

Future<bool> confirmCalendarSaved(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did you save the event?'),
        content: const Text(
          'Confirm after saving in Calendar. Otherwise this screenshot stays in your inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep in inbox'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, saved'),
          ),
        ],
      ),
    ) ??
    false;
