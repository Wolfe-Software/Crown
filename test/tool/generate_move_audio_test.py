"""Signal-level checks for the offline move-sound processor."""
import hashlib
import io
import math
import struct
import unittest
import wave

from tool import generate_move_audio as audio


class MoveAudioProcessingTest(unittest.TestCase):
    def test_eq_boosts_wood_body_without_boosting_deep_bass_or_treble(self):
        for frequency, expected_db in [(400, 2.0), (40, 0.0), (8000, 0.0)]:
            samples = [0.1 * math.sin(2 * math.pi * frequency * i / audio.RATE)
                       for i in range(audio.RATE)]
            processed = audio.equalize(samples)
            # Exclude filter startup and measure steady-state amplitude gain.
            ratio = audio.rms(processed[audio.RATE // 2:]) / audio.rms(samples[audio.RATE // 2:])
            self.assertAlmostEqual(20 * math.log10(ratio), expected_db, delta=0.1)

    def test_compressor_has_two_to_one_ratio_and_smooth_attack_release(self):
        duration = round(audio.RATE * 0.15)
        samples = [0.5] * duration + [0.0] * duration
        processed, reduction = audio.compress(samples, threshold_db=-18.0)
        expected = (20 * math.log10(0.5) + 18.0) / 2
        self.assertAlmostEqual(reduction[duration - 1], expected, places=3)
        self.assertGreater(reduction[0], 0)
        self.assertLess(reduction[0], expected * 0.1)
        self.assertAlmostEqual(reduction[round(audio.RATE * audio.ATTACK) - 1],
                               expected * (1 - 1 / math.e), delta=0.02)
        self.assertGreater(reduction[round(audio.RATE * 0.02)], expected * 0.99)
        self.assertAlmostEqual(reduction[duration + round(audio.RATE * 0.065)],
                               expected / math.e, delta=0.02)
        self.assertAlmostEqual(processed[duration - 1], 0.5 * 10 ** (-expected / 20), places=4)
        self.assertTrue(all(value == 0 for value in processed[duration:]))

    def test_soft_knee_engages_gently_below_threshold(self):
        level = 10 ** (-20 / 20)  # 2 dB below a -18 dB threshold, inside the 6 dB knee.
        _, reduction = audio.compress([level] * audio.RATE, threshold_db=-18)
        self.assertGreater(reduction[-1], 0)
        self.assertLess(reduction[-1], 0.1)
        _, silent_reduction = audio.compress([0.0] * 100, threshold_db=-18)
        self.assertEqual(silent_reduction, [0.0] * 100)

    def test_version_b_preserves_reference_timing_headroom_and_loudness(self):
        result = audio.prepare()
        self.assertEqual(hashlib.sha256(result.baseline).hexdigest(),
                         'a39d8e98b3d56b3f9fe2df14b3a9e9712d7f5dbabdea40a61fb80a9789619be2')
        self.assertNotEqual(result.encoded, result.baseline)
        self.assertEqual(result.encoded, audio.prepare().encoded)
        self.assertGreaterEqual(result.max_reduction_db, 2.0)
        self.assertLessEqual(result.max_reduction_db, 3.0)
        self.assertLessEqual(abs(result.rms_delta_db), 0.15)
        self.assertAlmostEqual(result.start, 3045 / audio.RATE)
        with wave.open(io.BytesIO(result.encoded), 'rb') as source:
            self.assertEqual((source.getnchannels(), source.getsampwidth(), source.getframerate()),
                             (1, 2, 44100))
            self.assertEqual(source.getnframes(), 6174)
            samples = [item[0] for item in struct.iter_unpack('<h', source.readframes(6174))]
        self.assertEqual((samples[0], samples[-1]), (0, 0))
        self.assertLessEqual(max(abs(value) for value in samples), round(0.65 * 32767))


if __name__ == '__main__':
    unittest.main()
