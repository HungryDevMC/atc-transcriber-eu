import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'whisper_service.dart';

/// Model download information
class ModelDownloadInfo {
  final WhisperModelType type;
  final String url;
  final String sha256;

  const ModelDownloadInfo({
    required this.type,
    required this.url,
    required this.sha256,
  });
}

/// Manages Whisper model downloads and storage
class ModelManager {
  final _progressController = StreamController<ModelDownloadProgress>.broadcast();

  Stream<ModelDownloadProgress> get progressStream => _progressController.stream;

  /// Available models for download.
  ///
  /// Standard models (base, small, medium) are hosted by ggerganov/whisper.cpp.
  /// WhisperATC models are fine-tuned on the ATCO2 EU ATC corpus by
  /// Delft University (jlvdoorn) and must be converted to GGML format using
  /// whisper.cpp's convert-hf-to-ggml.py script before hosting.
  ///
  /// TODO: Populate SHA256 checksums for download integrity verification.
  static const Map<WhisperModelType, ModelDownloadInfo> availableModels = {
    WhisperModelType.base: ModelDownloadInfo(
      type: WhisperModelType.base,
      url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      sha256: '',
    ),
    WhisperModelType.small: ModelDownloadInfo(
      type: WhisperModelType.small,
      url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      sha256: '',
    ),
    WhisperModelType.medium: ModelDownloadInfo(
      type: WhisperModelType.medium,
      url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin',
      sha256: '',
    ),
    // WhisperATC large-v3: GGML-converted model fine-tuned on ATCO2 corpus.
    // Source: https://huggingface.co/jlvdoorn/whisper-large-v3-atco2-asr
    // The GGML binary must be converted and hosted before this URL is valid.
    // Conversion: python convert-hf-to-ggml.py jlvdoorn/whisper-large-v3-atco2-asr
    WhisperModelType.whisperAtcLargeV3: ModelDownloadInfo(
      type: WhisperModelType.whisperAtcLargeV3,
      url: 'https://huggingface.co/jlvdoorn/whisper-large-v3-atco2-asr-ggml/resolve/main/ggml-large-v2.bin',
      sha256: '',
    ),
    // WhisperATC large-v3 quantized (Q5_0) for storage-constrained devices.
    WhisperModelType.whisperAtcLargeV3Quantized: ModelDownloadInfo(
      type: WhisperModelType.whisperAtcLargeV3Quantized,
      url: 'https://huggingface.co/jlvdoorn/whisper-large-v3-atco2-asr-ggml/resolve/main/ggml-large-v1.bin',
      sha256: '',
    ),
  };

  /// Get the models directory
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/whisper_models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    return modelsDir;
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(WhisperModelType model) async {
    final modelsDir = await getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.filename}');
    return modelFile.exists();
  }

  /// Get model file size if downloaded
  Future<int?> getModelSize(WhisperModelType model) async {
    final modelsDir = await getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.filename}');

    if (await modelFile.exists()) {
      return modelFile.length();
    }
    return null;
  }

  /// Download a model
  Future<void> downloadModel(
    WhisperModelType model, {
    void Function(double progress)? onProgress,
  }) async {
    final info = availableModels[model];
    if (info == null) {
      throw Exception('Model ${model.name} not available for download');
    }

    final modelsDir = await getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.filename}');
    final tempFile = File('${modelsDir.path}/${model.filename}.tmp');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(info.url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      final sink = tempFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          onProgress?.call(progress);
          _progressController.add(ModelDownloadProgress(
            model: model,
            progress: progress,
            downloadedBytes: receivedBytes,
            totalBytes: totalBytes,
          ));
        }
      }

      await sink.close();

      // Verify download (optional: check SHA256)
      // ...

      // Move temp file to final location
      await tempFile.rename(modelFile.path);

      debugPrint('Model ${model.filename} downloaded successfully');
    } catch (e) {
      // Clean up temp file on error
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Delete a downloaded model
  Future<void> deleteModel(WhisperModelType model) async {
    final modelsDir = await getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.filename}');

    if (await modelFile.exists()) {
      await modelFile.delete();
    }
  }

  /// Import a model from a local file path
  Future<void> importModel(WhisperModelType model, String sourcePath) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw Exception('Source file not found: $sourcePath');
    }

    final modelsDir = await getModelsDirectory();
    final destFile = File('${modelsDir.path}/${model.filename}');

    await sourceFile.copy(destFile.path);
    debugPrint('Model imported: ${model.filename}');
  }

  /// Get disk space used by models
  Future<int> getTotalModelsSize() async {
    final modelsDir = await getModelsDirectory();
    var totalSize = 0;

    await for (final entity in modelsDir.list()) {
      if (entity is File && entity.path.endsWith('.bin')) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  void dispose() {
    _progressController.close();
  }
}

/// Progress information for model download
class ModelDownloadProgress {
  final WhisperModelType model;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;

  const ModelDownloadProgress({
    required this.model,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get downloadedMB => '${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB';

  String get totalMB => '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
