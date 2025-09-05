import 'dart:math' as math;
import 'pitch_detector.dart';

class DiscreteNote {
  final String note;
  final int startMs;
  final int durationMs;
  DiscreteNote(
      {required this.note, required this.startMs, required this.durationMs});
}

class PitchToNotes {
  static List<DiscreteNote> consolidate(List<PitchPoint> points) {
    if (points.isEmpty) {
      print('PitchToNotes: No pitch points to consolidate');
      return const [];
    }

    print('PitchToNotes: Consolidating ${points.length} pitch points');
    ms(double t) => (t * 1000).round();
    final merged = <DiscreteNote>[];
    String? curNote;
    int curStart = ms(points.first.timeSec);
    int curEnd = curStart;
    int rawNotes = 0;
    int shortNotesFiltered = 0;

    for (final p in points) {
      final n = p.note.replaceAll(RegExp(r'\d+'), '');
      final t = ms(p.timeSec);
      rawNotes++;

      if (curNote == null) {
        curNote = n;
        curStart = t;
        curEnd = t;
      } else if (n == curNote && (t - curEnd) <= 300) {
        // Further increased gap tolerance for natural singing/humming
        // same note within short gap -> extend
        curEnd = t;
      } else {
        final dur = math.max(0, curEnd - curStart);
        if (dur >= 50) {
          // Much shorter minimum duration for quick melodies
          merged.add(
              DiscreteNote(note: curNote, startMs: curStart, durationMs: dur));
        } else {
          shortNotesFiltered++;
        }
        curNote = n;
        curStart = t;
        curEnd = t;
      }
    }
    // flush
    final dur = math.max(0, curEnd - curStart);
    if (curNote != null) {
      if (dur >= 50) {
        merged.add(
            DiscreteNote(note: curNote, startMs: curStart, durationMs: dur));
      } else {
        shortNotesFiltered++;
      }
    }

    print('PitchToNotes: Consolidated to ${merged.length} discrete notes');
    print('  Filtered out $shortNotesFiltered short notes (< 50ms)');
    print(
        '  Retention rate: ${((merged.length / rawNotes) * 100).toStringAsFixed(1)}%');

    if (merged.isNotEmpty) {
      print(
          '  Final notes: ${merged.map((n) => '${n.note}(${n.durationMs}ms)').join(', ')}');
      
      // DETAILED TIMING DEBUG - Critical for melody playback accuracy
      print('=== DETAILED NOTE TIMING EXTRACTION ===');
      for (int i = 0; i < merged.length; i++) {
        final note = merged[i];
        final endMs = note.startMs + note.durationMs;
        print('Note $i: ${note.note} | Start: ${note.startMs}ms | Duration: ${note.durationMs}ms | End: ${endMs}ms');
        
        // Check for gaps between consecutive notes
        if (i > 0) {
          final prevNote = merged[i - 1];
          final prevEndMs = prevNote.startMs + prevNote.durationMs;
          final gapMs = note.startMs - prevEndMs;
          if (gapMs > 0) {
            print('  → Gap from previous note: ${gapMs}ms');
          } else if (gapMs < 0) {
            print('  → OVERLAP with previous note: ${-gapMs}ms');
          }
        }
      }
      print('Total melody duration: ${merged.isNotEmpty ? merged.last.startMs + merged.last.durationMs : 0}ms');
      print('=== END TIMING DEBUG ===');
      
      final noteCount = <String, int>{};
      for (final n in merged) {
        noteCount[n.note] = (noteCount[n.note] ?? 0) + 1;
      }
      print(
          '  Note summary: ${noteCount.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    }

    return merged;
  }
}
