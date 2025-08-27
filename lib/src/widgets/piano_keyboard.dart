import 'package:flutter/material.dart';
import '../analysis/detected_chord.dart';

class PianoKeyboard extends StatefulWidget {
  final DetectedChord? selectedChord;
  final bool showChordNotes;
  
  const PianoKeyboard({
    super.key,
    this.selectedChord,
    this.showChordNotes = true,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  static const List<String> whiteKeys = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<String> blackKeys = ['C#', 'D#', '', 'F#', 'G#', 'A#', ''];

  bool _isKeyActive(String note) {
    if (widget.selectedChord == null) return false;
    // Remove octave numbers from notes for comparison
    final chordNotes = widget.selectedChord!.notes.map((n) => n.replaceAll(RegExp(r'\d+'), '')).toList();
    return chordNotes.contains(note);
  }

  List<String> _getActiveNotes() {
    if (widget.selectedChord == null) return [];
    // Remove octave numbers from notes for display
    return widget.selectedChord!.notes.map((n) => n.replaceAll(RegExp(r'\d+'), '')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.showChordNotes && widget.selectedChord != null) ...[
              Text(
                '${widget.selectedChord!.symbol}: ${_getActiveNotes().join(', ')}',
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Piano keyboard - Real piano layout
            // White keys: C D E F G A B (7 per octave)
            // Black keys: C# D# _ F# G# A# _ (5 per octave, gaps between E-F and B-C)
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  // White keys (2 octaves)
                  Row(
                    children: [
                      for (int octave = 0; octave < 2; octave++)
                        for (int i = 0; i < whiteKeys.length; i++)
                          _buildWhiteKey('${whiteKeys[i]}${octave + 4}', whiteKeys[i]),
                    ],
                  ),
                  // Black keys (2 octaves) - positioned correctly between white keys
                  for (int octave = 0; octave < 2; octave++)
                    for (int i = 0; i < blackKeys.length; i++)
                      if (blackKeys[i].isNotEmpty)
                        _buildBlackKey('${blackKeys[i]}${octave + 4}', blackKeys[i], octave * 7 + i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteKey(String keyName, String note) {
    final isActive = _isKeyActive(note);
    return Container(
      width: 24,
      height: 80,
      margin: const EdgeInsets.only(right: 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isActive ? Colors.orange : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(3),
          bottomRight: Radius.circular(3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isActive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 8,
                color: isActive ? Colors.orange.shade700 : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlackKey(String keyName, String note, int globalPosition) {
    final isActive = _isKeyActive(note);
    
    // Calculate correct positioning based on white key layout
    // In each octave: C# is between C-D, D# between D-E, F# between F-G, G# between G-A, A# between A-B
    final octave = globalPosition ~/ 7;
    final positionInOctave = globalPosition % 7;
    
    late double leftOffset;
    final whiteKeyWidth = 24.5; // 24px + 0.5px margin
    final octaveOffset = octave * 7 * whiteKeyWidth;
    
    switch (positionInOctave) {
      case 0: // C# - between C(0) and D(1)
        leftOffset = octaveOffset + (0.7 * whiteKeyWidth);
        break;
      case 1: // D# - between D(1) and E(2)
        leftOffset = octaveOffset + (1.7 * whiteKeyWidth);
        break;
      case 3: // F# - between F(3) and G(4)
        leftOffset = octaveOffset + (3.7 * whiteKeyWidth);
        break;
      case 4: // G# - between G(4) and A(5)
        leftOffset = octaveOffset + (4.7 * whiteKeyWidth);
        break;
      case 5: // A# - between A(5) and B(6)
        leftOffset = octaveOffset + (5.7 * whiteKeyWidth);
        break;
      default:
        leftOffset = 0;
    }
    
    return Positioned(
      left: leftOffset,
      child: Container(
        width: 16,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? Colors.orange.shade800 : Colors.grey.shade800,
          border: Border.all(
            color: isActive ? Colors.orange : Colors.grey.shade700,
            width: isActive ? 2 : 1,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isActive)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                note.replaceAll('#', '♯'),
                style: TextStyle(
                  fontSize: 6,
                  color: isActive ? Colors.orange.shade200 : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}