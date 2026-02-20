import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../models/transcription.dart';
import '../utils/atc_vocabulary.dart';

enum WhisperModelType {
  /// Generic Whisper model (not recommended for ATC)
  base('ggml-base.en.bin', 'Base English', 142, WhisperModel.base),

  /// Small model - faster but less accurate
  small('ggml-small.en.bin', 'Small English', 466, WhisperModel.small),

  /// Medium model - good balance
  medium('ggml-medium.en.bin', 'Medium English', 1500, WhisperModel.medium),

  /// ATC-tuned model (custom, must be downloaded separately)
  /// Falls back to medium model until custom model support is added
  atcTuned('ggml-atc-medium.en.bin', 'ATC-Tuned Medium', 1500, WhisperModel.medium);

  final String filename;
  final String displayName;
  final int sizeMB;
  final WhisperModel whisperModel;

  const WhisperModelType(this.filename, this.displayName, this.sizeMB, this.whisperModel);
}

enum WhisperState {
  uninitialized,
  downloading,
  initializing,
  ready,
  transcribing,
  error,
}

/// Whisper.cpp based transcription service for accurate ATC transcription.
/// Supports custom fine-tuned models for EU ATC communications.
class WhisperService {
  Whisper? _whisper;
  WhisperModelType _currentModel = WhisperModelType.atcTuned;

  final _stateController = StreamController<WhisperState>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _transcriptionController = StreamController<Transcription>.broadcast();

  WhisperState _state = WhisperState.uninitialized;
  String? _currentFrequency;

  Stream<WhisperState> get stateStream => _stateController.stream;
  Stream<double> get downloadProgressStream => _progressController.stream;
  Stream<Transcription> get transcriptionStream =>
      _transcriptionController.stream;
  WhisperState get state => _state;
  WhisperModelType get currentModel => _currentModel;

  /// Initialize Whisper with the specified model
  Future<void> initialize({WhisperModelType? model}) async {
    if (_state == WhisperState.initializing ||
        _state == WhisperState.downloading) {
      return;
    }

    _currentModel = model ?? WhisperModelType.medium;
    _setState(WhisperState.initializing);

    try {
      // Use the standard WhisperModel enum - models will be downloaded automatically
      _whisper = Whisper(
        model: _currentModel.whisperModel,
        downloadHost: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      );

      _setState(WhisperState.ready);
      debugPrint('Whisper initialized with model: ${_currentModel.displayName}');
    } catch (e) {
      debugPrint('Whisper init error: $e');
      _setState(WhisperState.error);
      rethrow;
    }
  }


  /// Transcribe an audio file
  Future<Transcription?> transcribeFile(String audioPath) async {
    if (_state != WhisperState.ready || _whisper == null) {
      throw Exception('Whisper not ready. Current state: $_state');
    }

    _setState(WhisperState.transcribing);

    try {
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          isTranslate: false,
          isNoTimestamps: false,
          splitOnWord: true,
        ),
      );

      _setState(WhisperState.ready);

      if (result.text.isEmpty) {
        return null;
      }

      final text = _postProcessTranscription(result.text);
      final callsigns = AtcVocabulary.extractCallsigns(text);

      final transcription = Transcription(
        id: const Uuid().v4(),
        text: text,
        timestamp: DateTime.now(),
        confidence: 0.95, // Whisper doesn't provide per-segment confidence
        detectedCallsigns: callsigns,
        frequency: _currentFrequency,
        isPartial: false,
      );

      _transcriptionController.add(transcription);
      return transcription;
    } catch (e) {
      debugPrint('Transcription error: $e');
      _setState(WhisperState.ready);
      rethrow;
    }
  }

  /// Transcribe audio from bytes (e.g., from recording)
  Future<Transcription?> transcribeBytes(
    Uint8List audioBytes, {
    String format = 'wav',
  }) async {
    // Save to temp file and transcribe
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.$format');

    try {
      await tempFile.writeAsBytes(audioBytes);
      return await transcribeFile(tempFile.path);
    } finally {
      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Post-process transcription to improve ATC accuracy
  String _postProcessTranscription(String text) {
    var processed = text.trim();

    // Normalize common ATC terms
    processed = _normalizeAtcTerms(processed);

    // Fix common Whisper mistakes in ATC context
    processed = _fixCommonMistakes(processed);

    return processed;
  }

  /// Normalize ATC terminology
  String _normalizeAtcTerms(String text) {
    var result = text;

    // Normalize flight level mentions
    result = result.replaceAllMapped(
      RegExp(r'flight level (\d)(\d)(\d)', caseSensitive: false),
      (m) => 'flight level ${m.group(1)} ${m.group(2)} ${m.group(3)}',
    );

    // Normalize runway numbers
    result = result.replaceAllMapped(
      RegExp(r'runway (\d)(\d)', caseSensitive: false),
      (m) => 'runway ${m.group(1)} ${m.group(2)}',
    );

    return result;
  }

  /// Fix common Whisper mistakes in ATC context
  String _fixCommonMistakes(String text) {
    var result = text;

    // Common misheard words in ATC
    final corrections = {
      'niner': 'niner', // Keep as-is (correct)
      'tree': 'three', // Sometimes Whisper writes "tree"
      'fife': 'five', // ATC pronunciation
      'to altitude': 'two altitude',
      'for altitude': 'four altitude',
      'won': 'one',
    };

    for (final entry in corrections.entries) {
      result = result.replaceAll(
        RegExp(r'\b' + entry.key + r'\b', caseSensitive: false),
        entry.value,
      );
    }

    return result;
  }

  /// Set the current frequency being monitored
  void setFrequency(String? frequency) {
    _currentFrequency = frequency;
  }

  /// Get the models directory path
  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/whisper_models';
  }

  /// List all supported models (whisper_flutter_new downloads them automatically)
  List<WhisperModelType> getSupportedModels() {
    return WhisperModelType.values.toList();
  }

  void _setState(WhisperState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _stateController.close();
    await _progressController.close();
    await _transcriptionController.close();
  }
}
