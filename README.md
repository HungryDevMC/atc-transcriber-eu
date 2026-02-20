# ATC Transcriber EU

Offline ATC (Air Traffic Control) communication transcription app for EU/Belgium aviation.

## Features

- **Offline Speech Recognition**: Uses Vosk for on-device transcription - works without internet connection (essential for in-flight use)
- **Bluetooth Audio Support**: Connect to custom ATC radio audio interface hardware
- **Callsign Detection**: Automatically highlights aircraft callsigns in transcriptions
- **Belgian Aviation Focus**: Pre-configured with Belgian airports, frequencies, and common EU airline callsigns
- **Dark Mode**: Cockpit-friendly dark theme for better visibility
- **Transcription History**: Browse and export past transcriptions

## Architecture

```
lib/
├── core/
│   ├── models/          # Data models (Transcription, AudioSource)
│   ├── services/        # Business logic (TranscriptionService, BluetoothService)
│   ├── providers/       # Riverpod state management
│   └── utils/           # ATC vocabulary, helpers
├── features/
│   ├── transcription/   # Main transcription screen
│   ├── bluetooth/       # Bluetooth device connection
│   ├── history/         # Transcription history
│   └── settings/        # App settings
└── shared/
    ├── widgets/         # Reusable UI components
    └── theme/           # App theming
```

## Setup

### Prerequisites

- Flutter SDK 3.10+
- Android Studio / Xcode for device deployment

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/HungryDevMC/atc-transcriber-eu.git
   cd atc-transcriber-eu
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate Hive adapters:
   ```bash
   dart run build_runner build
   ```

4. Download a Vosk speech model:
   - Get a model from [Vosk Models](https://alphacephei.com/vosk/models)
   - Recommended: `vosk-model-small-en-us-0.15` (~40MB)
   - Extract to device's app documents folder

5. Run the app:
   ```bash
   flutter run
   ```

## Speech Model Setup

The app uses [Vosk](https://alphacephei.com/vosk/) for offline speech recognition. You need to download a model:

1. Download from https://alphacephei.com/vosk/models
2. Recommended models:
   - `vosk-model-small-en-us` - Small, fast (~40MB)
   - `vosk-model-en-us` - Large, accurate (~1.8GB)
3. Extract and place in the app's documents directory

## Belgian Aviation Reference

### Airports (ICAO)
- EBBR - Brussels Airport
- EBAW - Antwerp Airport
- EBCI - Charleroi Airport
- EBLG - Liege Airport
- EBOS - Ostend-Bruges Airport

### Common Frequencies
- 118.250 - Brussels Approach
- 120.775 - Brussels Departure
- 126.900 - Brussels Tower
- 129.100 - Belgian Radar (North)
- 131.100 - Eurocontrol Maastricht

## Hardware Integration

This app is designed to receive audio from a custom hardware interface that connects to your aircraft radio. The hardware should:

1. Tap into the radio audio output
2. Stream audio to the phone via Bluetooth audio profile
3. The app will transcribe received transmissions in real-time

## License

MIT License

## Disclaimer

This app is intended as a supplementary tool for pilots. Always rely on primary radio communication and follow proper ATC procedures. The transcriptions may contain errors and should not be used as the sole source of ATC instructions.
