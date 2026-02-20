# Building a Custom EU ATC Speech Recognition Model

## Goal: Achieve <3% Word Error Rate for EU/Belgium ATC

This document outlines the strategy for building a highly accurate speech recognition model specifically optimized for European Air Traffic Control communications, with a focus on Belgian airspace.

## Current State of the Art

| Model | WER on ATC | Notes |
|-------|-----------|-------|
| Generic Whisper | ~75% | Unusable for ATC |
| jacktol/whisper-large-v3-finetuned-for-ATC | 6.5% | General ATC |
| jlvdoorn/whisper-large-v3-atco2-asr | ~5% | SOTA on ATCO2 |
| **Our Target** | **<3%** | EU/Belgium specific |

## Why a Custom Model?

Existing models are trained on mixed datasets. A EU-specific model can achieve lower error rates by:

1. **Accent specialization** - Focus on European English accents (Belgian, Dutch, German, French controllers)
2. **Vocabulary focus** - Belgian waypoints, airports, airways, SIDs/STARs
3. **Frequency-specific training** - Brussels FIR phraseology patterns
4. **Noise profile matching** - Real EU radio characteristics

---

## Phase 1: Data Collection Strategy

### 1.1 Primary Data Sources

#### LiveATC Recordings (Largest Source)
```
Target airports:
- EBBR (Brussels) - Primary
- EBAW (Antwerp)
- EBCI (Charleroi)
- EBLG (Liege)
- EHAM (Amsterdam) - High traffic reference
- EDDL (Düsseldorf) - Nearby major
- LFPG (Paris CDG) - High traffic reference
```

**Collection approach:**
```python
# Automated collection script outline
airports = ['EBBR', 'EBAW', 'EBCI', 'EBLG']
frequencies = {
    'EBBR': ['EBBR_APP', 'EBBR_TWR', 'EBBR_GND'],
    # ... etc
}

# Collect 24/7 for 3-6 months
# Target: 500+ hours of raw audio per major airport
```

#### ATCO2 Corpus (Existing Labeled Data)
- 4 hours manually transcribed
- Use as validation/test set
- Don't train on this to ensure unbiased evaluation

#### UWB-ATCC Corpus
- 20 hours of EU ATC
- Czech/English communications
- Good for accent diversity

#### ATCOSIM Corpus
- 10 hours simulation data
- Non-native speakers
- Good for accent training

### 1.2 Belgian-Specific Data Collection

**Target: 200+ hours of labeled Belgian ATC**

| Source | Hours | Quality | Notes |
|--------|-------|---------|-------|
| EBBR Approach | 100 | High | Primary target |
| EBBR Tower | 50 | High | Ground ops |
| Belgian Radar | 30 | Medium | En-route |
| Other Belgian | 20 | Medium | Regional |

### 1.3 Synthetic Data Augmentation

Generate synthetic ATC communications to increase training data:

```python
# Template-based generation
templates = [
    "{callsign} climb flight level {fl}",
    "{callsign} descend to {altitude} feet",
    "{callsign} turn {direction} heading {heading}",
    "{callsign} contact {facility} on {frequency}",
    "{callsign} cleared {approach} approach runway {runway}",
]

# Belgian-specific elements
belgian_callsigns = generate_realistic_callsigns('EBBR')
belgian_waypoints = ['HELEN', 'DENUT', 'CIV', 'SOPOK', 'ELSIK', ...]
belgian_frequencies = ['118.250', '120.775', '126.900', ...]
```

Use text-to-speech with various accents:
- Belgian-accented English
- German-accented English
- French-accented English
- Dutch-accented English

---

## Phase 2: Data Labeling Pipeline

### 2.1 Semi-Automated Transcription

```
Raw Audio → VAD → Segmentation → Initial Transcription → Human Review → Final Label
              ↓
         (Silero VAD)      (Existing ATC Whisper)        (Crowd/Expert)
```

### 2.2 Labeling Schema

