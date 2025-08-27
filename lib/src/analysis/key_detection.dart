import 'dart:math' as math;

class KeyResult { final String key; final bool isMinor; final double score; KeyResult(this.key,this.isMinor,this.score); }

class KeyDetector {
  // Krumhansl-Schmuckler major/minor profiles (normalized)
  static const List<double> major = [
    6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
  ];
  static const List<double> minor = [
    6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
  ];
  static const List<String> noteNames = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

  static KeyResult detect(List<String> notes) {
    if (notes.isEmpty) return KeyResult('Unknown', false, 0);
    // Build pitch class histogram
    final hist = List<double>.filled(12, 0);
    for (final n in notes) {
      final idx = _noteIndex(n);
      if (idx >= 0) hist[idx] += 1;
    }
    // Normalize
    final sum = hist.fold<double>(0, (s, v) => s + v);
    if (sum == 0) return KeyResult('Unknown', false, 0);
    for (int i = 0; i < 12; i++) { hist[i] /= sum; }

    double bestScore = -1e9; String bestKey = 'C'; bool bestMinor = false;

    for (int tonic = 0; tonic < 12; tonic++) {
      final shifted = List<double>.generate(12, (i) => hist[(i + tonic) % 12]);
      final mjScore = _correlation(shifted, major);
      if (mjScore > bestScore) { bestScore = mjScore; bestKey = noteNames[tonic]; bestMinor = false; }
      final mnScore = _correlation(shifted, minor);
      if (mnScore > bestScore) { bestScore = mnScore; bestKey = noteNames[tonic]; bestMinor = true; }
    }

    return KeyResult(bestKey, bestMinor, bestScore);
  }

  static int _noteIndex(String note) {
    final base = note.toUpperCase().replaceAll(RegExp(r'\d+'), '');
    const map = {
      'C':0,'C#':1,'DB':1,'D':2,'D#':3,'EB':3,'E':4,'F':5,'F#':6,'GB':6,'G':7,'G#':8,'AB':8,'A':9,'A#':10,'BB':10,'B':11
    };
    return map[base] ?? -1;
  }

  static double _correlation(List<double> a, List<double> b) {
    double meanA = a.reduce((x,y)=>x+y) / a.length;
    double meanB = b.reduce((x,y)=>x+y) / b.length;
    double num = 0, da = 0, db = 0;
    for (int i=0;i<a.length;i++) {
      final va = a[i]-meanA;
      final vb = b[i]-meanB;
      num += va*vb; da += va*va; db += vb*vb;
    }
    final denom = math.sqrt(da*db);
    return denom == 0 ? 0 : num/denom;
  }
}
