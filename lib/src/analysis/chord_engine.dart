import '../theory/music_theory.dart' as music_theory;

class DetectedNote {
  final String note;
  final int startTime;
  final int duration;
  DetectedNote(
      {required this.note, required this.startTime, required this.duration});
}

class ChordSuggestion {
  final String symbol;
  final String root;
  final music_theory.ChordType chordType;
  final List<String> notes;
  final int duration;
  final int startTime;
  final double weight;
  ChordSuggestion({
    required this.symbol,
    required this.root,
    required this.chordType,
    required this.notes,
    required this.duration,
    required this.startTime,
    required this.weight,
  });
}

class ChordProgressionSuggestion {
  final String name;
  final String key;
  final String scale;
  final List<ChordSuggestion> chords;
  final double score;
  ChordProgressionSuggestion({
    required this.name,
    required this.key,
    required this.scale,
    required this.chords,
    required this.score,
  });
}

class ChordSuggestionOptions {
  final int maxProgressions;
  final int minChordDuration;
  final List<List<String>> preferredProgressions;
  final bool extendedChords;
  final double jazziness;
  const ChordSuggestionOptions({
    this.maxProgressions = 8,
    this.minChordDuration = 400, // Much more permissive for short melodies
    this.preferredProgressions = const [],
    this.extendedChords = true,
    this.jazziness = 0.3,
  });
}

class ChordSuggestionEngine {
  final ChordSuggestionOptions options;
  const ChordSuggestionEngine({this.options = const ChordSuggestionOptions()});

  List<ChordProgressionSuggestion> suggest(
      List<DetectedNote> melody, String keyLabel, bool isMinor) {
    if (melody.isEmpty) {
      print('ChordEngine: No melody notes provided');
      return [];
    }
    if (keyLabel == 'Unknown') {
      print('ChordEngine: Key detection failed - cannot suggest chords');
      return [];
    }

    print(
        'ChordEngine: Generating chord suggestions for ${melody.length} notes in $keyLabel ${isMinor ? 'minor' : 'major'}');
    final keyRoot = isMinor ? keyLabel.replaceAll('m', '') : keyLabel;
    final scaleType =
        isMinor ? music_theory.SCALE_TYPES.NATURAL_MINOR : music_theory.SCALE_TYPES.MAJOR;
    final scale = music_theory.buildScale(keyRoot, scaleType);
    print('ChordEngine: Scale notes: ${scale.join(', ')}');

    final segments = _segmentMelody(melody);
    print('ChordEngine: Segmented melody into ${segments.length} phrase(s)');

    // If melody segmentation fails, create a simple single segment
    if (segments.isEmpty && melody.isNotEmpty) {
      print(
          'ChordEngine: Segmentation failed, using entire melody as single segment');
      segments.add(melody);
    }

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      print(
          '  Segment ${i + 1}: ${seg.map((n) => n.note).join(', ')} (${seg.length} notes, ${seg.fold(0, (sum, n) => sum + n.duration)}ms total)');
    }

    final progs = _generateProgressions(segments, keyRoot, scaleType, scale);
    print('ChordEngine: Generated ${progs.length} progression candidates');

    progs.sort((a, b) => b.score.compareTo(a.score));

    if (progs.isNotEmpty) {
      print(
          'ChordEngine: Best progression: "${progs.first.name}" (score: ${progs.first.score.toStringAsFixed(3)})');
      print('  Chords: ${progs.first.chords.map((c) => c.symbol).join(' - ')}');

      // Show all candidates with scores
      print('ChordEngine: All candidates:');
      for (int i = 0; i < progs.length && i < 5; i++) {
        final prog = progs[i];
        print(
            '  ${i + 1}. ${prog.name}: ${prog.chords.map((c) => c.symbol).join(' - ')} (${prog.score.toStringAsFixed(3)})');
      }
    } else {
      print('ChordEngine: No valid progressions generated');
    }

