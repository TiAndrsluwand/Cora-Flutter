import 'detected_chord.dart';

class ChordProgressionSuggestion {
  final String name;
  final String key;
  final List<DetectedChord> chords;

  ChordProgressionSuggestion({
    required this.name,
    required this.key,
    required this.chords,
  });

  @override
  String toString() {
    return 'ChordProgressionSuggestion(name: $name, key: $key, chords: $chords)';
  }
}
