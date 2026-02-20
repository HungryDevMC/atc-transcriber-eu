import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

class Transcription extends Equatable {
  final String id;
  final String text;
  final DateTime timestamp;
  final double confidence;
  final List<String> detectedCallsigns;
  final String? frequency;
  final bool isPartial;

  const Transcription({
    required this.id,
    required this.text,
    required this.timestamp,
    this.confidence = 0.0,
    this.detectedCallsigns = const [],
    this.frequency,
    this.isPartial = false,
  });

  Transcription copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    double? confidence,
    List<String>? detectedCallsigns,
    String? frequency,
    bool? isPartial,
  }) {
    return Transcription(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      detectedCallsigns: detectedCallsigns ?? this.detectedCallsigns,
      frequency: frequency ?? this.frequency,
      isPartial: isPartial ?? this.isPartial,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'detectedCallsigns': detectedCallsigns,
      'frequency': frequency,
      'isPartial': isPartial,
    };
  }

  factory Transcription.fromJson(Map<String, dynamic> json) {
    return Transcription(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedCallsigns: (json['detectedCallsigns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      frequency: json['frequency'] as String?,
      isPartial: json['isPartial'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        timestamp,
        confidence,
        detectedCallsigns,
        frequency,
        isPartial,
      ];
}

/// Hive adapter for Transcription
class TranscriptionAdapter extends TypeAdapter<Transcription> {
  @override
  final int typeId = 0;

  @override
  Transcription read(BinaryReader reader) {
    final map = reader.readMap().cast<String, dynamic>();
    return Transcription(
      id: map['id'] as String,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedCallsigns: (map['detectedCallsigns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      frequency: map['frequency'] as String?,
      isPartial: map['isPartial'] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Transcription obj) {
    writer.writeMap({
      'id': obj.id,
      'text': obj.text,
      'timestamp': obj.timestamp.millisecondsSinceEpoch,
      'confidence': obj.confidence,
      'detectedCallsigns': obj.detectedCallsigns,
      'frequency': obj.frequency,
      'isPartial': obj.isPartial,
    });
  }
}
