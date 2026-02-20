import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/services/transcription_service.dart';
import '../../core/utils/atc_vocabulary.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/transcription_card.dart';

class TranscriptionScreen extends ConsumerStatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  ConsumerState<TranscriptionScreen> createState() =>
      _TranscriptionScreenState();
}

class _TranscriptionScreenState extends ConsumerState<TranscriptionScreen> {
  String _partialText = '';
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final transcriptionService = ref.read(transcriptionServiceProvider);
      final bluetoothService = ref.read(bluetoothServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      await storageService.initialize();
      await bluetoothService.initialize();
      await transcriptionService.initialize();

      // Listen to partial transcriptions
      transcriptionService.partialStream.listen((partial) {
        if (mounted) {
          setState(() => _partialText = partial);
        }
      });

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initError = e.toString());
      }
    }
  }

  Future<void> _toggleRecording() async {
    final transcriptionService = ref.read(transcriptionServiceProvider);
    final isRecording = ref.read(isRecordingProvider);

    try {
      if (isRecording) {
        await transcriptionService.stopListening();
        ref.read(isRecordingProvider.notifier).state = false;
      } else {
        await transcriptionService.startListening();
        ref.read(isRecordingProvider.notifier).state = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(isRecordingProvider);
    final transcriptionState = ref.watch(transcriptionStateProvider);
    final history = ref.watch(transcriptionHistoryProvider);

    if (_initError != null) {
      return _buildErrorView();
    }

    if (!_isInitialized) {
      return _buildLoadingView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ATC Transcriber'),
        actions: [
          _buildFrequencyChip(),
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => Navigator.pushNamed(context, '/bluetooth'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(transcriptionState, isRecording),
          if (isRecording && _partialText.isNotEmpty)
            _buildPartialTranscription(),
          Expanded(
            child: history.isEmpty
                ? _buildEmptyState()
                : _buildTranscriptionList(history),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _toggleRecording,
        backgroundColor:
            isRecording ? AppTheme.recordingColor : null,
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 36,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingView() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing speech recognition...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Initialization Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Please ensure you have downloaded a Vosk model and placed it in the app\'s documents folder.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initError = null;
                    _isInitialized = false;
                  });
                  _initializeServices();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    AsyncValue<TranscriptionState> state,
    bool isRecording,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? AppTheme.recordingColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRecording ? 'Recording...' : 'Ready',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          state.when(
            data: (s) => Text(
              s.name.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Icon(Icons.error, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyChip() {
    final frequency = ref.watch(currentFrequencyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ActionChip(
        avatar: const Icon(Icons.radio, size: 18),
        label: Text(frequency ?? 'No freq'),
        onPressed: () => _showFrequencyDialog(),
      ),
    );
  }

  void _showFrequencyDialog() {
    final controller = TextEditingController(
      text: ref.read(currentFrequencyProvider),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Frequency (e.g., 118.250)',
                hintText: '118.250',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Common Belgian frequencies:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AtcVocabulary.belgianFrequencies.entries
                  .take(4)
                  .map((e) => ActionChip(
                        label: Text(e.key, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          controller.text = e.key;
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final freq = controller.text.trim();
              ref.read(currentFrequencyProvider.notifier).state =
                  freq.isEmpty ? null : freq;
              ref.read(transcriptionServiceProvider).setFrequency(
                    freq.isEmpty ? null : freq,
                  );
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialTranscription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.recordingColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.recordingColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _partialText,
              style: AppTheme.transcriptionText.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No transcriptions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the microphone to start',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTranscriptionList(List<dynamic> history) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final transcription = history[index];
        return TranscriptionCard(
          transcription: transcription,
          onDelete: () {
            ref.read(transcriptionHistoryProvider.notifier).remove(
                  transcription.id,
                );
          },
        );
      },
    );
  }
}
