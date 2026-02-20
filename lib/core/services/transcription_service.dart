import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../models/transcription.dart';
import '../utils/atc_vocabulary.dart';

enum TranscriptionState {
  uninitialized,
  initializing,
  ready,
  listening,
  processing,
  error,
}

/// Transcription service using on-device speech recognition.
/// Currently uses speech_to_text which supports offline mode on iOS and
/// Android (when models are downloaded). Can be extended to use Vosk
/// for guaranteed offline support when needed.
class TranscriptionService {
  final SpeechToText _speech = SpeechToText();

  final _stateController = StreamController<TranscriptionState>.broadcast();
  final _transcriptionController = StreamController<Transcription>.broadcast();
  final _partialController = StreamController<String>.broadcast();

  TranscriptionState _state = TranscriptionState.uninitialized;
  String? _currentFrequency;
  bool _isInitialized = false;

  Stream<TranscriptionState> get stateStream => _stateController.stream;
  Stream<Transcription> get transcriptionStream =>
      _transcriptionController.stream;
  Stream<String> get partialStream => _partialController.stream;
  TranscriptionState get state => _state;

  /// Initialize the transcription service
  Future<void> initialize() async {
    if (_state == TranscriptionState.initializing) return;

    _setState(TranscriptionState.initializing);

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (_state == TranscriptionState.listening) {
            _setState(TranscriptionState.ready);
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' && _state == TranscriptionState.listening) {
            _setState(TranscriptionState.ready);
          }
        },
      );

      if (!_isInitialized) {
        throw Exception(
          'Speech recognition not available on this device. '
          'Please ensure microphone permissions are granted.',
        );
      }

      // Check for offline capability
      final locales = await _speech.locales();
      debugPrint('Available locales: ${locales.length}');

      _setState(TranscriptionState.ready);
    } catch (e) {
      debugPrint('Transcription init error: $e');
      _setState(TranscriptionState.error);
      rethrow;
    }
  }

  /// Start listening for audio input
  Future<void> startListening() async {
    if (_state != TranscriptionState.ready) {
      throw Exception('Service not ready. Current state: $_state');
    }

    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      _setState(TranscriptionState.listening);

      await _speech.listen(
        onResult: _handleResult,
        listenFor: const Duration(minutes: 30), // Long listening for ATC
        pauseFor: const Duration(seconds: 5), // Pause detection
        partialResults: true,
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          autoPunctuation: true,
          enableHapticFeedback: false,
        ),
      );
    } catch (e) {
      debugPrint('Start listening error: $e');
      _setState(TranscriptionState.error);
      rethrow;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_state != TranscriptionState.listening) return;

    try {
      await _speech.stop();
      _setState(TranscriptionState.ready);
    } catch (e) {
      debugPrint('Stop listening error: $e');
    }
  }

  /// Set the current frequency being monitored
  void setFrequency(String? frequency) {
    _currentFrequency = frequency;
  }

  void _handleResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();

    if (text.isEmpty) return;

    if (result.finalResult) {
      // Final result - create transcription
      final callsigns = AtcVocabulary.extractCallsigns(text);

      final transcription = Transcription(
        id: const Uuid().v4(),
        text: text,
        timestamp: DateTime.now(),
        confidence: result.confidence,
        detectedCallsigns: callsigns,
        frequency: _currentFrequency,
        isPartial: false,
      );

      _transcriptionController.add(transcription);

      // Auto-restart listening for continuous transcription
      if (_state == TranscriptionState.listening) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_state == TranscriptionState.ready ||
              _state == TranscriptionState.listening) {
            startListening();
          }
        });
      }
    } else {
      // Partial result
      _partialController.add(text);
    }
  }

  void _setState(TranscriptionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Clean up resources
  Future<void> dispose() async {
    await stopListening();
    await _stateController.close();
    await _transcriptionController.close();
    await _partialController.close();
  }
}
