# ATC Transcriber EU - Training & Model Documentation

## Quick Summary

**Current WER: 19.10%** → **Target WER: <5%**

The key to near-zero error rate is **constrained decoding** - ATC follows strict ICAO phraseology patterns. Instead of free-form transcription, we validate output against known ATC grammar rules.

---

## Current Status

### Training Results
- **Final Word Error Rate (WER): 19.10%**
- **Training Data**: ATCO2 corpus (EU ATC communications)
- **Hardware Used**: NVIDIA GTX 1080 Ti with CUDA 11.8
- **Model Size**: 175MB (quantized GGML Q5_0)
- **Base Model**: Whisper Small
- **Output Location**: `./training/models/ggml-atc-whisper-q5_0.bin`

### App Integration Status
- ✅ Custom model support added to WhisperService
- ✅ Settings UI for model selection and import
- ✅ File picker for importing custom models
- ⚠️ **Issue**: Base model not auto-downloading (PathNotFoundException)

---

## Current Issues

### 1. Model Download Failure
**Error**: `PathNotFoundException: /data/user/0/com.hungrydev.atc_transcriber/app_flutter/whisper_models/ggml-base.bin`

**Root Cause**: The `whisper_flutter_new` package attempts to download models from Hugging Face on first use, but:
- Network restrictions may block the download
- The download host might be unreachable
- App may lack proper storage permissions for the models directory

**Solution**: Bundle the model with the app assets instead of relying on runtime download.

### 2. Word Error Rate Analysis (19.10%)

**Why is WER still at ~19%?**

1. **Limited Training Data**
   - ATCO2 corpus, while specialized, may not cover all EU ATC variations
   - Belgian/Dutch/French accented English needs more representation

2. **Acoustic Challenges**
   - Radio static and interference patterns
   - Squelch sounds at transmission start/end
   - Overlapping transmissions
   - Cockpit background noise (engine, wind)

3. **Vocabulary Gaps**
   - Whisper's general vocabulary doesn't include all ATC terms
   - Uncommon waypoint names, SIDs/STARs not in training data
   - Non-standard phraseology variations

4. **Numerical Confusion**
   - ATC uses specialized number pronunciation (niner, tree, fife)
   - Frequency numbers often misheard (118.25 vs 118.52)
   - Flight levels and altitudes (FL350 vs altitude 35000)

---

## Path to Near-Flawless Transcription

### Strategy 1: Enhanced Post-Processing (Immediate)

ATC communications follow strict ICAO phraseology patterns. We can leverage this:

```
[CALLSIGN] + [INSTRUCTION/READBACK] + [DETAILS] + [FREQUENCY/SQUAWK]
```

#### Pattern Templates
```
# Clearances
"{CALLSIGN}, cleared to {DESTINATION}, {SID} departure, runway {RWY}, squawk {CODE}"
"{CALLSIGN}, climb flight level {FL}"
"{CALLSIGN}, descend altitude {ALT} feet"
"{CALLSIGN}, turn {LEFT/RIGHT} heading {HDG}"

# Readbacks (Pilot)
"{CALLSIGN}, cleared {SID}, runway {RWY}, squawk {CODE}"
"{CALLSIGN}, climbing flight level {FL}"
"{CALLSIGN}, descending {ALT}"

# Handoffs
"{CALLSIGN}, contact {FACILITY} on {FREQ}"
"{CALLSIGN}, {FREQ}, {CALLSIGN}"  # Short readback
```

#### Implementation: Grammar-Constrained Decoding
Instead of free-form transcription, constrain output to valid ATC patterns:

```python
# Pseudo-code for constrained decoding
valid_commands = [
    "cleared", "climb", "descend", "turn", "maintain",
    "contact", "squawk", "taxi", "hold short", "line up",
    "cleared for takeoff", "cleared to land", "go around"
]

def constrain_output(raw_text):
    # Match against ATC grammar patterns
    # Correct numbers to ATC format
    # Validate callsign format
    pass
```

### Strategy 2: Custom Vocabulary Injection

Create a specialized vocabulary file for decoding:

```
# Belgian Airports
EBBR Brussels
EBAW Antwerp
EBOS Ostend
EBLG Liège
EBCI Charleroi

# Common Waypoints
HELEN DENUT SOPOK MAKLU ROUSY

# Standard Terms
SQUAWK FL FLIGHT LEVEL FEET KNOTS
HEADING RUNWAY CLEARED CONTACT
```

