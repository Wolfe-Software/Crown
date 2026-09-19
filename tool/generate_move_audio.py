"""Prepare Crown's recorded wooden-piece landing. Requires only Python 3.

Source and license: tool/audio_sources/README.md.
Run with --check to verify the bundled asset without modifying any files.
"""
import argparse
from dataclasses import dataclass
import hashlib
import io
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tool/audio_sources/wood-piece-placement.wav'
TARGET = ROOT / 'assets/move.wav'
BASELINE = ROOT / 'tool/audio_sources/move-baseline.wav'
SOURCE_SHA256 = 'b1cb3b43dba3e7244f41c80cc4e9b7cf533627d6dfe9e1d7bc63b1414149aaef'
RATE = 44100
DURATION = 0.140
PEAK = 0.65
EQ_FREQUENCY = 400.0
EQ_GAIN_DB = 2.0
EQ_Q = 0.7
RATIO = 2.0
# The recorded contact peaks within a millisecond; a 4 ms attack misses it.
ATTACK = 0.0005
RELEASE = 0.065
KNEE_DB = 6.0
TARGET_REDUCTION_DB = 2.5


@dataclass(frozen=True)
class PreparedAudio:
    encoded: bytes
    baseline: bytes
    start: float
    threshold_db: float
    max_reduction_db: float
    peak_db: float
    rms_db: float
    rms_delta_db: float


def rms(samples):
    return math.sqrt(sum(value * value for value in samples) / len(samples))


def equalize(samples):
    """RBJ peaking biquad: broad +2 dB wooden-body emphasis at 400 Hz."""
    amplitude = 10 ** (EQ_GAIN_DB / 40)
    omega = 2 * math.pi * EQ_FREQUENCY / RATE
    alpha = math.sin(omega) / (2 * EQ_Q)
    cosine = math.cos(omega)
    a0 = 1 + alpha / amplitude
    b0, b1, b2 = ((1 + alpha * amplitude) / a0, -2 * cosine / a0,
                  (1 - alpha * amplitude) / a0)
    a1, a2 = -2 * cosine / a0, (1 - alpha / amplitude) / a0
    x1 = x2 = y1 = y2 = 0.0
    output = []
    for x0 in samples:
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        output.append(y0)
        x2, x1, y2, y1 = x1, x0, y1, y0
    return output


def compress(samples, threshold_db):
    """Soft-knee peak compressor with attack/release smoothing of dB reduction."""
    attack = math.exp(-1 / (RATE * ATTACK))
    release = math.exp(-1 / (RATE * RELEASE))
    previous = 0.0
    output, envelope = [], []
    slope = 1 - 1 / RATIO
    for sample in samples:
        over = 20 * math.log10(max(abs(sample), 1e-12)) - threshold_db
        if over <= -KNEE_DB / 2:
            target = 0.0
        elif over >= KNEE_DB / 2:
            target = slope * over
        else:
            target = slope * (over + KNEE_DB / 2) ** 2 / (2 * KNEE_DB)
        coefficient = attack if target > previous else release
        reduction = target + coefficient * (previous - target)
        output.append(sample * 10 ** (-reduction / 20))
        envelope.append(reduction)
        previous = reduction
    return output, envelope


def fade(samples):
    output = samples.copy()
    fade_in = round(RATE * 0.0005)
    fade_out = round(RATE * 0.012)
    for index in range(len(output)):
        output[index] *= min(1.0, index / (fade_in - 1))
        output[index] *= min(1.0, (len(output) - 1 - index) / (fade_out - 1))
    return output


def encode(samples):
    pcm = b''.join(struct.pack('<h', round(sample * 32767)) for sample in samples)
    output = io.BytesIO()
    with wave.open(output, 'wb') as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm)
    return output.getvalue()