```json
{
  "id": "ebbr_app_20240315_1423_001",
  "audio_path": "audio/ebbr_app_20240315_1423_001.wav",
  "duration_seconds": 4.2,
  "transcription": "brussels approach beeline four seven two descending flight level one two zero",
  "normalized": "BRUSSELS APPROACH BEL472 DESCENDING FL120",
  "metadata": {
    "airport": "EBBR",
    "frequency": "118.250",
    "facility": "approach",
    "speaker": "pilot",
    "callsign": "BEL472",
    "instruction_type": "altitude",
    "accent": "belgian",
    "noise_level": "low",
    "audio_quality": "good"
  },
  "entities": [
    {"type": "callsign", "value": "BEL472", "start": 18, "end": 24},
    {"type": "altitude", "value": "FL120", "start": 36, "end": 41}
  ]
}
```

### 2.3 Quality Control

- **Double-blind labeling** for 20% of samples
- **Expert review** for ambiguous cases
- **Inter-annotator agreement** threshold: >95%

---

## Phase 3: Model Architecture

### 3.1 Base Model Selection

| Model | Parameters | VRAM | Speed | Accuracy |
|-------|-----------|------|-------|----------|
| Whisper Large v3 | 1.5B | 10GB | Slow | Highest |
| Whisper Medium | 769M | 5GB | Medium | High |
| Whisper Small | 244M | 2GB | Fast | Good |

**Recommendation:** Start with Whisper Medium for mobile deployment, use Large v3 for server-side.

### 3.2 Fine-Tuning Strategy

```python
from transformers import WhisperForConditionalGeneration, WhisperProcessor
from peft import LoraConfig, get_peft_model

# Load base model
model = WhisperForConditionalGeneration.from_pretrained("openai/whisper-medium.en")
processor = WhisperProcessor.from_pretrained("openai/whisper-medium.en")

# LoRA configuration for efficient fine-tuning
lora_config = LoraConfig(
    r=32,
    lora_alpha=64,
    target_modules=["q_proj", "v_proj", "k_proj", "out_proj"],
    lora_dropout=0.05,
    bias="none",
)

model = get_peft_model(model, lora_config)

# Training configuration
training_args = TrainingArguments(
    output_dir="./whisper-atc-eu",
    per_device_train_batch_size=16,
    gradient_accumulation_steps=2,
    learning_rate=1e-4,
    warmup_steps=500,
    max_steps=10000,
    fp16=True,
    evaluation_strategy="steps",
    eval_steps=500,
    save_steps=1000,
    logging_steps=100,
)
```

### 3.3 Multi-Stage Training

**Stage 1: General ATC (10K steps)**
- Train on combined ATCO2 + UWB-ATCC + ATCOSIM
- Objective: Learn ATC domain vocabulary

**Stage 2: EU-Specific (5K steps)**
- Train on EU airport recordings
- Lower learning rate (5e-5)
- Objective: Adapt to EU accents and phraseology

**Stage 3: Belgian Fine-Tuning (3K steps)**
- Train on Belgian-specific data only
- Lowest learning rate (1e-5)
- Objective: Maximize Belgian accuracy

---

## Phase 4: Achieving <3% WER

### 4.1 Error Analysis Categories

Typical errors in ATC transcription:

| Error Type | Example | Solution |
|------------|---------|----------|
| Callsign confusion | "BEL472" → "BELL 472" | Callsign vocabulary constraint |
| Number errors | "flight level one two zero" → "flight level 120" | Number normalization |
| Waypoint misspelling | "HELEN" → "ELLEN" | Waypoint vocabulary |
| Accent issues | Belgian pronunciation | Accent-specific training |
| Radio noise | Static causing hallucinations | Noise augmentation |

### 4.2 Post-Processing Pipeline

```python
class ATCPostProcessor:
    def __init__(self):
        self.callsign_patterns = load_callsign_patterns()
        self.waypoints = load_eu_waypoints()
        self.frequencies = load_frequencies()

    def process(self, transcription: str) -> str:
        result = transcription

        # 1. Normalize numbers
        result = self.normalize_numbers(result)

        # 2. Fix callsigns using fuzzy matching
        result = self.fix_callsigns(result)

        # 3. Correct waypoint names
        result = self.correct_waypoints(result)

        # 4. Apply grammar constraints
        result = self.apply_atc_grammar(result)

        return result

    def fix_callsigns(self, text: str) -> str:
        # Use edit distance to find closest valid callsign
        for potential in extract_potential_callsigns(text):
            closest = find_closest_callsign(potential, self.callsign_patterns)
            if edit_distance(potential, closest) <= 2:
                text = text.replace(potential, closest)
        return text
```

### 4.3 Language Model Rescoring

