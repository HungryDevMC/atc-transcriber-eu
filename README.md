# ATC Transcriber EU

Offline ATC (Air Traffic Control) communication transcription app for EU/Belgium aviation.

## Why Whisper.cpp?

Generic speech recognition achieves **~75% word error rate** on ATC audio. This app uses [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) with ATC-fine-tuned models to achieve **<7% WER**.

| Model | WER on ATC | Status |
|-------|-----------|--------|
| Generic (Google/Apple) | ~75% | Unusable |
| Whisper ATC-tuned | ~6.5% | Supported |
| Custom EU Model | <3% | Planned |

## Features

- **Whisper.cpp Integration**: Accurate offline transcription using ATC-fine-tuned Whisper models
- **Bluetooth Audio Support**: Connect to custom ATC radio audio interface hardware
- **Callsign Detection**: Automatically highlights aircraft callsigns in transcriptions
- **Belgian Aviation Focus**: Pre-configured with Belgian airports, frequencies, and common EU airline callsigns
- **Dark Mode**: Cockpit-friendly dark theme for better visibility
- **Transcription History**: Browse and export past transcriptions
- **Custom Model Support**: Use your own fine-tuned GGML models

## Architecture

```
lib/
├── core/
│   ├── models/          # Transcription, AudioSource
│   ├── services/
│   │   ├── whisper_service.dart    # Whisper.cpp integration
│   │   ├── model_manager.dart      # Model download/management
│   │   ├── transcription_service.dart  # Fallback native STT
│   │   └── bluetooth_service.dart  # Hardware connection
│   ├── providers/       # Riverpod state management
│   └── utils/           # ATC vocabulary, helpers
├── features/
│   ├── transcription/   # Main transcription screen
│   ├── bluetooth/       # Bluetooth device connection
│   ├── history/         # Transcription history
│   └── settings/        # App settings
└── shared/
    ├── widgets/         # TranscriptionCard with callsign highlighting
    └── theme/           # Dark/light themes
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

3. Download a Whisper model (see below)

4. Run the app:
   ```bash
   flutter run
   ```

## Whisper Model Setup

### Option 1: Use Pre-trained ATC Model (Recommended)

Download the ATC-fine-tuned model from HuggingFace:

```bash
# Download and convert the model
pip install transformers
python scripts/convert_model.py jacktol/whisper-medium.en-fine-tuned-for-ATC
```

Or download pre-converted GGML:
- [whisper-medium.en-fine-tuned-for-ATC (GGML)](https://huggingface.co/jacktol/whisper-medium.en-fine-tuned-for-ATC-faster-whisper)

Place in: `<app_documents>/whisper_models/ggml-atc-medium.en.bin`

### Option 2: Use Generic Whisper (Lower Accuracy)

Download from [whisper.cpp models](https://huggingface.co/ggerganov/whisper.cpp):
- `ggml-base.en.bin` - 142MB, fast
- `ggml-small.en.bin` - 466MB, balanced
- `ggml-medium.en.bin` - 1.5GB, accurate

### Option 3: Build Custom EU Model

See [docs/EU_ATC_MODEL_TRAINING.md](docs/EU_ATC_MODEL_TRAINING.md) for our strategy to build a custom model achieving <3% WER on EU/Belgian ATC.

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

This app is designed to receive audio from a custom hardware interface that connects to your aircraft radio:

1. Hardware taps into radio audio output
2. Streams audio to phone via Bluetooth audio profile
3. App records and transcribes in segments
4. Whisper.cpp processes each segment offline

## Test Results

Real ATC audio transcription comparison (5 samples from ATCO2 dataset):

```
Ground Truth: "climb flight level one six zero emirates one four zero"
Generic:      "I'm on level 160, MH 140" (90% WER)
ATC-tuned:    "climb flight level one six zero emirates one four zero" (0% WER)

Ground Truth: "singapoore three two five request flight level three three zero standby"
Generic:      "Singapore 325, request my lever, 330. Bye bye" (91% WER)
ATC-tuned:    "singapoore three two five request flight level three three zero standby" (0% WER)
```

## Roadmap

- [x] Whisper.cpp integration
- [x] ATC-tuned model support
- [ ] Audio recording from Bluetooth
- [ ] Real-time streaming transcription
- [ ] Custom EU model training
- [ ] Callsign database with live flight data

## License

MIT License

## Disclaimer

This app is intended as a supplementary tool for pilots. Always rely on primary radio communication and follow proper ATC procedures. The transcriptions may contain errors and should not be used as the sole source of ATC instructions.
