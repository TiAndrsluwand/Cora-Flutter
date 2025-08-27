import 'dart:math' as math;
import 'dart:typed_data';

class PitchPoint {
  final double timeSec;
  final double frequencyHz;
  final String note;
  final int cents;
  PitchPoint({required this.timeSec, required this.frequencyHz, required this.note, required this.cents});
}

class PitchDetector {
  final double minVolume;
  final double minConfidence;
  final int windowSize;
  final double smoothing;

  const PitchDetector({
    this.minVolume = 0.005,  // Reduced from 0.01 - was too high for quiet melodies
    this.minConfidence = 0.6,  // Reduced from 0.8 - was too restrictive
    this.windowSize = 2048,
    this.smoothing = 0.8,
  });

  List<PitchPoint> analyze(Float32List pcm, double sampleRate) {
    if (pcm.isEmpty) {
      print('PitchDetector: Empty PCM data provided');
      return const [];
    }
    
    final hop = (windowSize / 2).floor();
    final points = <PitchPoint>[];
    double lastFreq = 0;
    int volumeRejects = 0;
    int confidenceRejects = 0;
    int totalWindows = 0;

    print('PitchDetector: Analyzing ${pcm.length} samples at ${sampleRate}Hz (${(pcm.length/sampleRate).toStringAsFixed(2)}s)');
    print('  Settings: minVolume=${minVolume}, minConfidence=${minConfidence}, windowSize=${windowSize}');

    for (int start = 0; start + windowSize <= pcm.length; start += hop) {
      totalWindows++;
      final window = pcm.sublist(start, start + windowSize);
      final volume = _rms(window);
      if (volume < minVolume) {
        volumeRejects++;
        continue;
      }
      final res = _autocorrelation(window, sampleRate);
      var freq = res.$1;
      final conf = res.$2;
      if (freq <= 0 || conf < minConfidence) {
        confidenceRejects++;
        continue;
      }
      if (lastFreq > 0) {
        freq = smoothing * lastFreq + (1 - smoothing) * freq;
      }
      lastFreq = freq;
      final noteCents = _frequencyToNote(freq);
      final timeSec = start / sampleRate;
      points.add(PitchPoint(
        timeSec: timeSec,
        frequencyHz: freq,
        note: noteCents.$1,
        cents: noteCents.$2,
      ));
    }
    
    print('PitchDetector: Results - ${points.length} valid points from ${totalWindows} windows');
    print('  Rejected: ${volumeRejects} volume, ${confidenceRejects} confidence');
    print('  Success rate: ${((points.length / totalWindows) * 100).toStringAsFixed(1)}%');
    if (points.isNotEmpty) {
      final noteFreq = <String, int>{};
      for (final p in points) {
        final note = p.note.replaceAll(RegExp(r'\d+'), '');
        noteFreq[note] = (noteFreq[note] ?? 0) + 1;
      }
      print('  Note distribution: ${noteFreq.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    }
    
    return points;
  }

  double _rms(Float32List buf) {
    double sum = 0;
    for (final v in buf) { sum += v * v; }
    return math.sqrt(sum / buf.length);
  }

  (double, double) _autocorrelation(Float32List buffer, double sampleRate) {
    final size = buffer.length;
    final acf = Float32List(size);
    // Hamming window + autocorrelation
    for (int lag = 0; lag < size; lag++) {
      double sum = 0;
      for (int i = 0; i < size - lag; i++) {
        final w = 0.54 - 0.46 * math.cos((2 * math.pi * i) / (size - 1));
        sum += (buffer[i] * w) * (buffer[i + lag] * w);
      }
      acf[lag] = sum;
    }
    int peakIndex = -1;
    double peakValue = double.negativeInfinity;
    final minLag = (sampleRate / 1000).floor();
    final maxLag = math.min((sampleRate / 50).floor(), size - 1);
    for (int lag = minLag; lag < maxLag; lag++) {
      final v = acf[lag];
      if (v > peakValue) { peakValue = v; peakIndex = lag; }
    }
    if (peakIndex <= 0 || acf[0] == 0) return (0.0, 0.0);
    final alpha = acf[peakIndex - 1];
    final beta = acf[peakIndex];
    final gamma = acf[peakIndex + 1];
    final denom = (alpha - 2 * beta + gamma);
    final p = denom.abs() < 1e-9 ? 0.0 : 0.5 * (alpha - gamma) / denom;
    final trueLag = peakIndex + p;
    final freq = sampleRate / trueLag;
    final conf = beta / acf[0];
    return (freq, conf);
  }

  (String, int) _frequencyToNote(double frequency) {
    const A4 = 440.0;
    final C0 = A4 * math.pow(2, -4.75);
    if (frequency < 20) return ('Too low', 0);
    final halfSteps = (12 * (math.log(frequency / C0) / math.ln2)).round();
    final exactFrequency = C0 * math.pow(2, halfSteps / 12);
    final cents = (1200 * (math.log(frequency / exactFrequency) / math.ln2)).round();
    const names = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
    final noteIndex = ((halfSteps % 12) + 12) % 12;
    final noteName = names[noteIndex];
    final octave = (halfSteps / 12).floor();
    return ('$noteName$octave', cents);
  }
}