    // Always return the single most accurate result
    return progs.isEmpty ? [] : [progs.first];
  }

  List<List<DetectedNote>> _segmentMelody(List<DetectedNote> melody) {
    if (melody.isEmpty) return [];
    final segments = <List<DetectedNote>>[];
    var current = <DetectedNote>[melody.first];
    var dur = melody.first.duration;
    for (var i = 1; i < melody.length; i++) {
      final n = melody[i];
      current.add(n);
      dur += n.duration;
      final isLongEnough = dur >= options.minChordDuration;
      final isBoundary = _isPhraseBoundary(melody, i);
      if (isLongEnough && isBoundary) {
        segments.add(List.of(current));
        current.clear();
        dur = 0;
      }
    }
    if (current.isNotEmpty) segments.add(List.of(current));
    // Be more aggressive about creating segments for short melodies
    if (segments.length < 2 && melody.length > 2) return _forceSegments(melody);
    return segments;
  }

  List<List<DetectedNote>> _forceSegments(List<DetectedNote> melody) {
    final segments = <List<DetectedNote>>[];
    final total = melody.length;
    final target = (total / 6).ceil().clamp(2, total);
    final per = (total / target).ceil();
    for (var i = 0; i < total; i += per) {
      final end = (i + per > total) ? total : i + per;
      segments.add(melody.sublist(i, end));
    }
    return segments;
  }

  bool _isPhraseBoundary(List<DetectedNote> melody, int pos) {
    if (pos <= 0 || pos >= melody.length) return false;
    final cur = melody[pos];
    final prev = melody[pos - 1];
    final isLong = prev.duration > 500;
    final pitchChange =
        (music_theory.getNoteIndex(cur.note) - music_theory.getNoteIndex(prev.note)).abs();
    final isSignificant = pitchChange > 4;
    final gap = cur.startTime - (prev.startTime + prev.duration);
    final isRest = gap > 300;
    return isLong || isSignificant || isRest;
  }

  List<ChordProgressionSuggestion> _generateProgressions(
    List<List<DetectedNote>> segments,
    String key,
    music_theory.ScaleType scaleType,
    List<String> scale,
  ) {
    final result = <ChordProgressionSuggestion>[];
    if (segments.isEmpty) return result;

    final patterns = scaleType == music_theory.SCALE_TYPES.MAJOR
        ? [
            {
              'name': 'Basic I-IV-V',
              'nums': ['I', 'IV', 'V']
            },
            {
              'name': 'Pop I-V-vi-IV',
              'nums': ['I', 'V', 'vi', 'IV']
            },
            {
              'name': 'Classic I-vi-IV-V',
              'nums': ['I', 'vi', 'IV', 'V']
            },
            {
              'name': 'ii-V-I',
              'nums': ['ii', 'V', 'I']
            },
            {
              'name': 'Turnaround I-vi-ii-V',
              'nums': ['I', 'vi', 'ii', 'V']
            },
            {
              'name': 'vi-ii-V-I',
              'nums': ['vi', 'ii', 'V', 'I']
            },
          ]
        : [
            {
              'name': 'Natural Minor i-iv-v',
              'nums': ['i', 'iv', 'v']
            },
            {
              'name': 'Harmonic Minor i-iv-V',
              'nums': ['i', 'iv', 'V']
            },
            {
              'name': 'Epic i-VI-III-VII',
              'nums': ['i', 'VI', 'III', 'VII']
            },
            {
              'name': 'Minor iiø-V-i (approx)',
              'nums': ['ii', 'V', 'i']
            },
          ];

    final all = [...patterns];
    for (var i = 0; i < options.preferredProgressions.length; i++) {
      all.add({
        'name': 'Custom ${i + 1}',
        'nums': options.preferredProgressions[i]
      });
    }

    for (final p in all) {
      final nums = (p['nums'] as List<String>);
      if (nums.length > segments.length) continue;
      final progChords = music_theory.progressionToChords(nums, key, scaleType);
      final adapted = _adaptToSegments(progChords, segments, scale);
      final score = _scoreProgression(adapted, segments, scale);
      result.add(ChordProgressionSuggestion(
        name: p['name'] as String,
        key: key,
        scale: scaleType.name,
        chords: adapted,
        score: score,
      ));
    }
    return result;
  }

  List<ChordSuggestion> _adaptToSegments(
    List<music_theory.DiatonicChord> chordProg,
    List<List<DetectedNote>> segments,
    List<String> scale,
  ) {
    final repeated = <music_theory.DiatonicChord>[];
    while (repeated.length < segments.length) {
      repeated.addAll(chordProg);
    }
    final trimmed = repeated.sublist(0, segments.length);

    final out = <ChordSuggestion>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final chord = trimmed[i];
      final start = seg.first.startTime;
      final end = seg.last.startTime + seg.last.duration;
      final dur = end - start;
      final notes = music_theory.buildChord(chord.root, chord.chordType);
      final weight = _chordWeight(chord, seg, scale);
      out.add(ChordSuggestion(
        symbol: chord.symbol,
        root: chord.root,
        chordType: chord.chordType,
        notes: notes,
        duration: dur,
        startTime: start,
        weight: weight,
      ));
    }
    return out;
  }

  double _chordWeight(
      music_theory.DiatonicChord chord, List<DetectedNote> segment, List<String> scale) {
    // Duration-weighted pitch fitness with strong-beat emphasis
    var weight = 0.0;
    var totalDur = 0.0;
    final chordNotes = music_theory.buildChord(chord.root, chord.chordType);
    if (segment.isEmpty) return 0;
    final segStart = segment.first.startTime;
    for (final n in segment) {
      final norm = music_theory.normalizeNoteName(n.note);
      final dur = n.duration.clamp(1, 2000).toDouble();
      totalDur += dur;
      final posMs = (n.startTime - segStart).clamp(0, 1000000);
      final onStrongBeat =
          (posMs % 500) < 120; // rough 120ms window around 0.5s grid

      double noteScore;
      if (music_theory.isNoteInChord(norm, chordNotes)) {
        noteScore = 2.2;
      } else if (music_theory.isNoteInScale(norm, scale))
        noteScore = 1.0;
      else
        noteScore = 0.1; // chromatic

      if (onStrongBeat) {
        // Emphasize strong beat correctness
        noteScore *= music_theory.isNoteInChord(norm, chordNotes) ? 1.4 : 0.7;
      }

      if (n.duration > 400) {
        noteScore += 0.4; // sustained tones are harmonically salient
      }
      weight += noteScore * dur;
    }
    if (totalDur <= 0) return 0;
    return weight / totalDur;
  }

  double _scoreProgression(List<ChordSuggestion> chords,
      List<List<DetectedNote>> segments, List<String> scale) {
    // Base: average chord fitness
    var score = chords.fold<double>(0.0, (s, c) => s + c.weight);
    // Voice-leading/root motion and cadential strength
    for (var i = 1; i < chords.length; i++) {
      final a = chords[i - 1];
      final b = chords[i];
      final interval = music_theory.getInterval(a.root, b.root);
      final degA = music_theory.getScaleDegree(a.root, scale);
      final degB = music_theory.getScaleDegree(b.root, scale);

      // Prefer small root motion
      final smallMotion = {1, 2, 3, 4};
      if (smallMotion.contains(interval)) score += 0.2;
      if (interval == 7) score += 0.4; // fifth relationship (functional)
      if (interval == 5) score += 0.3; // fourth
      if (interval == 6) score -= 0.2; // tritone step

      // Functional patterns
      final isFiveToOne = (degA == 5 && degB == 1);
      final isTwoToFive = (degA == 2 && degB == 5);
      if (isTwoToFive) score += 0.4;
      if (isFiveToOne) score += 0.6;

      // Ending cadence preference
      if (i == chords.length - 1) {
        if (degB == 1) {
          score += 0.6; // authentic/plagal resolution
        } else if (degB == 6) score += 0.3; // deceptive resolution tendency
      }
    }
    return score / (chords.isEmpty ? 1 : chords.length);
  }
}
