import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcription.dart';
import '../services/bluetooth_service.dart';
import '../services/model_manager.dart';
import '../services/storage_service.dart';
import '../services/transcription_service.dart';
import '../services/whisper_service.dart';

// Transcription engine selection
enum TranscriptionEngine {
  whisper, // Whisper.cpp - accurate, offline
  native, // Device native - fallback
}

// Service providers
final whisperServiceProvider = Provider<WhisperService>((ref) {
  final service = WhisperService();
  ref.onDispose(() => service.dispose());
  return service;
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  final manager = ModelManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

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

// Active transcription engine
final activeEngineProvider = StateProvider<TranscriptionEngine>((ref) {
  return TranscriptionEngine.whisper;
});

// Whisper state
final whisperStateProvider = StreamProvider<WhisperState>((ref) {
  final service = ref.watch(whisperServiceProvider);
  return service.stateStream;
});

final whisperModelProvider = Provider<WhisperModelType>((ref) {
  final service = ref.watch(whisperServiceProvider);
  return service.currentModel;
});

// Native transcription state (fallback)
final transcriptionStateProvider = StreamProvider<TranscriptionState>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.stateStream;
});

final bluetoothStateProvider =
    StreamProvider<BluetoothConnectionState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.stateStream;
});

// Combined transcription stream (from both engines)
final currentTranscriptionProvider = StreamProvider<Transcription>((ref) {
  final engine = ref.watch(activeEngineProvider);

  if (engine == TranscriptionEngine.whisper) {
    final whisperService = ref.watch(whisperServiceProvider);
    return whisperService.transcriptionStream;
  } else {
    final nativeService = ref.watch(transcriptionServiceProvider);
    return nativeService.transcriptionStream;
  }
});

final partialTranscriptionProvider = StreamProvider<String>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.partialStream;
});

// Model download progress
final modelDownloadProgressProvider =
    StreamProvider<ModelDownloadProgress>((ref) {
  final manager = ref.watch(modelManagerProvider);
  return manager.progressStream;
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
