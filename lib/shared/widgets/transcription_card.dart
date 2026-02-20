import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/transcription.dart';
import '../theme/app_theme.dart';

class TranscriptionCard extends StatelessWidget {
  final Transcription transcription;
  final VoidCallback? onDelete;

  const TranscriptionCard({
    super.key,
    required this.transcription,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _showOptions(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildText(context),
              if (transcription.detectedCallsigns.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCallsigns(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');

    return Row(
      children: [
        Text(
          timeFormat.format(transcription.timestamp),
          style: AppTheme.timestampText,
        ),
        if (transcription.frequency != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              transcription.frequency!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => _copyToClipboard(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildText(BuildContext context) {
    if (transcription.detectedCallsigns.isEmpty) {
      return Text(
        transcription.text,
        style: AppTheme.transcriptionText,
      );
    }

    // Highlight callsigns in the text
    return RichText(
      text: _buildHighlightedText(context),
    );
  }

  TextSpan _buildHighlightedText(BuildContext context) {
    String text = transcription.text;
    final spans = <TextSpan>[];
    int lastEnd = 0;

    // Find and highlight each callsign
    for (final callsign in transcription.detectedCallsigns) {
      final pattern = RegExp(
        callsign.replaceAll('-', '-?'),
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text.substring(lastEnd));

      if (match != null) {
        final start = lastEnd + match.start;
        final end = lastEnd + match.end;

        // Add text before callsign
        if (start > lastEnd) {
          spans.add(TextSpan(
            text: text.substring(lastEnd, start),
            style: AppTheme.transcriptionText.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ));
        }

        // Add highlighted callsign
        spans.add(TextSpan(
          text: text.substring(start, end),
          style: AppTheme.callsignHighlight,
        ));

        lastEnd = end;
      }
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTheme.transcriptionText.copyWith(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  Widget _buildCallsigns(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: transcription.detectedCallsigns.map((callsign) {
        return Chip(
          label: Text(
            callsign,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transcription.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context);
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
