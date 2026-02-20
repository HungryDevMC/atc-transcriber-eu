#!/usr/bin/env python3
"""
ATC Transcription Quality Test

Compares generic Whisper vs ATC-fine-tuned Whisper on real ATC audio samples.
This demonstrates why a specialized model is essential for ATC transcription.

Requirements:
    pip install datasets torch transformers librosa jiwer soundfile

Usage:
    python test_atc_transcription.py
"""

import os
from dataclasses import dataclass


@dataclass
class TranscriptionResult:
    model_name: str
    transcription: str
    ground_truth: str
    wer: float


def calculate_wer(reference: str, hypothesis: str) -> float:
    """Calculate Word Error Rate between reference and hypothesis."""
    try:
        from jiwer import wer
        return wer(reference.lower(), hypothesis.lower())
    except ImportError:
        # Simple WER calculation if jiwer not available
        ref_words = reference.lower().split()
        hyp_words = hypothesis.lower().split()
        if not ref_words:
            return 1.0 if hyp_words else 0.0
        # Very rough approximation
        errors = abs(len(ref_words) - len(hyp_words))
        for r, h in zip(ref_words, hyp_words):
            if r != h:
                errors += 1
        return min(1.0, errors / len(ref_words))


def load_atc_samples(num_samples: int = 5):
    """Load ATC audio samples from HuggingFace dataset."""
    print("Loading ATC dataset from HuggingFace...")
    try:
        from datasets import load_dataset

        dataset = load_dataset("jacktol/atc-dataset", split="test")
        samples = []

        for i, item in enumerate(dataset):
            if i >= num_samples:
                break
            samples.append({
                "audio": item["audio"],
                "text": item["text"],
                "id": i
            })

        print(f"Loaded {len(samples)} ATC samples")
        return samples
    except Exception as e:
        print(f"Error loading dataset: {e}")
        return []


def transcribe_with_generic_whisper(audio_array, sample_rate: int):
    """Transcribe using generic Whisper (not fine-tuned)."""
    try:
        import torch
        from transformers import WhisperProcessor, WhisperForConditionalGeneration

        model_name = "openai/whisper-small.en"
        processor = WhisperProcessor.from_pretrained(model_name)
        model = WhisperForConditionalGeneration.from_pretrained(model_name)

        # Process audio
        inputs = processor(
            audio_array,
            sampling_rate=sample_rate,
            return_tensors="pt"
        )

        with torch.no_grad():
            generated_ids = model.generate(inputs.input_features, max_length=448)

        transcription = processor.batch_decode(
            generated_ids,
            skip_special_tokens=True
        )[0]

        return transcription.strip()
    except Exception as e:
        return f"[Error: {e}]"


def transcribe_with_atc_whisper(audio_array, sample_rate: int):
    """Transcribe using ATC-fine-tuned Whisper."""
    try:
        import torch
        from transformers import WhisperProcessor, WhisperForConditionalGeneration

        # Use the ATC-fine-tuned model
        model_name = "jacktol/whisper-medium.en-fine-tuned-for-ATC"
        processor = WhisperProcessor.from_pretrained(model_name)
        model = WhisperForConditionalGeneration.from_pretrained(model_name)

        # Process audio
        inputs = processor(
            audio_array,
            sampling_rate=sample_rate,
            return_tensors="pt"
        )

        with torch.no_grad():
            generated_ids = model.generate(inputs.input_features, max_length=448)

        transcription = processor.batch_decode(
            generated_ids,
            skip_special_tokens=True
        )[0]

        return transcription.strip()
    except Exception as e:
        return f"[Error: {e}]"


def run_comparison_test():
    """Run comparison test between generic and ATC-tuned Whisper."""
    print("=" * 60)
    print("ATC TRANSCRIPTION QUALITY TEST")
    print("=" * 60)
    print()

    samples = load_atc_samples(num_samples=5)

    if not samples:
        print("No samples loaded. Please install: pip install datasets")
        return

    generic_wers = []
    atc_wers = []

    for sample in samples:
        audio = sample["audio"]
        ground_truth = sample["text"]
        audio_array = audio["array"]
        sample_rate = audio["sampling_rate"]

        print(f"\n--- Sample {sample['id'] + 1} ---")
        print(f"Ground Truth: {ground_truth}")
        print()

        # Test generic Whisper
        print("Testing generic Whisper (small.en)...")
        generic_result = transcribe_with_generic_whisper(audio_array, sample_rate)
        generic_wer = calculate_wer(ground_truth, generic_result)
        generic_wers.append(generic_wer)
        print(f"  Transcription: {generic_result}")
        print(f"  WER: {generic_wer:.1%}")

        # Test ATC-tuned Whisper
        print("\nTesting ATC-tuned Whisper (medium.en)...")
        atc_result = transcribe_with_atc_whisper(audio_array, sample_rate)
        atc_wer = calculate_wer(ground_truth, atc_result)
        atc_wers.append(atc_wer)
        print(f"  Transcription: {atc_result}")
        print(f"  WER: {atc_wer:.1%}")

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    avg_generic_wer = sum(generic_wers) / len(generic_wers) if generic_wers else 0
    avg_atc_wer = sum(atc_wers) / len(atc_wers) if atc_wers else 0

    print(f"\nAverage WER - Generic Whisper: {avg_generic_wer:.1%}")
    print(f"Average WER - ATC-tuned Whisper: {avg_atc_wer:.1%}")
    print(f"\nImprovement: {((avg_generic_wer - avg_atc_wer) / avg_generic_wer * 100):.0f}% reduction in errors")
    print()

    if avg_atc_wer < 0.15:
        print("✓ ATC-tuned model is RECOMMENDED for production use")
    else:
        print("⚠ Consider using larger model (whisper-large-v3-finetuned-for-ATC)")


def check_dependencies():
    """Check if required packages are installed."""
    missing = []

    try:
        import datasets
    except ImportError:
        missing.append("datasets")

    try:
        import torch
    except ImportError:
        missing.append("torch")

    try:
        import transformers
    except ImportError:
        missing.append("transformers")

    try:
        import soundfile
    except ImportError:
        missing.append("soundfile")

    if missing:
        print("Missing dependencies. Install with:")
        print(f"  pip install {' '.join(missing)}")
        return False
    return True


if __name__ == "__main__":
    if check_dependencies():
        run_comparison_test()
    else:
        print("\nAlternatively, run the quick demo without ML dependencies:")
        print("  python test_atc_transcription.py --demo")
