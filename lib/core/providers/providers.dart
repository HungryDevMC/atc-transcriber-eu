import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcription.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../services/transcription_service.dart';

// Service providers
final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final service = TranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(() => service.dispose());
  return service;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final service = StorageService();
  ref.onDispose(() => service.dispose());
  return service;
});

// State providers
final transcriptionStateProvider =
    StreamProvider<TranscriptionState>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.stateStream;
});

final bluetoothStateProvider =
    StreamProvider<BluetoothConnectionState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.stateStream;
});

final currentTranscriptionProvider = StreamProvider<Transcription>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.transcriptionStream;
});

final partialTranscriptionProvider = StreamProvider<String>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.partialStream;
});

// Transcription history
final transcriptionHistoryProvider =
    StateNotifierProvider<TranscriptionHistoryNotifier, List<Transcription>>(
        (ref) {
  final storageService = ref.watch(storageServiceProvider);
  final transcriptionStream = ref.watch(currentTranscriptionProvider);

  final notifier = TranscriptionHistoryNotifier(storageService);

  // Auto-save new transcriptions
  transcriptionStream.whenData((transcription) {
    notifier.add(transcription);
  });

  return notifier;
});

class TranscriptionHistoryNotifier extends StateNotifier<List<Transcription>> {
  final StorageService _storageService;

  TranscriptionHistoryNotifier(this._storageService)
      : super(_storageService.getTodayTranscriptions());

  void add(Transcription transcription) {
    _storageService.saveTranscription(transcription);
    state = [transcription, ...state];
  }

  void remove(String id) {
    _storageService.deleteTranscription(id);
    state = state.where((t) => t.id != id).toList();
  }

  void loadToday() {
    state = _storageService.getTodayTranscriptions();
  }

  void loadDateRange(DateTime start, DateTime end) {
    state = _storageService.getTranscriptionsByDateRange(start, end);
  }

  void clearAll() {
    _storageService.clearAllTranscriptions();
    state = [];
  }
}

// Settings
final darkModeProvider = StateProvider<bool>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.getDarkMode();
});

final currentFrequencyProvider = StateProvider<String?>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.getSavedFrequency();
});

// Recording state
final isRecordingProvider = StateProvider<bool>((ref) => false);
