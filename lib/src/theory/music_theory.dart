class ChordType {
  final String name;
  final List<int> intervals; // semitone steps from root
  const ChordType(this.name, this.intervals);
}

class ScaleType {
  final String name;
  final List<int> intervals; // semitone steps from root for 7-note scale
  const ScaleType(this.name, this.intervals);
}

class CHORD_TYPES {
  static const MAJOR_TRIAD = ChordType('MAJOR_TRIAD', [0, 4, 7]);
  static const MINOR_TRIAD = ChordType('MINOR_TRIAD', [0, 3, 7]);
  static const DIMINISHED_TRIAD = ChordType('DIMINISHED_TRIAD', [0, 3, 6]);
  static const MAJOR_SEVENTH = ChordType('MAJOR_SEVENTH', [0, 4, 7, 11]);
  static const MINOR_SEVENTH = ChordType('MINOR_SEVENTH', [0, 3, 7, 10]);
  static const DOMINANT_SEVENTH = ChordType('DOMINANT_SEVENTH', [0, 4, 7, 10]);
  static const HALF_DIMINISHED = ChordType('HALF_DIMINISHED', [0, 3, 6, 10]);
}

class SCALE_TYPES {
  static const MAJOR = ScaleType('MAJOR', [0, 2, 4, 5, 7, 9, 11]);
  static const NATURAL_MINOR = ScaleType('NATURAL_MINOR', [0, 2, 3, 5, 7, 8, 10]);
}

const List<String> _NOTE_NAMES_SHARP = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const Map<String,int> _NOTE_TO_INDEX = {
  'C':0,'C#':1,'DB':1,'D':2,'D#':3,'EB':3,'E':4,'F':5,'F#':6,'GB':6,'G':7,'G#':8,'AB':8,'A':9,'A#':10,'BB':10,'B':11
};

String normalizeNoteName(String note) {
  final up = note.toUpperCase();
  // Remove octave if present
  final base = up.replaceAll(RegExp(r'\d+'), '');
  if (_NOTE_TO_INDEX.containsKey(base)) {
    final idx = _NOTE_TO_INDEX[base]!;
    return _NOTE_NAMES_SHARP[idx];
  }
  return base;
}

int getNoteIndex(String note) {
  final n = normalizeNoteName(note);
  return _NOTE_NAMES_SHARP.indexOf(n);
}

List<String> buildScale(String root, ScaleType type) {
  final rootIdx = getNoteIndex(root);
  return type.intervals.map((i) => _NOTE_NAMES_SHARP[(rootIdx + i) % 12]).toList();
}

List<String> buildChord(String root, ChordType type) {
  final rootIdx = getNoteIndex(root);
  return type.intervals.map((i) => _NOTE_NAMES_SHARP[(rootIdx + i) % 12]).toList();
}

bool isNoteInScale(String note, List<String> scale) {
  return scale.contains(normalizeNoteName(note));
}

bool isNoteInChord(String note, List<String> chordNotes) {
  return chordNotes.contains(normalizeNoteName(note));
}

int getInterval(String rootA, String rootB) {
  final a = getNoteIndex(rootA);
  final b = getNoteIndex(rootB);
  return (b - a + 12) % 12;
}

int getScaleDegree(String root, List<String> scale) {
  final n = normalizeNoteName(root);
  final idx = scale.indexOf(n);
  return idx >= 0 ? idx + 1 : -1;
}

int romanNumeralToScaleDegree(String numeral) {
  final map = {
    'I':1,'II':2,'III':3,'IV':4,'V':5,'VI':6,'VII':7,
    'i':1,'ii':2,'iii':3,'iv':4,'v':5,'vi':6,'vii':7
  };
  // Strip accidentals and diminished markers for degree calculation
  final base = numeral.replaceAll(RegExp(r'[°#b]'), '');
  return map[base] ?? 1;
}

class DiatonicChord { final String root; final ChordType chordType; final String symbol; DiatonicChord(this.root,this.chordType,this.symbol); }

DiatonicChord getDiatonicChord(int degree, String keyRoot, ScaleType scaleType) {
  final scale = buildScale(keyRoot, scaleType);
  final idx = (degree - 1).clamp(0, 6);
  final root = scale[idx];
  ChordType type;
  String symbol;
  if (scaleType == SCALE_TYPES.MAJOR) {
    switch (degree) {
      case 1: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}'; break;
      case 2: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      case 3: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      case 4: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}'; break;
      case 5: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}'; break;
      case 6: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      default: type = CHORD_TYPES.DIMINISHED_TRIAD; symbol = '${root}°';
    }
  } else {
    // natural minor
    switch (degree) {
      case 1: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      case 2: type = CHORD_TYPES.DIMINISHED_TRIAD; symbol = '${root}°'; break;
      case 3: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}'; break;
      case 4: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      case 5: type = CHORD_TYPES.MINOR_TRIAD; symbol = '${root}m'; break;
      case 6: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}'; break;
      default: type = CHORD_TYPES.MAJOR_TRIAD; symbol = '${root}';
    }
  }
  return DiatonicChord(root, type, symbol);
}

String getChordSymbol(String root, ChordType type) {
  if (type == CHORD_TYPES.MAJOR_TRIAD) return root;
  if (type == CHORD_TYPES.MINOR_TRIAD) return '${root}m';
  if (type == CHORD_TYPES.DOMINANT_SEVENTH) return '${root}7';
  if (type == CHORD_TYPES.MAJOR_SEVENTH) return '${root}maj7';
  if (type == CHORD_TYPES.MINOR_SEVENTH) return '${root}m7';
  if (type == CHORD_TYPES.HALF_DIMINISHED) return '${root}ø7';
  if (type == CHORD_TYPES.DIMINISHED_TRIAD) return '${root}°';
  return root;
}

List<DiatonicChord> progressionToChords(List<String> numerals, String keyRoot, ScaleType scaleType) {
  return numerals.map((n) {
    final deg = romanNumeralToScaleDegree(n);
    return getDiatonicChord(deg, keyRoot, scaleType);
  }).toList();
}