Use a domain-specific language model to rescore n-best hypotheses:

```python
# Train a small LM on ATC transcripts
from transformers import GPT2LMHeadModel, GPT2Tokenizer

# Fine-tune GPT-2 small on ATC text
# Use for rescoring Whisper hypotheses

def rescore_hypotheses(hypotheses: List[str], lm: GPT2LMHeadModel) -> str:
    scores = []
    for hyp in hypotheses:
        # Combine acoustic score with LM score
        acoustic_score = hyp.confidence
        lm_score = compute_lm_score(hyp.text, lm)
        combined = 0.7 * acoustic_score + 0.3 * lm_score
        scores.append((hyp.text, combined))

    return max(scores, key=lambda x: x[1])[0]
```

### 4.4 Constrained Decoding

Force decoder to follow ATC grammar patterns:

```python
# Define ATC grammar constraints
ATC_GRAMMAR = {
    "instruction": [
        "climb", "descend", "turn", "maintain", "contact",
        "cleared", "hold", "proceed", "report", "squawk"
    ],
    "altitude_prefix": ["flight level", "altitude", "feet"],
    "direction": ["left", "right"],
    # ... etc
}

# During decoding, constrain output to valid ATC patterns
```

---

## Phase 5: Model Optimization for Mobile

### 5.1 Quantization

```bash
# Convert to GGML format with quantization
python convert-hf-to-gguf.py \
    --model whisper-atc-eu \
    --outfile ggml-atc-eu-medium.bin

# Quantize to reduce size
./quantize ggml-atc-eu-medium.bin ggml-atc-eu-medium-q5_0.bin q5_0
```

| Quantization | Size | Speed | Accuracy Loss |
|--------------|------|-------|---------------|
| f16 | 1.5GB | Baseline | 0% |
| q8_0 | 800MB | +20% | <0.5% |
| q5_0 | 500MB | +40% | <1% |
| q4_0 | 400MB | +50% | ~2% |

**Recommendation:** Use q5_0 for mobile - good balance of size and accuracy.

### 5.2 Distillation (Optional)

Train a smaller student model from the large fine-tuned model:

```python
# Distill Large → Medium → Small
# Can achieve near-large accuracy with small model speed
```

---

## Phase 6: Continuous Improvement

### 6.1 User Feedback Loop

```
Transcription → User Correction → Feedback Database → Periodic Retraining
```

### 6.2 Active Learning

```python
def select_samples_for_labeling(unlabeled_pool):
    # Select samples where model is least confident
    uncertain = []
    for sample in unlabeled_pool:
        result = model.transcribe_with_confidence(sample)
        if result.confidence < 0.8:
            uncertain.append(sample)

    # Also select samples with novel patterns
    novel = detect_novel_patterns(unlabeled_pool)

    return uncertain + novel
```

### 6.3 A/B Testing

- Deploy multiple model versions
- Compare WER on real user transcriptions
- Promote best performing model

---

## Expected Results

| Metric | Generic Whisper | Current SOTA | Our Target |
|--------|-----------------|--------------|------------|
| Overall WER | 75% | 6.5% | **<3%** |
| Callsign WER | 90% | 10% | **<2%** |
| Instruction WER | 60% | 5% | **<3%** |
| Belgian-specific | N/A | ~8% | **<2%** |

---

## Resource Requirements

### Data Collection
- 6-12 months collection time
- Cloud storage: ~500GB
- Labeling: ~$10-20K (outsourced) or significant internal time

### Training
- GPU compute: 100-500 GPU hours (A100)
- Estimated cost: $500-2000 (cloud)

### Ongoing
- Continuous data collection
- Quarterly retraining
- User feedback integration

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Data Collection | 3-6 months | 200+ hours labeled EU ATC |
| Initial Training | 2 weeks | Base fine-tuned model |
| Belgian Optimization | 2 weeks | Belgium-specific model |
| Mobile Optimization | 1 week | Quantized GGML model |
| Evaluation & Iteration | Ongoing | <3% WER achieved |

---

## Next Steps

1. **Immediate:** Set up LiveATC recording pipeline for EBBR
2. **Week 1-2:** Build labeling interface
3. **Month 1:** Collect and label initial 50 hours
4. **Month 2:** First training run, evaluate
5. **Month 3-6:** Iterate until <3% WER achieved
