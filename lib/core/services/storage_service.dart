import 'package:hive_flutter/hive_flutter.dart';

import '../models/transcription.dart';

/// Local storage service for persisting transcriptions
class StorageService {
  static const String _transcriptionBoxName = 'transcriptions';
  static const String _settingsBoxName = 'settings';

  Box<Transcription>? _transcriptionBox;
  Box? _settingsBox;

  /// Initialize Hive storage
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TranscriptionAdapter());
    }

    _transcriptionBox = await Hive.openBox<Transcription>(_transcriptionBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  // Transcription methods

  /// Save a transcription
  Future<void> saveTranscription(Transcription transcription) async {
    await _transcriptionBox?.put(transcription.id, transcription);
  }

  /// Get all transcriptions
  List<Transcription> getAllTranscriptions() {
    return _transcriptionBox?.values.toList() ?? [];
  }

  /// Get transcriptions by date range
  List<Transcription> getTranscriptionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return getAllTranscriptions()
        .where((t) => t.timestamp.isAfter(start) && t.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get today's transcriptions
  List<Transcription> getTodayTranscriptions() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getTranscriptionsByDateRange(startOfDay, endOfDay);
  }

  /// Delete a transcription
  Future<void> deleteTranscription(String id) async {
    await _transcriptionBox?.delete(id);
  }

  /// Clear all transcriptions
  Future<void> clearAllTranscriptions() async {
    await _transcriptionBox?.clear();
  }

  // Settings methods

  /// Get a setting value
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue) as T?;
  }

  /// Save a setting
  Future<void> saveSetting<T>(String key, T value) async {
    await _settingsBox?.put(key, value);
  }

  /// Get dark mode preference
  bool getDarkMode() {
    return getSetting<bool>('darkMode', defaultValue: true) ?? true;
  }

  /// Set dark mode preference
  Future<void> setDarkMode(bool value) async {
    await saveSetting('darkMode', value);
  }

  /// Get saved frequency
  String? getSavedFrequency() {
    return getSetting<String>('lastFrequency');
  }

  /// Save frequency
  Future<void> saveFrequency(String frequency) async {
    await saveSetting('lastFrequency', frequency);
  }

  /// Clean up
  Future<void> dispose() async {
    await _transcriptionBox?.close();
    await _settingsBox?.close();
  }
}
