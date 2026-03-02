import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../models/transcription.dart';
import '../utils/atc_vocabulary.dart';

/// WhisperATC model version from jlvdoorn/whisper-large-v3-atco2-asr (Delft University).
/// Used for traceability when debugging transcription issues.
const String whisperAtcModelVersion = 'jlvdoorn/whisper-large-v3-atco2-asr@main';

enum WhisperModelType {
  /// Generic Whisper base model (not recommended for ATC)
  base('ggml-base.bin', 'Base English', 142, WhisperModel.base),

  /// Small model - faster but less accurate
  small('ggml-small.bin', 'Small English', 466, WhisperModel.small),

  /// Medium model - good balance of speed and accuracy
  medium('ggml-medium.bin', 'Medium English', 1500, WhisperModel.medium),

  /// WhisperATC Large v3 - fine-tuned on ATCO2 EU ATC corpus (Delft University)
  /// Achieves significantly lower WER than generic Whisper models on ATC audio.
  /// ~3.1GB download — WiFi recommended.
  /// Note: Uses WhisperModel.largeV2 enum mapping; whisper.cpp auto-detects
  /// the actual architecture from the GGML file header.
  whisperAtcLargeV3(
      'ggml-large-v2.bin', 'WhisperATC Large v3', 3100, WhisperModel.largeV2),

  /// WhisperATC Large v3 quantized (Q5_0) - smaller footprint for
  /// storage-constrained devices. ~1GB download.
  whisperAtcLargeV3Quantized(
      'ggml-large-v1.bin', 'WhisperATC Large v3 (Q5)', 1050, WhisperModel.largeV1);

  final String filename;
  final String displayName;
  final int sizeMB;
  final WhisperModel whisperModel;

  const WhisperModelType(
      this.filename, this.displayName, this.sizeMB, this.whisperModel);

  /// Whether this model requires a custom download via ModelManager
  /// (not available from the standard ggerganov/whisper.cpp host).
  bool get requiresCustomDownload =>
      this == whisperAtcLargeV3 || this == whisperAtcLargeV3Quantized;
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
/// Defaults to WhisperATC large-v3 model (fine-tuned on ATCO2 EU ATC corpus)
/// with automatic fallback to medium model if the ATC model is unavailable.
class WhisperService {
  Whisper? _whisper;
  WhisperModelType _currentModel = WhisperModelType.whisperAtcLargeV3;

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

  /// The preferred model for ATC transcription.
  /// Defaults to WhisperATC Large v3, falling back to medium if unavailable.
  WhisperModelType get _preferredModel => WhisperModelType.whisperAtcLargeV3;

  /// Initialize Whisper with the specified model.
  ///
  /// For ATC models ([WhisperModelType.requiresCustomDownload]), the model
  /// must be pre-downloaded via [ModelManager.downloadModel] before calling
  /// this method. If the model file is not found, initialization falls back
  /// to [WhisperModelType.medium] which auto-downloads from the standard host.
  Future<void> initialize({WhisperModelType? model}) async {
    if (_state == WhisperState.initializing ||
        _state == WhisperState.downloading) {
      return;
    }

    _currentModel = model ?? _preferredModel;
    _setState(WhisperState.initializing);

    try {
      final modelsDir = await getModelsDirectory();

      // For ATC models, verify the file was pre-downloaded via ModelManager
      if (_currentModel.requiresCustomDownload) {
        final modelFile = File('$modelsDir/${_currentModel.filename}');
        if (!await modelFile.exists()) {
          debugPrint(
            'ATC model ${_currentModel.filename} not found in $modelsDir, '
            'falling back to medium model',
          );
          _currentModel = WhisperModelType.medium;
        }
      }

      _whisper = Whisper(
        model: _currentModel.whisperModel,
        modelDir: modelsDir,
        downloadHost:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      );

      _setState(WhisperState.ready);
      debugPrint(
        'Whisper initialized with model: ${_currentModel.displayName} '
        '(version: $whisperAtcModelVersion)',
      );
    } catch (e) {
      debugPrint('Whisper init error: $e');
      // If a non-medium model failed, try falling back to medium
      if (_currentModel != WhisperModelType.medium) {
        debugPrint('Falling back to medium model');
        _currentModel = WhisperModelType.medium;
        _state = WhisperState.uninitialized;
        return initialize(model: WhisperModelType.medium);
      }
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

  /// Get the models directory path, creating it if necessary.
  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/whisper_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
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