### Strategy 3: Two-Stage Transcription

1. **Stage 1**: Raw Whisper transcription
2. **Stage 2**: ATC-specific correction model

```
Raw: "speedbird one two three descend altitude to zero zero"
→ Corrected: "Speedbird 123, descend altitude 2000"

Raw: "oscar alpha bravo charlie cleared island one whiskey"
→ Corrected: "OO-ABC, cleared EBBR1W departure"
```

### Strategy 4: Fine-Tuning Improvements

For next training iteration:

1. **Data Augmentation**
   - Add synthetic radio effects (squelch, static)
   - Speed variations (fast/slow speakers)
   - Accent variations

2. **More Training Data**
   - LiveATC.net recordings (Belgium frequencies)
   - EUROCONTROL training materials
   - Simulated ATC recordings

3. **Curriculum Learning**
   - Start with clean studio recordings
   - Gradually add noise and radio effects
   - Fine-tune on real-world recordings last

### Strategy 5: Confidence-Based Verification

```dart
class TranscriptionResult {
  String text;
  double confidence;
  List<String> alternatives;
  bool requiresVerification;

  bool get isReliable => confidence > 0.85 && matchesAtcPattern;
}
```

For low-confidence transcriptions:
- Highlight uncertain segments
- Suggest alternatives
- Allow user correction (feeds back to training)

---

## Expected WER Improvements

| Strategy | Expected WER Reduction | Effort |
|----------|----------------------|--------|
| ATC Grammar Constraints | -3-5% | Medium |
| Custom Vocabulary | -2-3% | Low |
| Two-Stage Correction | -5-8% | High |
| More Training Data | -3-5% | High |
| Data Augmentation | -2-4% | Medium |
| **Combined** | **~10-15%** | High |

**Target WER: 5-9%** (Professional ATC systems achieve ~5%)

---

## Immediate Fixes Required

### Fix 1: Bundle Base Model with App

Modify `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/ggml-base.bin
```

### Fix 2: Ensure Model Directory Exists

```dart
Future<void> ensureModelDirectory() async {
  final dir = Directory(await getModelsDirectory());
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
```

### Fix 3: Copy Model from Assets on First Run

```dart
Future<void> initializeModel() async {
  final modelPath = '${await getModelsDirectory()}/ggml-base.bin';
  final modelFile = File(modelPath);

  if (!await modelFile.exists()) {
    // Copy from assets
    final data = await rootBundle.load('assets/models/ggml-base.bin');
    await modelFile.writeAsBytes(data.buffer.asUint8List());
  }
}
```

---

## ATC Communication Patterns Reference

### Standard Phraseology (ICAO)

| Instruction | Format | Example |
|-------------|--------|---------|
| Altitude | "climb/descend FL/altitude X" | "climb flight level 350" |
| Heading | "turn left/right heading X" | "turn right heading 270" |
| Speed | "reduce/increase speed to X" | "reduce speed to 250 knots" |
| Frequency | "contact X on Y" | "contact Brussels on 126.9" |
| Squawk | "squawk X" | "squawk 4521" |

### Number Pronunciation
- 0: zero
- 1: one
- 2: two
- 3: tree (three)
- 4: four (fower)
- 5: fife (five)
- 6: six
- 7: seven
- 8: eight
- 9: niner (nine)

### Belgian Callsign Prefixes
- OO-XXX: Belgian registered aircraft
- BAW: British Airways
- DLH: Lufthansa
- AFR: Air France
- BEL: Brussels Airlines
- TUI: TUI fly Belgium

---

## Next Steps

