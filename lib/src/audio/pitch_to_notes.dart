import 'dart:math' as math;
import 'pitch_detector.dart';

class DiscreteNote {
  final String note;
  final int startMs;
  final int durationMs;
  DiscreteNote({required this.note, required this.startMs, required this.durationMs});
}

class PitchToNotes {
  static List<DiscreteNote> consolidate(List<PitchPoint> points) {
    if (points.isEmpty) return const [];
    final ms = (double t) => (t * 1000).round();
    final merged = <DiscreteNote>[];
    String? curNote; int curStart = ms(points.first.timeSec); int curEnd = curStart;

    for (final p in points) {
      final n = p.note.replaceAll(RegExp(r'\d+'), '');
      final t = ms(p.timeSec);
      if (curNote == null) {
        curNote = n; curStart = t; curEnd = t;
      } else if (n == curNote && (t - curEnd) <= 120) {
        // same note within short gap -> extend
        curEnd = t;
      } else {
        final dur = math.max(0, curEnd - curStart);
        if (dur >= 100) merged.add(DiscreteNote(note: curNote, startMs: curStart, durationMs: dur));
        curNote = n; curStart = t; curEnd = t;
      }
    }
    // flush
    final dur = math.max(0, curEnd - curStart);
    if (curNote != null && dur >= 100) merged.add(DiscreteNote(note: curNote!, startMs: curStart, durationMs: dur));

    return merged;
  }
}