def prepare():
    source_bytes = SOURCE.read_bytes()
    if hashlib.sha256(source_bytes).hexdigest() != SOURCE_SHA256:
        raise ValueError('Source recording changed; verify its provenance before regenerating.')
    with wave.open(io.BytesIO(source_bytes), 'rb') as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (1, 2, RATE):
            raise ValueError('Expected mono 44.1 kHz, 16-bit PCM source.')
        raw = source.readframes(source.getnframes())
    samples = [value[0] / 32768 for value in struct.iter_unpack('<h', raw)]

    # Gentle first-order filters retain the actual impact and board resonance.
    high_pass = math.exp(-2 * math.pi * 60 / RATE)
    low_pass = 1 - math.exp(-2 * math.pi * 5000 / RATE)
    previous_input = previous_high = previous_low = 0.0
    filtered = []
    for sample in samples:
        high = high_pass * (previous_high + sample - previous_input)
        low = previous_low + low_pass * (high - previous_low)
        filtered.append(low)
        previous_input, previous_high, previous_low = sample, high, low

    maximum = max(abs(sample) for sample in filtered)
    if maximum < 0.001:
        raise ValueError('Source has no usable contact sound.')
    onset = next(i for i, sample in enumerate(filtered) if abs(sample) >= maximum * 0.04)
    start = max(0, onset - round(RATE * 0.001))
    length = round(RATE * DURATION)
    contact = filtered[start:start + length]
    if len(contact) != length:
        raise ValueError('Source does not contain the full landing decay.')

    # Baseline reproduces the previous asset byte-for-byte, including its crop.
    contact = fade(contact)
    gain = PEAK / max(abs(sample) for sample in contact)
    baseline = [sample * gain for sample in contact]

    # Process with pre-roll, but crop using the original cleanup signal's onset.
    equalized = equalize(filtered)
    low, high = -80.0, 0.0
    for _ in range(32):
        threshold = (low + high) / 2
        _, reduction = compress(equalized, threshold)
        if max(reduction[start:start + length]) > TARGET_REDUCTION_DB:
            low = threshold
        else:
            high = threshold
    threshold = (low + high) / 2
    compressed, reduction = compress(equalized, threshold)
    processed = fade(compressed[start:start + length])

    # Match baseline energy rather than forcing the compressed version louder.
    gain = rms(baseline) / rms(processed)
    gain = min(gain, PEAK / max(abs(sample) for sample in processed))
    processed = [sample * gain for sample in processed]
    return PreparedAudio(
        encoded=encode(processed), baseline=encode(baseline), start=start / RATE,
        threshold_db=threshold, max_reduction_db=max(reduction[start:start + length]),
        peak_db=20 * math.log10(max(abs(sample) for sample in processed)),
        rms_db=20 * math.log10(rms(processed)),
        rms_delta_db=20 * math.log10(rms(processed) / rms(baseline)),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify the committed asset is reproducible.')
    args = parser.parse_args()
    result = prepare()
    outputs = [(TARGET, result.encoded), (BASELINE, result.baseline)]
    if args.check:
        for path, encoded in outputs:
            if not path.exists() or path.read_bytes() != encoded:
                raise SystemExit(f'{path.relative_to(ROOT)} differs; run python3 tool/generate_move_audio.py')
        action = 'Verified'
    else:
        for path, encoded in outputs:
            path.write_bytes(encoded)
        action = 'Prepared'
    print(f'{action} {TARGET.relative_to(ROOT)}: {DURATION * 1000:.0f} ms, '
          f'mono {RATE} Hz / 16-bit; contact starts {result.start:.6f} s into the source excerpt.\n'
          f'  EQ: {EQ_GAIN_DB:+.1f} dB at {EQ_FREQUENCY:.0f} Hz, Q={EQ_Q}\n'
          f'  Compression: {RATIO:.0f}:1, attack {ATTACK * 1000:.1f} ms, '
          f'release {RELEASE * 1000:.0f} ms, knee {KNEE_DB:.0f} dB\n'
          f'  Calibrated threshold: {result.threshold_db:.3f} dBFS; '
          f'maximum gain reduction: {result.max_reduction_db:.2f} dB\n'
          f'  Peak: {result.peak_db:.2f} dBFS; RMS: {result.rms_db:.2f} dBFS; '
          f'RMS difference from baseline: {result.rms_delta_db:+.3f} dB\n'
          f'  Comparison reference: {BASELINE.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