1. [ ] Fix model loading issue (bundle with assets)
2. [ ] Implement ATC grammar post-processor
3. [ ] Add confidence scoring to transcriptions
4. [ ] Create feedback mechanism for corrections
5. [ ] Collect more Belgian ATC recordings for fine-tuning
6. [ ] Test with real-world radio scanner input

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/core/services/whisper_service.dart` | Custom model support, separate model directories |
| `lib/core/providers/providers.dart` | Added customModelAvailableProvider |
| `lib/features/settings/settings_screen.dart` | Model selection UI, import functionality |
| `pubspec.yaml` | Added file_picker dependency |

---

## How to Achieve Near-Zero Error Rate (<5% WER)

### The Key Insight: ATC is NOT Free-Form Speech

ATC communication follows **strict ICAO phraseology**. This is the secret weapon:

```
STANDARD ATC PATTERN:
[CALLSIGN] + [INSTRUCTION] + [PARAMETERS] + [OPTIONAL: FREQUENCY/SQUAWK]
```

### Solution: Constrained Decoding + Post-Processing

#### Step 1: Build an ATC Grammar
```
INSTRUCTION := CLEARANCE | ALTITUDE | HEADING | SPEED | FREQUENCY | SQUAWK
CLEARANCE   := "cleared" (DESTINATION | SID | APPROACH | "to land" | "for takeoff")
ALTITUDE    := ("climb" | "descend") ("flight level" FL | "altitude" ALT "feet")
HEADING     := "turn" ("left" | "right") "heading" HDG
FREQUENCY   := "contact" FACILITY "on" FREQ
FL          := DIGIT DIGIT DIGIT
ALT         := DIGIT+ ("thousand" | "hundred")?
FREQ        := DIGIT DIGIT DIGIT "." DIGIT+
CALLSIGN    := (AIRLINE_CODE DIGITS) | (REGISTRATION)
```

#### Step 2: Validate & Correct Output
```python
def post_process_atc(raw_text):
    # 1. Extract potential callsign (always first)
    callsign = extract_callsign(raw_text)

    # 2. Match against known instruction patterns
    instruction = match_instruction_pattern(raw_text)

    # 3. Validate numbers (frequencies, altitudes, headings)
    validated = validate_atc_numbers(instruction)

    # 4. Check against known waypoints/airports
    final = validate_locations(validated)

    return f"{callsign}, {final}"
```

#### Step 3: Use Beam Search with Grammar Constraints
Instead of greedy decoding, use beam search that scores candidates against ATC grammar validity.

### Implementation Priorities

| Priority | Action | Impact | Effort |
|----------|--------|--------|--------|
| 1 | **Number normalization** (niner→9, tree→3) | -3% WER | Low |
| 2 | **Callsign extraction** (OO-ABC format) | -2% WER | Low |
| 3 | **Instruction pattern matching** | -5% WER | Medium |
| 4 | **Belgian waypoint/airport dictionary** | -2% WER | Low |
| 5 | **Frequency validation** (118.xxx format) | -2% WER | Low |
| 6 | **Fine-tune on more Belgian ATC data** | -3% WER | High |

### Example Corrections

| Raw Whisper Output | Corrected Output |
|--------------------|------------------|
| "speedbird one two tree descend altitude to zero zero" | "Speedbird 123, descend altitude 2000" |
| "oscar oscar alpha bravo charlie contact brussels one two six niner" | "OO-ABC, contact Brussels 126.9" |
| "climb flight level tree fife zero" | "Climb flight level 350" |
| "squawk for five to one" | "Squawk 4521" |

### Belgian-Specific Enhancements

1. **Known Frequencies Dictionary**
   - Brussels Approach: 126.900, 118.250
   - Antwerp: 118.875
   - Charleroi: 119.550

2. **Belgian Callsign Patterns**
   - OO-XXX (Belgian registration)
   - BEL/SN (Brussels Airlines)
   - TUI (TUI fly Belgium)

3. **Common Waypoints**
   - HELEN, DENUT, SOPOK, MAKLU, ROUSY, BRUNO

### Realistic Target

With the above improvements:
- **Current**: 19.10% WER
- **After post-processing**: ~10% WER
- **After more training data**: ~7% WER
- **With constrained decoding**: **<5% WER**

Professional ATC systems achieve 3-5% WER using similar techniques.

---

## Current Session Findings

### Issue Encountered
- **Error**: `PathNotFoundException` - Whisper model not downloading
- **Location**: `/data/user/0/com.hungrydev.atc_transcriber/app_flutter/whisper_models/ggml-base.bin`
- **Cause**: whisper_flutter_new auto-download may be blocked by network/firewall

### Solution
Import your trained model manually via Settings → Import Model

### Model Location
Your trained model: `./training/models/ggml-atc-whisper-q5_0.bin` (175MB)
Pushed to phone: `/sdcard/Download/ggml-atc-whisper-q5_0.bin`

---

*Document created: 2025-02-20*
*Author: Claude Code (GESP ATC Transcriber Project)*
