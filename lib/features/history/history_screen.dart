import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/transcription.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/transcription_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(transcriptionHistoryProvider);

    // Group by date
    final grouped = _groupByDate(history);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDialog();
              } else if (value == 'export') {
                _exportTranscriptions(history);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmptyState()
          : _buildGroupedList(grouped),
    );
  }

  Map<String, List<Transcription>> _groupByDate(List<Transcription> items) {
    final grouped = <String, List<Transcription>>{};
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final item in items) {
      final key = dateFormat.format(item.timestamp);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No transcription history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transcriptions will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(Map<String, List<Transcription>> grouped) {
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final items = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, items.length),
            ...items.map((t) => TranscriptionCard(
                  transcription: t,
                  onDelete: () {
                    ref.read(transcriptionHistoryProvider.notifier).remove(t.id);
                  },
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    String label;
    if (dateDay == today) {
      label = 'Today';
    } else if (dateDay == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMMM d').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);

      final start = DateTime(picked.year, picked.month, picked.day);
      final end = start.add(const Duration(days: 1));

      ref.read(transcriptionHistoryProvider.notifier).loadDateRange(start, end);
    }
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete all transcription history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(transcriptionHistoryProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _exportTranscriptions(List<Transcription> items) {
    // Generate text export
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    buffer.writeln('ATC Transcription Export');
    buffer.writeln('Generated: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final item in items) {
      buffer.writeln('[${dateFormat.format(item.timestamp)}]');
      if (item.frequency != null) {
        buffer.writeln('Frequency: ${item.frequency}');
      }
      buffer.writeln(item.text);
      if (item.detectedCallsigns.isNotEmpty) {
        buffer.writeln('Callsigns: ${item.detectedCallsigns.join(', ')}');
      }
      buffer.writeln();
    }

    // TODO: Implement file saving or sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }
}
