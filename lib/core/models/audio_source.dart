import 'package:equatable/equatable.dart';

enum AudioSourceType {
  microphone,
  bluetooth,
  wired,
}

class AudioSource extends Equatable {
  final String id;
  final String name;
  final AudioSourceType type;
  final bool isConnected;

  const AudioSource({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
  });

  AudioSource copyWith({
    String? id,
    String? name,
    AudioSourceType? type,
    bool? isConnected,
  }) {
    return AudioSource(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [id, name, type, isConnected];
}
